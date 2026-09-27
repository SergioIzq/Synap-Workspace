# ai-assistant Specification

## Purpose

The capability that makes Synap an actual "second brain" rather than a plain notes app: it connects a user's notes to each other by meaning, and lets the user ask questions in natural language and get answers grounded in their own captured knowledge.

## Requirements

### Requirement: Embedding generation
The system SHALL generate a semantic embedding for every note's content, asynchronously, without blocking note creation or editing.

#### Scenario: Embedding created on note capture
- **WHEN** a user creates a new note
- **THEN** the system generates an embedding for its content shortly after, without delaying the response to the user

#### Scenario: Embedding refreshed on edit
- **WHEN** a user edits an existing note's content
- **THEN** the system regenerates that note's embedding to reflect the new content

### Requirement: Semantic relations between notes
The system SHALL let a user retrieve other notes semantically related to a given note, scoped to that user's own vault.

#### Scenario: Related notes surfaced
- **WHEN** a user requests notes related to one of their own notes
- **THEN** the system returns other notes from that same user, ranked by semantic similarity, excluding the note itself

#### Scenario: Related notes never cross users
- **WHEN** a user requests notes related to one of their own notes
- **THEN** the system never includes notes belonging to any other user, regardless of semantic similarity

### Requirement: Natural-language assistant queries
The system SHALL let a user ask a natural-language question and receive an answer grounded in the relevant notes from their own vault.

#### Scenario: Answer grounded in the user's notes
- **WHEN** a user asks a question that relates to content they have previously captured
- **THEN** the system retrieves the relevant notes from that user's vault and returns an answer based on them

#### Scenario: No relevant notes found
- **WHEN** a user asks a question with no semantically relevant notes in their vault
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

### Requirement: Follow-up questions within a scoped conversation
For questions scoped to a note or a tag, the system SHALL take into account the previous turns of that same scoped conversation, up to the last 3 question-answer pairs, so that follow-up questions that refer to earlier answers can be answered. Questions without a scope SHALL be answered without conversation history.

#### Scenario: Follow-up question
- **WHEN** a user asked "resume esta nota" scoped to a note, got a numbered summary, and then asks "desarrolla el punto 2" in the same scoped conversation
- **THEN** the answer expands the second point of the previous summary

#### Scenario: History limited to recent turns
- **WHEN** a scoped conversation has more than 3 previous turns
- **THEN** only the last 3 are taken into account, and a request carrying more is not rejected

#### Scenario: Global questions stay independent
- **WHEN** a user asks a question with no scope
- **THEN** the answer is generated without any previous turns, as before

### Requirement: Bookmark notes are not yet a question scope
Because bookmark notes only hold a link and not the linked page's content, the system SHALL NOT generate answers scoped to a bookmark note, and SHALL respond with a specific result and a Spanish message explaining that questions about links are not available yet. The web app SHALL show the option as unavailable, with that explanation, on bookmark notes.

#### Scenario: Question scoped to a bookmark
- **WHEN** a user asks a question scoped to one of their bookmark notes
- **THEN** the system returns a result indicating the scope is not supported, with a Spanish explanation, and contacts no generation provider

#### Scenario: Option shown as unavailable
- **WHEN** a user opens one of their bookmark notes
- **THEN** the "Preguntar a la IA" option is visible but disabled, with an explanation that questions about links will be available once the article's content can be read

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
