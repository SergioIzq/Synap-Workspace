---
name: "MONTREL Azure: Apply"
description: "Implementar las tareas de un change en los repos afectados con comprobación de rama y build"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(graphify:*), AskUserQuestion, Skill, TodoWrite
category: Workflow
tags: [workflow, openspec, montrel, azure-devops]
---

Implementa las tareas de un change OpenSpec en los repos de código de `workspace.yaml`.

**Wrapper fino:** las tareas las gobierna `/opsx:apply`. Los pasos 1 y 2 añaden las comprobaciones Montrel de rama y build por repo, y el paso 4 revisa la documentación según `revision_docs`.

**Entrada:** nombre opcional del change. Si sigue ambiguo tras revisar el contexto, pregunta; nunca elijas a ciegas.

## Paso 1 — resolver change, repos afectados y ramas

1. Resuelve el change (si falta y hay varias opciones, `openspec list --json` y AskUserQuestion). Indica `Using change: <name>` y cómo reemplazarlo.
2. Lee `workspace.yaml` y `tasks.md`. Los repos afectados son los `<id>` de las cabeceras `## N. <nombre> (<id>)`. Si no hay cabeceras por repo o un id no existe en `workspace.yaml`, pregunta.
3. Para cada repo afectado, ejecuta `git -C "<ruta>" branch --show-current` y muestra una tabla `repo → rama actual`. Pregunta mediante AskUserQuestion si desea crear `feature/<change>` en cada uno desde su rama actual o seguir en la actual.
4. Si crea ramas, revisa `git -C "<ruta>" status --porcelain` en cada repo; si hay cambios, informa y no crees la rama en ese repo hasta que el usuario decida (nunca stash automático). Crea con `git -C "<ruta>" checkout -b feature/<change>`. Si ya existe, pregunta si cambiar a ella o seguir. La rama debe llamarse exactamente `feature/<change>`: `/montrel-azure:archive` la usa para decidir qué repos llevan PR.

## Paso 2 — build previo opcional

Pregunta mediante AskUserQuestion si desea compilar los repos afectados antes de implementar. Si acepta, para cada repo afectado ejecuta en orden sus comandos `build` desde la raíz del repo (`<ruta>`). Si un repo no tiene `build`, indícalo y sáltalo.

Si una build falla, muestra el error y pregunta si continuar, corregir o parar.

## Paso 3 — delegar implementación

Invoca `opsx:apply` mediante la **Skill tool**, pasando el nombre del change. Sigue sus instrucciones de lectura del contexto, bucle de tareas y actualización de checkboxes. Usa TodoWrite para el avance.

- El código de cada tarea se edita en la `ruta` del repo de su sección; en este repo solo se marcan checkboxes.
- Si una tarea es ambigua, aparece un bloqueo o una decisión de diseño, pausa y pregunta. Mantén los cambios acotados a cada tarea.

## Paso 4 — revisar documentación

Al acabar o pausar el bucle, para cada repo afectado que tenga `revision_docs` en `workspace.yaml`, ejecuta `git -C "<ruta>" status --short` y selecciona los ficheros tocados a los que aplica esa regla.

- Si no hay ninguno, omite la revisión.
- Si hay, muestra la regla y pregunta mediante AskUserQuestion si desea revisarla ahora o dejarla para el commit que hará `/montrel-azure:archive`.
- Si acepta, corrige solo la documentación que no cumpla la regla o no describa el comportamiento real.

## Reglas

- No hagas commit desde apply ni toques el work item; el código se comitea por repo al archivar, cuando `/montrel-azure:archive` abre las PRs.
- Nunca registres secretos de producción ni de staging.
- Si la implementación revela un problema de diseño, para y sugiere `/montrel-azure:update`.
- Los comentarios y la interfaz/documentación van en español.
- Para localizar código usa primero `graphify query` si existe `graphify-out/graph.json` y graphify está instalado; si no, busca con grep y lee ficheros. Nunca ejecutes `graphify update` en los repos de código.
- Al terminar, indica que el siguiente paso es `/montrel-azure:archive`, que abre las PRs de los repos con cambios, y que `/montrel-azure:graph` refresca el grafo unificado.
