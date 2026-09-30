# Tasks

Order follows design.md — Migration Plan: the columns first (nobody is briefed), then the content
and the message (verifiable without a scheduler or Telegram), and the job last, which is the point
at which anything can be sent.

## 1. The setting, off by default

- [x] 1.1 Add the briefing's three fields to the `User` aggregate — on/off, the local hour, and the last local date a briefing was resolved for — with the behaviour that turning it on requires an hour and that absent means off; verify unit tests in `Synap.UnitTests` cover the default of `specs/briefing` "Off by default" and that an invalid hour is refused
- [x] 1.2 Add the additive EF migration for the three columns on `users`, nullable with no backfill, and apply it; verify `docker compose exec postgres psql -c "\d users"` shows them and the existing rows are untouched
- [x] 1.3 Add the command that turns the briefing on or off and sets the hour, through the same use-case path as the other settings; verify a unit test asserts that it changes only the requesting user's row, covering `specs/briefing` "One user's setting is not another's"
- [x] 1.4 Return the briefing's state from `GetSettingsQuery` and expose both on `SettingsController`; verify an integration test in `Synap.IntegrationTests` asserts the state round-trips and that another user's settings are never reachable

## 2. What the briefing is made of

- [x] 2.1 Add the query for the reminders falling due inside a user's local day, resolving the day's bounds with `UserClock` so a user far from UTC gets their own day; verify unit tests cover a user in `Europe/Madrid` at either end of the day and a user with no timezone falling back to UTC
- [x] 2.2 Add the query for the user's recently created notes with no row in `note_tags`; verify an integration test against the real database asserts a tagged note is excluded, an untagged one included, and another user's notes never appear
- [x] 2.3 Add the query for the user's notes whose text matches the open-thread markers, over the existing `search_vector`; verify an integration test asserts a note containing «pendiente» is found, one without it is not, and the match never crosses users
- [x] 2.4 Assemble the three into one per-user result with its counts, capped per section as design.md Decision 4 describes; verify a test asserts the total count is reported even when the items shown are capped

## 3. The message

- [x] 3.1 Add the pure builder that turns the assembled result and the user's timezone into the message text, identifying a note by its title or a preview of its text as `AssistantAgent.NoteLabel` already does, and stating each reminder's local due time; verify unit tests cover the scenarios of `specs/briefing` "What a briefing contains", with a fixed clock and no Telegram
- [x] 3.2 Leave a section out entirely when it is empty, and report "nothing to report" as a distinct outcome rather than an empty message; verify tests assert an empty section produces no heading and that an all-empty result is not a message at all, covering "An empty section is left out" and "Empty day"
- [x] 3.3 Say how many items a truncated section stands for; verify a test asserts the count of a section with more items than are shown

## 4. Sending, once a day, on the user's clock

- [x] 4.1 Add the query that lists the users a sweep has to consider — briefing on, the local day unresolved, the chosen hour already past in their timezone — with their chat id and timezone in the same row, the way `ListDueAsync` does for reminders; verify unit tests cover before the hour, after the hour, and a day already resolved, for `specs/briefing` "Sent at the chosen hour" and "Before the chosen hour"
- [x] 4.2 Add the service that, for each of those users, builds the briefing, sends it through `ITelegramSender` and records the local day as resolved; verify a test asserts one send for a user swept twice in the same local day, covering "Not sent twice in a day"
- [x] 4.3 Resolve the day without sending when there is nothing to report; verify a test asserts no message is sent, the day is recorded, and items created later that day do not produce a second briefing ("Items appear later the same day")
- [x] 4.4 Leave the day unresolved when sending fails, record the failure with the cause the sender reported, and let one user's failure not stop the others; verify tests cover "Delivery fails" and "One failure does not stop the rest"
- [x] 4.5 Record once — not per sweep — that a user with the briefing on has no linked Telegram chat, reusing the recorder written for withheld reminders; verify a test asserts one record across two consecutive sweeps, covering "Briefing on, Telegram not connected"
- [x] 4.6 Add the hosted service that sweeps on its own timer, does not run at all when Telegram delivery is turned off for the deployment, and survives a tick that throws; verify a test asserts a failing tick does not end the service, and that nothing is sent or recorded with delivery off ("Delivery turned off for the deployment")
- [x] 4.7 Verify the missed-hour and stale-day behaviour end to end with a controllable clock: a sweep that first runs after the hour on the same local day sends the briefing, and one that first runs the next day does not send yesterday's — `specs/briefing` "The system was down at the hour" and "The day is over"
- [x] 4.8 Verify that two users in different timezones with the same chosen hour are each briefed on their own clock, not at the same instant ("Each user on their own clock")

## 5. Asking for a briefing

- [x] 5.1 Extract building-and-sending one user's briefing into a use case both callers share, so the sweep of group 4 and the on-demand paths cannot drift apart; verify the sweep's tests still pass against it unchanged
- [x] 5.2 Make the on-demand path answer when there is nothing to report, instead of staying silent as the automatic one does, and leave the resolved day untouched; verify tests cover `specs/briefing` "Asked for with nothing to report" and "Asking does not consume the day"
- [x] 5.3 Add the endpoint that asks for the user's own briefing now, refusing with the connect-Telegram message when they have no linked chat; verify an integration test covers "Asked for from the web app", "Asked for without a linked chat" and that it never reaches another user's data
- [x] 5.4 Add `/briefing` to `ProcessTelegramUpdateCommandHandler` next to `/start`, resolving the chat id to its user and answering an unlinked chat with the reply it already gives anything it does not act on; verify tests cover "Asked for from the bot" and "The bot is asked by an unknown chat"
- [x] 5.5 Verify that asking works for a user who never turned the briefing on, and that it starts no automatic ones ("Asked for before the briefing was ever turned on")

## 6. The web app

- [x] 6.1 Add the briefing section to the settings page — on/off, the hour, and what it will contain — alongside the Telegram and memory sections; verify a component spec asserts the control reflects the stored state and saves a change
- [x] 6.2 Tell a user who has the briefing on but no linked Telegram chat that it cannot arrive until they connect Telegram, next to the setting; verify a component spec asserts the warning appears only in that combination, covering the web app's half of "Briefing on, Telegram not connected"

## 7. Documentation

- [x] 7.1 Add the briefing to `docs/telegram-bot-runbook.md`: that it rides on the same bot and chat link, that `/briefing` is now a command the bot answers, and how to tell from the log that a sweep ran, sent, withheld or failed

## 8. Verification against the running system

- [x] 8.1 On the Compose stack with Telegram enabled: turn the briefing on for a user with a linked chat and an hour already past, and confirm one message arrives with the sections its data warrants, and that a second sweep sends nothing
- [x] 8.2 Confirm a user with the briefing on and no linked chat is not sent anything, is warned in the web app, and leaves exactly one record in `docker compose logs synap-api`
- [x] 8.3 Confirm a user with the briefing off is never considered, and that the reminder poller keeps delivering normally while the briefing sweep runs
- [x] 8.4 Confirm on the running stack that the button in Settings and `/briefing` to the bot both deliver the same briefing, that asking before the chosen hour still leaves the automatic one arriving, and that a day with nothing to report answers instead of staying quiet
- [x] 8.5 Run the full unit and integration suites and confirm no regressions
