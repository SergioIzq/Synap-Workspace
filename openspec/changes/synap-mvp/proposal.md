## Why

Sergio's notes, code snippets, links and study material are scattered across WhatsApp-to-self messages, browser bookmarks and paper notebooks, with no fast way to capture something on the go (especially from an iPhone with no Mac/Apple dev license) or to find it again later. Synap is a personal "second brain": a multi-user PWA that captures material with near-zero friction and, critically, uses AI to connect that material and answer questions grounded in the user's own notes ("I've hit this error before — what did I do?"). This is the foundational change that stands up the project from nothing: identity, the note vault itself, and the AI layer that makes it more than a notes app.

## What Changes

- **New project.** Scaffold a .NET solution applying DDD, Hexagonal architecture and CQRS (MediatR), an Angular 21 PWA frontend, and a Python FastAPI service for the AI layer, deployed via Docker Compose to Sergio's own VPS (3 vCPU / 8 GB, no GPU).
- **PostgreSQL + pgvector** as the single database engine, shared by the .NET API (relational data) and the Python service (embeddings), avoiding a second piece of vector-store infrastructure.
- **Multi-user identity** with open self-registration (no invite codes for v1); every user gets their own isolated vault — no cross-user data or search leakage.
- **Knowledge vault**: capture and organize notes, code snippets and bookmarks (with automatic metadata scraping for links), tag-based organization, and full-text search.
- **Frictionless capture from iPhone**: since the Web Share Target API is not supported in iOS Safari, capture from the iOS share sheet is implemented via an iOS Shortcut that POSTs to a quick-capture API endpoint, not via PWA share-target registration. The in-app "quick note" input is the primary capture path on all platforms.
- **AI assistant layer (the "soul" of the project)**: local, lightweight embedding generation for every note (kept on-VPS, cheap enough for CPU-only hardware) plus pgvector-backed semantic similarity between notes; a RAG chat endpoint that answers natural-language questions ("I have this error...") grounded in the user's own vault. Text generation is offloaded to an external free-tier LLM API (e.g. Groq/Gemini free tier) rather than self-hosted, to avoid starving the VPS (which also runs Sergio's other production sites) and to keep the project at zero infrastructure cost.
- **Explicitly out of scope for this change** (captured for future changes, not forgotten): academic planning (degrees/years/subjects/assignment deadlines), Pomodoro sessions, photo capture with OCR/vision, offline mode (Service Worker + IndexedDB caching), and automatic AI tagging. These were discussed and sequenced but depend on this foundation landing first.

## Capabilities

### New Capabilities
- `identity`: user registration and login, session/token issuance, per-user data isolation enforced across the API and the AI layer.
- `knowledge-vault`: the Note aggregate (text / code snippet / bookmark types), Tag entity, NoteMetadata value object (link scraping), quick-capture endpoint (used by the iOS Shortcut and the in-app quick-note UI), and full-text search.
- `ai-assistant`: per-note embedding generation, pgvector-backed semantic relations between notes, and a RAG chat endpoint that retrieves relevant notes and calls an external free-tier LLM to generate grounded answers.

### Modified Capabilities
(none — greenfield project, nothing existing to modify)

## Impact

- **New repositories/code**: entire Synap codebase (.NET API, Angular PWA, Python AI service) — no existing system is touched, this is net-new.
- **Infrastructure**: PostgreSQL 16+ with the `pgvector` extension, Docker Compose definitions, deployment onto Sergio's existing VPS alongside other already-hosted sites — sized to fit within 3 vCPU / 8 GB without starving those sites.
- **External dependencies**: one external free-tier LLM API for RAG answer generation (embeddings stay local/self-hosted).
- **Follow-up changes anticipated**: academic planning, Pomodoro, photo/OCR capture, offline mode, and AI auto-tagging, each as its own change once this foundation is in place.
