# Spec Delta

## ADDED Requirements

### Requirement: Password recovery by email
The system SHALL let a user who forgot their password request a recovery link by email and use it once, within one hour, to set a new password that meets the registration password rules, without revealing whether an email address has an account.

#### Scenario: Recovery requested for a registered email
- **WHEN** a visitor requests password recovery for the email of an existing account
- **THEN** the system sends that address an email from "Synap" containing a single-use link to set a new password, valid for one hour

#### Scenario: Recovery requested for an unknown email
- **WHEN** a visitor requests password recovery for an email with no account
- **THEN** the system returns the same response as for a registered email and sends nothing

#### Scenario: Password reset with a valid link
- **WHEN** a user opens a valid, unexpired recovery link and submits a new password that meets the password rules
- **THEN** the system sets the new password, subsequent logins succeed only with it, and the link can no longer be used

#### Scenario: Expired, used or unknown link
- **WHEN** a user submits a new password with a recovery link that has expired, was already used, or never existed
- **THEN** the system rejects it with the same Spanish message for every case and the password stays the same

#### Scenario: Newer request invalidates older links
- **WHEN** a user requests recovery twice and then uses the link from the first email
- **THEN** the system rejects it, because only the most recent link is valid

#### Scenario: Invalid new password
- **WHEN** a user submits, through a valid link, a new password that does not meet the password rules
- **THEN** the system rejects it with a Spanish validation message and the link remains usable until it expires

### Requirement: Password changes end other sessions
The system SHALL end every existing session of a user when their password is changed, whether through password recovery or from the account settings, while keeping the personal access token for the iOS Shortcut valid.

#### Scenario: Sessions ended after a reset
- **WHEN** a user resets their password through a recovery link
- **THEN** every session token issued before the reset stops being accepted

#### Scenario: Current session kept after changing the password
- **WHEN** a signed-in user changes their password from the account settings
- **THEN** their sessions on other devices stop being accepted, while the session they used to change it continues working

#### Scenario: Personal access token unaffected
- **WHEN** a user's password is changed or reset
- **THEN** their personal access token for the iOS Shortcut keeps working

## MODIFIED Requirements

### Requirement: Authentication attempt limiting
The system SHALL limit the number of login, registration and password-recovery attempts from the same client address within a time window, and the number of recovery emails per email address, rejecting excess attempts without evaluating them.

#### Scenario: Too many login attempts
- **WHEN** a client exceeds the allowed number of login attempts within the window
- **THEN** further attempts are rejected with a "too many requests" response and a Spanish message indicating to wait, until the window resets

#### Scenario: Normal usage unaffected
- **WHEN** a user logs in a small number of times within the window
- **THEN** every attempt is evaluated normally

#### Scenario: Too many recovery requests for one email
- **WHEN** recovery is requested for the same email address more times than allowed within an hour, from any number of clients
- **THEN** no further recovery emails are sent to that address until the hour passes, and the response gives no indication that the limit was reached
