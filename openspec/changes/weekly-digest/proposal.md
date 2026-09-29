# Proposal

## Why

Al final de la semana es difícil saber qué avanzaste, qué dejaste sin cerrar y en qué empleaste el tiempo. Revisar nota a nota no escala. Un digest semanal automático da una vista de pájaro en segundos: qué capturaste, qué temas dominaron tu semana, qué hilos siguen abiertos. Útil tanto para la gestión del trabajo como para ver si avanzas en la formación.

## What Changes

Cada domingo (o el día configurable), Synap genera y entrega un resumen de la semana:

- **Volumen**: cuántas notas capturaste y en qué días.
- **Temas**: los 3–5 temas principales deducidos de las notas, con el número de notas de cada uno.
- **Sin cerrar**: notas con indicios de algo pendiente o que no tienen etiqueta de cierre.
- **Formación**: si hay un tema de estudio activo, cuántas notas nuevas hubo y cuál fue la última.
- **Acciones pendientes**: recordatorios que vencen la semana siguiente (si `assistant-reminders` está implementado).

El digest se entrega por el mismo canal que el briefing diario. Si no hay nada nuevo en la semana, no se envía.

## Capabilities

### New Capabilities

- `weekly-digest`: generación y entrega del resumen semanal, con configuración de día y canal.

### Modified Capabilities

- `briefing`: comparten canal de entrega y configuración; el digest es la versión semanal del briefing.

## Impact

- Comparte infraestructura de scheduler y canal de entrega con `daily-briefing`.
- Se beneficia de `smart-resurfacing` para detectar hilos sin cerrar.
- Puede implementarse antes que el briefing diario si se quiere empezar por la frecuencia más baja.
