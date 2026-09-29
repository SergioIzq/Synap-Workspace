# ai-assistant Specification

## Purpose

The capability that makes Synap an actual "second brain" rather than a plain notes app: it connects a user's notes to each other by meaning, and lets the user ask questions in natural language and get answers grounded in their own captured knowledge.

## Requirements

### Requirement: Embedding generation
The system SHALL generate a semantic embedding for every note from its title and content, asynchronously, without blocking note creation or editing, using a model that handles Spanish and English text. When the configured embedding model changes, the system SHALL regenerate the embeddings produced by any other model in the background, without manual intervention and without making the assistant unavailable meanwhile.

#### Scenario: Embedding created on note capture
- **WHEN** a user creates a new note
- **THEN** the system generates an embedding for its title and content shortly after, without delaying the response to the user

#### Scenario: Embedding refreshed on edit
- **WHEN** a user edits an existing note's title or content
- **THEN** the system regenerates that note's embedding to reflect the new text

#### Scenario: Spanish notes matched by meaning
- **WHEN** a user has a note in Spanish about "configurar el proxy inverso de nginx" and asks "¿cómo monté el reverse proxy?"
- **THEN** that note is retrieved as relevant even though the wording differs

#### Scenario: Reindexing after a model change
- **WHEN** the service starts with an embedding model different from the one that produced some existing embeddings
- **THEN** those embeddings are regenerated in the background with the new model, notes created or edited meanwhile get new-model embeddings as usual, and the assistant keeps answering during the process

### Requirement: Semantic relations between notes
The system SHALL let a user retrieve other notes semantically related to a given note, scoped to that user's own vault.

#### Scenario: Related notes surfaced
- **WHEN** a user requests notes related to one of their own notes
- **THEN** the system returns other notes from that same user, ranked by semantic similarity, excluding the note itself

#### Scenario: Related notes never cross users
- **WHEN** a user requests notes related to one of their own notes
- **THEN** the system never includes notes belonging to any other user, regardless of semantic similarity

### Requirement: Natural-language assistant queries
The system SHALL let a user ask a natural-language question and receive an answer grounded in the relevant notes from their own vault. Relevant notes SHALL be found both by meaning and by exact words (names, error codes, identifiers), so that a note containing the exact term asked about is found even when its semantic similarity is low.

#### Scenario: Answer grounded in the user's notes
- **WHEN** a user asks a question that relates to content they have previously captured
- **THEN** the system retrieves the relevant notes from that user's vault and returns an answer based on them

#### Scenario: Exact term found
- **WHEN** a user asks "¿qué hice con el error NU1605?" and one of their notes contains "NU1605"
- **THEN** that note is among the notes the answer is based on

#### Scenario: No relevant notes found
- **WHEN** a user asks a question with no relevant notes in their vault
- **THEN** the system states that it found nothing relevant rather than fabricating an answer

#### Scenario: Assistant queries never cross users
- **WHEN** a user asks the assistant a question
- **THEN** the system only retrieves from and answers based on that user's own vault, never another user's notes

### Requirement: Graceful handling of generation provider failure
The system SHALL handle unavailability, rate-limiting, or credential rejection by the external answer-generation provider without exposing a broken or partial response, and SHALL tell the user which of these occurred, in Spanish.

#### Scenario: Generation provider unavailable
- **WHEN** the external generation provider is unreachable or fails at the time of a query
- **THEN** the system returns a clear message that the assistant is temporarily unavailable, rather than a broken or partial answer

#### Scenario: User's key rejected by the provider
- **WHEN** the provider rejects the user's stored key (revoked or invalid)
- **THEN** the system returns a message stating the key is no longer valid and that it must be updated in Settings, rather than a generic error

#### Scenario: User's quota or rate limit exhausted
- **WHEN** the provider rejects the request because the user's key has exceeded its rate limit or quota
- **THEN** the system returns a message stating the user's Groq quota has been reached and to try again later

### Requirement: Answers generated with the user's own credentials
The system SHALL generate assistant answers exclusively with the requesting user's own stored Groq API key and chosen model, and SHALL NOT use any shared or server-owned generation key.

#### Scenario: Answer uses the user's key
- **WHEN** a user with a configured key asks a question that has relevant notes
- **THEN** the answer is generated using that user's key and chosen model

#### Scenario: No shared fallback key
- **WHEN** a user without a configured key asks a question
- **THEN** the system does not fall back to any other key and does not contact the generation provider

