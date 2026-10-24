---
name: "MONTREL: Explore"
description: "Validar los repositorios del workspace y explorar antes de proponer"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(graphify:*), AskUserQuestion, Skill
category: Workflow
tags: [workflow, explore, montrel]
---

Modo exploración sobre el workspace del cliente de `workspace.yaml`. **No se implementa código.** Antes de delegar en `/opsx:explore`, sigue estos pasos en orden.

## Paso 0 — inventario de repositorios

Lee `workspace.yaml`. Para cada entrada de `repos` (rutas relativas a este repo):

- Si la carpeta no existe, clónala con `git clone --branch <ramas.integracion> "<url>" "<ruta>"`. Informa del repositorio que se está clonando. No necesitas preguntar: el usuario ha autorizado esta sincronización automática.
- Si el clon falla, reporta el error y continúa con los demás; no borres automáticamente la carpeta parcial.
- Si la ruta existe pero no contiene `.git`, no clones encima: informa y deja ese repositorio pendiente.
- Si ya es un repositorio Git, compara `git -C "<ruta>" remote get-url origin` con su `url`. Si no coincide o falta `origin`, no lo modifiques; repórtalo para resolución manual.

Este repo de specs también se valida en los pasos 1 y 2 (ruta `.`).

## Paso 1 — validar la rama de integración

Para cada repositorio disponible, ejecuta `git -C "<ruta>" rev-parse --abbrev-ref HEAD`.

Si todos están en `ramas.integracion`, continúa. Si alguno está en otra rama, muestra una tabla `repositorio → rama` y pregunta con AskUserQuestion si quiere cambiarlos a `ramas.integracion`.

- Si acepta, comprueba individualmente `git -C "<ruta>" status --porcelain`. Solo cambia de rama si el árbol está limpio y la rama existe localmente o en `origin`; nunca hagas stash automático ni descartes trabajo.
- Si un repositorio está sucio o no tiene esa rama, no lo cambies; informa la razón y continúa.
- Si rechaza, no cambies ninguna rama; registra las ramas observadas y continúa.

## Paso 2 — fetch y fast-forward seguro

Para cada repositorio disponible y su rama actual:

```text
git -C "<ruta>" fetch origin
git -C "<ruta>" rev-list --left-right --count HEAD...origin/<rama-actual>
```

- Si `origin` o la rama remota no existe, informa y deja ese repositorio pendiente.
- Si está al día, no hagas nada. Si solo va adelantado, informa cuántos commits locales hay; no hagas push.
- Si está detrás y el árbol está limpio, ejecuta `git -C "<ruta>" pull --ff-only origin <rama-actual>`.
- Si tiene cambios sin commitear, ha divergido o falla el fast-forward, no fuerces ni descartes nada: informa y continúa.
- Al final, resume qué repositorios se validaron, actualizaron, no están clonados o requieren resolución manual.

## Paso 3 — grafo unificado

Si existe `graphify-out/graph.json` en este repo, úsalo para localizar código antes de buscar con grep: `graphify query "<pregunta>"`, `graphify path "<A>" "<B>"` o `graphify explain "<concepto>"`. El campo `repo` de cada nodo indica de qué repo viene.

Si no existe, o si algún repo del paso 2 se actualizó después de la fecha del grafo, recomienda ejecutar `/montrel:graph` y continúa sin él. No regeneres el grafo desde este wrapper.

Si `graphify --version` y `python -m graphify --version` fallan, graphify no está instalado: díselo al usuario, indica que `/montrel:graph` ofrece instalarlo y continúa buscando con grep y leyendo ficheros. No instales nada desde este wrapper.

## Paso 4 — delegar exploración

Usa la **Skill tool** para invocar `opsx:explore`, pasándole el tema del usuario. Sigue sus instrucciones. Las specs se leen solo de `openspec/` de este repo; ignora el `openspec/` de los repos de código.

## Guardrails Montrel

- Explorar no implementa: leer, buscar y diagramar sí; escribir código de negocio no.
- Nunca hagas commit, push ni merge desde este comando.
- No cambies de rama con trabajo local pendiente y no uses force-pull, reset ni stash automático.
- La conversación y los artefactos van en español. Sustenta hallazgos con `<id>/ruta:línea` o con el comando que los produjo.
