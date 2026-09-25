# Design

## Context

Ver `proposal.md — Why` para la motivación.

Stack actual relevante:
- Angular 22 standalone, signals, `ChangeDetectionStrategy.Eager`
- PrimeNG 22 + Aura theme vía `@primeuix/themes`; `providePrimeNG` en `app.config.ts`
- `@angular/animations` + `provideAnimationsAsync()` ya configurados, pero ningún componente los usa todavía
- Un solo fichero global de estilos (`styles.scss`) más estilos inline en cada componente
- Sin dark mode activo (`darkModeSelector: false` en `app.config.ts`)

## Goals / Non-Goals

**Goals:**
- Identidad visual "productividad premium" (indigo profundo + violeta, inspirado en Linear/GitHub)
- Animaciones funcionalmente correctas usando el motor que ya está instalado
- Cero dependencias nuevas
- Todos los cambios son aditivos o de reemplazo en la capa de presentación

**Non-Goals:**
- Dark mode (queda como open question)
- Responsive/mobile layout
- Cambios en lógica de negocio, stores o servicios
- Rediseño de la página de detalle de nota (fuera de scope de esta iteración)

## Decisions

### D1 — Customización del tema vía `definePreset` de `@primeuix/themes`

**Decisión**: extender Aura con `definePreset` en `app.config.ts` en lugar de sobreescribir variables CSS manualmente.

**Rationale**: `definePreset` genera todos los tokens derivados automáticamente (hover, focus, disabled states). Sobreescribir CSS a mano sería frágil y requeriría mantener cientos de variables.

**Alternativas descartadas**:
- CSS custom properties en `styles.scss`: funciona para casos simples pero rompe los tokens semánticos de PrimeNG.
- Cambiar de Aura a otro preset (Lara, Material): más disruptivo, Aura ya está integrado.

**Paleta objetivo**:
```
primary:    { 500: '#6366f1', 600: '#4f46e5', 700: '#4338ca' }  // indigo
surface:    Aura default (no cambiar — sidebar usará su propio bg)
```

### D2 — Sidebar con gradiente oscuro via CSS, no mediante tema PrimeNG

**Decisión**: la sidebar usa `background: linear-gradient(180deg, #1e1b4b 0%, #312e81 100%)` directamente en su componente, no a través de tokens.

**Rationale**: el sidebar es el único elemento con fondo oscuro en modo claro; meterlo en el tema contaminaría el sistema de tokens para toda la app.

**Alternativas descartadas**:
- Surface dark tokens: afectarían cards y otros componentes, no solo el sidebar.

### D3 — Animaciones de ruta con `@angular/animations` en `AppShellComponent`

**Decisión**: añadir un trigger `routeAnimation` en `app-shell.component.ts` que detecta el outlet activo y aplica una transición `opacity + translateX`.

**Approach**:
```
router-outlet + * (la vista hija)
  :enter  → opacity:0, translateX(12px) → opacity:1, translateX(0)   [200ms ease-out]
  :leave  → opacity:1, translateX(0)    → opacity:0, translateX(-8px) [150ms ease-in]
```
El `RouterOutlet` debe exponerse con `(activate)` para poder leer el estado de animación.

**Alternativas descartadas**:
- Animaciones en cada página individual: requiere duplicar el trigger en cada componente y sincronizar timing.
- `AnimationBuilder` imperativo: más potente pero excesivo para transiciones simples.

### D4 — Stagger de note cards con `query` + `stagger` de Angular Animations

**Decisión**: en `notes-list.page.ts`, un trigger en el contenedor padre usa `query(':enter', stagger(60ms, animate(...)))` cuando el array de notas cambia.

**Approach**: el trigger se dispara con `[@listAnimation]="notesStore.notes().length"` para que Angular detecte los cambios de lista.

**Alternativas descartadas**:
- CSS `animation-delay` calculado con `ngStyle`: más simple pero no limpia el estado al salir.
- Librería externa (GSAP, etc.): innecesario, `@angular/animations` lo cubre perfectamente.

### D5 — Typing indicator en el asistente con CSS puro (sin Angular Animations)

