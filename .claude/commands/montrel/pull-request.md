---
name: "MONTREL: Pull Request"
description: "Crear una pull request (GitHub o Azure DevOps) desde una rama elegida, con las convenciones de Montrel"
allowed-tools: Bash(git:*), Bash(gh:*), Bash(az:*), Bash(openspec:*)
category: "Workflow"
tags: ["workflow", "pr", "pull-request", "git", "azure-devops", "montrel"]
---

Crea una pull request (en GitHub o Azure DevOps, según a dónde apunte el remote `origin`) desde una rama
que elige el usuario, contra una rama base que también elige, con un título y una descripción basados en
lo que realmente ha cambiado — aplicando de principio a fin las convenciones de este repositorio.

**Este comando no delega en ningún otro**: contiene toda la lógica, mecánica de Git/GitHub/Azure DevOps
incluida.

**Entrada**: opcionalmente el repo y/o la rama origen tras `/montrel:pull-request` (p. ej.
`/montrel:pull-request <id> feature/<change>`). Si se omiten, se preguntan como se describe en los pasos 0 y 3.

**Modo archive** (`<id> <rama> --base <base> --modo-archive`): lo usa `/montrel:archive`, que ya ha
decidido el repo, la rama origen y la base. En este modo:

- Pasos 0, 3 y 6: usa los valores recibidos sin preguntar ni mostrar la lista de ramas.
- Paso 4: no aplica (la rama origen es `feature/<change>`).
- Paso 7: si ya existe una PR abierta desde esa rama, no crees otra ni preguntes: devuelve su número y
  URL y termina.
- Paso 8: el change ya está archivado; búscalo en `openspec/changes/archive/*-<change>/`.
- Se mantienen las confirmaciones del commit (paso 5) y del título y cuerpo de la PR (paso 9).
- Termina devolviendo el número y la URL de la PR para que archive los anote.

## Pasos

0. **(MONTREL multi-repo) Elegir el repositorio**

   Lee `workspace.yaml`. Si no se indicó, pregunta con la **AskUserQuestion tool** en qué repositorio se
   crea la PR: uno de los `id` de `repos` (con su `ruta`) o `specs` (este repo, ruta `.`).
   Anota su ruta como `<repo-path>`. **Todos los comandos `git` de los pasos siguientes se ejecutan como
   `git -C "<repo-path>" ...`**, y los ficheros listados son relativos a ese repo. Nunca mezcles ficheros
   de repos distintos en un commit o PR. Para una PR de cada repo afectado, ejecuta el comando una vez por
   repo.

1. **Detectar el proveedor a partir del remote `origin`**

   Ejecuta `git remote get-url origin` y compara la URL con estos patrones (cuentan tanto HTTPS como SSH)
   para determinar `<provider>` — `GitHub` o `AzureDevOps` — y, en el caso de Azure DevOps, extraer
   `<organization>`, `<project>` y `<repository>`:

   - **GitHub** — la URL contiene `github.com`:
     - HTTPS: `https://github.com/<owner>/<repo>.git`
     - SSH: `git@github.com:<owner>/<repo>.git`
     - No hace falta más parseo: `gh` infiere owner/repo del remote local por sí solo.
   - **AzureDevOps** — la URL contiene `dev.azure.com` o `.visualstudio.com`:
     - HTTPS (actual): `https://dev.azure.com/<organization>/<project>/_git/<repository>`
     - SSH: `git@ssh.dev.azure.com:v3/<organization>/<project>/<repository>`
     - HTTPS (legacy): `https://<organization>.visualstudio.com/<project>/_git/<repository>`
     - Extrae `<organization>`, `<project>` y `<repository>` del patrón que coincida. Estos tres valores
       alimentan todos los `az repos pr` de más abajo — **nunca los inventes ni confíes en la
       autodetección de `az`**.
   - **Cualquier otra cosa** (GitHub Enterprise Server, un Azure DevOps Server on-prem, o cualquier otro
     host) — para aquí. Dile al usuario la URL del remote detectada y que este comando solo soporta
     remotes `github.com` y `dev.azure.com`/`*.visualstudio.com`. No adivines un proveedor ni intentes
     ningún flujo.

