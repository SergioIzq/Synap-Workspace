# Design

## Context

La generación vive en el ai-service de Python (`GroqProvider`, `settings.groq_api_key`). La tabla de usuarios la posee .NET (`User`, EF Core), que llama a Python por red interna con `X-Internal-Api-Key`. Los embeddings son locales (fastembed), así que la key solo interviene en `/ask`. `/ask` "siempre devuelve 200" y hoy colapsa todo fallo en un mensaje genérico en inglés. En el frontend ya existen `AuthService.generateApiToken()` y `getApiTokenStatus()`, pero no hay pantalla que los use.

## Goals / Non-Goals

**Goals:**
- Que la key de cada usuario nunca salga de .NET salvo hacia Python, en la petición concreta que la necesita.
- Mantener el ai-service sin estado respecto a secretos de usuario: no lee keys de la base de datos.
- Un único contrato de estados del asistente que el frontend pueda mapear a mensajes y acciones.

**Non-Goals:**
- Soportar otros proveedores (OpenAI, Anthropic…). El diseño no lo impide, pero no se construye aquí.
- Cambio de contraseña y borrado de cuenta: van en `backend-hardening`.
- Rotación automática de la clave maestra de cifrado. Se deja preparada con un prefijo de versión, sin herramientas.

## Decisions

### 1. Almacenamiento: columnas en `users`, cifrado AES-256-GCM con clave maestra en variable de entorno
Columnas nuevas: `groq_api_key_encrypted` (text, nullable), `groq_api_key_last4` (varchar(4)), `groq_api_key_updated_at` (timestamptz) y `groq_model` (varchar(128), nullable).

Formato del texto cifrado: `v1:<base64 nonce>:<base64 ciphertext+tag>`. La clave maestra de 32 bytes llega en base64 por `SECRETS_ENCRYPTION_KEY` y se valida al arrancar: si falta o es inválida, la API no arranca. Se implementa detrás de `ISecretProtector` (`Protect`/`Unprotect`) en `Synap.Shared.Application.Interfaces`, con la implementación en Infrastructure.

*Alternativa descartada: ASP.NET Core Data Protection.* Obliga a persistir el key ring (volumen o tabla) y a gestionar su ciclo de vida. Para un solo secreto por usuario, una clave explícita es más transparente, portable entre despliegues y fácil de respaldar.

*Alternativa descartada: guardar la key en el cliente (localStorage) y enviarla en cada petición.* Se perdería en otros dispositivos y el Atajo de iOS no podría usarla. Además, expone la key a cualquier XSS.

### 2. La key viaja de .NET a Python por petición
`AskAssistantQueryHandler`:
1. Carga el usuario.
2. Si no tiene key, devuelve `status = "key_missing"` sin llamar a Python.
3. Si la tiene, la descifra y llama a `/internal/assistant/ask` con `{ user_id, question, groq_api_key, groq_model }`.

`GroqProvider.generate_answer(question, context, api_key, model)` deja de leer `settings`. `groq_api_key` se elimina de `Settings`. `groq_model` se queda como **modelo por defecto**, que no tiene coste para el propietario.

*Alternativa descartada: que Python lea y descifre la key de la base de datos.* Duplicaría la clave maestra en dos servicios y rompería la separación actual, en la que .NET posee a los usuarios.

### 3. Validación y listado de modelos a través de Python
Endpoint interno nuevo `POST /internal/llm/models` con `{ api_key }`. Llama a `GET https://api.groq.com/openai/v1/models`:
- **200**: devuelve la lista filtrada a modelos de chat (se excluyen `whisper*`, `*guard*`, `*tts*` y los inactivos).
- **401**: devuelve `{ status: "invalid_key" }`.
- **Otro error**: devuelve `{ status: "unavailable" }`.

Guardar una key y listar modelos usan este mismo endpoint. Así todo el conocimiento sobre Groq sigue en `app/llm`, fiel al principio de "proveedor detrás de una interfaz".

*Alternativa descartada: que .NET llame a Groq directamente.* Añadiría una segunda integración con Groq y otro punto de mantenimiento.

### 4. Contrato de estados del asistente
`/internal/assistant/ask` y `POST /api/assistant/ask` siguen respondiendo 200 y añaden `status`:

| status | Origen | Mensaje (es) | Acción en el front |
|---|---|---|---|
| `ok` | respuesta generada | la respuesta | — |
| `no_relevant_notes` | sin coincidencias | "No he encontrado nada relevante en tus notas." | — |
| `key_missing` | .NET, antes de llamar | "Necesitas configurar tu API key de Groq." | Botón a Configuración |
| `invalid_key` | Groq 401 | "Tu API key de Groq ya no es válida. Actualízala en Configuración." | Botón a Configuración |
| `rate_limited` | Groq 429 | "Has alcanzado el límite de tu cuota de Groq. Inténtalo más tarde." | — |
| `unavailable` | resto de fallos, o ai-service caído | "El asistente no está disponible temporalmente." | — |

`LlmProviderUnavailableError` se divide en `LlmInvalidCredentialsError`, `LlmRateLimitedError` y `LlmProviderUnavailableError`. `AssistantAnswer` gana la propiedad `Status`, un enum serializado como camelCase string, igual que `NoteType`. Los textos pasan a español en Python, y .NET usa el mismo mensaje para `key_missing` y para su propio fallback de `unavailable`.

