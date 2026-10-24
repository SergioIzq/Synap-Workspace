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

## 1. Clonar el repo de orquestación

El servidor no compila nada: descarga las imágenes que publica CI (ver sección 11), así que solo
necesita este repo (el compose, `scripts/deploy.sh` y la plantilla `.env.example`). En el VPS vive
en `/var/www/Synap-Workspace`.

```bash
git clone https://github.com/SergioIzq/Synap-Workspace.git /var/www/Synap-Workspace
cd /var/www/Synap-Workspace
```

Los repos `Synap-Backend` y `Synap-Frontend` solo se clonan en una máquina de desarrollo, para
construir el stack en local con `docker compose up --build`.

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

La primera vez, con las imágenes ya publicadas en GHCR (sección 11), se descargan y se arrancan sin
construir nada:

```bash
docker compose pull
docker compose up -d
```

A partir de ahí cada fusión en `main` se despliega sola. Verifica que arrancan los cuatro
servicios:

```bash
docker compose ps
docker compose logs -f synap-api synap-ai
```

## 5. Migraciones de base de datos

No hay que aplicarlas a mano: la API ejecuta `Database.Migrate()` al arrancar, así que cada
despliegue de `synap-api` deja el esquema al día (`users`, `notes`, `tags`, `note_tags`,
`note_embeddings` con la extensión `vector`, etc.). Comprueba el arranque con
`docker compose logs synap-api`.

`Migrate()` solo avanza, no deshace: ver «Migraciones compatibles hacia atrás» en la sección 11.

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
subdominio propio, otro para la API → `synap-api` (puerto 8081 del host). `postgres` y
`synap-ai` deliberadamente no tienen puertos publicados en `docker-compose.yml` — no deben ser
alcanzables desde fuera del propio stack.

## 8. Migrar a "cada usuario con su propia key de Groq" (byok-groq-and-settings)

Si el servidor ya estaba desplegado con la antigua `GROQ_API_KEY` global:

1. Genera la clave maestra y añádela al `.env`: `echo "SECRETS_ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env`.
   Guárdala también fuera del servidor (gestor de contraseñas).
2. Borra `GROQ_API_KEY` del `.env` — ya no se lee en ningún sitio.
3. Despliega (sección 11). La migración `AddUserGroqSettings` solo añade columnas
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

Despliega (sección 11) y comprueba el valor:

