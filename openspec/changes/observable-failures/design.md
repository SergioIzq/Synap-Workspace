# Design

## Context

See `proposal.md` — Why. What matters for the approach is where the current behaviour comes from:

- **The API's log is written by a shared package.** `builder.UseKernelSerilog("Synap")` (SergioIzq.AspNetCore.Kernel) sets a console *bootstrap* logger and then replaces it with an HTML-file logger from SergioIzq.Logging.HtmlFile. Its signature takes two strings and no options, so a console sink cannot be added through it. The HTML file lives inside the container with no volume behind it.
- **Failures are collapsed at the boundary.** `TelegramSender.CallAsync` and `AiServiceClient` each end in one broad `catch` that logs a single message and returns a failure value. On the Python side, `_raise_for_tool_error` maps any 400 whose message contains the substring `tool` to "the model does not support tools", discarding the provider's own text.
- **The agent trusts the model's prose.** `AssistantAgent.RunAsync` returns `result.Text` verbatim when a step produces no tool call. `run.Actions` — the list the web app renders as chips — is never compared against what the text asserts.
- **The models available are small.** Keys are the user's own (BYOK) on a free tier; the model in use is a 7B one. It calls `create_note` and `add_tags` reliably and does not call `set_reminder` — the one tool whose arguments must be *computed* (an ISO 8601 UTC instant derived from wording plus a timezone) rather than copied from what the user said.

## Goals / Non-Goals

**Goals:**

- Every failure is readable by whoever operates the deployment, with the platform's ordinary tooling.
- A recorded cause is the real one, and survives the classification that decides how to react.
- An answer cannot assert an action the system did not perform.
- Setting a reminder asks of the model only what a small model does well.

**Non-Goals:**

- Metrics, tracing, alerting or a log aggregator. This change makes the existing record truthful and reachable; it does not introduce observability infrastructure.
- Structured log schemas or correlation ids across services.
- Making the assistant work with *any* model. The guard makes a model's failure visible and honest; it does not make a weak model capable.
- Changing the deployment process. The manual VPS deploy and the per-container configuration drift that this session exposed are real, and out of scope (proposal.md — Impact).

## Decisions

### Decision 1: The kernel's logger is wrapped, not replaced, so the console sees what the HTML file sees

`Program.cs` keeps `UseKernelSerilog("Synap")` and then makes the logger it produced a sub-logger of a new root that also writes to the console.

*Why not rebuild the configuration in Synap* (the first choice here, changed during implementation): what the HTML file keeps is decided inside the package, and is not reachable through its public options. Composing `WriteTo.Console()` and `WriteTo.WriteToHtmlFile(…)` as siblings was measured to be wrong in both directions — the sink's filtering applies to the whole pipeline, so the console silently loses every Information record that is not database-related, while the file with hand-written options loses the Information records it keeps today. Wrapping leaves the file's behaviour byte-identical because it is the same pipeline, and the new root has no filter, so the console receives everything, through `Log` and through the injected `ILoggerFactory` alike.

*Why not extend the kernel package:* adding an overload to SergioIzq.AspNetCore.Kernel is the better long-term home — every project deployed in a container has this problem — but it means publishing a new package version and bumping it here before anything can be verified. Wrapping needs neither.

*Why keep the HTML file at all:* it is genuinely better for reading a past incident than scrollback, and nothing about it is wrong except being the *only* copy. The console sink makes it a convenience rather than a single point of failure.

*Why not a volume instead:* a volume for `/app/logs` preserves the file across recreations but still requires entering the host's filesystem to read it, and does nothing for anyone using `docker compose logs`. It is a reasonable addition, not a substitute.

### Decision 2: Boundary failures are recorded by outcome, not by one catch-all

Each outbound call distinguishes three outcomes, and records the evidence each one actually has:

| Outcome | Evidence recorded |
|---|---|
| The request was never formed | the exception type, and that nothing was sent |
| The request was sent and transport failed | the exception type and the destination |
| The destination answered and refused | the status code and the body it returned |

The first is the one that has never existed and is the reason this change exists: `NotSupportedException` from a malformed URI, an absent configuration value, a serialization failure. Today all three arrive as "could not be reached".

*Why not just log the exception type everywhere:* that alone would have solved this session's debugging, but it leaves the *message* the user sees still pointing at the wrong party. The outcome is what the message and the record are both derived from.

*On the Python side:* `_raise_for_tool_error` keeps the provider's message on the error it raises, and stops treating "any 400 mentioning tools" as proof the model cannot use tools. A 400 that is not recognisably about tool support falls through to the generic mapping instead of silently degrading the whole conversation to a question-answer exchange.

### Decision 3: The webhook records why it rejected, and answers exactly as before

The rejection reason (delivery off, or secret mismatch) is recorded; the HTTP response stays a bare 401. The asymmetry is the point: the caller learns nothing, the operator learns everything.

*Risk of a noisy public endpoint:* this endpoint is on the open internet and anything can post to it. Recording every rejection at `Warning` invites a flooded log. The rejection is therefore recorded at `Warning` for the misconfiguration cases that an operator needs to see (delivery off, secret mismatch) but rate-limited to one record per reason per minute, so a scanner cannot turn the log into a denial of service. Sampling loses nothing: the reason is a configuration state, identical on every call.

### Decision 4: The answer is checked against the actions performed, and a claim without an action is not delivered

