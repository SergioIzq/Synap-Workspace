## 1. Infrastructure & Repo Setup

- [x] 1.1 [Backend] Scaffold the .NET solution in `Synap-Backend` mirroring Kash-Backend's project split exactly: `Synap.Api`, `Synap.Application`, `Synap.Domain`, `Synap.Infrastructure`, `Synap.Shared.Domain`, `Synap.Shared.Application`; reference `SergioIzq.Domain.Kernel` + `SergioIzq.Application.Kernel` (used as-is) and `SergioIzq.AspNetCore.Kernel` (used partially — see design.md Decision 7); add MediatR, EF Core + `Npgsql.EntityFrameworkCore.PostgreSQL` (no `SergioIzq.Infrastructure.Kernel` — it is MySQL-only). Solution builds clean (0 errors, 0 warnings).
- [x] 1.2 [AI] Scaffold the Python FastAPI project for the AI service as its own deployable process inside `Synap-Backend` (e.g. `ai-service/`), since only `Synap-Backend` and `Synap-Frontend` exist today — flag with Sergio if this should instead be split into a third repo. Minimal FastAPI app + `/health` route + Dockerfile written; **not runtime-verified** — this dev machine has no local Python interpreter (only the Windows Store stub alias), so `pip install`/`uvicorn` could not be executed here. Please run it once on your VPS or a machine with Python 3.12 before trusting it.
- [x] 1.3 [Frontend] Scaffold the Angular 21 project in `Synap-Frontend` mirroring Kash-Frontend's layout (`core/` for guards, interceptors, models, `services/api/`; `features/<feature>/` for routes, pages, components, colocated signal stores) plus the PWA schematic (manifest, service worker, icons, installable on iOS via "Add to Home Screen"). Builds clean; `core/`+`features/` skeleton created; iOS `apple-mobile-web-app-*` meta tags added (Angular's PWA schematic alone only targets Chrome/Android install prompts).
- [x] 1.4 [Infra] Add PostgreSQL with the `pgvector` extension enabled to a Docker Compose file wiring Postgres, the .NET API, the Python AI service and the Angular build. Written at `Synap/docker-compose.yml` (`pgvector/pgvector:pg16` image, healthcheck-gated `depends_on`); **not runtime-verified** — this dev machine has no local Docker daemon.
- [x] 1.5 [Infra] Set up local dev configuration (env vars, connection strings) shared sanely between the two repos. `Synap/.env.example` + root `.gitignore` (ignoring `.env`) for compose; `Synap.Api/appsettings.Development.json` gets a local `DefaultConnection` for running the API outside Docker.

## 2. Identity Capability

- [x] 2.1 [Backend] Model the `User` aggregate and its registration/authentication behavior. Verified against the actual kernel DLLs via reflection (not guessed) - see design.md Decision 7 addendum.
- [x] 2.2 [Backend] Implement `RegisterUserCommand` (open self-registration, unique email enforcement, password hashing)
- [x] 2.3 [Backend] Implement `AuthenticateUserCommand` issuing a JWT access token
- [x] 2.4 [Backend] Add EF Core migration for the `Users` table. Generated with `dotnet ef migrations add InitialCreate`; produces Postgres-native `uuid`/`timestamp with time zone` columns and a unique index on `email`. **Not applied to a live database** - no local Postgres/Docker available in this dev environment; run `dotnet ef database update` against a real instance before relying on it.
- [x] 2.5 [Backend] Add authentication middleware/authorization policy required on every knowledge-vault and ai-assistant endpoint. Implemented as a global `FallbackPolicy` (`RequireAuthenticatedUser()`) so every future controller is protected by default unless marked `[AllowAnonymous]`, rather than a per-endpoint reminder.
- [x] 2.6 [Backend] Add a `user_id`-scoping base/helper used by every repository and query so isolation can't be forgotten per-feature. `IUserContext.RequireUserId()` extension method in `Synap.Shared.Application/UserContextExtensions.cs` - revised during task 3.x from an inheritance-based base class, which both conflicted with `AbsWriteRepository<TEntity,TId>`'s single inheritance slot and lived in the wrong layer (Application handlers need the same check but must not depend on Infrastructure).
- [x] 2.7 [Backend] Port Kash's personal-access-token feature (`GenerateApiTokenCommand`, `ApiTokenAuthenticationHandler`, `GetApiTokenStatusQuery`) for non-interactive authentication, to be reused by the quick-capture endpoint (task 3.4)
- [x] 2.8 [Frontend] Build registration and login screens, token storage, route guards for authenticated views, and the `auth.interceptor`/`error.interceptor`/`loading.interceptor` trio from Kash's `core/interceptors`. Two deliberate deviations from Kash, both noted in code comments: (1) plain-Angular-signals store instead of `@ngrx/signals`' `signalStore` - that package has no release supporting Angular 21 yet; (2) header/localStorage Bearer token instead of Kash's HttpOnly-cookie session, to stay consistent with the personal-access-token flow's own plain-Bearer model and avoid the CORS-credentials/cookie-attribute complexity cookies would add. No UI component library chosen yet, so the screens are functional but unstyled.

