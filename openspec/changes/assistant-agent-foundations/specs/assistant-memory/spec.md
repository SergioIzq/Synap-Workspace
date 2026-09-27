# Spec Delta

## Purpose

Lets the assistant know who the user is: a short, user-controlled list of persistent facts about them (preferences, context, ongoing goals) that is taken into account in every assistant answer.

## ADDED Requirements

### Requirement: Memory entries are bounded
The system SHALL store, per user, at most 25 memory entries, each a non-empty text of at most 200 characters, and SHALL reject additions or edits that break these limits with a clear message in Spanish, leaving the stored memory unchanged.

#### Scenario: Entry too long
- **WHEN** a user saves a memory entry longer than 200 characters
- **THEN** the system rejects it with a Spanish message stating the maximum length, and nothing is stored

#### Scenario: Empty entry
- **WHEN** a user saves a memory entry that is empty or only whitespace
- **THEN** the system rejects it and nothing is stored

#### Scenario: Memory full
- **WHEN** a user who already has 25 memory entries adds another
- **THEN** the system rejects it with a Spanish message explaining the memory is full and that an entry must be deleted first

### Requirement: Manage memory from the web app
The web app SHALL provide a "Memoria" section in the Settings page where the user can see all their memory entries with their last update date, add an entry, edit an entry, delete an entry, and delete all entries after confirming.

#### Scenario: Entries listed
- **WHEN** a user opens the "Memoria" section
- **THEN** all of their memory entries are shown, most recently updated first, together with how many of the 25 are used

#### Scenario: Entry added manually
- **WHEN** a user adds the entry "Trabajo con .NET y Angular"
- **THEN** it appears in the list and is taken into account in the next assistant answers

#### Scenario: Entry edited
- **WHEN** a user edits one of their entries
- **THEN** the new text replaces the old one and is what the assistant uses from then on

#### Scenario: Entry deleted
- **WHEN** a user deletes one of their entries
- **THEN** it disappears from the list and is no longer taken into account by the assistant

#### Scenario: All entries deleted
- **WHEN** a user chooses to delete all their memory and confirms
- **THEN** every entry is removed; if they do not confirm, nothing is removed

### Requirement: Saving memory through the assistant
The assistant SHALL save a memory entry when the user explicitly asks it to remember something, subject to the same limits as a manual entry, and SHALL NOT save memory entries the user did not ask for.

#### Scenario: User asks to remember
- **WHEN** a user tells the assistant "recuerda que prefiero respuestas cortas" in a conversation where actions are available
- **THEN** a memory entry with that fact is stored, and the answer reports it as "Recordado: …"

#### Scenario: Nothing saved unasked
- **WHEN** a user mentions a personal fact without asking the assistant to remember it
- **THEN** no memory entry is stored

#### Scenario: Memory full when asked to remember
- **WHEN** a user whose memory is full asks the assistant to remember something
- **THEN** nothing is stored, and the answer tells the user the memory is full and that an entry must be deleted from Settings

#### Scenario: Remembering without actions
- **WHEN** a user asks to remember something in a conversation where actions are not available (a scoped conversation, or a model without action support)
- **THEN** nothing is stored, and the answer tells the user they can add it from the "Memoria" section in Settings

### Requirement: Memory informs every answer
The system SHALL take all of a user's memory entries into account when generating any assistant answer for that user, in global and scoped conversations alike, without making additional requests to the generation provider to do so.

#### Scenario: Preference applied
- **WHEN** a user has the entry "prefiero respuestas cortas" and asks the assistant a question
- **THEN** the answer is generated with that preference taken into account

#### Scenario: No extra provider calls
- **WHEN** a user with memory entries asks a question that would take one generation request without memory
- **THEN** it still takes exactly one generation request

### Requirement: Memory never crosses users
The system SHALL only ever show, change, delete, or use a user's memory entries for that same user.

#### Scenario: Another user's entry
- **WHEN** a user tries to edit or delete a memory entry identifier that belongs to another user
- **THEN** the system responds as if the entry did not exist, and the entry is unchanged

#### Scenario: Answers use only own memory
- **WHEN** any user asks the assistant a question
- **THEN** only that user's own memory entries are taken into account
