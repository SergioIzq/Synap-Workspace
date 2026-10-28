Seguimiento: SergioIzq/Synap-Workspace#16

# Proposal

## Why

El calendario va a vivir en un servidor CalDAV propio, y los próximos changes (vista de calendario, escritura de eventos) se construyen sobre CalDAV. Mantener Google exige un cliente OAuth por despliegue, verificación de Google y un segundo adaptador que probar, para una opción que nunca se ha usado: no hay ni ha habido ninguna conexión de Google en producción.

Además, la sección "Calendario" de la web no funciona contra la API: el front llama a rutas que no existen (`GET /api/settings/calendar`, `POST .../caldav`, `.../google/authorize`) y espera otra forma de respuesta. Como este change rehace esa sección, la deja alineada con la API.

## What Changes

- **BREAKING** Se elimina la conexión con Google Calendar: el consentimiento OAuth, su callback, su configuración (`GoogleCalendar:*`), la renovación y revocación de tokens, y el estado del inicio de conexión guardado en el usuario.
- CalDAV pasa a ser el único proveedor de calendario. La lectura, el asistente, el briefing y los recordatorios anclados a eventos no cambian.
- La API deja de exponer si Google está disponible.
- La sección "Calendario" de Configuración solo ofrece CalDAV, sin botón de Google ni lectura del resultado de un consentimiento.
- La sección "Calendario" usa el contrato real de la API: el estado se lee de `GET /api/settings`, se conecta con `PUT /api/settings/calendar/caldav` y muestra la cuenta y la marca de reconexión.
- Una migración borra las columnas del inicio de conexión con Google. No hay tokens que revocar.

## Scope

- Retirar Google del backend: dominio, aplicación, infraestructura, API, configuración y tests.
- Retirar Google del frontend y alinear la sección "Calendario" con la API.
- Actualizar las specs `calendar-integration`, `user-settings` y `ai-assistant`.

## Non-goals

- Vista de calendario, escritura de eventos, varios calendarios o ámbitos Personal/Trabajo: son changes posteriores.
- Guardar eventos en Synap: esa regla se revisa en el change que lo introduzca.
- Cambiar cómo se descubre o se lee un calendario CalDAV.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `calendar-integration`: el calendario solo se conecta por CalDAV. Se elimina el requisito de conectar Google, y la desconexión, la reconexión y el estado dejan de mencionar Google.
- `user-settings`: la sección "Calendario" solo ofrece CalDAV y muestra la cuenta conectada.
- `ai-assistant`: el escenario de consulta del calendario deja de suponer una conexión de Google.

## Impact

- Repos afectados: `back` (eliminación del adaptador de Google, la migración y el contrato de settings) y `front` (sección "Calendario", modelo y servicio de settings).
- Desaparecen las variables `GoogleCalendar__*`. Nunca llegaron a `docker-compose.yml` ni al runbook, así que el despliegue no cambia.
- Desaparecen las rutas `POST /api/settings/calendar/google/start` y `GET /api/calendar/google/callback`.
