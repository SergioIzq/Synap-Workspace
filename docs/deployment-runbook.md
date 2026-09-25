# Desplegar Synap en el VPS (tarea 5.4)

Esto es lo que **tú** tienes que ejecutar contra tu VPS real (3 vCPU / 8 GB, sin GPU, ya sirviendo
otras webs — ver `openspec/changes/synap-mvp/design.md`). No pude hacerlo desde este entorno de
desarrollo: no hay Docker ni acceso a tu VPS aquí. Esto es el paso a paso exacto, no una promesa
de que ya está desplegado.

## 0. Antes de empezar

- [ ] Docker y Docker Compose instalados en el VPS.
- [ ] DNS de `synap.sergioizq.com` (o el subdominio que uses) apuntando al VPS.
- [ ] Revisa cuánta RAM/CPU están usando ya tus otras webs — el objetivo es confirmar que queda
      margen real antes de sumar Postgres + la API + el servicio de IA + el frontend.

## 1. Clonar los tres repos

```bash
git clone https://github.com/SergioIzq/Synap-Workspace.git synap
cd synap
git clone https://github.com/SergioIzq/Synap-Backend.git
git clone https://github.com/SergioIzq/Synap-Frontend.git
```

## 2. Configurar secretos

```bash
cp .env.example .env
```

Rellena en `.env`:
- `POSTGRES_PASSWORD` — contraseña nueva, no la de desarrollo local.
- `JWT_SECRET_KEY` y `INTERNAL_API_KEY` — genera cada una con `openssl rand -base64 48`. Son
  secretos distintos entre sí y distintos de cualquier valor usado en local. `JWT_SECRET_KEY`
  debe tener al menos 32 caracteres: si no, la API no arranca y lo indica en el log.
- `SECRETS_ENCRYPTION_KEY` — clave maestra que cifra (AES-256-GCM) la API key de Groq de cada
  usuario. Genérala con `openssl rand -base64 32` (tienen que ser exactamente 32 bytes). **Haz
  copia de seguridad**: si se pierde, todas las keys guardadas quedan ilegibles y cada usuario
  tendrá que volver a introducir la suya. Sin ella la API no arranca.
- `GROQ_MODEL` — solo el modelo **por defecto** para usuarios que no hayan elegido uno. Ya no
  existe una `GROQ_API_KEY` del servidor: cada usuario configura su propia key en
  Configuración > Asistente IA, así que el asistente no te cuesta nada.

**Nunca comitees `.env`** (ya está en `.gitignore`).

## 3. Ajustar CORS al dominio real

`Synap-Backend/Synap.Api/Program.cs` tiene `builder.Services.AddKernelCors("synap.sergioizq.com")`
como placeholder — cámbialo por tu dominio real si es distinto, o el frontend no podrá llamar a
la API desde el navegador.

## 4. Levantar el stack

```bash
docker compose up --build -d
```

Verifica que arrancan los cuatro servicios:

```bash
docker compose ps
docker compose logs -f synap-api synap-ai
```

## 5. Aplicar las migraciones de base de datos

Las migraciones se generaron aquí pero **nunca se aplicaron** contra una Postgres real — hazlo
ahora, una vez el contenedor de `postgres` esté sano:

```bash
docker compose exec synap-api dotnet ef database update \
  --project /app  # ajusta si tu imagen publica los assemblies en otra ruta
```

Si la imagen de producción no incluye las herramientas de EF Core (probable, ya que
`Dockerfile` publica solo el runtime), aplica las migraciones desde tu máquina apuntando a la
Postgres del VPS (por ejemplo, abriendo un túnel SSH temporal al puerto 5432, o ejecutando
`dotnet ef database update` desde un contenedor efímero con el SDK que sí tenga red hacia el
`postgres` del VPS). El objetivo es simplemente que las tablas `users`, `notes`, `tags`,
`note_tags` y `note_embeddings` (con la extensión `vector`) existan antes del primer registro.

## 6. Comprobar recursos bajo carga ligera

Con el stack arriba y sin usuarios reales todavía:

```bash
docker stats
```

Confirma que, sumado a tus otras webs, sigues con margen — especialmente al generar unos
cuantos embeddings de prueba (`fastembed` carga el modelo ONNX en memoria una vez al arrancar
`synap-ai`, así que el pico de RAM de ese contenedor debería estabilizarse pronto tras el
arranque, no crecer sin límite).

## 7. Reverse proxy / TLS

Si ya tienes nginx (u otro) delante de tus webs actuales, añade un `server` para
`synap.sergioizq.com` → `synap-frontend` (puerto 4200 del host) y, si expones la API en un
subdominio propio, otro para la API → `synap-api` (puerto 8080 del host). `postgres` y
`synap-ai` deliberadamente no tienen puertos publicados en `docker-compose.yml` — no deben ser
alcanzables desde fuera del propio stack.

## 8. Migrar a "cada usuario con su propia key de Groq" (byok-groq-and-settings)

Si el servidor ya estaba desplegado con la antigua `GROQ_API_KEY` global:

1. Genera la clave maestra y añádela al `.env`: `echo "SECRETS_ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env`.
   Guárdala también fuera del servidor (gestor de contraseñas).
2. Borra `GROQ_API_KEY` del `.env` — ya no se lee en ningún sitio.
3. `docker compose up -d --build`. La migración `AddUserGroqSettings` solo añade columnas
   nullable a `users`, sin pérdida de datos.
