# Design

## Context

- **Canal elegido**: Telegram únicamente. Email y push quedan para otros changes.
- **Scheduler existente**: `IBackgroundJobQueue` es una cola en memoria que procesa inmediatamente; no sirve para recordatorios con fecha futura ni sobrevive a reinicios. Se necesita un mecanismo diferente.
- **Patrón de dominio de referencia**: `MemoryEntry` en el área `Users` — agregado simple con validación en fábrica, repositorio de lectura/escritura y comandos mediados. Los recordatorios siguen el mismo patrón.
- **Herramientas del asistente**: el bucle de herramientas de `assistant-agent-foundations` ya está en .NET (`AssistantAgent`). `set_reminder` se añade como una herramienta más.
- **Timezone**: el frontend envía la zona horaria en cada petición al asistente (y al crear recordatorios manualmente) como campo `timezone` (IANA, p. ej. `Europe/Madrid`). El servidor la **guarda** en `users.timezone` (última vista gana), porque el snooze se pulsa desde Telegram, donde no hay frontend que la envíe, y "mañana a las 9" necesita un huso horario. Si la columna está vacía, el servidor resuelve en UTC.

## Goals / Non-Goals

**Goals:**
- Crear recordatorios desde el asistente (lenguaje natural) y desde la web (selector).
- Entrega por Telegram con botones inline: confirmar, snooze y cancelar serie.
- Recordatorios únicos y recurrentes (diario, semanal, mensual).
- Snooze con tres opciones fijas: 1 hora, mañana a las 9, próxima semana.
- Vinculación de cuenta Telegram segura mediante token de un solo uso.

**Non-Goals:**
- Email, push o cualquier canal distinto de Telegram en v1.
- Historial de ocurrencias pasadas de recordatorios recurrentes.
- Recurrencias complejas (RRULE, "cada día laborable", "el tercer martes del mes").
- Snooze con tiempo libre (solo opciones fijas en el teclado inline).
- Recordatorios generados automáticamente sin petición explícita del usuario.

## Decisions

### 1. Poller por sondeo en BD en lugar de scheduler externo

Un `IHostedService` que despierta **cada minuto**, consulta `WHERE due_at <= NOW() AND sent_at IS NULL` y entrega. No se añade Hangfire, Quartz ni ninguna dependencia externa.

**Por qué:** el VPS es pequeño y compartido; añadir Hangfire requiere almacenamiento persistente externo o MySQL. Un poller en la misma BD que ya usamos es trivial, fiable y sin dependencias. La precisión de ±1 minuto es más que suficiente para recordatorios personales.

**Alternativa descartada:** Hangfire — más robusto pero requiere infraestructura adicional y es excesivo para el volumen esperado.

### 2. Fila reciclada para recordatorios recurrentes

Un recordatorio recurrente es **una sola fila** en la tabla. Al confirmarlo (`dismissed_at` recibido), el poller calcula la siguiente `due_at` según `recurrence`, y resetea `sent_at` y `dismissed_at` a NULL. La fila vive mientras la serie esté activa.

**Por qué:** crear una fila por ocurrencia añade complejidad (garbage collection, historial) sin valor para el caso de uso. Lo que importa es el próximo aviso, no los pasados.

**Consecuencia asumida:** no hay historial de cuántas veces se cumplió un recordatorio recurrente.

**Callbacks obsoletos:** como la fila se recicla, pulsar dos veces "✓ Esta vez" en el mismo mensaje avanzaría la serie dos ocurrencias. El `callback_data` incluye la `due_at` de la ocurrencia entregada; si no coincide con la `due_at` actual de la fila, el callback se ignora.

Para que esa comparación pueda cuadrar, `due_at` se almacena **truncada al segundo**: el
`callback_data` lleva la ocurrencia como timestamp Unix (segundos) y Postgres guardaría
microsegundos, así que sin truncar el guardia nunca coincidiría y ningún botón funcionaría. Los
recordatorios son de precisión de minuto, así que no se pierde nada.

### 3. Expresión de recurrencia como string simple

El campo `recurrence` almacena uno de: `null` (único), `"daily"`, `"weekly:<0-6>"` (0 = lunes), `"monthly:<1-28>"`.

No se usa iCal RRULE. El LLM parsea la intención del usuario y produce uno de estos valores; el selector de la web ofrece los mismos valores con labels. El cálculo de la siguiente ocurrencia es determinista con un switch sobre este string.

### 4. Telegram: webhook para callbacks inline, no long-polling

El bot recibe mensajes y callbacks de botones vía **webhook** (`POST /api/telegram/webhook`). Long-polling requiere un bucle en background que compite con el poller; un webhook es más limpio y ya tenemos HTTPS en producción.

En desarrollo local se necesita un túnel (ngrok o similar) o deshabilitar los botones inline y usar solo envío.

**Flujo de entrega:**
```
Poller detecta due_at <= NOW() (todos los vencidos del tick)
  → Para cada recordatorio, con 5 segundos de delay entre envíos:
      TelegramSender.SendAsync(chat_id, text, inline_keyboard)
      Marca sent_at = NOW()
  → Si falla (chat_id inválido, bot bloqueado): log + deja sent_at = NULL para reintentar en el siguiente tick
```

