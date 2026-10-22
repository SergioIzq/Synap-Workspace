---
name: "MONTREL Azure: Archive"
description: "Archivar un change OpenSpec y abrir las PRs de los repos con cambios y del repo de specs"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(az:*), AskUserQuestion, Skill
category: Workflow
tags: [workflow, archive, montrel, azure-devops]
---

Archiva un change implementado y abre sus pull requests: una por cada repo de código donde haya cambios y otra para este repo de specs.

**Wrapper fino:** el paso 1 decide sin preguntar qué repos tienen cambios; el paso 2 delega el archivado en `/opsx:archive`; los pasos 3 y 5 delegan cada PR en `/montrel-azure:pull-request` en modo archive; el paso 4 propone el commit confirmado de este repo (nunca en una rama protegida); el paso 6 marca el work item como cerrado.

**Entrada:** nombre opcional del change, que se pasa a `/opsx:archive`.

## Paso 1 — detectar repos con cambios

No preguntes qué repos incluir: decídelo con Git.

1. Resuelve el change. `<rama>` es `feature/<change>` y `<base>` es `ramas.integracion` de `workspace.yaml`.
2. Para **cada** repo de `repos` de `workspace.yaml` (no solo los de `tasks.md`), con su `ruta`:
   - Ejecuta `git -C "<ruta>" fetch origin --prune`.
   - Si `<rama>` no existe ni en local ni en `origin`, el repo no tiene cambios.
   - Si existe, tiene cambios cuando `git -C "<ruta>" rev-list --count origin/<base>..<rama>` es mayor que 0, o cuando `<rama>` es la rama actual y `git -C "<ruta>" status --porcelain` no está vacío.
3. Muestra una tabla `repo → rama → commits por delante / cambios sin commitear → incluido sí/no`, solo como información.
4. Compara con las cabeceras `## N. <nombre> (<id>)` de `tasks.md`. Si un repo de `tasks.md` no tiene cambios, o uno con cambios no está en `tasks.md`, avísalo en la tabla, pero no cambies la decisión.
5. Si ningún repo de código tiene cambios, avisa y continúa: solo habrá PR de specs.

## Paso 2 — delegar archivado en `/opsx:archive`

Invoca `opsx:archive` con la **Skill tool**, pasando el nombre del change. Sigue sus instrucciones: selección, checks de artefactos y tareas, sync de delta specs si procede, movimiento al archivo y resumen.

Anota el change y el destino. Si `/opsx:archive` falla o se cancela, detente: no se abre ninguna PR.

## Paso 3 — PRs de los repos de código

Para cada repo incluido en el paso 1, en el orden de `workspace.yaml`, invoca `montrel-azure:pull-request` con la **Skill tool** y estos argumentos:

```text
<id> <rama> --base <base> --modo-archive
```

Sigue sus instrucciones. Anota de cada repo el id y la URL de la PR (creada o ya existente). Si un repo falla, informa y sigue con los demás; al final, resume cuáles no tienen PR.

## Paso 4 — proponer commit en el repo de specs

0. Ejecuta `git branch --show-current`. Si es una rama de `ramas.protegidas`, no comitees en ella: pregunta mediante AskUserQuestion si crear `<rama>` (o cambiar a ella si ya existe) o parar. Los ficheros sin commitear viajan con el cambio de rama; nunca hagas stash automático.
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
   <repo: PR <id>, por cada PR del paso 3>

   Ficheros modificados:
   <lista real agrupada por área, relativa a este repo>
   ```

   Usa la fecha real del entorno y convierte el nombre kebab-case a snake_case. Conserva las tildes y la `ñ`. `<cierre>` sale de la línea `Seguimiento: <ref>` del proposal: `Fixes <ref>` (con `<ref>` = `#<n>`): Azure Repos resuelve el work item cuando este commit llega a la rama por defecto mediante una PR. Omítelo si no hay `Seguimiento:`. Omite `PRs de código:` si el paso 3 no creó ninguna.
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

Si el usuario rechaza, no modifiques el índice ni hagas commit; muestra el mensaje para reutilizarlo y no sigas al paso 5.

## Paso 5 — PR del repo de specs

Solo si se creó el commit, invoca `montrel-azure:pull-request` con la **Skill tool** y los argumentos `specs <rama> --base <base> --modo-archive`. Esa PR lleva el `Fixes #<n>` y es la que cierra el work item.

## Paso 6 — marcar el work item como cerrado

Solo si se creó el commit y el proposal archivado empieza con `Seguimiento: #<n>`, sin preguntar. `<org>` es `https://dev.azure.com/<seguimiento.organizacion>/`.

1. Lee sus tags actuales: `az boards work-item show --id <n> --organization "<org>" --query "fields.\"System.Tags\"" --output tsv`.
2. Quita `<etiquetas.en_curso>`, añade `<etiquetas.cerrado>` y conserva las demás. Azure sustituye la lista entera, así que escribe la lista resultante separada por `; `.
3. Ejecuta `az boards work-item update --id <n> --organization "<org>" --fields "System.Tags=<lista resultante>"`.

No cambies el estado: lo resuelve Azure Repos con `Fixes #<n>` al completarse la PR de specs en la rama por defecto. Si `az` no está autenticado, avisa y continúa.

## Salida

Tabla final `repo → PR (id y URL) / sin cambios / fallo`, incluido `specs`, y el estado del work item.

## Limpieza y reglas

- Elimina `commit_msg.txt` después del intento, tanto si confirma como si cancela o falla: `Remove-Item ".\commit_msg.txt" -ErrorAction SilentlyContinue`.
- No se abre ninguna PR si el archivado falla o se cancela.
- La selección de repos es automática; los commits y el texto de cada PR siguen requiriendo confirmación explícita.
- Este wrapper solo comitea en este repo de specs; los commits de los repos de código los hace `/montrel-azure:pull-request`.
- Nunca mergees ninguna PR desde este wrapper.
