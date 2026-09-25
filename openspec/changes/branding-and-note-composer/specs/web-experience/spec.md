# Spec Delta

## ADDED Requirements

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
