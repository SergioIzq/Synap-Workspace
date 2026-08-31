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
The system SHALL handle unavailability or rate-limiting of the external answer-generation provider without exposing a broken or partial response.

#### Scenario: Generation provider unavailable
- **WHEN** the external generation provider is unreachable or rate-limited at the time of a query
- **THEN** the system returns a clear message that the assistant is temporarily unavailable, rather than a broken or partial answer
