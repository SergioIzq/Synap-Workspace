# Tasks

## 1. Angular 22 Upgrade

- [x] 1.1 Run `ng update @angular/core@22 @angular/cli@22` inside `Synap-Frontend/` and verify `ng build` completes with no errors after the update schematics apply
- [x] 1.2 Update `@angular/service-worker` to 22 (`ng update @angular/service-worker@22` or manual bump) and verify `ng build --configuration production` succeeds (service worker re-generated without errors)

## 2. PrimeNG Installation & Global Configuration

- [x] 2.1 Install `primeng@22.1.1`, `@angular/cdk@^22`, and `primeicons@8` inside `Synap-Frontend/` and verify all peer dependency warnings are resolved (`npm ls primeng` shows no unmet peers)
- [x] 2.2 Inspect `node_modules/primeng/themes/` to confirm the Aura preset path (expected `primeng/themes/aura` or `@primeng/themes/aura`) and note the exact import for use in the next task
- [x] 2.3 Add `providePrimeNG({ theme: { preset: Aura } })` to `app.config.ts` using the import path confirmed in 2.2, and verify `ng build` compiles without type errors
- [x] 2.4 Add PrimeNG base CSS and primeicons to `styles.scss` (or `angular.json` styles array) and verify the dev server renders primeicon glyphs (e.g., check network tab for primeicons font file loading)

## 3. App Shell Layout

- [x] 3.1 Create `src/app/core/layout/app-shell.component.ts` with a two-column layout: fixed-width sidebar containing `p-menu` navigation (Notes, Assistant links) and a logout button, plus `<router-outlet>` for the content area; verify the component compiles
- [x] 3.2 Restructure `app.routes.ts`: move `notes` and `assistant` routes under a `/app` shell route guarded by `authGuard` that loads `AppShellComponent`; move `auth` routes to remain at root level without the shell; verify `ng build` compiles and the app loads in the browser at `/app/notes`
- [x] 3.3 Update `authGuard` redirect target if needed (returnUrl should redirect to `/app/notes` not `/notes`) and verify an unauthenticated visit to `/app/notes` redirects to `/auth/login?returnUrl=/app/notes`

## 4. Auth Pages

- [x] 4.1 Rewrite `login.page.ts` template: centered `p-card` wrapper, `p-inputtext` for email, `p-password` for password, `p-button` for submit, `p-message` for error display; verify login works end-to-end with a real backend call (correct credentials → redirect to `/app/notes`)
- [x] 4.2 Rewrite `register.page.ts` template with the same component palette; verify registration works end-to-end (new email → account created, redirect to login or `/app/notes`)
- [x] 4.3 Create a minimal `AuthLayoutComponent` (full-screen centered, no sidebar) and add it as the parent route for `auth/**`; verify auth pages render centered and without the sidebar

## 5. Notes Feature

- [x] 5.1 Rewrite `notes-list.page.ts` template: `p-inputgroup` + `p-inputtext` + `p-button` for quick capture; `p-inputtext` + `p-select` for search/tag filter; verify quick capture creates a note visible in the list without page reload
- [x] 5.2 Rewrite `note-card.component.ts` template as a `p-card` with title, content preview, and `p-tag` for each hashtag in the note; verify tags display for a note that contains `#example` in its content
- [x] 5.3 Rewrite `note-detail.page.ts` template: `p-card` with full content rendered via `MarkdownService.render()` bound to `[innerHTML]` (using `DomSanitizer.bypassSecurityTrustHtml`), and a `p-button` for back navigation; verify a note containing a Markdown code block renders with syntax highlighting

## 6. Assistant Feature

- [x] 6.1 Rewrite `assistant.page.ts` template: each chat turn as a `p-card` (user question + assistant answer); assistant answer bound to `[innerHTML]` via `MarkdownService.render()` with `bypassSecurityTrustHtml`; `p-inputgroup` + `p-button` for the question input; verify sending a question shows a "Thinking…" card and then the rendered answer
- [x] 6.2 Verify Markdown rendering in the assistant: ask the assistant a question that triggers a response with a code block and confirm the code block is syntax-highlighted in the rendered output
- [x] 6.3 Verify the "Grounded in N of your notes" indicator still displays correctly after the template rewrite

## 7. Final Build & Smoke Test

- [x] 7.1 Run `ng build --configuration production` and verify it completes with no errors or warnings about missing PrimeNG modules
- [x] 7.2 Start the full docker-compose stack (`docker-compose up`) and perform a full user journey: register → login → capture a note → search for it → open detail → go to assistant → ask a question about the note; verify all steps complete without console errors