```bash
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

## 11. Despliegue continuo (CI/CD)

**Ramas.** En los tres repos `develop` es la rama de integración y la rama por defecto: las ramas
de trabajo salen de ella y sus pull requests van a ella. Fusionar en `develop` no publica ni
despliega nada. `main` es producción: solo recibe la pull request `develop → main`, que se fusiona
**con merge commit** (squash y rebase están desactivados en `main` para que las dos ramas no
diverjan). Esa fusión es el paso a producción.

Cada fusión en `main` de `Synap-Backend` o `Synap-Frontend` ejecuta en GitHub Actions
`test` → `publish` → `deploy` → `tag`:

1. `test`: compila (y en back pasa los pytest sin red). En una pull request a `develop` o a `main`
   solo corre esto, sin secretos.
2. `publish`: construye y publica en GHCR `ghcr.io/sergioizq/synap-api`, `synap-ai` (back) y
   `synap-frontend` (front), con el SHA completo del commit y `latest`.
3. `deploy`: por SSH ejecuta `scripts/deploy.sh <servicios> <sha>` en el VPS, que:
   copia la base de datos antes de reiniciar `synap-api`, escribe `SYNAP_*_TAG=<sha>` en `.env`,
   hace `docker compose pull` y `up -d` **solo de esos servicios** (back: `synap-api` y
   `synap-ai`; front: `synap-frontend`; `postgres` no se toca) y espera a que su `HEALTHCHECK`
   sea `healthy` (máximo 180 s, `SYNAP_DEPLOY_TIMEOUT`). Si no lo es, el job sale en rojo
   indicando qué servicio falla.
4. `tag`: solo si `deploy` terminó bien, crea sobre el commit el tag SemVer siguiente subiendo el
   patch (`v1.0.0` el primero, luego `v1.0.1`…). Si el deploy falla, no hay versión.

**Versiones.** Cada tag `vX.Y.Z` marca algo que llegó a producción. En este repo,
`.github/workflows/release-tag.yml` crea el tag en cada push a `main` (aquí no hay deploy desde CI).
Para subir minor o major, crea el tag a mano sobre `main` (`git tag -a v1.1.0 -m v1.1.0 origin/main`
y `git push origin v1.1.0`); la siguiente versión automática parte de él (`v1.1.1`). Un rollback
por `workflow_dispatch` no crea versión.

El despliegue no pide aprobación y no hay compilación en el VPS. Un reinicio de la API implica
unos segundos de corte.

**Volver a una versión anterior (rollback por SHA).** Es la misma operación con un SHA publicado:

- Desde GitHub: Actions > CI > *Run workflow* en `main`, con el SHA completo en la entrada `sha`
  (ejecuta solo `deploy`).
- Emergencia, desde el VPS: `scripts/deploy.sh synap-api <sha>`.

**Migraciones compatibles hacia atrás.** Volver a una imagen anterior no deshace migraciones. Por
eso cada migración debe funcionar con la versión inmediatamente anterior de la aplicación: solo
añadir (tablas, columnas nulables o con valor por defecto). Borrar o renombrar se hace en dos
despliegues: primero se deja de usar lo antiguo, y en el siguiente se elimina. Antes de cada
reinicio de `synap-api`, `deploy.sh` guarda con `scripts/backup.sh` un volcado
`predeploy-*.sql.gz` en `/var/backups/synap` (se borran los de más de 7 días); si falla la copia,
no se despliega.

**`git pull` manual.** El clon `/var/www/Synap-Workspace` sigue en `main` (producción), no en
`develop`, y no se actualiza solo. Tras fusionar un
cambio de `docker-compose.yml` o `scripts/deploy.sh` hay que hacer `git pull` en el VPS, antes
de que el siguiente despliegue dependa de él.

**`docker-compose.override.yml` no debe existir en el VPS.** Está en `.gitignore` y es solo para
desarrollo local; en el servidor haría que compose mezclara configuración ajena al despliegue.

**Puertos.** La API se publica en el 8081 del host y el frontend en el 4200; `postgres` y
`synap-ai` no publican puertos.

## 12. Preparar el servidor para CI/CD (una sola vez)

1. Confirma la arquitectura: `uname -m` debe dar `x86_64` (los runners publican imágenes x86_64).
2. Publica las imágenes (primer push a `main` de cada repo) y márcalas **públicas** en GitHub
   (Packages > el paquete > Package settings > Change visibility), una vez por paquete. Comprueba
   sin sesión iniciada: `docker pull ghcr.io/sergioizq/synap-api:latest`.
3. `git pull` en `/var/www/Synap-Workspace` y comprueba `docker compose config --images`.
4. Crea el usuario de despliegue, sin sudo y en el grupo `docker`:

   ```bash
   adduser --disabled-password --gecos "" deploy
   usermod -aG docker deploy
   chown deploy /var/www/Synap-Workspace/.env && chmod 600 /var/www/Synap-Workspace/.env
   install -d -o deploy -m 750 /var/backups/synap
   id deploy   # no debe incluir sudo
   ```

5. Genera una clave SSH **solo para CI** (`ssh-keygen -t ed25519 -f ci_deploy -N ""`) y añade la
   pública a `/home/deploy/.ssh/authorized_keys` restringida al script:

   ```
   command="/var/www/Synap-Workspace/scripts/deploy.sh",no-pty,no-port-forwarding,no-agent-forwarding ssh-ed25519 AAAA… ci-deploy
   ```

   Con esa clave, `ssh deploy@vps ls` no ejecuta `ls`: `deploy.sh` rechaza cualquier servicio o
   SHA no válido. Quien pueda modificar `deploy.sh` controla el servidor, por eso `main` debe
   estar protegida.
6. En `Synap-Backend` y `Synap-Frontend` crea el *environment* `production` (sin reglas de
   aprobación) con estos secretos de entorno: `VPS_HOST`, `VPS_USER` (`deploy`), `VPS_SSH_KEY`
   (la privada) y `VPS_HOST_KEY` (la línea de `known_hosts` del servidor, de
   `ssh-keyscan -t ed25519 <VPS_HOST>`). Pégalos en GitHub, nunca en un chat ni en un repo.
7. Protege `main` y `develop` en `Synap-Backend`, `Synap-Frontend` y este repo con dos rulesets
   que nombren cada rama explícitamente (`refs/heads/main` y `refs/heads/develop`, nunca «rama por
   defecto», o al cambiarla una quedaría sin proteger): `proteger-main` y `proteger-develop`, con
   pull request obligatoria, sin borrado ni force-push y, en back y front, la comprobación `test`.
   En `proteger-main` el único método de fusión permitido es merge.
8. Copia diaria de Postgres con `scripts/backup.sh` (el mismo que usa `deploy.sh` para la copia
   previa): deja `daily-<fecha UTC>.sql.gz` en `/var/backups/synap`, fuera del volumen de la base
   de datos, solo legible por su dueño, y borra las de más de 7 días únicamente si la nueva es
   válida. Un volcado que falla, sale vacío o está cortado no se guarda y no borra nada.
   Requiere que el clon esté en un `main` que ya incluya el script (`git pull`). Programa el cron
   del usuario `deploy` (`sudo crontab -u deploy -e`):

   ```
   15 3 * * * /var/www/Synap-Workspace/scripts/backup.sh daily 2>&1 | logger -t synap-backup
   ```

   Pruébalo una vez a mano (`sudo -u deploy /var/www/Synap-Workspace/scripts/backup.sh`) y, al
   día siguiente, comprueba que hay un fichero nuevo (`ls -l /var/backups/synap`) y que el log no
   tiene errores (`journalctl -t synap-backup`). Restáuralo en una base de pruebas y bórrala:

   ```bash
   cd /var/www/Synap-Workspace
   docker compose exec -T postgres sh -c 'createdb -U "$POSTGRES_USER" restore_test'
   gunzip -c /var/backups/synap/daily-<fecha>.sql.gz | docker compose exec -T postgres sh -c 'psql -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d restore_test'
   docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d restore_test -c "\dt"'
   docker compose exec -T postgres sh -c 'dropdb -U "$POSTGRES_USER" restore_test'
   ```

   Estas copias viven en el mismo servidor: guarda también una fuera de él.

## 13. Cuando todo esto esté hecho

Sigue con `docs/smoke-test-checklist.md` (tarea 5.5) para la prueba de extremo a extremo.
