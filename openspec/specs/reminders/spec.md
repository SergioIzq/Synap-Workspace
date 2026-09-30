# reminders Specification

## Purpose

Closes the loop between capturing something and being told about it in time: a reminder is a short text with a due moment, optionally attached to a note, that Synap delivers to the user through Telegram when it falls due, and that the user can confirm, postpone or cancel.

## Requirements

### Requirement: A reminder is an owned text with a due moment
A reminder SHALL belong to exactly one user and consist of a non-empty text of at most 500 characters, a due moment stored as an instant in UTC, an optional link to one of that user's notes, and an optional recurrence. The system SHALL reject a reminder whose text is empty or too long, or whose due moment is not in the future, with a clear message in Spanish, storing nothing.

#### Scenario: Reminder created
- **WHEN** a user creates a reminder with the text "Renovar el certificado SSL" due at a future moment
- **THEN** it is stored as pending for that user with that text and that due moment

#### Scenario: Text too long
- **WHEN** a user creates a reminder with a text longer than 500 characters
- **THEN** the system rejects it with a Spanish message stating the maximum length, and nothing is stored

#### Scenario: Empty text
- **WHEN** a user creates a reminder whose text is empty or only whitespace
- **THEN** the system rejects it and nothing is stored

#### Scenario: Due moment in the past
- **WHEN** a user creates a reminder due at a moment that has already passed
- **THEN** the system rejects it with a Spanish message explaining the moment must be in the future, and nothing is stored

### Requirement: Recurring reminders repeat on a simple schedule
A reminder SHALL be either one-off or recurring, where a recurrence is one of: every day, every week on a given weekday, or every month on a given day between 1 and 28. Any other recurrence SHALL be rejected. A recurring reminder SHALL always have exactly one next due moment: once the user confirms an occurrence, the system SHALL compute the following due moment from the recurrence, keeping the same time of day, and the reminder SHALL become pending again for that moment.

#### Scenario: Daily reminder confirmed
- **WHEN** a user confirms an occurrence of a reminder that repeats every day at 09:00
- **THEN** the reminder becomes pending again for 09:00 of the following day

#### Scenario: Weekly reminder confirmed
- **WHEN** a user confirms an occurrence of a reminder that repeats every Monday at 18:00
- **THEN** the reminder becomes pending again for 18:00 of the next Monday

#### Scenario: Monthly reminder confirmed
- **WHEN** a user confirms an occurrence of a reminder that repeats on day 15 of every month
- **THEN** the reminder becomes pending again for day 15 of the following month at the same time of day

#### Scenario: Unsupported recurrence rejected
- **WHEN** a reminder is created with a recurrence other than daily, weekly on a weekday, or monthly on a day from 1 to 28 — for example "every weekday" or "the third Tuesday"
- **THEN** the system rejects it with a Spanish message, and nothing is stored

#### Scenario: Past occurrences are not kept
- **WHEN** a user looks at a recurring reminder after confirming several of its occurrences
- **THEN** only its next due moment is shown; the system does not keep a history of the occurrences already confirmed

### Requirement: Pending reminders are delivered when they fall due
The system SHALL deliver every pending reminder whose due moment has passed, within one minute of that moment, and SHALL mark it as delivered so it is never delivered twice for the same occurrence. When several reminders of the same or different users fall due together, all of them SHALL be delivered. Delivery SHALL survive a restart of the system: a reminder that fell due while the system was down SHALL be delivered once it is running again.

#### Scenario: Reminder delivered on time
- **WHEN** a pending reminder's due moment passes
- **THEN** the user receives it within one minute, and the reminder is marked as delivered

#### Scenario: Not delivered twice
- **WHEN** the system checks for due reminders again after having delivered one
- **THEN** that reminder is not delivered again for the same occurrence

#### Scenario: Several reminders due at once
- **WHEN** five reminders of different users fall due in the same minute
- **THEN** all five are delivered, each to its own user

#### Scenario: Due while the system was down
- **WHEN** the system starts after being down past a reminder's due moment
- **THEN** that reminder is delivered, and its lateness does not prevent delivery

