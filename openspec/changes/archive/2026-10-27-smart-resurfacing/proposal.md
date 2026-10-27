Seguimiento: AB#2

# Proposal

## Why

Para compaginar carrera con trabajo el problema no es capturar, es **no perder lo que ya capturaste**. Una nota sobre Kubernetes que escribiste hace un mes sigue ahí, pero ya no la ves. Cuando capturas algo nuevo relacionado, Synap no te avisa. La conexión entre ideas se pierde y el conocimiento se fragmenta en islas. Este change hace que Synap conecte las notas por ti y te traiga de vuelta lo relevante en el momento justo.

## What Changes

- **Conexiones al capturar**: cuando guardas una nota nueva desde la web, Synap busca en segundo plano las notas existentes que se relacionan con ella por su sentido, por encima de un umbral de relevancia. Si las hay, lo avisa sin interrumpir: "Se relaciona con 3 notas tuyas sobre #kubernetes", con acceso directo a la nota. El detalle de una nota muestra esas mismas conexiones (con el umbral, en lugar de las cinco más parecidas sin filtro de ahora) y espera a que termine el análisis de una nota recién creada en lugar de no mostrar nada.
- **Actividad de una nota**: Synap registra cuándo abriste una nota por última vez, además de cuándo la editaste. Abrirla en la web cuenta; que la lea el asistente, que salga en una búsqueda o en el briefing, no.
- **Notas dormidas en el briefing**: una nota sin estado que no has abierto ni editado en un periodo que fija el sistema está dormida. El briefing incorpora una sección «Para retomar» con las notas dormidas que se relacionan con lo que has capturado o editado hace poco, cada una con la nota reciente que explica por qué vuelve ahora. Una nota rescatada no vuelve a salir hasta pasado un tiempo.

### Fuera de alcance

Quedan para changes posteriores, como siguientes pasos de esta línea:

- **Resumen de tema como acción rápida** ("Resume todo lo que tengo sobre AZ-204"): hoy ya se puede preguntar desde una etiqueta con la conversación acotada a ella (specs `ai-assistant`, «Questions scoped to a tag»).
- **Repasos espaciados** para temas marcados como estudio (1 día, 3 días, 1 semana, 2 semanas).
- Avisos de conexiones por Telegram o tras capturar desde el Atajo de iOS o el asistente: esas notas muestran sus conexiones en su detalle, sin aviso.
- Un umbral de dormida configurable por usuario: es fijo, como el de las notas pausadas.

## Capabilities

### New Capabilities

- `redescubrimiento`: conexiones entre notas por su sentido, aviso de conexiones al capturar, actividad de una nota (última apertura o edición) y selección de notas dormidas relacionadas con lo reciente.

### Modified Capabilities

- `briefing`: nueva sección «Para retomar» con las notas dormidas rescatadas, que cuenta como contenido del día.

## Impact

Repos afectados (ids de `workspace.yaml`):

- **`back`**:
  - API .NET: endpoint de conexiones de una nota, endpoint para registrar que se abrió una nota, columnas nuevas en `notes` (última apertura y último rescate) con su migración, y la sección nueva en el briefing (contenido, mensaje y registro del rescate al entregarse).
  - `ai-service`: conexiones de una nota con umbral, distinguiendo una nota aún sin analizar, y similitud entre un conjunto de notas recientes y uno de candidatas, en una sola consulta vectorial.
- **`front`**: aviso no bloqueante tras crear una nota, bloque de conexiones en el detalle (con espera breve si la nota aún se está analizando) y registro de la apertura al entrar en el detalle.

Se apoya en la búsqueda por similitud que ya existe (`assistant-agent-foundations`, archivado) y en el umbral de relevancia que el briefing usa para las notas de un evento (`calendar-integration`), para que «relacionado» signifique lo mismo en todo Synap. No hacen falta jobs nuevos: el rescate se calcula al construir el briefing.
