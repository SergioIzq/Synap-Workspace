# Design

## Context

- **Request flow today:** `POST /api/assistant/ask { question }` → `AskAssistantQueryHandler` (loads the user and decrypts their Groq key) → `AiServiceClient.AskAsync` → ai-service `/internal/assistant/ask`.
- **ai-service:**
  - embeds the question with `bge-small-en-v1.5`;
  - takes the top 5 from `note_embeddings`, all of which clear the `MIN_RELEVANT_SIMILARITY = 0.2` threshold (measured: two unrelated Spanish notes score 0.59);
  - joins every note's content into the context;
  - calls Groq with a single system and user message pair.
- **No history** is sent. The frontend keeps one conversation per user in `localStorage` (`synap.chat.<userId>`, capped at 50 messages).
- **Isolation:** the invariant already applies to every path. The .NET side checks ownership with `GetOwnedByUserAsync`, and every ai-service query filters by `user_id`.
- **Tags:** the `tags` table has `(user_id, name)` unique, and `note_tags(note_id, tag_id)` links them to notes.
- **Constraint:** the user runs on Groq's free tier with their own key. Tokens per minute is the binding limit, so context size must be bounded per request.

## Goals / Non-Goals

**Goals:**
- Scoped answers that do not depend on the quality of global semantic retrieval.
- A bounded, predictable prompt size: note or notes, plus history, plus question.
- Stay backward compatible: a request without `scope` or `history` behaves exactly as today.

**Non-Goals:**
- Fixing global retrieval (embedding model, threshold, hybrid search, honest citations). That belongs to the future `fix-semantic-retrieval` change.
- Bookmark and article content, and chunking. That belongs to the future `read-later-articles` change.
- Streaming answers, server-side conversation storage, and memory for the global conversation.
- Multi-note scopes, meaning an arbitrary selection of several notes.

## Decisions

### 1. API contract
Public request:

```http
POST /api/assistant/ask
{
  "question": "string",
  "scope":   { "noteId": "guid" } | { "tag": "string" } | null,
  "history": [ { "question": "string", "answer": "string" } ] | null
}
```

Validation, in the .NET query handler:
- **Scope:** exactly one of `noteId` and `tag`, otherwise 400 with a Spanish message. `tag` is normalised the same way tags are stored.
- **History:** only the **last 3** items are kept and the rest are ignored silently. The spec says more are not rejected.
- **Item size:** each `question` is truncated to 1,000 characters and each `answer` to 2,000.
- **Global questions:** when `scope` is null, `history` is dropped entirely. The spec keeps global questions stateless.

Response: `AssistantAnswer` gains:
- `scope`: an echo of `{ noteId | tag }`;
- `partialContext`: a bool, true when the note or notes were truncated to fit the budget;
- a new status, `scopeUnsupported`, for bookmarks.

All three fields are additive, so older clients keep working.

- **Alternative considered:** separate endpoints (`/notes/{id}/ask`, `/tags/{name}/ask`). Rejected, because one endpoint keeps the rate-limit policy (`AiHeavy`), the key handling and the error mapping in one place.

### 2. Ownership is checked in .NET before the AI service is called
- **Note scope:** `GetOwnedByUserAsync(noteId, userId)`. If it returns nothing, respond with `Error.NotFound("Nota no encontrada.")` (404). This is the same response as a missing note, and the provider is never contacted.
- **Note type:** if the note is a bookmark, return `AssistantAnswer.Failed(<Spanish message>, ScopeUnsupported)` without calling the AI service.
- **Tag scope:** no .NET lookup. The ai-service query filters by `user_id` and tag name. A tag that is empty or belongs to someone else falls through to `noRelevantNotes`, which the spec requires to be indistinguishable.
- **Order of checks:** the key checks (`keyMissing` / `invalidKey`) run first, as they do today. Then the scope checks run.
- **Defense in depth:** the ai-service still filters every query by `user_id`, even for a `note_id` that .NET has already verified.

### 3. Context assembly in the ai-service, with a character budget
Define `CONTEXT_BUDGET_CHARS = 12_000`, roughly 3,000 to 4,000 tokens. It is configurable through `SYNAP_AI_CONTEXT_BUDGET_CHARS`.

- **Note scope:** fetch `id, title, content, note_type` with `WHERE id = $1 AND user_id = $2`. Use the full content if it fits. Otherwise keep the first `budget` characters, cut at the last paragraph or line break, and set `partial_context = True`. No embedding and no similarity step.
- **Tag scope:**
  - Fetch the notes of that tag for the user (join `note_tags` and `tags`, with `tags.user_id = $user`).
  - If the sum of their contents fits the budget, use them all, newest first.
  - Otherwise, embed the question and rank only those notes by similarity (`note_embeddings` join with `note_id = ANY(tag note ids)`). Add notes in rank order until the budget is reached. A single note that is larger than the remaining budget is truncated as in the note scope. Set `partial_context = True`.
  - No similarity threshold: the user chose the set explicitly.
  - No notes means `no_relevant_notes`.