2. **Comprobar prerequisitos**

   Según `<provider>`:

   - **GitHub**: ejecuta `gh auth status` para confirmar que la CLI de GitHub está instalada y
     autenticada. Si falla, dile al usuario que ejecute `gh auth login` (o instale `gh`) y para aquí — no
     intentes crear la PR de otra forma.
   - **AzureDevOps**: ejecuta `az account show` para confirmar que hay una sesión activa de Azure. Luego
     ejecuta `az repos pr list --organization "https://dev.azure.com/<organization>/" --project
     "<project>" --top 1 --output json` para confirmar que hay acceso real a este proyecto de Azure Repos
     (no basta con un login genérico de Azure) — la extensión `azure-devops` se instala sola al primer uso
     de un comando `az repos`. Si cualquiera de las dos falla, dile al usuario que ejecute `az login` (o
     `az extension add --name azure-devops` si el problema es la extensión) y para aquí.

   Ejecuta `git fetch origin --prune` para que la lista de ramas y los diffs reflejen el remote, no un
   estado local desactualizado.

3. **Listar ramas y preguntar la rama origen (head)**

   Ejecuta `git branch --all --sort=-committerdate` (locales y remote-tracking, sin duplicados, más
   recientes primero) y muéstraselo al usuario.

   - Si se dio un argumento y coincide con una rama real, úsalo directamente y sáltate la pregunta.
   - Si no, pregunta exactamente:

     *"¿Desde qué rama quieres crear la PR?"*

   Antes de cambiar de rama, ejecuta `git status --porcelain` sobre la rama actual. Si está sucia, para y
   dile al usuario que commitee o guarde con stash primero — nunca cambies de rama sobre trabajo sin
   commitear. Si está limpia y la rama origen resuelta no es la actual, ejecuta `git checkout
   <source-branch>`.

4. **(MONTREL) ¿Rama protegida?**

   Si `<source-branch>` está en `ramas.protegidas` de `workspace.yaml` — pregunta con la
   **AskUserQuestion tool**: "`<source-branch>` es una rama protegida. Normalmente no se abre una PR
   *desde* una rama protegida. ¿Continúas de todas formas?" — opciones: continuar / cancelar.

   - **Si cancela:** para aquí. No sigas a ningún paso posterior.

5. **Comprobar cambios sin commitear en la rama origen — ofrecer commitear con la convención de Montrel**

   Ejecuta `git status --porcelain` ya sobre `<source-branch>`.

   - **Si está limpia:** continúa al paso 6.
   - **Si está sucia:** ofrece commitear aquí mismo, con la **convención de mensaje de Montrel** (asunto
     `<tipo>/<YYYY-MM-DD>_<descripcion_breve>`, cuerpo con Motivo / Cambios / Ficheros modificados) —
     nunca un "título conciso" genérico:

     a. Pregunta con la **AskUserQuestion tool**: "La rama `<source-branch>` tiene cambios sin commitear.
        ¿Quieres commitearlos con la convención de Montrel antes de crear la PR?" — opciones: commitear /
        dejarlo así y seguir / cancelar.

     - **Si "dejarlo así y seguir" o "cancelar":** no toques git. Si es "cancelar", para aquí del todo. Si
       es "dejarlo así y seguir", continúa al paso 6 con la rama tal cual está — la PR se abrirá solo con
       lo ya commiteado.

     b. **Si "commitear":**

        - Reúne los ficheros tocados con `git status --short` y `git diff --stat` — solo referencia lo
          que aparece en esa salida, nunca inventes un fichero.
        - **(MONTREL) Solo si el repo tiene `revision_docs` en `workspace.yaml`:** aplica esa regla a los
          ficheros tocados a los que corresponda; corrige solo la documentación que no la cumpla y vuelve a
          ejecutar `git status --short`.
        - Determina el `TIPO` (`feature`/`fix`/`refactor`/`docs`/`test`/`chore`/`release`) por lo que
          realmente cambia; si es ambiguo, elige el más cercano y dilo.
        - Construye el mensaje:

          ```
          <tipo>/<YYYY-MM-DD>_<descripcion_breve>

          Change OpenSpec: `<change-name>`. <ref>

          Motivo:
          <por qué se hizo, en prosa>

          Cambios:
          <qué cambia de verdad, en frases completas>

          Ficheros modificados:
          <lista real de git status --short>
          ```

          `<YYYY-MM-DD>` es la fecha real de hoy, leída del entorno — nunca inventada.
          `<descripcion_breve>` va en minúsculas con guiones bajos en vez de guiones, sin espacios ni
          artículos. Omite la línea `Change OpenSpec` si no hay change que coincida, y `<ref>` si el
          change no tiene `Seguimiento:` en su proposal.
        - Muestra el mensaje completo y pregunta con la **AskUserQuestion tool**: "¿Confirmas este
          commit?" — opciones: commitear tal cual / cambiar el `TIPO` / lo hago yo a mano.
        - **Si confirma tal cual:** escribe el mensaje en un fichero UTF-8 sin BOM. `git add` solo los
          ficheros listados — **nunca `git add -A`**. Revisa `git status --short` completo antes de
          commitear (por si hay algo ajeno preparado de antes) y quítalo del índice con `git restore
          --staged <ruta>` si aparece. Luego `git commit -F <fichero>`. **Nunca `-m`, nunca
          `--no-verify`, nunca `--amend`.**
        - **Si cambia el `TIPO`:** reconstruye el asunto y vuelve a confirmar.
        - **Si "lo hago yo a mano":** para aquí sin tocar git; muestra el mensaje para que lo reutilice.
        - Verifica el commit leyéndolo de vuelta con `git log -1 --format=%B` — no te fíes de cómo lo
          pintó la consola: puede mostrar mal un commit correcto, y al revés.

