# Spec Delta

## MODIFIED Requirements

### Requirement: Store a personal Groq API key
The system SHALL let an authenticated user save their own Groq API key, validating it against Groq before storing it, and SHALL store it encrypted at rest. When validation cannot be completed, the message the user sees SHALL NOT attribute the failure to Groq unless Groq is what failed: a failure to reach or use Synap's own AI service SHALL be reported as such, and SHALL be distinguishable by whoever operates the system from Groq being unreachable.

#### Scenario: Valid key saved
- **WHEN** a user submits a Groq API key that Groq accepts
- **THEN** the system stores it encrypted, associated only with that user, and reports the key as configured

#### Scenario: Invalid key rejected
- **WHEN** a user submits a Groq API key that Groq rejects as invalid
- **THEN** the system does not store it, keeps any previously stored key unchanged, and returns a clear validation error in Spanish

#### Scenario: Groq unreachable during validation
- **WHEN** a user submits a key and Groq cannot be reached to validate it
- **THEN** the system does not store it and tells the user validation could not be completed and to retry later

#### Scenario: AI service unreachable during validation
- **WHEN** a user submits a key and Synap's own AI service cannot be reached, or rejects the request, before Groq is ever contacted
- **THEN** the system does not store it, the message does not blame Groq, and the recorded cause identifies the AI service as what failed

#### Scenario: Key replaced
- **WHEN** a user who already has a stored key submits a new valid key
- **THEN** the system replaces the old key with the new one
