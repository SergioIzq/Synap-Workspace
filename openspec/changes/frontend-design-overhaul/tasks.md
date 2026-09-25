# Tasks

## 1. Tema PrimeNG — paleta indigo

- [x] 1.1 En `app.config.ts`, reemplazar `providePrimeNG({ theme: { preset: Aura } })` por un `definePreset(Aura, { ... })` con `primary.500: #6366f1`, `primary.600: #4f46e5`, `primary.700: #4338ca`; verificar que los botones y links del app muestren el color indigo en el navegador.
- [x] 1.2 En `styles.scss`, añadir las variables de tipografía de página (`--page-heading-size: 1.15rem; font-weight: 700; letter-spacing: -0.02em`) y aplicarlas a todos los `h2` de páginas de features; verificar que los encabezados "Tus notas" y "Pregunta a Synap" adopten el estilo.

## 2. Sidebar — rediseño visual

- [x] 2.1 En `app-shell.component.ts`, cambiar el `background` de `.sidebar` a `linear-gradient(160deg, #1e1b4b 0%, #312e81 100%)` y el `border-right` a `none`; verificar que el sidebar muestre el gradiente oscuro.
- [x] 2.2 Reemplazar el `<div class="sidebar-brand">Synap</div>` por el lockup SVG + wordmark definido en `design.md — D7` (icono blanco 28px + span "Synap" en `color: #e0e7ff`, `font-weight: 700`, `letter-spacing: -0.025em`); verificar que el brand se muestre correctamente.
- [x] 2.3 Actualizar los estilos de `.nav-link` para fondo oscuro: `color: rgba(255,255,255,0.7)`, hover `background: rgba(255,255,255,0.08) / color: white`, estado `active` con `background: rgba(255,255,255,0.12) / color: white / font-weight: 600`; verificar que la navegación sea legible y que el estado activo resalte.
- [x] 2.4 Añadir `box-shadow: 4px 0 24px rgba(0,0,0,0.25)` al sidebar para separarlo visualmente del contenido; verificar que no haya artefactos visuales en el borde.

## 3. Animaciones de ruta

- [x] 3.1 Crear la función `routeAnimations` en `src/app/core/animations/route.animations.ts` con un trigger `routeAnimation` que aplique `opacity 0→1 + translateX(10px→0)` en `:enter` (200ms ease-out) y `opacity 1→0 + translateX(0→−8px)` en `:leave` (140ms ease-in).
- [x] 3.2 En `app-shell.component.ts`, importar `BrowserAnimationsModule` / `provideAnimationsAsync` (ya configurado), añadir el trigger al host de `.content`, exponer el `RouterOutlet` con `(activate)="onActivate($event)"` y vincular `[@routeAnimation]` al outlet; verificar que al navegar entre Notas y Asistente se vea la transición.

## 4. Note cards — entrada escalonada y hover

- [x] 4.1 En `notes-list.page.ts`, importar `trigger, transition, query, stagger, animate, style` de `@angular/animations`; añadir un trigger `listAnimation` en el contenedor `@for` que use `query(':enter', stagger(55ms, [style({opacity:0, transform:'translateY(6px)'}), animate('220ms ease-out', style({opacity:1, transform:'none'}))]), {optional:true})`; vincular `[@listAnimation]="notesStore.notes().length"` al contenedor; verificar que las cards entren escalonadas al cargar.
- [x] 4.2 En `note-card.component.ts`, añadir `transition: transform 0.18s ease, box-shadow 0.18s ease` al `a` wrapper y en `a:hover ::ng-deep .p-card` añadir `transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0,0,0,0.10)`; verificar que las cards se eleven suavemente al hacer hover.

## 5. Asistente — burbujas y typing indicator

- [x] 5.1 Rediseñar el chat en `assistant.page.ts`: reemplazar los `p-card` por un layout de burbujas; mensajes del usuario (`.msg-user`) alineados a la derecha con `background: #6366f1; color: white; border-radius: 16px 16px 4px 16px`; respuestas de Synap (`.msg-synap`) alineadas a la izquierda con `background: var(--p-surface-card); border-radius: 16px 16px 16px 4px`; verificar que el chat tenga aspecto de mensajería.
- [x] 5.2 Reemplazar el `<p class="answer-pending">Pensando…</p>` por un componente inline de typing indicator: tres puntos (`<span>`) con `@keyframes dotPulse { 0%,80%,100%{transform:scale(0.6);opacity:0.4} 40%{transform:scale(1);opacity:1} }` en stagger de 160ms entre puntos; verificar que el indicador pulse mientras se espera la respuesta.
- [x] 5.3 Añadir animación de entrada a cada mensaje nuevo: `@keyframes msgIn { from{opacity:0;transform:translateY(8px)} to{opacity:1;transform:none} }` aplicada con `animation: msgIn 0.2s ease-out`; verificar que cada burbuja nueva aparezca animada.

## 6. Auth layout — fondo decorativo

- [x] 6.1 En `auth-layout.component.ts`, cambiar el `background` de `:host` a `linear-gradient(135deg, #eef2ff 0%, #e0e7ff 40%, #ede9fe 100%)`; verificar que el fondo del login/register muestre el gradiente suave.
- [x] 6.2 En `login.page.ts` y `register.page.ts`, añadir `animation: cardIn 0.3s cubic-bezier(0.16,1,0.3,1)` con `@keyframes cardIn { from{opacity:0;transform:translateY(16px) scale(0.98)} to{opacity:1;transform:none} }` al `:host`; verificar que el card entre animado al navegar a la ruta de auth.

## 7. Skeleton loaders

- [x] 7.1 En `notes-list.page.ts`, importar `SkeletonModule` de `primeng/skeleton`; reemplazar el bloque `@if (notesStore.loading()) { <p class="empty-state">Cargando…</p> }` por tres repeticiones de `<p-skeleton height="80px" styleClass="mb-3" borderRadius="8px" />`; verificar que al cargar notas se muestren los skeletons antes que las cards.

## 8. Polish final

- [x] 8.1 En `styles.scss`, añadir una transición global suave al `RouterOutlet` wrapper para evitar saltos de scroll: `scroll-behavior: smooth` en `.content`; verificar que el scroll no salte al cambiar de ruta.
- [x] 8.2 Revisar contraste WCAG AA del texto blanco sobre el gradiente del sidebar (`#e0e7ff` sobre `#1e1b4b` y `#312e81`); ajustar opacidad del texto de nav si el ratio es inferior a 4.5:1; documentar el ratio final aquí.
- [x] 8.3 Verificar que `prefers-reduced-motion` deshabilite todas las animaciones añadidas: añadir `@media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; } }` en `styles.scss`; verificar con DevTools que la preferencia se respeta.