## 3. Knowledge Vault Capability

- [x] 3.1 [Backend] Model the `Note` aggregate root (factory method, `UpdateContent`, `AddTag`, `AttachMetadata`), `NoteType` enum (text / code snippet / bookmark), `Tag` entity, and `NoteMetadata` owned value object
- [x] 3.2 [Backend] Add EF Core migrations for `Notes`, `Tags`, and the `NoteTags` join table. Generated (`note_tags` join table, cascade deletes, unique `(user_id, name)` index on tags) - **not applied to a live database**, same caveat as task 2.4.
- [x] 3.3 [Backend] Implement `CreateNoteCommand`, `UpdateNoteCommand`, `DeleteNoteCommand`, `AddTagCommand`
- [x] 3.4 [Backend] Implement the quick-capture endpoint (`QuickCaptureCommand`), authenticated via the personal-access-token mechanism from task 2.7. Type is inferred (`NoteTypeInference`) when the caller doesn't specify one, since a Shortcut only ever hands over raw text or a URL.
- [x] 3.5 [Backend] Implement asynchronous bookmark metadata scraping (title, description, preview image) triggered on bookmark note creation via the in-process background queue (design.md Decision 8), degrading gracefully when the link is unreachable. Built the queue itself here (`IBackgroundJobQueue`/`BackgroundJobQueue`/`QueuedJobHostedService`) since this is its first use; `HtmlAgilityPack` added for parsing (Open Graph tags preferred, falling back to `<title>`/meta description).
- [x] 3.6 [Backend] Implement `SearchNotesQuery` using Postgres full-text search, supporting a tag filter. `to_tsvector`/`plainto_tsquery`/`ts_rank` computed on the fly via Dapper (no stored tsvector column yet - fine at MVP scale, revisit with a generated column + GIN index if search gets slow).
- [x] 3.7 [Frontend] Build the "quick note" input as the app's primary capture surface. Always-visible input at the top of the notes list page (`NotesListPage`).
- [x] 3.8 [Frontend] Build note list/detail views: markdown rendering, syntax-highlighted code snippets with copy-to-clipboard, bookmark cards. `marked` for markdown, `highlight.js/lib/core` with a handful of registered languages (not the ~1MB full bundle - dropped the detail page's lazy chunk from 1.14 MB to ~119 KB). No dedicated "get note by id" endpoint was added: the detail page looks the note up client-side from the already-loaded search results, since a personal vault's note list is never going to be huge.
- [x] 3.9 [Frontend] Build search UI (free text + tag filter) and tag management UI. Tag filter is a dropdown built from tags already present in the loaded notes (no separate "list all my tags" endpoint).
- [x] 3.10 [Docs] Write the iOS Shortcut (share-sheet capture) template and a short onboarding setup guide. A real `.shortcut` binary can't be produced/distributed programmatically (proprietary Apple format, built in the Shortcuts app or shared via iCloud link) - wrote `docs/ios-shortcut-setup.md` with the exact manual setup steps instead.

## 4. AI Assistant Capability

- [ ] 4.1 [AI] Choose and wire a CPU-friendly local embedding model into the Python service
- [ ] 4.2 [Backend] Add a `pgvector` embedding column/migration for notes
- [ ] 4.3 [Backend/AI] Build the asynchronous embedding pipeline via the same in-process background queue (design.md Decision 8): the backend enqueues a job on note create/edit, the AI service generates/regenerates the embedding without blocking the original write
- [ ] 4.4 [AI] Implement the "related notes" semantic similarity query (`pgvector`, scoped to the requesting user)
- [ ] 4.5 [AI] Implement RAG retrieval: embed the incoming question, fetch top-k relevant notes for that user
- [ ] 4.6 [AI] Integrate one external free-tier LLM provider (e.g. Groq or Gemini) behind a single internal interface for answer generation
- [ ] 4.7 [AI] Handle the no-relevant-notes case (state nothing relevant was found) and the provider-unavailable case (clear "temporarily unavailable" message) without fabricating or partially rendering an answer
- [ ] 4.8 [Backend] Expose the assistant chat endpoint connecting the frontend to the AI service
- [ ] 4.9 [Frontend] Build the assistant chat UI, showing which notes grounded each answer
- [ ] 4.10 [Frontend] Build the "related notes" panel on the note detail view

## 5. Cross-Cutting: Isolation, Limits & Deployment

- [ ] 5.1 [Backend] Write integration tests proving one user can never read, search, or list another user's notes or tags
- [ ] 5.2 [AI] Write integration tests proving embeddings, related-notes results, and assistant answers never cross users
- [ ] 5.3 [Backend] Add a per-user rate limit on the quick-capture and assistant chat endpoints to protect the shared VPS
- [ ] 5.4 [Infra] Deploy the Docker Compose stack to the VPS alongside Sergio's existing sites and confirm CPU/RAM stay within budget under light concurrent use
- [ ] 5.5 [QA] Run the end-to-end smoke test: register → capture a note in-app and via the iOS Shortcut → search for it → ask the assistant a question that should retrieve it