**Teclado inline según tipo:**
- Único: `[ ✓ Hecho ] [ ⏰ En 1 hora ] [ ⏰ Mañana ] [ ⏰ Próxima semana ]`
- Recurrente: `[ ✓ Esta vez ] [ ⏰ En 1 hora ] [ ⏰ Mañana ] [ ⏰ Próxima semana ] [ ✗ Cancelar serie ]`

### 5. Vinculación de cuenta Telegram con token de un solo uso

Para asociar el `chat_id` de Telegram con un usuario de Synap de forma segura y sin exponer credenciales:

```
1. Usuario pulsa "Conectar Telegram" en Configuración
2. Synap genera token aleatorio (32 bytes hex), TTL 15 min, guardado en BD
3. UI muestra: "Envía /start <token> al bot @SynapBot"
4. Usuario envía el mensaje → webhook recibe el update
5. Webhook extrae el token, busca al usuario, guarda chat_id, borra el token
6. Bot responde: "¡Listo! Recibirás tus recordatorios aquí 🔔"
7. El endpoint de vinculación devuelve OK; el frontend refresca el estado
```

El token es de un solo uso y expira. Si caduca, el usuario puede generar uno nuevo. El `chat_id` se guarda en la tabla `users` como columna nullable.

### 6. El LLM produce `due_at` en UTC

Cuando el asistente interpreta "recuérdame el viernes a las 9", la herramienta `set_reminder` recibe el `due_at` ya como UTC calculado por el LLM a partir de:
- La fecha y hora actual (incluida en el system prompt)
- La timezone enviada por el frontend

El LLM no devuelve lenguaje natural ni un offset: devuelve un ISO 8601 UTC. Si la expresión es ambigua ("el viernes" sin hora), el LLM usa las 9:00 del huso horario del usuario como valor por defecto.

### 7. Datos

```
reminders
─────────────────────────────────────────────────────
id            uuid PK
user_id       uuid FK users ON DELETE CASCADE
text          varchar(500) NOT NULL
note_id       uuid FK notes NULL (ON DELETE SET NULL)
due_at        timestamptz NOT NULL
sent_at       timestamptz NULL
dismissed_at  timestamptz NULL
recurrence    varchar(20) NULL   -- null | "daily" | "weekly:1" | "monthly:15"
created_at    timestamptz NOT NULL DEFAULT now()

INDEX (user_id)
INDEX (due_at) WHERE sent_at IS NULL   -- sondeo del poller

users (columnas añadidas)
─────────────────────────
telegram_chat_id   varchar(20) NULL
telegram_link_token        varchar(64) NULL
telegram_link_token_expires timestamptz NULL
timezone           varchar(64) NULL   -- IANA, última enviada por el frontend
```

`note_id` se pone a NULL si la nota se borra (`ON DELETE SET NULL`), no se borra el recordatorio.

**Nota sobre los tipos de fecha:** el esquema existente usa `timestamp without time zone` en todas
las tablas, con `Npgsql.EnableLegacyTimestampBehavior` activado en `Program.cs`. Las columnas de
`reminders` siguen esa convención en lugar de `timestamptz` para no mezclar dos tipos en el mismo
esquema. Todos los instantes son UTC por construcción: `Reminder` fija el `DateTimeKind` al
crear, editar y reprogramar.

## Risks / Trade-offs

- **[Precisión de ±1 minuto]** El poller no dispara exactamente a la hora indicada.
  → Aceptado. Para recordatorios personales la diferencia es irrelevante.

- **[Fallo de entrega en Telegram]** Si el usuario bloquea el bot o el `chat_id` queda inválido, el recordatorio nunca se entrega.
  → Mitigación: tras 3 fallos consecutivos en el mismo recordatorio, se marca con un estado `delivery_failed` y se muestra un aviso en la web. La columna `delivery_failed_at` puede añadirse si hace falta; por ahora se registra en logs.

- **[El LLM malinterpreta fechas relativas]** "El viernes" puede ser el próximo o el de esta misma semana si es lunes por la noche.
  → Mitigación: el LLM siempre elige el viernes más próximo en el futuro, y la respuesta al usuario confirma la fecha y hora exactas calculadas ("Recordatorio creado para el viernes 3 de octubre a las 9:00").

- **[Webhook de Telegram no disponible en local]** El webhook necesita HTTPS accesible externamente.
  → Mitigación: en desarrollo, el constructor de `TelegramSender` detecta el entorno y desactiva los botones inline (solo envío sin callbacks). El desarrollador puede usar ngrok para probar el flujo completo.

- **[Token de vinculación expuesto en pantalla]** El token de `/start` se muestra en la UI.
  → Es de un solo uso, caduca en 15 min, y solo sirve para vincular Telegram, no para autenticarse en Synap.

## Migration Plan

1. Migración EF Core: tabla `reminders`, columnas `telegram_*` en `users`.
2. Desplegar .NET con el poller apagado (flag de config `Telegram:Enabled = false`).
3. Registrar el bot con BotFather y configurar el webhook apuntando al endpoint de producción.
4. Activar `Telegram:Enabled = true` y desplegar el frontend con la sección "Recordatorios" y "Conectar Telegram".
5. **Rollback**: desactivar `Telegram:Enabled`. Las filas de `reminders` son inocuas si el poller no corre. Las migraciones son aditivas.