### Requirement: Assistant requires a configured key
The system SHALL refuse assistant questions from a user who has no Groq API key configured, and the web app SHALL warn the user and point them to Settings before they try to ask.

#### Scenario: Question without a key rejected
- **WHEN** a user without a configured key submits a question
- **THEN** the system returns a result indicating that a key must be configured, without generating an answer

#### Scenario: Warning shown on entering the assistant
- **WHEN** a user without a configured key opens the assistant page
- **THEN** the page shows a warning explaining that a personal Groq API key is needed, with a direct link to the Settings page, and the question input is disabled

#### Scenario: Assistant unlocked after configuring a key
- **WHEN** a user saves a valid key and returns to the assistant page
- **THEN** the warning is no longer shown and the user can ask questions

### Requirement: Navigable answer sources
The system SHALL return, with every grounded answer, the identifier and title of each source note used, and the web app SHALL display them as links to those notes.

#### Scenario: Sources shown with an answer
- **WHEN** the assistant returns an answer grounded in the user's notes
- **THEN** the answer lists each source note by title (or a content preview when it has no title), and selecting one opens that note

#### Scenario: Sources never cross users
- **WHEN** an answer lists its source notes
- **THEN** every listed note belongs to the requesting user

### Requirement: Conversation persists on the device
The web app SHALL keep a separate assistant conversation for the global scope and for each note or tag scope, SHALL preserve each of them across page reloads on the same device for the signed-in user, and SHALL let the user start a new conversation in the current scope.

#### Scenario: Reload keeps the conversation
- **WHEN** a user reloads the assistant page
- **THEN** the previous questions and answers of the conversation for the active scope are still shown

#### Scenario: Conversations are kept per scope
- **WHEN** a user asks questions about a note, removes that scope, asks a global question, and later opens the same note's scope again
- **THEN** the global question is not shown in the note's conversation, and the note's earlier questions and answers are shown again

#### Scenario: New conversation
- **WHEN** a user chooses "Nueva conversación"
- **THEN** the conversation for the active scope is cleared, and conversations for other scopes are kept

#### Scenario: Conversation cleared on sign out
- **WHEN** a user signs out
- **THEN** all of that user's stored conversations, for every scope, are removed from the device, so the next user signing in on that device cannot see them

### Requirement: Questions scoped to a single note
The system SHALL let a user ask a question about one specific note of their own and SHALL answer it based only on that note's content, without searching the rest of the vault. When the note is longer than the context budget, the system SHALL use only the part that fits and SHALL indicate that the answer is based on part of the note.

#### Scenario: Answer about a note
- **WHEN** a user with a configured key asks "resúmelo" scoped to one of their text or code notes
- **THEN** the answer is generated from that note's content only, and that note is the only source listed

#### Scenario: Note belonging to someone else or missing
- **WHEN** a user asks a question scoped to a note that does not exist or belongs to another user
- **THEN** the system responds exactly as for a note that does not exist, without revealing whether it belongs to someone else, and contacts no generation provider

#### Scenario: Very long note
- **WHEN** a user asks about a note whose content exceeds the context budget
- **THEN** the answer is generated from the part of the note that fits, and the response indicates that only part of the note was used

### Requirement: Questions scoped to a tag
The system SHALL let a user ask a question about one of their tags and SHALL answer it based only on their own notes carrying that tag: all of them when they fit in the context budget, otherwise the ones most semantically similar to the question among them.

#### Scenario: Answer about a tag
- **WHEN** a user asks "¿qué he aprendido de esto?" scoped to their tag "docker"
- **THEN** the answer is based only on their notes tagged "docker", and every listed source carries that tag

#### Scenario: Tag with more notes than fit
- **WHEN** a user asks about a tag whose notes together exceed the context budget
- **THEN** the answer uses only the notes of that tag most similar to the question, within the budget

#### Scenario: Tag without notes or not the user's
- **WHEN** a user asks about a tag they have no notes with, including a tag that only exists in another user's vault
- **THEN** the system states that it found nothing relevant, exactly as for an unused tag, without revealing other users' tags, and contacts no generation provider

### Requirement: Follow-up questions within a conversation
For every conversation, global or scoped to a note or a tag, the system SHALL take into account the previous turns of that same conversation, up to the last 3 question-answer pairs, so that follow-up questions that refer to earlier answers can be answered.

#### Scenario: Follow-up question
- **WHEN** a user asked "resume esta nota" scoped to a note, got a numbered summary, and then asks "desarrolla el punto 2" in the same scoped conversation
- **THEN** the answer expands the second point of the previous summary

