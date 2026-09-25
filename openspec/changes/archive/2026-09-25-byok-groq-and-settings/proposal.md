# Proposal

## Why

Hoy todas las respuestas del asistente se generan con una única API key de Groq (la del propietario, `SYNAP_AI_GROQ_API_KEY`). Con registro abierto, cualquier usuario consume la cuota y el coste del propietario. Cada usuario debe traer su propia key de Groq ("bring your own key") para que el uso del asistente no le cueste nada al propietario. Además, la app no tiene ninguna pantalla de configuración: el token personal del Atajo de iOS ya tiene endpoints y servicio Angular, pero ningún usuario puede generarlo desde la UI.

## What Changes

- **Key de Groq por usuario**: cada usuario puede guardar, reemplazar y eliminar su propia API key de Groq. Se valida contra Groq antes de guardarse, se almacena cifrada y nunca se devuelve en claro (solo enmascarada, p. ej. `gsk_…a1B2`).
- **Selección de modelo por usuario**: el usuario elige qué modelo de chat de Groq usa el asistente, entre los disponibles para su key. Si no elige, se usa el modelo por defecto configurado en el servidor.
- **BREAKING (operación)**: se elimina por completo la key global `SYNAP_AI_GROQ_API_KEY`. No hay fallback: sin key propia el asistente no genera respuestas.
- **Asistente bloqueado sin key**: al entrar al asistente sin key configurada, el usuario ve un aviso con acceso directo a Configuración y no puede enviar preguntas. El backend también rechaza la pregunta sin llamar al proveedor.
- **Errores del proveedor diferenciados**: key inválida o revocada, cuota agotada o límite de ritmo y servicio no disponible se comunican por separado y en español, en lugar del genérico "temporarily unavailable".
- **Página de Configuración** (`/app/settings`) con entrada "Configuración" en el menú lateral y estas secciones:
  - *Asistente IA*: key de Groq (estado, alta, cambio, borrado, enlace a la consola de Groq) y selector de modelo.
  - *Atajo de iOS*: estado del token personal, generar o regenerar, y copiar al portapapeles.
  - *Cuenta*: email del usuario (el cambio de contraseña y el borrado de cuenta llegan en `backend-hardening`).

## Capabilities

### New Capabilities
- `user-settings`: configuración personal del usuario. Gestión de su key de Groq y del modelo del asistente, y gestión del token personal de acceso desde la UI.

### Modified Capabilities
- `ai-assistant`: la generación de respuestas usa exclusivamente la key del propio usuario; se añade el bloqueo cuando no hay key y se diferencian los fallos del proveedor (key inválida, cuota agotada, no disponible).

## Impact

- **Synap-Backend (.NET)**:
  - Columnas nuevas en `users`: key cifrada, últimos 4 caracteres, fecha de actualización y modelo elegido, más su migración EF.
  - Servicio de cifrado simétrico y un secreto nuevo, `SECRETS_ENCRYPTION_KEY`.
  - Endpoints nuevos `/api/settings/**`.
  - Cambios en `AskAssistantQueryHandler`, `AiServiceClient` y `AssistantAnswer`.
- **Synap-Backend (ai-service, Python)**:
  - `GroqProvider` recibe la key y el modelo por petición.
  - Endpoint interno nuevo para validar una key y listar sus modelos.
  - `/internal/assistant/ask` devuelve un `status` tipado.
  - Se elimina `groq_api_key` de la configuración.
- **Synap-Frontend**:
  - Ruta, página y store de Configuración, más el enlace en el sidebar.
  - Aviso y bloqueo en el asistente, y mensajes por estado.
  - Modelos y servicios de settings.
- **Orquestación**: `docker-compose.yml` y `.env.example` pierden `GROQ_API_KEY` y ganan `SECRETS_ENCRYPTION_KEY`; hay que actualizar el runbook de despliegue.
- **Dependencias**: ninguna nueva. El cifrado usa `System.Security.Cryptography.AesGcm` y la validación de keys reutiliza `httpx`.
