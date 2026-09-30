# Proposal

## Why

Un bug de un carácter en la URL del bot de Telegram costó una tarde de depuración porque el sistema
nunca dijo la verdad sobre lo que fallaba: el error se registró como «could not be reached», que
suena a problema de red, cuando la petición ni siquiera había salido del proceso. El rastro que lo
desmentía estaba en un HTML dentro del contenedor, invisible desde `docker compose logs` y borrado
al recrearlo. En la misma sesión, un 401 entre dos contenedores propios se presentó al usuario como
«No se pudo contactar con Groq», y un webhook rechazado por configuración no dejó ninguna traza.

Y el caso más grave no calla ni señala a otro: **afirma algo falso.** Pedirle al asistente «recuérdame
hoy a las 20:20 que tengo que hacer algo» devolvió «Listo, te recuerdo hoy a las 20:20», sin que se
creara ningún recordatorio. El modelo recibió la herramienta `set_reminder`, no la llamó, y el sistema
entregó su texto tal cual: `run.Actions` estaba vacío y nadie lo comparó con lo que la respuesta
afirmaba. El usuario confió en un aviso que nunca iba a llegar. No es una incapacidad del modelo: el
mismo modelo, en la misma conversación, sí llama a `create_note` y a `add_tags`. Sea cual sea la causa
de que no elija esa herramienta, el sistema no puede seguir presentando su palabra como un hecho.

El patrón se repite en los cuatro casos: **el fallo señala a un tercero — la red, Groq, Telegram — o
directamente a nada, en vez de a donde está, y la evidencia que lo corregiría es inalcanzable para
quien opera.** Esto no son cuatro bugs; es que la plataforma no es diagnosticable y que nada contrasta
lo que dice con lo que hizo.

## What Changes

- Los logs de la API llegan a donde quien opera los busca: salida estándar del contenedor, que es lo
  que `docker compose logs` lee. Hoy solo salen dos líneas de arranque y todo lo demás se queda en un
  fichero dentro del contenedor.
- Los registros de fallo dejan de atribuir la causa al tercero equivocado: cuando el error ocurre
  antes de que salga una petición (URL mal construida, configuración ausente), el registro lo dice,
  en vez de informar de que el destino era inalcanzable.
- El webhook de Telegram deja traza al rechazar una llamada, distinguiendo «la entrega está apagada»
  de «el secreto no coincide». La respuesta al llamante no cambia: sigue siendo un 401 sin detalle.
- El error que ve el usuario al validar su API key de Groq distingue qué tramo falló: no haber podido
  llegar al servicio de IA no es lo mismo que el servicio de IA no haber podido llegar a Groq.
- El asistente no puede afirmar una acción que no ha ejecutado. Hoy, si el modelo contesta «listo» sin
  llamar a ninguna herramienta, esa frase llega al usuario intacta aunque no se haya creado nada.
- Un recordatorio que no puede entregarse porque el usuario no tiene Telegram vinculado deja constancia
  en algún sitio donde se pueda ver, en vez de quedarse pendiente para siempre sin decir nada.
- El runbook de Telegram corrige su paso de verificación, que hoy manda leer por `docker compose logs`
  una línea que nunca sale por ahí.

## Capabilities

### New Capabilities

<!-- Ninguna: el change no añade funcionalidad, corrige cómo se reportan y se alcanzan los fallos
     de capacidades que ya existen. -->

### Modified Capabilities

- `platform-operations`: nueva exigencia de que los registros de la plataforma sean alcanzables por
  quien la opera allí donde está desplegada, y de que un fallo registrado identifique su causa real y
  no la del componente al que no se llegó a llamar.
- `reminders`: el rechazo de una llamada al webhook deja traza con el motivo, y la causa que se
  registra en un fallo de entrega es la real ("Delivery failures do not lose a reminder" ya exige
  registrar el motivo; lo que faltaba es que ese motivo sea cierto). Un recordatorio que vence sin
  chat vinculado deja de ser invisible.
- `ai-assistant`: la respuesta del asistente no puede afirmar una acción que no está entre las
  ejecutadas. "Answering without actions" ya exige que, sin soporte de acciones, la respuesta lo diga;
  falta el caso simétrico y hoy real: el modelo **sí** tiene las herramientas, no las usa, y afirma
  haberlo hecho. Incluye que el aviso de acciones no disponibles nombre también los recordatorios, que
  se quedaron fuera al añadirse la cuarta acción.
- `user-settings`: la validación de la API key de Groq informa de qué tramo de la cadena falló, en vez
  de atribuir a Groq cualquier fallo intermedio.

## Impact

- `Synap.Api/Program.cs`: configuración de Serilog (`UseKernelSerilog`), que hoy dirige todo a
  `/app/logs/log<fecha>.html` dentro del contenedor.
- `Synap.Infrastructure/Services/Telegram/TelegramSender.cs` y
  `Synap.Infrastructure/Services/Ai/AiServiceClient.cs`: los `catch` anchos que colapsan causas
  distintas en un único mensaje.
- `Synap.Api/Controllers/TelegramController.cs`: el rechazo silencioso de `IsFromTelegram()`.
- `Synap.Application/Features/Settings/SettingsErrors.cs`: los mensajes que ve el usuario.
- `Synap.Application/Features/Assistant/Agent/AssistantAgent.cs`: la salida del bucle que devuelve el
  texto del modelo sin contrastarlo con `run.Actions`.
- `ai-service/app/llm/groq_provider.py`: `ACTIONS_UNAVAILABLE_INSTRUCTIONS`, que solo nombra tres de
  las cuatro acciones, y `_raise_for_tool_error`, que traduce cualquier 400 con la subcadena "tool" a
  "el modelo no soporta herramientas" descartando el mensaje real de Groq.
- `Synap.Application/Features/Assistant/Agent/AgentTools.cs`: la definición de `set_reminder` — la
  única herramienta que el modelo no elige, mientras `create_note` y `add_tags` sí se ejecutan con el
  mismo modelo y en la misma conversación.
- `Synap.Application/Features/Reminders/ReminderDeliveryService.cs`: el `continue` sin traza cuando no
  hay chat vinculado.
- `docs/telegram-bot-runbook.md`: el paso 3.
- Sin cambios de base de datos ni de API pública. Ninguna respuesta HTTP cambia de forma ni de código.
- Fuera de alcance, aunque la sesión que motivó este change los destapó: el despliegue manual del VPS
  (un fix puede estar horas en `main` sin llegar a producción) y la deriva de variables entre
  contenedores recreados por separado. Son problemas de proceso de despliegue, no de la plataforma.
