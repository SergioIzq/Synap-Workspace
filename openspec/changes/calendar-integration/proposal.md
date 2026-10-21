Seguimiento: SergioIzq/Synap-Workspace#7

# Proposal

## Why

El contexto de lo que pasa en el día está en el calendario, no en las notas. Sin acceso al calendario, Synap no puede prepararte para una reunión, recordarte que mañana tienes una demo o conectar una nota de ayer con la reunión de mañana. Con acceso al calendario, el briefing diario pasa de ser un resumen de notas a ser un verdadero co-piloto del día.

## What Changes

- El usuario conecta su calendario desde Configuración: Google Calendar (OAuth) o cualquier servidor CalDAV (URL, usuario y contraseña de aplicación). Una sola conexión por usuario, y se lee solo su calendario principal.
- El asistente puede responder preguntas como "¿qué tengo mañana?" o "¿cuándo tengo la próxima reunión de sprint?".
- El briefing diario incluye los eventos del día con las notas relacionadas: si tienes una reunión de revisión de código y tienes notas sobre ese módulo, el briefing las enlaza.
- El asistente puede crear recordatorios anclados a un evento: "recuérdame revisar X una hora antes de la demo". El momento se fija al crearlo; si el evento se mueve después, el recordatorio no cambia.
- Los eventos del calendario no se guardan como notas ni de ninguna otra forma: solo se leen en el momento de generar la respuesta o el briefing.

## Scope

- Conexión, estado y desconexión de un calendario de Google o CalDAV, con las credenciales cifradas.
- Lectura en tiempo real de los eventos del calendario principal, con las recurrencias expandidas.
- Nueva acción de solo lectura del asistente para consultar eventos.
- Sección de eventos del día en el briefing, automático y bajo demanda.
- Recordatorios anclados a un evento, creados desde el asistente.

## Non-goals

- Crear, modificar o borrar eventos del calendario.
- Varios calendarios por cuenta o varias cuentas de calendario por usuario.
- Recordatorios que sigan al evento si este cambia de hora.
- Crear recordatorios anclados a eventos desde la sección "Recordatorios" de la web.
- Indexar, embeber o guardar en caché los eventos.
- Microsoft 365/Outlook u otros proveedores con API propia.

## Capabilities

### New Capabilities

- `calendar-integration`: conexión y lectura de un calendario externo, con privacidad (los eventos nunca se almacenan en Synap).

### Modified Capabilities

- `ai-assistant`: nueva acción `get_calendar_events` en la conversación global, y recordatorios anclados a un evento.
- `briefing`: los eventos del día se incluyen en el briefing con las notas relacionadas.
- `reminders`: un recordatorio anclado a un evento es un recordatorio ordinario con un momento fijo.
- `user-settings`: la página de Configuración gana una sección "Calendario".

## Impact

- Repos afectados: `back` (conectores de Google y CalDAV, almacenamiento cifrado de credenciales, acción del asistente, briefing) y `front` (sección "Calendario" en Configuración).
- Requiere un cliente OAuth de Google por despliegue (nuevas variables de entorno en `docker-compose.yml` y en el runbook de despliegue de este repo). Sin él, solo se ofrece CalDAV.
- Los eventos se leen en tiempo real; no se indexan ni se embeben, lo que simplifica privacidad y almacenamiento.
- Es el change más complejo de este grupo: OAuth, manejo de tokens de terceros y dos protocolos de lectura.
- Depende de `daily-briefing` y `assistant-reminders`, ya archivados.
