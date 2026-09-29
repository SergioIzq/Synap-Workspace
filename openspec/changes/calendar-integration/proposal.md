# Proposal

## Why

El contexto de lo que pasa en el día está en el calendario, no en las notas. Sin acceso al calendario, Synap no puede prepararte para una reunión, recordarte que mañana tienes una demo o conectar una nota de ayer con la reunión de mañana. Con acceso al calendario, el briefing diario pasa de ser un resumen de notas a ser un verdadero co-piloto del día.

## What Changes

- El usuario conecta su calendario (Google Calendar en primera iteración; CalDAV como opción genérica).
- El asistente puede responder preguntas como "¿qué tengo mañana?" o "¿cuándo tengo la próxima reunión de sprint?".
- El briefing diario incluye los eventos del día con las notas relacionadas: si tienes una reunión de revisión de código y tienes notas sobre ese módulo, el briefing las enlaza.
- El asistente puede crear recordatorios alineados con eventos del calendario: "recuérdame revisar X una hora antes de la demo".
- Los eventos del calendario no se guardan como notas; solo se leen en el momento de generar la respuesta o el briefing.

## Capabilities

### New Capabilities

- `calendar-integration`: conexión y lectura de un calendario externo, con privacidad (los eventos nunca se almacenan en Synap).

### Modified Capabilities

- `ai-assistant`: nueva herramienta `get_calendar_events` disponible en la conversación global.
- `briefing`: los eventos del día se incluyen en el briefing con las notas relacionadas.
- `assistant-reminders`: los recordatorios pueden anclarse a eventos del calendario.

## Impact

- Requiere OAuth con Google Calendar o soporte CalDAV.
- Los eventos se leen en tiempo real; no se indexan ni se embeben, lo que simplifica privacidad y almacenamiento.
- Es el change más complejo de este grupo: OAuth, manejo de tokens de terceros y permisos de lectura de calendario.
- Depende de `daily-briefing` y `assistant-reminders` para sacarle el máximo partido.