### Requirement: Reminders are delivered to the user's linked Telegram chat
Telegram SHALL be the only delivery channel. A reminder SHALL only be delivered to the Telegram chat the owning user has linked; a user with no linked chat SHALL NOT receive deliveries, and the web app SHALL tell them their pending reminders cannot be delivered until they connect Telegram. When a reminder falls due and cannot be delivered because its owner has no linked chat, the system SHALL record that it was withheld, without repeating the record on every later check of the same reminder.

#### Scenario: Delivered to the linked chat
- **WHEN** a reminder of a user with a linked Telegram chat falls due
- **THEN** the message arrives in that chat and in no other

#### Scenario: No chat linked
- **WHEN** a user with no linked Telegram chat has pending reminders
- **THEN** the web app warns them that reminders will not arrive until they connect Telegram, and the reminders stay pending

#### Scenario: Due with no chat linked
- **WHEN** a reminder falls due and its owner has no linked Telegram chat
- **THEN** the reminder stays pending, the system records once that it was withheld for lack of a linked chat, and later checks of that same reminder do not repeat the record

### Requirement: A delivered reminder shows its text, its note and its options
The delivered message SHALL contain the reminder's text and, when the reminder is linked to a note, a link that opens that note in the web app. The message SHALL offer buttons to confirm the reminder and to postpone it, and, when the reminder is recurring, an additional button to cancel the whole series.

#### Scenario: Reminder linked to a note
- **WHEN** a reminder linked to a note is delivered
- **THEN** the message includes the reminder text and a link that opens that note

#### Scenario: Free-text reminder
- **WHEN** a reminder with no linked note is delivered
- **THEN** the message includes the reminder text and no note link

#### Scenario: Options on a one-off reminder
- **WHEN** a one-off reminder is delivered
- **THEN** the message offers to confirm it and to postpone it, and offers no option to cancel a series

#### Scenario: Options on a recurring reminder
- **WHEN** a recurring reminder is delivered
- **THEN** the message offers to confirm this occurrence, to postpone it, and to cancel the whole series

### Requirement: Confirming a delivered reminder
When the user confirms a delivered reminder, a one-off reminder SHALL stop being pending and never be delivered again, and a recurring one SHALL be scheduled for its next due moment. The message SHALL be updated to show it was confirmed, and confirming the same delivery again SHALL change nothing further.

#### Scenario: One-off confirmed
- **WHEN** a user confirms a delivered one-off reminder
- **THEN** it is no longer pending, it is not delivered again, and the message shows it as confirmed

#### Scenario: Recurring confirmed
- **WHEN** a user confirms a delivered recurring reminder
- **THEN** the message shows this occurrence as confirmed and the reminder is pending again for its next due moment

#### Scenario: Confirmed twice
- **WHEN** a user presses confirm again on a message they already confirmed
- **THEN** nothing further changes and no additional occurrence is scheduled

### Requirement: Postponing a delivered reminder
A delivered reminder SHALL be postponable to one of exactly three moments: one hour later, 09:00 the next day, or 09:00 one week later. Postponing SHALL make the reminder pending again for the chosen moment so it is delivered again then, and SHALL NOT change its recurrence. No other postponement interval SHALL be offered.

#### Scenario: Postponed an hour
- **WHEN** a user postpones a delivered reminder by one hour
- **THEN** it is pending again for one hour after that moment and is delivered again then

#### Scenario: Postponed to tomorrow
- **WHEN** a user postpones a delivered reminder to the next day
- **THEN** it is pending again for 09:00 of the following day in their own timezone

#### Scenario: Recurrence survives a postponement
- **WHEN** a user postpones an occurrence of a daily reminder to the next week
- **THEN** it is delivered again one week later, and it is still a daily reminder afterwards

### Requirement: Cancelling a recurring series
When the user cancels a recurring reminder from a delivered message, the whole series SHALL stop: the reminder SHALL no longer be pending and SHALL never be delivered again, and the message SHALL be updated to show the series was cancelled.

