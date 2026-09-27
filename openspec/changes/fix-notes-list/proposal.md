# Proposal

## Why

El listado de notas no deja paginar de forma visible: el backend ya devuelve páginas (`page`, `pageSize`, `totalCount`), pero el frontend las encadena con scroll infinito y el botón "Cargar más" solo aparece en casos concretos, así que el usuario no ve controles ni sabe en qué página está. Además se ha reportado que, con más de 3 notas, las de abajo se pintan cortadas o desaparecen.

Por otro lado, el stack local de `docker compose` está roto para el frontend: su nginx no redirige `/api` a la API y responde `index.html` con 200, así que el login falla con "Correo o contraseña incorrectos" y el listado muestra el error técnico `Unexpected token '<', "<!doctype "... is not valid JSON`.

## What Changes

- **Paginador visible** en el listado de notas, en lugar del scroll infinito:
  - botones de primera, anterior, números de página, siguiente y última;
  - selector de tamaño de página (10 / 20 / 50);
  - texto "Mostrando 21–40 de 134";
  - la página, el tamaño y los filtros (texto, etiqueta, tipo) se reflejan en la URL, así que "Atrás", recargar o compartir el enlace devuelven al mismo resultado;
  - cambiar un filtro vuelve a la página 1;
  - al cambiar de página se sube al inicio del listado.
- **BREAKING (solo UI)**: se elimina el scroll infinito y el botón "Cargar más".
- **Arreglo de las tarjetas que se cortan o desaparecen**: primero se reproduce en el entorno donde se ve (el primer intento en Chrome headless no lo reprodujo) y luego se corrige la causa. La sospecha principal es la animación escalonada de la lista con `@angular/animations`, que es una API obsoleta.
- **Proxy `/api` en el nginx del frontend**, activado por configuración de entorno: en `docker compose` las peticiones a `/api` llegan a `synap-api`. En producción no cambia nada mientras no se configure.
- **Respuestas que no son de la API**: si el frontend recibe HTML u otro contenido no JSON donde esperaba la API, muestra un error en español ("No se pudo contactar con el servidor") en lugar del mensaje técnico del parser.

## Capabilities

### New Capabilities

_Ninguna._

### Modified Capabilities

- `web-experience`:
  - nuevo requisito de listado paginado con controles de página y filtros en la URL;
  - nuevo requisito de que todas las notas de la página se muestran completas;
  - "Operation feedback" cubre también las respuestas que no provienen de la API.
- `platform-operations`: nuevo requisito de que, en el stack autoalojado con `docker compose`, la app web y la API se sirven desde el mismo origen.

## Impact

- **Synap-Frontend**:
  - `notes-list.page.ts` (paginador; se quitan el `IntersectionObserver` y la `listAnimation`);
  - `notes.store.ts` (pasa de acumular páginas a sustituir la página actual, y deja de tener `loadMore`);
  - `error.interceptor.ts` y `http-errors.ts` (detección de respuestas no JSON);
  - `nginx.conf` pasa a ser una plantilla con proxy opcional;
  - `Dockerfile`.
- **Synap-Workspace**: `docker-compose.yml` (variable de entorno del upstream de la API para `synap-frontend`) y README.
- **Backend**: sin cambios. `GET /api/notes` ya acepta `page` y `pageSize` (máximo 50) y devuelve `totalCount`.
