# Proposal

## Why

Synap hoy es completamente reactivo: solo responde cuando tú preguntas. El mayor coste cognitivo de
gestionar trabajo y formación no es capturar ni buscar, sino **recordar qué hilo dejaste sin
cerrar**. Un briefing diario automático elimina ese esfuerzo: antes de empezar el día ya sabes
dónde estás, sin abrir nada ni preguntar nada.

Lo que hay hoy no lo cubre. Los recordatorios avisan de lo que tú te acordaste de apuntar; el
briefing avisa de lo que se te está olvidando. Una nota capturada a las once de la noche y nunca
etiquetada no vuelve a aparecer por sí sola: no la buscas porque no recuerdas que existe.

## What Changes

Cada mañana, a una hora que el usuario elige, Synap le envía por Telegram un mensaje con lo que
tiene delante ese día:

- **Recordatorios de hoy**: los que vencen en su día local.
- **Notas sin etiquetar**: las recientes que se quedaron sin clasificar.
- **Hilos abiertos**: notas cuyo texto contiene indicios de algo sin cerrar («pendiente», «TODO»,
  «revisar»).

Tres cosas que este change decide, y que la versión anterior de esta propuesta dejaba abiertas:

- **El contenido se calcula, no se redacta.** El briefing sale de consultas a la base de datos y
  una plantilla fija, sin pasar por el modelo. Dice siempre la verdad, es verificable sin un modelo
  en el bucle, no gasta la cuota de Groq del usuario y funciona aunque no tenga API key
  configurada. Un briefing es una afirmación diaria sobre el estado de las notas del usuario: es
  exactamente el sitio donde `observable-failures` acaba de demostrar que no se puede confiar la
  verdad a la prosa de un modelo.
- **Telegram es el único canal.** Ya está vinculado, probado y entregando recordatorios. El email
  y el push quedan fuera.
- **El progreso de formación queda fuera.** Depende de interpretar la memoria del asistente, que es
  texto libre, y no se puede hacer fiable sin el modelo que el primer punto descarta.

Y además **se puede pedir cuando quieras**, sin esperar a la hora: con un botón en Configuración y
con `/briefing` al bot. Es el mismo briefing, calculado en ese momento. Pedirlo no gasta el del día
—el automático llega igual a su hora— y, a diferencia de este, siempre contesta: si no hay nada que
contar lo dice, porque un botón que no responde parece roto.

El briefing automático es **opt-in**: nadie lo recibe hasta que lo activa y elige la hora. Pedirlo a
mano no requiere activarlo: mirar tus propias notas no es lo mismo que consentir un mensaje diario.

## Capabilities

### New Capabilities

- `briefing`: qué lleva el resumen matutino, cuándo se entrega, cómo se activa y se configura, y
  qué pasa cuando no hay nada que contar o no se puede entregar.

### Modified Capabilities

<!-- Ninguna. El briefing lee notas y recordatorios a través de lo que ya existe, sin cambiar lo
     que esas capacidades prometen. El canal de Telegram tampoco cambia: se reutiliza el envío que
     `reminders` ya especifica, y el comando `/briefing` se suma a lo que el bot entiende sin
     tocar `/start`, los botones de un recordatorio ni el rechazo del webhook. Lo que el bot
     contesta a `/briefing` lo promete `briefing`, no `reminders`. -->

## Impact

- Necesita un disparador periódico. El poller de recordatorios ya barre cada minuto
  (`ReminderPollerHostedService`), y la hora del briefing es una hora local por usuario, así que la
  forma de dispararlo se decide en `design.md`.
- Necesita persistir la preferencia (activado, hora) y qué día se envió el último, para no repetir
  ni duplicar. Cambio aditivo en `users`; no hay tabla nueva.
- Reutiliza `ITelegramSender` tal cual. Ningún cambio en el bot, ni en el webhook, ni en los
  botones.
- Sin llamadas al proveedor de generación: el briefing no consume cuota de Groq.
- Fuera de alcance: email, push, progreso de formación, resumen en prosa, y cualquier concepto
  nuevo de «nota revisada» — `notes` no lo tiene y este change no lo añade.
