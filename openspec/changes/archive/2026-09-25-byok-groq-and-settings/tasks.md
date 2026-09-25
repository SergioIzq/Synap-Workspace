# Tasks

## 1. ai-service (Python)

- [x] 1.1 Dividir `LlmProviderUnavailableError` en `LlmInvalidCredentialsError`, `LlmRateLimitedError` y `LlmProviderUnavailableError`. Mapear en `GroqProvider` 401→credenciales, 429→rate limit y resto→no disponible. Verificar con tests usando `httpx.MockTransport`.
- [x] 1.2 Cambiar `LlmProvider.generate_answer` para que reciba `api_key` y `model` por parámetro. Eliminar `groq_api_key` de `Settings` y mantener `groq_model` como modelo por defecto. Verificar que `grep -r groq_api_key app/` no devuelve nada.
- [x] 1.3 Añadir `groq_api_key` y `groq_model` (opcional) a `AskRequest` y `status` a `AskResponse` (`ok | no_relevant_notes | invalid_key | rate_limited | unavailable`). Traducir los mensajes a español. Verificar con tests de `/internal/assistant/ask` para cada estado.
- [x] 1.4 Crear `POST /internal/llm/models`, protegido con la key interna, que valide la key y devuelva los modelos de chat filtrados o el estado de error. Verificar con tests de los casos 200, 401 y error de red.
- [x] 1.5 Confirmar que ningún log ni mensaje de excepción incluye la key. Verificar con un test que fuerza un error y comprueba que la key no aparece en `caplog`.

## 2. Backend .NET: dominio y persistencia

- [x] 2.1 Añadir a `User` las propiedades `GroqApiKeyEncrypted`, `GroqApiKeyLast4`, `GroqApiKeyUpdatedAt` y `GroqModel`, y los métodos `SetGroqApiKey(encrypted, last4)`, `ClearGroqApiKey()` y `SetGroqModel(model?)`. Verificar con tests unitarios de dominio.
- [x] 2.2 Configurar las columnas en `UserConfiguration` y generar la migración `AddUserGroqSettings`. Verificar que `dotnet ef migrations script` solo añade columnas nullable.
- [x] 2.3 Crear `ISecretProtector` en Shared.Application y `AesGcmSecretProtector` en Infrastructure (formato `v1:nonce:cipher`), leyendo `SECRETS_ENCRYPTION_KEY` y fallando al arrancar si falta o no mide 32 bytes. Verificar con tests unitarios de ida y vuelta, manipulación del texto cifrado (debe fallar) y clave inválida.

## 3. Backend .NET: cliente IA y asistente

- [x] 3.1 Ampliar `IAiServiceClient` con `ListModelsAsync(apiKey)` y pasar key y modelo en `AskAsync`. Añadir `AssistantAnswerStatus` y `Status` a `AssistantAnswer`. Si el ai-service no responde, devolver `unavailable` con mensaje en español. Verificar ampliando `AiServiceClientTests`.
- [x] 3.2 En `AskAssistantQueryHandler`, cargar el usuario y devolver `key_missing` sin llamar al ai-service si no hay key. Si la hay, descifrarla (un fallo de descifrado cuenta como `invalid_key`) y usar su modelo o el `Ai:DefaultGroqModel`. Verificar con tests unitarios del handler.

## 4. Backend .NET: API de settings

- [x] 4.1 Crear la query `GetSettings` y la respuesta con `email` y el bloque `ai` (key enmascarada, modelo y modelo por defecto). Verificar que el JSON nunca contiene la key en claro.
- [x] 4.2 Crear el comando `SaveGroqApiKey`: valida con `ListModelsAsync` y, según el resultado, cifra y guarda, o devuelve `Error.Validation` ("La API key de Groq no es válida.") o un error de "no se pudo validar, inténtalo más tarde". Verificar con tests de los tres caminos.
- [x] 4.3 Crear el comando `DeleteGroqApiKey` y la query `ListGroqModels`. Verificar con tests.
- [x] 4.4 Crear el comando `SetGroqModel`, que valida contra la lista, con `null` para volver al modelo por defecto. Verificar con un test que un modelo desconocido se rechaza y conserva el anterior.
- [x] 4.5 Crear `SettingsController` con las cinco rutas del diseño y `AiHeavy` en las que llaman a Groq. Verificar con `Synap.Api.http` o Swagger contra la API local.
- [x] 4.6 Añadir un test de integración: el usuario A guarda una key, el usuario B consulta settings y pregunta al asistente, y nunca ve ni usa la key de A.

## 5. Orquestación y documentación

- [x] 5.1 En `docker-compose.yml` y `.env.example`, eliminar `GROQ_API_KEY`, añadir `SECRETS_ENCRYPTION_KEY` (obligatoria en la API) y pasar `GROQ_MODEL` también a la API como `Ai__DefaultGroqModel`. Verificar que `docker compose config` resuelve sin errores.
- [x] 5.2 Actualizar `docs/deployment-runbook.md` (generar y respaldar la clave maestra, pasos de migración y rollback) y los README de los repos. Verificar por revisión.

## 6. Frontend: settings

- [x] 6.1 Añadir los modelos `UserSettings`, `AiSettings` y `GroqModel`, y `SettingsService` con las cinco llamadas. Verificar con tests del servicio usando `HttpTestingController`.
- [x] 6.2 Crear `SettingsStore` (signals) con `load`, `saveGroqKey`, `deleteGroqKey`, `loadModels`, `setModel` y `hasGroqKey` computado. Verificar con tests del store.
- [x] 6.3 Registrar `MessageService` y `ConfirmationService` a nivel de app y colocar `<p-toast>` y `<p-confirmdialog>` en el shell. Verificar que un toast de prueba se muestra.
- [x] 6.4 Crear `SettingsPage` con la ruta `/app/settings` y la sección "Asistente IA" (estado, key enmascarada, formulario con `p-password`, eliminar con confirmación, enlace a la consola de Groq, nota de privacidad y selector de modelo). Verificar a mano que se guarda una key válida, se rechaza una inválida con mensaje, se borra y se cambia de modelo.
- [x] 6.5 Crear la sección "Atajo de iOS" (estado, generar o regenerar con confirmación, token visible una vez con botón de copiar y enlace a las instrucciones). Verificar a mano que tras generar y recargar solo se ve el estado.
- [x] 6.6 Crear la sección "Cuenta" con el email. Verificar a mano.
- [x] 6.7 Añadir el enlace "Configuración" (`pi pi-cog`) al sidebar de `app-shell`. Verificar que navega y queda marcado como activo.

## 7. Frontend: asistente

- [x] 7.1 Añadir `status` al modelo de respuesta del asistente y eliminar el texto inglés del store. Verificar con tests del store por estado.
- [x] 7.2 En `AssistantPage`, cargar los settings y, si no hay key, mostrar el aviso con el botón "Configurar API key" y deshabilitar el input. Verificar a mano con un usuario sin key.
- [x] 7.3 Pintar cada respuesta según su `status` (estilo de aviso para los errores y botón a Configuración en `key_missing` e `invalid_key`, que además refresca los settings). Verificar a mano con una key revocada.

## 8. Verificación end-to-end

- [x] 8.1 Con `docker compose up --build`, hacer este recorrido: registrar un usuario nuevo, ver el aviso en el asistente, guardar la key, elegir modelo, preguntar y obtener una respuesta fundamentada, borrar la key y comprobar que vuelve el aviso. Confirmar además que `GROQ_API_KEY` ya no existe en ningún contenedor (`docker compose exec ai-service env | grep -i groq`).
