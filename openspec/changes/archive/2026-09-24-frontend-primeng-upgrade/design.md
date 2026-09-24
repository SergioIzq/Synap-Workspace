# Design

## Context

See `proposal.md — Why` for motivation. Current state relevant to the approach:

- Angular 21.2 standalone app with signals-based stores, lazy-loaded feature modules, HTTP interceptors, and a service worker. The business logic layer (services, stores, guards, interceptors) is solid and is not touched by this change.
- No UI component library or CSS framework is installed. All templates use native HTML elements.
- `MarkdownService` exists and returns sanitized HTML strings (using `marked` + `highlight.js`) but is only used in `note-detail.page`. The assistant page renders answers as plain text despite the API returning Markdown.
- PrimeNG 22 requires Angular 22. The project is on Angular 21.2, so a major version upgrade is a prerequisite.

## Goals / Non-Goals

**Goals:**
- Angular 21 → 22 upgrade as the unlock step for PrimeNG 22
- PrimeNG 22 + Aura preset installed and globally configured
- Authenticated shell with a persistent sidebar navigation (not an overlay)
- All feature page templates replaced with PrimeNG components
- Markdown rendering in the assistant page (and note detail) using the existing service

**Non-Goals:**
- Dark mode toggle (Aura ships dark-mode-ready tokens; wiring a toggle is a follow-up)
- Responsive/mobile breakpoints beyond basic usability
- Editor for note content (the notes are plain-text captures; rich editing is a separate change)
- Any change to backend APIs, services, stores, guards, or interceptors

## Decisions

### D1 — Angular upgrade via `ng update`
Use `ng update @angular/core@22 @angular/cli@22` to migrate automatically. Angular's update schematics handle most breaking changes. After the upgrade, verify compilation; no manual migration work is expected for this codebase given its limited use of deprecated APIs.

*Alternative considered*: Pin PrimeNG to v21 to avoid the Angular upgrade. Rejected — user explicitly requested latest stable of both; staying on Angular 21 creates immediate version debt.

### D2 — PrimeNG setup: `providePrimeNG` in `app.config.ts`

```typescript
// app.config.ts
import { providePrimeNG } from 'primeng/config';
import Aura from 'primeng/themes/aura'; // path confirmed at install time

providers: [
  ...
  providePrimeNG({ theme: { preset: Aura } }),
]
```

The Aura preset source path (`primeng/themes/aura` vs `@primeng/themes/aura`) must be confirmed after `npm install` — `@primeng/themes` did not release a v22, suggesting presets were bundled into the main `primeng` package for v22.

*Alternative*: CSS theme via `angular.json` styles array (legacy approach). Rejected — PrimeNG 19+ uses the styled-components / design-token model; the CSS-only approach loses runtime theming capabilities.

### D3 — Layout: dedicated `AppShellComponent` with a shell route

A new authenticated shell route wraps `notes` and `assistant`:

```
/                    → redirect to /notes
/auth/**             → AuthLayout (full-screen, no sidebar)
/app                 → AppShellComponent (sidebar + router-outlet)
  /app/notes/**      → NotesFeature
  /app/assistant/**  → AssistantFeature
```

The shell component renders a fixed-width sidebar (using PrimeNG `p-menu` or plain styled links) plus a `<router-outlet>` for the content area. This is a static layout, not a `p-sidebar` overlay — overlays are for mobile drawers, not a persistent desktop navigation panel.

The `authGuard` remains on the `/app` route so unauthenticated users are redirected to `/auth/login`.

*Alternative*: Keep flat routes and add the sidebar inside each feature page. Rejected — duplicates layout code across features and makes future layout changes fragile.

### D4 — Markdown rendering: `[innerHTML]` with `MarkdownService`

The existing `MarkdownService.render(text)` returns an HTML string (already processed through `marked` + `highlight.js`). Binding it via `[innerHTML]` in templates is safe because:
- Content comes from Synap's own AI service (trusted internal source)
- `marked` + `highlight.js` do not introduce XSS vectors on their own for typical note content

`DomSanitizer.bypassSecurityTrustHtml()` is used to suppress Angular's sanitization warning for this binding, with a comment explaining the trust reasoning.

*Alternative*: Add DOMPurify for belt-and-suspenders sanitization. Reasonable future hardening; skipped now to avoid scope creep. Revisit if the assistant ever processes user-supplied URLs or arbitrary HTML.

### D5 — PrimeNG components per screen

| Screen | Key PrimeNG components |
|--------|----------------------|
| Login / Register | `p-card`, `p-inputtext`, `p-password`, `p-button`, `p-message` |
| App Shell | `p-menu` (sidebar nav), `p-toolbar` (optional topbar) |
| Notes list | `p-inputgroup`, `p-inputtext`, `p-button`, `p-select`, `p-card`, `p-tag` |
| Note detail | `p-card`, `p-button` (back), markdown `[innerHTML]` |
| Assistant | `p-card` (per turn), `p-inputgroup`, `p-button`, markdown `[innerHTML]` |

## Risks / Trade-offs

- **PrimeNG 22 Aura import path unknown** — `@primeng/themes` stopped at v21, implying the preset is now in `primeng` itself. If the import path differs, the fix is a one-liner once we inspect the installed package. → Mitigation: resolve as first step of implementation (Task 1).

- **Angular 22 breaking changes** — Angular major upgrades occasionally require template or DI changes the schematics miss. → Mitigation: run `ng build` immediately after upgrade; fix any compilation errors before touching UI code.

- **Service worker cache invalidation** — Changing `styles.scss` and adding new JS bundles will cause the service worker to update on next visit. This is expected and harmless; no mitigation needed.

- **`highlight.js` already bundled** — It's in `dependencies`, so code highlighting in the assistant is zero additional cost. If the `MarkdownService` doesn't already register the languages needed (e.g., TypeScript, Python), they can be added in the service without touching this change's scope.

## Open Questions

- **Exact Aura preset import path for PrimeNG 22**: Verify by running `ls node_modules/primeng/themes/` after install. If the path differs from `primeng/themes/aura`, update `app.config.ts` accordingly. No design-level impact — just an import string.
