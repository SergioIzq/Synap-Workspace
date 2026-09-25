# Proposal

## Why

El frontend actual es funcional pero visualmente plano — carece de la identidad y el pulido esperado en una herramienta de productividad premium. Con las funcionalidades core estables, un lavado de cara integral mejorará la percepción de calidad, la confianza del usuario y la experiencia diaria.

## What Changes

- **Tema PrimeNG personalizado**: paleta indigo/violeta oscura aplicada vía tokens de `@primeuix/themes/aura`, afectando colores primarios, superficies y radios en toda la app.
- **Sidebar rediseñada**: fondo con gradiente oscuro (indigo profundo → violeta), marca "Synap" con estilo mejorado, nav links con estado activo prominente y micro-animación en hover.
- **Transiciones de ruta**: animación crossfade + slide entre páginas usando Angular Animations (`@routeAnimation` en `app-shell`).
- **Animaciones de lista en notas**: entrada escalonada (stagger) de las note cards al cargar la lista; hover con `translateY` + sombra elevada.
- **Burbujas de chat en el asistente**: mensajes con apariencia de burbuja diferenciada (usuario vs. Synap), animación de entrada slide-up por mensaje, indicador de "Pensando…" con tres puntos pulsantes en lugar de texto plano.
- **Auth layout con fondo decorativo**: gradiente o patrón sutil detrás del card de login/register; animación de entrada del card.
- **Skeleton loaders**: reemplazar los estados de carga de texto plano por componentes `p-skeleton` que imitan la forma de las cards.
- **Mejoras menores de polish**: transición en `.nav-link` hover, `transition` en note-card, mejor jerarquía tipográfica en encabezados de página.

## Capabilities

### New Capabilities
<!-- Ninguna — cambio puramente visual/animación, sin cambios de comportamiento. -->

### Modified Capabilities
<!-- Ninguna — los requisitos funcionales de identity, knowledge-vault y ai-assistant no cambian. -->

## Impact

- **Solo frontend**: todos los cambios son en `Synap-Frontend/src/`.
- **Archivos principales**: `styles.scss`, `app.config.ts`, `app-shell.component.ts`, `auth-layout.component.ts`, `login.page.ts`, `register.page.ts`, `notes-list.page.ts`, `note-card.component.ts`, `assistant.page.ts`.
- **Sin cambios de API**: no se tocan servicios, stores ni contratos de backend.
- **Dependencias**: `@angular/animations` y `@primeuix/themes` ya instalados; no se añaden paquetes nuevos.
- **Sin breaking changes**: puro cambio de presentación.
