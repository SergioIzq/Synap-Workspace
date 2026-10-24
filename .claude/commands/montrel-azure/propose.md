---
name: "MONTREL Azure: Propose"
description: "Proponer un change OpenSpec multi-repo y generar artefactos de planificación"
allowed-tools: Bash(openspec:*), Bash(az:*), AskUserQuestion, Skill, TodoWrite
category: Workflow
tags: [workflow, openspec, montrel, azure-devops]
---

Propón un nuevo change de OpenSpec para el cliente de `workspace.yaml` y genera sus artefactos de planificación.

**Wrapper fino:** la creación y elaboración de artefactos la gobierna `/opsx:propose`. Montrel no duplica su flujo.

**Entrada:** nombre kebab-case, descripción del trabajo o, con seguimiento `azure-boards`, `#<n>` o la URL de un work item (`.../_workitems/edit/<n>`).

## Pasos

1. Si no hay entrada, pregunta mediante AskUserQuestion qué quiere construir o corregir. Deriva un nombre kebab-case y no continúes hasta entender la intención.
2. Resuelve la referencia de seguimiento `<ref>` según `seguimiento.tipo` de `workspace.yaml`. `<org>` es `https://dev.azure.com/<seguimiento.organization>/`, `<proyecto>` es `seguimiento.project` y `<area>` es `seguimiento.area` (si falta, el área raíz: `<proyecto>`):
   - **`azure-boards`:** si la entrada es `#<n>`, `AB#<n>` o la URL de un work item, léelo con `az boards work-item show --id <n> --organization "<org>" --output json` (`System.Title`, `System.Description`, `System.Tags`, `System.State`) y úsalo como descripción del trabajo. Si no, pregunta mediante AskUserQuestion si crear un work item, vincular uno existente (`#<n>`) o seguir sin work item. Para crearlo, infiere `<tipo>` (feature, fix, refactor, docs, test, chore o release) con la regla «Tipo de change» de `AGENTS.md`, muestra título, descripción (la intención en dos o tres líneas; el detalle vivirá en el change) y `<tipo>`, espera confirmación (el usuario puede corregir el tipo), escribe título y descripción en ficheros UTF-8 sin BOM (la descripción en HTML simple con `<p>`, porque Azure Boards la guarda como HTML) y ejecuta:

     ```text
     az boards work-item create --organization "<org>" --project "<proyecto>" --type "<seguimiento.tipo_work_item>" --area "<area>" --title "@<fichero-titulo>" --description "@<fichero-descripcion>" --fields "System.Tags=<tipo>" --output json
     ```

     Lee `id` del JSON; el estado inicial es `seguimiento.estados.propuesta`. `<ref>` es `AB#<n>`.
   - **`ninguno` o sin bloque `seguimiento`:** no hay `<ref>`.
   Si hay `<ref>`, la primera línea del `proposal.md` es `Seguimiento: <ref>`: así lo encuentran los demás commands.
3. Lee `workspace.yaml`. Si el trabajo cae en `fuera_de_alcance`, para y sugiere el flujo propio de ese repo.
   Si este repo está en una rama de `ramas.protegidas`, pregunta mediante AskUserQuestion si crear `feature/<change>` desde ella (recomendado: la propuesta se revisa por PR) o seguir. Crea la rama solo con el árbol limpio; nunca hagas stash automático.
4. Usa la **Skill tool** para invocar `opsx:propose`, pasando la entrada. Sigue sus instrucciones hasta que estén listos los artefactos requeridos por `apply.requires`, con estas restricciones:
   - El proposal indica qué repos de `workspace.yaml` se ven afectados, por id.
   - `tasks.md` se agrupa por repo con cabeceras `## N. <nombre> (<id>)`.
   - Las delta specs van contra `openspec/specs/` de este repo. Nunca leas ni uses el `openspec/` de los repos de código.
   - Si el change toca comportamiento existente que aún no tiene spec, descríbelo como `ADDED` con el comportamiento resultante.
   - En cada grupo de un repo con `pruebas` en `workspace.yaml`, `tasks.md` incluye tareas de pruebas **unitarias** y de **integración** según `pruebas.reglas`, que nombran los `#### Scenario` de las delta specs que cubren. Todo scenario que toque ese repo queda cubierto.
