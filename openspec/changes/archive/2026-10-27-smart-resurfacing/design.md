# Design

## Context

Ver `proposal.md` («Why»). Estado actual del que parte el diseño:

- **Embeddings.** Al crear o editar una nota, `EmbeddingSupport.EnqueueGeneration` encola en `IBackgroundJobQueue` la llamada al `ai-service`, que guarda el vector en `note_embeddings` (una fila por nota y modelo, con `ON DELETE CASCADE`). Una nota recién creada pasa unos segundos sin embedding, y otra con un embedding de un modelo antiguo espera al reindexado.
- **Relacionadas.** `GET /api/notes/{id}/related` comprueba la propiedad en .NET y pide a `GET /internal/notes/{id}/related` las cinco más parecidas, **sin umbral**. Si la nota no tiene embedding, devuelve una lista vacía, igual que una nota sin relación. El detalle de la nota (`note-detail.page.ts`) lo pinta como «Relacionadas».
- **Umbral de relevancia.** El briefing ya filtra las notas de un evento con `BriefingLimits.RelatedNoteSimilarityFloor = 0.55`, más estricto que el `min_relevant_similarity = 0.45` del `ai-service` para las preguntas, porque nadie ha preguntado por esas notas.
- **Briefing.** `BriefingContentService.BuildAsync` arma `BriefingContent` con secciones independientes, `BriefingMessage` las pinta y `BriefingDispatcher` las envía. `BriefingLimits` guarda los números que la spec no fija. El sweep (`BriefingSweepHostedService`, cada 15 minutos) y el briefing bajo demanda pasan por el mismo dispatcher.
- **Note.** Tiene `FechaCreacion`, `UpdatedAt` (solo la edición de texto lo mueve) y `Status`/`StatusChangedAt`. No registra aperturas.

## Goals / Non-Goals

**Goals:**

- Una única definición de «relacionado» en Synap: el umbral del briefing se reutiliza en las conexiones y en el rescate.
- Que el rescate cueste una sola consulta vectorial por briefing, sea cual sea el tamaño de la bóveda.
- Que la apertura de una nota sea un dato propio que no altere `UpdatedAt` y que no lo generen el asistente ni las búsquedas.

**Non-Goals:**

- Precalcular y guardar conexiones. Se calculan al consultarlas: la tabla de embeddings ya es el índice.
- Notificaciones push o por Telegram de conexiones.
- Cambiar `GET /api/notes/{id}/related` ni su spec (`ai-assistant`, «Semantic relations between notes»): sigue existiendo para quien lo use, aunque el detalle pasa a usar conexiones.

## Decisions

### 1. Conexiones: endpoint nuevo en lugar de cambiar `related`

`GET /api/notes/{id}/connections` devuelve `{ status: "ready" | "pending", notes: [{ id, title, content, type, similarity }], topic: string | null }`. Detrás, `GET /internal/notes/{id}/connections?user_id&min_similarity&limit` en el `ai-service` devuelve `{ indexed: bool, notes: [...] }`. `indexed` es falso cuando la nota no tiene embedding del modelo actual, y entonces .NET responde `pending`.

- *Alternativa:* añadir umbral y forma nueva a `related`. Romper su contrato obliga a tocar su spec y al cliente actual, y sigue sin distinguir «sin analizar». Un endpoint nuevo es aditivo.
- **Umbral:** `RelatedNoteSimilarityFloor` sale de `BriefingLimits` y pasa a una clase compartida (`RelevanceLimits` en `Synap.Domain`), que usan el briefing, las conexiones y el rescate. El valor se mantiene (0,55). **Máximo:** 5 conexiones (`ConnectionLimits.MaxConnections`).
- **Tema común:** se calcula en .NET con las etiquetas de las notas conectadas (una consulta a `note_tags` filtrada por usuario). Gana la etiqueta que llevan más conexiones, siempre que la lleven al menos dos. Un empate se resuelve por orden alfabético, para que la respuesta sea determinista. El `ai-service` no sabe de etiquetas en esta ruta, y así se queda.
- La propiedad se comprueba en .NET antes de llamar al `ai-service`, como en `GetRelatedNotesQueryHandler`. Un fallo del `ai-service` se traduce en un error 503 con mensaje en español. El front lo trata como «sin conexiones».

