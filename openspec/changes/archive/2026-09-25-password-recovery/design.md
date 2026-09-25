# Design

## Context

- **Contraseñas:** `PasswordPolicy` (8–128) ya existe y la usan registro y cambio de contraseña. `IPasswordHasher` del kernel.
- **Sesiones:** los JWT se emiten a través de `KernelJwtTokenGenerator.GenerateToken(userId, email)`, que no admite claims adicionales. El token actual solo lleva `sub`, `email`, `jti`, `nameidentifier`, `exp`, `iss` y `aud` (12 h). El `OnTokenValidated` de `Program.cs` ya comprueba en cada petición que el usuario existe, mediante `IUserExistenceCache` (1 min).
- **Token del Atajo de iOS:** es un token opaco con SHA-256 (`ApiTokenHasher`) y se autentica por otro esquema (`ApiToken`).
- **Trabajo en segundo plano:** existe una `BackgroundJobQueue` en proceso con `QueuedJobHostedService`.
- **Referencia:** Kash-Backend usa `AddKernelEmail` (cola en memoria + `EmailBackgroundSender` con MailKit) del paquete `SergioIzq.Infrastructure.Kernel`, token en claro en la tabla con 1 h de validez, y un enlace `…/auth/reset-password?token=…&email=…` construido con `BASE_URL`.

## Goals / Non-Goals

**Goals:**
- Recuperación de contraseña que no permita averiguar qué emails tienen cuenta, con tokens inútiles aunque alguien lea la BD.
- Que cambiar la contraseña (por cualquier vía) expulse al resto de sesiones.
- Ningún secreto de Brevo en el repositorio.

**Non-Goals:**
- Verificación del email al registrarse.
- Plantillas de email multi-idioma o editor de plantillas: un único HTML en español en el código.
- Invalidar el token del Atajo de iOS (se regenera a mano en Configuración si hace falta).
- Reintentos persistentes de envío: si Brevo falla, se registra el error y el usuario puede volver a pedir el enlace.

## Decisions

### 1. Token de recuperación: aleatorio, con hash y sin email en la URL
`User.StartPasswordReset(tokenHash, expiresAt)` guarda `password_reset_token_hash` (hex de SHA-256) y `password_reset_expires_at`. El token en claro (32 bytes aleatorios en base64url) solo aparece en el email. Se reutiliza `IApiTokenHasher.GenerateToken()`/`Hash()`: mismo formato y el mismo SHA-256.

- `ResetPassword` busca el usuario **por hash del token** (índice en la columna), comprueba la caducidad, aplica `PasswordPolicy`, cambia el hash de contraseña, borra el token y renueva el sello.
- Un token caducado se borra al detectarlo.
- Pedir otro token sobrescribe el anterior, así que solo vale el último.
- Mensaje único para inexistente, usado o caducado: "El enlace no es válido o ha caducado. Solicita uno nuevo."

*Alternativa descartada: guardar el token en claro, como Kash.* Una copia de la BD, un log o un backup filtrado permitiría tomar cualquier cuenta con una petición pendiente.

*Alternativa descartada: JWT firmado como token de reset.* No se puede invalidar tras usarlo sin guardar estado, y además es más largo en la URL.

### 2. `ForgotPassword` siempre responde 200 y con el mismo tiempo aproximado
- **Email desconocido:** `Result.Success()` sin hacer nada más.
- **Email conocido:** guarda el token y **encola** el envío, sin esperar a Brevo. La latencia es parecida en ambos casos y no delata la existencia de la cuenta.
- **Límite por email:** contador en `IMemoryCache` por email normalizado (máximo **3 por hora**). Por encima, se responde igual pero sin generar token ni enviar.
- **Límite por IP:** política `PasswordRecovery` (5 por hora, ventana deslizante), que devuelve 429 como login y registro. No revela nada sobre la cuenta.

### 3. Email: `IEmailSender` propio con MailKit, sin el paquete de infraestructura del kernel
- `IEmailSender.Enqueue(EmailMessage)` en Shared.Application.
- Implementación en Infrastructure: encola en la `BackgroundJobQueue` existente un trabajo que envía con `MailKit.Net.Smtp.SmtpClient` (STARTTLS en el puerto 587).
- `EmailSettings`: `SmtpServer`, `SmtpPort`, `EnableSsl`, `FromEmail`, `FromName`, `SmtpUser`, `SmtpPass`. Mismas claves que Kash, para poder copiar la configuración.
- Si falta `SmtpUser` o `SmtpPass`, el emisor **no rompe el arranque**: registra un warning una vez, y cada envío se registra como "email no enviado (SMTP sin configurar)". Así la app funciona en desarrollo sin credenciales.

