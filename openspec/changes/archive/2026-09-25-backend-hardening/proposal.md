# Proposal

## Why

El backend cubre bien el MVP, pero le faltan garantías básicas de un servicio en producción con registro abierto:

- **Seguridad**: `login` y `register` no tienen límite de intentos, así que se puede hacer fuerza bruta sin freno.
- **Cuenta**: el usuario no puede cambiar su contraseña ni borrar su cuenta y sus datos, algo que exige el RGPD.
- **Búsqueda**: devuelve todas las notas de golpe, sin paginar. Además usa el diccionario `english` sobre contenido mayoritariamente en español, así que falla con plurales y acentos.
- **Operación**: `/health` no comprueba ni la base de datos ni el servicio de IA.

## What Changes

- **Perfil del usuario**: `GET /api/users/me` devuelve el email y la fecha de alta.
- **Cambio de contraseña**: exige la contraseña actual y valida la nueva con las mismas reglas que el registro.
- **Borrado de cuenta**:
  - Exige la contraseña.
  - Elimina de forma irreversible al usuario y todos sus datos (notas, etiquetas, embeddings, key de Groq y token personal).
- **Protección contra fuerza bruta**: límite de intentos por IP en `login` y `register`. Por encima del límite, la API responde 429 con un mensaje en español.
- **Búsqueda paginada** (**BREAKING** en la forma de respuesta de `GET /api/notes/search`): acepta `page` y `pageSize` (máximo 50) y devuelve `{ items, page, pageSize, totalCount }`.
- **Filtro por tipo de nota** en la búsqueda (`type=text|codeSnippet|bookmark`).
- **Nota individual y lista de etiquetas** (añadido al implementar): `GET /api/notes/{id}` y `GET /api/tags`. Con la búsqueda paginada, el detalle ya no puede buscar la nota entre las cargadas (fallaría con notas fuera de la primera página) y el filtro de etiquetas ya no puede deducirse de ellas.
- **Búsqueda en español**: índice de texto completo con una configuración adecuada a español y que ignora acentos, almacenado e indexado en lugar de calculado en cada consulta.
- **Health checks reales**: `/health` informa del estado de Postgres y del ai-service.
- **Frontend**:
  - Configuración > Cuenta incluye "Cambiar contraseña" y "Eliminar cuenta" (con confirmación escribiendo la contraseña).
  - La lista de notas usa scroll infinito con la búsqueda paginada y añade el filtro por tipo.

Depende de `byok-groq-and-settings` (sección Cuenta de la página de Configuración y columnas de la key de Groq, que el borrado de cuenta debe eliminar).

## Capabilities

### New Capabilities
- `platform-operations`: comportamiento operativo observable del servicio, es decir, informar de su salud y de la de sus dependencias.

### Modified Capabilities
- `identity`: se añaden perfil propio, cambio de contraseña, borrado de cuenta con eliminación de todos los datos, y límite de intentos en autenticación y registro.
- `knowledge-vault`: la búsqueda de texto completo pasa a ser paginada, admite filtro por tipo y trata correctamente el español (acentos y variantes).

## Impact

- **Synap-Backend (.NET)**:
  - Features nuevas en `Features/Users` (`GetCurrentUser`, `ChangePassword`, `DeleteAccount`) y un `UsersController` nuevo.
  - Políticas de rate limit por IP y `ForwardedHeaders` para obtener la IP real detrás del proxy.
  - Cambios en la firma de `SearchNotesQuery` y `NoteReadRepository`.
  - Migración con columna `search_vector` generada, índice GIN y extensión `unaccent`.
  - Health checks de Npgsql y del ai-service.
- **Synap-Backend (ai-service)**: nada. Su `/health` ya existe y .NET lo consulta.
- **Synap-Frontend**: `NoteService`, `NotesStore` y `notes-list.page.ts` (scroll infinito y filtro por tipo), y la sección Cuenta de `SettingsPage`.
- **Dependencias nuevas**: `AspNetCore.HealthChecks.NpgSql` (NuGet) para el check de Postgres.
- **Clientes**: el Atajo de iOS solo usa `quick-capture` y no le afecta el cambio de la respuesta de búsqueda.
