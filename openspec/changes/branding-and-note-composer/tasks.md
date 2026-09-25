# Tasks

## 1. Backend

- [ ] 1.1 Fijar los nombres JSON de `NoteType` (`text`, `codeSnippet`, `bookmark`) con `[JsonStringEnumMemberName]`. Verificar con un test de serialización y con `curl /api/notes/search`, que devuelve `"type":"text"`.
- [ ] 1.2 Extraer "obtener o crear etiqueta del usuario" a `TagAssignment` y usarlo en `AddTagCommandHandler`. Verificar que los tests existentes de etiquetas siguen pasando.
- [ ] 1.3 Ampliar `CreateNoteCommand` con `Type` opcional (inferido con `NoteTypeInference`) y `Tags` (normalizadas, máximo 10, rechazo atómico si alguna está vacía). Verificar con tests de integración: nota con etiquetas nuevas y existentes en una petición, URL sin tipo → bookmark, y etiqueta vacía → 400 sin nota ni etiquetas creadas.

## 2. Identidad visual

- [ ] 2.1 Crear `public/favicon.svg` (logo sobre gradiente índigo) y `scripts/generate-icons.mjs`, que renderiza con Chrome headless los PNG `any` y `maskable`, `apple-touch-icon` de 180 y `favicon.ico`/PNG de 32. Verificar abriendo los PNG generados y que no quede ningún icono de Angular (`git grep -l` o una revisión visual).
- [ ] 2.2 Actualizar `manifest.webmanifest` (nombre, colores, iconos `any`/`maskable` separados) e `index.html` (favicon SVG y PNG, apple-touch-icon y `theme-color`). Verificar con Chrome headless que la pestaña muestra el logo y que Lighthouse PWA no marca iconos inválidos.

## 3. Compositor de notas

- [ ] 3.1 Actualizar `NoteService.create` y los modelos (`type` opcional y `tags`). Verificar con un test del servicio.
- [ ] 3.2 Crear `NoteComposerComponent` (replegado/desplegado, título, contenido, etiquetas con sugerencias y creación libre, tipo con Auto, `Ctrl/⌘+Enter`, `Esc`, confirmación para descartar) y sustituir con él la captura rápida en `notes-list`. Verificar a mano a 1280 y 360 px: crear una nota con título y dos etiquetas (una existente) y que aparece con ellas sin entrar al detalle.
- [ ] 3.3 Añadir el atajo global `n` en `app-shell` (salvo con el foco en un campo), que navega a `/app/notes?compose=1` y abre y enfoca el compositor. Verificar a mano desde el Asistente y dentro de un input.

## 4. Lista y detalle

- [ ] 4.1 Crear la pipe `relativeTime` (`Intl.RelativeTimeFormat('es')`) con tests (segundos, minutos, horas, días, fechas sin zona tratadas como UTC).
- [ ] 4.2 Rediseñar `note-card` (icono por tipo, fecha relativa con título completo y enlaces con dominio, título, descripción y miniatura). Verificar a mano con una nota de cada tipo en claro y oscuro.
- [ ] 4.3 Rediseñar `note-detail` (cabecera con tipo y fechas, edición de título, contenido y etiquetas en un formulario, y copiar en todos los tipos). Verificar a mano editando título y etiquetas a la vez.

## 5. Configuración, auth y pulido

- [ ] 5.1 Pasar Configuración a rejilla de 2 columnas a partir de 1200 px (IA e iOS a la izquierda, Apariencia y Cuenta a la derecha). Verificar con Chrome headless a 1280 px (dos columnas) y 360 px (una), sin scroll horizontal.
- [ ] 5.2 Rediseñar login y registro (logo, título, subtítulo y enlace "¿Olvidaste tu contraseña?" condicionado a la ruta). Verificar a mano en claro, oscuro y 360 px.
- [ ] 5.3 Añadir las fuentes autoalojadas `@fontsource-variable` (Plus Jakarta Sans y JetBrains Mono) y aplicarlas a la interfaz y al código. Verificar con `getComputedStyle` en Chrome headless y con `ng build` sin avisos de presupuesto nuevos.
- [ ] 5.4 Arreglar `NG0100` con `prepareRoute(outlet)`. Verificar que el log de `ng serve` no muestra el error al navegar entre páginas.

## 6. Verificación

- [ ] 6.1 Hacer una pasada completa en escritorio y 360 px, claro y oscuro: login, crear nota con el compositor (con título, etiquetas y tipo), lista con los tres tipos, detalle y edición, Configuración y atajo `n`. Verificar además que `dotnet test` y los tests del front pasan y que `ng build` no da avisos.
