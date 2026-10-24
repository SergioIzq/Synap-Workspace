---
name: "MONTREL: Archive"
description: "Archivar un change OpenSpec tras mergear sus PRs y proponer commit en el repo de specs"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(az:*), Bash(gh:*), AskUserQuestion, Skill
category: Workflow
tags: [workflow, archive, montrel]
---

Archiva un change completado y después propone el commit en este repo de specs.

**Wrapper fino:** el paso 1 comprueba que el código ya esté mergeado; el paso 2 delega el archivado en `/opsx:archive`; los pasos 3 y 4 proponen el commit confirmado de este repo (nunca en una rama protegida) y preguntan por separado si hacer push. El código ya se comiteó por repo en `/montrel:pull-request`.

**Entrada:** nombre opcional del change, que se pasa a `/opsx:archive`.

## Paso 1 — comprobar PRs de código

1. Resuelve el change y los repos afectados: los `<id>` de las cabeceras `## N. <nombre> (<id>)` de `tasks.md`, con su `ruta` de `workspace.yaml`.
2. Para cada repo afectado, detecta el proveedor con `git -C "<ruta>" remote get-url origin` (mismos patrones que el paso 1 de `/montrel:pull-request`; nunca inventes owner, organización ni proyecto) y busca una PR completada desde `feature/<change>`:

   - **GitHub:** `gh pr list --repo <owner>/<repo> --head "feature/<change>" --state merged --json number,url`.
   - **Azure DevOps:**

   ```text
   az repos pr list --organization "https://dev.azure.com/<organization>/" --project "<project>" --repository "<repository>" --source-branch "feature/<change>" --status completed --output json
   ```

3. Muestra una tabla `repo → PR completada (id) / ninguna`. Si falta alguna, pregunta mediante AskUserQuestion si continuar de todas formas o parar. Por defecto, parar.
4. Si la CLI del proveedor (`gh`/`az`) no está autenticada, o el `origin` de un repo no es de GitHub ni de Azure DevOps, marca ese repo como «no comprobable» en la tabla y pregunta si continuar sin la comprobación.

## Paso 2 — delegar archivado en `/opsx:archive`

Invoca `opsx:archive` con la **Skill tool**, pasando el nombre del change. Sigue sus instrucciones: selección, checks de artefactos y tareas, sync de delta specs si procede, movimiento al archivo y resumen.

Anota el change y el destino. Si `/opsx:archive` falla o se cancela, detente: no hay commit que proponer.

## Paso 3 — proponer commit en el repo de specs

0. Ejecuta `git branch --show-current`. Si es una rama de `ramas.protegidas`, no comitees en ella: pregunta mediante AskUserQuestion si crear `feature/<change>` (o cambiar a ella si ya existe) o parar. Los ficheros sin commitear viajan con el cambio de rama; nunca hagas stash automático.
1. Reúne con `git status --short` los ficheros de este change en este repo: el change archivado y las specs sincronizadas. Ignora cualquier otro cambio.
2. Lee el `proposal.md` archivado para clasificar el tipo: comportamiento nuevo `feature`, corrección `fix`, refactor `refactor`, solo docs `docs`, tests `test`, tooling `chore`, publicación `release`. Si es ambiguo, elige el más cercano y dilo.
3. Propón un mensaje completo en español:

   ```text
   <tipo>/<YYYY-MM-DD>_<descripcion_breve>

   Archiva el change de OpenSpec `<change-name>`. <cierre>

   Motivo:
   <resumen fiel de Why>

   Cambios:
   <qué specs cambian, en frases completas>

   PRs de código:
   <repo: PR <id>, por cada repo afectado>

   Ficheros modificados:
   <lista real agrupada por área, relativa a este repo>
   ```

   Usa la fecha real del entorno y convierte el nombre kebab-case a snake_case. Conserva las tildes y la `ñ`. `<cierre>` sale de la línea `Seguimiento: <ref>` del proposal: `Closes <ref>` con seguimiento `github` (GitHub cierra el issue cuando esta PR se mergea en la rama por defecto) y `<ref>` con `azure-boards`. Omítelo si no hay `Seguimiento:`.
4. Escribe el mensaje en `commit_msg.txt` en UTF-8 sin BOM, con ruta absoluta:

   ```powershell
   $msg = @"
   <mensaje completo>
   "@
   $ruta = Join-Path (Get-Location).Path "commit_msg.txt"
   [System.IO.File]::WriteAllText($ruta, $msg, (New-Object System.Text.UTF8Encoding($false)))
   ```

   El terminador `"@` empieza en columna 1. No uses `Out-File` ni `git commit -m`.
5. Muestra el asunto, el cuerpo completo y las rutas exactas. Pregunta mediante AskUserQuestion si confirma, quiere cambiar el tipo o lo hará manualmente.
6. Solo tras la confirmación, haz `git add` de las rutas enumeradas. Revisa el índice con `git status --short` y quita del stage cualquier ruta ajena con `git restore --staged <ruta>`. Ejecuta `git commit -F "commit_msg.txt"`; nunca `git add -A` ni `git add .`.
7. Verifica el mensaje con `git log -1 --format=%B`.

Si el usuario rechaza, no modifiques el índice ni hagas commit; muestra el mensaje para reutilizarlo.

## Paso 4 — preguntar por push

Solo si se creó el commit, pregunta mediante AskUserQuestion si desea hacer push a `origin`.

- Si acepta, comprueba `git rev-parse --abbrev-ref --symbolic-full-name @{u}`; ejecuta `git push` si hay upstream o `git push -u origin <rama-actual>` si no.
- Si rechaza, deja el commit local.
- Nunca crees PR ni hagas merge desde este wrapper.

## Limpieza y reglas

- Elimina `commit_msg.txt` después del intento, tanto si confirma como si cancela o falla: `Remove-Item ".\commit_msg.txt" -ErrorAction SilentlyContinue`.
- Los pasos de commit y push no se ejecutan si el archivado falla o se cancela.
- Este wrapper solo comitea en este repo de specs; nunca toca los repos de código.
- Todo commit y push requiere confirmación explícita e independiente.
