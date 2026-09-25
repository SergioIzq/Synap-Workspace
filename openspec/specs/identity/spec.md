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
The system SHALL limit the number of login and registration attempts from the same client address within a time window, rejecting excess attempts without evaluating them.

#### Scenario: Too many login attempts
- **WHEN** a client exceeds the allowed number of login attempts within the window
- **THEN** further attempts are rejected with a "too many requests" response and a Spanish message indicating to wait, until the window resets

#### Scenario: Normal usage unaffected
- **WHEN** a user logs in a small number of times within the window
- **THEN** every attempt is evaluated normally
