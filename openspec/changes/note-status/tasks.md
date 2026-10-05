# Tasks

Ordered so the vault is usable before the briefing changes: groups 1–5 deliver status and its filtering, group 6 swaps the briefing over, group 7 is the UI, group 8 the final check. The design's one Open Question (whether a long-paused note is surfaced in the web list too) does not affect any task below.

## 1. Domain

- [x] 1.1 Add `NoteStatus` (`Pending`, `InProgress`, `Paused`, `Completed`) in `Synap.Domain/Notes/NoteStatus.cs` with a `NoteStatusJsonConverter` mirroring `NoteTypeJsonConverter` — wire names `pending`/`inProgress`/`paused`/`completed`, input case-insensitive (design Decision 8); verify unit tests cover each name round-tripping and `"PENDING"` being accepted
- [x] 1.2 Add `Status` (nullable) and `StatusChangedAt` (nullable) to `Note` with a `SetStatus(NoteStatus?)` that records the moment and accepts any status from any other, including null (design Decisions 1 and 3); verify unit tests cover setting, replacing, clearing, and completed → in progress being accepted
- [x] 1.3 Make `Note.Create` accept an optional status, setting `StatusChangedAt` to the creation time when one is given (specs/knowledge-vault "Create a note with a status"); verify a unit test shows a note created with no status has neither status nor `StatusChangedAt`
- [x] 1.4 Confirm `Note.UpdateContent` leaves `Status` and `StatusChangedAt` untouched; verify a unit test asserts both are unchanged after an edit (specs/knowledge-vault "Editing content leaves the status alone")

## 2. Persistence

- [x] 2.1 Map the two new columns in `NoteConfiguration` (status stored by name, both nullable); verify `dotnet ef migrations add AddNoteStatus` produces exactly two additive nullable columns with no default and no backfill (design Migration Plan step 1)
- [x] 2.2 Apply the migration against the dev database and verify existing notes come back with a null status and remain fully usable
- [x] 2.3 Add `Status` to `NoteSearchResult` and have `NoteReadRepository` return it; verify an integration test in `NoteSearchTests` shows a marked note reporting its status and an unmarked one reporting none (specs/knowledge-vault "Status in search results")

## 3. Status filtering in search

- [x] 3.1 Add the status filter to `NoteSearchCriteria` as a set of statuses plus a flag for "no status", with a factory turning the wire values (including `none`) into it and rejecting anything else (design Decision 4)
- [x] 3.2 Implement the filter in `NoteReadRepository.SearchAsync`, writing the default branch as `(n.status IS NULL OR n.status <> 'Completed')` — **never** a bare `<>` (design Decision 2); verify an integration test lists notes with no status filter and asserts every unmarked note is returned
- [x] 3.3 Add `Status` to `SearchNotesQuery` as a comma-separated wire string and parse it in `SearchNotesQueryHandler`, with an `InvalidStatus` Spanish error naming the accepted values, following the existing `InvalidType` pattern; verify `SearchNotesQueryHandlerTests` covers one status, several, `none`, mixed, an unknown value, and an empty filter
- [x] 3.4 Expose the status parameter on `GET /api/notes/search` in `NotesController`; verify integration tests cover the default (completed excluded, unmarked included), `status=completed`, `status=none`, `status=pending,inProgress`, and all four plus `none` returning everything
- [x] 3.5 Verify an integration test combines the status filter with a search term, a tag and a type, and that `NoteIsolationTests` gains a case showing the status filter never crosses users

## 4. Changing a note's status

- [x] 4.1 Add `SetNoteStatusCommand`/`Handler` under `Features/Notes/Commands/SetStatus` that loads the caller's own note, calls `SetStatus`, and returns the not-found error for a note of another user; verify unit tests cover success, an unknown status, and another user's note
- [x] 4.2 Add `PATCH /api/notes/{id}/status` to `NotesController` accepting a status or null (design Decision 5); verify an integration test marks a note, clears it, and gets 404 for another user's note
- [x] 4.3 Verify an integration test asserts a status change leaves `Title`, `Content` and `UpdatedAt` untouched, and that an `UpdateNote` call leaves `Status` and `StatusChangedAt` untouched — the two halves of specs/knowledge-vault "Changing a status is not editing the note"