- **Sources:** exactly the notes whose content was sent.
- **History budget:** separate from the note budget, at most 3 × (1,000 + 2,000) characters. That is already enforced upstream and re-checked here.
- **Why characters rather than tokens:** there is no tokenizer dependency for Groq models, and a conservative character budget is good enough to stay under the free-tier TPM.
- **Alternative considered:** reusing `search_similar` with a note or tag filter for all cases. Rejected, because for a single note it adds an embedding call and ranking that do not help. For small tags, sending everything gives better answers than a top-k subset.

### 4. Prompt shape and history
`LlmProvider.generate_answer(question, context, api_key, model, *, history=(), scope_kind=None)` builds these messages:

1. **system:** the current `SYSTEM_PROMPT`, plus a scope line. For a note: "The user is asking about the single note below; answer about it." For a tag: "The notes below are all the user's notes tagged #x." When partial: "Only the beginning of the note is included."
2. **Earlier turns:** for each history item, a `user` message with the question and an `assistant` message with the answer, sent before the new question. The notes context is **not** repeated for past turns.
3. **user:** `Notes:\n{context}\n\nQuestion: {question}`.

The history comes from the client, so it is untrusted. It is the user's own conversation, though, so the only person it can mislead is that user. It is length-capped and never used for retrieval, which keeps it from reaching another user's data.

- **Alternative considered:** rewriting the follow-up question with an extra LLM call before retrieval. Rejected, because it doubles the Groq calls per question on the free tier. In a note scope no retrieval happens, and in a tag scope retrieval uses the new question joined with the previous question, with no extra call.

### 5. Frontend: conversations keyed by scope
- **Scope type:** `type AssistantScope = { kind: 'global' } | { kind: 'note'; noteId; title } | { kind: 'tag'; tag }`. The key is `global`, `note:<id>` or `tag:<name>`.
- **Storage:** `synap.chat.<userId>` changes from `ChatMessage[]` to `{ v: 2, conversations: Record<key, { messages: ChatMessage[]; updatedAt }> }`.
  - Each conversation keeps up to 50 messages.
  - At most 20 scoped conversations are stored; the least recently updated are evicted first. `global` is never evicted.
  - On read, a legacy array is migrated to `conversations.global`.
  - Sign-out already removes every `synap.chat.*` key, so every scope is cleared (spec: "Conversation cleared on sign out").
- **Routing:** `/app/assistant?note=<id>` or `/app/assistant?tag=<name>`, so the entry points are plain links and the state survives a reload.
  - For a note scope, the page calls `notesStore.ensureNote(id)` to get the title and type.
  - If the note is missing, the page shows "La nota ya no existe", drops that conversation and navigates to the global scope with `replaceUrl`.
- **History sent:** for scoped questions only, the last 3 settled `{ question, answer.answer }` pairs of that conversation.
- **Quick actions:** predefined Spanish questions.
  - Note: "Resume esta nota", "¿Cuáles son los puntos clave?", and for `codeSnippet` "Explícame este código paso a paso".
  - Tag: "Resume lo que sé sobre #x", "¿Qué conclusiones o patrones se repiten en #x?".
- **`@` and `#` pickers:** an autocomplete in the input.
  - `@` queries `GET /api/notes?q=<text>&pageSize=8` with debounce and shows the title or a preview. Bookmarks appear disabled, with the spec's explanation.
  - `#` filters `notesStore.allTags()` locally.
  - Picking an option removes the typed token and sets the scope.
- **Entry points:**
  - the note detail page gets a "Preguntar a la IA" button (disabled with a tooltip for bookmarks);
  - each tag chip on the detail page gets an "Preguntar sobre #tag" action;
  - when a tag filter is active, the notes list gets a "Preguntar sobre #tag" button next to it.
- **Answer display:** `partialContext` shows a small note under the answer: "La nota es larga: solo se ha usado el principio."

## Risks / Trade-offs

- [Global retrieval is still poor, so the difference between scoped and global answers may confuse users] → The chip makes the active scope explicit. Global quality is addressed by `fix-semantic-retrieval`, which is next in the queue.
- [Truncating long notes to the start can miss the relevant part] → The response flags `partialContext` and the UI says so. Chunk-level retrieval within a note arrives with `read-later-articles`.
- [Large tags: the similarity ranking inside a tag uses the same weak English-only model] → This only decides which notes fit when the tag exceeds the budget. It will improve automatically once the embedding model is replaced.
- [History tokens eat into the TPM] → The history is capped at 3 turns and 9,000 characters, and only for scoped conversations. A worst-case prompt stays around 5,000 to 6,000 tokens.
- [The localStorage format changes] → The migration of the legacy array to `global` runs on read. A store unit test covers it.

## Migration Plan

- No database changes.
- **Deployment order:** ai-service first (its new request fields are optional), then the .NET API (the new optional fields are passed through), then the frontend. Each step is backward compatible with the previous one.
- **Rollback:** redeploy the previous images in reverse order. The frontend's v2 storage is ignored by an older frontend, which reads a non-array value as an empty conversation. The global history is lost in that case, which is acceptable.

## Open Questions

- The exact value of `CONTEXT_BUDGET_CHARS` (12,000 by default) can be tuned after trying the user's usual model's TPM. It is configurable and does not change behaviour or tasks.
