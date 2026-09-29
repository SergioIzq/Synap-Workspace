# Tasks

## 1. Domain

- [x] 1.1 Add `ReminderId` to `Synap.Shared.Domain/ValueObjects/Ids/` following `MemoryEntryId`, and verify it compiles with `dotnet build Synap-Backend/Synap.slnx`
- [x] 1.2 Add `Recurrence` to `Synap.Domain/Reminders/` parsing and rendering the strings `daily`, `weekly:<0-6>` (0 = Monday) and `monthly:<1-28>`, exposing `NextAfter(DateTime utc, string timezone)` that keeps the same local time of day; verify with unit tests in `Synap.UnitTests/Domain` covering each form, a month-end rollover, a DST boundary, and rejection of `weekly:7`, `monthly:29` and free text
- [x] 1.3 Add the `Reminder` aggregate to `Synap.Domain/Reminders/Reminder.cs` following `MemoryEntry`: `Create(userId, text, dueAtUtc, noteId?, recurrence?)` validating non-empty text, `MaxTextLength = 500` and a future `dueAtUtc`, with `Error` statics carrying the Spanish messages; verify with unit tests covering empty text, 501 characters, a past `dueAtUtc` and a valid creation
- [x] 1.4 Add `Reminder` behaviour for the delivery lifecycle — `MarkSent(nowUtc)`, `Confirm(nowUtc, timezone)` (one-off: stays dismissed; recurring: advances `DueAt` via `Recurrence.NextAfter` and clears `SentAt`/`DismissedAt`), `Snooze(untilUtc)` clearing `SentAt`/`DismissedAt` and keeping `Recurrence`, `CancelSeries()`, and `Edit(text, dueAtUtc, recurrence)` reusing the creation validation; verify with unit tests that a confirmed one-off is never pending again, a confirmed daily reminder advances one day, and a snoozed daily reminder is still daily
- [x] 1.5 Add `IReminderWriteRepository` / `IReminderReadRepository` to `Synap.Domain/Reminders/IReminderRepositories.cs` following `IMemoryEntryRepositories`, with `GetOwnedByUserAsync`, `ListPendingByUserAsync`, `ListByNoteAsync` and `ListDueAsync(nowUtc, limit)`, plus a `ReminderSummary` record; verify it compiles
- [x] 1.6 Add `Timezone`, `TelegramChatId` and the Telegram link token to `Synap.Domain/Users/User.cs` — `SetTimezone(string?)` validating an IANA id, `StartTelegramLink(token, expiresAtUtc)` / `HasValidTelegramLink(nowUtc)` / `CompleteTelegramLink(chatId)` / `ClearTelegramLink()` following the existing password-reset methods, and `HasTelegram`; verify with unit tests covering a valid link, an expired one and a rejected timezone

## 2. Persistence

- [x] 2.1 Add `ReminderConfiguration` to `Synap.Infrastructure/Persistence/Command/Configurations/` mapping the `reminders` table per design.md Decision 7 (cascade on `user_id`, `ON DELETE SET NULL` on `note_id`, index on `user_id`, filtered index on `due_at WHERE sent_at IS NULL`), register the `DbSet`, and verify `dotnet ef migrations list` still resolves the context
- [x] 2.2 Add the `telegram_chat_id`, `telegram_link_token`, `telegram_link_token_expires` and `timezone` columns to `UserConfiguration`, and verify the model snapshot builds
- [x] 2.3 Create the EF Core migration for the `reminders` table and the new `users` columns, and verify it applies to a clean database with `dotnet ef database update`
- [x] 2.4 Implement `ReminderWriteRepository` and `ReminderReadRepository` in `Synap.Infrastructure/Persistence/Data/Reminders/`, register both in `AddInfrastructure`, and verify with an integration test that a reminder round-trips and that `ListDueAsync` returns only rows with `due_at <= now` and `sent_at IS NULL`
- [x] 2.5 Verify with an integration test that deleting a note sets its reminders' `note_id` to NULL while keeping them pending, and that deleting a user removes their reminders

## 3. Reminder use cases

