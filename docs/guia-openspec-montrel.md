# Guía de aprendizaje: OpenSpec, /montrel:*, graphify y documentación

Guía para entender cómo se trabaja en un workspace multi-repo con OpenSpec y los comandos `/montrel:*`
sobre Azure DevOps (Azure Repos y Azure Boards). Usa SimacGermanLNG como ejemplo, pero todo lo
específico del proyecto vive en `workspace.yaml`: el resto es igual para cualquier cliente.

Estructura del ejemplo (`C:\REPOSITORIO AZURE\GermanLNG`), tres repos hermanos en Azure DevOps
(`montrelcorp/BRUNSBUTTEL`):

```
GermanLNG/
├── simac-german-lng-specs/       ← repo de specs: openspec/, workspace.yaml, comandos /montrel:*
├── SimacGermanGNL/               ← id back:  .NET 10, ASP.NET Core, NHibernate, SQL Server
└── simac-german-lng-frontend/    ← id front: Angular
```

---

## 1. La idea en una frase

**Primero se escribe qué debe hacer el sistema (spec), después se implementa, y al final la spec pasa a
ser la verdad oficial.** OpenSpec pone el orden; los comandos Montrel lo adaptan a varios repos, a Git y
al seguimiento en Azure Boards (work items).

---

## 2. OpenSpec

### 2.1 Conceptos

| Concepto | Dónde vive | Qué es |
|---|---|---|
| **Spec** | `openspec/specs/<capacidad>/spec.md` | La verdad **actual** de una capacidad de negocio (`secuencia-entrada`, `pesajes`, `albaranes`…). Describe lo que ya está en producción. |
| **Change** | `openspec/changes/<change>/` | Una propuesta de cambio en curso. Contiene sus artefactos y sus delta specs. |
| **Delta spec** | `openspec/changes/<change>/specs/<capacidad>/spec.md` | Solo **lo que cambia** respecto a la spec principal. |
| **Archivo** | `openspec/changes/archive/<fecha>-<change>/` | Changes terminados. Su historia (proposal, design) explica el porqué de cada decisión. |
| **Schema** | `openspec/config.yaml` → `schema: spec-driven` | Qué artefactos tiene un change y en qué orden. |

### 2.2 Artefactos de un change (schema `spec-driven`)

```
openspec/changes/barrera-entrada-sincrona-tactil/
├── proposal.md     ← QUÉ y POR QUÉ (Why, Scope, Non-goals, repos afectados)
├── specs/          ← QUÉ debe hacer el sistema (deltas por capacidad)
│   └── secuencia-entrada/spec.md
├── design.md       ← CÓMO (decisiones técnicas, alternativas, riesgos, migración)
└── tasks.md        ← PASOS de implementación con checkboxes
```

### 2.3 Formato de una spec

Las palabras clave del formato van en inglés; el contenido, en español.

```markdown
### Requirement: Apertura de la barrera de entrada
El sistema SHALL abrir la barrera de entrada solo cuando la carga esté autorizada y el peso de entrada registrado.

#### Scenario: Carga autorizada con peso registrado
- **WHEN** el operador confirma la entrada en el terminal táctil de una carga autorizada con peso de entrada
- **THEN** la barrera se abre y la secuencia de entrada avanza al siguiente paso

#### Scenario: Carga sin peso de entrada
- **WHEN** el operador confirma la entrada de una carga sin peso de entrada registrado
- **THEN** la barrera no se abre y el terminal muestra el motivo en español
```

- **Requirement**: una obligación del sistema (`SHALL` / `SHALL NOT` / `MAY`).
- **Scenario**: un ejemplo verificable `WHEN` → `THEN`. Cada requirement tiene al menos uno.

### 2.4 Delta specs: las cuatro operaciones

| Sección | Significado |
|---|---|
| `## ADDED Requirements` | Requirement nuevo. |
| `## MODIFIED Requirements` | Sustituye un requirement existente (se copia **entero**, con el texto nuevo). |
| `## REMOVED Requirements` | Elimina un requirement. |
| `## RENAMED Requirements` | Cambia el título de un requirement. |