6. **Listar ramas otra vez y preguntar la rama destino (base)**

   Muestra de nuevo la lista de ramas del paso 3, excluyendo `<source-branch>`. Pregunta exactamente:

   *"¿Contra qué rama quieres fusionar (base)?"*

   Puedes señalar `ramas.integracion` de `workspace.yaml` como el destino habitual si está en la lista, pero deja que el usuario elija
   cualquier rama — nunca lo asumas.

7. **Verificar que hay algo que fusionar**

   - Ejecuta `git rev-list --count <base>..<source-branch>`. Si es `0`, dile al usuario que no hay
     commits por delante de `<base>` y para — no hay nada para lo que abrir una PR.
   - Comprueba si ya existe una PR abierta sobre `<source-branch>`, según `<provider>`:
     - **GitHub**: `gh pr list --head "<source-branch>" --state open --json number,url,title`.
     - **AzureDevOps**: `az repos pr list --organization "https://dev.azure.com/<organization>/"
       --project "<project>" --repository "<repository>" --source-branch "<source-branch>" --status
       active --output json`. Lee `pullRequestId` y `title` de cada resultado; construye la URL de la PR
       igual que en el paso 10 (`<repository.webUrl>/pullrequest/<pullRequestId>`, usando el campo
       `repository.webUrl` de esa misma entrada JSON). Si esa versión de `az` no incluye un objeto
       `repository` en el listado, recurre a `az repos show --repository "<repository>" --organization
       "https://dev.azure.com/<organization>/" --project "<project>" --output json` y lee `webUrl` de
       ahí.
   - Si ya existe una PR abierta para esta rama, muestra su id/número, título y URL, y pregunta si parar o
     continuar de todas formas. Por defecto, parar — abrir una segunda PR para la misma rama casi nunca es
     lo que se quiere.

8. **Reunir el contexto real — nunca lo inventes**

   - **Commits**: `git log <base>..<source-branch> --pretty=format:"%h %s"` — el historial real que se va
     a fusionar.
   - **Archivos modificados**: `git diff <base>...<source-branch> --stat` (diff de tres puntos, relativo
     al merge-base) — solo lista los ficheros que aparecen en esta salida.
   - **Motivo de los cambios / Descripción de la solución**: busca en este repo de specs (`openspec list
     --json` y `openspec/changes/archive/`) un change de OpenSpec ligado a esta rama — un change
     archivado o activo cuyo nombre coincida con el de la rama (`feature/<change>`) o esté referenciado en
     los mensajes de commit. Si el `proposal.md` empieza con `Seguimiento: <ref>`, termina el cuerpo con
     `Refs <ref>` (seguimiento `github`) o con `<ref>` (`azure-boards`), para que la plataforma vincule la PR.
     En los repos de código nunca uses `Closes`/`Fixes`: el issue lo cierra `/montrel:archive` tras abrir las PRs. Si lo encuentras, lee su `proposal.md` (razón → Motivo) y `design.md`/`tasks.md`
     (enfoque tomado → Descripción). **Si no hay ningún change que coincida**, derívalos directamente de
     los mensajes de commit y del diff, y dilo explícitamente: son una inferencia, no una razón verificada
     — no la disfraces de otra cosa.

