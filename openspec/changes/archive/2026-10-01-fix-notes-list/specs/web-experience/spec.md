# Spec Delta

## ADDED Requirements

### Requirement: Notes list is paginated with visible page controls
The notes list SHALL show one page of notes at a time with visible controls to move between pages and choose the page size (10, 20 or 50, default 20), SHALL state which range of notes is shown out of the total, and SHALL keep the current page, page size and filters (search text, tag, type) in the page address so that reloading, going back or opening the same address shows the same results.

#### Scenario: Moving to another page
- **WHEN** a user with 45 notes is on page 1 with a page size of 20 and selects page 2
- **THEN** notes 21 to 40 replace the previous ones, the list scrolls back to its start, and the list states "Mostrando 21–40 de 45"

#### Scenario: Changing the page size
- **WHEN** a user on page 3 changes the page size to 50
- **THEN** the list shows page 1 with up to 50 notes

#### Scenario: Changing a filter
- **WHEN** a user on page 2 changes the search text, tag or type filter
- **THEN** the list shows page 1 of the new results

#### Scenario: Back button restores the page
- **WHEN** a user on page 3 opens a note and then goes back
- **THEN** the list shows page 3 again with the same filters and page size

#### Scenario: Single page of results
- **WHEN** all of a user's matching notes fit on one page
- **THEN** no page navigation controls are shown

#### Scenario: Requested page no longer exists
- **WHEN** a user opens an address for a page beyond the last one, for example after deleting notes
- **THEN** the list shows the last existing page instead of an empty list

#### Scenario: Page controls on a phone
- **WHEN** a user views a list with many pages on a screen 360px wide
- **THEN** the page controls fit on screen without horizontal scrolling

### Requirement: Every note on the page is fully visible
The notes list SHALL display every note of the current page in full: no note may remain hidden, transparent, clipped or overlapped by another element after the list has loaded or changed, whatever the number of notes, screen size or navigation that led to it.

#### Scenario: Page with many notes
- **WHEN** a user opens a page containing 20 notes of mixed types
- **THEN** all 20 notes are shown completely and none is partially or fully hidden

#### Scenario: List changes while it is being shown
- **WHEN** the list is replaced quickly several times, such as when changing filters or pages in succession, navigating from another section, or after creating a note
- **THEN** once the final list is shown, all of its notes are fully visible

## MODIFIED Requirements

### Requirement: Operation feedback
The web app SHALL show a brief, non-blocking notification in Spanish after each create, update, delete, or tag operation, and after any unexpected server or network error, including a response that does not come from the API, and SHALL never show the user a raw technical parsing or transport error.

#### Scenario: Successful operation
- **WHEN** a user saves an edited note
- **THEN** a success notification is shown

#### Scenario: Unexpected failure
- **WHEN** a request fails with a server error or the network is unreachable
- **THEN** an error notification in Spanish is shown and the user is not left without feedback

#### Scenario: Response that is not from the API
- **WHEN** a request to the API receives a web page or any other response that is not a valid API response, even with a success status
- **THEN** the app treats it as a failure and shows a Spanish message saying the server could not be reached, never a message such as "Unexpected token '<'"
