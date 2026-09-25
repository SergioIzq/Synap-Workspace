# Design

## Context

- **Iconos:** `public/` contiene `favicon.ico` e `icons/icon-*.png`, todos los iconos por defecto de Angular. El manifest se llama `synap-frontend` y no tiene colores. El logo existe solo como SVG inline en `app-shell` (líneas blancas sobre fondo transparente).
- **Captura de notas:** `notes-list.page.ts` tiene un input que llama a `NotesStore.create({ type: 'text', title: null, content })`. Las etiquetas se añaden después, una a una, en el detalle (`POST /api/notes/{id}/tags`). `CreateNoteCommand(Type, Title, Content)` no acepta etiquetas. `NoteTypeInference.Infer` (URL → Bookmark, resto → Text) solo lo usa la captura rápida.
- **Tipo de nota:** la API serializa `NoteType` en PascalCase porque el `UseResultHandler` del kernel ignora el conversor camelCase de `Program.cs` (el mismo problema que ya resolvimos con `AssistantAnswerStatus` mediante `[JsonStringEnumMemberName]`). El front compara con `'codeSnippet'` y `'bookmark'`.
- **Configuración:** `:host { max-width: 760px }` y `.sections` en columna.
- **Animación de rutas:** `app-shell` incrementa `routeState` dentro de `(activate)` del `router-outlet`, durante la detección de cambios, y provoca `NG0100` en desarrollo.
- **Tipografía:** la del sistema, vía `--p-font-family`.

## Goals / Non-Goals

**Goals:**
- Capturar una nota completa (título, etiquetas y tipo) sin salir de la lista.
- Una identidad coherente en la pestaña, el móvil y la instalación de la PWA, en claro y oscuro.

**Non-Goals:**
- Editor Markdown con vista previa en vivo.
- Reordenar o renombrar etiquetas.
- Rediseñar la paleta de colores (se mantienen los tokens `--synap-*`).

## Decisions

### 1. Iconos generados desde un único SVG maestro
- `public/favicon.svg`: el logo del sidebar sobre un cuadrado redondeado (rx 22 %) con el gradiente `#1e1b4b → #4f46e5`. Al llevar fondo propio se ve igual en pestañas claras y oscuras.
- Los PNG (72, 96, 128, 144, 152, 192, 384, 512 y `apple-touch-icon` 180) se generan renderizando ese SVG con Chrome headless, con un script en `scripts/generate-icons.mjs` que se versiona para regenerarlos. Las variantes `maskable` usan un 80 % de zona segura con el fondo a sangre, y `any` usa el cuadrado redondeado.
- `favicon.ico` se sustituye por un PNG de 32 px referenciado como `icon`, que todos los navegadores actuales aceptan. Se mantiene `favicon.ico` con el nuevo diseño en 32 px para peticiones heredadas a `/favicon.ico`.
- Manifest: `name`/`short_name` "Synap", `theme_color` `#1e1b4b`, `background_color` `#f8fafc`, e iconos separados en `purpose: any` y `purpose: maskable`, porque la combinación `"maskable any"` recorta mal en Android.

*Alternativa descartada: añadir ImageMagick o `sharp` al proyecto.* Chrome headless ya está disponible y se usó para las pruebas visuales; el script no añade dependencias al build.

### 2. Crear nota con etiquetas en una sola transacción
- `CreateNoteCommand(NoteType? Type, string? Title, string Content, IReadOnlyList<string>? Tags)`. Si `Type` es null se usa `NoteTypeInference.Infer`.
- Las etiquetas se normalizan (trim y sin duplicados insensibles a mayúsculas). Si alguna está vacía, `Error.Validation` y no se crea nada. Máximo 10 por nota.
- La lógica de "obtener o crear la etiqueta del usuario" que hoy vive en `AddTagCommandHandler` se extrae a un helper compartido (`TagAssignment`), para que los dos casos de uso se comporten igual.
- Todo pasa por el mismo `UnitOfWork.SaveChangesAsync`, así que es atómico.

*Alternativa descartada: crear la nota y luego una petición por etiqueta desde el front.* No es atómico (se quedarían notas a medias si falla una etiqueta) y genera N+1 peticiones y N+1 toasts.

### 3. Tipo de nota en camelCase en la API
Un `NoteTypeJsonConverter` (escribe camelCase y lee sin distinguir mayúsculas) aplicado con `[property: JsonConverter]` en las formas de respuesta (`NoteSearchResult.Type` y `RelatedNote.Type`). Un conversor a nivel de propiedad tiene prioridad sobre el conversor genérico del kernel.

