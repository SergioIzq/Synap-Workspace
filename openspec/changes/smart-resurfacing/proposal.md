# Proposal

## Why

Para compaginar carrera con trabajo el problema no es capturar, es **no perder lo que ya capturaste**. Una nota sobre Kubernetes que escribiste hace un mes sigue ahí, pero ya no la ves. Cuando capturas algo nuevo relacionado, Synap no te avisa. La conexión entre ideas se pierde y el conocimiento se fragmenta en islas. Este change hace que Synap conecte las notas por ti y te traiga de vuelta lo relevante en el momento justo.

## What Changes

- **Conexiones al capturar**: cuando guardas una nota nueva, Synap busca en segundo plano si hay notas existentes relacionadas. Si las hay, te lo hace saber: "Esto que acabas de apuntar sobre Helm se relaciona con 3 notas que tienes de Kubernetes."
- **Resurfacing por tiempo**: notas de un tema que no has tocado en N días (configurable) vuelven a aparecer como sugerencia, con el contexto de por qué pueden ser relevantes ahora.
- **Resumen de tema bajo demanda**: "Resume todo lo que tengo sobre la certificación AZ-204" — el asistente ya puede hacer esto con las herramientas actuales, pero este change lo expone como acción rápida desde etiquetas y como parte del briefing.
- **Espaciado para formación**: opcionalmente, para un tema marcado como "estudio", Synap programa repasos con intervalos crecientes (spaced repetition ligero).

## Capabilities

### New Capabilities

- `resurfacing`: detección de conexiones entre notas, notificaciones de notas dormidas y repasos programados.

### Modified Capabilities

- `ai-assistant`: nueva herramienta o acción rápida para el resumen de tema.
- `briefing`: el resurfacing alimenta la sección de "progreso de formación" del briefing diario.

## Impact

- La detección de conexiones puede hacerse en segundo plano con la búsqueda híbrida que ya existe.
- El espaciado requiere un scheduler y un modelo de intervalos (puede ser muy simple: 1 día, 3 días, 1 semana, 2 semanas).
- Depende de `assistant-agent-foundations` para las búsquedas.