Regla del workspace: si un change toca comportamiento que **ya existe pero aún no tiene spec**, se
describe como `ADDED` con el comportamiento resultante. Las specs empiezan de cero y crecen con los
changes.

### 2.5 La CLI `openspec`

Los comandos `/opsx:*` la usan por debajo; conviene conocerla para depurar.

| Comando | Para qué |
|---|---|
| `openspec init --tools claude .` | Genera (una vez por máquina) los comandos `/opsx:*` y las skills en `.claude/`. Respeta el `config.yaml` existente. |
| `openspec list --json` | Changes activos. |
| `openspec new change "<nombre>"` | Crea la carpeta del change. |
| `openspec status --change "<nombre>" --json` | Estado de los artefactos (`done`, `ready`, `blocked`), rutas reales y schema. |
| `openspec instructions <artefacto> --change "<nombre>" --json` | Plantilla e instrucciones para crear un artefacto. |
| `openspec instructions apply --change "<nombre>" --json` | Tareas pendientes y contexto para implementar. |
| `openspec validate` | Valida formato de specs y changes. |
| `openspec archive` | Mueve el change al archivo. |

Versión mínima: OpenSpec ≥ 1.9.

### 2.6 `openspec/config.yaml`

Es el "prompt fijo" que OpenSpec inyecta a la IA en cada operación:

- `schema`: el flujo (`spec-driven`).
- `context`: **solo contexto de negocio** (qué es el producto, idioma, convenciones). Los datos técnicos
  (repos, ramas, build) van en `workspace.yaml`, no aquí.
- `rules.<artefacto>`: reglas por artefacto (p. ej. proposal ≤ 500 palabras con Scope y Non-goals;
  `tasks.md` agrupado por repo).
- `operations.<op>.guidance`: consejos por operación (`apply`, `archive`).

---

## 3. Las tres capas de comandos

```
┌───────────────────────────────────────────────────────────────┐
│  /montrel:*                          ← tú usas ESTOS          │
│  Wrappers: multi-repo, ramas, build, Git, PRs, seguimiento    │
├───────────────────────────────────────────────────────────────┤
│  /opsx:*  (+ skills openspec-*)      ← generados por openspec │
│  Lógica OpenSpec: crear artefactos, tareas, sync, archivo     │
├───────────────────────────────────────────────────────────────┤
│  CLI openspec                        ← estado y validación    │
└───────────────────────────────────────────────────────────────┘
```

### 3.1 ¿Qué es un "wrapper fino"?

Un comando Montrel **no reimplementa** OpenSpec: hace sus comprobaciones antes y después, y en medio
invoca el `/opsx:*` equivalente con la Skill tool. Ventajas:

- Cuando OpenSpec se actualiza (`openspec init` de nuevo), los wrappers siguen funcionando.
- Las reglas del proyecto (ramas, seguimiento, idioma) están en un solo sitio.
- Si `/opsx:*` falla, el wrapper **se detiene** y muestra el error; nunca suple su lógica a mano.

En el flujo normal **no se invocan los `/opsx:*` directamente**.

### 3.2 Los comandos generados por OpenSpec (`/opsx:*`)

| Comando | Qué hace |
|---|---|
| `/opsx:explore` | Modo "compañero de pensamiento": investiga, compara, dibuja. **Nunca implementa.** |
| `/opsx:propose` | Crea el change y genera todos los artefactos que pide el schema. Se para al terminar la planificación. |
| `/opsx:apply` | Lee contexto y tareas, implementa una a una y marca checkboxes. |
| `/opsx:update` | Revisa los artefactos y los reconcilia entre sí en cualquier dirección. Nunca toca código. |
| `/opsx:sync` | Fusiona las delta specs en las specs principales de forma inteligente e idempotente. |
| `/opsx:archive` | Comprueba artefactos y tareas, sincroniza si hace falta y mueve el change al archivo. |

### 3.3 Los wrappers Montrel: qué añaden