*Alternativa descartada: `AddKernelEmail` de `SergioIzq.Infrastructure.Kernel` 0.2.9.* Arrastra Hangfire, Dapper y EF Core 9, y obliga a subir `SergioIzq.Application.Kernel` de la 0.2.6 a la 0.2.9 en toda la solución. Es mucho riesgo para unas 60 líneas.

### 4. Sello de seguridad en el JWT
- Nueva columna `security_stamp` (varchar(32), no nula). En la migración, las filas existentes reciben un valor aleatorio con `gen_random_uuid()`.
- `User.RotateSecurityStamp()` se llama al restablecer y al cambiar la contraseña.
- `JwtTokenGenerator` deja de delegar en el kernel y emite el token con `System.IdentityModel.Tokens.Jwt`, usando la misma sección `JwtSettings` (`SecretKey`, `Issuer`, `Audience`, `ExpirationMinutes`). Lleva los **mismos claims** (`sub`, `email`, `jti`, `nameidentifier`) más `stamp` e `iat`. Así el `AbsController.GetCurrentUserId()` y la validación del kernel (`AddKernelJwtAuthentication`) siguen funcionando sin cambios.
- `IUserExistenceCache` pasa a ser `IUserSessionCache`: `GetStampAsync(userId)` devuelve `null` si el usuario no existe. `OnTokenValidated` rechaza el token si falta el claim `stamp`, si el usuario no existe o si el sello no coincide. `Invalidate(userId)` se llama al borrar la cuenta, al restablecer y al cambiar la contraseña.
- `ChangePassword` pasa a devolver `{ token, expiresAt }` generado con el sello nuevo. El front lo guarda y la sesión actual sigue viva.

*Alternativa descartada: comparar `exp - ExpirationMinutes` con una fecha `password_changed_at`.* Funciona sin tocar el generador, pero depende de que la duración configurada no cambie nunca y no es explícito.

### 5. URL pública y rutas del front
- `App:PublicBaseUrl` (`PUBLIC_BASE_URL`; por defecto `http://localhost:4200` en Development) construye `{PublicBaseUrl}/auth/reset-password?token={token}`.
- Front:
  - `ForgotPasswordPage`: email, envío y mensaje fijo "Si existe una cuenta con ese email, te hemos enviado un enlace…".
  - `ResetPasswordPage`: lee `token` de la query, pide nueva contraseña y repetición con la misma validación de 8–128. Al terminar redirige a login con un toast.
  - Enlace "¿Olvidaste tu contraseña?" en el login.
- Ambas páginas son anónimas y usan el `AuthLayoutComponent`.

### 6. Secretos
- `appsettings.json` lleva `EmailSettings` con servidor, puerto, remitente y `SmtpUser`/`SmtpPass` **vacíos**.
- **Local:** `dotnet user-secrets set "EmailSettings:SmtpUser" …` en `Synap.Api`. El proyecto recibe un `UserSecretsId`.
- **Compose:** `EmailSettings__SmtpUser: ${EMAIL_SMTP_USER:-}`, `EmailSettings__SmtpPass: ${EMAIL_SMTP_PASS:-}` y `App__PublicBaseUrl: ${PUBLIC_BASE_URL:?…}`.
- `.env.example` lleva los nombres de variable sin valores.

## Risks / Trade-offs

- **[Todos los usuarios deben volver a iniciar sesión al desplegar]** → Los JWT antiguos no llevan `stamp`. Es un coste de una sola vez y lo aceptamos; se documenta en el runbook.
- **[El email cae en spam o no llega]** → Mitigación: remitente verificado en Brevo (`no-reply@sergioizq.com`, el mismo dominio que ya usa Kash), SPF/DKIM del dominio configurados en Brevo y texto plano alternativo junto al HTML.
- **[La cola en memoria pierde emails si la API se reinicia justo tras encolar]** → El usuario vuelve a pedir el enlace. No compensa la complejidad de una cola persistente.
- **[El límite por email vive en memoria]** → Se reinicia al reiniciar la API. Aceptable con una sola instancia.
- **[El token viaja en la URL y puede quedar en el historial o en logs del proxy]** → Es de un solo uso y caduca en 1 h; además se usa y se borra en el primer POST.

## Migration Plan

1. Migración `AddPasswordRecovery`: columnas nullable del token con índice en el hash, más `security_stamp` rellenado con valores aleatorios y luego NOT NULL.
2. En el VPS, añadir al `.env` `EMAIL_SMTP_USER`, `EMAIL_SMTP_PASS` y `PUBLIC_BASE_URL=https://synap.sergioizq.com`, y ejecutar `docker compose up -d --build`.
3. **Rollback**: volver a la imagen anterior. Las columnas nuevas se ignoran. Los tokens con `stamp` emitidos en ese intervalo siguen siendo válidos para la versión anterior, porque ignora el claim.
