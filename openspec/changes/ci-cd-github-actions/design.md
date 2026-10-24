# Design

## Context

Motivación y alcance en `proposal.md`; requisitos en `specs/entrega-continua/spec.md`.

Estado verificado:

- VPS (`ssh contabo`, Docker 29.1.3): el stack vive en `/var/www/Synap-Workspace/docker-compose.yml`, proyecto compose `synap-workspace`, y es un clon del repo de specs. Comparte máquina con kash, ahorroland y mi-db.
- `docker-compose.yml` solo tiene `build:` en `synap-api`, `synap-ai` y `synap-frontend`. `synap-api` publica `8081:80`, `synap-frontend` `4200:80`; `synap-ai` y `postgres` no publican puertos.
- Los tres Dockerfiles definen `HEALTHCHECK` (la API contra `/health`, `Synap.Api/Program.cs:308`).
- La API aplica las migraciones al arrancar (`Synap.Api/Program.cs:276`, `db.Database.Migrate()`).
- `docker-compose.override.yml` está en `.gitignore`. Los repos `back` y `front` no tienen `.github/`.
- Los repos son públicos. GitHub personal no comparte secretos entre repos.

## Goals / Non-Goals

**Goals:**
- Que lo que se prueba en CI sea exactamente lo que se ejecuta en producción (misma imagen).
- Que desplegar y volver atrás sean la misma operación: «poner el servicio en la imagen del commit X».
- Que la credencial de CI, si se filtra, permita lo mínimo posible.

**Non-Goals:**
- Pruebas de integración o e2e en CI (solo los comandos de `build` de `workspace.yaml`).
- Entornos de staging, despliegues progresivos o sin interrupción: un reinicio breve del servicio actualizado es aceptable.
- Copia de seguridad fuera del VPS (ver Open Questions).

## Decisions

### 1. Un workflow por repo, con las fases encadenadas
Cada repo (`back`, `front`) tiene un único `ci.yml` con trabajos `test` → `publish` → `deploy`. `test` corre en pull requests y en push a `main`; `publish` y `deploy` solo en push a `main` (`if: github.event_name == 'push'`).

*Alternativa:* workflows separados enlazados con `workflow_run`. Descartada: más piezas, y el deploy podría lanzarse tras un `publish` fallido si se configura mal.

### 2. Imágenes en GHCR, públicas, con tag de SHA y `latest`
Autenticación con `GITHUB_TOKEN` (permiso `packages: write` solo en el trabajo `publish`). Nombres: `ghcr.io/sergioizq/synap-api`, `synap-ai` (ambos desde `back`, el segundo con contexto `ai-service/`) y `synap-frontend` (desde `front`). El paquete nace privado: hay que marcarlo público una vez por imagen.

*Alternativa:* Docker Hub, que ya usa kash. Descartada: añade otro secreto y límites de descarga; GHCR no necesita ninguno.

### 3. Compose con `build:` + `image:` y tag por variable
Cada servicio conserva `build:` y gana `image: ghcr.io/sergioizq/synap-<x>:${SYNAP_<X>_TAG:-latest}`. Con `pull` + `up -d` (sin `--build`) se usa la imagen descargada; `docker compose up --build` en local sigue construyendo desde el código.

### 4. El despliegue lo hace un script versionado en el VPS, invocado por SSH con clave restringida
`scripts/deploy.sh <servicio...> <sha>` (en el repo de specs, clonado en el VPS) hace: copia previa de la base de datos si el servicio es `synap-api`, escribe el tag en `.env`, `docker compose pull` y `up -d` solo de esos servicios, y espera a que el `HEALTHCHECK` de cada uno pase a `healthy` con un tiempo máximo; sale con error si no.

El usuario `deploy` pertenece al grupo `docker` y su entrada en `authorized_keys` lleva `command="…/deploy.sh …"`, `no-pty`, `no-port-forwarding`, `no-agent-forwarding`: la clave de CI solo puede ejecutar ese script. El workflow se conecta con `ssh` plano, con la huella del servidor fijada en un secreto (`VPS_HOST_KEY`), sin acciones de terceros.

Se despliega el **SHA exacto** que se acaba de probar, no `latest`. Así, dos fusiones seguidas no se pisan (el job usa `concurrency` sin cancelar) y el rollback es la misma operación con un SHA anterior.

