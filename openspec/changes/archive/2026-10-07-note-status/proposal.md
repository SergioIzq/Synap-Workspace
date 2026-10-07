# Proposal

## Why

The briefing's "Hilos abiertos" section guesses which notes have something left open by searching their text for `TODO`, `pendiente` and `revisar`. The daily-briefing design accepted this as a known risk ("the open-thread markers are wrong in both directions"), and it is wrong both ways in practice: a note saying "ya revisé esto, todo salió bien" is listed, while a note titled "Migrar auth a OAuth" never is. The user cannot correct either case, because there is nothing to correct — the signal is inferred, not recorded.

Giving a note an explicit status replaces the guess with a fact the user controls, and makes the briefing say what is actually in progress versus what is merely queued.

## What Changes

- A note MAY carry a status: pending, in progress, paused, or completed. A note without one is ordinary material (a bookmark, a snippet, an idea) and is never treated as work.
- A note's status can be changed on its own, without rewriting the note. Changing it does not count as editing the note's content.
- A note's status can be chosen when the note is created, the way tags already can.
- Searching and listing notes can be filtered by status, by several statuses at once, and by "has no status at all". With no status filter, completed notes are left out and everything else — including notes with no status — is shown.
- The notes list shows each note's status and lets the user change it from the list.
- **BREAKING** The briefing stops inferring open threads from note text. Its "Hilos abiertos" section is replaced by two sections driven by status: what is in progress, and what is pending. The text markers (`TODO`, `pendiente`, `revisar`) are removed entirely, with no backfill — no query can infer the status of an existing note. Until the user starts marking notes, those briefing sections are empty.
- A note left paused for a long time rejoins the pending section rather than disappearing for good, so pausing silences a note without losing it.

## Capabilities

### New Capabilities

None. Status is part of what a note is and of what a briefing reports, not a capability of its own.

### Modified Capabilities

- `knowledge-vault`: notes gain an optional status; it can be set at creation and changed on its own; search and listing gain status filtering, including "no status" and the rule that a note without a status is never hidden.
- `briefing`: "What a briefing contains" changes — the open-thread section defined by note text is replaced by status-driven in-progress and pending sections, plus the rule that a long-paused note resurfaces.
- `web-experience`: the notes list shows a note's status, lets the user change it in place, and lets the user filter by status including seeing completed notes.

## Impact

**Backend (Synap-Backend)**
- `Synap.Domain/Notes`: new `NoteStatus` enum and its JSON converter (mirroring `NoteType`/`NoteTypeJsonConverter`); `Note` gains `Status` and the moment it last changed.
- `Synap.Infrastructure/Persistence`: one additive nullable column plus the moment of its last change, no backfill; `NoteConfiguration` mapping; `NoteReadRepository.SearchAsync` gains status filtering — where a naive `status <> 'Completed'` would silently drop every note whose status is NULL.
- `Synap.Application/Features/Notes`: `NoteSearchCriteria` and `SearchNotesQuery` gain the status filter with validation and a Spanish error; a new command and handler for changing a note's status; `CreateNoteCommand` accepts an optional status.
- `Synap.Api/Controllers/NotesController`: new status endpoint; search gains the status parameter.
- `Synap.Application/Features/Briefing` and `Synap.Infrastructure/.../Briefing`: `ListOpenThreadNotesAsync` and the `StemmedMarkers`/`LiteralMarkers` constants are removed and replaced by status queries; `BriefingContent` and `BriefingMessage` change shape.
- Tests: `BriefingQueriesTests`, `BriefingContentService` tests and `BriefingMessage` tests cover the old markers and change with them; `NoteSearchTests` and `SearchNotesQueryHandlerTests` gain status cases.

**Frontend (Synap-Frontend)**
- `core/models/note.model.ts`: `NoteStatus`, `Note.status`, status on create and in `NoteSearchParams`.
- `features/notes/store/notes.store.ts`: status joins `NoteFilters` and the query mirrored in the URL.
- `notes-list.page.ts`, `note-card.component.ts`, `note-detail.page.ts`, `note-composer.component.ts`: status badge, in-place change, filter control, optional status at capture.
- `core/services/api/note.service.ts`: the status endpoint and the search parameter.

**Not affected**
- `reminders` stays as it is: a reminder is a time, a status is a state of work, and neither replaces the other.
- Tags are untouched. Status is deliberately not a tag, so that marking a note as pending does not remove it from the briefing's "notas sin etiquetar".