5. Usa TodoWrite para seguir el progreso de los artefactos.
6. Con `azure-boards` y `<ref>`, pregunta mediante AskUserQuestion si actualizar el work item: comentario con la ruta del change (`openspec/changes/<change>/`), la etiqueta de tipo de change reconciliada con el `Why` del proposal (puede diferir de la inferida al crear el work item; si cambia, dilo), una etiqueta por cada id de repo afectado del proposal (`back`, `front`…), pasarlo a `seguimiento.estados.en_curso` y asignarlo. Lee antes estado, asignado y etiquetas (`az boards work-item show --id <n> --organization "<org>" --query "{estado:fields.\"System.State\",asignado:fields.\"System.AssignedTo\".uniqueName,tags:fields.\"System.Tags\"}" --output json`). Pasa a `en_curso` solo si el estado actual es `seguimiento.estados.propuesta` (nunca lo hagas retroceder desde `cerrado`) y asígnalo solo si no tiene asignado. Calcula la lista de etiquetas conservando las demás (regla «Tipo de change» de `AGENTS.md`: una sola etiqueta de tipo), resuelve `<asignado>` con la regla «Asignado» de `AGENTS.md` y ejecuta `az boards work-item update --id <n> --organization "<org>" --state "<seguimiento.estados.en_curso>" --assigned-to "<asignado>" --discussion "@<fichero>" --fields "System.Tags=<lista separada por '; '>" --output json` (omite el flag que no aplique). Verifica el resultado leyendo `System.State` y `System.AssignedTo` y aplica el reintento de «Asignado» si hace falta; si sigue sin asignarse, dilo explícitamente en el resumen.
7. Con `azure-boards`, `<ref>` y `seguimiento.tipo_padre`, cuelga el work item del padre de su capacidad. Las capacidades del change son las carpetas de sus delta specs (`openspec/changes/<change>/specs/<capacidad>/`, con la ruta completa si está anidada).
   1. Si el work item ya tiene padre (`az boards work-item show --id <n> --organization "<org>" --expand relations --output json`, relación `System.LinkTypes.Hierarchy-Reverse`), no lo cambies: informa de cuál es y sigue.
   2. Si hay una sola capacidad, esa es la principal. Si hay varias, pregunta mediante AskUserQuestion cuál es la principal.
   3. Busca el padre por título exacto dentro del área:

      ```text
      az boards query --organization "<org>" --project "<proyecto>" --wiql "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '<proyecto>' AND [System.WorkItemType] = '<tipo_padre>' AND [System.Title] = '<capacidad>' AND [System.AreaPath] UNDER '<area>'" --output json
      ```

      Si hay más de uno, muéstralos y pregunta cuál usar.
   4. Si no existe, pregunta mediante AskUserQuestion si crearlo: `az boards work-item create --organization "<org>" --project "<proyecto>" --type "<tipo_padre>" --area "<area>" --title "<capacidad>" --output json`.
   5. Enlázalo como padre: `az boards work-item relation add --id <n> --relation-type parent --target-id <id-padre> --organization "<org>"`.
8. Anota el nombre del change, su ruta y `<ref>`; indica que el siguiente paso es `/montrel-azure:apply <change>`.
## Reglas

- Los artefactos se redactan en español; no se escribe código de negocio.
- Nunca crees work items `Task`: las tareas viven solo en `tasks.md`. Nunca asignes iteración: la planifica el equipo.
- El tipo de change nunca se expresa con el tipo de work item (siempre `seguimiento.tipo_work_item`), sino con la etiqueta de tipo. El work item se asigna y pasa a en curso aquí (paso 6); `/montrel-azure:apply` solo corrige lo que falte.
- Si el change ya existe, pregunta si continuar el existente o crear otro; no lo sobrescribas.
- Si `/opsx:propose` falla, detente y muestra el error; no suplas su lógica a mano.
- Si `az` no está autenticado (`az account show` falla), dile al usuario que ejecute `az login` y pregunta si seguir sin work item.
- Si algún repo afectado tiene `revision_docs` en `workspace.yaml`, comunica que `/montrel-azure:apply` y `/montrel-azure:pull-request` revisarán esa regla en los ficheros tocados.