#### Scenario: Series cancelled
- **WHEN** a user cancels the series from a delivered recurring reminder
- **THEN** no further occurrence is ever delivered, and the message shows the series as cancelled

### Requirement: Connecting a Telegram account
The web app SHALL let the user connect their Telegram account from Settings. On request, the system SHALL issue a single-use code valid for 15 minutes and show the user how to send it to the bot. When the bot receives that code, the system SHALL link the sending chat to that user, invalidate the code, and confirm in the chat that reminders will arrive there. An expired, unknown or already-used code SHALL NOT link anything, and the user SHALL be able to request a new one. The web app SHALL show whether Telegram is currently connected.

#### Scenario: Account linked
- **WHEN** a user sends the code shown in Settings to the bot
- **THEN** their Telegram chat is linked, the bot confirms it in the chat, and Settings shows Telegram as connected

#### Scenario: Code is single use
- **WHEN** a code that has already linked a chat is sent again, from the same or another chat
- **THEN** nothing is linked

#### Scenario: Code expired
- **WHEN** a user sends the code more than 15 minutes after requesting it
- **THEN** nothing is linked, and the user can request a new code from Settings

#### Scenario: Unknown code
- **WHEN** someone sends the bot a code Synap never issued
- **THEN** nothing is linked and no information about any user is revealed

### Requirement: Disconnecting a Telegram account
The web app SHALL let the user disconnect their Telegram account from Settings. After disconnecting, no reminder SHALL be delivered to that chat, buttons on messages already delivered there SHALL no longer change anything, and the user's pending reminders SHALL be kept as pending. Connecting again SHALL require a new code, and the previous chat SHALL NOT be relinked on its own.

#### Scenario: Account disconnected
- **WHEN** a user disconnects Telegram from Settings
- **THEN** Settings shows Telegram as not connected, and their pending reminders are still pending

#### Scenario: No delivery after disconnecting
- **WHEN** a reminder of a user who has disconnected Telegram falls due
- **THEN** nothing is delivered to the chat they had linked, and the reminder stays pending

#### Scenario: Old buttons are inert
- **WHEN** a user presses confirm, postpone or cancel on a message delivered before they disconnected
- **THEN** nothing changes, and the reminder keeps its state

#### Scenario: Connecting again
- **WHEN** a user who has disconnected wants Telegram back
- **THEN** they request a new code from Settings and send it to the bot, and the code they used before does not link anything

### Requirement: Managing reminders from the web app
The web app SHALL provide a "Recordatorios" section where the user can see all of their pending reminders with their due moment shown in their own timezone, the note each one is linked to, and its recurrence; create a reminder by choosing a moment and, optionally, a recurrence; change the text, the moment and the recurrence of a pending reminder; and cancel a pending reminder. Changes SHALL be subject to the same validation as creation.

#### Scenario: Pending reminders listed
- **WHEN** a user opens the "Recordatorios" section
- **THEN** their pending reminders are listed, soonest first, each showing its due moment in their own timezone, its recurrence if any, and the note it is linked to if any

#### Scenario: Reminder created from the web app
- **WHEN** a user creates a reminder for a future moment with a weekly recurrence
- **THEN** it appears in the list as pending with that moment and recurrence, and is delivered when it falls due

#### Scenario: Reminder edited
- **WHEN** a user changes the moment of a pending reminder
- **THEN** it is delivered at the new moment and not at the old one

#### Scenario: Invalid edit rejected
- **WHEN** a user changes a pending reminder's moment to one that has already passed
- **THEN** the change is rejected with a Spanish message, and the reminder keeps its previous moment

#### Scenario: Reminder cancelled
- **WHEN** a user cancels a pending reminder
- **THEN** it disappears from the list and is never delivered

### Requirement: Reminders created from a note
The web app SHALL let the user create a reminder directly from one of their notes, without going through the assistant, with that note already linked. A note SHALL be able to have more than one reminder at the same time, and its reminders SHALL be visible from the note.

#### Scenario: Reminder created from a note
- **WHEN** a user creates a reminder from one of their notes
- **THEN** the reminder is linked to that note, and the delivered message will link back to it

