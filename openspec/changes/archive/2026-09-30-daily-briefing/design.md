# Design

## Context

See `proposal.md` — Why. What shapes the approach is what already exists:

- **A sweep already runs every minute.** `ReminderPollerHostedService` ticks on a `PeriodicTimer`, queries the reminders that have fallen due and delivers them. It returns immediately without running at all when `TelegramSettings.IsConfigured` is false. Its state lives in the table, not in memory, so a tick missed while the API was down is recovered on the first tick after it starts.
- **Telegram delivery is settled.** `ITelegramSender.SendAsync` returns false rather than throwing for every failure — invalid chat, blocked bot, unreachable Telegram — and the caller decides what that means. `DueReminder` already proves the shape of the query the briefing needs: the rows to act on, joined to the owner's chat id and timezone, in one round trip instead of a user lookup per row.
- **Local time is already a solved problem.** `UserClock` converts between a user's wall clock and UTC, including the hour that does not exist on a spring-forward and the one that happens twice in autumn. `users.timezone` is whatever the browser last sent, and may be absent or retired by a tzdata update, which `UserClock` resolves as UTC rather than throwing.
- **Notes have no notion of being reviewed.** `notes` has `id`, `user_id`, `note_type`, `title`, `content`, `created_at`, `updated_at`, link metadata and a generated `search_vector`. Tags hang off `note_tags`/`tags`. There is no "reviewed" flag and this change does not add one.
- **The generation provider is the user's own.** Keys are BYOK on a free tier, and a user may have no key at all. Nothing that runs unattended, every day, for every user, can depend on one.

## Goals / Non-Goals

**Goals:**

- A briefing states only things that are true of the user's data at the moment it was built.
- It arrives on the user's own clock, once a day, and cannot arrive twice.
- It is verifiable without a model, a network or a clock that moves.
- It costs the user nothing and works for a user with no Groq key.

**Non-Goals:**

- Prose, summarising, ranking or advice. The briefing lists; it does not interpret.
- Email, web push, or a second channel of any kind.
- Progress on what the user is studying (proposal.md — What Changes).
- A "reviewed" state on notes, or any other new concept in `knowledge-vault`.
- A general scheduler. This change adds one periodic job, not a job framework.

## Decisions

### Decision 1: The briefing is computed, never generated

The three sections are three queries and a fixed template. No request to the AI service, no tool loop, no model.

*Why:* a briefing is an unprompted daily claim about the state of the user's own notes — the one place where a wrong sentence is least likely to be checked, because the user did not ask the question and has nothing to compare the answer against. `observable-failures` has just finished establishing that the system cannot present a model's prose as fact; sending that prose every morning, unread by anyone until it is wrong, would reintroduce the same failure on a schedule. Determinism also makes the whole feature testable with a fixed clock and a fake sender, and makes it work for a user with no key, which the alternative cannot.

*What it costs:* the briefing cannot say "you left the pgvector migration half done" — only "this note contains «pendiente»". That is a real loss of polish and the reason the proposal originally reached for the model. It is accepted: a plain list that is always right beats a paragraph that is usually right.

*Alternative considered — deterministic data with a generated sentence on top:* the failure mode is better (it degrades to the deterministic briefing) but it still spends a Groq request per user per day, still needs a key, and still puts model text in front of the user unprompted. The data is the value here; the sentence is decoration.

### Decision 2: One more responsibility for the existing sweep, not a second scheduler

The briefing runs from a periodic job of its own, built the way `ReminderPollerHostedService` is built — `BackgroundService` + `PeriodicTimer`, state in the table — rather than inside the reminder poller's tick.

*Why a separate job rather than the same tick:* a briefing that throws must not stop reminders from being delivered, and the two have different cadences (a minute versus an hour). Sharing the tick couples the reliability of the feature nobody asked for to the feature people depend on.

*Why not a cron container, Hangfire or Quartz:* the same argument the reminder poller already made and that has held. The work is a query against a database that is already running, and the accuracy needed is "some time after the hour the user chose", not the second.

*Cadence:* every 15 minutes is enough — the promise is "at or after the chosen hour", not "at the stroke of it" — and it keeps the sweep cheap. The exact interval is a constant, not a promise of the spec.