| Wrapper | Antes de delegar | Delega en | Después |
|---|---|---|---|
| **explore** | Clona repos que falten, comprueba rama de integración, `fetch` + `pull --ff-only` seguro, consulta el grafo | `/opsx:explore` | — |
| **propose** | Crea o vincula el work item, comprueba `fuera_de_alcance`, ofrece rama si estás en una protegida | `/opsx:propose` (con restricciones multi-repo) | Actualiza tags, comenta en el work item y lo cuelga del `Feature` de su capacidad |
| **apply** | Tabla repo → rama, ofrece `feature/<change>` en cada repo afectado, build previo opcional | `/opsx:apply` (exigiendo pruebas unitarias y de integración) | Ejecuta las pruebas (`pruebas`) y revisa la documentación (`revision_docs`) |
| **update** | Resuelve el change y sus rutas reales | `/opsx:update` | Recomienda el siguiente comando |
| **sync** | Resuelve el change | `/opsx:sync` | Anota specs tocadas (para el commit de archive) |
| **pull-request** | *No delega*: lo hace todo él. Normalmente lo invoca `archive` (modo archive) | — | Commit Montrel, push, PR, verificación de codificación |
| **archive** | Detecta qué repos tienen cambios en `feature/<change>` | `/opsx:archive` y `pull-request` | PRs de código, commit y PR de specs, tag `cerrado` |
| **graph** | *No delega*: construye el grafo unificado | — | Resumen de nodos y avisos |

### 3.4 Restricciones multi-repo que imponen los wrappers

- **Specs solo en este repo.** El `openspec/` de un repo de código, si existe, nunca se lee ni se usa.
- **Un change es uno solo aunque toque varios repos**: un único proposal, design y tasks.
- `tasks.md` se agrupa por repo con cabeceras `## N. <nombre> (<id>)`, con el `id` de `workspace.yaml`.
  Así `apply` sabe en qué repos crear la rama; `archive` lo contrasta con los cambios reales.
- Lo exclusivo de un repo dentro de una spec se marca con su id en mayúsculas: `[BACK]`, `[FRONT]`.
- Los repos de código son **hermanos** del repo de specs (`ruta: ../SimacGermanGNL`). Abre la sesión en
  `simac-german-lng-specs` con un `--add-dir` por cada repo de código.
- Lo que está en `fuera_de_alcance` (en SimacGermanLNG: DatosControl, Dialogos, PruebasWindowsForm, el
  `.sqlproj` y los clones COCO, DIALOGOS, SERVICIO_MEMORIA_PERIODICAS y SINOPTICOS) no se toca con este
  flujo.

---

## 4. El ciclo de vida de un change

```
explore ──► propose ──► (PR de specs) ──► apply ──► archive ──► merge manual de las PRs
               ▲                            │           │
               └────────── update ◄─────────┘           └─► PRs automáticas: back / front (según cambios) + specs
```

| Paso | Comando | Resultado | ¿Commit? |
|---|---|---|---|
| 1 | `explore [tema]` | Repos al día, problema entendido | No |
| 2 | `propose <idea \| #n>` | Change con proposal, specs, design, tasks; work item creado en `en-curso` | No |
| 3 | `update [change]` | Plan reconciliado si cambia algo | No |
| 4 | `apply [change]` | Código implementado en `feature/<change>` de cada repo | No |
| 5 | `sync [change]` *(opcional)* | Specs principales actualizadas sin archivar | No |
| 6 | `archive [change]` | Change archivado; PR de cada repo de código con cambios y PR de specs; work item en `cerrado` | Sí, con confirmación |
| 7 | (merge manual de las PRs) | Primero las de código, **la de specs la última**; esta cierra el work item | — |
| — | `graph` | Grafo de código unificado regenerado (tras `apply` o cuando falte) | No |

### 4.1 Cómo decide `archive` qué PRs abrir

Sin preguntar. Revisa **todos** los repos de `workspace.yaml` y abre PR en los que tengan la rama
`feature/<change>` con commits por delante de `develop` o con cambios sin commitear:

| Cambios en… | PRs que abre |
|---|---|
| Solo backend | `back` + `specs` |
| Solo frontend | `front` + `specs` |
| Backend y frontend | `back` + `front` + `specs` |
| Ningún repo de código | Solo `specs` (avisa) |

