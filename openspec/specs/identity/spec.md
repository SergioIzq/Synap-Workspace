# identity Specification

## Purpose

Lets each person have their own private, isolated Synap vault behind a login, with open self-registration so classmates can join without an invite step.

## Requirements

### Requirement: User registration
The system SHALL allow a new user to register an account using an email and password, with no invite code required.

#### Scenario: Successful registration
- **WHEN** a visitor submits a unique email and a valid password
- **THEN** the system creates a new account with an empty, isolated vault for that user

#### Scenario: Duplicate email rejected
- **WHEN** a visitor submits an email that is already registered
- **THEN** the system rejects the registration and does not create a second account

### Requirement: User authentication
The system SHALL allow a registered user to authenticate with their email and password and receive an access token for subsequent API requests.

#### Scenario: Successful login
- **WHEN** a registered user submits their correct email and password
- **THEN** the system issues an access token that identifies that user

#### Scenario: Invalid credentials rejected
- **WHEN** a user submits an incorrect password or an unregistered email
- **THEN** the system rejects the authentication attempt and issues no token

### Requirement: Authenticated access to the vault
The system SHALL require a valid access token on every knowledge-vault and ai-assistant operation.

#### Scenario: Unauthenticated request rejected
- **WHEN** a request to a vault or assistant endpoint carries no valid access token
- **THEN** the system rejects the request without performing the operation

### Requirement: Per-user data isolation
The system SHALL ensure that a user's notes, tags, embeddings and assistant answers are never visible to, searchable by, or returned to any other user.

#### Scenario: Cross-user isolation
- **WHEN** user A searches, browses, or asks the assistant a question
- **THEN** the system only considers and returns data belonging to user A, never data belonging to any other user

### Requirement: Current user profile
The system SHALL let an authenticated user retrieve their own profile (email and account creation date).

#### Scenario: Profile retrieved
- **WHEN** an authenticated user requests their profile
- **THEN** the system returns that user's email and account creation date, and nothing about any other user

### Requirement: Change password
The system SHALL let an authenticated user change their password after confirming their current password, applying the same password rules as registration.

#### Scenario: Password changed
- **WHEN** a user submits their correct current password and a valid new password
- **THEN** the system updates the password, and subsequent logins succeed only with the new password

#### Scenario: Wrong current password
- **WHEN** a user submits an incorrect current password
- **THEN** the system rejects the change and the password stays the same

#### Scenario: Invalid new password
- **WHEN** a user submits a new password that does not meet the registration password rules
- **THEN** the system rejects the change with a validation message in Spanish

### Requirement: Delete account
The system SHALL let an authenticated user permanently delete their account after confirming their password, removing all of their data: notes, tags, embeddings, stored Groq API key, and personal access token.

#### Scenario: Account deleted
- **WHEN** a user confirms account deletion with their correct password
- **THEN** the system removes the user and all their data, their existing session and personal access token stop working, and the email becomes available for a new registration

#### Scenario: Deletion with wrong password
- **WHEN** a user requests account deletion with an incorrect password
- **THEN** the system rejects the request and deletes nothing

#### Scenario: Other users unaffected
- **WHEN** a user deletes their account
- **THEN** no data belonging to any other user is modified or removed

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
