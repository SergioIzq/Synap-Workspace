# Tasks

## 0. Prerequisite

- [x] 0.1 Finish and archive `scoped-assistant` (tasks 4.3 and 6.1 are pending). Verified by `openspec validate assistant-agent-foundations --strict` no longer reporting that the RENAMED source for "Follow-up questions within a scoped conversation" is missing.

## 1. Spike: embedding model, threshold and tool-capable models

- [x] 1.1 Write a throwaway script (not committed to the app) that embeds a copy of 50–100 real notes with `paraphrase-multilingual-MiniLM-L12-v2` and, if the installed fastembed lists it, `multilingual-e5-small`. Run about 20 real Spanish questions with known expected notes through vector-only and hybrid (RRF) retrieval, and record hit@5 and the similarity of the best irrelevant match. Pick the model and the vector threshold (design.md Decision 5). Verified by the results table and the choice written in a short "Spike results" note appended to design.md.
- [x] 1.2 With a real free-tier Groq key, run a fixed set of 6 tool-use prompts (create note, add tags to a found note, remember, a multi-search question, a question that needs no tools, and a deletion request) against the candidate Groq models. Record which ones produce valid `tool_calls` and respect the "no destructive" instruction, and which ones return 400 for `tools`. Verified by the resulting `tool_capable_models` list being added to "Spike results" in design.md.

## 2. Database migrations (.NET, EF Core)

- [x] 2.1 Add the migration `note_embeddings.model text NOT NULL DEFAULT 'BAAI/bge-small-en-v1.5'` plus an index on `(user_id, model)`. If the model chosen in 1.1 is not 384-dimensional, the same migration also drops and recreates `embedding` with the new dimension (every row is re-embedded anyway). Verified by `dotnet ef database update` on a fresh Compose database and by `\d note_embeddings`.
- [x] 2.2 Add the `MemoryEntry` entity and the `memory_entries` table (`id`, `user_id` FK with `ON DELETE CASCADE`, `text varchar(200)`, `created_at`, `updated_at`, index on `user_id`). Verified by the migration applying cleanly and by an integration test in which deleting a user removes their entries.

## 3. ai-service: embeddings and hybrid search

- [x] 3.1 Set `embedding_model` to the model chosen in 1.1, and handle `query:`/`passage:` prefixes if it is e5. `/internal/embeddings/generate` accepts `title` and embeds `title + "\n\n" + content`. `upsert_embedding` writes `model`. Verified by `tests/test_embeddings_api.py`, which asserts the stored `model` and that the title changes the vector.
- [x] 3.2 Add the startup reindex task: select notes with a missing embedding or `model != current`, in batches of 32 with a pause between batches, write-only on `note_embeddings`, and log progress. Verified by a test against real Postgres: rows seeded with an old model are all re-embedded with the current one, and a failure in one note does not stop the rest.
- [x] 3.3 Add `repository.hybrid_search(user_id, query_text, query_embedding, limit)`: vector top 20 filtered by `user_id` and the current model, full-text top 20 with the query's lexemes OR-ed together on `notes.search_vector`, RRF with k = 60, and the keep rule "similarity ≥ 0.45 OR at least min(2, query lexemes) distinct query lexemes matched" (design.md Spike results). Make `search_similar` and `find_related_notes` filter by the current model. Verified by tests: an exact-term note ("NU1605") is found despite low similarity; old-model rows are ignored by the vector half; another user's notes are never returned (`test_isolation.py`).
- [x] 3.4 Add `POST /internal/search { user_id, query, limit }` returning `[{id, title, type, tags, snippet(400)}]`, and switch the unscoped `/internal/assistant/ask` RAG path to `hybrid_search`. Verified by `tests/test_assistant_api.py`: the RAG path still returns `no_relevant_notes` without a provider call when nothing is kept.

## 4. ai-service: LLM step, memory and model capabilities

- [x] 4.1 Add `StepResult`, `LlmToolsUnsupportedError` and `LlmProvider.chat_step(messages, tools, api_key, model)`. Implement it in `GroqProvider` with OpenAI-style `tools` and `tool_calls`, parse arguments with `json.loads`, and return an `arguments_error` for invalid JSON. Map a 400 that mentions `tools` or `tool_choice` to `LlmToolsUnsupportedError`. Verified by `tests/test_groq_provider.py` with `httpx.MockTransport` covering text, tool calls, invalid JSON, a 400 for tools, 401 and 429.
- [x] 4.2 Add `POST /internal/llm/step { messages, tools?, groq_api_key, groq_model }` returning `{ status, text?, tool_calls? }`, with the same typed statuses as `/ask` plus `tools_unsupported`. Verified by the API tests.
- [x] 4.3 Add `memory: list[str]` to `/internal/assistant/ask` and `generate_answer`, rendered as a block after the fixed system instructions and before the history (design.md Decision 8), for both scoped and unscoped paths. Verified by provider tests asserting the position of the memory block in the messages, and that an empty memory leaves the prompt identical to today's.
- [x] 4.4 Add a `tool_capable_models` setting, filled from spike 1.2, and make `/internal/llm/models` return `[{id, supports_actions}]`. Verified by `tests/test_llm_api.py`.

