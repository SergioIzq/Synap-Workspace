# Proposal

## Why

Synap es una PWA pensada para capturar desde el iPhone, pero su layout solo funciona en escritorio: el sidebar ocupa 220px fijos y no hay navegación móvil. Además faltan piezas que se esperan de una web profesional:

- **Modo oscuro**: PrimeNG está configurado con `darkModeSelector: false`.
- **Confirmación y feedback**: borrar una nota no pide confirmación y no hay avisos de éxito.
- **Página 404**: no existe.
- **Asistente**: las respuestas dicen "basado en N notas" pero no enlazan a ellas, y la conversación se pierde al recargar.

## What Changes

- **Layout responsive**:
  - Por debajo de 768px, el sidebar se sustituye por una barra de navegación inferior fija (Notas, Asistente, Configuración) y una cabecera compacta con la marca.
  - Respeta las safe areas de iOS (`env(safe-area-inset-*)`).
  - Hay que revisar las páginas (lista, detalle, asistente, auth y configuración) para que no haya scroll horizontal en 360px.
- **Tema claro, oscuro y sistema**:
  - Preferencia elegida por el usuario en Configuración (nueva sección *Apariencia*), recordada en el dispositivo y aplicada antes del primer pintado para evitar el parpadeo.
  - Los colores fijos (`#6366f1`, gradientes del sidebar…) pasan a tokens.
- **Feedback y acciones destructivas**:
  - Borrar una nota pide confirmación.
  - Crear, editar, borrar y etiquetar notas muestran un toast de éxito o de error.
  - Los errores HTTP no controlados (500, red caída) muestran un toast global en español.
- **Asistente**:
  - Las notas fuente de cada respuesta se muestran como chips con título y enlazan a la nota. El backend pasa a devolver id y título de cada fuente.
  - La conversación persiste en el dispositivo durante la sesión del usuario, con un botón "Nueva conversación".
  - Cada respuesta tiene un botón de copiar.
  - Sugerencias de preguntas en el estado vacío.
- **Página 404** para rutas desconocidas, con vuelta a Notas.
- **Estados vacíos** con icono y llamada a la acción en notas (sin notas, sin resultados de búsqueda) y en el asistente.
- **Atajos de teclado**: `/` enfoca la búsqueda y `Ctrl/⌘+Enter` guarda la nota en captura y edición.
- **Coherencia de idioma**: todo el texto visible, incluidos los mensajes que llegan del backend, en español.

Depende de `byok-groq-and-settings`, que crea la página de Configuración y el sistema de toasts sobre el que se construye este cambio.

## Capabilities

### New Capabilities
- `web-experience`: comportamiento transversal de la aplicación web. Navegación adaptable a móvil, preferencia de tema, confirmación de acciones destructivas, feedback de operaciones, página de ruta no encontrada e idioma único.

### Modified Capabilities
- `ai-assistant`: las respuestas exponen sus notas fuente de forma navegable (id y título) y la conversación persiste en el dispositivo.

## Impact

- **Synap-Frontend** (la mayor parte):
  - `app-shell` (layout responsive y barra inferior), `app.config.ts` (selector de modo oscuro), `styles.scss` (tokens y utilidades responsive) e `index.html` (script de tema previo al arranque y `viewport-fit=cover`).
  - Páginas de notas y asistente, `SettingsPage` (sección Apariencia), nuevo `NotFoundPage`, `ThemeService`, `error.interceptor` (toast global) y `AssistantStore` (persistencia).
- **Synap-Backend**: `AssistantAnswer` y la respuesta de `/ask` incluyen `sources: [{ id, title }]`, que obtiene Python de la misma consulta de similitud. Se mantiene `sourceNoteIds` por compatibilidad.
- **Sin dependencias nuevas**: PrimeNG ya incluye toast, confirmdialog y los tokens de tema oscuro de Aura.
