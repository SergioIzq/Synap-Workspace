## Context

See proposal.md - Why for motivation. Constraints that shape this design:

- **Deployment target**: Sergio's own VPS — 3 vCPU, 8 GB RAM, no GPU, SSD, already running other production sites. Any AI workload must not starve those sites.
- **Repo layout**: two independent git repositories, `Synap-Backend/` and `Synap-Frontend/`, both nested under this `Synap/` workspace where OpenSpec (this proposal, design and specs) lives one level above both. This workspace is the place with simultaneous visibility into both repos, which matters because most features here cut across both (an API contract change on the backend usually has a corresponding frontend consumer change in the same feature).
- **Stack already decided during exploration**: .NET (DDD, Hexagonal, CQRS via MediatR) for the backend API; Angular 21 PWA for the frontend; a Python (FastAPI) service for the AI layer; PostgreSQL with the `pgvector` extension as the single database engine.
- **Architecture reference**: Sergio's prior project, [Kash-Backend](https://github.com/SergioIzq/Kash-Backend) and [Kash-Frontend](https://github.com/SergioIzq/Kash-Frontend), is the explicit template for how this solution is structured — reusing a proven, already-working convention rather than inventing a new one. See Decision 7.
- **Cost constraint**: the whole system must run at zero recurring cost — self-hosted where cheap (embeddings), external free-tier where self-hosting would be too heavy (LLM generation).

## Goals / Non-Goals

**Goals:**
- Stand up `identity`, `knowledge-vault` and `ai-assistant` as three cleanly separated capabilities that can each evolve independently.
- Keep the AI workload within the VPS's real budget (3 vCPU / 8 GB, shared with other sites) by keeping only cheap work (embeddings) local and pushing expensive work (text generation) to an external free tier.
- Make per-user data isolation a cross-cutting guarantee enforced at the data-access layer, not something each feature has to remember.
- Keep the capture path usable from an iPhone with no Mac and no Apple developer license.

**Non-Goals:**
- Building a native iOS app, or relying on the Web Share Target API (unsupported in iOS Safari — see proposal.md).
- Academic planning, Pomodoro, photo/OCR capture, offline mode, and AI auto-tagging — each is a candidate for its own future change once this foundation lands.
- Horizontal scaling or multi-node deployment — this is a single-VPS deployment for now.

## Decisions

