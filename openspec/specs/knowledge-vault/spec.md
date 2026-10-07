# knowledge-vault Specification

## Purpose

The core note-capture and retrieval capability: lets a user save text notes, code snippets and bookmarks with near-zero friction from any device, organize them with tags, and find them again through fast search.

## Requirements

### Requirement: Capture a note
The system SHALL allow an authenticated user to create a note as one of: plain text, code snippet, or bookmark (URL), optionally giving it a title, tags, and a status in the same operation; when no type is given, the system SHALL infer it from the content. When no status is given, the note SHALL be created with none.

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

#### Scenario: Create a note with a status
- **WHEN** a user creates a note and includes a status
- **THEN** the note is created already carrying that status, and the moment of its creation is recorded as the moment the status was set

#### Scenario: Create a note without a status
- **WHEN** a user creates a note without naming a status
- **THEN** the note is created carrying none

#### Scenario: Create a note with an invalid status
- **WHEN** a user creates a note naming a status that is not one of the four
- **THEN** the system rejects the request with a Spanish validation message and creates neither the note nor any tag

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
The system SHALL let a user search their own notes by text content and retrieve matches ranked by relevance, in pages, optionally filtered by tag, by note type, and by status, matching Spanish text regardless of accents.

#### Scenario: Search returns matching notes
- **WHEN** a user searches for a term that appears in one or more of their notes
- **THEN** the system returns those notes, ranked by relevance to the search term

#### Scenario: Search scoped to tag
- **WHEN** a user searches using a tag filter
- **THEN** the system returns only notes carrying that tag

#### Scenario: Search scoped to note type
- **WHEN** a user searches using a note type filter (text, code snippet, or bookmark)
- **THEN** the system returns only notes of that type

#### Scenario: Search scoped to status
- **WHEN** a user searches using a status filter
- **THEN** the system returns only notes satisfying that filter

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

### Requirement: Note status
The system SHALL allow a user to mark one of their own notes with exactly one status out of: pending, in progress, paused, completed. A status is optional: a note MAY have none, and a note with no status SHALL be treated as material rather than as work. The system SHALL allow a status to be set, changed to any other status, and cleared back to none, in any order, and SHALL NOT reject a change on the grounds of which status the note held before. The system SHALL record the moment a note's status last changed.

#### Scenario: Mark a note with a status
- **WHEN** a user sets the status of one of their notes to pending
- **THEN** the note carries that status, and the moment of the change is recorded

#### Scenario: A note has no status by default
- **WHEN** a user creates a note without giving a status
- **THEN** the note has no status, and is not reported as work anywhere

#### Scenario: Any status may follow any other
- **WHEN** a user changes a completed note's status back to in progress
- **THEN** the change is accepted, and the moment of the change is recorded

#### Scenario: Clearing a status
- **WHEN** a user clears the status of a note that had one
- **THEN** the note has no status again, exactly as a note that never had one

#### Scenario: Only one status at a time
- **WHEN** a user sets the status of a note that already has one
- **THEN** the new status replaces the old one, and the note carries exactly one status

#### Scenario: An unknown status is rejected
- **WHEN** a user sets a note's status to a value that is not one of the four
- **THEN** the system rejects the request with a Spanish validation message and the note's status is unchanged

#### Scenario: Another user's note cannot be marked
- **WHEN** a user sets the status of a note identifier that belongs to another user or does not exist
- **THEN** the system responds that the note was not found, without revealing whether it exists, and changes nothing

### Requirement: Changing a status is not editing the note
The system SHALL allow a user to change a note's status without submitting its title or content, and SHALL NOT alter the note's content or its last-modified time when only its status changes. Equally, editing a note's content SHALL NOT alter its status or the moment that status last changed.

#### Scenario: Status change leaves the note's text alone
- **WHEN** a user changes a note's status
- **THEN** the note's title, content and last-modified time are unchanged

#### Scenario: Editing content leaves the status alone
- **WHEN** a user edits the content of a note that carries a status
- **THEN** the note keeps that status and the moment it last changed, and only its content and last-modified time change

### Requirement: Search and listing filtered by status
The system SHALL let a user filter their notes by status, naming one or more statuses in a single request, and SHALL also accept a value standing for notes that carry no status, which MAY be named alongside statuses. When a request names no status filter, the system SHALL return notes of every status except completed, together with notes that carry no status. A note that carries no status SHALL NEVER be omitted on account of the status filter unless the request names a status filter that excludes it.

#### Scenario: Filtered to one status
- **WHEN** a user lists their notes filtered to pending
- **THEN** only their pending notes are returned

#### Scenario: Filtered to several statuses at once
- **WHEN** a user lists their notes filtered to pending and in progress
- **THEN** notes of either status are returned, and no others

#### Scenario: Filtered to notes without a status
- **WHEN** a user lists their notes filtered to those with no status
- **THEN** only notes carrying no status are returned

#### Scenario: Statuses and "no status" filtered together
- **WHEN** a user lists their notes filtered to pending together with those carrying no status
- **THEN** pending notes and notes with no status are returned, and no others

#### Scenario: Completed notes are left out by default
- **WHEN** a user lists their notes without naming a status filter
- **THEN** their completed notes are not returned

#### Scenario: A note without a status is never hidden by default
- **WHEN** a user lists their notes without naming a status filter, and some of those notes carry no status
- **THEN** every one of those notes is returned

#### Scenario: Completed notes asked for explicitly
- **WHEN** a user lists their notes filtered to completed
- **THEN** their completed notes are returned

#### Scenario: Everything asked for explicitly
- **WHEN** a user lists their notes naming all four statuses and those with no status
- **THEN** every note of that user is returned, completed ones included

#### Scenario: Status filter combined with a search term
- **WHEN** a user searches for a term and filters to in progress
- **THEN** only their in-progress notes matching that term are returned, ranked by relevance as usual

#### Scenario: Status filter combined with a tag or type filter
- **WHEN** a user filters by status together with a tag or a note type
- **THEN** only notes satisfying every filter are returned

#### Scenario: An unknown value in the status filter
- **WHEN** a user names a status filter containing a value that is neither one of the four statuses nor the value standing for no status
- **THEN** the system rejects the request with a Spanish validation message naming the accepted values, and returns no results

#### Scenario: Status filter does not cross users
- **WHEN** a user filters their notes by status
- **THEN** only their own notes are returned, whatever status other users' notes carry

### Requirement: A note's status is returned with the note
The system SHALL report a note's status, or its absence, wherever it returns the note itself — in search results, when a single note is retrieved, and when a note is created or changed.

#### Scenario: Status in search results
- **WHEN** a user searches their notes and some of the matches carry a status
- **THEN** each returned note reports its status, and a note with none reports that it has none

#### Scenario: Status when a single note is retrieved
- **WHEN** a user retrieves one of their notes by identifier
- **THEN** the note is returned with its status, or with none when it has none
