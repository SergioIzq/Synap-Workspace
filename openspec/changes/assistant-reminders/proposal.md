# Proposal

## Why

Hoy el asistente puede crear una nota cuando le dices "apúntame que tengo que renovar el certificado SSL el día 15". Pero Synap no puede avisarte cuando llega ese momento. Sin el aviso, la nota existe pero no te llega en el momento en que importa: el loop captura → recordatorio → acción nunca se cierra. Este change cierra ese loop.

## What Changes

- El asistente reconoce peticiones de recordatorio ("recuérdame esto el viernes", "avísame en 2 semanas") y programa un aviso.
- El aviso llega por un canal configurable (Telegram, push o email) en el momento indicado, con el texto de la nota o el fragmento relevante y un enlace directo.
- El usuario puede ver, editar y cancelar sus recordatorios pendientes desde la web.
- Los recordatorios se pueden crear también manualmente desde una nota, sin pasar por el asistente.
- Una nota puede tener más de un recordatorio.

## Capabilities

### New Capabilities

- `reminders`: creación, entrega y gestión de recordatorios asociados a notas o a texto libre.

### Modified Capabilities

- `ai-assistant`: nueva herramienta `set_reminder` disponible en la conversación global.
- `assistant-memory`: el asistente puede usar la memoria para inferir el canal preferido del usuario.

## Impact

- Necesita un scheduler para disparar los recordatorios en el momento configurado.
- Necesita al menos un canal de entrega (mismo que `daily-briefing`).
- Depende de `assistant-agent-foundations`.
