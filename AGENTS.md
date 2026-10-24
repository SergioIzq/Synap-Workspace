# Reglas del repositorio de specs multi-repo (AGENTS.md)

Este repositorio contiene **solo especificación**: specs, changes y comandos OpenSpec de un cliente. El código se edita en los repositorios hermanos. OpenCode lo carga directamente; Claude Code llega mediante `CLAUDE.md`.

## Datos del cliente: `workspace.yaml`

Todo lo específico del cliente está en [`workspace.yaml`](workspace.yaml): nombre, ramas, repos de código (id, ruta, URL, stack, alcance, build, regla de documentación `revision_docs`, modo de `grafo`), exclusiones del grafo y lo que queda fuera de alcance. **Léelo antes de actuar.** Los comandos `/montrel:*` y este fichero son genéricos: nunca escribas en ellos datos de un cliente.

Sesión de trabajo: abrir Claude Code en este repo con un `--add-dir <ruta>` por cada repo de `workspace.yaml`.

## Dónde viven las specs

- **Todas las specs y changes viven solo en `openspec/` de este repo.** Specs por capacidad de negocio, no por repo; lo exclusivo de un repo se marca con su id en mayúsculas (`[<ID>]`).
- El `openspec/` de un repo de código, si existe, **nunca se lee, se edita ni se usa como contexto**. Si contradice una spec de este repo, manda este repo.
- Las specs empiezan de cero y crecen con los changes: si un change toca comportamiento que ya existe pero aún no tiene spec, se describe como `ADDED` con el comportamiento resultante.
- Si un trabajo cae en `fuera_de_alcance`, se trabaja con el flujo propio de ese repo, no con este.

## Normas

- Specs y changes **solo** se editan en este repo; el código, solo en los repos de `workspace.yaml`.
- Gitflow en todos los repos: `ramas.integracion` es la base y las ramas de `ramas.protegidas` no reciben push directo. Cambios de rama solo con confirmación y árbol limpio; actualizaciones `pull --ff-only`; nunca forzar, descartar ni hacer stash automático.
- Misma rama `feature/<change>` en cada repo afectado. Referencia el change y su seguimiento en commits y PRs (ver «Seguimiento»).
- `tasks.md` se agrupa por repo con cabeceras `## N. <nombre> (<id>)` tomadas de `workspace.yaml`.
- Archivar un change solo cuando los PRs de código de todos los repos afectados estén completados.
- Idioma de documentación, comentarios y mensajes: español. En los repos con `revision_docs`, esa regla se revisa en los ficheros tocados antes del commit.
- Commits con rutas explícitas y mensaje UTF-8 sin BOM mediante `git commit -F <fichero>`; nunca `git commit -m`, `git add -A` ni `--no-verify`. Verifica con `git log -1 --format=%B`. Cada repo se comitea en su propio repo; nunca mezcles ficheros de repos distintos. No incluyas líneas `Co-Authored-By`.

## Seguimiento

`seguimiento` de `workspace.yaml` decide dónde se sigue cada funcionalidad: **1 change = 1 issue o work item**. El repo guarda el qué y el porqué (specs, proposal, design, tasks); el issue, quién, cuándo y en qué estado. Las tareas no se duplican en el issue: viven en `tasks.md`.

- La referencia `<ref>` (`<repo>#<n>` en `github`, `AB#<n>` en `azure-boards`) es la primera línea del `proposal.md`: `Seguimiento: <ref>`.
- `github`: `propose` crea o vincula el issue y le pone la etiqueta de propuesta; `apply` lo marca en curso y lo asigna; las PRs de código llevan `Refs <ref>`; el commit de `archive` lleva `Closes <ref>`, que lo cierra al mergearse.
- `azure-boards`: el work item es del tipo `seguimiento.tipo_work_item`; `propose` lo crea o vincula (estado `estados.propuesta`) con la etiqueta de tipo de change; `apply` lo pasa a `estados.en_curso` y lo asigna; las PRs de código llevan `#<n>` (Azure Repos lo enlaza); la PR de specs de `archive` lleva `Fixes #<n>` y, al completarse con *Complete associated work items*, lo pasa a `estados.cerrado`. `<n>` sale de `Seguimiento: AB#<n>` (se acepta también `#<n>`).
- **Tipo de change (etiqueta, `azure-boards`).** El proceso Basic no distingue bug de feature en el tipo de work item, así que el tipo va como **una** etiqueta, con el mismo vocabulario que los commits: comportamiento nuevo `feature`, corrección de un defecto o bug `fix`, reestructurar sin cambiar comportamiento `refactor`, solo documentación `docs`, solo pruebas `test`, tooling/dependencias/CI/procesos `chore`, publicación `release`. Se infiere de la descripción y, cuando existe, del `Why` del `proposal.md`; si es ambiguo, se elige el más cercano y se dice. Al reconciliar etiquetas, quita cualquier otra etiqueta de este vocabulario y conserva las demás. Azure sustituye la lista entera: escríbela separada por `; `.
- **Asignado (`azure-boards`).** El autor del trabajo: `git config user.email` del repo. Tras actualizar, lee `System.AssignedTo`; si Azure rechazó el email o el campo sigue vacío (el email de git puede no ser el de la cuenta de Azure), reintenta con `az account show --query user.name -o tsv`. Si también falla, avisa y sigue sin asignar. Si el work item ya tiene asignado, no lo cambies.
- Toda escritura en el issue o work item (crear, comentar, etiquetar, asignar, cambiar de estado) se confirma antes con el usuario. Las etiquetas no se crean desde los commands.

## Comandos Montrel

| Fase | Comando |
|---|---|
| Explorar | `/montrel:explore` |
| Proponer | `/montrel:propose` |
| Aplicar | `/montrel:apply` |
| Actualizar planificación | `/montrel:update` |
| Sincronizar specs | `/montrel:sync` |
| Pull request (por repo) | `/montrel:pull-request` |
| Archivar | `/montrel:archive` |
| Grafo de código unificado | `/montrel:graph` |

No invoques `opsx-*` directamente en el flujo normal; cada wrapper delega en el suyo.

## graphify

`graphify-out/graph.json` de este repo es un grafo unificado de todos los repos de `workspace.yaml` (artefacto local, generado con `/montrel:graph`). El campo `repo` de cada nodo indica su repo.

- Para preguntas sobre el código, usa primero `graphify query "<pregunta>"`, `graphify path "<A>" "<B>"` o `graphify explain "<concepto>"` desde este repo. Lee ficheros o usa grep solo si el grafo no basta.
- El grafo propio de un repo de código (`<ruta>/graphify-out/`) es de ese repo: se lee, pero **nunca se regenera ni se modifica** desde aquí. Nunca ejecutes `graphify update`, `extract` sin `--out` ni `hook install` en los repos de código.
- Tras modificar código, recomienda `/montrel:graph`; no lo ejecutes sin que el usuario lo pida.
- graphify es opcional. Si no está instalado (falla `graphify --version` y `python -m graphify --version`), trabaja con grep y lectura de ficheros y sugiere `/montrel:graph`, que ofrece instalarlo. Nunca instales nada sin confirmación explícita.
