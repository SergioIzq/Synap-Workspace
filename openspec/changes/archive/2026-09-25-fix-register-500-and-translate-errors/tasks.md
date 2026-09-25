# Tasks

## 1. Fix 500 en registro (Npgsql timestamp)

- [x] 1.1 Añadir `AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true)` en `Program.cs` (después de los `using`, antes de `WebApplication.CreateBuilder`), y verificar que `POST /api/auth/register` con email y contraseña válidos devuelve 200 (no 500).

## 2. Traducir errores del backend

- [x] 2.1 En `Synap.Domain/Errors/UserErrors.cs`: traducir "This email is already registered." → "Este correo ya está registrado." y "Invalid email or password." → "Correo o contraseña incorrectos." Verificar que login con email inexistente devuelve el mensaje en español.

- [x] 2.2 En `Synap.Shared.Domain/ValueObjects/Email.cs`: traducir "Email cannot be empty." → "El email no puede estar vacío." y el mensaje de formato → "'{value}' no es una dirección de email válida." Verificar que `POST /api/auth/register` con email vacío o malformado devuelve el mensaje en español.

- [x] 2.3 En `Synap.Shared.Domain/ValueObjects/PasswordHash.cs`: traducir "The provided password hash is invalid or empty." → "El hash de contraseña no es válido."

- [x] 2.4 En `Synap.Api/Middleware/ExceptionHandlingMiddleware.cs`: traducir "An unexpected error occurred." → "Ha ocurrido un error inesperado."

- [x] 2.5 En `Synap.Api/Controllers/AuthController.cs` (líneas 44 y 58): traducir "Not authenticated." → "No autenticado."

- [x] 2.6 En `Synap.Api/Authentication/ApiTokenAuthenticationHandler.cs`: traducir "Invalid API token." → "Token de API inválido."

- [x] 2.7 En los handlers de notas (`UpdateNoteCommandHandler`, `DeleteNoteCommandHandler`, `AddTagCommandHandler`, `GetRelatedNotesQueryHandler`): traducir "Note not found." → "Nota no encontrada." y "Tag name cannot be empty." → "El nombre de la etiqueta no puede estar vacío."

- [x] 2.8 En `GenerateApiTokenCommandHandler` y `GetApiTokenStatusQueryHandler`: traducir "User not found." → "Usuario no encontrado."

## 3. Traducir fallbacks del frontend

- [x] 3.1 En `auth.store.ts`: traducir "Could not register." → "No se pudo crear la cuenta." y "Invalid email or password." → "Correo o contraseña incorrectos." Verificar que el registro fallido muestra el texto en español.

- [x] 3.2 En `notes.store.ts`: traducir los cuatro fallbacks ("Could not load notes.", "Could not create note.", "Could not update note.", "Could not delete note.", "Could not add tag.") a español.

- [x] 3.3 En `assistant.store.ts`: traducir "Could not reach the assistant." → "No se pudo contactar con el asistente."

## 4. Verificación end-to-end

- [x] 4.1 Reconstruir la imagen Docker del backend (`docker build -t synap-api:local ./Synap-Backend`) y verificar que el contenedor arranca sin errores.

- [x] 4.2 Ejecutar el flujo de registro completo: navegar a `/auth/register`, crear una cuenta con email y contraseña válidos, verificar que se muestra "¡Cuenta creada!" (no un error 500).

- [x] 4.3 Intentar registrar con el mismo email dos veces y verificar que el segundo intento muestra "Este correo ya está registrado." en español.

- [x] 4.4 Intentar registrar con email malformado y verificar que el error de validación aparece en español.
