# Tasks

## 1. ai-service: scoped context and history

- [x] 1.1 In `app/embeddings/repository.py`, add `get_owned_note(note_id, user_id)` and `get_notes_with_tag(user_id, tag)` (joining `note_tags` and `tags` with `tags.user_id = $user`), plus `rank_notes_by_similarity(user_id, note_ids, embedding)`. Every query filters by `user_id`. Verified by `tests/test_isolation.py` cases: another user's note or tag returns nothing.
- [x] 1.2 Add a context builder with `CONTEXT_BUDGET_CHARS`, configurable through `SYNAP_AI_CONTEXT_BUDGET_CHARS`. It truncates at a line or paragraph boundary, fits whole notes for a tag, and falls back to ranking with truncation when the tag exceeds the budget. It returns `(context, sources, partial)`. Verified by unit tests: a short note is sent whole; a long note is truncated and marked partial; a small tag includes all its notes; a large tag includes the ranked notes that fit.
- [x] 1.3 Extend `AskRequest` with an optional `scope_note_id`, `scope_tag` and `history` (capped at 3 items and at the per-item lengths). Branch `/internal/assistant/ask` by scope. Return `partial_context` and the `scope` echo, and `no_relevant_notes` for an empty tag. The unscoped path stays unchanged. Verified by `tests/test_assistant_api.py`: note, tag, empty tag, and an unscoped request with byte-identical behaviour to before.
- [x] 1.4 Change `LlmProvider.generate_answer` / `GroqProvider` to accept `history` and `scope_kind`. Build the scope line in the system prompt and add the history as alternating user and assistant messages before the final question. Verified by `tests/test_groq_provider.py`, which asserts the message list sent through `httpx.MockTransport`.

## 2. .NET API: contract, validation and ownership

- [x] 2.1 Extend `AssistantController.AskRequest` and `AskAssistantQuery` with `Scope` (`NoteId` or `Tag`) and `History`. Return 400 with a Spanish message when both or neither are given inside `scope`. Trim the history to the last 3 items and the per-item lengths, and drop it when there is no scope. Verified by handler unit tests.
- [x] 2.2 In `AskAssistantQueryHandler`, after the key checks, resolve a note scope with `GetOwnedByUserAsync`: return 404 "Nota no encontrada." when it is missing or not owned, and `ScopeUnsupported` with a Spanish message for bookmarks, in both cases without calling the AI service. Verified by unit tests using a fake `IAiServiceClient` that asserts it was not called.
- [x] 2.3 Add `AssistantAnswerStatus.ScopeUnsupported` (`scopeUnsupported`), `PartialContext` and `Scope` to `AssistantAnswer`. Pass `scope` and `history` through `IAiServiceClient.AskAsync` / `AiServiceClient`. Verified by `AiServiceClientTests` (request body and response mapping) and `AssistantAnswerSerializationTests` (wire names).
- [x] 2.4 Add integration tests: user B asking about user A's note gets 404 without reaching the AI service; user B asking about a tag that only A has is forwarded with B's own user id only (design.md Decision 2: .NET does no tag lookup). The `noRelevantNotes` outcome and the absence of any provider call for that tag are covered in the ai-service, by `tests/test_isolation.py::test_get_notes_with_tag_never_crosses_users` against real Postgres and by `test_tag_scope_without_notes_contacts_no_provider`. Verified by the new tests passing in `Synap.IntegrationTests` and the ai-service suite.

## 3. Frontend: model, service and store

- [x] 3.1 Add `AssistantScope`, the `scopeUnsupported` status, and `partialContext` and `scope` to `assistant.model.ts`. Make `AssistantService.ask(question, scope?, history?)` send the new body. Verified by a service spec asserting the request payload.
- [x] 3.2 Refactor `AssistantStore` to key conversations by scope (the v2 storage from design.md Decision 5): legacy array migrated to `global`, 50 messages per conversation, at most 20 scoped conversations evicted by LRU, `clear()` affecting only the active scope, and the last 3 settled turns sent as history for scoped questions only. Verified by store unit tests covering migration, isolation between scopes, eviction, history content and clearing.

## 4. Frontend: assistant page

- [x] 4.1 Read `?note=` or `?tag=` into the active scope. For a note, call `ensureNote` for the title and type, and when it is missing show "La nota ya no existe", drop that conversation and go to the global scope. Show a removable scope chip; removing it navigates to the global scope. Verified by component tests for the note, tag, missing note and remove flows.
- [x] 4.2 Add quick actions per scope kind (note, code note, tag), and a `partialContext` hint under answers. Verified by component tests for which actions are shown per scope and the hint rendering.
- [x] 4.3 Add the `@` note picker (debounced `GET /api/notes?q=&pageSize=8`, bookmarks disabled with an explanation) and the `#` tag picker (from `allTags`). Picking an option sets the scope and removes the typed token. Verified by component tests and a manual check on a 360px screen.

## 5. Frontend: entry points

- [x] 5.1 Add a "Preguntar a la IA" button to the note detail page, linking to `/app/assistant?note=<id>`, disabled with an explanatory tooltip for bookmarks. Add a "Preguntar sobre #tag" action on each tag of the detail page. Verified by component tests for the text, code and bookmark cases.
- [x] 5.2 In the notes list, show "Preguntar sobre #tag" next to an active tag filter. Verified by a component test that the button appears only when a tag filter is active and links to `?tag=`.

## 6. End-to-end check

- [x] 6.1 On the Compose stack, with a real Groq key on the free tier, walk through every scope:
  - **Note:** ask "resume esta nota" on a long note, then "desarrolla el punto 2". Check that the follow-up works, the only source is that note and the partial hint is shown.
  - **Tag:** ask about a tag. Check that every source carries that tag.
  - **Bookmark:** check that the option is disabled.
  - **Other user:** ask about another user's note through the URL. Check that it shows not-found.
  - **Global:** check that global questions behave as before.
  - **Reload:** reload and check that each scope's conversation is restored.

  Verified by completing the walkthrough and saving screenshots in the change folder.

  _Done 2026-09-28: walkthrough (and the 360px picker check of 4.3) completed manually by the user on the Compose stack, all OK. No screenshots were saved._
