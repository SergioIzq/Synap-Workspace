# Tasks

> Las tareas de cada repo dependen de las de orquestación y servidor (grupos 3 y 4) en el orden que se indica en `design.md` → Migration Plan: 1) CI, 2) imágenes, 3) compose, 4) servidor, 5) deploy, 6) copias.

## 1. Backend (back)

- [x] 1.1 Crear `.github/workflows/ci.yml` con el trabajo `test` (en pull requests y push a `main`): `dotnet build Synap.slnx` y pytest de `ai-service` con los dos ficheros de `workspace.yaml`; verificar abriendo una PR de prueba y viendo la comprobación en verde, y otra con un error de compilación que debe salir en rojo
- [x] 1.2 Añadir permisos mínimos (`contents: read`) y confirmar que en una PR desde un fork el workflow no dispone de ningún secreto
- [x] 1.3 Añadir el trabajo `publish` (solo push a `main`, tras `test`) que construye y publica `ghcr.io/sergioizq/synap-api` (contexto raíz) y `synap-ai` (contexto `ai-service/`) con tags de SHA y `latest`, con `packages: write` solo en este trabajo; verificar que tras fusionar aparecen ambos paquetes con los dos tags
- [x] 1.4 Marcar los paquetes `synap-api` y `synap-ai` como públicos y verificar con `docker pull ghcr.io/sergioizq/synap-api:latest` desde una máquina sin sesión iniciada
- [x] 1.5 Añadir el trabajo `deploy` (push a `main`, tras `publish`, `environment: production`, `concurrency` sin cancelar) que se conecta por `ssh` con la huella fijada en `VPS_HOST_KEY` y ejecuta el script para `synap-api` y `synap-ai` con el SHA; requiere 3.2 y 4.x; verificar con un commit trivial: el job termina en verde y `docker ps` en el VPS muestra los contenedores con la imagen de ese SHA
- [x] 1.6 Añadir disparo `workflow_dispatch` con entrada `sha` que ejecuta solo `deploy`; verificar volviendo a un SHA anterior y comprobando en el VPS que la API usa esa imagen
- [x] 1.7 Confirmar que ningún secreto de producción aparece en el repo ni en la imagen publicada (`docker history` y búsqueda de `.env`) y que el `Dockerfile` no necesita cambios

## 2. Frontend (front)

- [x] 2.1 Crear `.github/workflows/ci.yml` con `test` (PR y push a `main`): `npm ci` y `npm run build`; verificar con una PR en verde y otra con error de compilación en rojo
- [x] 2.2 Añadir permisos mínimos y confirmar que una PR desde un fork no dispone de secretos
- [x] 2.3 Añadir `publish` (solo push a `main`) que publica `ghcr.io/sergioizq/synap-frontend` con tags de SHA y `latest`; verificar que aparecen en GHCR tras fusionar
- [x] 2.4 Marcar el paquete `synap-frontend` como público y verificar con `docker pull` sin sesión
- [x] 2.5 Añadir `deploy` (mismo esquema que 1.5) para `synap-frontend`; requiere 3.2 y 4.x; verificar con un commit trivial y comprobando la imagen del contenedor en el VPS
- [x] 2.6 Añadir `workflow_dispatch` con entrada `sha`; verificar volviendo a un SHA anterior

## 3. Orquestación y documentación (specs)

- [x] 3.1 En `docker-compose.yml`, añadir `image: ghcr.io/sergioizq/synap-<x>:${SYNAP_<X>_TAG:-latest}` a los tres servicios conservando `build:`; verificar con `docker compose config` y que `docker compose up --build` sigue construyendo en local
- [x] 3.2 Crear `scripts/deploy.sh <servicio...> <sha>`: copia previa si incluye `synap-api`, actualización de las líneas `SYNAP_*_TAG` en `.env`, `docker compose pull` y `up -d` solo de esos servicios, espera a `healthy` con tiempo máximo y salida con error si no; verificar en local con un stack de pruebas que un servicio sano termina en 0 y uno que no arranca termina en error
- [x] 3.3 Añadir `SYNAP_API_TAG`, `SYNAP_AI_TAG` y `SYNAP_FRONTEND_TAG` a `.env.example` sin valores reales; verificar que el fichero sigue sin secretos
- [x] 3.4 Actualizar `docs/deployment-runbook.md`: sustituir el despliegue manual por el flujo CI/CD, documentar rollback por SHA, migraciones compatibles hacia atrás, `git pull` manual del clon tras cambios de compose o script, y corregir el puerto de la API (8081, no 8080); verificar releyendo que no queda ninguna instrucción de `--build` en el VPS
- [x] 3.5 Comprobar que `docker-compose.override.yml` sigue ignorado y documentar que no debe existir en el VPS

## 4. Servidor y GitHub (manual, con el operador)

- [x] 4.1 Confirmar la arquitectura del VPS (`uname -m`, esperado `x86_64`) antes de publicar imágenes
- [x] 4.2 En el VPS, hacer `git pull` de `/var/www/Synap-Workspace` tras fusionar el compose y el script; verificar que `scripts/deploy.sh` existe y que `docker compose config` resuelve las tres imágenes
- [x] 4.3 Crear el usuario `deploy` (sin sudo, en el grupo `docker`, permisos de lectura y escritura sobre `.env`) y generar un par de claves SSH nuevo solo para CI; verificar que `id deploy` no incluye `sudo`
- [x] 4.4 Añadir la clave pública a `authorized_keys` de `deploy` con `command="…/scripts/deploy.sh …"`, `no-pty`, `no-port-forwarding` y `no-agent-forwarding`; verificar que con esa clave `ssh deploy@vps "ls"` no ejecuta `ls`
- [x] 4.5 En `back` y `front`, crear el *environment* `production` con `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY` y `VPS_HOST_KEY`; verificar que aparecen como secretos del entorno y que ningún valor se ha pegado en el chat ni en el repo
- [x] 4.6 Activar la protección de `main` en `back`, `front` y el repo de specs exigiendo la comprobación `test`; verificar que una PR con CI en rojo no se puede fusionar
- [ ] 4.7 Configurar la copia diaria de Postgres (cron, `pg_dump` comprimido, retención de 7 días, fuera del volumen de la base de datos); verificar que aparece un fichero nuevo al día siguiente y que se puede restaurar en una base de pruebas
- [ ] 4.8 Prueba final de extremo a extremo: fusionar un cambio trivial en `back` y otro en `front`, comprobar que cada deploy actualiza solo sus servicios y que `/health` responde; forzar un fallo de arranque y comprobar que el job termina en rojo
