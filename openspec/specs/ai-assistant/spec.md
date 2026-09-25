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
The web app SHALL keep the current assistant conversation across page reloads on the same device for the signed-in user, and SHALL let the user start a new conversation.

#### Scenario: Reload keeps the conversation
- **WHEN** a user reloads the assistant page
- **THEN** the previous questions and answers of the current conversation are still shown

#### Scenario: New conversation
- **WHEN** a user chooses "Nueva conversación"
- **THEN** the displayed conversation is cleared

#### Scenario: Conversation cleared on sign out
- **WHEN** a user signs out
- **THEN** the stored conversation is removed from the device, so the next user signing in on that device cannot see it
