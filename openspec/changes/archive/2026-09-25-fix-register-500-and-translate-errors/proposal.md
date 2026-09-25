# Proposal

## Why

El endpoint `POST /api/auth/register` lanza siempre un 500 porque `AbsEntity` inicializa `FechaCreacion` con `DateTime.Now` (`Kind=Local`), y Npgsql 6+ rechaza escribir `Kind=Local` en columnas `timestamp with time zone` sin el switch de compatibilidad. Además, todos los mensajes de error del backend y los fallbacks del frontend están en inglés, mientras la app está en español.

## What Changes

- Habilitar `Npgsql.EnableLegacyTimestampBehavior` en `Program.cs` para aceptar `DateTime.Kind=Local` en columnas `timestamptz` (comportamiento de Npgsql ≤5).
- Traducir al español todos los mensajes de error de dominio en el backend (`UserErrors`, `Email`, `PasswordHash`, handlers de notas/api-token, `AuthController`, `ApiTokenAuthenticationHandler`, `ExceptionHandlingMiddleware`).
- Traducir al español todos los mensajes de fallback en los stores del frontend (`auth.store`, `notes.store`, `assistant.store`).

## Capabilities

### New Capabilities
_(ninguna — este cambio no introduce nuevas capacidades)_

### Modified Capabilities
_(ninguna — la capacidad `identity` ya requiere que el registro funcione; este cambio lo hace funcionar sin modificar los requisitos. La traducción de errores es una decisión de implementación, no un cambio de requisito)_

> **Nota de skip_specs:** al no haber cambios en los requisitos observables, este change usa `skip_specs: true`.

## Impact

- `Synap-Backend/Synap.Api/Program.cs` — añadir `AppContext.SetSwitch` antes del builder.
- `Synap-Backend/Synap.Api/Middleware/ExceptionHandlingMiddleware.cs` — mensaje genérico en español.
- `Synap-Backend/Synap.Api/Controllers/AuthController.cs` — dos mensajes "Not authenticated."
- `Synap-Backend/Synap.Api/Authentication/ApiTokenAuthenticationHandler.cs` — mensaje "Invalid API token."
- `Synap-Backend/Synap.Domain/Errors/UserErrors.cs` — dos mensajes de error de usuario.
- `Synap-Backend/Synap.Shared.Domain/ValueObjects/Email.cs` — dos mensajes de validación.
- `Synap-Backend/Synap.Application/Features/Users/Commands/GenerateApiToken/GenerateApiTokenCommandHandler.cs`
- `Synap-Backend/Synap.Application/Features/Users/Queries/GetApiTokenStatusQueryHandler.cs`
- `Synap-Backend/Synap.Application/Features/Notes/Commands/Update/UpdateNoteCommandHandler.cs`
- `Synap-Backend/Synap.Application/Features/Notes/Commands/Delete/DeleteNoteCommandHandler.cs`
- `Synap-Backend/Synap.Application/Features/Notes/Commands/AddTag/AddTagCommandHandler.cs`
- `Synap-Backend/Synap.Application/Features/Notes/Queries/GetRelatedNotesQueryHandler.cs`
- `Synap-Frontend/src/app/core/stores/auth.store.ts`
- `Synap-Frontend/src/app/features/notes/store/notes.store.ts`
- `Synap-Frontend/src/app/features/assistant/store/assistant.store.ts`
