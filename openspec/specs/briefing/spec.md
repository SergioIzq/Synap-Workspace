# briefing Specification

## Purpose

Tells a user, once each morning and without being asked, what their notes and reminders have waiting for them that day, so that nothing they captured and forgot stays invisible until they happen to search for it.

## Requirements

### Requirement: A briefing is sent once a day at the hour the user chose
The system SHALL send an enabled user one briefing of its own accord per calendar day, on the day as it falls in that user's own timezone, at or after the local hour they chose. It SHALL NOT send a second briefing for a day it has already sent one for, whatever happens in between — the process restarting, the sweep running more than once, or delivery being retried. When the hour passes while the system is not running, or delivery cannot be attempted, the briefing SHALL still be sent later the same local day, and SHALL NOT be sent once that day is over.

#### Scenario: Sent at the chosen hour
- **WHEN** the local time in a user's timezone reaches the hour they chose, and they have not had a briefing today
- **THEN** their briefing is sent to their linked Telegram chat, and the day is recorded as briefed

#### Scenario: Not sent twice in a day
- **WHEN** the sweep runs again later the same local day for a user who has already been briefed
- **THEN** no second briefing is sent

#### Scenario: Before the chosen hour
- **WHEN** the sweep runs on a local day whose chosen hour has not arrived yet
- **THEN** no briefing is sent, and the day stays unbriefed

#### Scenario: The system was down at the hour
- **WHEN** the system starts again on the same local day, after the chosen hour has passed unattended
- **THEN** the briefing for that day is sent

#### Scenario: The day is over
- **WHEN** the system starts again on the following local day, having missed yesterday's hour entirely
- **THEN** yesterday's briefing is not sent, and only the new day's is considered

#### Scenario: Each user on their own clock
- **WHEN** two users in different timezones have chosen the same local hour
- **THEN** each is briefed when that hour arrives where they are, not at the same instant

### Requirement: What a briefing contains
A briefing SHALL report, for the user it belongs to and no one else: the reminders that fall due on that local day, the notes created recently that carry no tag, and the notes whose text shows something left open. Every item SHALL be identifiable — a reminder by its text and its local due time, a note by its title or, having none, by a preview of its text. Each section SHALL be left out when it has nothing in it, and a count SHALL say how many items a section stands for when it shows only some of them.

#### Scenario: Today's reminders
- **WHEN** a user has reminders falling due on the local day being briefed
- **THEN** the briefing lists them with their text and the local time they are due

#### Scenario: Untagged notes
- **WHEN** a user has recently created notes that carry no tag
- **THEN** the briefing lists them, identified by title or by a preview when they have no title

#### Scenario: Open threads
- **WHEN** a user has notes whose text shows something left open
- **THEN** the briefing lists them, identified the same way

#### Scenario: An empty section is left out
- **WHEN** a user has nothing to report in one of the sections
- **THEN** that section does not appear in the briefing at all, rather than appearing empty

#### Scenario: More items than are shown
- **WHEN** a section has more items than the briefing shows
- **THEN** the briefing says how many there are in total

#### Scenario: A briefing never crosses users
- **WHEN** a briefing is built for a user
- **THEN** it contains only that user's own notes and reminders

### Requirement: Nothing to report means nothing is sent unasked
When a briefing the system sends of its own accord would contain no items in any of its sections, it SHALL NOT be sent, and SHALL treat the day as briefed so that the same empty day is not reconsidered later. A daily message that arrives with nothing in it trains the user to stop reading it.

#### Scenario: Empty day
- **WHEN** the chosen hour arrives for a user with no reminders due, no untagged notes and no open threads
- **THEN** no message is sent, and no second attempt is made for that day

#### Scenario: Items appear later the same day
- **WHEN** a user whose day was passed over as empty creates notes later that same day
- **THEN** they are not briefed again that day; those items are considered for the following day's briefing

### Requirement: The briefing is off until the user turns it on
The system SHALL NOT send briefings to a user who has not asked for them. An authenticated user SHALL be able to turn the briefing on and off and to choose the local hour it arrives, SHALL be shown its current state, and the setting SHALL be theirs alone. Turning it off SHALL stop delivery from that moment, without deleting anything.

#### Scenario: Off by default
- **WHEN** a user has never configured the briefing
- **THEN** they receive none, whatever their notes contain

