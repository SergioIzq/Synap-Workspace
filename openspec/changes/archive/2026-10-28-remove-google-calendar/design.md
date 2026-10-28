# Design

## Context

La integración se hizo con dos proveedores detrás de un mismo puerto de lectura (`ICalendarReader` → `ICalendarProviderClient`), y la conexión guarda el proveedor como texto (`provider`, `HasConversion<string>()`). Las credenciales se serializan como JSON según el proveedor. Google añade además:
- un inicio de conexión guardado en `users` (`calendar_oauth_nonce` y `calendar_oauth_expires_at`);
- un endpoint anónimo de vuelta;
- un bloque de opciones `GoogleCalendar`.

Al revisar el front se ve que la sección "Calendario" no coincide con la API en ningún punto:

| | Front espera | API real |
|---|---|---|
| Estado | `GET /api/settings/calendar` → `{ connected, kind, connectedAt, googleAvailable }` | Bloque del calendario en `GET /api/settings` → `{ googleCalendarAvailable, connection: { provider, account, connectedAt, needsReconnect, needsReconnectSince } \| null }` |
| CalDAV | `POST .../calendar/caldav` con `{ serverUrl, username, password }` | `PUT /api/settings/calendar/caldav` con `{ url, username, password }` |
| Google | `POST .../google/authorize` + `POST .../google` | `POST .../calendar/google/start` + `GET /api/calendar/google/callback` |

Los tests de cada lado pasan porque el front prueba contra mocks escritos con su propio contrato.

## Goals / Non-Goals

**Goals:**
- Que no quede código, configuración ni columna de Google, y que CalDAV funcione igual que hoy.
- Que la sección "Calendario" funcione de verdad contra la API.

**Non-Goals:**
- Reestructurar el puerto de lectura o el cliente CalDAV más allá de quitar la rama de Google.

## Decisions

### 1. Mantener el concepto de proveedor, con un solo valor

`CalendarProvider` queda con `CalDav`, y la columna `provider` y el campo `provider` del estado se mantienen.
- **Por qué:** se evita una migración de datos y un cambio de contrato. Además, si algún día vuelve otro proveedor (por ejemplo Microsoft Graph), el modelo ya está preparado.
- **Alternativa descartada:** quitar el campo y la columna. Se ahorra muy poco y obliga a cambiar el contrato dos veces.

`ICalendarProviderClient` se queda como está, con una única implementación. Quitar la indirección sería un refactor que no aporta nada a este change.

### 2. La API manda en el contrato; el front se adapta

El contrato del backend está cubierto por tests de integración y por la spec. Así que el front pasa a:
- leer el bloque del calendario de `GET /api/settings`;
- conectar con `PUT /api/settings/calendar/caldav` y `{ url, username, password }`;
- desconectar con `DELETE /api/settings/calendar`.

Las tres llamadas devuelven el mismo bloque, que queda como `{ connection: … | null }`. El modelo del front reproduce esa forma, de modo que la cuenta y la marca de reconexión se muestran sin campos inventados.
- **Alternativa descartada:** añadir en el back un `GET /api/settings/calendar` con la forma que espera el front. Eso dejaría dos contratos para lo mismo.

Para que no se repita el desajuste, los specs del front usan como fixtures respuestas con la forma exacta que devuelve la API.

### 3. Migración: borrar columnas y, por si acaso, filas de Google

La migración `RemoveGoogleCalendar`:
- borra `calendar_oauth_nonce` y `calendar_oauth_expires_at` de `users`;
- ejecuta `DELETE FROM calendar_connections WHERE provider = 'Google'`.

No hay ninguna fila de Google en producción, pero si existiera, EF no podría convertir `'Google'` al enum y fallaría al leer. Borrarla deja al usuario sin calendario, que es el mismo estado que tendría al desaparecer el proveedor. El `Down` vuelve a crear las columnas como nullable; las filas borradas no se recuperan, y no hace falta.

Unas credenciales guardadas con una forma que no sea CalDAV ya se tratan como inválidas y marcan reconexión. Ese camino se mantiene.

### 4. Qué desaparece del backend

- `GoogleCalendarClient` y su registro.
- `GoogleCalendarOptions`, `IGoogleCalendarAuthorization`, `GoogleOAuthState`, `GoogleCalendarCommands`.
- `CalendarController` completo, porque solo contenía el callback.
- La ruta `calendar/google/start` de `SettingsController`.
- `CalendarCredentials.Google` y `CalendarErrors.GoogleNotAvailable`.
- El inicio de conexión en `User`.
- `GoogleCalendarAvailable` de `CalendarSettingsResponse`.
- Las dependencias de `GetSettingsQuery` con `GoogleCalendarOptions`.
- Los tests y fakes de Google (`GoogleCalendarClientTests`, `GoogleCalendarConnectApiTests`, `ApiGoogleCalendarFake`, `UserCalendarOAuthTests`) y los casos de Google dentro de los tests compartidos.

## Risks / Trade-offs

- [Riesgo] Un despliegue con `GoogleCalendar__*` en su entorno → Las variables se ignoran sin error. Nunca llegaron a `docker-compose.yml`.
- [Riesgo] El front sigue sin probarse contra la API real → Fixtures con la forma exacta de la API, y una comprobación manual de punta a punta en la tarea final. El guard de red bloquea servidores CalDAV en direcciones privadas, así que la prueba manual necesita un servidor CalDAV público con HTTPS.
- [Trade-off] Quien quiera Google tiene que usar CalDAV de otro proveedor, porque Google CalDAV exige OAuth → Asumido. No hay usuarios afectados.

## Migration Plan

1. Desplegar el backend con la migración `RemoveGoogleCalendar`. Las conexiones CalDAV no se tocan.
2. Desplegar el frontend. Front y back van en la misma versión del despliegue (`develop → main`), así que no hay ventana con contratos cruzados que no exista ya.
3. Rollback: revertir ambas imágenes y aplicar el `Down` de la migración. CalDAV sigue funcionando en los dos sentidos.
