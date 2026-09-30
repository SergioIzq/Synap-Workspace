# Spec Delta

## ADDED Requirements

### Requirement: A rejected webhook call is recorded
When the system rejects a call to the Telegram webhook, it SHALL record that it did and which condition caused the rejection — delivery being turned off, or a shared secret that does not match. The response to the caller SHALL NOT change: it stays a bare rejection that reveals nothing about the configuration.

#### Scenario: Rejected because delivery is off
- **WHEN** a call reaches the webhook while Telegram delivery is turned off
- **THEN** the call is rejected, the response reveals nothing, and the system records that the rejection was because delivery is off

#### Scenario: Rejected because the secret does not match
- **WHEN** a call reaches the webhook carrying a shared secret that does not match the configured one, or none at all
- **THEN** the call is rejected, the response reveals nothing, and the system records that the rejection was because the secret did not match

## MODIFIED Requirements

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
