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
