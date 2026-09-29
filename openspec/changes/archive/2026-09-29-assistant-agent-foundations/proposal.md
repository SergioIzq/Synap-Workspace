# Proposal

## Why

El objetivo a largo plazo es que el asistente de Synap sea un asistente personal tipo "Jarvis": que te conozca, que actúe por ti y que más adelante se adelante a lo que necesitas. Hoy está lejos de eso por tres motivos, y cada uno depende del anterior:

1. **No encuentra bien tus notas.** Los embeddings usan `BAAI/bge-small-en-v1.5`, un modelo solo en inglés, con notas escritas en español. La búsqueda semántica global no discrimina y las respuestas mezclan fuentes irrelevantes. Todo lo demás se apoya en esta búsqueda, así que es lo primero que hay que arreglar.
2. **No sabe quién eres.** Solo conoce lo que has capturado. Cada conversación empieza de cero y la conversación global no recuerda ni siquiera la pregunta anterior.
3. **Solo sabe leer.** Aunque le digas "apúntame esto" o "etiqueta esta nota como #trabajo", no puede hacerlo: solo busca notas y redacta una respuesta.

Este change cubre los tres primeros niveles: búsqueda fiable, memoria sobre el usuario y acciones sobre el vault. Deja preparado el terreno para los siguientes (tareas, recordatorios, avisos proactivos, voz e integraciones), que irán en changes aparte.

## What Changes

### Nivel 0: búsqueda fiable en español

- **Modelo de embeddings multilingüe**: se sustituye el modelo actual por uno que entienda español.
  - La dimensión sigue siendo 384, como la columna `vector(384)`, así que no hay que cambiar el esquema del vector.
- **Se embebe el título junto al contenido**: hoy solo se usa el contenido.
- **Reindexación de todas las notas existentes**:
  - se guarda qué modelo generó cada embedding;
  - los embeddings de un modelo distinto al configurado se regeneran en segundo plano, sin intervención manual;
  - mientras dura la reindexación, el asistente sigue funcionando.
- **Búsqueda híbrida para el asistente**: combina la búsqueda semántica con la búsqueda de texto completo en español que ya existe (`synap_note_search_vector`). Así, un nombre propio, un código de error o una palabra exacta encuentran su nota aunque la similitud semántica sea baja.
- **Umbral de relevancia recalibrado** para el nuevo modelo, sin cambiar el comportamiento visible: si no hay nada relevante, el asistente lo dice.

### Nivel 1: el asistente te conoce

- **Memoria del usuario**: una lista de hechos sobre ti, como "trabajo con .NET y Angular", "prefiero respuestas cortas" o "estoy preparando la certificación AZ-204".
  - Se incluye en cada pregunta al asistente, tanto en la conversación global como en las que tienen alcance, sin llamadas extra a Groq.
  - Tiene un tamaño máximo acotado.
- **Cómo se guarda un recuerdo**:
  - pidiéndoselo al asistente ("recuerda que…"), usando las acciones del nivel 2;
  - o a mano, desde una sección "Memoria" en Configuración.
- **Control total del usuario sobre su memoria**:
  - puede ver, editar y borrar cada recuerdo, o borrarlos todos;
  - la memoria nunca se comparte entre usuarios;
  - se borra al eliminar la cuenta.
- **La conversación global tiene memoria corta**: lleva los últimos turnos, igual que ya hacen las conversaciones con alcance (scoped-assistant). Así funcionan seguimientos como "¿y eso cómo se configura?".

### Nivel 2: el asistente actúa sobre tus notas

- **Asistente con herramientas (tool calling)** en la conversación global. El modelo decide qué hacer:
  - **buscar notas**: con la búsqueda híbrida, varias veces si hace falta y con términos que elige él, en vez de un único top-k fijo;
  - **leer una nota concreta** entera;
  - **crear una nota** (texto o código) con título y etiquetas;
  - **añadir etiquetas** a una nota existente;
  - **guardar un recuerdo** en la memoria del usuario.
- **Solo acciones no destructivas**: el asistente no puede borrar notas ni sobrescribir su contenido. Todo lo que hace se puede deshacer desde la web.
- **Transparencia**:
  - cada respuesta lista las acciones realizadas ("Nota creada: …", "Etiqueta #x añadida a …", "Recordado: …"), con enlace a lo creado o modificado;
  - las fuentes consultadas se siguen mostrando como hoy.