*Alternativa:* `appleboy/ssh-action` ejecutando comandos libres. Descartada: la clave podría ejecutar cualquier cosa, y dependemos de un tercero con acceso a producción.

### 5. El tag desplegado se guarda en `.env` del VPS
El script reescribe solo las líneas `SYNAP_API_TAG`, `SYNAP_AI_TAG` y `SYNAP_FRONTEND_TAG`. Así un `docker compose up -d` manual posterior no devuelve nada a `latest` sin querer. Consecuencia: `deploy` necesita leer y escribir `.env`.

### 6. Rollback = relanzar el despliegue de un SHA anterior
El workflow admite `workflow_dispatch` con un `sha`; vuelve a ejecutar solo `deploy` con él. Emergencia: en el VPS, `scripts/deploy.sh synap-api <sha>`.

### 7. Secretos acotados
Secretos de despliegue (`VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `VPS_HOST_KEY`) en un *environment* `production` de cada repo, sin reglas de aprobación (el deploy es automático), más `permissions: contents: read` por defecto. Las ejecuciones de pull requests, también de forks, no reciben secretos. Los secretos de la aplicación siguen solo en el `.env` del VPS.

### 8. Copia de seguridad
`pg_dump` diario por cron en el VPS, comprimido, con retención de 7 días, en un directorio fuera del volumen de Postgres. Además, `deploy.sh` hace una copia antes de reiniciar `synap-api`.

## Risks / Trade-offs

- **`Migrate()` solo avanza** → volver a una imagen anterior no deshace migraciones. Mitigación: migraciones compatibles hacia atrás con la versión anterior (aditivas; borrar o renombrar en dos despliegues) y copia previa al deploy. El deploy automático sin aprobación se mantiene por decisión.
- **Pertenecer al grupo `docker` equivale a root en el host** → mitigado por la clave con `command=` restringido a `deploy.sh` y sin pty ni reenvíos. No elimina el riesgo si alguien puede modificar `deploy.sh`: la rama `main` debe estar protegida.
- **Deploy automático con una fusión rota** → el healthcheck lo detecta y falla el job, pero el servicio ya se habrá reiniciado. Mitigación: rollback por SHA y CI obligatorio antes de fusionar (protección de rama).
- **Cambios en el compose o en `deploy.sh` no se despliegan solos** → el VPS es un clon que solo se actualiza con `git pull` manual. Mitigación: documentarlo en el runbook; es un cambio poco frecuente.
- **Paquete GHCR privado en el primer push** → el VPS no podría hacer `pull`. Mitigación: tarea explícita de hacerlo público y verificar con `docker pull` sin login.
- **Arquitectura** → los runners son x86_64; hay que confirmar que el VPS lo es antes del primer despliegue.
- **Recursos compartidos del VPS** → `pull` + reinicio es mucho más ligero que compilar, pero un reinicio de la API provoca una interrupción de segundos.
- **Fuera de este change**, observado en el VPS: MySQL (`:3307`) y phpMyAdmin (`:8082`) publicados en `0.0.0.0`, y ficheros `privatekey`/`privkey2.pem` en `/root` sin revisar. No se tocan aquí; conviene abordarlos aparte.

## Migration Plan

1. CI en pull requests (`test`), sin tocar producción.
2. Añadir `publish`: primeras imágenes en GHCR; marcarlas públicas.
3. Cambiar el compose, fusionarlo y hacer `git pull` en el VPS; verificar con las imágenes publicadas, sin automatizar aún.
4. Crear el usuario `deploy`, su clave y los secretos.
5. Añadir `deploy`; probar con un commit trivial y comprobar el healthcheck.
6. Probar el rollback con un SHA anterior. Activar copias y protección de rama.

Rollback del propio change: borrar los workflows y devolver el compose al `build:` previo; el VPS puede volver a construir con `docker compose up --build -d`.

## Open Questions

- ¿Dónde guardar una copia de seguridad fuera del VPS (otro servidor, almacenamiento de objetos)? No cambia los requisitos ni las tareas de este change.
- ¿Añadir `dotnet test` de `Synap.UnitTests` al CI de `back`? Hoy `workspace.yaml` solo define compilación y los dos ficheros de pytest; se puede ampliar después.
