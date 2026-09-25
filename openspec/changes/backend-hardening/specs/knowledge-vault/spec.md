# Spec Delta

## MODIFIED Requirements

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