- **Coste acotado**: cada pregunta tiene un número máximo de llamadas a Groq, con la key del usuario. Si se alcanza, el asistente responde con lo que tenga en ese momento, sin romperse.
- **Modelos sin tool calling**: si el modelo elegido por el usuario no admite herramientas, el asistente vuelve al comportamiento de solo responder (RAG con la nueva búsqueda). En Configuración se indica qué modelos admiten acciones.
- **Las acciones respetan las mismas reglas que la API**:
  - propiedad de las notas y aislamiento entre usuarios;
  - validaciones de nota y etiqueta;
  - rate limiting.
  El asistente no tiene un camino de escritura privilegiado.

### Fuera de alcance (niveles siguientes)

- Tareas, recordatorios y notificaciones (push, Telegram, email).
- Briefing diario, revisión semanal y resurfacing proactivo.
- Voz (Whisper y Atajo de iOS conversacional).
- Integraciones externas (Kash, calendario).
- Extracción automática de recuerdos sin que el usuario lo pida: costaría llamadas extra a Groq por cada conversación.
- Herramientas dentro de las conversaciones con alcance: estas mantienen su comportamiento actual, más la memoria del usuario.

## Capabilities

### New Capabilities

- `assistant-memory`: hechos persistentes sobre el usuario que el asistente usa como contexto. Cubre:
  - alta por petición al asistente o a mano;
  - consulta, edición y borrado desde la web;
  - límites de tamaño;
  - aislamiento entre usuarios;
  - borrado con la cuenta.

### Modified Capabilities

- `ai-assistant`:
  - "Embedding generation": modelo multilingüe, título más contenido, y reindexación automática al cambiar de modelo;
  - "Natural-language assistant queries": recuperación híbrida y uso de la memoria del usuario;
  - nuevos requisitos de memoria corta en la conversación global;
  - nuevos requisitos de acciones del asistente: herramientas permitidas, no destructivas, visibles en la respuesta, límite de llamadas y aislamiento;
  - nuevo requisito de modo sin herramientas para modelos que no las admiten.
- `user-settings`:
  - "Choose the assistant model" indica qué modelos admiten acciones;
  - la sección "Memoria" en la página de Configuración.
- `identity`:
  - "Delete account" también borra la memoria del usuario.

## Impact

- **Depende de `scoped-assistant`**: debe archivarse antes. Este change reutiliza su historial acotado y su presupuesto de contexto, y extiende su prompt.
- **Synap-Backend (ai-service)**:
  - `app/core/config.py`: modelo de embeddings, límites de iteraciones y de memoria;
  - `app/embeddings/`: texto a embeber, registro del modelo, reindexación y búsqueda híbrida (RRF entre pgvector y `tsvector`);
  - `app/api/assistant.py`: bucle de herramientas y fallback sin herramientas;
  - `app/llm/groq_provider.py` y `provider.py`: mensajes con `tools`, detección de soporte y memoria en el system prompt;
  - tests, incluido el aislamiento entre usuarios en cada herramienta.
- **Synap-Backend (.NET)**:
  - nuevo agregado de memoria del usuario: dominio, repositorio, endpoints CRUD y borrado en cascada con la cuenta;
  - las acciones de escritura del asistente pasan por los casos de uso existentes (`CreateNote`, etiquetado), que conservan la propiedad de las escrituras en el esquema relacional. El reparto exacto entre .NET y ai-service se decide en design.md;
  - `AssistantAnswer` con la lista de acciones realizadas;
  - `AskRequest` con historial también sin alcance.
- **Migraciones**:
  - columna del modelo en `note_embeddings`;
  - tabla de memoria del usuario.
- **Synap-Frontend**:
  - `assistant.page.ts` y `assistant.store.ts`: acciones realizadas con enlaces e historial en la conversación global;
  - página de Configuración: sección Memoria e indicador de soporte de acciones en el selector de modelo.
- **Coste en Groq**:
  - las preguntas sin herramientas siguen costando una llamada;
  - con herramientas cuestan de 1 al máximo configurado;
  - la memoria del usuario añade un bloque acotado de tokens a cada pregunta.
- **VPS**:
  - el nuevo modelo de embeddings es algo mayor, pero sigue siendo ONNX en CPU con fastembed;
  - la reindexación inicial es un pico puntual de CPU y se hace en segundo plano.