### 2. Aviso al capturar: sondeo acotado desde el front

Tras `NotesStore.create` con éxito desde el composer, el store lanza, sin esperar, un sondeo de `connections` cada 2 s hasta 6 intentos (unos 12 s). Si llega `ready` con notas, muestra un toast de PrimeNG no bloqueante («Se relaciona con N notas tuyas sobre #tema») con el botón «Ver», que navega a `/app/notes/{id}`. Si llega `ready` sin notas, `pending` hasta agotar los intentos o un error, no muestra nada. El sondeo vive en el store, no en el componente: el aviso sigue llegando aunque el usuario cambie de página.

- *Alternativa:* que el backend avise al terminar el embedding (SSE o WebSocket). Es infraestructura nueva para un aviso de cortesía. El sondeo acotado basta, porque el embedding tarda segundos.
- *Alternativa:* calcular las conexiones de forma síncrona en el `POST`. Retrasa la captura, que es la promesa central de Synap (fricción cero).
- Solo el composer lo dispara. Las capturas del Atajo de iOS, del asistente y las ediciones no, como dice la spec.

### 3. Detalle: mismo sondeo, bloque «Conexiones»

`note-detail.page.ts` sustituye `getRelated` por `getConnections`, con el mismo sondeo acotado mientras la respuesta sea `pending`, cancelado al cambiar de nota o al destruir el componente (`takeUntilDestroyed` y un `switchMap` sobre el id de la ruta). El bloque pasa a titularse «Conexiones» y solo se pinta con notas.

### 4. Apertura: `POST /api/notes/{id}/view` y columna `last_viewed_at`

`Note` recibe `LastViewedAt` (nullable) y `MarkViewed()`, que solo mueve ese campo. El detalle llama a `POST /api/notes/{id}/view` (204, o 404 si la nota no es del usuario) al cargar cada nota, sin esperar respuesta ni mostrar error.

- *Alternativa:* que `GET /api/notes/{id}` registre la apertura. Un GET con efectos secundarios se dispararía también al volver a leer la nota tras guardarla, o desde cualquier cliente futuro. Una llamada explícita deja claro qué cuenta como abrir.
- **Última actividad** = `GREATEST(updated_at, COALESCE(last_viewed_at, updated_at))`. `UpdatedAt` ya vale `FechaCreacion` al crear, así que cubre la creación sin una tercera columna. Las notas existentes migran con `last_viewed_at = NULL`: su actividad es su última edición, que es lo más honesto que se sabe de ellas.
- La operación no encola embedding ni toca `UpdatedAt`, `Status` o `StatusChangedAt`.

### 5. Rescate: .NET aplica las reglas y el `ai-service` solo compara vectores

`BriefingContentService` obtiene dos listas de ids con consultas de `IBriefingReadRepository`:

- **Motivos:** notas del usuario con `updated_at >= now - RecentWindow` (7 días), las 20 más recientes.
- **Candidatas:** notas del usuario sin estado, con última actividad `< now - DormantAfter` (30 días) y `last_resurfaced_at IS NULL OR last_resurfaced_at < now - ResurfaceCooldown` (30 días). No se limitan: son ids.

Con ambas listas no vacías, llama a `POST /internal/notes/similarity-pairs` con `{ user_id, anchor_ids, candidate_ids, min_similarity, limit }`. El endpoint resuelve en una consulta pgvector (`CROSS JOIN LATERAL` por candidata sobre los motivos, `DISTINCT ON (candidate)` ordenado por similitud, filtrando por `user_id` y por modelo actual en ambos lados) los pares `{ candidate_id, anchor_id, similarity }` por encima del umbral, de mayor a menor, hasta `limit` (3, `BriefingLimits.ResurfacedPerBriefing`). .NET carga título y contenido de candidatas y motivos para pintar el mensaje.

- *Alternativa:* que el `ai-service` filtre por estado y actividad con su propia SQL sobre `notes`. Repartiría la regla de «dormida» entre dos servicios y dos lenguajes. Aquí el `ai-service` no sabe qué es una nota dormida.
- *Alternativa:* llamar a `connections` por cada nota reciente. Serían N llamadas por usuario y sweep, frente a una.
- Los números (`DormantAfter`, `RecentWindow`, `ResurfaceCooldown`, `ResurfacedPerBriefing`) viven en `BriefingLimits`, con el mismo argumento que `PausedResurfaceAfter`: deciden cuánto muestra el briefing, no qué promete.
- Una nota no puede ser a la vez motivo y candidata: un motivo tiene `updated_at` de los últimos 7 días y una candidata lleva 30 sin actividad.

### 6. Registro del rescate al entregar

`BriefingContent` gana la sección `Resurfaced: BriefingSection<BriefingResurfacedNote>` (nota, días sin actividad y nota motivo), que cuenta en `IsEmpty`. Cuando `BriefingDispatcher` obtiene `Sent`, marca `last_resurfaced_at = now` en las notas mostradas con un `UPDATE` acotado por `user_id` e ids (`INoteWriteRepository.MarkResurfacedAsync`). Si la entrega falla, no marca nada. Vale igual para el sweep y para el briefing bajo demanda, porque ambos pasan por el dispatcher.

- *Alternativa:* marcarlas al construir el contenido. Un fallo de Telegram las «gastaría» sin que el usuario las viera, y la spec lo prohíbe.
- Si marcar falla después de enviar, se registra el error y el briefing sigue contando como entregado. Lo peor es que la nota se repita al día siguiente, que es preferible a reenviar el briefing.

### 7. Mensaje

`BriefingMessage` añade al final `Section(text, "🔁", "Para retomar", content.Resurfaced, ResurfacedLine)`, con línea `«Kubernetes: despliegues» <i>sin tocar hace 64 días · por «Helm charts»</i>`, escapada con `Escape` y `NoteDisplay.Label` como las demás.

### 8. Fallo del `ai-service` en el briefing

Un error o timeout de `similarity-pairs` deja la sección vacía, sin aviso (a diferencia del calendario, el usuario no ha configurado nada que deba revisar), y no se marca nada. Se registra en el log con su causa (spec `platform-operations`, «A recorded failure names its own cause»). Se aplica un techo de 10 s, como el calendario.

## Risks / Trade-offs

- [El sondeo de 12 s no basta si la cola de embeddings está saturada, por ejemplo durante un reindexado] → No se avisa y las conexiones aparecen después en el detalle. La spec lo admite («El análisis tarda demasiado»).
- [Una bóveda con miles de notas dormidas manda miles de ids en `candidate_ids`] → Se pasan como `uuid[]` en una sola consulta y la comparación es contra ≤ 20 motivos. Si algún día pesa, el paso siguiente es mover el filtro a una vista compartida, sin cambiar la spec.
- [El umbral de 0,55 se calibró para títulos de eventos, no para nota contra nota] → Se valida contra una bóveda real en una tarea propia. Si hay que moverlo, se mueve para todos, porque es una sola definición de «relacionado».
- [Registrar la apertura en cada visita escribe en la base de datos en cada carga del detalle] → Es un `UPDATE` de una fila por acción del usuario, despreciable al volumen de Synap. No se añade throttling.
- [Las notas antiguas, sin `last_viewed_at`, pueden salir como dormidas aunque se hayan consultado a menudo] → Solo se rescatan si se relacionan con algo reciente, y abrirlas una vez las despierta.

## Migration Plan

1. Migración EF: `notes.last_viewed_at timestamptz NULL` y `notes.last_resurfaced_at timestamptz NULL`, sin backfill. Es aditiva: el código anterior la ignora.
2. Desplegar `ai-service` y API juntos (mismo compose). Los endpoints nuevos son aditivos y `related` no cambia.
3. Desplegar el front.
4. **Rollback:** volver a la imagen anterior. Las columnas nuevas se quedan sin uso y sin efecto. La migración solo se revierte si se quiere limpiar el esquema.

## Open Questions

- El texto exacto del toast y el icono de la sección «Para retomar» se pueden ajustar en la revisión visual sin tocar la spec.