Para cada PR delega en `pull-request` en **modo archive**: repo, rama y base ya vienen decididos, y si la
PR ya existe la reutiliza. Lo único que pregunta es la confirmación del commit (si hay cambios sin
commitear) y la del título y cuerpo de cada PR. Si `tasks.md` y los cambios reales no coinciden, lo
avisa en la tabla, pero manda Git.

Por eso la rama de cada repo debe llamarse exactamente `feature/<change>`, como la crea `apply`.

**Contrapartida:** el change se archiva antes de que se revise y mergee el código. Para que las specs de
`develop` no describan algo que aún no está, **la PR de specs se mergea la última**, cuando las de código
ya están completadas. Si una PR de código se rechaza, la de specs tampoco debe completarse.

### 4.2 Pruebas en el ciclo

Cada repo puede declarar en `workspace.yaml` un bloque `pruebas`. Si lo tiene, el flujo trata las pruebas
como parte del trabajo, no como un extra:

| Momento | Qué pasa con las pruebas |
|---|---|
| `propose` | `tasks.md` incluye, en el grupo de cada repo, tareas de pruebas **unitarias** y de **integración** que nombran los `#### Scenario` que cubren. Todo scenario del repo queda cubierto. |
| `update` | Mantiene esas tareas y cubre los scenarios nuevos o cambiados. |
| `apply` (implementación) | Todo comportamiento nuevo o cambiado lleva sus pruebas según `pruebas.reglas`. Una tarea no se marca hecha sin ellas. Si `tasks.md` no las tiene, avisa y sugiere `update`. |
| `apply` (al terminar) | Ejecuta `pruebas.unitarias` y, si existe el fichero de `pruebas.integracion.requiere`, `pruebas.integracion.comandos`. Muestra la tabla de resultados; si algo falla, pregunta si corregir, seguir o parar. Nunca desactiva una prueba para que pase. |

**Del scenario a la prueba.** Los scenarios son la especificación verificable; las pruebas, su
comprobación:

```
#### Scenario: Carga sin peso de entrada                ──►  [back]  integración: la barrera no se abre y la carga no avanza
- WHEN el operador confirma la entrada sin peso          ──►  [back]  unitaria: la regla rechaza la carga sin peso
- THEN la barrera no se abre y se muestra el motivo      ──►  [front] integración: el terminal muestra el motivo en español
```

**Unitaria o de integración:**

| | Unitaria | Integración |
|---|---|---|
| Qué prueba | Una pieza aislada (regla, negocio, servicio, componente) | Varias piezas reales juntas |
| Dependencias | Dobles (sustitutos) | Reales: base de datos en back; TestBed con plantilla y servicios en front |
| Velocidad y requisitos | Rápida, sin nada externo | Más lenta; en back necesita la base de pruebas local |

**Configuración en SimacGermanLNG.** El backend ya tiene la suite xUnit `SimacGermanGNL.Tests.AccesoDatos`,
con `Unitarios/` (namespace `….Unitarios`) e `Integracion/` contra una SQL Server local configurada en un
`comun.json` que no se versiona. El frontend tiene Karma y Jasmine configurados, pero todavía ningún
`.spec.ts`: el primer change con pruebas de front las estrena.