4. A partir de aquí, los usuarios ven un aviso en el asistente hasta que guarden su propia key
   (se obtiene en https://console.groq.com/keys).

**Rollback**: vuelve a las imágenes anteriores y restaura `GROQ_API_KEY` en el `.env`. Las
columnas nuevas son nullable y la versión anterior simplemente las ignora.

## 9. Endurecimiento del backend (backend-hardening)

**IP real detrás del proxy.** Login y registro tienen límite de intentos por IP (10 logins por
minuto y 5 registros por hora). Detrás de nginx, la API ve la IP del proxy salvo que confíe en su
`X-Forwarded-For`, y solo confía en las direcciones de `ForwardedHeaders__KnownProxies`
(separadas por comas).

- Si nginx corre en el host y llega a la API por el puerto publicado, la IP que ve la API es la
  de la puerta de enlace de la red de Docker. Averíguala con
  `docker network inspect synap-workspace_default -f '{{(index .IPAM.Config 0).Gateway}}'` y
  ponla en el `.env`:

  ```
  FORWARDED_KNOWN_PROXIES=172.18.0.1
  ```

  y en `docker-compose.yml` (servicio `synap-api`): `ForwardedHeaders__KnownProxies: ${FORWARDED_KNOWN_PROXIES:-}`.
- nginx debe enviar la cabecera: `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`.
- **Comprobación tras desplegar**: haz 11 intentos de login fallidos desde tu navegador. El
  undécimo debe dar "Demasiados intentos". Si al hacerlo también se bloquea a otra persona desde
  otra red, la IP del proxy no está bien configurada (todos comparten la misma).
- **No pongas** direcciones que no sean tu proxy: cualquier cliente que llegue desde ellas podría
  elegir su propia IP con `X-Forwarded-For` y saltarse el límite.

**Migración de búsqueda (`AddNoteSearchVector`).** Se aplica sola al arrancar la API y:

- instala la extensión `unaccent` (`CREATE EXTENSION`). El usuario de Postgres del compose es el
  propietario de la base de datos, así que tiene permiso, igual que con `vector`. Si usas otro
  usuario, un superusuario debe ejecutar antes `CREATE EXTENSION unaccent;`;
- crea la configuración de texto `spanish_unaccent` y la columna generada `notes.search_vector`
  con índice GIN. Reescribe la tabla `notes`, lo que con el volumen actual lleva segundos.

Rollback: `dotnet ef database update AddUserGroqSettings` deshace la columna, el índice, la
función y la configuración (deja instalada la extensión `unaccent`, que es inofensiva).

**Health checks.** `GET /health` (anónimo) devuelve
`{ "status": "Healthy|Degraded|Unhealthy", "checks": { "database": ..., "aiService": ... } }`:
Healthy/Degraded con 200 y Unhealthy (Postgres caído) con 503. Con el servicio de IA caído el
estado es Degraded, porque las notas siguen funcionando. Sirve para el monitor de disponibilidad.

**Cambio de contrato.** `GET /api/notes/search` ahora está paginado y devuelve
`{ items, page, pageSize, totalCount }`. El frontend de esta misma versión ya lo usa; despliega
los dos juntos.

## 10. Recuperación de contraseña por email (password-recovery)

La API envía los emails de "¿Olvidaste tu contraseña?" con Brevo (`smtp-relay.brevo.com:587`,
remitente "Synap" `<no-reply@sergioizq.com>`, que debe estar verificado en Brevo como remitente).
**Las credenciales nunca van en el repo**: `appsettings.json` las tiene vacías.

**VPS** — añade al `.env` (y comprueba que sigue en `chmod 600`):

```
PUBLIC_BASE_URL=https://synap.sergioizq.com
EMAIL_SMTP_USER=<usuario SMTP de Brevo, p. ej. xxxx@smtp-brevo.com>
EMAIL_SMTP_PASS=<clave SMTP de Brevo, empieza por xsmtpsib->
```

`PUBLIC_BASE_URL` es obligatoria (sin barra final): con ella se construye el enlace del email.
Sin `EMAIL_SMTP_*` la API arranca igual, pero no envía nada (se registra un aviso por cada email).

```bash
docker compose up -d --build
docker compose exec synap-api printenv App__PublicBaseUrl
```

**Local (`dotnet run`)** — las credenciales van en user-secrets, fuera del repo:

```bash
cd Synap-Backend
dotnet user-secrets set "EmailSettings:SmtpUser" "<usuario>" --project Synap.Api
dotnet user-secrets set "EmailSettings:SmtpPass" "<clave>" --project Synap.Api
```

**Aviso al desplegar esta versión:** los tokens de sesión llevan ahora un sello de seguridad, y
los emitidos antes no lo tienen, así que **todos los usuarios tendrán que volver a iniciar sesión
una vez**. A partir de aquí, cambiar o restablecer la contraseña cierra la sesión en los demás
dispositivos (el token del Atajo de iOS no se ve afectado).

**Comprobación**: en la web, "¿Olvidaste tu contraseña?" con tu email → llega un correo de
"Synap" con un botón; el enlace abre `/auth/reset-password`, permite elegir contraseña y después
el login funciona solo con la nueva. Si el correo no llega, mira los errores en
`docker compose exec synap-api sh -c 'sed "s/<[^>]*>/ /g" /app/logs/$(ls -t /app/logs | head -1) | grep -i email | tail'`.

## 11. Cuando todo esto esté hecho

Sigue con `docs/smoke-test-checklist.md` (tarea 5.5) para la prueba de extremo a extremo.