*Descartado al implementar: `[JsonStringEnumMemberName]` en el enum, como en `AssistantAnswerStatus`.* Hace que la **entrada** solo acepte el nombre exacto (`codeSnippet`): `"CodeSnippet"` pasaba a dar 400 y habría roto el Atajo de iOS o cualquier cliente que envíe el tipo en PascalCase. Lo detectó un test de la captura rápida.

**Etiquetas:** la búsqueda de etiqueta existente pasa a ignorar mayúsculas y conserva la grafía original, para que `#Docker` reutilice `docker` en vez de crear una casi duplicada. Aplica también a añadir una etiqueta desde el detalle.

### 4. `NoteComposerComponent`
- Estado replegado: el input actual. Al enfocarlo se despliega con título, `textarea` autoajustable, `p-autocomplete` múltiple de etiquetas (sugerencias de `NotesStore.allTags()`, admite etiquetas nuevas) y `p-selectbutton` de tipo (Auto, Texto, Código, Enlace).
- Guarda con `Ctrl/⌘+Enter` o con el botón. `Esc` cancela y pliega si está vacío; si hay texto, pide confirmación para descartar.
- Tras guardar se vacía, se pliega y la lista se refresca (ya lo hace `NotesStore.create`).
- El componente vive en la lista, y el atajo `n` navega a `/app/notes?compose=1`, que lo abre y le da el foco.

### 5. Tarjetas y detalle
- **Tarjeta:**
  - icono por tipo (`pi-align-left`, `pi-code`, `pi-link`);
  - fecha relativa con `Intl.RelativeTimeFormat('es')` (pipe `relativeTime`) y `title` con la fecha completa;
  - en enlaces: dominio (`new URL(content).hostname`), título, descripción y miniatura.
- **Detalle:**
  - cabecera con título, tipo y "Creada … · Editada …";
  - el formulario de edición incluye las etiquetas (mismo `p-autocomplete`), guardadas con las llamadas existentes de actualizar y añadir etiqueta;
  - botón de copiar en todos los tipos (texto: contenido en bruto).
- Quitar etiquetas queda fuera: no existe endpoint y no se pidió.

### 6. Configuración en rejilla
`display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); align-items: start` a partir de 1200 px, con `max-width: 1200px`. Columna izquierda: Asistente IA y Atajo de iOS; columna derecha: Apariencia y Cuenta. Por debajo, una columna como ahora.

### 7. Login y registro
Logo (el mismo SVG) y "Synap" sobre la tarjeta, con un subtítulo ("Tu segundo cerebro: captura, busca y pregunta a tus notas"). Enlace "¿Olvidaste tu contraseña?" bajo el campo de contraseña, que solo se muestra si el router tiene la ruta `forgot-password` (la añade `password-recovery`). Así los dos cambios se pueden aplicar en cualquier orden.

### 8. Tipografía autoalojada
`@fontsource-variable/plus-jakarta-sans` y `@fontsource-variable/jetbrains-mono` importados en `styles.scss`, con `--p-font-family` apuntando a Plus Jakarta Sans y el código (`pre`, `code`, `.note-code`) a JetBrains Mono. El service worker cachea los `woff2` como el resto de recursos.

*Alternativa descartada: Google Fonts.* Filtra la IP de cada visita a Google y no funciona offline en la PWA.

### 9. Arreglo de `NG0100`
En lugar de mutar `routeState` en `(activate)`, el estado de la animación sale de `outlet.activatedRoute.snapshot.url` / `outlet.activatedRouteData`, leído en la plantilla vía `@routeAnimation]="prepareRoute(outlet)"`. Es el patrón documentado y no cambia valores durante la detección de cambios.

## Risks / Trade-offs

- **[Presupuesto de estilos por componente (4 kB aviso)]** → Mitigación: el compositor y la rejilla usan clases globales de `styles.scss` donde se repiten; se revisa con `ng build`.
- **[Peso de las fuentes (~50–80 kB en woff2)]** → Mitigación: solo subconjuntos latin y latin-ext y una única fuente variable por familia.
- **[Los navegadores cachean el favicon]** → Tras desplegar puede tardar en verse el nuevo; es cosmético y se documenta.
- **[`p-autocomplete` con creación libre en móvil]** → Mitigación: la etiqueta se confirma con Enter o coma y se prueba a 360 px.
