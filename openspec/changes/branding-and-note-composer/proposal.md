# Proposal

## Why

Capturar una nota con título o etiquetas exige hoy dos pasos: crearla con la captura rápida (solo contenido, siempre de tipo texto) y volver a entrar para editarla. Además, la app no parece un producto terminado:

- el favicon y los iconos de la PWA son los de Angular, y el manifest se llama `synap-frontend`;
- los fragmentos de código y los enlaces se pintan como texto normal, porque la API devuelve el tipo en PascalCase (`"CodeSnippet"`) y el front compara con `'codeSnippet'`;
- Configuración desaprovecha la pantalla del portátil con una única columna de 760 px;
- las pantallas de login y registro son un formulario sin identidad.

## What Changes

- **Identidad visual**:
  - Favicon SVG con el logo del sidebar sobre el gradiente índigo de la marca.
  - Iconos PNG de la PWA de 72 a 512 px (maskable).
  - `apple-touch-icon` de 180 px.
  - Manifest con nombre "Synap" y colores de marca.
  - Se eliminan los iconos de Angular.
- **Compositor de notas**: la captura rápida se despliega al enfocarla y permite, en un solo paso:
  - título opcional;
  - contenido multilínea;
  - etiquetas con sugerencias de las ya usadas;
  - tipo: *Auto* (detecta enlaces), Texto, Código o Enlace.

  Se guarda con `Ctrl/⌘+Enter`, y la nota se crea con todo en una sola petición.
- **Arreglo del tipo de nota**: la API devuelve el tipo como `text` / `codeSnippet` / `bookmark`, de modo que código y enlaces vuelven a verse como tales.
- **Tarjetas de nota**: icono por tipo, fecha relativa ("hace 2 h") y vista previa de enlaces más cuidada (dominio, imagen y descripción).
- **Detalle de nota**:
  - fechas de creación y edición visibles;
  - edición del título, contenido y etiquetas en el mismo formulario;
  - botón de copiar en todos los tipos.
- **Configuración en dos columnas** a partir de 1200 px.
- **Login y registro** con logo, texto de bienvenida y enlace "¿Olvidaste tu contraseña?". El enlace se muestra solo si existe la ruta, que añade `password-recovery`.
- **Atajo `n`** para abrir el compositor desde cualquier pantalla.
- **Tipografía**: *Plus Jakarta Sans* para la interfaz y *JetBrains Mono* para el código, autoalojadas (sin Google Fonts) para que la PWA funcione offline.
- **Arreglo del error `NG0100`** de la animación de rutas en desarrollo.

## Capabilities

### New Capabilities
<!-- Ninguna. -->

### Modified Capabilities
- `knowledge-vault`: capturar una nota admite título, etiquetas y tipo inferido en la misma operación.
- `web-experience`: identidad de la app instalada (nombre e iconos), resúmenes de nota con tipo y antigüedad, Configuración aprovechando el ancho disponible y atajo de teclado para crear una nota.

## Impact

- **Synap-Backend**:
  - `CreateNoteCommand` acepta `Tags` y un `Type` opcional, que se infiere con `NoteTypeInference` cuando falta.
  - Las etiquetas se crean o reutilizan en la misma transacción.
  - `NoteType` fija sus nombres JSON en camelCase, como `AssistantAnswerStatus`.
- **Synap-Frontend**:
  - Nuevo `NoteComposerComponent`, más `note-card`, `note-detail`, `notes-list`, `settings.page`, `login`/`register`, `app-shell` (atajo y animación), `styles.scss` e `index.html`.
  - Recursos nuevos: `public/favicon.svg`, iconos y `manifest.webmanifest`.
- **Dependencias nuevas (npm)**: `@fontsource-variable/plus-jakarta-sans` y `@fontsource-variable/jetbrains-mono`.
- **Compatibilidad**: el Atajo de iOS no cambia, porque la captura rápida acepta el tipo sin distinguir mayúsculas. Los clientes que leyeran `type` en PascalCase pasan a recibir camelCase; el único cliente es el propio front, que ya lo esperaba así.