At the end of a run, when `run.Actions` is empty and the model produced prose:

1. **Classify.** One extra generation request asks whether the answer claims to have created a note, added tags, saved a memory or set a reminder. It is a yes/no classification, not a rewrite.
2. **Retry once.** On yes, the loop runs one more step with the tools offered and an explicit instruction that the action has not happened yet.
3. **Neutralise.** If that step still performs no action, the claim is replaced by a fixed message — it could not be done, and where the user can do it by hand. Deterministic text, not the model's.

Both extra requests come out of the existing per-question budget (`specs/ai-assistant` "Bounded generation requests per question"), so a question cannot cost more than it does today.

*Alternatives considered:*

- **A verified tool-capable model list** (the pending spike 1.2). Rejected as a solution: the model in use *is* tool-capable — it calls two of the four tools. A list, however well verified, would have marked it capable and this failure would still have happened. Worth doing on its own merits; it does not address this.
- **Always forcing a tool call** (`tool_choice: "required"`). Rejected: most questions are questions. Forcing a call on "¿qué sé de Postgres?" produces a spurious action or a refusal. Forcing is right only once it is known that the turn asked for something, which is what step 1 establishes.
- **Matching the answer against patterns** ("listo", "he creado", "te recuerdo"). Rejected: brittle across phrasings and languages, and it fails in the direction that matters — a claim it does not match is delivered as true.
- **Relying on the action chips.** Status quo, rejected. The chips are additive: their absence says nothing to a user who has just read a sentence saying it is done.

*Cost acknowledged:* the classification is itself a model judgement, so it can be wrong. It is wrong in a bounded way — a false positive costs one retry and, at worst, replaces a truthful "listo" that performed no action; a false negative leaves today's behaviour. That is a strictly better distribution than the current one, where every claim is delivered unverified.

### Decision 5: `set_reminder` takes the user's wording; the system resolves the moment

The tool stops taking a computed `due_at` in ISO 8601 UTC and takes the moment as the user said it. Synap resolves that wording against the current instant in the user's timezone, with the rules that already existed (nearest future match, 09:00 when only a day is given, UTC when no timezone was supplied) now executed deterministically instead of by the model.

*Why:* it is the only tool whose arguments must be derived rather than echoed, and it is the only tool the model does not call. Timezone arithmetic — including the day that changes and the hour that does not exist on a DST switch — is work `UserClock` already does correctly and a 7B model does not. Moving it removes the reason to skip the tool and makes the result testable without a model in the loop.

*Consequence on the specs:* `ai-assistant` "Reminder moments resolved in the user's timezone" moves the resolution from the assistant to the system, and gains the case that did not exist before — wording the system cannot parse. That delta is written; the requirement's observable promises (nearest future match, 09:00 default, the answer stating the resolved moment) are unchanged.

*What this does not fix:* a model that does not call the tool for some other reason. That is Decision 4's job. Decision 5 makes the failure rarer; Decision 4 makes it honest when it happens.

*Alternative considered:* keeping `due_at` and adding examples to the tool description. Rejected: it makes the prompt longer without removing the arithmetic, and it is unfalsifiable — there is no way to know it worked short of trying each model.

### Decision 6: A reminder withheld for lack of a linked chat is recorded once

Recorded the first time a given reminder is passed over, not on every sweep. The existing code skips it silently precisely because a per-minute record would be useless; the fix is to record the event, not the condition.

## Risks / Trade-offs

- **Decision 4 adds model requests to a free tier** → Only on runs that end with zero actions and prose, which is rare; both requests fit inside the existing per-question cap, so the worst case is unchanged.
- **The classification misjudges an answer** → Bounded both ways (see Decision 4). A false positive costs a retry and a neutral message; a false negative is today's behaviour.
- **Decision 5 needs a parser for Spanish wording** → Natural-language date parsing is its own source of wrong answers. Mitigated by the requirement that unparseable wording creates nothing and asks the user, and by the answer always stating the resolved moment so the user can catch it. A moment resolved wrongly and stated plainly is recoverable; one resolved wrongly and silently is not.
- **Console logging changes what the deployment collects** → Log volume on the VPS grows. Mitigated by the existing level configuration; no new category of record is introduced except the rejections of Decision 3, which are rate-limited.
- **Decision 1 diverges from the kernel package** → Synap stops sharing the kernel's logging bootstrap, so a future kernel improvement does not reach it automatically. Accepted deliberately: the alternative is blocking this change on a package release.

## Migration Plan

1. Decisions 1, 2, 3 and 6 are records and messages only: no data, no API shape, no configuration changes. They can ship on their own and be verified by reading the log.
2. Decision 5 changes the tool's arguments. Nothing persisted changes — `reminders.due_at` is still a UTC instant — so there is no migration and no rollback beyond reverting the code.
3. Decision 4 ships last, once 1–3 make its behaviour observable. A run that reaches the neutralising branch should be visible in the log, otherwise the guard itself is unobservable, which is the failure this whole change exists to stop.

Rollback for any of them is reverting the deployment; no state is written that a previous version cannot read.

## Open Questions

- **Where the date parsing of Decision 5 comes from** — a small hand-written resolver for the wordings the assistant actually produces, or a library. It does not change the specs, the approach or the task breakdown; the requirement is the same either way.
- **Whether the kernel package gains a console-sink overload afterwards**, retiring Decision 1's local configuration. Independent of this change and of anything it specifies.
