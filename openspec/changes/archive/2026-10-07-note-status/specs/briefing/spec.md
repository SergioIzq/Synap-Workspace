# Spec Delta

## MODIFIED Requirements

### Requirement: What a briefing contains
A briefing SHALL report, for the user it belongs to and no one else: the reminders that fall due on that local day, the notes the user has marked as in progress, the notes the user has marked as pending, and the notes created recently that carry no tag. A note the user has marked as paused SHALL NOT be reported while it was paused recently, and SHALL be reported among the pending notes once it has stood paused for longer than a period the system fixes, saying how long it has been paused. A note carrying no status SHALL NOT be reported as work. Every item SHALL be identifiable — a reminder by its text and its local due time, a note by its title or, having none, by a preview of its text. Each section SHALL be left out when it has nothing in it, and a count SHALL say how many items a section stands for when it shows only some of them.

#### Scenario: Today's reminders
- **WHEN** a user has reminders falling due on the local day being briefed
- **THEN** the briefing lists them with their text and the local time they are due

#### Scenario: Notes in progress
- **WHEN** a user has notes marked as in progress
- **THEN** the briefing lists them in a section of their own, identified by title or by a preview when they have no title

#### Scenario: Pending notes
- **WHEN** a user has notes marked as pending
- **THEN** the briefing lists them in a section of their own, separate from the notes in progress

#### Scenario: A recently paused note stays quiet
- **WHEN** a user has a note they paused recently
- **THEN** the briefing does not mention it at all

#### Scenario: A long-paused note resurfaces
- **WHEN** a user has a note that has stood paused for longer than the period the system fixes
- **THEN** the briefing lists it among the pending notes, saying how long it has been paused

#### Scenario: Open threads
- **WHEN** a user has notes whose text contains words such as "TODO", "pendiente" or "revisar", but carries no status
- **THEN** the briefing does not list them on account of what their text says: a note is reported as work only when the user marked it so

#### Scenario: A note without a status is not reported as work
- **WHEN** a user has notes that carry no status, whatever their text says
- **THEN** none of them appears among the notes in progress or the pending notes

#### Scenario: Completed notes are not reported
- **WHEN** a user has notes marked as completed
- **THEN** none of them appears in the briefing

#### Scenario: Untagged notes
- **WHEN** a user has recently created notes that carry no tag
- **THEN** the briefing lists them, identified by title or by a preview when they have no title

#### Scenario: An empty section is left out
- **WHEN** a user has nothing to report in one of the sections
- **THEN** that section does not appear in the briefing at all, rather than appearing empty

#### Scenario: Nothing marked at all
- **WHEN** a user has marked none of their notes with any status
- **THEN** neither the in-progress nor the pending section appears, and the rest of the briefing is unaffected

#### Scenario: More items than are shown
- **WHEN** a section has more items than the briefing shows
- **THEN** the briefing says how many there are in total

#### Scenario: A briefing never crosses users
- **WHEN** a briefing is built for a user
- **THEN** it contains only that user's own notes and reminders
