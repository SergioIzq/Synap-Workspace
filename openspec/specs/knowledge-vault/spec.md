# knowledge-vault Specification

## Purpose

The core note-capture and retrieval capability: lets a user save text notes, code snippets and bookmarks with near-zero friction from any device, organize them with tags, and find them again through fast search.

## Requirements

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

### Requirement: Quick capture from an external trigger
The system SHALL expose a capture endpoint that accepts a note's content (and optionally a type) from an external trigger, such as an iOS Shortcut invoked from the system share sheet, without requiring the user to open the app first.

#### Scenario: Capture via external trigger
- **WHEN** an authenticated request to the quick-capture endpoint includes text or a URL
- **THEN** the system creates a note from that content, retrievable the next time the user opens the app

### Requirement: Bookmark metadata enrichment
The system SHALL enrich a bookmark note with metadata extracted from the linked page (title, description, and preview image) without blocking note creation on that enrichment.

#### Scenario: Metadata attached after capture
- **WHEN** a user saves a bookmark note pointing at a reachable web page
- **THEN** the system asynchronously attaches the page's extracted title, description and preview image to that note

#### Scenario: Unreachable link degrades gracefully
- **WHEN** a user saves a bookmark note whose URL cannot be reached or scraped
- **THEN** the note is still created and remains usable, with no metadata attached

### Requirement: Tagging
The system SHALL allow a user to attach one or more tags to a note, and reuse the same tag across multiple notes.

#### Scenario: Add tags to a note
- **WHEN** a user attaches one or more tags to a note
- **THEN** those tags are stored with the note and the note can later be found by any of them

### Requirement: Edit and delete notes
The system SHALL allow a user to update a note's content and to delete a note.

#### Scenario: Update note content
- **WHEN** a user edits an existing note's content
- **THEN** the system stores the new content and updates the note's last-modified time

#### Scenario: Delete a note
- **WHEN** a user deletes a note
- **THEN** the note is removed and no longer appears in search results or capture history

### Requirement: Full-text search
The system SHALL let a user search their own notes by text content and retrieve matches ranked by relevance, in pages, optionally filtered by tag and by note type, matching Spanish text regardless of accents.

#### Scenario: Search returns matching notes
- **WHEN** a user searches for a term that appears in one or more of their notes
- **THEN** the system returns those notes, ranked by relevance to the search term

#### Scenario: Search scoped to tag
- **WHEN** a user searches using a tag filter
- **THEN** the system returns only notes carrying that tag

#### Scenario: Search scoped to note type
- **WHEN** a user searches using a note type filter (text, code snippet, or bookmark)
- **THEN** the system returns only notes of that type

#### Scenario: No matches found
- **WHEN** a user searches for a term that matches none of their notes
- **THEN** the system returns an empty result set rather than an error

#### Scenario: Results are paginated
- **WHEN** a user requests a page of results with a given page size
- **THEN** the system returns at most that many notes for that page together with the total number of matches, and never more than 50 notes per page

#### Scenario: Accent-insensitive Spanish matching
- **WHEN** a user searches for "configuracion" and a note contains "configuración"
- **THEN** that note is included in the results

### Requirement: View a single note
The system SHALL let a user retrieve any one of their own notes by its identifier, regardless of which search page it would appear on.

#### Scenario: Own note retrieved
- **WHEN** a user requests one of their notes by identifier
- **THEN** the system returns that note with its tags

#### Scenario: Another user's note not revealed
- **WHEN** a user requests a note identifier that belongs to another user or does not exist
- **THEN** the system responds that the note was not found, without revealing whether it exists

### Requirement: List own tags
The system SHALL let a user list all the tags they have used, independently of which notes are currently loaded.

#### Scenario: All tags listed
- **WHEN** a user requests their tags
- **THEN** the system returns every tag name of that user, sorted alphabetically, and none of any other user