```yaml
repos:
  - id: back
    # …
    pruebas:
      reglas: >-
        xUnit en SimacGermanGNL/Tests/SimacGermanGNL.Tests.AccesoDatos, siguiendo su README.md.
        Unitarias en Unitarios/ (namespace SimacGermanGNL.Tests.AccesoDatos.Unitarios) con dobles, sin base de datos.
        Integración en Integracion/, sobre IntegracionTestBase o SecuenciaIntegracionTestBase, en la colección
        «Integración con base de datos», registrando la limpieza de todo lo que crean.
      unitarias:
        - dotnet test SimacGermanGNL/Tests/SimacGermanGNL.Tests.AccesoDatos/SimacGermanGNL.Tests.AccesoDatos.csproj --filter "FullyQualifiedName~.Unitarios." -v q -nologo
      integracion:
        requiere: SimacGermanGNL/Tests/SimacGermanGNL.Tests.AccesoDatos/comun.json
        comandos:
          - dotnet test SimacGermanGNL/Tests/SimacGermanGNL.Tests.AccesoDatos/SimacGermanGNL.Tests.AccesoDatos.csproj --filter "FullyQualifiedName!~.Unitarios." -v q -nologo

  - id: front
    # …
    pruebas:
      reglas: >-
        Jasmine y Karma con TestBed. Unitarias en <fichero>.spec.ts junto al fichero probado (servicios, pipes,
        funciones, componentes con dependencias simuladas). Integración en <fichero>.integration.spec.ts:
        componente con su plantilla y servicios reales, HTTP con provideHttpClientTesting y HttpTestingController,
        sin backend real.
      unitarias:
        - npx ng test --watch=false --browsers=ChromeHeadless   # ejecuta todas las .spec.ts, también las de integración
```

En el frontend un solo comando ejecuta ambos tipos, porque las de integración no necesitan nada externo.
Las de backend se separan por namespace para poder ejecutar las unitarias aunque no haya base de pruebas.

---

## 5. Seguimiento: work items de Azure Boards

**1 change = 1 work item.** El repo guarda el qué y el porqué; el work item, quién, cuándo y en qué
estado. Las tareas no se copian: viven en `tasks.md`.

El change recuerda su work item con la **primera línea de `proposal.md`**: `Seguimiento: #<n>`.

### 5.1 Vida del work item

| Momento | Qué le pasa al work item |
|---|---|
| Backlog | Work item con tag `idea` |
| `propose` | `az boards work-item create/show` en el área del proyecto, tag `en-curso` (sustituye a `idea` si venía del backlog) y tags de repos afectados (`back`, `front`), comentario con la ruta del change (`--discussion`) y enlace al `Feature` de su capacidad |
| `apply` | Nada: no toca el work item |
| `archive` → PRs de código | Cuerpo con `#12` y `--work-items 12`. **Aviso:** desmarcar *"Complete associated work items after merging"* al completar la PR |
| `archive` → specs | Commit con `Fixes #12`, PR de specs y tag `en-curso` → `cerrado` |
| Cierre real | Al completar la PR de specs en la rama por defecto, Azure Repos lo pasa al estado resuelto/cerrado de la plantilla |

Reglas:

- En los repos de código **nunca** se usa `Fixes`: el work item se cierra con el commit de archive, en el
  repo de specs.
- En `propose`, toda escritura en el work item (crear, comentar, cambiar tags, enlazar el `Feature`) se
  confirma antes. En `archive`, el paso a `cerrado` es automático.
- El tag `cerrado` se pone al **abrir** las PRs, no al mergearlas: indica que el trabajo está entregado
  para revisión. El estado del work item (Resolved/Closed) sí cambia al completarse la PR de specs.
- Nadie asigna el work item automáticamente: se asigna a mano en Azure Boards.
- Los tags se crean solos en Azure; no hace falta darlos de alta.

### 5.2 Configuración en `workspace.yaml`

```yaml
seguimiento:
  tipo: azure-boards
  organizacion: montrelcorp
  proyecto: BRUNSBUTTEL
  area: BRUNSBUTTEL            # área raíz del proyecto
  tipo_work_item: User Story   # según la plantilla de proceso del proyecto
  tipo_padre: Feature          # un Feature por capacidad; sin él no se enlaza padre
  etiquetas: { idea: idea, en_curso: en-curso, cerrado: cerrado }
  # estados: { en_curso: Active }   # opcional
```

> El `workspace.yaml` de SimacGermanLNG aún no tiene bloque `seguimiento`: sin él, los comandos
> trabajan sin work item. Añádelo para activar este ciclo.

> Nota: se usa `#<n>`, no `AB#<n>`. `AB#` sirve para enlazar work items desde repos que no están en
> Azure Repos; con el código en Azure Repos, `#<n>` es lo que enlaza y cierra.

### 5.3 Organización en Azure Boards

