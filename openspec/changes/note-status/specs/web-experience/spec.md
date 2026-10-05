# Spec Delta

## ADDED Requirements

### Requirement: The notes list shows and changes a note's status
The notes list SHALL show each note's status, in Spanish, and SHALL show nothing in its place for a note that carries none. The user SHALL be able to change a note's status, and clear it, from the list itself without opening the note, and the change SHALL be reflected without reloading the page. The note composer SHALL let the user choose a status while capturing a note, leaving it unset by default.

#### Scenario: A marked note shows its status
- **WHEN** a user's list contains notes marked pending, in progress, paused and completed
- **THEN** each shows its own status indicator, labelled in Spanish

#### Scenario: An unmarked note shows no status
- **WHEN** a user's list contains a note carrying no status
- **THEN** no status indicator is shown for it, and the note is otherwise displayed in full as any other

#### Scenario: Changing a status from the list
- **WHEN** a user changes a note's status from the notes list
- **THEN** the status is saved, the note's indicator updates in place, and a brief notification in Spanish confirms it

#### Scenario: Clearing a status from the list
- **WHEN** a user clears the status of a note from the notes list
- **THEN** the note is saved with no status and its indicator disappears

#### Scenario: Choosing a status while capturing
- **WHEN** a user opens the note composer
- **THEN** a status can be chosen but none is preselected, and leaving it alone creates a note with no status

### Requirement: The notes list can be filtered by status
The notes list SHALL offer a status filter allowing one or more statuses to be selected at once, and allowing notes that carry no status to be selected in the same way. With nothing selected, the list SHALL show every note except those marked completed, including notes that carry no status. The selected filter SHALL be reflected in the page address alongside the other filters, so that the view can be reloaded and shared.

#### Scenario: Nothing selected
- **WHEN** a user opens the notes list without choosing a status filter
- **THEN** their notes of every status except completed are shown, and notes carrying no status are shown among them

#### Scenario: Several statuses at once
- **WHEN** a user selects pending and in progress in the status filter
- **THEN** only notes of those two statuses are listed

#### Scenario: Seeing completed notes
- **WHEN** a user selects completed in the status filter
- **THEN** their completed notes are listed

#### Scenario: Seeing notes that are not work
- **WHEN** a user selects the option for notes with no status
- **THEN** only notes carrying no status are listed

#### Scenario: The filter survives a reload
- **WHEN** a user filtering by status reloads the page or opens its address again
- **THEN** the same status filter is applied, together with any search term, tag, type and page

#### Scenario: Status filter combined with the others
- **WHEN** a user filters by status while a search term or tag filter is active
- **THEN** only notes satisfying every filter are listed, and the pagination reflects that count

## MODIFIED Requirements

### Requirement: Note summaries show type and age
The notes list SHALL show, for each note, what kind of note it is, how long ago it was created, and its status when it has one, and bookmark notes SHALL show the linked site.

#### Scenario: Different note types are distinguishable
- **WHEN** a user's list contains a text note, a code snippet and a bookmark
- **THEN** each is displayed with its own type indicator, code snippets in a monospaced block, and bookmarks with the site's domain and, when available, its title and preview image

#### Scenario: Relative creation time
- **WHEN** a user views a note created two hours ago
- **THEN** its summary shows the age in Spanish, such as "hace 2 h"

#### Scenario: Status alongside type and age
- **WHEN** a user views a note that carries a status
- **THEN** its summary shows that status in Spanish without displacing its type indicator or its age
