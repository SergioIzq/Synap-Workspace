# web-experience Specification

## Purpose

Defines the cross-cutting behavior of the Synap web app that users rely on regardless of feature: usable navigation on any screen size, theme preference, safe handling of destructive actions, feedback on operations, and a consistent language.

## Requirements

### Requirement: Navigation adapts to screen size
The web app SHALL provide full navigation (Notes, Assistant, Settings, sign out) on both desktop and mobile screens, without horizontal scrolling at widths of 360px and above.

#### Scenario: Mobile navigation
- **WHEN** an authenticated user uses the app on a screen narrower than 768px
- **THEN** the main sections are reachable from a bottom navigation bar that stays visible and clear of the device's safe areas, and no page requires horizontal scrolling

#### Scenario: Desktop navigation
- **WHEN** an authenticated user uses the app on a screen 768px or wider
- **THEN** the main sections are reachable from a side navigation panel

### Requirement: Theme preference
The web app SHALL let the user choose between light, dark, and system theme, remember the choice on that device, and apply it on load without first showing the other theme.

#### Scenario: Dark theme chosen
- **WHEN** a user selects the dark theme in Settings
- **THEN** the whole app switches to dark colors immediately and stays dark after reloading

#### Scenario: System theme followed
- **WHEN** a user has the system option selected and their operating system switches between light and dark
- **THEN** the app follows the operating system's appearance

### Requirement: Destructive actions require confirmation
The web app SHALL ask for explicit confirmation before deleting a note, deleting the Groq API key, or regenerating the personal access token.

#### Scenario: Note deletion confirmed
- **WHEN** a user chooses to delete a note and confirms
- **THEN** the note is deleted and the user sees a success notification

#### Scenario: Note deletion cancelled
- **WHEN** a user chooses to delete a note and cancels the confirmation
- **THEN** the note is not deleted

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

### Requirement: Unknown routes
The web app SHALL show a "page not found" screen for unknown addresses, with a way back to the notes.

#### Scenario: Unknown address visited
- **WHEN** a user navigates to an address that does not exist in the app
- **THEN** a not-found page is shown with a link back to Notes

### Requirement: Single interface language
All user-visible text in the web app, including messages originating from the backend, SHALL be in Spanish.

#### Scenario: Backend message displayed
- **WHEN** the app displays a message received from the backend or AI service
- **THEN** that message is in Spanish

### Requirement: Recognisable app identity
The web app SHALL present itself as "Synap" with the Synap logo in browser tabs, bookmarks, and when installed on a phone or desktop, in both light and dark browser themes.

#### Scenario: Browser tab
- **WHEN** a user opens the app in a browser
- **THEN** the tab shows the Synap logo and the title "Synap"

#### Scenario: Installed app
- **WHEN** a user adds the app to their home screen on iOS or installs it on Android or desktop
- **THEN** the launcher shows the name "Synap" and the Synap logo, not a framework's default icon

### Requirement: Note summaries show type and age
The notes list SHALL show, for each note, what kind of note it is and how long ago it was created, and bookmark notes SHALL show the linked site.

#### Scenario: Different note types are distinguishable
- **WHEN** a user's list contains a text note, a code snippet and a bookmark
- **THEN** each is displayed with its own type indicator, code snippets in a monospaced block, and bookmarks with the site's domain and, when available, its title and preview image

#### Scenario: Relative creation time
- **WHEN** a user views a note created two hours ago
- **THEN** its summary shows the age in Spanish, such as "hace 2 h"

### Requirement: Settings use the available width
The Settings page SHALL lay its sections out in more than one column on wide screens and in a single column on narrow ones.

#### Scenario: Laptop screen
- **WHEN** a user opens Settings on a screen at least 1200px wide
- **THEN** the sections are arranged in two columns without horizontal scrolling

#### Scenario: Phone screen
- **WHEN** a user opens Settings on a screen narrower than 1200px
- **THEN** the sections are stacked in a single column

### Requirement: Keyboard shortcut to create a note
The web app SHALL open the note composer when the user presses "n" while not typing in a field.

#### Scenario: Shortcut from another page
- **WHEN** a signed-in user presses "n" on any app page while no input has focus
- **THEN** the notes page opens with the composer expanded and focused

#### Scenario: Typing is not hijacked
- **WHEN** a user types the letter "n" inside any text field
- **THEN** the letter is typed normally and nothing else happens

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
