# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Follow-up questions within a scoped conversation`
- TO: `### Requirement: Follow-up questions within a conversation`

## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Assistant actions in the global conversation
When the user's chosen model supports actions, the assistant SHALL be able, in the global conversation, to decide by itself to perform the following actions on the user's own vault to answer or fulfil a request: search notes, read a note in full, create a text or code note with a title and tags, add tags to an existing note, and save a memory entry. Each action SHALL be subject to the same validation, ownership, and limits as the equivalent action performed by the user through the API. Scoped conversations SHALL NOT perform actions.

#### Scenario: Note created on request
- **WHEN** a user asks "apúntame que el martes tengo que renovar el certificado SSL, etiqueta #infra"
- **THEN** a text note with that content and the tag "infra" is created in the user's vault

#### Scenario: Tag added on request
- **WHEN** a user asks the assistant to tag their note about Docker volumes as "#docker"
- **THEN** the assistant finds that note and adds the tag "docker" to it

#### Scenario: Several searches for one question
- **WHEN** a user asks a question whose answer needs notes found with different terms
- **THEN** the assistant can search more than once before answering, and the answer is based on the notes found

#### Scenario: Invalid action rejected
- **WHEN** the assistant attempts to create a note that fails the same validation a user-created note would fail
- **THEN** no note is created, and the answer says the note could not be created

#### Scenario: No actions in a scoped conversation
- **WHEN** a user asks, in a conversation scoped to a note, to create a new note
- **THEN** nothing is created, and the answer tells the user to ask from the global conversation

### Requirement: Assistant actions are non-destructive
The assistant SHALL NOT delete notes, delete tags, remove tags from notes, overwrite the title or content of existing notes, or delete memory entries.

#### Scenario: Deletion requested
- **WHEN** a user asks the assistant to delete one of their notes
- **THEN** nothing is deleted, and the answer explains that it cannot delete notes and that the user can do it from the note itself

#### Scenario: Rewrite requested
- **WHEN** a user asks the assistant to rewrite the content of an existing note
- **THEN** the existing note is unchanged; the assistant may instead offer or create a new note with the rewritten text

### Requirement: Actions shown in the answer
Every answer SHALL list the actions performed while producing it, in order, each with a short Spanish description ("Nota creada: …", "Etiqueta #x añadida a …", "Recordado: …"), and the web app SHALL show them with a link to the created or changed note, or to the "Memoria" section for memory entries. Actions performed before a failure SHALL be kept and still reported.

#### Scenario: Created note linked
- **WHEN** an answer reports that a note was created
- **THEN** selecting that action in the web app opens the created note

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
