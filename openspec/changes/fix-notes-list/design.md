# Design

## Context

- `NotesStore` (plain signals) accumulates pages: `search()` loads page 1 and `loadMore()` appends the next one. `NotesListPage` triggers `loadMore()` from an `IntersectionObserver` on a sentinel plus an `afterNextRender` check. Filters live only in the store, not in the URL.
- The list wraps the cards in `[@listAnimation]="notes().length"`, a `transition('* => *')` with `query(':enter')` and `stagger(55ms)`, from `@angular/animations`. That package has been deprecated since Angular 20.2; the app is on Angular 22. The whole page is also animated by the shell's `routeAnimation`, which briefly makes the entering page `position: absolute`.
- Reproduction attempt (Chrome headless, 31 mixed notes, at 1280px and 390px): initial load, scrolling to page 2, Assistant → Notes navigation, four rapid filter changes, and going back from a detail page. In every case all cards had `opacity: 1`, no leftover transform and a normal height. **The bug has not been reproduced yet.**
- The frontend image runs `nginx` as the non-root `nginx` user with `CMD ["nginx", ...]`. Its `nginx.conf` has only the SPA fallback `try_files $uri $uri/ /index.html`, so `/api/*` gets `index.html` with a 200 status.
- When Angular's `HttpClient` receives a 200 `text/html` response on a JSON request, it raises an `HttpErrorResponse` with `status: 200` and a `SyntaxError` inside. `isHandledGlobally()` only treats `0` and `>= 500` as global failures, so the raw `SyntaxError` message reaches the UI.
- The backend already supports the pagination: `page`, `pageSize` from 1 to 50 (default 20), and `totalCount` in `PagedResult`.

## Goals / Non-Goals

**Goals:**
- Numbered pagination that can be restored from the URL, with the store holding exactly one page.
- Find the real cause of the disappearing cards and remove it, not just hide the symptom.
- `docker compose up` works end-to-end on port 4200 without changing how production is served.

**Non-Goals:**
- Changing the backend search API or the ranking.
- Replacing `routeAnimation` or migrating other animations, unless the reproduction shows they cause the bug.
- Keyset or cursor pagination.

## Decisions

### 1. Page state lives in the URL; the store follows the route
`NotesListPage` reads `?q=&tag=&type=&page=&size=` from `ActivatedRoute.queryParamMap`. The UI changes the URL through `router.navigate` with `queryParamsHandling: 'merge'`, and every URL change triggers `store.search(...)`. Default values (page 1, size 20, no filters) are left out of the URL so it stays clean.

- **Why:** "Back" from a note and reload both work for free, and there is a single source of truth.
- **Alternative considered:** keep the state in the store and only mirror it to the URL. Rejected, because two sources of truth can diverge.
- Invalid values are clamped rather than rejected: `size` not in {10, 20, 50} falls back to 20, and a `page` below 1 falls back to 1.
- A `page` greater than the last page is replaced (with `replaceUrl`) by the last page once `totalCount` is known.

### 2. The store holds one page
`NotesStore` drops `loadMore`, `_loadingMore` and `hasMore`, and gains `page`, `pageSize`, `totalCount` and `pageCount`. `search()` replaces `_notes`. The existing `searchGeneration` guard against stale responses stays.

- Deleting a note reloads the current page, so it refills from the next one. If the current page becomes empty and it is not page 1, the list moves to the previous page.
- Creating a note keeps the current filters and navigates to page 1, where the new note appears.