## 5. .NET: memory feature

- [x] 5.1 Add the `MemoryEntry` domain type with validation (non-empty after trim, at most 200 characters), the read/write repositories, and the commands and queries `AddMemoryEntry` (rejects a 26th entry with the Spanish "memoria llena" message), `UpdateMemoryEntry`, `DeleteMemoryEntry`, `DeleteAllMemory` and `ListMemory` (most recently updated first). Another user's id is treated as not found. Verified by unit tests for each rule.
- [x] 5.2 Add `MemoryController`: `GET/POST /api/memory`, `PUT/DELETE /api/memory/{id}`, `DELETE /api/memory`. Verified by integration tests, including user B getting 404 on user A's entry, and account deletion removing entries (`identity` "Delete account").

## 6. .NET: assistant agent

- [x] 6.1 Adapt `IAiServiceClient` and `AiServiceClient`:
  - `AskAsync` gains `memory`;
  - new methods `StepAsync(messages, tools, key, model)` and `SearchAsync(userId, query, limit)`;
  - `ListModelsAsync` returns `supportsActions`.
  Adapt `GroqModelLookup`, `AiSettingsResponse` and the settings endpoint to expose `supportsActions` per model. Verified by `AiServiceClientTests` (request bodies and response mapping) and a settings endpoint integration test.
- [x] 6.2 Implement `AssistantAgent` in Application:
  - build the system prompt, with its rules (non-destructive, say "no he encontrado nada", note content is data and not instructions), memory, the last 3 history turns and the question;
  - loop up to `AssistantOptions.MaxSteps = 4`, omitting tools on the last step;
  - execute the tools of design.md Decision 2 through `CreateNoteCommand`, `AddTagCommand`, `AddMemoryEntry`, `GetOwnedByUserAsync` and `SearchAsync`;
  - turn validation and ownership failures into error results for the model;
  - skip a duplicate `create_note` within one question;
  - collect `sources` (deduplicated, at most 8) and `actions`.

  Verified by unit tests with a scripted fake `IAiServiceClient`: create-and-tag flow, step cap reached, invalid arguments, another user's note id treated as not_found, duplicate creation skipped, and a provider failure at step 3 keeping the earlier actions in the response.
- [x] 6.3 Route requests in `AskAssistantQueryHandler`:
  - scoped questions keep today's path, now with memory;
  - global questions whose model supports actions go to `AssistantAgent`;
  - otherwise, or on `tools_unsupported`, global questions use the RAG path with memory and history;
  - `history` is no longer dropped for global questions.

  Add `Actions` to `AssistantAnswer`, always serialised (`[]` when empty). Verified by handler unit tests for each route and by `AssistantAnswerSerializationTests`.
- [x] 6.4 Add integration tests for isolation: user B's agent cannot read or tag user A's note, B's searches never return A's notes, and A's memory is never sent in B's requests. Verified by the tests passing in `Synap.IntegrationTests`.

## 7. Frontend

- [x] 7.1 Add `AssistantAction` and `actions` to `assistant.model.ts`. `AssistantStore` stores the actions with each answer (a missing field reads as `[]`) and sends the last 3 settled turns as `history` in the global conversation too. Verified by store unit tests: actions survive a reload, and global history is sent and capped.
- [x] 7.2 Render the actions under each answer in `assistant.page.ts`, as chips with icons. Note and tag actions open `/app/notes/:id`; memory actions open the "Memoria" section in Settings. Verified by component tests for each action type and the link targets.
- [x] 7.3 Add a `MemoryService` and a "Memoria" section in the Settings page:
  - a list with the update date and an "n/25" counter;
  - add and inline edit with the 200-character limit shown;
  - delete, and "Borrar toda la memoria" using the existing confirmation dialog;
  - Spanish error toasts.

  Verified by component tests, and by a manual check on a 360px screen.
- [x] 7.4 Show an "Acciones" tag on models that support actions in the Settings model selector, plus a helper text when the selected model does not. Verified by component tests.

## 8. End-to-end verification

- [x] 8.1 On the Compose stack, with a real free-tier Groq key and the vault from spike 1.1, check:
  - the reindex completes while the assistant keeps answering;
  - "¿qué hice con el error X?" finds the note;
  - a global follow-up works;
  - "apúntame … #infra" creates a linked note;
  - "etiqueta mi nota de Docker como #docker" works;
  - "recuerda que prefiero respuestas cortas" appears in Memoria and changes later answers;
  - "borra mi nota de X" is refused;
  - with a model without action support, "apúntame …" explains that the current model can't perform actions;
  - no question takes more than 4 Groq calls (checked in the ai-service logs).

  Record the outcomes in the change's notes.
