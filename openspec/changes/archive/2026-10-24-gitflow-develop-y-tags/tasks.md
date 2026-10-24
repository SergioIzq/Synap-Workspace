# Tasks

> Orden según `design.md` → Migration Plan: primero el grupo 1 (GitHub), después las ramas de trabajo desde `develop` y los grupos 2 a 4; el grupo 5 cierra con el primer paso a producción.

## 1. GitHub (manual, con el operador)

- [x] 1.1 Crear `develop` en remoto desde `origin/main` en `Synap-Workspace`, `Synap-Backend` y `Synap-Frontend`; verificar con `git ls-remote --heads origin develop` que apunta al mismo SHA que `origin/main`
- [x] 1.2 Cambiar el ruleset `proteger-main` de cada repo a `refs/heads/main` (en lugar de `~DEFAULT_BRANCH`) y `allowed_merge_methods: ["merge"]`, conservando el resto de reglas; verificar con `gh api repos/SergioIzq/<repo>/rulesets/<id>`
- [x] 1.3 Crear el ruleset `proteger-develop` sobre `refs/heads/develop` con borrado y force-push bloqueados, PR obligatoria (merge, squash y rebase) y, en `back` y `front`, la comprobación `test`; verificar con `gh api repos/SergioIzq/<repo>/rules/branches/develop` que aplican las mismas reglas que a `main`
- [x] 1.4 Cambiar la rama por defecto a `develop` en los tres repos (requiere 1.2); verificar con `gh api repos/SergioIzq/<repo> --jq .default_branch` y que `main` sigue protegida rechazando un push directo
- [x] 1.5 Crear `feature/gitflow-develop-y-tags` desde `origin/develop` en `back` y `front`; verificar con `git log -1` que parte del SHA de `develop`

## 2. Backend (back)

- [ ] 2.1 En `.github/workflows/ci.yml`, `pull_request.branches: [main, develop]` y actualizar el comentario de cabecera; verificar que la PR de este change a `develop` ejecuta `test`
- [x] 2.2 Añadir el trabajo `tag` (`needs: deploy`, solo push con deploy correcto, `contents: write`, checkout con `fetch-depth: 0`) con el cálculo y reintento de D3; verificar el script en local en un repo de prueba: sin tags crea `v1.0.0`, con `v1.0.3` crea `v1.0.4`, con `v1.1.0` manual crea `v1.1.1`, y con el commit ya etiquetado no crea nada (escenarios «Primera versión», «Subida automática del patch», «Subida manual del minor», «Reejecución sin duplicar»)
- [x] 2.3 Comprobar leyendo el workflow que en `workflow_dispatch` el trabajo `tag` se omite y que con `deploy` fallido no se ejecuta (escenarios «Una vuelta atrás no crea versión» y «Despliegue fallido sin versión»)

## 3. Frontend (front)

- [ ] 3.1 Lo mismo que 2.1 en `.github/workflows/ci.yml`; verificar que la PR de este change a `develop` ejecuta `test`
- [x] 3.2 Añadir el trabajo `tag` con el mismo script que 2.2; verificar con `diff` que el paso de cálculo es idéntico al de `back`
- [x] 3.3 Mismas comprobaciones que 2.3

## 4. Orquestación y documentación (specs)

- [x] 4.1 En `workspace.yaml`, `ramas.integracion: develop` y `ramas.protegidas: [main, develop]` con comentarios que expliquen que `main` es producción; verificar que `/montrel-azure:explore` muestra `develop` como base
- [x] 4.2 Crear `.github/workflows/release-tag.yml` (push a `main`, `contents: write`) con el mismo script de tag; verificar con `diff` frente al paso de `back`
- [x] 4.3 Actualizar `docs/deployment-runbook.md`: ramas `develop`/`main`, paso a producción con PR `develop → main` y solo merge commit, tags automáticos y subida manual de minor/major, y que el VPS sigue en `main`; verificar releyendo que la protección descrita nombra las dos ramas
- [x] 4.4 Alinear la delta spec del change `ci-cd-github-actions` con `/montrel-azure:update` para que «rama de integración» pase a «rama de producción» donde se refiere a publicar y desplegar; verificar con `openspec validate ci-cd-github-actions`

## 5. Paso a producción (manual, con el operador)

- [ ] 5.1 Fusionar en `develop` las PRs de este change en los tres repos y verificar que un push a `develop` no publica, no despliega ni crea tag (escenario «Fusión en develop no llega a producción»)
- [ ] 5.2 Intentar fusionar una PR `develop → main` con squash y verificar que GitHub no lo permite (escenario «Fusión aplastada a main no permitida»)
- [ ] 5.3 Fusionar con merge commit la PR `develop → main` en cada repo; verificar en `back` y `front` deploy en verde y tag `v1.0.0`, y en specs tag `v1.0.0` (escenarios «Paso a producción» y «Primera versión»)
- [ ] 5.4 Verificar en una PR de prueba a `develop` en `back` con un error de compilación que `test` sale en rojo y no se puede fusionar (escenario «Comprobación fallida bloquea la fusión»)
