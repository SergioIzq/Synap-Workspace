# Design

## Context

See proposal.md — Why. The constraints that shape the approach:

- `Note` today is `{ Id, UserId, Type, Title, Content, UpdatedAt, Metadata, Tags[] }`. It has no notion of work.
- `UpdateNoteCommand(title, content)` rewrites content and moves `UpdatedAt`. It is the only way a note changes.
- The briefing's three sections are three Dapper queries in `BriefingReadRepository`, each taking its total in the same round trip with `COUNT(*) OVER()`. The third one, `ListOpenThreadNotesAsync`, matches `BriefingLimits.StemmedMarkers` through the Spanish `search_vector` and `LiteralMarkers` (`TODO`) as a case-sensitive `LIKE`.
- Search filters are single-valued today: `SearchNotesQuery.Type` is a wire string validated against `Enum.GetNames<NoteType>()`, rejected with a Spanish message.
- The briefing is a Telegram message, not a report. `BriefingLimits.ItemsPerSection = 5` and every empty section disappears, deliberately (specs/briefing — "An empty section is left out").
- The frontend mirrors its filters in the URL via `NotesQuery` in `notes.store.ts`.

## Goals / Non-Goals

**Goals:**
- Make "this note is work I have open" a recorded fact rather than an inference over text.
- Keep status orthogonal to tags, to note type, and to reminders, so no existing briefing section changes meaning as a side effect.
- Keep the briefing a short message after gaining status sections.
- Let a user adopt status gradually: a vault where nothing is marked must behave exactly as it does today, minus the old heuristic.

**Non-Goals:**
- No workflow enforcement. Status is not a state machine; any status can follow any other (see Decision 3).
- No per-user configuration of statuses, their names, or the paused threshold.
- No status on anything but notes. Reminders keep `sent_at` and nothing else.
- No history of status changes beyond the moment of the last one.
- No backfill. Nothing can infer the status of an existing note (see Migration Plan).

## Decisions

### Decision 1: Status is nullable, and NULL means "not work"

`notes` gains a nullable status column. A note with no status is ordinary material — a bookmark, a snippet, a captured idea.

*Why not a non-null default of `Pending`:* the vault holds three note types and two of them (`CodeSnippet`, `Bookmark`) are almost never tasks. Defaulting everything to pending would put the whole vault in the briefing's pending section on the first morning, which is the same worthless-section failure the heuristic already had, arrived at from the other direction.

*Why not a tag:* a tag cannot be mutually exclusive (`#pendiente` + `#completado` is expressible), has no closed vocabulary (`#pend`, `#Pendiente`), and — decisively — a status expressed as a tag would remove the note from the briefing's "notas sin etiquetar" section. Two briefing sections would interfere through a shared mechanism. A column keeps them orthogonal.

*The consequence this forces:* NULL is now a meaningful, common value that filtering must handle deliberately rather than incidentally. See Decision 4.

### Decision 2: A note without a status is never hidden

This is a requirement, not an implementation detail, and the spec states it, because the obvious SQL gets it wrong:

```sql
-- WRONG: NULL <> 'Completed' is NULL, which WHERE discards.
WHERE n.user_id = @UserId AND n.status <> 'Completed'
-- RIGHT:
WHERE n.user_id = @UserId AND (n.status IS NULL OR n.status <> 'Completed')
```

The wrong version makes every unmarked note — most of the vault — vanish from the default notes list, and it passes a test asserting only that completed notes are hidden. Writing it as a requirement with its own scenario is what makes a later refactor fail loudly instead of silently emptying the list.

### Decision 3: Four statuses, no transitions enforced

`Pending`, `InProgress`, `Paused`, `Completed`, plus the absence of a status. Any status may follow any other, and a status may be cleared back to none.

*Why no state machine:* the value of the four statuses is in querying them, not in constraining their order. A user who completes something and then reopens it is doing something ordinary; rejecting it would be the tool arguing with the user about their own notes. Validation that forbids nothing is validation nobody has to debug.