9. **Redactar el título y la descripción de la PR**

   - **Título**: conciso, descriptivo, en modo imperativo (p. ej. `Add dark mode toggle to settings`),
     que refleje lo que hace la rama de verdad — nunca una etiqueta genérica como "cambios" o
     "actualizaciones".
   - **Cuerpo**, con exactamente estas tres secciones:

     ```markdown
     ## Motivo de los cambios
     <por qué se hizo este cambio>

     ## Descripción de la solución
     <qué se implementó realmente>

     ## Archivos modificados
     - <fichero 1>
     - <fichero 2>
     ```

   Muestra el título y el cuerpo redactados al usuario y espera su confirmación (o sus cambios) antes de
   tocar git, GitHub o Azure DevOps.

   **Tras la confirmación**, escribe el título y el cuerpo confirmados en sendos ficheros **UTF-8 sin
   BOM** — p. ej. `<tmp>/pr-titulo.txt` y `<tmp>/pr-cuerpo.md` — antes de pasar al paso 10. Es la misma
   razón por la que el paso 5 nunca commitea con `-m`: un argumento de línea de comandos con tildes o `ñ`
   puede llegarle mal a `gh`/`az` según el codepage de la consola, así que el título y el cuerpo confirmados
   viajan siempre desde fichero, nunca tecleados de nuevo en el comando.

10. **Al confirmar, hacer push y crear la PR**

    - Si `<source-branch>` no tiene upstream, o está por detrás de su remote, haz push: `git push -u
      origin <source-branch>` (`git push` a secas si ya trackea y solo va por delante). **Nunca uses
      `--force` ni `--force-with-lease`.** Si el push es rechazado, infórmalo y deja que decida el
      usuario — no fuerces para pasar por encima.
    - Crea la pull request, según `<provider>`, leyendo el título y el cuerpo de los ficheros del paso 9
      — nunca los reescribas como literal en el comando:
      - **GitHub**:
        ```bash
        gh pr create --base "<base-branch>" --head "<source-branch>" --title "$(cat <tmp>/pr-titulo.txt)" --body-file "<tmp>/pr-cuerpo.md"
        ```
        `gh` no tiene un `--title-file`, así que el título pasa por `$(cat ...)`; el cuerpo, en cambio,
        usa `--body-file` para que `gh` lo lea directamente del fichero sin pasar por el argumento de la
        shell. Informa de la URL de la PR que devuelve `gh` directamente.
      - **AzureDevOps**: **antes** de ejecutar `az repos pr create`, comprueba que los ficheros del paso 9
        no llevan caracteres corrompidos — vuelve a leerlos (`cat <tmp>/pr-titulo.txt`,
        `cat <tmp>/pr-cuerpo.md`) y compáralos con el texto confirmado en el paso 9. Si aparece alguna
        secuencia típica de doble codificación (`Ã³`, `Ã±`, `Â»`…) en vez de la tilde o la `ñ` esperada,
        **corrige el fichero y no ejecutes `az repos pr create` hasta que el fichero esté limpio**: Azure
        DevOps no se vuelve a comprobar después de crear la PR, así que esta es la única comprobación.

        ```bash
        az repos pr create --organization "https://dev.azure.com/<organization>/" --project "<project>" --repository "<repository>" --source-branch "<source-branch>" --target-branch "<base-branch>" --title "@<tmp>/pr-titulo.txt" --description "@<tmp>/pr-cuerpo.md" --output json
        ```
        El prefijo `@<fichero>` le dice a `az` que cargue el valor desde ese fichero en vez de tratarlo
        como literal — así ni el título ni la descripción pasan por el argumento de la shell. Lee
        `pullRequestId` y `repository.webUrl` del JSON devuelto y construye la URL como
        `<repository.webUrl>/pullrequest/<pullRequestId>`.

        **No releas ni compares el `title`/`description` que devuelve este mismo comando** (ni su JSON,
        ni cómo lo pinta la consola) para juzgar si el título o la descripción llegaron bien codificados:
        la consola de Windows puede mostrar `�` en vez de tildes/`ñ` aunque el valor guardado en Azure
        DevOps sea correcto — es un artefacto de cómo esa consola pinta el texto devuelto, no del dato
        real. La única comprobación de codificación es la de **antes** de crear la PR (párrafo anterior);
        una vez creada, no hay nada más que comprobar por este camino — si hace falta confirmar de verdad,
        se mira la PR en el navegador, nunca releyendo la salida de `az`.
    - **GitHub**: verifica el título y el cuerpo ya creados leyéndolos de vuelta con `gh pr view <number>
      --json title,body` — nunca te fíes de cómo los pintó la consola al crearlos. Compara el resultado
      con lo confirmado en el paso 9; si alguna tilde o `ñ` aparece corrompida, avísalo explícitamente y
      corrígelo con `gh pr edit <number> --title "$(cat <tmp>/pr-titulo.txt)" --body-file
      "<tmp>/pr-cuerpo.md"` — nunca lo dejes corrompido en silencio.

