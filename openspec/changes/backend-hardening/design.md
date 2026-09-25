# Design

## Context

- **Autenticación**:
  - JWT de sesión con 720 minutos de validez, emitido por el kernel (`AddKernelJwtAuthentication`), más un token personal que resuelve `ApiTokenAuthenticationHandler` buscando por hash.
  - El `SmartBearer` elige entre ambos.
  - El rate limiting existente (`AiHeavy`) particiona por el claim `sub`.
- **Datos del usuario**:
  - `notes` y `tags` tienen `user_id` pero **no tienen FK a `users`**. `note_tags` y `note_embeddings` cuelgan de `notes` con `ON DELETE CASCADE`.
- **Búsqueda**:
  - Dapper con `to_tsvector('english', …)` calculado en cada consulta y sin índice.
- **Infraestructura**:
  - La API corre detrás de un proxy inverso en el VPS, así que `RemoteIpAddress` es la IP del proxy salvo que se procesen las cabeceras `X-Forwarded-*`.

## Goals / Non-Goals

**Goals:**
- Que borrar una cuenta no deje datos huérfanos y que un JWT de una cuenta borrada deje de ser útil.
- Que la búsqueda escale con un índice y funcione bien en español.

**Non-Goals:**
- Refresh tokens y revocación de sesiones al cambiar la contraseña. Las demás sesiones siguen válidas hasta que caduquen (12 h); ver Riesgos.
- Recuperación de contraseña por email, que necesitaría un servicio de correo.
- Verificación de email en el registro.

## Decisiones

### 1. Controlador `api/users/me`
`GET /api/users/me`, `PUT /api/users/me/password` `{ currentPassword, newPassword }` y `DELETE /api/users/me` `{ password }` (body en DELETE, aceptado por ASP.NET Core y por `HttpClient` de Angular con `options.body`).

La contraseña se valida con el mismo validador que `RegisterUserCommand`, extraído a una regla reutilizable. Una contraseña actual incorrecta devuelve `Error.Validation("La contraseña actual no es correcta.")`, no 401, para que el `errorInterceptor` no cierre la sesión.

`GET /api/users/me` es independiente de `GET /api/settings` (cambio 1). El perfil es identidad; los settings son preferencias. El front puede seguir usando `settings.email` en la página de Configuración.

*Alternativa descartada: meter estas rutas en `AuthController`.* Mezclaría la emisión de credenciales con la gestión de la cuenta.

### 2. Borrado de cuenta en una transacción explícita
`DeleteAccountCommandHandler`, dentro del `UnitOfWork`, ejecuta `DELETE FROM notes WHERE user_id = @id` (en cascada caen `note_tags` y `note_embeddings`), después `DELETE FROM tags WHERE user_id = @id` y por último borra el `User` (con él, la key de Groq y el hash del token personal). Todo en una transacción.

Para que un JWT de una cuenta borrada no pueda seguir creando notas huérfanas (no hay FK), se añade un `OnTokenValidated` en el JwtBearer que comprueba que el usuario existe. La comprobación se cachea con `IMemoryCache` durante 1 minuto por `sub`, y el borrado invalida esa entrada.

*Alternativa descartada: añadir FKs `notes.user_id → users.id ON DELETE CASCADE`.* Es la solución más limpia a largo plazo, pero exige limpiar primero posibles huérfanos en producción y cambia el comportamiento de escritura. Se deja como pregunta abierta, porque no cambia el spec.

### 3. Rate limit por IP para autenticación
- Nueva política `Auth`: ventana deslizante particionada por `RemoteIpAddress`.
  - `login`: 10 intentos por minuto.
  - `register`: 5 por hora, con una política `Register` separada.
- `app.UseForwardedHeaders()` con `ForwardedHeaders.XForwardedFor | XForwardedProto` y `KnownProxies`/`KnownNetworks` configurables (`ForwardedHeaders:KnownProxies`), porque confiar en cualquier `X-Forwarded-For` permitiría esquivar el límite.
- La respuesta 429 incluye un `Result.Failure` con el mensaje "Demasiados intentos. Espera un momento y vuelve a intentarlo." (a través de `OnRejected`).

