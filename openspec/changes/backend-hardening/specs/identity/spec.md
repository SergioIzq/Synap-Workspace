# Spec Delta

## ADDED Requirements

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
