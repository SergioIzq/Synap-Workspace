# Spec Delta

## MODIFIED Requirements

### Requirement: Delete account
The system SHALL let an authenticated user permanently delete their account after confirming their password, removing all of their data: notes, tags, embeddings, assistant memory entries, stored Groq API key, and personal access token.

#### Scenario: Account deleted
- **WHEN** a user confirms account deletion with their correct password
- **THEN** the system removes the user and all their data, including their assistant memory, their existing session and personal access token stop working, and the email becomes available for a new registration

#### Scenario: Deletion with wrong password
- **WHEN** a user requests account deletion with an incorrect password
- **THEN** the system rejects the request and deletes nothing

#### Scenario: Other users unaffected
- **WHEN** a user deletes their account
- **THEN** no data belonging to any other user is modified or removed