### 4. Búsqueda: columna generada `search_vector`, configuración `spanish_unaccent` e índice GIN
Migración con SQL crudo, igual que se hizo con `note_embeddings`:
1. `CREATE EXTENSION IF NOT EXISTS unaccent;`
2. Configuración de texto `spanish_unaccent`, copia de `spanish` con `unaccent` en el mapeo de palabras.
3. Función `IMMUTABLE` que envuelve `to_tsvector('spanish_unaccent', …)`. Hace falta porque las columnas generadas exigen funciones inmutables y `unaccent` no lo es.
4. `ALTER TABLE notes ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (…) STORED;` más `CREATE INDEX … USING GIN (search_vector)`.

La consulta usa `websearch_to_tsquery('spanish_unaccent', @q)`, que además admite comillas y `-exclusión`, y ordena por `ts_rank(search_vector, q)`.

*Alternativa descartada: la configuración `simple`.* No tiene stemming ("notas" no encuentra "nota").

### 5. Paginación por offset
`SearchNotesQuery(SearchTerm, Tag, Type, Page = 1, PageSize = 20)`. `PageSize` se limita a `[1, 50]` y `Page` debe ser `>= 1`, con validación de FluentValidation o la del kernel. `COUNT(*) OVER()` en la misma consulta da el `totalCount` sin una segunda ida a la base de datos. La respuesta es `PagedResult<NoteSearchResult>` `{ items, page, pageSize, totalCount }`.

*Alternativa descartada: paginación keyset.* El orden por relevancia no produce un cursor estable, y con volúmenes personales el coste del offset es irrelevante.

### 6. Health checks
- `AddHealthChecks()`:
  - `.AddNpgSql(connectionString, name: "database", failureStatus: Unhealthy)`.
  - Un check propio `AiServiceHealthCheck` que llama al `/health` del ai-service con un timeout de 3 s y `failureStatus: Degraded`.
- `MapHealthChecks("/health")` con un `ResponseWriter` JSON mínimo: `{ status, checks: { database, aiService } }`, sin mensajes de excepción.

### 7. Frontend
- `NoteService.search` recibe `page`, `pageSize` y `type`.
- `NotesStore` gestiona `items`, `page`, `totalCount` y `hasMore`, más `loadMore()`. Una nueva búsqueda reinicia a la página 1.
- Scroll infinito con `IntersectionObserver` sobre un centinela al final de la lista, más un botón "Cargar más" como alternativa accesible.
- Filtro por tipo con `p-selectbutton` (Todas / Texto / Código / Enlaces).
- Configuración > Cuenta:
  - Formulario de cambio de contraseña (actual, nueva y repetición).
  - Zona de peligro con "Eliminar cuenta": `p-dialog` que pide escribir la contraseña. Tras borrar, cierra la sesión y redirige a `/auth/login` con un toast.

## Risks / Trade-offs

- **[Las sesiones siguen activas tras cambiar la contraseña]** → Una sesión robada sobrevive hasta 12 h. Se acepta por ahora; la solución, un `security_stamp` en el JWT, queda fuera de alcance. Se documenta.
- **[Consulta extra por petición para validar que el usuario existe]** → Mitigación: caché de 1 minuto. En el peor caso, una cuenta recién borrada puede seguir haciendo peticiones durante ese minuto desde otra instancia; hoy solo hay una.
- **[Proxies mal configurados en `KnownProxies`]** → Todos los clientes compartirían la IP del proxy y se bloquearían entre sí. Mitigación: documentarlo en el runbook y comprobar en el despliegue que `RemoteIpAddress` es la IP real.
- **[Cambio de forma en la respuesta de búsqueda]** → El frontend se despliega a la vez. Durante unos segundos, un frontend antiguo en caché del service worker puede fallar al listar. Mitigación: desplegar primero el frontend compatible con ambas formas (detecta `items`), o aceptar el breve corte.
- **[La migración de la columna generada reescribe la tabla `notes`]** → Con el volumen actual tarda segundos; se ejecuta en el arranque, como las demás.

## Migration Plan

1. Desplegar el backend. `Migrate()` al arrancar crea la extensión, la configuración, la columna y el índice. El usuario de Postgres necesita permiso para `CREATE EXTENSION`; con la imagen `pgvector` y el usuario propietario ya lo tiene, porque se hizo lo mismo con `vector`.
2. Configurar `ForwardedHeaders__KnownProxies` en el `.env` del VPS.
3. Desplegar el frontend.
4. **Rollback**: la migración `Down` elimina el índice, la columna, la función y la configuración. Revertir las imágenes.

## Open Questions

- ¿Añadir más adelante FKs de `notes`/`tags` a `users` con cascada, tras una limpieza de huérfanos? No cambia el spec ni este diseño.
- Ajustar los límites de `login` y `register` con datos reales de uso.
