# user-settings Specification

## Purpose

Lets each user manage their own personal configuration: the Groq API key and model the assistant uses on their behalf, and the personal access token used by the iOS Shortcut.

## Requirements

### Requirement: Store a personal Groq API key
The system SHALL let an authenticated user save their own Groq API key, validating it against Groq before storing it, and SHALL store it encrypted at rest.

#### Scenario: Valid key saved
- **WHEN** a user submits a Groq API key that Groq accepts
- **THEN** the system stores it encrypted, associated only with that user, and reports the key as configured

#### Scenario: Invalid key rejected
- **WHEN** a user submits a Groq API key that Groq rejects as invalid
- **THEN** the system does not store it, keeps any previously stored key unchanged, and returns a clear validation error in Spanish

#### Scenario: Groq unreachable during validation
- **WHEN** a user submits a key and Groq cannot be reached to validate it
- **THEN** the system does not store it and tells the user validation could not be completed and to retry later

#### Scenario: Key replaced
- **WHEN** a user who already has a stored key submits a new valid key
- **THEN** the system replaces the old key with the new one

### Requirement: Stored key is never disclosed
The system SHALL never return a stored Groq API key in plaintext through any API response or log entry; it SHALL only expose whether a key is configured, a masked form showing at most its last four characters, and when it was last updated.

#### Scenario: Settings read after saving a key
- **WHEN** a user with a stored key requests their settings
- **THEN** the response indicates the key is configured and includes only its masked form and last update date, never the full key

#### Scenario: Keys isolated between users
- **WHEN** any user requests their settings or uses the assistant
- **THEN** the system never reveals or uses another user's key

### Requirement: Remove the personal Groq API key
The system SHALL let a user delete their stored Groq API key.

#### Scenario: Key removed
- **WHEN** a user deletes their stored key
- **THEN** the system erases it and reports the key as not configured, and the assistant becomes unavailable to that user until a new key is saved

### Requirement: Choose the assistant model
The system SHALL let a user with a configured key choose which Groq chat model the assistant uses for them, from the chat models available to their key; when no model is chosen, the server's default model SHALL be used.

#### Scenario: Available models listed
- **WHEN** a user with a configured key requests the list of models
- **THEN** the system returns the chat-capable models Groq exposes for that key

#### Scenario: Model selected
- **WHEN** a user selects a model from the available list
- **THEN** subsequent assistant answers for that user are generated with that model

#### Scenario: Unknown model rejected
- **WHEN** a user selects a model identifier that is not available to their key
- **THEN** the system rejects the selection and keeps the previous choice

#### Scenario: Default model used
- **WHEN** a user has a configured key but never selected a model
- **THEN** the assistant uses the server's default model

### Requirement: Settings page in the web app
The web app SHALL provide a Settings page reachable from the main navigation, containing an AI assistant section (Groq key status, save/replace/delete, link to obtain a key, model selector), an iOS Shortcut section (personal access token status, generate/regenerate, copy) and an account section (user email).

#### Scenario: Settings reachable from navigation
- **WHEN** an authenticated user opens the main navigation
- **THEN** a "Configuración" entry is present and leads to the Settings page

#### Scenario: Personal access token generated from the UI
- **WHEN** a user generates or regenerates their personal access token in the Settings page
- **THEN** the plaintext token is shown once with a copy action, and the previous token stops working

#### Scenario: Token not shown again
- **WHEN** a user returns to the Settings page after generating a token
- **THEN** the page shows only whether a token exists and since when, never its value
