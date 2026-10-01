# Spec Delta

## ADDED Requirements

### Requirement: Web app and API served from one origin in the self-hosted stack
When the platform is run with the project's Docker Compose stack, the web app's origin SHALL forward every request under `/api/` to the API, so that the web app works with its production configuration (API at the same origin, path `/api`) without any external reverse proxy. Deployments that do not enable this forwarding SHALL keep serving the web app exactly as before.

#### Scenario: Signing in on the Compose stack
- **WHEN** an operator starts the stack with Docker Compose and a user signs in through the web app's published port
- **THEN** the sign-in request reaches the API and a user with valid credentials is signed in

#### Scenario: API routes never answered by the web app
- **WHEN** a request under `/api/` reaches the web app's origin on the Compose stack
- **THEN** the response comes from the API, and the web app's HTML page is never returned for it

#### Scenario: Deployment without forwarding configured
- **WHEN** the web app container starts without an API upstream configured, as behind the production reverse proxy
- **THEN** it starts normally and serves the web app as before