### Decision 3: "Already briefed today" is a local date on the user, not a new table

`users` gains the date of the last local day a briefing was resolved for that user, alongside whether the briefing is on and the local hour it should arrive.

*Why a date and not a timestamp:* the question the sweep asks is "has this user been briefed on *their* today?", and a local date answers it directly across restarts, duplicate ticks and timezone changes. A UTC timestamp would need the comparison redone every time and would get the day wrong for users far from UTC.

*Why it is set for an empty day too:* a day with nothing to report is a resolved day (spec — "Nothing to report means nothing is sent"). Leaving it unresolved would make the sweep reconsider that user every 15 minutes until midnight, and would send a briefing at an arbitrary hour as soon as the user happened to create one note.

*Why it is not set when delivery fails:* the day is unresolved precisely so the next sweep tries again, which is what "attempted again while the local day lasts" means. The cost is that a user whose Telegram is broken is retried every 15 minutes until their midnight; bounded, silent to them, and recorded once rather than per sweep — the same treatment `reminders` gives a withheld delivery.

*Migration:* three additive columns on `users`, no backfill. Absent means off, which is the specified default.

### Decision 4: What each section asks the database

| Section | Question |
|---|---|
| Today's reminders | the user's pending reminders whose due instant falls inside their local day |
| Untagged notes | the user's notes created within a recent window that have no row in `note_tags` |
| Open threads | the user's notes whose text matches the open-thread markers |

The window for "recent", the marker words, and how many items a section shows before it falls back to a count are constants, not promises: the spec fixes that a section exists, is identifiable and is counted when truncated, not the numbers.

*On the markers:* the search vector over title and content already exists and is indexed, so matching a word like "pendiente" or "revisar" is a query the database is built for, and its stemming catches "pendientes" and "revisando" for free.

Not every marker survives it, though: the vector is built with the Spanish configuration, and **"todo" is a Spanish stopword**, so `to_tsvector('public.spanish_unaccent', 'TODO revisar')` yields `'revis'` and nothing else. The marker most likely to appear in a technical note is the one the index cannot see. Dropping it would quietly shrink what the section promises, so the query matches the stemmable markers through `search_vector` and the stopword ones literally, over the rows the user filter has already narrowed. At a personal vault's scale that literal pass is cheap; it is also the kind of detail that only shows up against a real database, which is why the section's tests run against one.

That literal match is **case sensitive**, and it has to be. "TODO" means something as a convention only in capitals; case-insensitively it is just the Spanish word *todo*, which turns up in "todo salió bien", "sobre todo" and "todo el día". Matching those would put most of a vault in the section and make it worth nothing — the failure mode that matters here is not missing a thread, it is a section so noisy the user stops reading it.

Either way the section will miss a thread phrased differently and will catch a note that merely mentions the word. That is stated plainly rather than engineered around: the section is a prompt to look, not a verdict, and the user sees the note title and can dismiss it in a glance. Anything better needs the model that Decision 1 rules out.

*On ordering and volume:* each section is capped and counted rather than paginated. A briefing is a message, not a report; a user with four hundred untagged notes needs the number, not four hundred lines.

### Decision 5: The message is built apart from the sending, like the reminder's

A pure function turns the three result sets plus the user's timezone into the message text, and the job sends it. Same split as `ReminderMessage`, for the same reason: every promise the spec makes about content — sections left out when empty, counts when truncated, a note identified by title or preview — is then testable without HTTP, without a clock and without Telegram.

*No buttons on the message itself.* A reminder's buttons exist because there is something to do to *that* reminder — confirm it, postpone it. A briefing is read and closed, and the one thing a user wants to do with it, ask for a fresh one, is not tied to the message that arrived: they want it on a day the automatic one had nothing to say, and before the hour on a day it has not run. That is why it is a request the user makes (Decision 7), not a button on a message that may not exist.

*Note identification* reuses the rule the assistant already applies — the title, or a short preview of the text when there is none — so a note looks the same in a briefing as it does in an answer's sources.

### Decision 6: Withheld and failed are recorded, and the user is told the part they can fix

A user with the briefing on and no linked chat is recorded once, not per sweep, and told in the web app where the setting is. A delivery that fails is recorded with the cause the sender actually reported.

