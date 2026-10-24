---
name: "MONTREL: Propose"
description: "Proponer un change OpenSpec multi-repo y generar artefactos de planificación"
allowed-tools: Bash(openspec:*), Bash(gh:*), AskUserQuestion, Skill, TodoWrite
category: Workflow
tags: [workflow, openspec, montrel]
---

Propón un nuevo change de OpenSpec para el cliente de `workspace.yaml` y genera sus artefactos de planificación.

**Wrapper fino:** la creación y elaboración de artefactos la gobierna `/opsx:propose`. Montrel no duplica su flujo.

**Entrada:** nombre kebab-case, descripción del trabajo o, con seguimiento `github`, `#<n>` o la URL de un issue.

## Pasos

1. Si no hay entrada, pregunta mediante AskUserQuestion qué quiere construir o corregir. Deriva un nombre kebab-case y no continúes hasta entender la intención.
2. Resuelve la referencia de seguimiento `<ref>` según `seguimiento.tipo` de `workspace.yaml`:
   - **`github`:** si la entrada es `#<n>` o la URL de un issue de `seguimiento.repo`, léelo con `gh issue view <n> --repo <repo> --json number,title,body,labels,url` y úsalo como descripción del trabajo. Si no, pregunta mediante AskUserQuestion si crear un issue, vincular uno existente (`#<n>`) o seguir sin issue. Para crearlo, muestra título y cuerpo (la intención en dos o tres líneas; el detalle vivirá en el change), espera confirmación y ejecuta `gh issue create --repo <repo> --title "<título>" --body-file <fichero UTF-8 sin BOM> --label <etiquetas.propuesta>`. `<ref>` es `<repo>#<n>`.
   - **`azure-boards`:** pregunta mediante AskUserQuestion el work item o si no tiene. `<ref>` es `AB#<n>`.
   - **`ninguno` o sin bloque `seguimiento`:** no hay `<ref>`.
   Si hay `<ref>`, la primera línea del `proposal.md` es `Seguimiento: <ref>`: así lo encuentran los demás commands.
3. Lee `workspace.yaml`. Si el trabajo cae en `fuera_de_alcance`, para y sugiere el flujo propio de ese repo.
   Si este repo está en una rama de `ramas.protegidas`, pregunta mediante AskUserQuestion si crear `feature/<change>` desde ella (recomendado: la propuesta se revisa por PR) o seguir. Crea la rama solo con el árbol limpio; nunca hagas stash automático.
4. Usa la **Skill tool** para invocar `opsx:propose`, pasando la entrada. Sigue sus instrucciones hasta que estén listos los artefactos requeridos por `apply.requires`, con estas restricciones:
   - El proposal indica qué repos de `workspace.yaml` se ven afectados, por id.
   - `tasks.md` se agrupa por repo con cabeceras `## N. <nombre> (<id>)`.
   - Las delta specs van contra `openspec/specs/` de este repo. Nunca leas ni uses el `openspec/` de los repos de código.
   - Si el change toca comportamiento existente que aún no tiene spec, descríbelo como `ADDED` con el comportamiento resultante.
5. Usa TodoWrite para seguir el progreso de los artefactos.
6. Con `github` y `<ref>`, pregunta mediante AskUserQuestion si actualizar el issue: comentario con la ruta del change (`openspec/changes/<change>/`) y etiqueta `etiquetas.propuesta` en lugar de `etiquetas.idea` (`gh issue comment <n> --repo <repo> --body-file <fichero>` y `gh issue edit <n> --repo <repo> --add-label <propuesta> --remove-label <idea>`). Si la etiqueta no existe en el repo, avisa y no la crees.
7. Anota el nombre del change, su ruta y `<ref>`; indica que el siguiente paso es `/montrel:apply <change>`.

## Reglas

- Los artefactos se redactan en español; no se escribe código de negocio.
- Si el change ya existe, pregunta si continuar el existente o crear otro; no lo sobrescribas.
- Si `/opsx:propose` falla, detente y muestra el error; no suplas su lógica a mano.
- Si algún repo afectado tiene `revision_docs` en `workspace.yaml`, comunica que `/montrel:apply` y `/montrel:pull-request` revisarán esa regla en los ficheros tocados.
