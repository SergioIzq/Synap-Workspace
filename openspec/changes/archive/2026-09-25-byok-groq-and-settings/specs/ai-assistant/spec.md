# Spec Delta

## ADDED Requirements

### Requirement: Answers generated with the user's own credentials
The system SHALL generate assistant answers exclusively with the requesting user's own stored Groq API key and chosen model, and SHALL NOT use any shared or server-owned generation key.

#### Scenario: Answer uses the user's key
- **WHEN** a user with a configured key asks a question that has relevant notes
- **THEN** the answer is generated using that user's key and chosen model

#### Scenario: No shared fallback key
- **WHEN** a user without a configured key asks a question
- **THEN** the system does not fall back to any other key and does not contact the generation provider

### Requirement: Assistant requires a configured key
The system SHALL refuse assistant questions from a user who has no Groq API key configured, and the web app SHALL warn the user and point them to Settings before they try to ask.

#### Scenario: Question without a key rejected
- **WHEN** a user without a configured key submits a question
- **THEN** the system returns a result indicating that a key must be configured, without generating an answer

#### Scenario: Warning shown on entering the assistant
- **WHEN** a user without a configured key opens the assistant page
- **THEN** the page shows a warning explaining that a personal Groq API key is needed, with a direct link to the Settings page, and the question input is disabled

#### Scenario: Assistant unlocked after configuring a key
- **WHEN** a user saves a valid key and returns to the assistant page
- **THEN** the warning is no longer shown and the user can ask questions

## MODIFIED Requirements

### Requirement: Graceful handling of generation provider failure
The system SHALL handle unavailability, rate-limiting, or credential rejection by the external answer-generation provider without exposing a broken or partial response, and SHALL tell the user which of these occurred, in Spanish.

#### Scenario: Generation provider unavailable
- **WHEN** the external generation provider is unreachable or fails at the time of a query
- **THEN** the system returns a clear message that the assistant is temporarily unavailable, rather than a broken or partial answer

#### Scenario: User's key rejected by the provider
- **WHEN** the provider rejects the user's stored key (revoked or invalid)
- **THEN** the system returns a message stating the key is no longer valid and that it must be updated in Settings, rather than a generic error

#### Scenario: User's quota or rate limit exhausted
- **WHEN** the provider rejects the request because the user's key has exceeded its rate limit or quota
- **THEN** the system returns a message stating the user's Groq quota has been reached and to try again later