#### Scenario: Several reminders on one note
- **WHEN** a user creates a second reminder on a note that already has one
- **THEN** both exist as pending reminders on that note, and each is delivered at its own moment

### Requirement: A deleted note leaves its reminders standing
When a note with reminders is deleted, its reminders SHALL be kept and still delivered, with their link to the note removed. Deleting a user SHALL delete all of their reminders.

#### Scenario: Linked note deleted
- **WHEN** a user deletes a note that had a pending reminder
- **THEN** the reminder is still pending and is delivered with its text, without a note link

#### Scenario: User deleted
- **WHEN** a user's account is deleted
- **THEN** all of their reminders are removed and none is ever delivered

### Requirement: Reminders never cross users
Every reminder SHALL only ever be read, changed, cancelled, confirmed, postponed or delivered for the user who owns it. A reminder identifier, a note identifier or a Telegram chat belonging to another user SHALL be treated as if it did not exist.

#### Scenario: Another user's reminder
- **WHEN** a user tries to read, edit or cancel a reminder identifier that belongs to another user
- **THEN** the system responds as if the reminder did not exist, and the reminder is unchanged

#### Scenario: Another user's note linked
- **WHEN** a reminder is created with a note identifier that belongs to another user
- **THEN** the system rejects it as a note that does not exist, and nothing is stored

#### Scenario: Action from an unlinked chat
- **WHEN** a confirm, postpone or cancel action reaches the system from a Telegram chat that is not the one linked to the reminder's owner
- **THEN** nothing changes, and the reminder keeps its state

### Requirement: Delivery failures do not lose a reminder
When delivery to Telegram fails, the reminder SHALL stay pending and be attempted again on the following checks, and the failure SHALL be recorded in the system's logs with the reminder and the reason it actually failed. A reason SHALL NOT be reported as the messaging provider being unreachable when the request was never sent to it. A failure delivering one reminder SHALL NOT prevent the other reminders due at that moment from being delivered.

#### Scenario: Delivery fails once
- **WHEN** delivering a due reminder fails because Telegram is unreachable
- **THEN** the reminder stays pending, the failure is logged as the provider being unreachable, and it is delivered on a later attempt

#### Scenario: Bot blocked by the user
- **WHEN** delivering fails because the user has blocked the bot
- **THEN** the reminder stays pending, the failure is logged with that reason, and the other due reminders are still delivered

#### Scenario: Request never sent
- **WHEN** delivering fails before any request reaches Telegram, such as invalid or absent delivery configuration
- **THEN** the reminder stays pending and the failure is logged as a request that was never sent, naming that cause rather than reporting Telegram as unreachable

### Requirement: Reminders are inert while delivery is turned off
The system SHALL run with Telegram delivery turned off by configuration. In that state no reminder SHALL be delivered and no Telegram request SHALL be made, while creating, listing, editing and cancelling reminders SHALL keep working, and reminders that fell due SHALL stay pending and be delivered once delivery is turned on.

#### Scenario: Delivery turned off
- **WHEN** reminders fall due while Telegram delivery is turned off
- **THEN** nothing is delivered, no Telegram request is made, and the reminders stay pending

#### Scenario: Delivery turned on again
- **WHEN** Telegram delivery is turned on after reminders have fallen due
- **THEN** those reminders are delivered

### Requirement: A rejected webhook call is recorded
When the system rejects a call to the Telegram webhook, it SHALL record that it did and which condition caused the rejection — delivery being turned off, or a shared secret that does not match. The response to the caller SHALL NOT change: it stays a bare rejection that reveals nothing about the configuration.

#### Scenario: Rejected because delivery is off
- **WHEN** a call reaches the webhook while Telegram delivery is turned off
- **THEN** the call is rejected, the response reveals nothing, and the system records that the rejection was because delivery is off

#### Scenario: Rejected because the secret does not match
- **WHEN** a call reaches the webhook carrying a shared secret that does not match the configured one, or none at all
- **THEN** the call is rejected, the response reveals nothing, and the system records that the rejection was because the secret did not match
