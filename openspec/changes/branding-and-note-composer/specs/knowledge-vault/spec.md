# Spec Delta

## MODIFIED Requirements

### Requirement: Capture a note
The system SHALL allow an authenticated user to create a note as one of: plain text, code snippet, or bookmark (URL), optionally giving it a title and tags in the same operation; when no type is given, the system SHALL infer it from the content.

#### Scenario: Create a text note
- **WHEN** a user submits a title and text content
- **THEN** the system creates a note of type text, timestamped with its creation time

#### Scenario: Create a code snippet note
- **WHEN** a user submits content marked as a code snippet
- **THEN** the system stores the content exactly as submitted, preserving whitespace and indentation, and records its type as code snippet

#### Scenario: Create a bookmark note
- **WHEN** a user submits a URL as a bookmark
- **THEN** the system creates a note of type bookmark referencing that URL

#### Scenario: Create a note with tags
- **WHEN** a user creates a note and includes one or more tags
- **THEN** the note is created already carrying those tags, reusing any of the user's existing tags with the same name, and it can be found by any of them immediately

#### Scenario: Type inferred when not given
- **WHEN** a user creates a note without choosing a type and the content is a single web address
- **THEN** the system creates it as a bookmark; any other content becomes a text note

#### Scenario: Invalid tags reject the whole note
- **WHEN** a user creates a note with a blank tag
- **THEN** the system rejects the request with a Spanish validation message and creates neither the note nor any tag
