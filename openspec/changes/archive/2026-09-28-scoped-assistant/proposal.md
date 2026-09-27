# Proposal

## Why

Hoy el asistente solo sabe responder sobre "todo el vault": cada pregunta busca por similitud semántica entre todas las notas y, como esa búsqueda no discrimina bien (modelo de embeddings solo en inglés con notas en español y un umbral que nada supera por abajo), las respuestas mezclan fuentes irrelevantes. Además cada pregunta va aislada, así que un seguimiento como "desarrolla el punto 2" no funciona.

El caso de uso más frecuente es "pregúntale sobre *esto*": una nota concreta o todo lo que hay bajo una etiqueta. Si el usuario elige el alcance, no hace falta adivinar qué notas son relevantes, las respuestas se basan justo en lo que el usuario ha señalado, el contexto enviado a Groq es pequeño y predecible (importante con el plan gratuito del usuario) y se puede entregar sin esperar a arreglar la búsqueda semántica global.

## What Changes

- **Preguntar sobre una nota**: el asistente responde basándose solo en el contenido de esa nota, enviado tal cual y sin búsqueda semántica. Si la nota es muy larga, se recorta a un presupuesto de tokens y la respuesta indica que solo se ha usado una parte.
- **Preguntar sobre una etiqueta**: el asistente responde usando solo las notas del usuario que llevan esa etiqueta:
  - si caben todas en el presupuesto, se envían todas;
  - si no, se envían las más parecidas a la pregunta dentro de esa etiqueta.
- **Memoria corta en las conversaciones con alcance**: la pregunta lleva los últimos 3 turnos de esa conversación, para que funcionen los seguimientos. La conversación global sigue sin memoria.
- **Entradas en la web**:
  - botón "Preguntar a la IA" en el detalle de una nota;
  - "Preguntar sobre #etiqueta" desde la etiqueta, en el detalle y en el filtro del listado;
  - en el chat, escribir `@` para elegir una nota o `#` para elegir una etiqueta.
- **Chat con alcance**:
  - un chip muestra el alcance activo ("Sobre: <título>" o "Sobre: #etiqueta") y se puede quitar;
  - acciones rápidas según el alcance: Resumir, Puntos clave, Explícame este código (solo para notas de código), y para etiquetas "Resume lo que sé de #x";
  - cada alcance tiene su propia conversación, guardada en el dispositivo.
- **Enlaces (bookmarks)**: por ahora no se puede preguntar sobre ellos, porque solo guardan la URL. El botón aparece desactivado con una explicación, y la API responde con un estado específico. Se habilitará con el futuro change de artículos "leer después".
- **API**: `POST /api/assistant/ask` acepta `scope` (`noteId` o `tag`) y `history` como campos opcionales. Sin ellos se comporta exactamente como hoy (compatible hacia atrás).

## Capabilities

### New Capabilities

_Ninguna._

### Modified Capabilities

- `ai-assistant`:
  - nuevos requisitos de preguntas con alcance de nota, con alcance de etiqueta y con memoria corta;
  - nuevos requisitos de entradas y chip de alcance en la web, y de enlaces no disponibles como alcance;
  - "Conversation persists on the device" pasa a ser una conversación por alcance.

## Impact

- **Synap-Backend (.NET)**:
  - `AssistantController.AskRequest`;
  - `AskAssistantQuery` y su handler (validación del alcance, comprobación de propiedad de la nota o etiqueta, límites del historial);
  - `IAiServiceClient.AskAsync` y `AiServiceClient`;
  - `AssistantAnswer` (nuevos campos y estado);
  - tests unitarios y de integración, incluido el aislamiento entre usuarios.
- **Synap-Backend (ai-service)**:
  - `app/api/assistant.py` (ramas por alcance y presupuesto de contexto);
  - `app/embeddings/repository.py` (lectura de una nota y búsqueda limitada a una etiqueta, siempre filtrando por `user_id`);
  - `LlmProvider.generate_answer` y `GroqProvider` (mensajes de historial y prompt según el alcance);
  - tests.
- **Synap-Frontend**:
  - `assistant.model.ts`, `assistant.service.ts`, `assistant.store.ts` (conversaciones por alcance y migración del almacenamiento actual);
  - `assistant.page.ts` (chip, acciones rápidas, selector `@` y `#`);
  - `note-detail.page.ts` y `notes-list.page.ts` (entradas).
- **Coste en Groq**: una llamada por pregunta, como hoy. El contexto está acotado por el presupuesto, más el historial de 3 turnos también acotado.
- **Sin migraciones de base de datos.**