Los work items no pertenecen a un repo sino al **proyecto** `BRUNSBUTTEL`, compartido por los tres
repos. Se organizan así:

| Nivel | Qué se usa | Quién lo pone |
|---|---|---|
| **Área** | Área raíz `BRUNSBUTTEL` (`seguimiento.area`) | `propose` al crear (`--area`) |
| **Padre** | Un `Feature` por capacidad de negocio, con el mismo nombre que su carpeta en `openspec/specs/` | `propose`, tras generar las delta specs |
| **Change** | Un `User Story` por change | `propose` |
| **Tags de estado** | `idea` (backlog) → `en-curso` → `cerrado` | `propose` y `archive` |
| **Tags de repo** | `back`, `front` según los repos afectados del proposal | `propose` |
| **Iteración** | Sprint | A mano: la planifica el equipo |
| **Tasks** | **No se crean** work items `Task` | Las tareas viven solo en `tasks.md` |

```
BRUNSBUTTEL
├── Feature: secuencia-entrada
│   ├── User Story #120  barrera-entrada-sincrona-tactil     [en-curso, back, front]
│   └── User Story #118  peso-entrada-sincrona-tactil        [cerrado, back]
└── Feature: albaranes
    └── User Story #125  alinear-isletas-generacion-albaran  [en-curso, back]
```

Cómo elige `propose` el `Feature`:

1. Las capacidades del change son las carpetas de sus delta specs
   (`openspec/changes/<change>/specs/<capacidad>/`). Si hay varias, pregunta cuál es la principal.
2. Busca un `Feature` con ese título exacto dentro del área (consulta WIQL con `az boards query`).
3. Si no existe, pregunta si crearlo. Así los `Feature` crecen a la vez que `openspec/specs/`.
4. Lo enlaza como padre (`az boards work-item relation add --relation-type parent`). Si el work item ya
   tenía padre, no lo cambia.

Consulta útil para el board: work items del área con tag `en-curso`, agrupados por padre.
Así se ven los changes vivos de cada capacidad.

---

## 6. Convenciones Git

| Regla | Detalle |
|---|---|
| Ramas | `ramas.integracion` (`develop`) es la base; `ramas.protegidas` (`main`, `develop`) nunca reciben push directo. Misma rama `feature/<change>` en cada repo afectado. |
| Cambiar de rama | Solo con confirmación y árbol limpio. Nunca stash automático, reset ni descartar trabajo. |
| Actualizar | Solo `pull --ff-only`. Nunca force-push. |
| Asunto del commit | `<tipo>/<YYYY-MM-DD>_<descripcion_breve>` (tipo: `feature`, `fix`, `refactor`, `docs`, `test`, `chore`, `release`). |
| Cuerpo del commit | Línea del change y `<ref>`, `Motivo:`, `Cambios:`, `Ficheros modificados:`. |
| Cómo se comitea | Mensaje en fichero UTF-8 sin BOM y `git commit -F <fichero>`. `git add` de rutas explícitas. Verificar con `git log -1 --format=%B`. |
| Prohibido | `git commit -m`, `git add -A`/`git add .`, `--no-verify`, `--amend`, líneas `Co-Authored-By`, mezclar ficheros de repos distintos. |
| PR | Título y cuerpo desde fichero (`@fichero` en `az repos pr create`). Cuerpo con *Motivo de los cambios*, *Descripción de la solución*, *Archivos modificados*. Nunca se mergea desde el comando. |

**¿Por qué tanto fichero UTF-8?** En la consola de Windows, un argumento con tildes o `ñ` puede llegar
corrompido a `git` o `az` según el codepage. Desde fichero, no.

---

## 7. graphify

### 7.1 Qué es

graphify convierte código en un **grafo de conocimiento** (nodos = clases, funciones, ficheros; aristas
= llamadas, imports, herencia). La IA lo consulta antes de leer ficheros a ciegas, con mucho menos
contexto que un grep.

### 7.2 El grafo unificado del workspace

`/montrel:graph` genera `graphify-out/graph.json` en el repo de specs (artefacto local, en
`.gitignore`) a partir de todos los repos de `workspace.yaml`:

