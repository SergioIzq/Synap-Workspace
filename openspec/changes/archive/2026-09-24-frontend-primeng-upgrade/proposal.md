# Proposal

## Why

The MVP frontend is functional but ships raw HTML with no visual design system — inputs, buttons, and layouts are browser-default styled, making the app feel unfinished and hard to extend. Adding PrimeNG with Aura gives Synap a polished, consistent UI from day one and accelerates all future feature development.

## What Changes

- **Upgrade Angular 21 → 22** (required by PrimeNG 22; handled via `ng update`)
- **Install PrimeNG 22.1.1** + `@angular/cdk@22`, `primeicons@8`, with Aura preset and dark-mode support
- **New `AppShellComponent`** — sidebar layout (`p-drawer` / static sidebar) with navigation links (Notes, Assistant) and logout, wrapping all authenticated routes via a dedicated shell route
- **Auth pages redesigned** — login and register use `p-card`, `p-inputtext`, `p-password`, `p-button`; rendered outside the shell (full-screen centered layout)
- **Notes list redesigned** — quick-capture uses `p-inputgroup`; search uses `p-inputtext` + `p-select`; each note is a `p-card`; hashtags rendered as `p-tag`
- **Note detail redesigned** — content displayed inside a `p-card` with full Markdown rendering via the existing `markdown.service`
- **Assistant page redesigned** — chat turns use `p-card` per message; assistant answers rendered as Markdown HTML (with `highlight.js` for code blocks); input uses `p-inputgroup` + `p-button`
- **Global theming** — PrimeNG Aura preset configured in `app.config.ts` via `providePrimeNG`; `styles.scss` imports PrimeNG base styles and primeicons

## Capabilities

### New Capabilities
<!-- None — this change adds no new system behaviors. All user-facing features
     (auth, notes, assistant) already exist. This is a pure UI layer upgrade. -->

### Modified Capabilities
<!-- No existing spec-level requirements change. The underlying API behavior
     for identity, knowledge-vault, and ai-assistant is untouched. -->

## Impact

- **`Synap-Frontend/package.json`** — Angular upgraded to 22.2, `primeng`, `@angular/cdk`, `primeicons` added
- **`Synap-Frontend/src/app/app.config.ts`** — `providePrimeNG` added with Aura preset
- **`Synap-Frontend/src/styles.scss`** — PrimeNG base CSS and primeicons imported
- **All feature page templates** — replaced with PrimeNG components; existing services, stores, guards, and interceptors unchanged
- **New `core/layout/app-shell.component.ts`** — authenticated shell with sidebar navigation
- **No backend changes** — `Synap-Backend` and `ai-service` are untouched
