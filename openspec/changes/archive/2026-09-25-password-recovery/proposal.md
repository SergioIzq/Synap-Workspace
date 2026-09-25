# Proposal

## Why

Un usuario que olvida su contraseña no tiene forma de recuperar su cuenta: el cambio de contraseña solo existe estando logueado (Configuración > Cuenta) y no hay ningún canal de email. La única salida hoy es manipular la base de datos a mano. Además, cambiar la contraseña no cierra las sesiones abiertas en otros dispositivos, justo cuando más importa (sospecha de acceso ajeno).

## What Changes

- **"¿Olvidaste tu contraseña?"** en la pantalla de login, que lleva a `/auth/forgot-password`. El usuario introduce su email y, si existe una cuenta, recibe un enlace para restablecerla. La respuesta es siempre la misma, exista o no la cuenta.
- **Email transaccional con Brevo** (SMTP `smtp-relay.brevo.com:587`, remitente "Synap" `<no-reply@sergioizq.com>`), enviado en segundo plano para que la petición no espere al proveedor. Mismo enfoque que Kash-Backend, pero con un emisor propio basado en MailKit.
- **Pantalla `/auth/reset-password?token=…`** para elegir una contraseña nueva con la misma política que el registro (8–128 caracteres).
- **Token de recuperación seguro**:
  - Aleatorio, de un solo uso y caduca en 1 hora.
  - Solo se guarda su hash (SHA-256).
  - El enlace no incluye el email.
  - Pedir uno nuevo invalida el anterior.
- **Límites** en la solicitud de recuperación: por IP y por email, para que nadie pueda inundar un buzón.
- **Cerrar todas las sesiones al cambiar la contraseña**, tanto al restablecerla por email como al cambiarla estando logueado. Se añade un sello de seguridad por usuario que viaja en el JWT; si no coincide, la sesión deja de ser válida. La sesión desde la que se cambia la contraseña recibe un token nuevo. El token personal del Atajo de iOS no se ve afectado.
- **Secretos fuera del repositorio**: `EmailSettings.SmtpUser`/`SmtpPass` vacíos en `appsettings.json`. En local se configuran con `dotnet user-secrets` y en Docker/VPS con variables de entorno del `.env` (`EMAIL_SMTP_USER`, `EMAIL_SMTP_PASS`, `PUBLIC_BASE_URL`).

## Capabilities

### New Capabilities
<!-- Ninguna: todo es comportamiento de identidad. -->

### Modified Capabilities
- `identity`: se añaden la recuperación de contraseña por email y el cierre de sesiones al cambiar la contraseña. También se amplía el límite de intentos a las solicitudes de recuperación.

## Impact

- **Synap-Backend (.NET)**:
  - Columnas nuevas en `users`: `password_reset_token_hash`, `password_reset_expires_at`, `security_stamp` (migración EF).
  - Comandos `ForgotPassword` y `ResetPassword` y endpoints anónimos `POST /api/auth/forgot-password` y `POST /api/auth/reset-password`.
  - `ChangePassword` pasa a devolver un token nuevo.
  - Nuevo `IEmailSender` (MailKit) encolado en la `BackgroundJobQueue` existente.
  - Generación propia del JWT con claim de sello, en sustitución del adaptador sobre `KernelJwtTokenGenerator`.
  - `OnTokenValidated` compara el sello, usando la misma caché de 1 minuto.
  - Nuevas políticas de rate limit.
- **Synap-Frontend**:
  - Páginas `forgot-password` y `reset-password` en el layout de auth.
  - Enlace en el login.
  - Tras cambiar la contraseña, se guarda el token nuevo.
- **Orquestación**: `docker-compose.yml`, `.env.example` y el runbook incluyen las variables de email y la URL pública.
- **Dependencias**: `MailKit` (NuGet) en Infrastructure.
- **BREAKING (sesiones)**: al desplegar, las sesiones existentes, emitidas sin sello, dejan de valer y todos los usuarios tienen que volver a iniciar sesión una vez.