```
SimacGermanGNL ────────────► (propio)  ──► filtrar ──► graphify-out/repos/back/…/graph.json  ─┐
                                                                                             ├──► merge-graphs ──► graphify-out/graph.json
simac-german-lng-frontend ─► (extraer) ──► filtrar ──► graphify-out/repos/front/…/graph.json ─┘
```

En SimacGermanLNG el backend usa `grafo: propio` (el repo ya mantiene su `graphify-out/`) y el frontend
`grafo: extraer`.

| Modo (`grafo:` en `workspace.yaml`) | Comportamiento |
|---|---|
| `propio` | Usa el grafo que el repo ya mantiene (`<ruta>/graphify-out/graph.json`). **Nunca se regenera desde aquí.** Avisa si es más antiguo que el último commit. |
| `extraer` | `graphify extract "<ruta>" --code-only --out "graphify-out/cache/<id>"`: AST local, sin LLM ni API key, incremental. |
| `ninguno` | El repo no entra en el grafo. |
| *(omitido)* | `propio` si el repo tiene grafo; si no, `extraer`. |

- **Filtrado:** `scripts/graphify_filtrar.py` quita los nodos cuyo `source_file` empieza por un prefijo
  de `graphify.excluir` (p. ej. `openspec/`, `.claude/`), sus aristas y sus miembros en hiperaristas. No
  modifica el origen y tiene una autocomprobación con `assert`.
- **Fusión:** la carpeta `repos/<id>/` hace que cada nodo lleve `repo: <id>`, así se sabe de qué repo viene.

### 7.3 Uso diario

```bash
graphify query "¿cómo se genera el albarán de una carga?"   # subgrafo relevante para una pregunta
graphify path "SecuenciaEntrada" "Albaran"                   # cómo se conectan dos conceptos
graphify explain "Pesaje"                                    # un concepto en detalle
```

Orden recomendado: **grafo primero, grep y lectura después** si el grafo no basta.

### 7.4 Hooks

`.claude/settings.json` registra `graphify hook-guard` antes de `Bash`/`Grep` y `Read`/`Glob`: recuerda a
la IA que use el grafo antes de buscar a ciegas. Termina con `|| exit 0`, así que **si graphify no está
instalado no hace nada**.

### 7.5 Requisitos e instalación

- Python ≥ 3.10 (en Windows, el alias de Microsoft Store no cuenta) y graphify ≥ 0.9.80 (paquete PyPI
  `graphifyy`, con doble `y`).
- `/montrel:graph` detecta lo que falta y ofrece: instalar (con confirmación), ver instrucciones o
  continuar sin grafo.

```bash
python -m pip install --user --upgrade "graphifyy>=0.9.80"
```

### 7.6 Reglas

- Nunca escribir en los repos de código: ni `graphify update`, ni `extract` sin `--out`, ni `hook install`.
- No usar `extract` sin `--code-only` (la extracción semántica necesita LLM y API key).
- graphify es **opcional**: todo el flujo funciona sin él.
- Regenerar con `/montrel:graph` después de `apply` o cuando `explore` avise de que el grafo está
  desactualizado.

---

## 8. Documentación del workspace

### 8.1 Qué fichero guarda qué

Cada dato vive en **un solo sitio**; los demás enlazan.

| Fichero | Contenido | Lo lee |
|---|---|---|
| `README.md` | Guía para personas: filosofía, flujo de trabajo y comandos; igual para todos los clientes | Personas |
| `AGENTS.md` | **Fuente única de reglas** para agentes (Claude Code y OpenCode) | IA |
| `CLAUDE.md` | Solo un puntero a `AGENTS.md` y `workspace.yaml`; no duplica reglas | Claude Code |
| `workspace.yaml` | **Único fichero que cambia entre proyectos**: cliente, ramas, seguimiento, repos (id, ruta, url, stack, alcance, build, `pruebas`, `revision_docs`, grafo), exclusiones, fuera de alcance | Comandos Montrel |
| `openspec/config.yaml` | Contexto de **negocio** y reglas por artefacto para OpenSpec | CLI openspec / `/opsx:*` |
| `openspec/specs/` | La verdad actual de cada capacidad | Todos |
| `openspec/changes/archive/` | El porqué histórico de cada decisión | Todos |
| `.claude/commands/` | Comandos `opsx` (generados) y `montrel` (genéricos) | IA |