This is `observable-failures` applied to a feature that runs unattended: a briefing that silently never arrives is indistinguishable from one that had nothing to say, and the user is the only person who can notice, so the web app has to carry that one message. Everything else belongs in the log.

### Decision 7: Asking for a briefing is a separate act from being sent one

The same briefing can be asked for at any moment, from the web app and with `/briefing` to the bot. Both land on one use case that builds the briefing for a user and sends it; the sweep of Decision 2 is then just the caller that runs it unattended.

*Why it does not touch the resolved day:* the date of Decision 3 exists to stop the system pestering the user twice in a morning. A briefing the user asked for is not pestering. Consuming the day would mean that asking at 07:00 silently cancels the 09:00 one — the user would have to learn that looking costs them the thing they subscribed to.

*Why it answers even when there is nothing:* the automatic briefing stays silent on an empty day (that is the whole of "Nothing to report means nothing is sent unasked"), but silence is only readable as "nothing to report" when the user did not ask. Someone who just pressed a button or typed a command and got nothing back is looking at a broken feature. So the on-demand path has one extra outcome the automatic one does not: a plain "nothing pending today".

*Why `/briefing` and not a button under the message:* `ProcessTelegramUpdateCommandHandler` already receives every message the bot gets, already resolves a chat id to a user, and already answers anything it does not understand. A command is a few lines there. A button would only exist on a message that was sent, which is exactly the day the user least needs it.

*Whether asking requires being subscribed:* it does not. Asking is a read of your own data; subscribing is consent to be messaged every morning. Tying them would mean the only way to see a briefing once is to start receiving them daily.

*What the bot answers an unknown chat:* the reply it already gives anything it does not act on. A chat that is not linked learns nothing about whether an account exists — the same silence `/start` with a bad code gives (specs/reminders "Unknown code").

## Risks / Trade-offs

- **The open-thread markers are wrong in both directions** → Accepted and stated in the message's framing rather than hidden. Mitigated by the section being a list of note titles the user can dismiss at a glance, and by the marker list being a constant that can change without touching the spec.
- **A daily message people stop reading** → The main reason empty briefings are not sent, and the reason each section disappears when it has nothing in it. The briefing is off until asked for, and off again in one click.
- **Sweeping every user every 15 minutes** → The query is filtered to users with the briefing on and the day unresolved, which is a small set on a personal deployment, and no work at all for a deployment where nobody has turned it on. If it ever stops being small, the filter is where the index goes.
- **A user who changes timezone mid-day** → They may be briefed twice across the change, or not at all that day, depending on the direction. Bounded to one day, self-correcting the next, and not worth carrying a second column to avoid.
- **The clock a user chose is stored as an hour, not a minute** → Deliberate. The sweep's own cadence makes any finer promise a lie.
- **`/briefing` is an unauthenticated path that sends the user their own data** → It acts only on the chat id Telegram itself vouched for, which is the same trust the reminder buttons already run on, and it sends to that chat and no other. A chat that is not linked to an account gets the bot's ordinary "I do not know you" reply.
- **On demand makes the feature spammable by its owner** → Bounded to the person's own chat and their own data, and it costs three indexed queries. Not rate-limited in this change; if it ever matters, the limiter goes where the webhook's rejection recorder already is.
- **Three more columns on `users`** → Additive and nullable; an older deployment reads the table unchanged. The alternative, a `briefing_settings` table, buys nothing at one row per user.

## Migration Plan

1. The columns ship first, defaulted to off. Nobody is briefed and nothing changes.
2. The queries and the message builder ship next, verifiable entirely in tests — no scheduler, no Telegram.
3. The job ships last, which is the point at which anything can actually be sent. Turning it on for one user on the deployment is the end-to-end check.

Rollback is turning the setting off, or reverting the deployment; the columns are additive and a previous version reads the table unchanged.

## Open Questions

- **Whether the briefing should eventually carry the day's calendar**, once `calendar-integration` exists. It is the obvious fourth section and deliberately not designed for here.
- **Whether "recent" for untagged notes should be a window or simply every untagged note**, once there is a real corpus to look at. It changes a constant, not the spec.
