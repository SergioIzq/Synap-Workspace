# Spec Delta

## MODIFIED Requirements

### Requirement: Choose the assistant model
The system SHALL let a user with a configured key choose which Groq chat model the assistant uses for them, from the chat models available to their key; when no model is chosen, the server's default model SHALL be used. The list of models SHALL indicate which ones support assistant actions.

#### Scenario: Available models listed
- **WHEN** a user with a configured key requests the list of models
- **THEN** the system returns the chat-capable models Groq exposes for that key, each marked as supporting assistant actions or not

#### Scenario: Model selected
- **WHEN** a user selects a model from the available list
- **THEN** subsequent assistant answers for that user are generated with that model

#### Scenario: Unknown model rejected
- **WHEN** a user selects a model identifier that is not available to their key
- **THEN** the system rejects the selection and keeps the previous choice

#### Scenario: Default model used
- **WHEN** a user has a configured key but never selected a model
- **THEN** the assistant uses the server's default model

#### Scenario: Action support shown in the picker
- **WHEN** a user opens the model selector in the Settings page
- **THEN** models that support assistant actions are marked as such, and choosing one that does not shows that the assistant will only answer questions with it

### Requirement: Settings page in the web app
The web app SHALL provide a Settings page reachable from the main navigation, containing an AI assistant section (Groq key status, save/replace/delete, link to obtain a key, model selector), a "Memoria" section (the user's assistant memory entries), an iOS Shortcut section (personal access token status, generate/regenerate, copy) and an account section (user email).

#### Scenario: Settings reachable from navigation
- **WHEN** an authenticated user opens the main navigation
- **THEN** a "Configuración" entry is present and leads to the Settings page

#### Scenario: Memory section present
- **WHEN** a user opens the Settings page
- **THEN** the "Memoria" section is shown, whether or not a Groq key is configured

#### Scenario: Personal access token generated from the UI
- **WHEN** a user generates or regenerates their personal access token in the Settings page
- **THEN** the plaintext token is shown once with a copy action, and the previous token stops working

#### Scenario: Token not shown again
- **WHEN** a user returns to the Settings page after generating a token
- **THEN** the page shows only whether a token exists and since when, never its value
