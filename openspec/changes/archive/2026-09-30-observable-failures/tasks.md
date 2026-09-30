# Tasks

Order follows design.md — Migration Plan: the records come first, so the behaviour of group 5 is
observable when it ships.

## 1. The log reaches whoever operates the deployment

- [x] 1.1 Make the kernel's logger a sub-logger of a new root in `Synap.Api/Program.cs` that also writes to the console, keeping the current minimum level, so the HTML file's own filtering is untouched; verify `docker compose up -d --build synap-api && docker compose logs synap-api` shows the operational records that today only exist in `/app/logs/log<date>.html`
- [x] 1.2 Verify the HTML file is still written and still browsable after 1.1, by reading `/app/logs/log<date>.html` in the running container and confirming the same records appear in both sinks

## 2. A recorded failure names its own cause

- [x] 2.1 In `TelegramSender.CallAsync`, split the single `catch` into the three outcomes of design.md Decision 2 (request never formed / transport failed / destination refused), recording the exception type for the first two and the status plus body for the third; verify a unit test in `Synap.UnitTests/Services/Telegram/TelegramSenderTests.cs` asserts a malformed bot token is recorded as a request that was never sent and not as the provider being unreachable
- [x] 2.2 Apply the same three outcomes to `AiServiceClient` (`ListModelsAsync` and the other calls), so a failure reaching the AI service is distinguishable from the AI service refusing; verify unit tests assert a non-success response from the AI service is recorded with its status and body, and that neither it nor an unreachable service is reported as Groq failing
- [x] 2.3 Map the AI service outcomes onto `SettingsErrors` so the message the user sees no longer blames Groq for a failure that never reached it, adding the error for the AI-service case; verify the integration test for saving a Groq key covers the AI-service-unreachable scenario of `specs/user-settings`
- [x] 2.4 In `ai-service/app/llm/groq_provider.py`, make `_raise_for_tool_error` keep the provider's own message on the raised error and stop treating every 400 containing "tool" as proof the model cannot use tools; verify `ai-service/tests/test_groq_provider.py` covers a 400 that is not about tool support falling through to the generic mapping

## 3. Silent rejections leave a trace

- [x] 3.1 Record the webhook's rejection reason in `TelegramController` (delivery off vs secret mismatch), rate-limited to one record per reason per minute, leaving the 401 response byte-for-byte as it is; verify `Synap.IntegrationTests/TelegramWebhookApiTests.cs` asserts the response still reveals nothing and the reason is recorded
- [x] 3.2 Record once, in `ReminderDeliveryService`, that a due reminder was withheld for lack of a linked chat, without repeating it on later sweeps; verify a test asserts one record for a reminder passed over on two consecutive sweeps

## 4. The system resolves the reminder's moment

- [x] 4.1 Add a resolver that turns the wordings the assistant produces ("hoy a las 20:20", "el viernes", "mañana a las 8", "en dos semanas") into a UTC instant against a given timezone, reusing `UserClock` for the conversion, and reporting wording it cannot resolve; verify unit tests cover the scenarios of `specs/ai-assistant` "Reminder moments resolved in the user's timezone", including the day already passed this week and the DST cases `UserClock` already handles
- [x] 4.2 Change the `set_reminder` tool definition in `AgentTools` to take the moment as the user expressed it instead of `due_at` in ISO 8601 UTC, and update `AgentPrompt.Clock` so it no longer instructs the model to compute UTC; verify the tool's schema test reflects the new argument
- [x] 4.3 Resolve the wording in `AssistantAgent.SetReminderAsync` before `CreateReminderCommand`, returning to the model the resolved moment it must state, and creating nothing when the wording cannot be resolved; verify a test asserts that unresolvable wording creates no reminder and asks the user when
- [x] 4.4 Verify end to end that the answer still states the resolved date and time in the user's timezone, with a test covering a user in `Europe/Madrid` asking at 19:50 for "hoy a las 20:20" and getting 20:20 local, not 20:20 UTC

## 5. An answer cannot claim an action it did not perform

- [x] 5.1 Add the classification step of design.md Decision 4: when a run ends with no actions and prose, one request asks whether the answer claims a note, tags, a memory or a reminder; verify a unit test with a faked AI service asserts the classification is only requested when `run.Actions` is empty
- [x] 5.2 On a positive classification, run one more tool step instructing the model that the action has not happened yet; verify a test asserts the retry happens once and stays within the per-question request cap of `specs/ai-assistant` "Bounded generation requests per question"
- [x] 5.3 When the retry still performs no action, replace the claim with the fixed message saying it could not be done and where to do it by hand; verify a test asserts the model's claiming text never reaches the answer in that case
- [x] 5.4 Record when the neutralising branch is taken, so the guard is itself observable in the log; verify the record appears when the test of 5.3 runs against the running API
- [x] 5.5 Add the reminders to `ACTIONS_UNAVAILABLE_INSTRUCTIONS` in `ai-service/app/llm/groq_provider.py` for both the `model` and `scope` cases, which name only three of the four actions; verify `ai-service/tests` asserts both texts mention reminders

## 6. Documentation

- [x] 6.1 Correct step 3 of `docs/telegram-bot-runbook.md`, which tells the operator to look for the poller's line with `docker compose logs`; verify the corrected command is the one that actually prints it after task 1.1
- [x] 6.2 Note in the runbook how to tell the webhook's rejection reasons apart from the log, since the response deliberately does not say

## 7. Verification against the running system

- [x] 7.1 Verify on a deployment that a `/start` with a wrong secret leaves a record naming the mismatch while still answering 401, and that the record is visible with `docker compose logs synap-api`
- [x] 7.2 Verify that asking the assistant to be reminded of something at a given time creates the reminder with the expected moment and reports it as an action, with the model available on the deployment's Groq tier
- [x] 7.3 Verify that a model that does not perform the action results in an answer that says so, and not in a claim that it was done
- [x] 7.4 Run the full unit and integration suites and confirm no regressions
