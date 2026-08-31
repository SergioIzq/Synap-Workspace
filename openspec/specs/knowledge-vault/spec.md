# knowledge-vault Specification

## Purpose

The core note-capture and retrieval capability: lets a user save text notes, code snippets and bookmarks with near-zero friction from any device, organize them with tags, and find them again through fast search.

## Requirements

### Requirement: Capture a note
The system SHALL allow an authenticated user to create a note as one of: plain text, code snippet, or bookmark (URL).

#### Scenario: Create a text note
- **WHEN** a user submits a title and text content
- **THEN** the system creates a note of type text, timestamped with its creation time

#### Scenario: Create a code snippet note
- **WHEN** a user submits content marked as a code snippet
- **THEN** the system stores the content exactly as submitted, preserving whitespace and indentation, and records its type as code snippet

#### Scenario: Create a bookmark note
- **WHEN** a user submits a URL as a bookmark
- **THEN** the system creates a note of type bookmark referencing that URL

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
The system SHALL let a user search their own notes by text content and retrieve matches ranked by relevance.

#### Scenario: Search returns matching notes
- **WHEN** a user searches for a term that appears in one or more of their notes
- **THEN** the system returns those notes, ranked by relevance to the search term

#### Scenario: Search scoped to tag
- **WHEN** a user searches using a tag filter
- **THEN** the system returns only notes carrying that tag

#### Scenario: No matches found
- **WHEN** a user searches for a term that matches none of their notes
- **THEN** the system returns an empty result set rather than an error
