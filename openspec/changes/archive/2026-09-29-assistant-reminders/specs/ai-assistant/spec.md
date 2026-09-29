# Spec Delta

## ADDED Requirements

### Requirement: Reminder moments resolved in the user's timezone
A caller asking a question SHALL be able to supply the user's timezone, and the web app SHALL supply it on every question. The assistant SHALL know the current date and time, and SHALL resolve a relative moment ("el viernes", "en dos semanas", "mañana a las 8") against that current moment in the supplied timezone, always choosing the nearest matching moment in the future. When the user gives a day without a time, the assistant SHALL use 09:00 in the user's timezone. When no timezone is supplied, the assistant SHALL resolve moments in UTC. The answer SHALL state the exact date and time it resolved, in the user's timezone, so the user can tell it got it wrong.

#### Scenario: Relative day resolved
- **WHEN** a user in `Europe/Madrid` asks on a Monday "recuérdame el viernes llamar al banco"
- **THEN** a reminder is created for 09:00 of that same week's Friday in `Europe/Madrid`, and the answer states that date and time

#### Scenario: Day already passed this week
- **WHEN** a user asks on a Saturday to be reminded "el viernes"
- **THEN** the reminder is created for the following Friday, not for the one that has just passed

#### Scenario: Explicit time honoured
- **WHEN** a user in `Europe/Madrid` asks to be reminded "mañana a las 8 de la tarde"
- **THEN** the reminder is created for 20:00 of the next day in `Europe/Madrid`

#### Scenario: No timezone supplied
- **WHEN** a caller asks to be reminded "mañana" without supplying a timezone
- **THEN** the reminder is created for 09:00 of the next day in UTC, and the answer states the moment it used

## MODIFIED Requirements

### Requirement: Assistant actions in the global conversation
When the user's chosen model supports actions, the assistant SHALL be able, in the global conversation, to decide by itself to perform the following actions on the user's own vault to answer or fulfil a request: search notes, read a note in full, create a text or code note with a title and tags, add tags to an existing note, save a memory entry, and set a reminder for a moment in the future, optionally linked to one of the user's notes and optionally recurring. Each action SHALL be subject to the same validation, ownership, and limits as the equivalent action performed by the user through the API. The assistant SHALL set a reminder only when the user asks to be reminded or warned about something, never on its own initiative. Scoped conversations SHALL NOT perform actions.

#### Scenario: Note created on request
- **WHEN** a user asks "apúntame que el martes tengo que renovar el certificado SSL, etiqueta #infra"
- **THEN** a text note with that content and the tag "infra" is created in the user's vault

#### Scenario: Tag added on request
- **WHEN** a user asks the assistant to tag their note about Docker volumes as "#docker"
- **THEN** the assistant finds that note and adds the tag "docker" to it

#### Scenario: Reminder set on request
- **WHEN** a user asks "recuérdame el viernes que tengo que renovar el certificado SSL"
- **THEN** a reminder with that text is created for that moment, and the answer confirms the date and time

#### Scenario: Reminder linked to a note
- **WHEN** a user asks the assistant to remind them next week about the note they have on Docker volumes
- **THEN** the assistant finds that note and creates a reminder linked to it

#### Scenario: Recurring reminder set on request
- **WHEN** a user asks "avísame todos los lunes de revisar las copias de seguridad"
- **THEN** a reminder repeating every Monday is created, and the answer says it will repeat

#### Scenario: No reminder set unasked
- **WHEN** a user mentions a future deadline without asking to be reminded of it
- **THEN** no reminder is created

#### Scenario: Several searches for one question
- **WHEN** a user asks a question whose answer needs notes found with different terms
- **THEN** the assistant can search more than once before answering, and the answer is based on the notes found

#### Scenario: Invalid action rejected
- **WHEN** the assistant attempts to create a note that fails the same validation a user-created note would fail
- **THEN** no note is created, and the answer says the note could not be created

#### Scenario: Reminder in the past rejected
- **WHEN** the assistant attempts to set a reminder for a moment that has already passed
- **THEN** no reminder is created, and the answer says so and asks the user for a future moment

#### Scenario: No actions in a scoped conversation
- **WHEN** a user asks, in a conversation scoped to a note, to create a new note
- **THEN** nothing is created, and the answer tells the user to ask from the global conversation

### Requirement: Assistant actions are non-destructive
The assistant SHALL NOT delete notes, delete tags, remove tags from notes, overwrite the title or content of existing notes, delete memory entries, or change or cancel existing reminders.

#### Scenario: Deletion requested
- **WHEN** a user asks the assistant to delete one of their notes
- **THEN** nothing is deleted, and the answer explains that it cannot delete notes and that the user can do it from the note itself

#### Scenario: Rewrite requested
- **WHEN** a user asks the assistant to rewrite the content of an existing note
- **THEN** the existing note is unchanged; the assistant may instead offer or create a new note with the rewritten text

#### Scenario: Reminder cancellation requested
- **WHEN** a user asks the assistant to cancel or move one of their existing reminders
- **THEN** no reminder is changed or cancelled, and the answer explains that the user can do it from the "Recordatorios" section or from the reminder's own notification

### Requirement: Actions shown in the answer
Every answer SHALL list the actions performed while producing it, in order, each with a short Spanish description ("Nota creada: …", "Etiqueta #x añadida a …", "Recordado: …", "Recordatorio creado: … para el …"), and the web app SHALL show them with a link to the created or changed note, to the "Memoria" section for memory entries, or to the "Recordatorios" section for reminders. A reminder's description SHALL include the resolved date and time in the user's timezone, and say so when it repeats. Actions performed before a failure SHALL be kept and still reported.

#### Scenario: Created note linked
- **WHEN** an answer reports that a note was created
- **THEN** selecting that action in the web app opens the created note

#### Scenario: Created reminder shown with its moment
- **WHEN** an answer reports that a reminder was created
- **THEN** the action says what will be recalled and on which date and time, and selecting it opens the "Recordatorios" section

#### Scenario: Failure after an action
- **WHEN** the assistant creates a note and the generation provider then fails before the final answer
- **THEN** the note remains created, and the response reports that action together with the provider failure message

#### Scenario: Actions kept after reload
- **WHEN** a user reloads the assistant page after an answer that performed actions
- **THEN** the answer is shown again with its list of actions