#### Scenario: Follow-up in the global conversation
- **WHEN** a user asked a global question about how they configured nginx, and then asks "¿y cómo lo reinicio?" in the global conversation
- **THEN** the answer is about restarting nginx, as the earlier turn established

#### Scenario: History limited to recent turns
- **WHEN** a conversation has more than 3 previous turns
- **THEN** only the last 3 are taken into account, and a request carrying more is not rejected

#### Scenario: Global questions stay independent
- **WHEN** a user asks a follow-up in the global conversation after having talked about a note in that note's scoped conversation
- **THEN** only the global conversation's previous turns are taken into account

### Requirement: Bookmark notes are not yet a question scope
Because bookmark notes only hold a link and not the linked page's content, the system SHALL NOT generate answers scoped to a bookmark note, and SHALL respond with a specific result and a Spanish message explaining that questions about links are not available yet. The web app SHALL show the option as unavailable, with that explanation, on bookmark notes.

#### Scenario: Question scoped to a bookmark
- **WHEN** a user asks a question scoped to one of their bookmark notes
- **THEN** the system returns a result indicating the scope is not supported, with a Spanish explanation, and contacts no generation provider

#### Scenario: Option shown as unavailable
- **WHEN** a user opens one of their bookmark notes
- **THEN** the "Preguntar a la IA" option is visible but disabled, with an explanation that questions about links will be available once the article's content can be read

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

### Requirement: Bounded generation requests per question
Answering one question SHALL take at most 4 requests to the generation provider, whatever actions the assistant performs. When that limit is reached, the assistant SHALL answer with what it has gathered so far instead of failing.

#### Scenario: Limit reached
- **WHEN** the assistant would need more than 4 generation requests to finish a question
- **THEN** it stops performing actions and returns an answer based on what it has so far, within the 4 requests

#### Scenario: Plain question
- **WHEN** a user asks a question that needs no actions and a model without action support is used
- **THEN** answering takes exactly one generation request

### Requirement: Answering without actions
When the user's chosen model does not support actions, or the provider refuses a request because of the actions offered, the system SHALL answer the question without actions, grounding it in the relevant notes found by meaning and exact words, as a plain question-answer exchange.

#### Scenario: Model without action support
- **WHEN** a user whose chosen model does not support actions asks a question in the global conversation
- **THEN** the system answers from the relevant notes without performing any action

#### Scenario: Action request without action support
- **WHEN** a user whose chosen model does not support actions asks the assistant to create a note
- **THEN** nothing is created, and the answer says that the current model cannot perform actions and that another model can be chosen in Settings

### Requirement: Assistant actions never cross users
Every action the assistant performs SHALL only read from and write to the requesting user's own vault and memory.

#### Scenario: Another user's note referenced
- **WHEN** the assistant attempts to read or tag a note identifier that belongs to another user
- **THEN** the action is treated as a note that does not exist, and the other user's note is neither read nor changed

#### Scenario: Searches limited to own vault
- **WHEN** the assistant searches notes on behalf of a user
- **THEN** only that user's notes can be returned

### Requirement: Choosing and showing a question scope in the web app
The web app SHALL let the user start a scoped conversation from a note's detail page, from a tag, and from the assistant's input by typing "@" to pick a note or "#" to pick a tag. While a scope is active, the assistant page SHALL show it (the note's title or a content preview, or the tag name), SHALL offer quick actions suited to it, and SHALL let the user remove it to return to the global conversation.

#### Scenario: Asking from a note
- **WHEN** a user selects "Preguntar a la IA" on one of their text notes
- **THEN** the assistant opens with that note as the active scope, showing its title, and with quick actions "Resumir" and "Puntos clave"

#### Scenario: Asking about code
- **WHEN** the active scope is a code snippet note
- **THEN** the quick actions also include "Explícame este código"

#### Scenario: Asking from a tag
- **WHEN** a user selects the option to ask about the tag "python"
- **THEN** the assistant opens with "#python" as the active scope and a quick action to summarise what they know about it

#### Scenario: Picking a scope while typing
- **WHEN** a user types "@" in the assistant input and picks one of their notes from the suggestions, or types "#" and picks one of their tags
- **THEN** that note or tag becomes the active scope

#### Scenario: Removing the scope
- **WHEN** a user removes the active scope
- **THEN** the assistant shows the global conversation, and new questions are asked about the whole vault

#### Scenario: Scoped note deleted
- **WHEN** a user opens the assistant scoped to a note that has since been deleted
- **THEN** the assistant says the note no longer exists, discards that conversation, and returns to the global conversation

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