*Alternativa descartada: devolver 4xx para `key_missing`.* El resto de estados ya son 200 con mensaje, y un solo formato simplifica store y UI. La defensa real está igualmente en el backend, porque nunca llama al proveedor.

### 5. API de settings
Nuevo `SettingsController` en `api/settings`, autenticado por la política global:
- `GET /api/settings` → `{ email, ai: { hasGroqKey, groqKeyMasked, groqKeyUpdatedAt, groqModel, defaultGroqModel } }`
- `PUT /api/settings/ai/groq-key` `{ apiKey }` → valida (Decisión 3), cifra, guarda y devuelve el bloque `ai`. Una key inválida es un `Error.Validation` con mensaje en español.
- `DELETE /api/settings/ai/groq-key` → borra la key y el modelo.
- `GET /api/settings/ai/models` → modelos para la key guardada.
- `PUT /api/settings/ai/model` `{ model }` → valida que esté en la lista; `null` restablece el modelo por defecto.

`PUT groq-key`, `GET models` y `PUT model` llevan `[EnableRateLimiting(AiHeavy)]` porque llaman a Groq. Los comandos y consultas siguen el patrón CQRS existente (`Features/Settings/...`). El token de iOS reutiliza los endpoints actuales de `/api/auth/api-token`.

`DefaultGroqModel` se expone en la configuración de .NET (`Ai:DefaultGroqModel`). Toma su valor de la misma variable `GROQ_MODEL` del compose, para que la UI pueda mostrar "Por defecto (x)".

### 6. Frontend
- `SettingsService` (HTTP) y `SettingsStore` (signals simples, como el resto de stores) con `settings`, `hasGroqKey` computado, `models`, `loading` y `saving`.
- Ruta `/app/settings` con carga diferida y página `SettingsPage`, compuesta por tres `p-card`:
  1. **Asistente IA**:
     - Estado con `p-tag`: configurada o no configurada.
     - Si está configurada, la key enmascarada.
     - `p-password` sin feedback, con toggle, para pegar la key.
     - Botones Guardar, Cambiar y Eliminar; eliminar pide confirmación con `p-confirmdialog`.
     - Enlace a `https://console.groq.com/keys` y nota de privacidad (cifrada, nunca visible de nuevo).
     - `p-select` de modelos, habilitado solo con key.
  2. **Atajo de iOS**: estado del token, botón Generar o Regenerar (con confirmación si ya existe), token visible una sola vez con botón de copiar (Clipboard API) y enlace a las instrucciones.
  3. **Cuenta**: email.
- Feedback con `p-toast` (`MessageService` a nivel de app).
- Sidebar: enlace "Configuración" (`pi pi-cog`) encima de "Cerrar sesión".
- `AssistantPage`:
  - Al iniciarse, si el store no tiene settings cargados, llama a `settingsStore.load()`.
  - Si `!hasGroqKey`, muestra un `p-message severity="warn"` con explicación y botón "Configurar API key" (`routerLink="/app/settings"`, `fragment="ai"`) y deshabilita el input.
  - Cada respuesta se pinta según su `status`. `invalid_key` y `key_missing` incluyen el botón a Configuración; si llega `invalid_key`, el store refresca los settings.
- `ChatMessage` o `AssistantAnswer` en el front ganan `status`. Se elimina el texto inglés "Something went wrong…".

## Risks / Trade-offs

- **[Se pierde `SECRETS_ENCRYPTION_KEY`]** → Todas las keys guardadas quedan ilegibles. Mitigación: el descifrado fallido se trata como `invalid_key`, el usuario vuelve a introducirla y el sistema sigue funcionando. El runbook documenta que hay que respaldar la variable.
- **[La key viaja en claro por la red interna de Docker]** → Es la misma red por la que ya viaja el contenido de las notas. Python no la persiste ni la registra: `str(exc)` de httpx incluye la URL pero no las cabeceras, y se revisa que ningún log incluya el body.
- **[Los usuarios actuales pierden el asistente en el despliegue]** → Es el comportamiento pedido. El aviso en la página de asistente les guía en un clic.
- **[La lista de modelos de Groq cambia]** → Si el modelo guardado desaparece, Groq responde 404/400 y se trata como `unavailable`. Mitigación: la página de Configuración marca el modelo guardado como "no disponible" si no aparece en la lista, y se puede volver al modelo por defecto.
- **[Descifrado en cada pregunta]** → AES-GCM sobre unos 60 bytes tiene un coste despreciable frente a la llamada al LLM.

## Migration Plan

1. Generar la clave maestra con `openssl rand -base64 32` y añadir `SECRETS_ENCRYPTION_KEY` al `.env` del servidor.
2. Desplegar el backend. La migración EF añade columnas nullable, así que no hay pérdida de datos.
3. Desplegar el ai-service. Eliminar `GROQ_API_KEY` del `.env` y del compose.
4. Desplegar el frontend.
5. **Rollback**: revertir las imágenes. Las columnas nuevas son nullable y la versión anterior las ignora; para restaurar el comportamiento anterior basta con volver a poner `GROQ_API_KEY`.
