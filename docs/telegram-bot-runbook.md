# Dar de alta el bot de Telegram (assistant-reminders, tarea 10.2)

Los recordatorios se entregan por Telegram. Esto es lo que **tú** tienes que ejecutar: crear el bot
con BotFather y apuntar su webhook a producción. No se puede hacer desde el entorno de desarrollo —
BotFather es una conversación en la app de Telegram, y el webhook necesita una URL pública con
HTTPS.

Hasta que termines, Synap funciona igual con `TELEGRAM_ENABLED=false`: los recordatorios se crean,
se listan, se editan y se cancelan, y simplemente no se entrega ninguno
(`specs/reminders`, "Reminders are inert while delivery is turned off").

## 0. Antes de empezar

- [ ] Synap desplegado y accesible por HTTPS (ver `deployment-runbook.md`).
- [ ] Acceso al `.env` del workspace en el VPS.

## 1. Crear el bot con BotFather

En Telegram, abre una conversación con [`@BotFather`](https://t.me/BotFather):

```
/newbot
```

Te pedirá dos cosas:

1. **Nombre** del bot, el que se ve en la cabecera del chat. Por ejemplo: `Synap`.
2. **Usuario**, que tiene que acabar en `bot` y ser único. Por ejemplo: `SynapRemindersBot`.

Responde con el token que te dé, que tiene esta pinta:

```
8123456789:AAH4k-ejemplo-no-uses-este-token-de-verdad
```

Ese token **es la credencial del bot**: quien lo tenga puede leer y escribir en su nombre. No lo
commitees; va solo en el `.env`.

Opcionalmente, en la misma conversación:

```
/setdescription   → Te aviso de tus recordatorios de Synap.
/setuserpic       → (sube un icono)
/setcommands      → start - Conectar tu cuenta de Synap
                    briefing - Enviarme mi briefing ahora
```

## 2. Generar el secreto del webhook

Telegram devuelve este valor en la cabecera `X-Telegram-Bot-Api-Secret-Token` en cada llamada, y el
endpoint rechaza cualquier petición que no lo traiga (`design.md` Decisión 4):

```bash
openssl rand -hex 32
```

## 3. Rellenar el `.env`

En el VPS, en el `.env` del workspace:

```bash
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=8123456789:AAH4k-el-token-de-BotFather
TELEGRAM_WEBHOOK_SECRET=el-valor-que-acabas-de-generar
TELEGRAM_BOT_USERNAME=SynapRemindersBot
```

`TELEGRAM_BOT_USERNAME` va **sin** la `@`: la web la pone al mostrar las instrucciones.

Levanta la API con la nueva configuración y busca la línea del poller:

```bash
docker compose up -d synap-api
docker compose logs synap-api | grep -i "reminder delivery"
```

Con `TELEGRAM_ENABLED=false` verás `Reminder delivery is turned off; the poller will not run`. Con
`true` no aparece esa línea: el poller ya está sondeando cada minuto.

El `grep` no es cosmético. El log de la API lleva los health checks de cada 30 segundos, así que la
línea de arranque queda enterrada a los pocos minutos; y `logs -f … | head` se queda esperando en
vez de terminar. Si no sale nada y el contenedor lleva rato levantado, recréalo para volver a ver el
arranque: `docker compose up -d --force-recreate synap-api`.

## 4. Registrar el webhook

Una sola llamada a la API de Telegram, sustituyendo el token, tu dominio y el secreto:

```bash
curl -sS "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook" \
  -d "url=https://synap.sergioizq.com/api/telegram/webhook" \
  -d "secret_token=<TELEGRAM_WEBHOOK_SECRET>" \
  -d "allowed_updates=[\"message\",\"callback_query\"]"
```

Respuesta esperada:

```json
{"ok":true,"result":true,"description":"Webhook was set"}
```

Compruébalo:

```bash
curl -sS "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/getWebhookInfo"
```

`url` debe ser la tuya, `pending_update_count` 0 y no debe haber `last_error_message`. Si ves
`SSL error` o `Connection refused`, Telegram no llega a tu dominio: revisa el proxy y el certificado
antes de seguir.

`allowed_updates` deja fuera todo lo que Synap no usa, así que el bot no recibe fotos, audios ni
mensajes de canales.

### Si Telegram recibe 401

El endpoint responde un 401 pelado, sin detalle, tanto si la entrega está apagada como si el secreto
no coincide: al llamante no se le dice nada porque está abierto a internet. El motivo sí queda en el
log, que es donde tienes que mirarlo:

```bash
docker compose logs synap-api | grep "webhook call was rejected"
```

- `delivery is turned off or no webhook secret is configured` → `TELEGRAM_ENABLED` no está a `true`,
  o falta `TELEGRAM_WEBHOOK_SECRET`. Repasa el paso 3 y recrea el contenedor.
- `the secret it carried does not match the configured one` → el `secret_token` que registraste en
  `setWebhook` no es el del `.env`. Vuelve a lanzar el `setWebhook` del paso 4 con el valor correcto.

Sin línea ninguna, la llamada no llegó a la API: mira el proxy y `getWebhookInfo`. Cada motivo se
registra como mucho una vez por minuto —el endpoint es público y cualquiera puede aporrearlo—, así
que no cuentes líneas para contar llamadas.

## 5. Probarlo de punta a punta

1. Entra en Synap → **Configuración** → **Telegram** → *Conectar Telegram*.
2. Abre el bot en Telegram y envíale el `/start <código>` que te muestra la web.
3. El bot responde «¡Listo! Recibirás tus recordatorios aquí 🔔».
4. Vuelve a la web, pulsa *Ya lo he enviado*: la sección pasa a **Conectado**.
5. Crea un recordatorio para dentro de dos minutos y espera. Debe llegar con sus botones.
6. Pulsa **⏰ En 1 hora**: el mensaje cambia a «Te lo recuerdo el …» y el recordatorio vuelve a estar
   pendiente en la web.
7. Envíale `/briefing` al bot. Debe contestar con el resumen del día —o decir que no tienes nada
   pendiente, si es el caso—, lo que confirma de paso que el chat quedó bien vinculado.

## 6. El briefing diario

El briefing va **sobre este mismo bot y este mismo enlace de chat**: no hay nada más que dar de
alta. Quien tenga Telegram conectado para sus recordatorios ya puede recibirlo; lo activa cada
usuario desde **Configuración → Briefing diario**, eligiendo la hora.

Dos cosas que conviene saber al operar:

- El barrido es **un servicio aparte** del poller de recordatorios, y corre cada 15 minutos. Si se
  cae, los recordatorios siguen entregándose; es a propósito.
- Con `TELEGRAM_ENABLED=false` no arranca, igual que el poller. Lo dice al arrancar:

```bash
docker compose logs synap-api | grep "briefing sweep will not run"
```

### `/briefing`, a demanda

El bot responde a `/briefing` enviando el resumen en el momento, sin esperar a la hora. No consume
el briefing automático del día: ese llega igual. Y a diferencia del automático, si no hay nada que
contar lo dice en vez de callarse.

Un chat que no esté vinculado a ninguna cuenta recibe la misma respuesta que cualquier mensaje que
el bot no entiende. Es deliberado: no se puede averiguar desde fuera si una cuenta existe.

### Leer el log

Todo lo del briefing sale por `docker compose logs synap-api`:

```bash
docker compose logs synap-api | grep -i briefing
```

| Lo que ves | Qué significa |
|---|---|
| `briefing sweep will not run` | La entrega está apagada en el despliegue. Nadie recibe nada. |
| `Briefings sent: N` | Ese barrido envió N briefings. |
| `was withheld: the user has no linked Telegram chat` | Lo tiene activado pero no ha conectado Telegram. **Sale una vez por usuario, no en cada barrido**, así que no cuentes líneas para contar barridos. El día queda sin resolver: en cuanto conecte, le llega el de hoy. |
| `could not be delivered; it will be tried again today` | Telegram rechazó el envío. El día queda sin resolver y se reintenta cada 15 minutos hasta su medianoche. |
| `The briefing of user … failed; the others are unaffected` | Algo reventó preparando el de ese usuario. Los demás sí se enviaron. |
| `The briefing sweep tick failed` | Reventó el barrido entero. Se reintenta en el siguiente; el servicio no se muere. |
| `A /briefing asked for by user … ended as …` | Alguien lo pidió a mano y no salió. El motivo va al final: `NoChatLinked` o `DeliveryFailed`. |

**Silencio no es error.** Un día sin recordatorios, sin notas sin etiquetar y sin hilos abiertos no
genera mensaje ni línea de log: el briefing automático calla y da el día por resuelto. Si alguien
dice que no le llega, mira primero si tiene algo que contar —pidiéndolo con `/briefing`, que sí
contesta siempre— antes de buscar una avería.

## 7. Desarrollo local

El webhook necesita una URL pública, así que en local tienes dos opciones:

- **Sin túnel**: deja `Telegram:InlineButtons` a `false` en `appsettings.Development.json`. Los
  recordatorios se envían, pero sin botones — que no tendrían a dónde responder.
- **Con túnel**: levanta [ngrok](https://ngrok.com/) y registra ese dominio como webhook.

  ```bash
  ngrok http 8081
  curl -sS "https://api.telegram.org/bot<TOKEN>/setWebhook" \
    -d "url=https://<algo>.ngrok-free.app/api/telegram/webhook" \
    -d "secret_token=<SECRETO>"
  ```

  Usa **un bot distinto** del de producción: un webhook por bot, y registrar el de ngrok borraría el
  de producción.

## Rollback

```bash
# 1. Deja de recibir actualizaciones.
curl -sS "https://api.telegram.org/bot<TOKEN>/deleteWebhook"

# 2. Apaga la entrega.
#    TELEGRAM_ENABLED=false en el .env
docker compose up -d synap-api
```

Las filas de `reminders` son inocuas con el poller parado: quedan pendientes y se entregan cuando
vuelvas a activarlo. Las migraciones son aditivas, no hay nada que deshacer en la base de datos.

Lo mismo vale para el briefing: `TELEGRAM_ENABLED=false` para el barrido y el comando a la vez, sin
tocar los ajustes de nadie. Nada se marca como enviado mientras está apagado, así que al volver a
activarlo el briefing de ese día sale en el siguiente barrido si su hora ya ha pasado.