**1. Single Postgres instance with `pgvector`, shared by both services.**
The .NET API owns the relational schema (users, notes, tags); the Python AI service owns the embeddings, stored as `vector` columns in the same database. Considered a dedicated vector store (Qdrant/Chroma): rejected for v1 because it adds a second piece of infrastructure to operate on an already resource-constrained VPS, with no benefit at this data volume (single user's notes, not web-scale).

**2. Embeddings generated locally; generation delegated to an external free-tier LLM.**
A small local embedding model (CPU-friendly, low-RAM) runs inside the Python service and is used for every note. The RAG chat's answer generation calls an external provider (e.g. Groq or Gemini free tier) instead of a locally-hosted LLM. Rationale: a 7-8B local model already needs 4-6 GB of RAM and is slow on 3 CPU cores with no GPU — on a VPS that also serves other production sites, that risk is not acceptable. Embeddings are cheap enough to stay local and free. The LLM provider is accessed through a single internal interface in the Python service so it can be swapped if a free tier's terms change.

**3. Capture from iOS via a Shortcut, not a PWA share target.**
An iOS Shortcut (distributed as a shareable link during onboarding) appears in the native iOS share sheet and POSTs to a `quick-capture` endpoint. The in-app "quick note" input remains the primary capture path on every platform; the Shortcut is the iOS-specific bridge for the "share from Safari/YouTube" flow described during exploration. Authentication for this non-interactive call reuses Decision 7's personal-access-token pattern rather than a session login.

**4. Per-user isolation enforced at the data-access layer in both services.**
Every query — relational (notes, tags) and vector (semantic search, RAG retrieval) — is scoped by `user_id` at the repository/query layer, not left to individual handlers to remember. This is treated as a security-critical invariant, not a convenience filter.

**5. CQRS with MediatR in the backend, one command/query per user-visible action.**
Matches the pattern already used in Sergio's prior project (Kash): e.g. `CreateNoteCommand`, `QuickCaptureCommand`, `SearchNotesQuery`, `GetRelatedNotesQuery`. Keeps note-writing (which triggers async embedding generation) decoupled from note-reading.

**6. Open self-registration for v1.**
Matches the decision to let UPO classmates join without friction. Combined with per-user isolation (Decision 4) and a rate limit on AI-heavy endpoints (see Risks) to protect the shared VPS from unbounded load.

**7. Backend and frontend structure mirror Kash's conventions exactly, not a generic DDD/Angular layout.**
Confirmed against the actual Kash-Backend/Kash-Frontend repos (not just remembered from description):

- Backend solution mirrors `Kash.sln`'s project split: `Synap.Api` (controllers, auth handlers, `Program.cs`), `Synap.Application` (MediatR, `Features/<Capability>/Commands|Queries/<UseCase>/<UseCase>Command.cs` + `<UseCase>CommandHandler.cs`, vertical-slice style), `Synap.Domain` (per-aggregate folder: the aggregate class, `I<Aggregate>ReadRepository`, `I<Aggregate>WriteRepository`, an `Eventos/` folder for domain events), `Synap.Infrastructure` (`Persistence/Command/Configurations/<Aggregate>Configuration.cs` + the write-side `DbContext` for EF Core, `Persistence/Data/<Aggregate>/<Aggregate>ReadRepository.cs` + `<Aggregate>WriteRepository.cs` implementations, `Persistence/Query/` for cross-aggregate/reporting-style read queries via a raw SQL connection factory, `EventHandlers/` for domain-event side effects), and `Synap.Shared.Domain` / `Synap.Shared.Application` for cross-cutting kernel types.
- Kash already solved non-interactive API authentication with a personal-access-token feature (`GenerateApiTokenCommand`, `ApiTokenAuthenticationHandler`, `GetApiTokenStatusQuery`). Synap reuses this exact mechanism for the iOS Shortcut's quick-capture call (Decision 3) instead of designing a new token scheme.
- Frontend mirrors the `core/` vs `features/` split: `core/` holds guards, interceptors (`auth`, `error`, `loading`), DTO models, and `services/api/<domain>.service.ts`; each `features/<feature>/` folder owns its own `routes.ts`, `pages/`, `components/`, and a colocated signal store (`store/<feature>.store.ts`) rather than one global NGRX store. Deployment follows Kash's per-repo `Dockerfile` + `nginx.conf` for the Angular app.
- Rationale: consistency with a codebase Sergio already knows well reduces the design surface of this change to genuinely new decisions (the AI layer, pgvector, multi-tenancy details) instead of re-litigating solved problems like how CQRS or repository splitting should look.
- **Amendment after inspecting the actual kernel packages on nuget.org**: `SergioIzq.Infrastructure.Kernel`'s own published description states it deliberately assumes MySQL (`LIMIT`/`OFFSET`, `DATE_FORMAT`) and is "not multi-provider" — its base `DbContext`, `IUnitOfWork`, and Read/Write repository base classes are not usable with PostgreSQL. `SergioIzq.AspNetCore.Kernel` is mostly provider-agnostic but its global exception middleware maps `MySqlException` specifically, and its bundled Hangfire wiring is MySQL-backed. Concretely, for Synap:
  - Reused as-is: `SergioIzq.Domain.Kernel` (entity base, Result/Error, repository/UoW contracts — fully DB-agnostic) and `SergioIzq.Application.Kernel` (CQRS/MediatR base, marker-interface DI — fully DB-agnostic).
  - Reused partially: `SergioIzq.AspNetCore.Kernel` for JWT auth, the base controller, bootstrap (Serilog/Kestrel/CORS/JSON/Swagger/compression/cookies) and health checks — but Synap writes its own exception-handling middleware instead of the kernel's MySQL-mapping one, and does not use the kernel's Hangfire helper.
  - Not used: `SergioIzq.Infrastructure.Kernel`. Synap.Infrastructure implements its own base `DbContext`, `IUnitOfWork`, domain-event-dispatch interceptor, and Read/Write repository base classes against Npgsql/PostgreSQL — matching Kash's *shape* (same class names, same read-via-Dapper/write-via-EF-Core split) without depending on the MySQL-only package.

**8. Background/async work (bookmark scraping, embedding generation) uses an in-process queue, not Hangfire.**
Kash's background jobs run on Hangfire with a MySQL storage backend, unavailable to us per Decision 7. Rather than standing up `Hangfire.PostgreSql` (its own tables, dashboard, more footprint on an already-tight VPS), Synap uses a lightweight in-process queue (`IHostedService` + `System.Threading.Channels`) for both the bookmark-metadata scraping (task 3.5) and the embedding generation pipeline (task 4.3). Trade-off accepted: queued work is lost if the process restarts mid-job — acceptable for v1's scale; revisit with durable job storage if this becomes a real reliability problem.

**9. Kernel API usage confirmed by reflection, not guessed from Kash's source.**
Kash's source shows how the kernel is *used*, not its exact signatures. Before writing Identity, the three kernel DLLs (already restored in `Synap-Backend`'s NuGet cache) were loaded into a scratch console app and inspected with `System.Reflection` — exact namespaces, method signatures, and default parameter values. This surfaced real discrepancies a guess would have missed: `AddKernelHealthChecks`'s connection-string parameter is literally named `mySqlConnectionString` (so it is called with no connection string at all, not Postgres's), `AddKernelJwtAuthentication`/`KernelJwtTokenGenerator.GenerateToken` have extra parameters with defaults, and `AbsController`'s members (`HandleResult`, `SendAndHandleAsync`, `GetCurrentUserId`) are `protected`, not `public`. Also confirmed usable as-is and provider-agnostic: `SergioIzq.AspNetCore.Kernel`'s `ResultHandlerMiddleware`/`NoCacheMiddleware` (`UseResultHandler()`/`UseNoCache()`) and `AddKernelPasswordHasher()`/`AddKernelUserContext()` — only `GlobalExceptionHandler` (MySQL-mapping) and the Hangfire/health-check helpers are skipped, narrower than Decision 7's original assumption that most of the ASP.NET Core kernel bootstrap needed replacing.