*What is recorded instead:* the moment the status last changed. That single timestamp is what makes Decision 6 possible, and it is cheaper and more useful than a transition log.

### Decision 4: The status filter is multi-valued, and `none` is one of its values

```
?status=pending,inProgress        exactly those
?status=none                      only notes with no status — the library
?status=pending,inProgress,none   mixed, allowed, harmless
?status=completed                 the archive
absent                            pending, inProgress, paused AND none
                                  (completed is the only thing left out)
```

*Why multi-valued over two parameters (`status=<one>` + `includeCompleted=true`):* the alternative needs magic values or contradictory combinations (`status=completed&includeCompleted=false` — error, or empty?) that have to be specified and tested. Multi-valued has no mode that is not also a value. It also expresses "mis tareas" (pending + inProgress + paused) in one request, which is the chip the notes list wants, and "everything" by listing all four.

*Why `none` is in the same list rather than a separate flag:* "notes with no status" is a view a user actually asks for — it is the reference library. Making it a value keeps one parameter, one control in the UI, and one validation rule. It costs one reserved name, which cannot collide because the four statuses are a closed set.

*Why the default excludes only completed:* the default list is "what is live". Completed is the only status whose whole point is being done; paused is still work, and `none` is most of the vault.

*Cost, stated plainly:* this breaks the single-valued pattern `type` follows. `type` stays as it is — making it multi-valued is not in this change's scope — so the two filters are shaped differently for a while. That asymmetry is worth the absence of magic values.

### Decision 5: Status changes through its own endpoint, and does not move `UpdatedAt`

`PATCH /api/notes/{id}/status`, a command of its own, setting the status and the moment it changed. `UpdateNoteCommand` is untouched.

*Why not part of `PUT /notes/{id}`:* that command takes `(title, content)` and moves `UpdatedAt`. Routing status through it would mean marking a note completed makes it look edited today — which poisons the one signal that says how long something has been sitting untouched, the signal Decision 6 depends on. A full PUT is also the wrong shape for a button on a list card, which has no content to send.

*Why the two timestamps stay separate:* `UpdatedAt` answers "when did this note's text last change", the status timestamp answers "how long has it been in this state". Collapsing them loses both answers.

*Status at creation:* `CreateNoteCommand` accepts an optional status, for the same reason the spec already lets tags be given at creation — the alternative is capture-then-mark for the most common case. Omitted means no status, the existing behaviour.

### Decision 6: A note paused for more than 15 days rejoins the pending section

Paused notes are absent from the briefing while they are freshly paused. Once the status has stood unchanged for more than 15 days, the note appears in the pending section, marked with how long it has been paused.

*Why not silent forever:* the briefing exists so that "nothing they captured and forgot stays invisible" (specs/briefing — Purpose). A status that removes a note permanently turns pausing into a black hole, and the user would learn not to use it.

*Why not a section of its own:* a fifth section makes the briefing a report. One extra line inside a section that already exists costs nothing to read.

*Why it rejoins pending rather than in-progress:* a note nobody has touched in over two weeks is queued, not underway. Putting it in in-progress would make that section, which is meant to be the three things actually at hand, lie.

*Why 15 days is a constant and not in the spec:* it sits in `BriefingLimits` beside `UntaggedWindow = 7` and `ItemsPerSection = 5`. It decides how much the briefing shows, not what it promises, so it can move without touching specs/briefing — the same reasoning daily-briefing design.md Decision 4 used.

### Decision 7: The briefing gains two status sections and loses the heuristic

```
⏰ Recordatorios de hoy
🔨 En desarrollo (3)        status = InProgress
📋 Pendiente (12)           status = Pending, plus Paused older than 15 days
📌 Notas sin etiquetar
```

`ListOpenThreadNotesAsync`, `BriefingLimits.StemmedMarkers` and `BriefingLimits.LiteralMarkers` are deleted, not kept as a fallback.

*Why two sections instead of one "Hilos abiertos" filtered by status:* separating what is underway from what is queued is the whole of "a clearer briefing". In one mixed list of fifteen items the distinction is invisible, and it is the distinction that decides what the user does next.