## 5. Status at capture

- [x] 5.1 Add an optional status to `CreateNoteCommand` and its handler, validated with the same Spanish error, rejecting the whole note (and any tag) when invalid; verify unit tests cover a valid status, none given, and an invalid one creating nothing
- [x] 5.2 Accept the status on the create endpoint in `NotesController`; verify an integration test creates a note with a status in one request and reads it back. Leave `QuickCaptureCommand` alone — a share-sheet capture has no status to give

## 6. Briefing

- [x] 6.1 Add `PausedResurfaceAfter = TimeSpan.FromDays(15)` to `BriefingLimits` and delete `StemmedMarkers` and `LiteralMarkers` (design Decisions 6 and 7)
- [x] 6.2 Replace `ListOpenThreadNotesAsync` in `IBriefingReadRepository`/`BriefingReadRepository` with `ListInProgressNotesAsync` and `ListPendingNotesAsync`, the latter also returning notes paused longer than the threshold together with how long they have been paused, each keeping the `COUNT(*) OVER()` total; verify `BriefingQueriesTests` covers both sections, a recently paused note being absent, a long-paused one appearing among pending, an unmarked note with `TODO` in its text appearing in neither, and a completed note appearing in neither
- [x] 6.3 Replace `OpenThreads` in `BriefingContent` with `InProgress` and `Pending` sections, carrying how long a resurfaced note has been paused, and update `IsEmpty`; verify the unit tests build a content with only pending notes and show it is not empty
- [x] 6.4 Update `BriefingContentService` to call the two new queries; verify `BriefingContentServiceTests` no longer references the markers and covers a user who has marked nothing
- [x] 6.5 Update `BriefingMessage`: sections `🔨 En desarrollo` then `📋 Pendiente` in place of `🔎 Hilos abiertos`, in-progress first, each still vanishing when empty and stating its total when capped, and a resurfaced note annotated with how long it has been paused; verify `BriefingMessageTests` covers both sections, their order, a resurfaced note's annotation, and the `NothingToReport` text updated to stop promising "hilos abiertos"
- [x] 6.6 Verify `BriefingSweepTests` and `BriefingOnDemandApiTests` still pass, and that a user whose notes carry no status gets a briefing with neither status section rather than an error or an empty heading

## 7. Frontend

- [x] 7.1 Add `NoteStatus`, `Note.status`, status on `CreateNoteRequest`, and the status filter on `NoteSearchParams` in `core/models/note.model.ts`; verify the project builds with `npm run build`
- [x] 7.2 Add the status endpoint and the search parameter to `core/services/api/note.service.ts`; verify its unit tests cover the PATCH call and the serialization of a multi-valued filter including `none`
- [x] 7.3 Add status to `NoteFilters`/`NotesQuery` in `notes.store.ts` with a `setStatus` action, and mirror it in the URL beside term/tag/type/page; verify a store test reloads a query with a status filter and gets the same state back
- [ ] 7.4 Show the status as a Spanish badge in `note-card.component.ts`, nothing at all when there is none, without displacing the type indicator or the age; verify by eye in the running app that all four statuses and an unmarked note render correctly on mobile and desktop widths
- [ ] 7.5 Let the user change and clear a note's status from the card, updating in place with a Spanish notification, and from `note-detail.page.ts`; verify in the running app that a change survives a page reload
- [ ] 7.6 Add the multi-select status filter to `notes-list.page.ts`, including the "sin estado" option and a shortcut selecting pending + in progress + paused; verify in the running app that the default view shows unmarked notes and hides completed ones, and that selecting completed shows them
- [x] 7.7 Add the optional status selector to `note-composer.component.ts`, unset by default; verify creating a note without touching it produces a note with no status

## 8. Verification

- [x] 8.1 Run `dotnet test` across `Synap.UnitTests` and `Synap.IntegrationTests` and verify everything passes, with no reference to the deleted markers left anywhere
- [x] 8.2 Run `openspec validate note-status --strict` and verify it reports the change as valid
- [ ] 8.3 In the running app, mark a handful of notes, request a briefing on demand, and verify it shows `🔨 En desarrollo` and `📋 Pendiente` with the right notes, no `🔎 Hilos abiertos`, and nothing reported for notes whose text merely contains "TODO"
