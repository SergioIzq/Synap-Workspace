# Proposal

## Why

Synap hoy es completamente reactivo: solo responde cuando tú preguntas. El mayor coste cognitivo de gestionar trabajo y formación no es capturar ni buscar, sino **recordar qué hilo dejaste sin cerrar**. Un briefing diario automático elimina ese esfuerzo: antes de empezar el día ya sabes dónde estás, sin abrir nada ni preguntar nada.

## What Changes

Cada mañana, a una hora configurable, Synap envía un mensaje (push, Telegram o email — canal a decidir en design) con:

- **Notas pendientes de revisar**: notas recientes sin etiquetar o sin marcar como revisadas.
- **Hilos abiertos**: notas que contienen indicios de algo sin cerrar ("pendiente", "TODO", "revisar", fechas futuras detectadas en el contenido).
- **Progreso de formación**: si hay notas de un tema de certificación o aprendizaje, cuándo fue la última y qué queda pendiente según la memoria del usuario.
- **Recordatorios del día**: entradas de memoria o notas con fecha que coinciden con hoy.

El briefing lo genera el asistente con las herramientas que ya tiene (búsqueda, lectura de notas, memoria), sin llamadas extra más allá de las necesarias para construirlo.

## Capabilities

### New Capabilities

- `briefing`: generación y entrega del resumen matutino, configuración del canal y la hora, y opt-out.

### Modified Capabilities

- `assistant-memory`: el asistente usa la memoria del usuario para personalizar el briefing.
- `ai-assistant`: el bucle de herramientas se reutiliza para construir el contenido del briefing.

## Impact

- Necesita un scheduler (cron o equivalente) para lanzar la generación a la hora configurada.
- Necesita al menos un canal de entrega (Telegram es el más simple; push requiere service worker).
- Depende de `assistant-agent-foundations` (herramientas del asistente y memoria).
