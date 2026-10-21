---
name: "MONTREL: Sync"
description: "Sincronizar los delta specs de un change con las specs principales"
allowed-tools: Bash(openspec:*), AskUserQuestion, Skill
category: Workflow
tags: [workflow, specs, montrel]
---

Sincroniza los delta specs de un change con las specs principales de este repo.

**Wrapper fino:** el mezclado inteligente de cambios `ADDED`, `MODIFIED`, `REMOVED` y `RENAMED` lo gobierna `/opsx:sync`.

**Entrada:** nombre opcional del change.

## Pasos

1. Si falta el nombre o es ambiguo, ejecuta `openspec list --json` y pregunta mediante AskUserQuestion. No adivines ni auto-selecciones.
2. Usa la **Skill tool** para invocar `opsx:sync`, pasando el change resuelto. Sigue sus instrucciones hasta el final.
3. Anota las specs realmente modificadas o creadas; `/montrel:archive` las necesitará para el commit.

## Reglas

- Solo se escriben specs de `openspec/` de este repo; nunca el `openspec/` de los repos de código.
- Lee el delta y la spec principal antes de cambiar esta última y conserva el contenido que el delta no menciona.
- La operación debe ser idempotente.
- Si `/opsx:sync` falla, detente y muestra el error.
