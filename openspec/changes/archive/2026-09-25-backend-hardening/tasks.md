# Tasks

## 1. Identidad: perfil y contraseña

- [x] 1.1 Extraer las reglas de contraseña del registro a un validador reutilizable. Verificar que los tests de registro siguen pasando.
- [x] 1.2 Crear la query `GetCurrentUser` y `UsersController` con `GET /api/users/me`. Verificar con un test de integración que devuelve solo el email y la fecha de alta del usuario autenticado.
- [x] 1.3 Crear el comando `ChangePassword`, que valida la contraseña actual y la nueva, y el endpoint `PUT /api/users/me/password`. Verificar con tests: éxito (el login solo funciona con la nueva), contraseña actual incorrecta y contraseña nueva inválida.

## 2. Identidad: borrado de cuenta

- [x] 2.1 Crear el comando `DeleteAccount`, que verifica la contraseña y borra notas, etiquetas y usuario en una transacción, y el endpoint `DELETE /api/users/me`. Verificar con un test de integración contra Postgres que no quedan filas en `notes`, `tags`, `note_tags`, `note_embeddings` ni `users` para ese usuario, y que los datos de otro usuario siguen intactos.
- [x] 2.2 Añadir `OnTokenValidated`, que rechaza un JWT cuyo usuario no existe, con caché de 1 minuto invalidada al borrar. Verificar con un test de integración que tras borrar la cuenta el JWT anterior recibe 401 y el token personal también.
- [x] 2.3 Verificar con un test que el email de una cuenta borrada puede volver a registrarse.

## 3. Rate limit de autenticación

- [x] 3.1 Configurar `UseForwardedHeaders` con `KnownProxies` configurables. Verificar con un test que la IP de `X-Forwarded-For` solo se usa si viene de un proxy conocido.
- [x] 3.2 Crear las políticas `Auth` (login, 10 por minuto por IP) y `Register` (5 por hora por IP), con `OnRejected` devolviendo el mensaje en español, y aplicarlas en `AuthController`. Verificar con un test que el intento 11 dentro de un minuto recibe 429 con el mensaje.

## 4. Búsqueda

- [x] 4.1 Crear la migración `AddNoteSearchVector` (extensión `unaccent`, configuración `spanish_unaccent`, función inmutable, columna generada `search_vector` e índice GIN, con su `Down`). Verificar que se aplica y revierte limpia en una base de datos local.
- [x] 4.2 Reescribir `NoteReadRepository.SearchAsync` con `search_vector`, `websearch_to_tsquery`, filtro por tipo, `LIMIT/OFFSET` y `COUNT(*) OVER()`. Verificar con un test de integración que "configuracion" encuentra "configuración" y "notas" encuentra "nota".
- [x] 4.3 Crear `PagedResult<T>` y ampliar `SearchNotesQuery` y el endpoint con `type`, `page` y `pageSize` validados (`pageSize` como máximo 50). Verificar con tests de validación y de paginación (total, última página y página vacía).
- [x] 4.4 Actualizar `NoteIsolationTests` para la nueva firma. Verificar que siguen pasando.
- [x] 4.5 Crear `GET /api/notes/{id}` (query `GetNoteById`, solo notas propias; ajenas o inexistentes dan 404). Verificar con un test de integración de aislamiento.
- [x] 4.6 Crear `GET /api/tags` (etiquetas propias, ordenadas). Verificar con un test de integración de aislamiento.

## 5. Health checks

- [x] 5.1 Añadir el paquete `AspNetCore.HealthChecks.NpgSql`, el check `database` y el check propio `AiServiceHealthCheck` (Degraded, timeout de 3 s), con un writer JSON sin detalles de excepción. Verificar con `curl /health` con todo arriba, con el ai-service parado (Degraded) y con Postgres parado (Unhealthy).

## 6. Frontend

- [x] 6.1 Actualizar `NoteService.search` y los modelos a `PagedResult` con `type`, `page` y `pageSize`. Verificar con un test del servicio.
- [x] 6.2 Añadir a `NotesStore` la paginación (`loadMore`, `hasMore`, reinicio al cambiar filtros) y la carga de etiquetas desde `GET /api/tags`; que el detalle cargue la nota con `GET /api/notes/{id}` si no está en la lista. Verificar con tests del store y abriendo una nota fuera de la primera página.
- [x] 6.3 Añadir a `notes-list.page.ts` el scroll infinito con `IntersectionObserver`, el botón "Cargar más" y el filtro por tipo con `p-selectbutton`. Verificar a mano con más de 20 notas.
- [x] 6.4 Añadir en Configuración > Cuenta el formulario de cambio de contraseña, con toast de éxito y error en línea. Verificar a mano.
- [x] 6.5 Añadir en Configuración > Cuenta la zona de peligro "Eliminar cuenta", con un diálogo que pide la contraseña y que después cierra la sesión y redirige. Verificar a mano con un usuario de prueba.

## 7. Documentación y verificación

- [x] 7.1 Documentar en `docs/deployment-runbook.md` la variable `ForwardedHeaders__KnownProxies`, la migración de búsqueda y los permisos de extensión. Verificar por revisión.
- [x] 7.2 Hacer una pasada end-to-end con `docker compose up --build`: buscar con acentos, paginar, filtrar por tipo, cambiar la contraseña, provocar un 429 en login, borrar la cuenta y consultar `/health`. Verificar que `dotnet test` y los tests del front pasan.
