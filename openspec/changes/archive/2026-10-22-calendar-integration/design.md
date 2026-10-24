# Design

## Context

Ver proposal.md (Why). Estas son las restricciones que condicionan el enfoque:

- Los secretos por usuario ya tienen un mecanismo: `ISecretProtector` cifra la API key de Groq (`User.GroqApiKeyEncrypted`) con `SECRETS_ENCRYPTION_KEY`. No hay ningún otro secreto de terceros por usuario.
- El asistente es un bucle de herramientas en `AssistantAgent` con un tope de 4 pasos (`MaxSteps`). Las herramientas están en `AgentTools.All` y se ejecutan como el propio usuario. `set_reminder` recibe el momento con las palabras del usuario y lo resuelve `ReminderWording` (observable-failures, Decision 5): el modelo no hace aritmética de fechas.
- El briefing es datos planos (`BriefingContent`) construidos por `BriefingContentService` a partir de consultas, nunca generados. Cada sección es una `BriefingSection<T>` con su total, y el mensaje escapa HTML en `BriefingMessage`.
- La búsqueda híbrida vive en el ai-service (`POST /search`, embeddings locales con fastembed) y no devuelve puntuación: `NoteSearchHit` no tiene `score`.
- La autenticación de la API es JWT por cabecera, así que una redirección del navegador desde Google no llega autenticada.
- Infraestructura sin SDKs de terceros: Telegram y Groq se usan con `HttpClient` directo.

## Goals / Non-Goals

**Goals:**
- Un único puerto de lectura de eventos con dos adaptadores (Google y CalDAV), para que el asistente y el briefing no sepan de proveedores.
- Que un calendario caído o revocado degrade a "sin eventos" con un aviso, nunca a un briefing o una respuesta fallidos.
- Que ningún dato de un evento llegue a la base de datos ni a los registros.

**Non-Goals:**
- Caché de eventos, ni siquiera en memoria entre peticiones. Cada pregunta y cada briefing leen del proveedor.
- Sincronización incremental, webhooks o notificaciones push del proveedor.
- Detección automática de qué notas "pertenecen" a un evento más allá de una búsqueda por su título.

## Decisions

### Decision 1: Un puerto `ICalendarReader` con un adaptador por proveedor

`Synap.Application` define `ICalendarReader.ListEventsAsync(userId, fromUtc, toUtc, maxEvents)`, que devuelve un `CalendarReadResult`: `NotConnected`, `NeedsReconnect`, `Unavailable(causa)` u `Ok(eventos)`. `Synap.Infrastructure` lo implementa con un despachador que carga la conexión del usuario y delega en `GoogleCalendarClient` o `CalDavCalendarClient`.

*Por qué un resultado en vez de excepciones:* los dos consumidores (asistente y briefing) tienen que hacer algo distinto en cada caso (remitir a Configuración, poner una línea de aviso, seguir sin eventos). Un tipo con los cuatro casos obliga a tratarlos todos, cosa que un `catch` olvidado no hace.

`CalendarEvent` es un record de dominio: `Title`, `StartUtc`, `EndUtc`, `AllDayDate?` (un `DateOnly` cuando dura todo el día, para que no se mueva con la zona horaria), `Location?`, `Description?`. Nunca se persiste.

### Decision 2: Una tabla `calendar_connections`, credenciales en un único blob cifrado

Tabla nueva, con clave `user_id` (que garantiza una conexión por usuario) y `ON DELETE CASCADE` hacia `users`: `provider` (`Google` | `CalDav`), `account_label` (email o usuario, para mostrarlo), `calendar_ref` (el id `primary` en Google, la URL de la colección en CalDAV), `credentials_encrypted`, `connected_at` y `needs_reconnect_since` (nullable).

`credentials_encrypted` es un JSON cifrado con `ISecretProtector`: `{refreshToken, accessToken, accessTokenExpiresAt}` en Google y `{username, password}` en CalDAV.