Regla de oro: **los comandos `/montrel:*` y `AGENTS.md` son genéricos**. Nunca se escriben en ellos datos
de un cliente; eso va en `workspace.yaml`.

### 8.2 `revision_docs`: documentación que se revisa sola

Un repo de `workspace.yaml` puede declarar una regla de documentación. En SimacGermanLNG la tiene el
backend:

```yaml
repos:
  - id: back
    revision_docs: "En los .cs tocados, los miembros public/protected llevan comentarios XML (/// <summary>, <param>, <returns>, <exception>, <remarks>) que reflejan el comportamiento actual."
```

El frontend no declara ninguna, así que en `front` no se revisa nada.

Se aplica en dos momentos, **solo sobre los ficheros tocados**:

1. **Al terminar `apply`**: si algún fichero tocado está afectado, pregunta si revisarla ahora o dejarla
   para el commit de `archive`.
2. **En `archive`**, cuando `pull-request` construye el commit de cada repo de código.

Solo se corrige la documentación que no cumpla la regla o no describa el comportamiento real. `propose`
avisa de que esa revisión ocurrirá.

### 8.3 Idioma

El `context` de `openspec/config.yaml` de SimacGermanLNG fija «Trabajar y documentar en español»:
specs, artefactos, comentarios, commits y PRs. Los nombres de capacidades y changes van en kebab-case
(`secuencia-entrada`, `barrera-entrada-sincrona-tactil`). Solo las palabras clave de OpenSpec
(`## ADDED Requirements`, `SHALL`, `WHEN`, `THEN`…) se mantienen en inglés.

---

## 9. Chuleta

```text
¿Idea nueva?                    /montrel:explore <tema>  →  /montrel:propose <idea | #n>
¿Cambió el plan?                /montrel:update <change>
¿Implementar?                   /montrel:apply <change>
¿Specs al día sin archivar?     /montrel:sync <change>
¿Implementado?                  /montrel:archive <change>   (abre las PRs: back/front según cambios + specs)
¿PR suelta fuera del flujo?     /montrel:pull-request <id> <rama>
¿Grafo viejo o inexistente?     /montrel:graph
```

### Errores frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `apply` no sabe qué repos tocar | `tasks.md` sin cabeceras `## N. <nombre> (<id>)` | `/montrel:update` para reagrupar |
| `apply` avisa de que faltan tareas de pruebas | El change se propuso antes de añadir `pruebas` al repo | `/montrel:update` para añadirlas |
| Las pruebas de integración de back salen «saltadas» | No existe el `comun.json` local de la base de pruebas | Configurarlo según el README de `SimacGermanGNL.Tests.AccesoDatos` |
| `ng test` no arranca | No hay Chrome instalado para `ChromeHeadless` | Instalar Chrome o ajustar el comando en `pruebas` |
| `archive` no abre PR de un repo que sí cambió | La rama no se llama `feature/<change>` | Renombrar la rama o abrir la PR con `/montrel:pull-request` |
| Las specs de `develop` describen algo que no está en el código | Se completó la PR de specs antes que las de código | Mergear siempre la PR de specs la última |
| `archive` vuelve a ejecutarse y no duplica PRs | Es lo esperado: en modo archive las PRs existentes se reutilizan | — |
| El seguimiento se cerró antes de tiempo (Azure) | Se dejó marcada *"Complete associated work items"* en una PR de código | Reabrir el work item; desmarcar la casilla la próxima vez |
| Tildes rotas en commit o PR | Texto pasado como argumento | Siempre desde fichero UTF-8 sin BOM |
| `graphify` no se encuentra | Paquete instalado pero `Scripts` fuera del `PATH` | Usar `python -m graphify` |
| La IA lee el `openspec/` de un repo de código | Violación de regla | Solo cuenta el `openspec/` del repo de specs |