#### Scenario: Turning it on
- **WHEN** a user turns the briefing on and chooses a local hour
- **THEN** the setting is stored for that user, and the briefing arrives from the next time that hour comes round

#### Scenario: Changing the hour
- **WHEN** a user who has already been briefed today moves the hour to a later one that same day
- **THEN** no second briefing is sent today, and tomorrow's arrives at the new hour

#### Scenario: Turning it off
- **WHEN** a user turns the briefing off
- **THEN** no further briefings are sent, and their notes, reminders and settings are otherwise unchanged

#### Scenario: One user's setting is not another's
- **WHEN** a user turns the briefing on
- **THEN** no other user's briefing setting changes

### Requirement: A briefing that cannot be delivered says so rather than vanishing
Telegram SHALL be the only channel. A user who has turned the briefing on but has no linked Telegram chat SHALL NOT be briefed, SHALL be told in the web app that the briefing cannot arrive until they connect Telegram, and the system SHALL record that it was withheld — once for that user, not on every sweep. When delivery is attempted and fails, the failure SHALL be recorded with the reason it actually failed, the day SHALL NOT be recorded as briefed, and the briefing SHALL be attempted again while the local day lasts. A failure for one user SHALL NOT stop the other users due at that moment from being briefed.

#### Scenario: Briefing on, Telegram not connected
- **WHEN** the chosen hour arrives for a user who has turned the briefing on but has no linked Telegram chat
- **THEN** nothing is sent, the web app tells them to connect Telegram for it to arrive, and the system records once that the briefing was withheld

#### Scenario: Delivery fails
- **WHEN** sending a briefing to Telegram fails
- **THEN** the failure is recorded with its actual cause, the day is not recorded as briefed, and it is attempted again later the same local day

#### Scenario: One failure does not stop the rest
- **WHEN** sending one user's briefing fails while other users are due at the same moment
- **THEN** the other users are still briefed

#### Scenario: Delivery turned off for the deployment
- **WHEN** Telegram delivery is turned off for the whole deployment
- **THEN** no briefings are sent and none are recorded as sent, exactly as reminders behave in that state

### Requirement: A briefing can be asked for at any moment
A user SHALL be able to ask for their briefing on demand and receive it straight away, from the web app and from the messaging bot alike, and it SHALL be the same briefing the system would send of its own accord, built from their data as it stands at that moment. Asking for one SHALL NOT count as the day's automatic briefing: the automatic one still arrives at its hour, and the user MAY ask as many times as they like. Unlike the automatic one, a briefing that was asked for SHALL always answer, saying plainly that there is nothing to report when there is nothing — a request that produces silence is indistinguishable from one that failed. It SHALL be subject to the same delivery conditions and SHALL contain only the asking user's own data.

#### Scenario: Asked for from the web app
- **WHEN** a user asks for their briefing from the web app
- **THEN** it is built from their data as it stands and delivered to their linked chat

#### Scenario: Asked for from the bot
- **WHEN** a user who has linked their chat asks the bot for their briefing
- **THEN** the same briefing is delivered to that chat

#### Scenario: Asking does not consume the day
- **WHEN** a user asks for their briefing before the hour they chose, and that hour later arrives
- **THEN** the automatic briefing is still sent that day

#### Scenario: Asked for twice
- **WHEN** a user asks for their briefing again minutes after the last one
- **THEN** it is delivered again, rebuilt from their data at that moment

#### Scenario: Asked for with nothing to report
- **WHEN** a user asks for their briefing on a day with no reminders due, no untagged notes and no open threads
- **THEN** they are told there is nothing to report, rather than receiving no answer

#### Scenario: Asked for before the briefing was ever turned on
- **WHEN** a user who has never turned the briefing on asks for one
- **THEN** it is delivered, because asking is not the same as subscribing, and no automatic briefing starts arriving

#### Scenario: Asked for without a linked chat
- **WHEN** a user with no linked Telegram chat asks for their briefing from the web app
- **THEN** nothing is sent and they are told to connect Telegram first

#### Scenario: The bot is asked by an unknown chat
- **WHEN** a chat that is not linked to any account asks the bot for a briefing
- **THEN** no briefing is sent and the reply reveals nothing about any account

#### Scenario: A requested briefing never crosses users
- **WHEN** a user asks for their briefing
- **THEN** it contains only their own notes and reminders, whichever way they asked