**10. Frontend Identity diverges from Kash in two specific, deliberate ways.**
- **Plain Angular signals instead of `@ngrx/signals`.** That package has no published version supporting Angular 21 (`20.0.1`'s peer dependency caps at `^20.0.0`, `22.0.0`'s requires `^22.0.0` — no release in between). Forcing an unsupported peer dependency into a brand-new project's foundation was judged riskier than a small, swappable plain-signals service with the same shape (state signals + computed + methods). Revisit once a compatible release exists.
- **Bearer token in memory/localStorage instead of an HttpOnly session cookie.** Kash's web login sets a cookie (`useCookie=true`, `Response.SetAuthCookie`) and its `auth.interceptor` just forwards credentials; Synap's `AuthController.Login` only ever returns the JWT in the response body, and the Angular `authInterceptor` attaches it as a header. Specs/identity only requires "an access token for subsequent API requests," not a cookie specifically, and keeping the interactive login on the same plain-Bearer model as the personal-access-token flow (Decision 3) avoids adding CORS-credentials mode and cookie-attribute handling for a single login flow.

## Risks / Trade-offs

- **[Risk]** Multiple users hitting the RAG chat concurrently could queue up behind the external LLM's free-tier rate limit, or several embedding jobs running at once could compete with the VPS's other hosted sites for CPU. **Mitigation**: process embedding generation through a background queue (not inline with the write), and apply a simple per-user rate limit on the chat endpoint.
- **[Risk]** Open registration means anyone with the link can create an account and consume the shared AI quota. **Mitigation**: per-user rate limits from day one; registration can be switched to invite-only later without a data model change.
- **[Risk]** The external free-tier LLM provider could change its terms, get slower, or disappear. **Mitigation**: Decision 2's provider-behind-an-interface approach keeps the swap cost low.
- **[Risk]** Two independent repos (`Synap-Backend`, `Synap-Frontend`) mean a single feature often needs coordinated changes in both. **Mitigation**: tasks.md will call out which repo each task belongs to, and this top-level OpenSpec workspace is the place where both are visible at once specifically so cross-repo contracts (API shape, DTOs) are designed together rather than guessed at from one side.
- **[Risk]** The iOS Shortcut requires a manual one-time install by each user, unlike a "just works" PWA share target. **Mitigation**: accepted trade-off given the iOS platform limitation; onboarding includes a direct install link and short setup steps.

## Migration Plan

Greenfield project — no existing data or users to migrate.

1. Provision PostgreSQL with `pgvector` enabled (local dev via Docker Compose; VPS via the same Compose file).
2. Stand up the .NET API with initial EF Core migrations for `identity` and `knowledge-vault`.
3. Stand up the Python AI service with the local embedding model and the external LLM provider wired behind its interface.
4. Stand up the Angular PWA (manifest + service worker for installability, not yet for offline caching).
5. Wire Docker Compose end-to-end and deploy to the VPS alongside the existing sites; verify resource usage (CPU/RAM) stays within budget under light concurrent use before opening registration publicly.
6. Smoke-test the full loop: register → capture a note (in-app and via the iOS Shortcut) → search → ask the assistant a question referencing that note.

Rollback: since this is a new deployment with no prior state, rollback is simply stopping the new containers — no other system depends on this yet.

## Open Questions

- Exact local embedding model and exact external LLM provider (Groq vs Gemini vs another free tier) — deferrable: either choice satisfies Decision 2 without changing the specs, and the provider-behind-an-interface approach means switching later is cheap.
- Exact per-user rate limit numbers for the AI endpoints — deferrable: start conservative, tune once real usage from UPO classmates is observed.