## Salida

```markdown
## Pull Request Creada

**Proveedor:** <GitHub | Azure DevOps>
**Desde:** <source-branch> → **Hacia:** <base-branch>
**Título:** <title>
**URL:** <pr-url>

<N> commits, <M> ficheros modificados.
```

## Salida cuando no hay nada que fusionar

```markdown
## Nada que fusionar

`<source-branch>` no tiene commits por delante de `<base-branch>`. No se ha creado ninguna PR.
```

## Reglas (MONTREL)

- Detecta el proveedor a partir del remote `origin` antes que nada; si la URL no coincide con
  `github.com` ni `dev.azure.com`/`*.visualstudio.com`, para y dilo en vez de adivinar un proveedor.
- Para Azure DevOps, `organization`/`project`/`repository` se parsean siempre del remote — nunca se
  inventan ni se confía en la autodetección de `az`.
- Nunca inventes Motivo, Descripción ni Archivos modificados: se basan en `git log`/`git diff`, y cuando
  exista, en el `proposal.md`/`design.md`/`tasks.md` real de un change de OpenSpec que coincida; di
  explícitamente cuándo el contenido es una inferencia a partir de los commits.
- Fuera del modo archive, muestra siempre la lista de ramas y pregunta tanto por el origen como por el destino — nunca asumas
  ninguna de las dos, aunque solo haya una candidata obvia.
- Nunca cambies de rama ni hagas push mientras el árbol de trabajo tenga cambios sin commitear en la rama
  de la que te vas (comprobación de rama sucia del paso 3).
- Si `<source-branch>` está en `ramas.protegidas` y el usuario cancela en el paso 4, no se
  ejecuta nada más.
- Si la rama origen está sucia (paso 5), ofrece commitear con la **convención de Montrel**
  (`<tipo>/<fecha>_<descripcion>` + Motivo/Cambios/Ficheros modificados, fichero UTF-8 sin BOM, `git
  commit -F`) — nunca un commit genérico, nunca `git add -A`, nunca `-m`, nunca `--no-verify`, nunca
  `--amend`. Muestra siempre el mensaje completo y pide confirmación explícita antes de commitear.
- Nunca hagas force-push.
- Muestra el título/cuerpo redactados y espera confirmación explícita antes de pushear o crear nada.
- Comprueba si ya existe una PR abierta en la rama antes de crear una nueva; por defecto, para si ya
  existe.
- Si la CLI del proveedor (`gh` o `az`) no está instalada o autenticada, para y dilo — no intentes un
  rodeo.
- Informa siempre de la URL real de la PR devuelta por `gh` o construida a partir del JSON de `az`, nunca
  una URL adivinada.
- **Título y cuerpo de la PR van siempre desde fichero UTF-8 sin BOM**, nunca tecleados de nuevo como
  literal en `gh pr create`/`az repos pr create`: `--body-file` en GitHub, `@<fichero>` en Azure DevOps, y
  `$(cat <fichero>)` para el título de GitHub (que no tiene flag de fichero propio). Es la misma regla que
  ya aplica a los mensajes de commit del paso 5, y por el mismo motivo: un argumento de línea de comandos
  con tildes o `ñ` puede corromperse según el codepage de la consola.
- **GitHub**: tras crear la PR, verifica leyendo de vuelta el título y el cuerpo con `gh pr view --json` —
  no te fíes de cómo los pintó la consola al crearla — y corrígelos con `gh pr edit` si aparecen
  corrompidos.
- **Azure DevOps**: la comprobación de caracteres corrompidos se hace **antes** de ejecutar
  `az repos pr create`, releyendo los ficheros del paso 9 — nunca después de crear la PR. No uses el
  `title`/`description` que devuelve `az repos pr create` (ni su JSON) como señal de corrupción: la
  consola de Windows puede pintar `�` ahí aunque el dato guardado en Azure DevOps esté bien.
- Este comando nunca mergea la PR — eso sigue siendo manual.