*Por qué no columnas en `users`:* son seis campos que solo existen cuando hay conexión, y el cascade cubre el borrado de la cuenta sin tocar `DeleteAccount`. *Por qué un blob y no columnas cifradas una a una:* el proveedor decide su forma, y añadir un tercer proveedor no requiere migración.

Si `TryUnprotect` falla (por ejemplo, porque se perdió la clave maestra), se trata como `NeedsReconnect`, igual que el camino de la clave de Groq.

### Decision 3: OAuth de Google con flujo de código en el servidor y `state` cifrado

1. `POST /api/settings/calendar/google/start` (autenticado) devuelve la URL de consentimiento. El `state` es `ISecretProtector.Protect({userId, nonce, expiresAt: +10 min})`, y el nonce y su caducidad se guardan en `users` (`calendar_oauth_nonce`, `calendar_oauth_expires_at`), con el mismo patrón que `TelegramLinkToken`. Un nuevo inicio sustituye al anterior.
2. Google redirige a `GET /api/calendar/google/callback?code&state` (anónimo). El endpoint descifra el `state`, comprueba que no ha caducado y que el nonce coincide con el del usuario, lo borra, intercambia el `code`, lee el `summary` del calendario `primary` (es el email de la cuenta) y guarda la conexión.
3. Responde con una redirección a `<AppOptions.PublicBaseUrl>/app/settings?calendar=connected|denied|error`, y la web muestra la notificación.

Scope: `https://www.googleapis.com/auth/calendar.events.readonly`, el mínimo que permite `events.list` sobre `primary`. Se pide `access_type=offline&prompt=consent` para obtener siempre un refresh token. El access token se renueva bajo demanda cuando falta menos de un minuto para que caduque; si la renovación devuelve `invalid_grant`, la conexión se marca con `needs_reconnect_since`.

*Por qué no se usa el `state` sin más:* un `state` cifrado pero reutilizable permitiría repetir una respuesta capturada. El nonce de un solo uso lo impide. *Por qué columnas y no una tabla:* solo hay un inicio en curso por usuario, igual que el código de Telegram, así que no hace falta entidad ni purga.

*Alternativa descartada, el SDK `Google.Apis.Calendar.v3`:* arrastra dependencias y su propio almacén de tokens para llamar a tres endpoints (token, events.list y revoke). Se queda `HttpClient`, como Telegram y Groq.

Se activa con `GoogleCalendar:ClientId`, `ClientSecret` y `RedirectUri`. Sin `ClientId`, `GET /api/settings` devuelve `googleCalendarAvailable: false` y la web solo ofrece CalDAV.

### Decision 4: CalDAV con descubrimiento, `expand` en el servidor e Ical.Net

Al conectar:
1. `PROPFIND` (Depth 0) sobre la URL dada. Si su `resourcetype` es `calendar`, esa es la colección.
2. Si no, se descubre `current-user-principal` (probando también `/.well-known/caldav`), luego `calendar-home-set` y, por último, `schedule-default-calendar-URL` si el servidor lo expone o, si no, la primera colección cuyo `supported-calendar-component-set` incluye `VEVENT`.
3. Un 401 o 403 se traduce a credenciales rechazadas; un timeout o un error de red, a servidor inalcanzable; si no se encuentra ninguna colección, a sin calendario utilizable (specs/calendar-integration "Conectar un calendario CalDAV").

Al leer, `REPORT calendar-query` con `time-range` y `<C:expand>`, para que el servidor devuelva las ocurrencias de las recurrencias. El iCalendar se parsea con **Ical.Net** (dependencia nueva en `Synap.Infrastructure`). Se descartan `STATUS:CANCELLED` y los `ATTENDEE` cuyo valor coincide con el usuario conectado y tienen `PARTSTAT=DECLINED`.

*Por qué Ical.Net:* parsear iCalendar a mano (plegado de líneas, `TZID` con `VTIMEZONE` embebidos, `VALUE=DATE`) es justo el código que falla a las 3 de la mañana. Si un servidor ignora `expand`, Ical.Net expande la regla en local como respaldo.

### Decision 5: La URL de CalDAV no puede apuntar a la red interna

