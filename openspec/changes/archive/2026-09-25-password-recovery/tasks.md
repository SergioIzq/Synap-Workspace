# Tasks

## 1. Dominio y persistencia

- [x] 1.1 Añadir a `User` `PasswordResetTokenHash`, `PasswordResetExpiresAt` y `SecurityStamp`, con los métodos `StartPasswordReset(hash, expiresAt)`, `CompletePasswordReset(newHash)` (valida la caducidad, borra el token y rota el sello) y `RotateSecurityStamp()`. `ChangePassword` también rota el sello. Verificar con tests unitarios de dominio: caducado, reutilizado y rotación.
- [x] 1.2 Crear la migración `AddPasswordRecovery` (columnas del token nullable con índice en el hash; `security_stamp` rellenado con aleatorio y después NOT NULL). Verificar que se aplica y revierte limpia en un Postgres desechable y que las filas existentes quedan con sello.

## 2. JWT con sello de seguridad

- [x] 2.1 Reescribir `JwtTokenGenerator` con `System.IdentityModel.Tokens.Jwt` sobre `JwtSettings`, con los mismos claims que el kernel más `stamp` e `iat`. Verificar con un test que el token lo acepta el esquema JWT existente y que `GetCurrentUserId()` sigue funcionando (login y `GET /api/users/me` en un test de API).
- [x] 2.2 Sustituir `IUserExistenceCache` por `IUserSessionCache` (`GetStampAsync`, `Invalidate`) y hacer que `OnTokenValidated` rechace un sello ausente o distinto. Verificar con tests de API: el token de antes del cambio da 401 y el token de iOS sigue funcionando.
- [x] 2.3 Hacer que `ChangePassword` devuelva un token nuevo e invalide la caché. Verificar con un test de API que el token antiguo da 401 y el devuelto funciona.

## 3. Email

- [x] 3.1 Crear `EmailSettings`, `IEmailSender.Enqueue(EmailMessage)` y su implementación con MailKit sobre la `BackgroundJobQueue`, sin romper el arranque si faltan credenciales. Verificar con un test unitario usando un servidor SMTP falso o un `ISmtpClient` sustituible, y con un log de "SMTP sin configurar".
- [x] 3.2 Añadir `EmailSettings` a `appsettings.json` con usuario y contraseña vacíos, `UserSecretsId` en `Synap.Api` y las variables en compose y `.env.example`. Verificar que `git grep -i xsmtpsib` no devuelve nada y que `docker compose config` resuelve.

## 4. Casos de uso y API

- [x] 4.1 Crear el comando `ForgotPassword`: 200 siempre, límite de 3 por email y hora en memoria, token con `IApiTokenHasher` válido 1 h y email HTML y texto en español con el enlace `{PublicBaseUrl}/auth/reset-password?token=…`. Verificar con tests unitarios: email desconocido no envía, email conocido encola uno y el cuarto en una hora no envía.
- [x] 4.2 Crear el comando `ResetPassword`: busca por hash, comprueba caducidad y `PasswordPolicy`, cambia la contraseña, borra el token, rota el sello e invalida la caché. Da un error único para inexistente, usado o caducado. Verificar con tests de API: éxito (login solo con la nueva), reutilización, caducado, contraseña inválida (el token sigue vivo) y que un token antiguo deja de valer al pedir otro.
- [x] 4.3 Crear los endpoints anónimos `POST /api/auth/forgot-password` y `POST /api/auth/reset-password`, con la política `PasswordRecovery` (5 por hora por IP) en el primero. Verificar con un test de API que la sexta petición de una IP recibe 429.
- [x] 4.4 Añadir un test de integración de extremo a extremo con un `IEmailSender` falso que captura el enlace: forgot, reset y login con la nueva contraseña, y la sesión anterior da 401.

## 5. Frontend

- [x] 5.1 Añadir `forgotPassword(email)` y `resetPassword(token, password)` a `AuthService`, y en `AuthStore` hacer que `changePassword` guarde el token devuelto. Verificar con tests de servicio y de store.
- [x] 5.2 Crear `ForgotPasswordPage` (`/auth/forgot-password`) con mensaje fijo tras enviar, y el enlace "¿Olvidaste tu contraseña?" en el login. Verificar a mano que muestra el mismo mensaje para un email existente y uno inexistente.
- [x] 5.3 Crear `ResetPasswordPage` (`/auth/reset-password?token=`): nueva contraseña y repetición (8–128), error si el enlace no es válido y redirección al login con toast al terminar. Verificar a mano con un enlace real y con uno usado.
- [x] 5.4 Hacer que Configuración > Cuenta guarde el token nuevo tras cambiar la contraseña y siga dentro. Verificar a mano que otra sesión abierta en otro navegador queda fuera.

## 6. Documentación y verificación

- [x] 6.1 Documentar en el runbook las variables de email, `PUBLIC_BASE_URL`, cómo configurar user-secrets en local y el aviso de que todos deben volver a iniciar sesión tras el despliegue. Verificar por revisión.
- [x] 6.2 Enviar un email real con Brevo en local (user-secrets) a una cuenta propia y completar el flujo desde el enlace del correo. Verificar que llega de "Synap" `<no-reply@sergioizq.com>`, que no cae en spam y que `dotnet test` y los tests del front pasan.
