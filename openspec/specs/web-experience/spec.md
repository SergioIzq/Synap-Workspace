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
The web app SHALL show a brief, non-blocking notification in Spanish after each create, update, delete, or tag operation, and after any unexpected server or network error.

#### Scenario: Successful operation
- **WHEN** a user saves an edited note
- **THEN** a success notification is shown

#### Scenario: Unexpected failure
- **WHEN** a request fails with a server error or the network is unreachable
- **THEN** an error notification in Spanish is shown and the user is not left without feedback

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