El servidor hace peticiones a una URL que escribe el usuario, así que sin defensa esto es un SSRF de manual. El `HttpClient` de CalDAV usa un `SocketsHttpHandler.ConnectCallback` que resuelve el host y rechaza direcciones de loopback, privadas (RFC 1918 y ULA), link-local y de metadatos (`169.254.169.254`) antes de abrir el socket. La comprobación se hace en la conexión, no al validar la URL, para que un DNS que cambia entre la validación y la petición no sirva de bypass. También se exige HTTPS, no se siguen redirecciones a otro host y las respuestas tienen un tamaño máximo.

### Decision 6: `get_calendar_events` con un intervalo en palabras y eventos recordados durante la pregunta

Herramienta nueva en `AgentTools`:

```json
{"range": "mañana" | "esta semana" | "el viernes" | "próximos 30 días" ...,
 "query": "texto opcional que debe aparecer en el título"}
```

`CalendarRangeWording` (en `Synap.Domain`, junto a `ReminderWording` y reutilizando su reconocimiento de días) resuelve: hoy, mañana, pasado mañana, un día de la semana, una fecha, esta semana, la semana que viene, este mes y "próximos N días". Si no se entiende, se usan los próximos 30 días. `query` filtra por título sin distinguir mayúsculas ni acentos. Así, "¿cuándo es la próxima reunión de sprint?" se convierte en `{range: "próximos 30 días", query: "sprint"}`.

El resultado devuelve a cada evento un id corto (`e1`, `e2`...) con título, horas locales, ubicación y descripción recortada. Los eventos leídos se guardan en el `Run` de la pregunta y se descartan al terminar: es memoria de la petición, no almacenamiento.

La herramienta se ofrece siempre, tenga o no calendario el usuario. Sin conexión, el resultado es `{"status": "no_calendar"}` y el prompt indica que se remita a Configuración. *Por qué no ocultarla:* sin la herramienta, el modelo responde "¿qué tengo mañana?" inventando o con evasivas, que es justo el fallo que `AgentClaimGuard` existe para atajar.

El texto de "Answering without actions" (`AgentPrompt`) añade la consulta del calendario a la lista de lo que no puede hacer.

### Decision 7: Recordatorios anclados con `event_id` en `set_reminder`

`set_reminder` gana un `event_id` opcional. Cuando viene, `when` se interpreta como una antelación respecto al inicio del evento ("una hora antes", "media hora antes", "30 minutos antes", "el día antes", "dos días antes"), y la resuelve `ReminderOffsetWording`. Un día sin hora significa las 09:00 locales. El `event_id` tiene que ser uno de los que devolvió `get_calendar_events` en la misma pregunta; si no, el resultado es `event_not_found`.

*Por qué un id de la misma pregunta y no el id del proveedor:* en CalDAV, una ocurrencia se identifica con UID más RECURRENCE-ID, y volver a pedirla supone una segunda consulta. Con el evento ya en memoria, el cálculo es una resta y no cuesta un paso más: los 4 pasos alcanzan para leer, crear el recordatorio y responder.

El recordatorio resultante pasa por `CreateReminderCommand` sin cambios: texto, momento en UTC y nota opcional. No guarda nada del evento (specs/reminders).

### Decision 8: Notas relacionadas por búsqueda con umbral

Por cada evento del día, `BriefingContentService` llama a `IAiServiceClient.SearchAsync(userId, título, NotesPerEvent)`. Hoy la búsqueda siempre devuelve algo, aunque no tenga que ver. Por eso `/search` gana un `min_similarity` opcional que filtra por similitud coseno de la parte semántica. Si no se pasa, el comportamiento actual no cambia. El umbral lo fija `BriefingLimits.EventNoteMinSimilarity` (punto de partida: 0,55; se ajusta con datos reales).

Límites: `BriefingLimits.EventsPerDay = 8`, `NotesPerEvent = 2`. La búsqueda va contra el ai-service interno con embeddings locales, así que el título del evento no sale del despliegue y no hace falta la key de Groq.

