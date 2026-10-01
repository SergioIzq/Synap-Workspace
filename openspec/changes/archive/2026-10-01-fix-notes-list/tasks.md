# Tasks

## 1. Reproduce the card bug

- [x] 1.1 Ask the user where they see the cards cut off or disappearing: device, browser, installed PWA or tab, production or local, and what triggers it (loading, scrolling, creating a note, going back). Record the answer in design.md Decision 4. Verified when the trigger and environment are written down.
- [x] 1.2 Reproduce it in that environment, first in an incognito window to rule out a stale service worker. Capture a screenshot, plus the computed `opacity`, `transform` and height of the affected `app-note-card`. Verified when the bug is reproduced and the cause is identified, or when it is shown to happen only with an old SW build.

## 2. Local stack: `/api` proxy

- [x] 2.1 Add `/docker-entrypoint.d/40-synap-api-proxy.sh` to Synap-Frontend. It writes `/etc/nginx/snippets/api-proxy.conf` with the `location /api/` block from design.md Decision 5 when `SYNAP_API_UPSTREAM` is set, and an empty file otherwise. Make the directory writable by the `nginx` user in the Dockerfile. Verified by `docker run` without the variable: the container is healthy and `curl :4200/api/x` still returns `index.html`.
- [x] 2.2 Add `include /etc/nginx/snippets/api-proxy.conf;` to `nginx.conf` before `location /`. Verified by `nginx -t` inside the container in both modes.
- [x] 2.3 Set `SYNAP_API_UPSTREAM: http://synap-api:80` on `synap-frontend` in `docker-compose.yml`. Verified with `docker compose up --build`: `curl -i localhost:4200/api/notes` returns `401` from the API (not `text/html`), and signing in through `localhost:4200` works.
- [x] 2.4 In the README, document the variable, the fact that production does not set it, and the shared-IP effect on the login rate limit on the local stack. Verified by reading the README section.

## 3. Non-JSON responses

- [x] 3.1 In `errorInterceptor`, turn an `HttpErrorResponse` with a 2xx status and a `SyntaxError` into a single Spanish "No se pudo contactar con el servidor" toast, and mark it so `isHandledGlobally()` is true. Verified by an `error.interceptor.spec.ts` case (200 `text/html` on a JSON request): one toast in Spanish and no `Unexpected token` text.
- [x] 3.2 Make `apiErrorMessage()` never return parser or transport text. Verified by a unit test with a `SyntaxError` payload that returns the fallback.

## 4. Store: one page at a time

- [x] 4.1 Refactor `NotesStore`: remove `loadMore`, `_loadingMore` and `hasMore`; add `page`, `pageSize` and `pageCount`; make `search({ ...filters, page, pageSize })` replace the notes, keeping the `searchGeneration` guard. Verified by store unit tests: replacement instead of appending, and a stale response is ignored.
- [x] 4.2 After `delete`, reload the current page and move to the previous page if it is empty and not page 1. After `create`, go to page 1 keeping the filters. Verified by store unit tests for both cases.

## 5. List page: paginator and URL state

- [x] 5.1 Drive the list from `queryParamMap` (`q`, `tag`, `type`, `page`, `size`), clamping invalid values and writing only non-default ones. Update the URL on search, filter, page and size changes, returning to page 1 when a filter or the size changes. Verified by component tests: `?page=3&tag=x` loads page 3 filtered by `x`; changing the type goes to page 1; `?size=7` is treated as 20.
- [x] 5.2 Add `p-paginator` (sizes 10/20/50, "Mostrando {first}–{last} de {totalRecords}", `pageLinkSize` 3 below 768px), hidden when everything fits on one page. On a page change, scroll `main.content` to the top of the list. Verified manually at 1280px and 360px (no horizontal scroll) and by a component test that it is hidden when `totalCount <= pageSize`.
- [x] 5.3 When `page` is beyond the last page, replace the URL with the last page (`replaceUrl`). Verified by a component test with `?page=99`.
- [x] 5.4 Remove the `IntersectionObserver`, the sentinel, `scheduleLoadCheck`, `PREFETCH_PX` and the "Cargar más" button. Verified when `npm run build` and the lint pass with no leftover references.

## 6. Fix the card bug

- [x] 6.1 Apply the fix for the cause found in 1.2. If it is the animation, remove `listAnimation` (or replace it with a CSS `animate.enter` that respects `prefers-reduced-motion`). Verified by a component test: after several quick list replacements, no `app-note-card` keeps an inline `opacity` or `transform`.
- [x] 6.2 Re-run the reproduction from 1.2 in the user's environment and ask the user to confirm the cards now display in full. Verified by the user's confirmation.

## 7. End-to-end check

- [x] 7.1 On the Compose stack with more than 45 notes of mixed types: sign in at `localhost:4200`, move between pages, change the size, filter, open a note and go back, then reload. Verified when the page, filters and results are preserved and every card is fully visible, on desktop and at a mobile width.