### 3. PrimeNG `p-paginator`
Use `p-paginator` with `rows`, `totalRecords`, `first`, `rowsPerPageOptions=[10,20,50]`, and `currentPageReportTemplate` = "Mostrando {first}–{last} de {totalRecords}". Below 768px, use `pageLinkSize` 3. The paginator is hidden when `totalCount <= pageSize`. On a page change, the page scrolls `main.content` (the shell's scroll container, not `window`) to the top of the list.

- **Alternative considered:** a custom paginator. Rejected, because PrimeNG is already a dependency and its paginator handles accessibility.

### 4. Card bug: reproduce first, then fix the cause
The first tasks reproduce the bug in the environment where the user sees it: the device, the browser, whether it is the installed PWA, and the trigger. They also rule out a stale service worker by comparing against an incognito window.

- **Main hypothesis:** an interrupted `listAnimation`, which leaves `:enter` elements with their initial inline style (`opacity: 0` or `translateY`), possibly combined with the nested `routeAnimation`.
- **Planned fix if confirmed:** remove `listAnimation` entirely, or replace it with native CSS through `animate.enter` together with `prefers-reduced-motion`. Pagination already removes the append-to-list case that triggered most `* => *` transitions.
- If the cause turns out to be something else, such as layout, the bottom navigation or a stale SW, the fix follows the evidence. The spec requirement "Every note on the page is fully visible" is the acceptance criterion either way.
- **Regression check:** a component test asserts that after several quick list replacements no `app-note-card` is left with a non-default inline `opacity` or `transform`.

### 5. Optional `/api` proxy in the frontend image
- `nginx.conf` gains `include /etc/nginx/snippets/api-proxy.conf;` inside the `server` block, before `location /`.
- A script in `/docker-entrypoint.d/`, run by the official image entrypoint that the Dockerfile keeps, writes that snippet at startup:
  - if `SYNAP_API_UPSTREAM` is set (for example `http://synap-api:80`), it writes:
    ```nginx
    location /api/ {
        resolver 127.0.0.11 valid=10s;
        set $synap_api ${SYNAP_API_UPSTREAM};
        proxy_pass $synap_api;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    ```
  - otherwise it writes an empty file.
- The snippets directory must be writable by the `nginx` user.
- **Why a variable plus Docker's resolver:** nginx resolves the name per request, not at startup. So an API container that restarts with a new IP, or is missing, never prevents the frontend from starting.
- **Why opt-in:** production sits behind the VPS reverse proxy, which already routes `/api`. Without the variable, nothing changes there.
- `docker-compose.yml` sets `SYNAP_API_UPSTREAM: http://synap-api:80` on `synap-frontend`.
- **Alternative considered:** `proxy_pass http://synap-api` hard-coded in `nginx.conf`. Rejected, because nginx refuses to start when that host cannot be resolved, which is the case in any deployment without a container named `synap-api`.
- **Forwarded headers:** the API's per-IP login limit trusts `X-Forwarded-For` only from `ForwardedHeaders__KnownProxies`. On the local stack this proxy is not listed, so every client shares the proxy's IP for the login limit. That is acceptable locally and documented in the README.

### 6. Non-JSON responses are global failures
- `errorInterceptor` treats an `HttpErrorResponse` whose `status` is 2xx and whose `error.error` is a `SyntaxError` (a parse failure) as "server unreachable". It shows one Spanish toast and rewrites the error so `isHandledGlobally()` returns true, meaning the stores do not show a second toast.
- `apiErrorMessage()` never returns `SyntaxError` text.

## Risks / Trade-offs

- [The card bug does not reproduce in the user's environment either] → Remove `listAnimation` anyway: it is deprecated and it is the only component that animates each card. Then ask the user to confirm in their environment before archiving.
- [Losing infinite scroll on mobile feels like a step back] → The page size can go up to 50, and the paginator sits at the bottom of the list, reachable with the thumb.
- [Filters in the URL change the address users see] → Only non-default values are written, and the router's `replaceUrl` is used for clamping, so no junk entries end up in history.
- [An entrypoint script depends on the base image keeping `/docker-entrypoint.sh`] → The Dockerfile keeps the base `ENTRYPOINT`, and a task checks that the container starts both with and without `SYNAP_API_UPSTREAM`.

## Migration Plan

- Frontend and nginx ship together in the frontend image. Production runs without `SYNAP_API_UPSTREAM`, so it behaves exactly as today.
- Old bookmarks of `/app/notes` have no query params, so they still open page 1.
- **Rollback:** redeploy the previous frontend image.