### Decision 9: El calendario en el briefing, con plazo y sin bloquear el barrido

`BriefingContent` gana `Calendar: BriefingCalendar`, que es `NotConnected`, `Unreadable(needsReconnect)` o `Events(BriefingSection<BriefingEvent>)`. `IsEmpty` cuenta los eventos, pero no el aviso. La lectura del calendario y sus búsquedas tienen un plazo de 10 s por usuario; si se supera, el resultado es `Unreadable`. Así, un CalDAV lento no retrasa el briefing de los demás, porque el despachador ya aísla los fallos por usuario.

`BriefingMessage` pinta `📅 Hoy en tu calendario` como primera sección: primero los eventos de todo el día y después los demás por hora, con las notas debajo con el mismo enlace a `/app/notes/{id}` que usan los recordatorios. Todo el texto del evento pasa por `Escape`.

### Decision 10: Los eventos son datos no confiables

Una invitación la puede escribir cualquiera, y su título o descripción pueden llevar instrucciones dirigidas al modelo. El resultado de la herramienta envuelve los eventos como datos, el prompt dice que nunca se sigan instrucciones contenidas en eventos, y la descripción se recorta a 500 caracteres. El impacto ya está acotado porque todas las acciones son no destructivas y del propio usuario, pero no se le da más superficie.

Los registros de los adaptadores solo llevan el usuario, el proveedor, el código de estado y la causa, nunca el cuerpo de la respuesta.

## Risks / Trade-offs

- [Riesgo] Mientras el proyecto de Google Cloud está en modo "Testing", los refresh tokens caducan a los 7 días y la conexión pide reconectar cada semana. → Mitigación: el runbook documenta publicar la app (el scope `calendar.events.readonly` es sensible y requiere verificación de Google para más de 100 usuarios). Para uso personal, añadir el propio usuario como tester y aceptar la reconexión, o usar CalDAV.
- [Riesgo] Servidores CalDAV que no implementan `expand` o lo hacen mal. → Mitigación: la expansión local con Ical.Net como respaldo, y tests con respuestas reales grabadas de iCloud, Fastmail y Nextcloud.
- [Riesgo] Google Calendar por CalDAV exige OAuth. → Se documenta en la UI: para Google se usa el botón de Google.
- [Riesgo] En CalDAV, la detección de invitaciones rechazadas depende de que el usuario coincida con el `ATTENDEE`. → Mitigación: si no coincide, el evento se muestra, que es el fallo menos dañino.
- [Trade-off] Leer en cada pregunta añade latencia (entre 200 ms y 1 s) a las preguntas que usan el calendario. Se acepta a cambio de no almacenar nada.
- [Trade-off] El umbral de similitud es un número fijo. → `ponytail:` umbral global; si da mucho ruido o muy poco, se ajusta por datos, no por usuario.
- [Riesgo] Un recordatorio anclado no sigue al evento. → Lo dice la spec y lo dice la respuesta del asistente.

## Migration Plan

1. Migración aditiva: la tabla `calendar_connections` y dos columnas nullable en `users`. Sin backfill.
2. Desplegar el backend sin `GoogleCalendar:ClientId`: solo se ofrece CalDAV, y el briefing de quien no tiene calendario no cambia.
3. Crear el cliente OAuth en Google Cloud con la URI de redirección `<api>/api/calendar/google/callback`, y añadir `GOOGLE_CALENDAR_CLIENT_ID`, `GOOGLE_CALENDAR_CLIENT_SECRET` y `GOOGLE_CALENDAR_REDIRECT_URI` a `docker-compose.yml` y a `docs/deployment-runbook.md` de este repo. **Este paso queda fuera de `tasks.md`**, porque `/montrel:apply` solo edita los repos de código: se hace a mano o en el PR del change en este repo.
4. Rollback: quitar `ClientId` desactiva Google. La migración se puede revertir porque nada más depende de esa tabla ni de esas columnas.

## Open Questions

- El valor final de `EventNoteMinSimilarity`. Se fija con el primer uso real y no cambia ni specs ni tareas.
