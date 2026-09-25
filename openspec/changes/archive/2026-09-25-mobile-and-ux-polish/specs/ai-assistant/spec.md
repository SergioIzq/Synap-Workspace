# Spec Delta

## ADDED Requirements

### Requirement: Navigable answer sources
The system SHALL return, with every grounded answer, the identifier and title of each source note used, and the web app SHALL display them as links to those notes.

#### Scenario: Sources shown with an answer
- **WHEN** the assistant returns an answer grounded in the user's notes
- **THEN** the answer lists each source note by title (or a content preview when it has no title), and selecting one opens that note

#### Scenario: Sources never cross users
- **WHEN** an answer lists its source notes
- **THEN** every listed note belongs to the requesting user

### Requirement: Conversation persists on the device
The web app SHALL keep the current assistant conversation across page reloads on the same device for the signed-in user, and SHALL let the user start a new conversation.

#### Scenario: Reload keeps the conversation
- **WHEN** a user reloads the assistant page
- **THEN** the previous questions and answers of the current conversation are still shown

#### Scenario: New conversation
- **WHEN** a user chooses "Nueva conversación"
- **THEN** the displayed conversation is cleared

#### Scenario: Conversation cleared on sign out
- **WHEN** a user signs out
- **THEN** the stored conversation is removed from the device, so the next user signing in on that device cannot see it
