Seguimiento: AB#6

# Proposal

## Why

Hoy Synap se despliega a mano: alguien entra por SSH al VPS, hace `git pull` de los tres repos y ejecuta `docker compose up --build -d`, de modo que .NET, Angular y Python se compilan en un servidor de 3 vCPU / 8 GB que comparte máquina con otras webs. No hay ninguna comprobación automática antes de publicar, ni forma rápida de volver a una versión anterior. Se necesita que cada cambio fusionado en `main` se pruebe, se empaquete y llegue al VPS sin intervención manual.

## What Changes

- CI en pull requests de `back` y `front`: compilación y pruebas con los mismos comandos que ya define `workspace.yaml`.
- Publicación de imágenes en GHCR (`ghcr.io/sergioizq/synap-api`, `synap-ai`, `synap-frontend`) en cada push a `main`, etiquetadas con el SHA del commit y con `latest`.
- `docker-compose.yml`: cada servicio conserva `build:` y gana `image:` con etiqueta configurable por variable (`${SYNAP_API_TAG:-latest}` y equivalentes), para desplegar y revertir sin compilar en el VPS.
- Despliegue automático por SSH en cada push a `main`, siempre y sin aprobación manual: `docker compose pull` y `up -d` solo de los servicios del repo que cambió, seguido de una comprobación de salud contra `/health`. Si no responde, el job falla.
- Usuario dedicado `deploy` en el VPS con una clave SSH exclusiva para CI, guardada como secreto de GitHub en cada repo.
- Copia de seguridad de Postgres automática, porque las migraciones EF se aplican solas al arrancar la API.

## Capabilities

### New Capabilities
- `entrega-continua`: comprobación automática de los cambios, publicación de imágenes versionadas, despliegue automático al VPS con verificación de salud, y vuelta a una versión anterior por etiqueta.

### Modified Capabilities
<!-- Ninguna. Los requisitos de `/health` ya existen en `platform-operations` y el despliegue solo los consume. -->

## Impact

**Repos afectados:**
- `back`: workflows de CI, publicación de `synap-api` y `synap-ai`, y deploy de ambos servicios.
- `front`: workflows de CI, publicación de `synap-frontend` y deploy de ese servicio.
- Repo de specs (`.`): `docker-compose.yml`, `.env.example`, `docs/deployment-runbook.md`.

**Sistemas:** GitHub Actions y GHCR; en el VPS (`/var/www/Synap-Workspace`) un nuevo usuario `deploy` y un `git pull` manual único del repo de specs tras fusionar el cambio del compose.

**Riesgos:** `Migrate()` solo avanza, así que volver a una imagen anterior no deshace migraciones; el rollback exige migraciones compatibles hacia atrás. Detalle en `design.md`.

## Scope

- Los dos repos de código y el compose/runbook del repo de specs.
- Solo el stack `synap-workspace` del VPS.

## Non-goals

- No se tocan los otros stacks del VPS (kash, ahorroland, mi-db, phpMyAdmin).
- No se cambia el reverse proxy ni TLS.
- No se añaden entornos de staging ni aprobaciones manuales.
- No se cambia el comportamiento de la aplicación ni se alteran migraciones.
