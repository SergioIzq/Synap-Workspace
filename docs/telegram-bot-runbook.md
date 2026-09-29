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

Levanta la API con la nueva configuración:

```bash
docker compose up -d synap-api
docker compose logs -f synap-api | head -40
```

Con `TELEGRAM_ENABLED=false` verás `Reminder delivery is turned off; the poller will not run`. Con
`true` no aparece esa línea: el poller ya está sondeando cada minuto.

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

## 5. Probarlo de punta a punta

1. Entra en Synap → **Configuración** → **Telegram** → *Conectar Telegram*.
2. Abre el bot en Telegram y envíale el `/start <código>` que te muestra la web.
3. El bot responde «¡Listo! Recibirás tus recordatorios aquí 🔔».
4. Vuelve a la web, pulsa *Ya lo he enviado*: la sección pasa a **Conectado**.
5. Crea un recordatorio para dentro de dos minutos y espera. Debe llegar con sus botones.
6. Pulsa **⏰ En 1 hora**: el mensaje cambia a «Te lo recuerdo el …» y el recordatorio vuelve a estar
   pendiente en la web.

## 6. Desarrollo local

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