*Why the heuristic is deleted rather than kept as a safety net for unmarked notes:* keeping it means two competing definitions of the same section, both wrong in their own way, and a user who cannot tell why a note appears. It also means the heuristic's false positives never go away. Deleting it makes the sections trustworthy at the cost of starting empty — see Migration Plan and Risks.

*Why in-progress comes first:* it is the shorter section and the more urgent one. Pending stays capped at `ItemsPerSection` and states its total, so a queue of two hundred is a number, not a wall.

*Why the two new sections obey the existing rules:* each disappears when empty and states its total when capped, exactly as the three current sections do. Nothing in specs/briefing's structural promises changes — only what the third section is made of.

### Decision 8: The Spanish wire names mirror `NoteType`

The statuses serialize as `pending`, `inProgress`, `paused`, `completed` through a converter mirroring `NoteTypeJsonConverter`, with input matched case-insensitively. Validation rejects anything else with a Spanish message, as `SearchNotesQueryHandler.InvalidType` already does.

*Why camelCase wire names and not Spanish ones:* the API is already English on the wire and Spanish in its messages (`NoteType` is `text`/`codeSnippet`/`bookmark` while its errors are Spanish). Mixing a Spanish enum into that is a new inconsistency for no gain. The user-visible labels are Spanish in the frontend, where every other label lives.

*Why case-insensitive input:* the same reason `NoteTypeJsonConverter` is — an exact-match enum breaks clients sending `Pending` instead of `pending`, which is the mistake the iOS Shortcut already made once.

## Risks / Trade-offs

- **The briefing gets thinner the day this ships, and looks broken** → Accepted and unavoidable: no backfill can infer a status (Migration Plan). Mitigated by making marking a one-click action from the notes list, so a vault becomes useful in one pass rather than note by note through the detail page.
- **Users never mark anything, and the briefing permanently loses a section it used to have** → The real failure mode of this change. The honest mitigation is that "notas sin etiquetar" and today's reminders still carry the briefing, and that status earns its place through the notes list — where filtering by status is useful on its own, independently of the briefing.
- **`status <> 'Completed'` silently hiding every unmarked note** → Decision 2, promoted to a spec requirement with its own scenario precisely so that a test, not a user, finds it.
- **Status drifts out of date and becomes a third thing to maintain** → Partly mitigated by Decision 6: a stale `Paused` resurfaces. Nothing resurfaces a stale `InProgress`, which is a deliberate gap — the briefing shows in-progress notes every day, so staleness there is already visible.
- **Two filters shaped differently (`type` single-valued, `status` multi-valued)** → Accepted, Decision 4. Making `type` multi-valued is a separate change and does not belong in this one.
- **`none` becomes a reserved word in the status parameter** → Safe because the statuses are a closed enum; a future status named `none` is not a thing. The validation message names the accepted values, so a typo is a clear error rather than an empty result.

## Migration Plan

1. Two additive nullable columns on `notes`: the status and the moment it last changed. No backfill, no default. Absent means "not work", which is the specified default.
2. Deploy backend and frontend together: the status filter and the badge are useless apart, and the briefing's new sections are empty either way until notes are marked.
3. Delete the marker constants and `ListOpenThreadNotesAsync` in the same change. Leaving them behind unused invites a later "fallback" that reintroduces two definitions of the same section.

**Rollback:** the columns are additive and nothing else reads them, so reverting the code leaves them orphaned and harmless. The briefing returns to its old shape only if the heuristic's deletion is also reverted — which is the one irreversible-feeling part of this change, and the reason it is marked BREAKING in the proposal rather than treated as an internal swap. Any status a user had already set survives a rollback untouched.

## Open Questions

- Whether a long-paused note should also be surfaced in the web notes list, or only in the briefing. Deferred because it adds a view, not a rule: the status and its timestamp are already recorded, so answering it later changes no spec requirement, no data, and no task already listed here.
