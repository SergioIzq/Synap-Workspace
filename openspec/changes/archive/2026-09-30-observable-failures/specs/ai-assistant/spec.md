# Spec Delta

## ADDED Requirements

### Requirement: An answer never claims an action it did not perform
An answer SHALL NOT state that the assistant created a note, added tags, remembered a fact or set a reminder unless that action is among the ones actually performed and reported with the answer. When the assistant produces an answer claiming such an action while no corresponding action was performed, the system SHALL NOT present that claim to the user as it stands: it SHALL either obtain the action, or deliver an answer that does not assert it. This SHALL hold whatever the reason the action did not happen, including the model simply not requesting it.

#### Scenario: Model asserts an action it never requested
- **WHEN** the model answers that it has set a reminder, but requested no action while producing that answer
- **THEN** the user is not told that a reminder was set

#### Scenario: Action performed and claimed
- **WHEN** the model requests a reminder, the reminder is created, and the answer says so
- **THEN** the answer is delivered with that action reported alongside it

#### Scenario: Requested action that failed
- **WHEN** an action the model requested fails, and the answer still claims it succeeded
- **THEN** the user is not told the action succeeded

## MODIFIED Requirements

### Requirement: Answering without actions
When the user's chosen model does not support actions, or the provider refuses a request because of the actions offered, the system SHALL answer the question without actions, grounding it in the relevant notes found by meaning and exact words, as a plain question-answer exchange. In that state the assistant SHALL be told that it can perform none of its actions — creating notes, adding tags, remembering facts and setting reminders alike — so that a request for any of them is answered by saying it cannot be done and how the user can do it instead. Refusing a request because of the actions offered SHALL be distinguished from the model being unable to use actions at all, and the reason the provider gave SHALL be preserved.

#### Scenario: Model without action support
- **WHEN** a user whose chosen model does not support actions asks a question in the global conversation
- **THEN** the system answers from the relevant notes without performing any action

#### Scenario: Action request without action support
- **WHEN** a user whose chosen model does not support actions asks the assistant to create a note
- **THEN** nothing is created, and the answer says that the current model cannot perform actions and that another model can be chosen in Settings

#### Scenario: Reminder request without action support
- **WHEN** a user whose chosen model does not support actions asks the assistant to remind them of something
- **THEN** no reminder is created, and the answer says that the current model cannot set reminders and that another model can be chosen in Settings

#### Scenario: Refusal for another reason
- **WHEN** the provider refuses a request for a reason other than the model being unable to use actions
- **THEN** the reason the provider gave is preserved for whoever operates the system, rather than being recorded as the model not supporting actions

### Requirement: Reminder moments resolved in the user's timezone
A caller asking a question SHALL be able to supply the user's timezone, and the web app SHALL supply it on every question. When the assistant sets a reminder it SHALL pass the moment as the user expressed it ("el viernes", "en dos semanas", "mañana a las 8", "hoy a las 20:20"), and the system — not the assistant — SHALL resolve that wording against the current moment in the supplied timezone, always choosing the nearest matching moment in the future. When the user gives a day without a time, the system SHALL use 09:00 in the user's timezone. When no timezone is supplied, the system SHALL resolve moments in UTC. When the wording cannot be resolved to a moment, no reminder SHALL be created and the answer SHALL ask the user to say when, rather than claiming one was set. The answer SHALL state the exact date and time that was resolved, in the user's timezone, so the user can tell it got it wrong.

#### Scenario: Relative day resolved
- **WHEN** a user in `Europe/Madrid` asks on a Monday "recuérdame el viernes llamar al banco"
- **THEN** a reminder is created for 09:00 of that same week's Friday in `Europe/Madrid`, and the answer states that date and time

#### Scenario: Day already passed this week
- **WHEN** a user asks on a Saturday to be reminded "el viernes"
- **THEN** the reminder is created for the following Friday, not for the one that has just passed

#### Scenario: Explicit time honoured
- **WHEN** a user in `Europe/Madrid` asks to be reminded "mañana a las 8 de la tarde"
- **THEN** the reminder is created for 20:00 of the next day in `Europe/Madrid`

#### Scenario: Time today honoured
- **WHEN** a user in `Europe/Madrid` asks at 19:50 to be reminded "hoy a las 20:20"
- **THEN** the reminder is created for 20:20 of that same day in `Europe/Madrid`, not 20:20 UTC

#### Scenario: No timezone supplied
- **WHEN** a caller asks to be reminded "mañana" without supplying a timezone
- **THEN** the reminder is created for 09:00 of the next day in UTC, and the answer states the moment it used

#### Scenario: Moment that cannot be resolved
- **WHEN** the assistant passes wording the system cannot resolve to a moment, such as "cuando pueda"
- **THEN** no reminder is created and the answer asks the user when they want to be reminded
