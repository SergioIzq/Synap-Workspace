Seguimiento: AB#7

# Proposal

## Why

Hoy `main` es a la vez la rama de integración y la de producción: cada PR fusionada se publica y se despliega en el VPS al momento, así que no hay dónde acumular y revisar cambios antes de que lleguen a los usuarios, y ninguna versión desplegada tiene un nombre estable al que referirse o al que volver. Se necesita separar integración de producción y marcar cada paso a producción con una versión.

## What Changes

- Nueva rama `develop` en los tres repos, creada desde `main`, que pasa a ser la rama por defecto en GitHub y la base de todas las ramas de trabajo; sus PRs van a `develop`.
- `main` queda como rama de producción: solo recibe la PR `develop → main`, que es el paso a producción. El despliegue automático actual en push a `main` no cambia.
- `develop` protegida igual que `main` (PR obligatoria, sin borrado ni force-push y, en `back` y `front`, comprobación `test` en verde). Las dos ramas se nombran explícitamente en la protección, que hoy se apoya en «rama por defecto» y dejaría a `main` sin proteger al cambiarla.
- Cada push a `main` crea automáticamente un tag SemVer subiendo el patch (`v1.0.0` el primero, luego `v1.0.1`…). Minor y major se suben a mano creando el tag.
- La comprobación `test` de `back` y `front` se ejecuta también en las PRs a `develop`; publicar y desplegar siguen solo en push a `main`.
- `workspace.yaml`: `ramas.integracion: develop` y `ramas.protegidas: [main, develop]`, de modo que los comandos Montrel crean ramas desde `develop` y abren las PRs contra ella.

## Capabilities

### New Capabilities
- `gestion-de-versiones`: ramas de integración y producción, su protección, comprobación de las PRs hacia ambas y versionado SemVer automático de cada paso a producción.

### Modified Capabilities
<!-- Ninguna en openspec/specs/. La capacidad `entrega-continua` aún no está archivada (change `ci-cd-github-actions`): su texto «rama de integración» debe leerse como rama de producción; se alinea en ese change antes de archivarlo (ver design.md). -->

## Impact

**Repos afectados:**
- `.` (specs): `workspace.yaml`, workflow de tag en `.github/workflows/`, `docs/deployment-runbook.md`.
- `back`: `.github/workflows/ci.yml` (test en PRs a `develop` y trabajo de tag tras el deploy).
- `front`: `.github/workflows/ci.yml` (lo mismo).

**Sistemas:** GitHub (rama `develop`, rama por defecto y rulesets de los tres repos). Los comandos Montrel no cambian: leen las ramas de `workspace.yaml`.

**Riesgos:** si la PR `develop → main` se fusiona con squash, `develop` y `main` divergen; por eso `main` solo admitirá merge commit.

## Scope

- Las tres ramas `develop`, la protección de `develop` y `main`, el tag automático y el ajuste de CI y de `workspace.yaml`.

## Non-goals

- GitHub Releases, changelog o notas de versión generadas.
- Calcular la versión a partir de los mensajes de commit.
- Ramas `release/*` o `hotfix/*`: los arreglos urgentes también pasan por `develop`.
- Entorno de preproducción desplegado desde `develop`.
- Proteger los tags frente a borrado.