- [x] 3.1 Add `CreateReminderCommand` (text, due-at UTC, optional note id, optional recurrence) to `Synap.Application/Features/Reminders/Commands/`, rejecting a note that does not belong to the caller as not found; verify with unit tests in `Synap.UnitTests/Features/Reminders` covering success, invalid input and another user's note
- [x] 3.2 Add `UpdateReminderCommand` and `CancelReminderCommand`, both treating a reminder that is missing or owned by someone else as not found; verify with unit tests covering a valid edit, a past due-at rejection and a foreign reminder
- [x] 3.3 Add `ListRemindersQuery` (the caller's pending reminders, soonest first, each with its recurrence and linked note title) and `ListNoteRemindersQuery`; verify with unit tests covering ordering and that only the caller's reminders are returned
- [x] 3.4 Add `SetUserTimezoneCommand` (or fold it into the existing assistant/reminder paths) storing the last `timezone` the frontend sent on `users.timezone`; verify with a unit test that a valid id is stored and an invalid one leaves the column unchanged

## 4. Telegram account linking

- [x] 4.1 Add `TelegramSettings` (`Enabled`, `BotToken`, `WebhookSecret`, `BotUsername`) to `Synap.Application/Features/Reminders/` following `AppOptions` (not Infrastructure as first planned: Infrastructure references Application, and both the link command and the sender need it), bind it in `AddInfrastructure`, and verify the API starts with the section absent and `Enabled` defaulting to false
- [x] 4.2 Add `StartTelegramLinkCommand` issuing a 32-byte hex single-use token with a 15-minute TTL and returning it with the bot username, plus `GetTelegramStatusQuery` reporting whether a chat is linked; verify with unit tests that a second request replaces the first token and that the token is returned only once
- [x] 4.3 Add `CompleteTelegramLinkCommand` taking a token and a chat id: on a valid, unexpired token it stores the chat id and clears the token; on an unknown, expired or used token it changes nothing and reports a generic failure that reveals no user; verify with unit tests for each of the four outcomes
- [x] 4.4 Add `DisconnectTelegramCommand` clearing `telegram_chat_id` and any outstanding link token, leaving the user's reminders pending; verify with unit tests that the user then has no linked chat, that their pending reminders are untouched, and that connecting again requires a freshly issued code

## 5. Telegram delivery

- [x] 5.1 Add `ITelegramSender` to `Synap.Shared.Application/Interfaces/` with a method to send a message with an optional inline keyboard and one to edit a sent message's text, and verify it compiles
- [x] 5.2 Implement `TelegramSender` over a typed `HttpClient` against the Bot API, a no-op when `Telegram:Enabled` is false and when the environment has no public webhook (design.md Risks — inline buttons off in local development), registered in `AddInfrastructure`; verify with unit tests over a fake `HttpMessageHandler` that a disabled sender makes no request and that an API error surfaces as a failure rather than an exception
- [x] 5.3 Add `ReminderMessage` building the delivered text (reminder text, and a link to the note when `note_id` is set, using the configured app base URL) and the inline keyboard per type — one-off: confirm plus the three snooze options; recurring: confirm-this-time, the three snooze options and cancel-series — with `callback_data` carrying the action, the reminder id and the delivered occurrence's `due_at` (design.md Decision 2, stale callbacks); verify with unit tests on both keyboards and on a reminder with and without a note
- [x] 5.4 Add `ReminderDeliveryService` in `Synap.Application/Features/Reminders/` that takes the reminders due at a moment, sends each through `ITelegramSender`, marks the sent ones, leaves a failed one pending and logs the reason, and skips users with no linked chat; verify with unit tests that one failure does not stop the rest and that a failed reminder is retried on a second run
- [x] 5.5 Add `ReminderPollerHostedService` in `Synap.Infrastructure/BackgroundJobs/` waking every minute, resolving a scope, calling `ReminderDeliveryService` with a 5-second gap between sends, and doing nothing when `Telegram:Enabled` is false; register it in `AddInfrastructure` and verify with an integration test that a reminder due in the past is delivered on the next tick and one due in the future is not

## 6. Telegram webhook

- [x] 6.1 Add `POST /api/telegram/webhook` to a new `TelegramController`, anonymous but rejecting any request whose secret header does not match `Telegram:WebhookSecret`, always answering 200 so Telegram does not retry; verify with an integration test that a wrong secret is rejected and a valid empty update is accepted
- [x] 6.2 Handle `/start <token>` updates in the webhook by running `CompleteTelegramLinkCommand` with the update's chat id and replying in the chat — a confirmation on success, an "expired or invalid code" message otherwise; verify with an integration test that the full link flow stores the chat id and that a bad token links nothing
- [x] 6.3 Handle inline-button callbacks: parse the action, reminder id and occurrence `due_at`; ignore the callback when the chat is not the one linked to the reminder's owner, when the reminder does not exist, or when the occurrence `due_at` no longer matches the row; otherwise run confirm, snooze or cancel-series and edit the message to show the outcome; verify with integration tests for confirm on a one-off, confirm on a recurring reminder, a double confirm changing nothing further, a snooze, a cancel-series, and a callback from an unlinked chat
- [x] 6.4 Resolve the two wall-clock snooze options (09:00 next day, 09:00 next week) against `users.timezone`, falling back to UTC when it is empty; verify with unit tests for a user in `Europe/Madrid` and a user with no stored timezone

## 7. Assistant tool

- [x] 7.1 Add the current date and time, and the user's timezone, to `AgentPrompt.System`, with the instruction to resolve relative moments to the nearest future match and to default a bare day to 09:00 local; verify with a unit test that the rendered prompt contains the moment and the timezone
- [x] 7.2 Add `timezone` to `AskAssistantQuery`, `AskRequest` and the ai-service call path, storing it on the user via the command from 3.4; verify with an integration test that a request without `timezone` still succeeds (older clients) and that a request with one stores it
- [x] 7.3 Add the `set_reminder` tool to `AgentTools` (text, `due_at` as an ISO 8601 UTC instant, optional `note_id`, optional `recurrence`) with a description that restricts it to explicit user requests; verify the tool schema parses in a unit test
- [x] 7.4 Implement `SetReminderAsync` in `AssistantAgent` dispatching through `CreateReminderCommand` like the other tools, returning the domain error text to the model on failure; verify with unit tests that a valid call creates a reminder and that a past `due_at` returns an error without creating one
- [x] 7.5 Add `ReminderCreated` to `AssistantActionType` and report the action with its resolved date, time and recurrence; verify with a unit test on the action's Spanish description and with an integration test in `AssistantAgentApiTests` that a "recuérdame…" question returns the action and creates the reminder

## 8. API endpoints

- [x] 8.1 Add `RemindersController` with list, create, update and cancel over the commands and queries from group 3, and a note-scoped list; verify with integration tests in a new `RemindersApiTests` covering each verb and its validation failures
- [x] 8.2 Add the Telegram endpoints to `SettingsController` — status, start link, disconnect — and verify with integration tests covering the status before linking, after linking and after disconnecting, that a due reminder is not delivered once disconnected, and that a callback from the formerly linked chat changes nothing
- [x] 8.3 Verify with an integration test in the style of `NoteIsolationTests` that one user cannot list, read, edit or cancel another user's reminders, nor link a reminder to another user's note

## 9. Frontend

- [x] 9.1 Add `reminder.model.ts` to `src/app/core/models/` and `reminder.service.ts` to `src/app/core/services/api/` covering the new endpoints; verify with the service's spec file that each call hits the expected URL
- [x] 9.2 Send the browser timezone (`Intl.DateTimeFormat().resolvedOptions().timeZone`) with every assistant question and every reminder creation from `assistant.service.ts` and `reminder.service.ts`; verify with updated service specs
- [x] 9.3 Add a `reminders` store and a "Recordatorios" page under `src/app/features/reminders/` listing pending reminders soonest first with their due moment in local time, recurrence and linked note, and supporting create, edit and cancel; verify with a spec covering the list rendering and the cancel flow
- [x] 9.4 Register the `reminders` route under the `app` shell in `app.routes.ts` and add its navigation entry to the shell; verify the page loads at `/app/reminders`
- [x] 9.5 Add a reminder selector (date, time, recurrence) usable from `note-detail.page.ts`, showing that note's existing reminders and allowing more than one; verify with a spec that a second reminder can be added to a note that already has one
- [x] 9.6 Add a "Conectar Telegram" block to the Settings page following `memory-settings.component.ts`: connection status, a button that requests the code, the `/start <code>` instructions with the bot username, and a disconnect action; verify with a spec covering the connected and disconnected states
- [x] 9.7 Warn in the "Recordatorios" page when the user has pending reminders and no linked Telegram chat, with a link to Settings; verify with a spec on that state
- [x] 9.8 Show the `reminderCreated` assistant action in the answer with its date and time, linking to the "Recordatorios" page; verify with an updated assistant page spec

## 10. Configuration and rollout

- [x] 10.1 Add the `Telegram` section to `appsettings.json` with `Enabled: false` and document `BotToken`, `WebhookSecret` and `BotUsername` as environment variables in the compose files and the backend README; verify the API starts with the variables unset
- [x] 10.2 Add a short runbook to `docs/` for registering the bot with BotFather, setting the webhook to the production endpoint with the secret header, and the local ngrok alternative; verify the document lists the exact commands
- [x] 10.3 Run `dotnet test` on the whole solution and the frontend test suite, and verify both pass
- [x] 10.4 Verify the rollout with `Telegram:Enabled = false` against the compose stack: reminders can be created, listed, edited and cancelled, a due reminder stays pending, no request reaches api.telegram.org and the webhook rejects every call
- [ ] 10.5 Verify delivery with `Telegram:Enabled = true` against a real bot: a due reminder arrives in the chat and its confirm, snooze and cancel-series buttons behave as specified (needs a BotFather token and a public webhook - see `docs/telegram-bot-runbook.md`)
