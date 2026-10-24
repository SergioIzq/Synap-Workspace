---
name: "MONTREL: Update"
description: "Revisar artefactos OpenSpec existentes y mantenerlos coherentes"
allowed-tools: Bash(openspec:*), AskUserQuestion, Skill
category: Workflow
tags: [workflow, openspec, montrel]
---

Revisa los artefactos de planificación de un change y mantenlos coherentes. **Nunca edites código.**

**Wrapper fino:** la revisión y reconciliación la gobierna `/opsx:update`.

**Entrada:** nombre opcional del change.

## Pasos

1. Si no hay nombre, ejecuta `openspec list --json` y pregunta mediante AskUserQuestion; no adivines ni auto-selecciones.
2. Ejecuta `openspec status --change "<name>" --json` y usa `schemaName`, `planningHome`, `changeRoot`, `artifactPaths` y `actionContext`. Edita solo ficheros existentes enumerados en `artifactPaths.<artefacto>.existingOutputPaths`.
3. Usa la **Skill tool** para invocar `opsx:update` con el change resuelto. Sigue sus instrucciones, compara artefactos entre sí y confirma cada edición antes de escribirla.
4. Resume los artefactos modificados y conservados, y recomienda el siguiente comando Montrel que corresponda.

## Reglas

- Solo artefactos de planificación de este repo; si el plan requiere cambios de código, detente y sugiere `/montrel:apply`.
- Mantén `tasks.md` agrupado por repo con cabeceras `## N. <nombre> (<id>)` de `workspace.yaml`.
- No crees artefactos que no existan ni escribas en rutas glob sin resolver.
- Si cambia la intención del change, recomienda un change nuevo con `/montrel:propose`.
- Si `/opsx:update` falla, detente y muestra el error.
