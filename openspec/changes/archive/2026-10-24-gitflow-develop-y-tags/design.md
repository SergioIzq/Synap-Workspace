## Context

Los tres repos (`.`, `back`, `front`) están en GitHub (`SergioIzq/Synap-Workspace`, `Synap-Backend`, `Synap-Frontend`), son públicos y tienen `main` como única rama de larga vida y rama por defecto. Cada uno tiene un ruleset `proteger-main` que aplica a `~DEFAULT_BRANCH` con: sin borrado, sin force-push, PR obligatoria (0 aprobaciones, merge/squash/rebase) y, en `back` y `front`, la comprobación `test`. No hay ningún tag.

En `back` y `front`, `.github/workflows/ci.yml` tiene `test` (PR y push a `main`), `publish` (push a `main`) y `deploy` (push a `main` o `workflow_dispatch` con `sha`, `environment: production`). El repo de specs no tiene CI propio (solo `copilot-setup-steps.yml`). El VPS hace `git pull` de `main` del repo de specs para el compose y `scripts/deploy.sh`.

`workspace.yaml` tiene `ramas.integracion: main` y `ramas.protegidas: [main]`; los comandos Montrel leen de ahí la base de las ramas y el destino de las PRs.

## Goals / Non-Goals

**Goals:**
- `develop` como integración y rama por defecto; `main` como producción, alimentada solo por PRs `develop → main`.
- Ambas ramas protegidas sin depender de cuál es la rama por defecto.
- Tag SemVer automático en cada push a `main`; en `back`/`front`, solo tras un deploy correcto.

**Non-Goals:**
- GitHub Releases, changelog, versión derivada de commits, ramas `release/*`/`hotfix/*`, preproducción desde `develop`, protección de tags.

## Decisions

### D1. Dos rulesets por repo, con ramas explícitas
`proteger-main` pasa de `~DEFAULT_BRANCH` a `refs/heads/main` (si no, al cambiar la rama por defecto a `develop` `main` quedaría sin proteger) y restringe `allowed_merge_methods` a `["merge"]`. Se crea `proteger-develop` sobre `refs/heads/develop` con las mismas reglas que tenía `main` (merge/squash/rebase permitidos y `test` en `back`/`front`).
- *Alternativa:* un solo ruleset con las dos ramas. Descartada: el método de fusión es un parámetro del ruleset y solo `main` debe limitarlo.
- *Por qué solo merge en `main`:* un squash de `develop → main` crea en `main` un commit que `develop` no tiene, y la siguiente PR arrastra conflictos o cambios repetidos.

### D2. Tag dentro del CI en `back`/`front`, workflow propio en specs
En `back` y `front` se añade a `ci.yml` un trabajo `tag` con `needs: deploy` e `if: github.event_name == 'push' && needs.deploy.result == 'success'`: el tag marca lo que realmente está en producción, y un `workflow_dispatch` (rollback) no crea versión. En el repo de specs, que no despliega desde CI, `.github/workflows/release-tag.yml` en `push` a `main` ejecuta el mismo paso.
- Permisos: `contents: write` solo en ese trabajo; se usa `GITHUB_TOKEN`. Los tags creados con `GITHUB_TOKEN` no disparan otros workflows, que es lo deseado.
- *Alternativa:* workflow de tag independiente también en `back`/`front`. Descartada: etiquetaría commits cuyo deploy ha fallado.

### D3. Cálculo de la versión
Con `actions/checkout` y `fetch-depth: 0`:
1. Si `GITHUB_SHA` ya tiene un tag `^v[0-9]+\.[0-9]+\.[0-9]+$`, termina sin hacer nada (reejecuciones).
2. Toma el mayor tag con esa forma (`git tag -l 'v*' --sort=-v:refname` filtrado por la expresión); sin ninguno, `v1.0.0`; si no, sube el PATCH.
3. Crea un tag anotado sobre `GITHUB_SHA` (mensaje con SHA y nombre del workflow) y lo publica con `git push origin refs/tags/<v>`.
4. Si el push falla porque el tag ya existe (otra ejecución ganó la carrera), hace `git fetch --tags --force` y repite desde 1, hasta 3 intentos.
- *Por qué no `concurrency`:* GitHub solo deja una ejecución pendiente por grupo y cancela las más antiguas, así que un commit podría quedarse sin versión. El reintento sobre el push del tag es suficiente y no pierde ejecuciones.
- El script (unas 20 líneas de bash) se duplica en los tres repos en lugar de una acción compartida, para no acoplar el CI de los repos de código a otro repo.

### D4. CI en PRs a `develop`
`test` pasa a `pull_request: branches: [main, develop]`. `push` sigue en `[main]`: un push a `develop` no prueba, publica ni despliega (ya se probó en su PR).

### D5. `workspace.yaml` y comandos
`ramas.integracion: develop` y `ramas.protegidas: [main, develop]`. Los comandos y `AGENTS.md` ya son genéricos y no cambian. La PR `develop → main` (paso a producción) no forma parte del flujo de un change: se abre a mano cuando se decide publicar.

## Risks / Trade-offs

- [Una PR abierta contra `develop` antes de que su `ci.yml` incluya `develop` nunca recibe `test` y queda bloqueada] → fusionar primero en `develop` el cambio de CI de este change (en una PR, el workflow se toma del merge con la base, así que la propia PR sí ejecuta `test`).
- [El change `ci-cd-github-actions`, aún sin archivar, llama «rama de integración» a la que despliega] → antes de archivarlo, alinear su delta spec para que diga «rama de producción» (`/montrel-azure:update`); si se archiva tal cual, la spec `entrega-continua` contradiría a `gestion-de-versiones`.
- [Arreglos urgentes pasan por `develop` y arrastran lo que haya pendiente en ella] → aceptado por ahora; si duele, se añadirá `hotfix/*` en otro change.
- [Cambiar la rama por defecto cambia la rama que ven los clones nuevos y el destino por defecto de las PRs en la web] → es lo que se busca; el VPS sigue haciendo `git pull` de `main` explícitamente.
- [El primer tag `v1.0.0` aparece en el primer paso a producción, no ahora] → si se quiere marcar ya el estado actual, el operador crea `v1.0.0` a mano sobre `main` y el siguiente será `v1.0.1`.

## Migration Plan

1. Crear `develop` en remoto desde `origin/main` en los tres repos.
2. Rulesets: cambiar `proteger-main` a `refs/heads/main` + solo merge; crear `proteger-develop`. Comprobar que ambas ramas aparecen protegidas.
3. Cambiar la rama por defecto a `develop` en los tres repos.
4. Ramas `feature/gitflow-develop-y-tags` desde `develop` en `back` y `front` (en specs ya existe); implementar y fusionar las PRs en `develop`.
5. PR `develop → main` en cada repo (merge commit): verificar deploy y tag `v1.0.0`.

**Rollback:** devolver la rama por defecto a `main`, restaurar `proteger-main` a `~DEFAULT_BRANCH`, borrar `proteger-develop` y revertir `workspace.yaml`. Los tags creados pueden quedarse.

## Open Questions

Ninguna: formato de tag, protección de `develop` y rama por defecto acordados con el usuario.