**Decisión**: el indicador de "Pensando…" se implementa como un componente CSS con 3 puntos y una animación `@keyframes` de `scale + opacity`, sin usar el motor de Angular Animations.

**Rationale**: es un elemento auto-contenido sin estado de entrada/salida que Angular necesite coordinar. CSS puro es más simple y no depende del `ChangeDetectionStrategy`.

### D6 — Skeleton loaders con `p-skeleton` de PrimeNG

**Decisión**: reemplazar el `<p class="empty-state">Cargando…</p>` en `notes-list.page.ts` por una lista de 3 `p-skeleton` con la forma de una card.

**Rationale**: `p-skeleton` ya está en PrimeNG, cero código extra, y da continuidad visual con las cards reales.

## Risks / Trade-offs

| Riesgo | Mitigación |
|--------|-----------|
| `query(':enter')` en la lista de notas no detecta cambios si Angular no re-renderiza los elementos hijos | Probar con un cambio de clave en el `@for` track; fallback: animación en el card individual con `:enter` |
| El gradiente oscuro del sidebar puede chocar con el texto blanco en resoluciones con bajo contraste | Verificar ratio WCAG AA mínimo 4.5:1 antes de cerrar |
| `definePreset` con versión PrimeNG 22 puede tener una API ligeramente diferente a la docs de v4 | Leer el tipo `PrimeNGConfig` en `node_modules/primeng` antes de implementar |
| Animaciones de ruta pueden causar un flash si el componente saliente tiene `overflow: hidden` | Envolver el outlet en un contenedor `position: relative` |

### D7 — Icono de marca: nodo de grafo SVG inline a 28px

**Decisión**: icono SVG geométrico inline en el componente sidebar a 28px junto al wordmark "Synap".

**Geometría**: viewBox 32×32. Centro (16,16) radio 5. Tres satélites a −90°/+30°/+150° a radio orbital 10, radio 2.5 cada uno. Aristas de 1.75px con `stroke-linecap="round"`.

**SVG coloreado** (fondo claro / uso futuro):
```xml
<svg viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <line x1="16" y1="16" x2="16"    y2="6"  stroke="#a5b4fc" stroke-width="1.75" stroke-linecap="round"/>
  <line x1="16" y1="16" x2="24.66" y2="21" stroke="#a5b4fc" stroke-width="1.75" stroke-linecap="round"/>
  <line x1="16" y1="16" x2="7.34"  y2="21" stroke="#a5b4fc" stroke-width="1.75" stroke-linecap="round"/>
  <circle cx="16"    cy="6"  r="2.5" fill="#818cf8"/>
  <circle cx="24.66" cy="21" r="2.5" fill="#818cf8"/>
  <circle cx="7.34"  cy="21" r="2.5" fill="#818cf8"/>
  <circle cx="16"    cy="16" r="5"   fill="#6366f1"/>
</svg>
```

**SVG blanco** (sidebar oscuro — versión a usar):
```xml
<svg viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <line x1="16" y1="16" x2="16"    y2="6"  stroke="rgba(255,255,255,0.38)" stroke-width="1.75" stroke-linecap="round"/>
  <line x1="16" y1="16" x2="24.66" y2="21" stroke="rgba(255,255,255,0.38)" stroke-width="1.75" stroke-linecap="round"/>
  <line x1="16" y1="16" x2="7.34"  y2="21" stroke="rgba(255,255,255,0.38)" stroke-width="1.75" stroke-linecap="round"/>
  <circle cx="16"    cy="6"  r="2.5" fill="rgba(255,255,255,0.65)"/>
  <circle cx="24.66" cy="21" r="2.5" fill="rgba(255,255,255,0.65)"/>
  <circle cx="7.34"  cy="21" r="2.5" fill="rgba(255,255,255,0.65)"/>
  <circle cx="16"    cy="16" r="5"   fill="white"/>
</svg>
```

**Lockup**: `<svg width="28" height="28">` + span `"Synap"` en `font-weight: 700`, `letter-spacing: -0.025em`, color `#e0e7ff`.

## Open Questions

- ¿Dark mode en esta misma iteración o deferido? → Deferido (no está en scope).
