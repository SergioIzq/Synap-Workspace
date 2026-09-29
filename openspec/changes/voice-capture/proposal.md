# Proposal

## Why

El cuello de botella de captura hoy es teclear. La mayoría de las ideas buenas llegan mientras haces otra cosa: en el bus, caminando, entre reuniones. Con voz, la fricción de capturar cae a cero: dices lo que quieres apuntar y Synap lo transcribe, lo estructura y lo guarda. El Atajo de iOS ya existe pero solo acepta texto; este change añade dictado de voz.

## What Changes

- El Atajo de iOS acepta audio además de texto: el usuario habla, el Atajo envía el audio a la API y Synap transcribe con Whisper y crea la nota.
- Opcionalmente, el asistente puede procesar la transcripción antes de guardarla: limpiar el texto, extraer etiquetas naturales ("esto va de #infra"), separar varias ideas en notas distintas si el usuario habló de varias cosas.
- La transcripción y la nota creada se confirman con una notificación de vuelta al usuario.
- En la web, un botón de micrófono en el campo de captura rápida permite lo mismo desde el navegador.

## Capabilities

### New Capabilities

- `voice-input`: transcripción de audio a nota mediante Whisper, accesible desde el Atajo de iOS y desde la web.

### Modified Capabilities

- `ai-assistant`: procesado opcional de la transcripción antes de guardar (extracción de etiquetas, separación en notas).

## Impact

- Necesita Whisper (OpenAI o local) en el ai-service, o una llamada directa desde el Atajo a la API de OpenAI.
- La versión local de Whisper en el VPS compartido puede ser lenta; la versión de API tiene coste por minuto de audio.
- No depende de `assistant-agent-foundations` para la transcripción pura, pero sí para el procesado inteligente.
