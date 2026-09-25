# Design

## Context

Angular 22 con componentes standalone y estilos inline, PrimeNG 22 con un preset Aura y primario índigo, y `darkModeSelector: false`. El shell (`app-shell.component.ts`) es un flex horizontal con un sidebar de 220px y colores fijos. El asistente guarda los mensajes en un signal en memoria. Los estilos globales están en `styles.scss`. Este cambio parte de lo que deja `byok-groq-and-settings`: `MessageService`/`ConfirmationService` a nivel de app, `SettingsPage` y `status` en las respuestas.

## Goals / Non-Goals

**Goals:**
- Que la app sea usable como PWA en el iPhone: navegación con el pulgar, safe areas y sin zoom accidental en los inputs.
- Una sola fuente de colores (tokens) para que claro y oscuro salgan del mismo código.

**Non-Goals:**
- Streaming de respuestas (SSE). Aporta, pero cambia el contrato entre los tres servicios; se deja para otro cambio.
- Historial de conversaciones guardado en el servidor.
- Internacionalización a varios idiomas. Solo se unifica en español.
- Rediseñar de nuevo la identidad visual (colores de marca y logo), que acaba de hacerse en `frontend-design-overhaul`.

## Decisions

### 1. Barra inferior en móvil, sidebar en escritorio
- Un breakpoint en 768px. El shell pinta los dos elementos y el CSS decide cuál se muestra (`@media`).
- Se usa CSS en lugar de `BreakpointObserver` para no tener lógica en TS y evitar parpadeos al arrancar.
- En móvil: cabecera de 56px con la marca y `nav.bottom-nav` fija con 3 iconos y etiqueta. "Cerrar sesión" pasa a Configuración > Cuenta en móvil.
- `padding-bottom: calc(64px + env(safe-area-inset-bottom))` en `.content`, y `viewport-fit=cover` en `index.html`.
- Inputs con `font-size >= 16px` en móvil para que iOS no haga zoom.

*Alternativa descartada: un drawer con `p-drawer` y botón hamburguesa.* Añade un toque más por navegación y es menos natural en una PWA con solo 3 secciones.

### 2. Tema con la clase `.app-dark` y resolución previa al arranque
- `providePrimeNG({ theme: { options: { darkModeSelector: '.app-dark' } } })`.
- `ThemeService` guarda `'light' | 'dark' | 'system'` en `localStorage` (`synap.theme`). Con `system` escucha `matchMedia('(prefers-color-scheme: dark)')`.
- Un script inline pequeño en `index.html` aplica `.app-dark` al `<html>` antes de que arranque Angular, para evitar el parpadeo del tema claro.
- Los colores fijos de los componentes (`#6366f1`, `#1e1b4b`, `#312e81`, `rgba(255,255,255,…)`) pasan a variables CSS propias (`--synap-sidebar-bg`, `--synap-bubble-user-bg`…) definidas en `styles.scss` para `:root` y `.app-dark`, y apoyadas en los tokens `--p-*`.
- Selector de tema en Configuración > Apariencia con `p-selectbutton`.

*Alternativa descartada: guardar la preferencia en el backend.* Es una preferencia de dispositivo, y en otros dispositivos el tema del sistema es un buen valor por defecto. No merece una columna ni un endpoint.

### 3. Feedback centralizado
- `NotificationService`, una capa fina sobre `MessageService` con `success(msg)` y `error(msg)` y duración estándar.
- Los stores de notas lo llaman tras cada operación.
- `errorInterceptor` muestra un toast global para `status === 0` ("Sin conexión con el servidor") y `>= 500` ("Algo ha fallado en el servidor"). Los 4xx los gestiona cada store con su mensaje de negocio, para no duplicar avisos.
- Confirmación con `ConfirmationService.confirm` (`p-confirmdialog` en el shell) al borrar nota, key de Groq o token.

### 4. Fuentes navegables del asistente
- Python ya tiene `title` en `matches`, así que `/internal/assistant/ask` devuelve `sources: [{ id, title }]`. Si una nota no tiene título, se usa un fragmento del contenido de hasta 60 caracteres.
- .NET lo propaga en `AssistantAnswer.Sources`.
- `sourceNoteIds` se mantiene como campo derivado, para no romper clientes antiguos durante el despliegue.
- El front pinta `p-chip` con `routerLink` a `/app/notes/:id`.

*Alternativa descartada: que el front pida cada nota por id.* Serían N peticiones por respuesta.

### 5. Persistencia de la conversación
- `AssistantStore` serializa `messages` en `localStorage`, bajo la clave `synap.chat.<userId>`, con un `effect`.
- Límite: las últimas 50 interacciones, para no crecer sin fin.
- Los mensajes `pending` no se persisten.
- `AuthStore.logout()` borra todas las claves `synap.chat.*`.

*Alternativa descartada: `sessionStorage`.* Se pierde al cerrar la pestaña, y en una PWA eso equivale a perderla cada vez que se sale de la app.

### 6. Página 404
Ruta comodín `**` en `app.routes.ts` hacia `NotFoundPage`, un componente standalone ligero sin shell que ofrece un enlace a `/app/notes`.

## Risks / Trade-offs

- **[El chat en `localStorage` es legible por cualquiera con acceso al dispositivo]** → Mitigación: se borra al cerrar sesión, se limita a 50 interacciones y solo contiene respuestas sobre las notas propias del usuario.
- **[Los colores fijos no migrados no se verán bien en oscuro]** → Mitigación: una tarea de auditoría con `grep` de `#[0-9a-f]{3,6}` y `rgba(` en `src/app` y una revisión visual de cada página en los dos temas.
- **[La barra inferior tapa contenido o botones fijos]** → Mitigación: el padding inferior en `.content` y la verificación en 360px.
