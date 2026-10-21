# Synap

Segundo cerebro personal: captura de notas, snippets de código y enlaces con fricción cero desde cualquier dispositivo (incluido iPhone sin Mac), búsqueda potente, y un asistente con IA que conecta tus notas entre sí y responde preguntas ancladas en tu propio contenido ("tengo este fallo, ¿cómo lo resolví la última vez?").

Este repo es el workspace de OpenSpec (specs, diseño técnico, tareas) más la orquestación (`docker-compose.yml`) y los runbooks (`docs/`) del proyecto — **no contiene código de aplicación**. El código vive en dos repos hermanos:

- [Synap-Backend](https://github.com/SergioIzq/Synap-Backend) — API en .NET (DDD + Hexagonal + CQRS) + servicio de IA en Python (FastAPI)
- [Synap-Frontend](https://github.com/SergioIzq/Synap-Frontend) — PWA en Angular

> - **Repos, ramas, build y alcance:** [`workspace.yaml`](workspace.yaml).
> - **Contexto de negocio para la IA:** `context` de [`openspec/config.yaml`](openspec/config.yaml).
> - **Reglas para agentes:** [`AGENTS.md`](AGENTS.md).

## Por qué está separado así

Cada feature suele tocar backend y frontend a la vez, así que este workspace vive un nivel por encima de ambos repos para poder diseñarlos con visión de los dos simultáneamente — mientras que el código de cada app se versiona y despliega de forma independiente (igual que [Kash-Backend](https://github.com/SergioIzq/Kash-Backend)/[Kash-Frontend](https://github.com/SergioIzq/Kash-Frontend), el proyecto anterior de Sergio del que Synap hereda su arquitectura).

Un change es **uno solo** aunque toque los dos repos: un único `proposal`, `design` y `tasks`. Las specs son por capacidad de negocio (`knowledge-vault`, `ai-assistant`, `reminders`…), no por repo; lo exclusivo de un repo se marca `[BACK]` o `[FRONT]`.

## Clonar el proyecto completo

```bash
git clone https://github.com/SergioIzq/Synap-Workspace.git Synap
cd Synap
git clone https://github.com/SergioIzq/Synap-Backend.git
git clone https://github.com/SergioIzq/Synap-Frontend.git
```

Quedan como tres repos independientes dentro de la misma carpeta `Synap/` (`.gitignore` excluye los dos de código). Si falta alguno, `/montrel:explore` lo clona solo desde la `url` de `workspace.yaml`.

Después, una vez por máquina, genera los comandos `opsx` y las skills de OpenSpec (respeta el `config.yaml` existente):

```bash
openspec init --tools claude .
```

Abre Claude Code en esta carpeta. Como los dos repos de código están dentro, no hace falta `--add-dir`.

## Levantar todo con Docker Compose

```bash
cp .env.example .env   # rellena POSTGRES_PASSWORD
docker compose up --build
```

Levanta Postgres (con `pgvector`), la API, el servicio de IA y el frontend — ver `docker-compose.yml`.

La web queda en http://localhost:4200 y llama a la API en el mismo origen (`/api`), igual que en producción. Aquí es el propio nginx del frontend quien reenvía `/api/` a `synap-api`, porque `docker-compose.yml` le define `SYNAP_API_UPSTREAM=http://synap-api:80`. En producción esa variable **no** se define: el proxy del VPS ya enruta `/api` y el contenedor solo sirve la SPA.

Efecto secundario en local: la API ve todas las peticiones como si vinieran del nginx del frontend (no está en `ForwardedHeaders__KnownProxies`), así que el límite de intentos de login por IP es compartido por todos los clientes que entren por el puerto 4200.

## Cómo se trabaja un change

```
explore ──► propose ──► (PR de specs) ──► apply ──► pull-request (por repo) ──► merge ──► archive
               ▲                            │
               └────────── update ◄─────────┘
```

| Comando | Qué hace | Commit |
|---|---|---|
| `/montrel:explore [tema]` | Clona o valida los repos de `workspace.yaml`, comprueba que están en `main` y al día (solo `--ff-only`), y explora con el grafo. No escribe código. | No |
| `/montrel:propose <idea \| #issue>` | Crea o vincula el issue, crea el change y genera `proposal`, `design`, `tasks` (agrupado por repo) y las delta specs. Si este repo está en `main`, ofrece una rama para revisar la propuesta por PR. | No |
| `/montrel:update [change]` | Reconcilia los artefactos cuando el plan cambia. Nunca toca código. | No |
| `/montrel:apply [change]` | Marca el issue en curso, crea la rama del change en cada repo afectado, ejecuta su `build` si lo pides e implementa las tareas. | No |
| `/montrel:pull-request [id] [rama]` | Un repo cada vez: commit con la convención Montrel, push y PR en GitHub con `gh`. | Sí, con confirmación |
| `/montrel:sync [change]` | Fusiona las delta specs en `specs/` sin archivar (opcional: `archive` también lo hace). | No |
| `/montrel:archive [change]` | Archiva cuando las PRs de código están mergeadas y comitea aquí, nunca en `main`. | Sí, con confirmación |
| `/montrel:graph` | Regenera el grafo de código unificado de los dos repos. | No |

Reglas que conviene tener presentes:

- Specs y changes solo se editan aquí; el código, solo en `Synap-Backend` y `Synap-Frontend`.
- `main` está protegida en los tres repos: todo entra por PR, nunca por push directo, y nunca se fuerza un push.
- Se archiva solo cuando las PRs de todos los repos afectados están mergeadas, porque las specs describen lo que ya está en `main`.
- Nada irreversible sin confirmación: ni commit, ni push, ni cambio de rama.

## Seguimiento con GitHub Issues

**1 change = 1 issue** en este repo. El change guarda el qué y el porqué; el issue, el quién, el cuándo y el estado. Las tareas no se copian al issue: viven en `tasks.md`.

| Momento | En el issue |
|---|---|
| Idea | Issue con etiqueta `idea`: es el backlog |
| `/montrel:propose #12` | Lee el issue como entrada, comenta la ruta del change y pasa a `propuesta` |
| `/montrel:apply` | Pasa a `en-curso` y se te asigna |
| `/montrel:pull-request` | Cada PR de código lleva `Refs SergioIzq/Synap-Workspace#12`: el issue muestra las PRs de los dos repos |
| `/montrel:archive` | El commit lleva `Closes SergioIzq/Synap-Workspace#12`: el issue se cierra al mergear esa PR |

El change recuerda su issue con la primera línea de su `proposal.md`: `Seguimiento: SergioIzq/Synap-Workspace#12`. Cada escritura en GitHub se confirma antes, y las etiquetas `idea`, `propuesta` y `en-curso` deben existir en el repo (los commands no las crean). La configuración está en el bloque `seguimiento` de `workspace.yaml`.

## Grafo de código (graphify)

`/montrel:graph` genera en `graphify-out/` (local, ignorado por git) un grafo unificado de los dos repos, para que la IA navegue el código con `graphify query "<pregunta>"` antes de leer ficheros a ciegas. Cada nodo lleva `repo: back` o `repo: front`.

Es opcional. Si falta Python ≥ 3.10 o graphify ≥ 0.9.80, `/montrel:graph` lo detecta y ofrece instalarlo, ver las instrucciones o continuar sin grafo; el resto de commands funciona igual.

```bash
python -m pip install --user --upgrade "graphifyy>=0.9.80"
```

## Requisitos

OpenSpec ≥ 1.9, GitHub CLI (`gh auth login`), .NET 10 SDK, Python (para `ai-service` y graphify), Node y npm, y Docker para levantar el entorno completo.

## Dónde está el porqué de cada decisión

Todo el razonamiento de arquitectura (por qué Postgres+pgvector, por qué IA híbrida local+free-tier, por qué el Atajo de iOS en vez de Share Target API, qué partes de los paquetes `SergioIzq.*.Kernel` se reutilizan y cuáles no...) está en el change fundacional, ya archivado:

```
openspec/changes/archive/2026-08-31-synap-mvp/proposal.md
openspec/changes/archive/2026-08-31-synap-mvp/design.md
openspec/changes/archive/2026-08-31-synap-mvp/specs/
openspec/changes/archive/2026-08-31-synap-mvp/tasks.md
```

La verdad actual de cada capacidad está en `openspec/specs/`.
