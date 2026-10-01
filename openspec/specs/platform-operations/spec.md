# platform-operations Specification

## Purpose

Defines the operational behavior of the Synap platform that operators and monitoring rely on, such as reporting whether the service and its dependencies are healthy.

## Requirements

### Requirement: Health reporting
The system SHALL expose an unauthenticated health endpoint that reports healthy only when the API, its database, and the AI service are reachable, and reports which dependency is failing otherwise, without exposing secrets or user data.

#### Scenario: All dependencies healthy
- **WHEN** the database and the AI service are reachable
- **THEN** the health endpoint reports a healthy status

#### Scenario: Database unreachable
- **WHEN** the database cannot be reached
- **THEN** the health endpoint reports an unhealthy status identifying the database as the failing dependency

#### Scenario: AI service unreachable
- **WHEN** the AI service cannot be reached but the database can
- **THEN** the health endpoint reports a degraded status identifying the AI service, since notes remain usable without it

### Requirement: Operational logs reachable where the system runs
The system SHALL write its operational log to the stream the deployment collects, so that whoever operates it can read it with the platform's own tooling without entering the running process's environment. A log that survives only inside a container's filesystem SHALL NOT be the only copy: recreating the process SHALL NOT be the act that destroys the record of why the previous one failed.

#### Scenario: Reading the log while operating
- **WHEN** an operator inspects the running system's log through the deployment's log collection
- **THEN** the operational records of the running system are there, not only its startup lines

#### Scenario: Record survives a restart
- **WHEN** the running process is replaced, as when applying new configuration
- **THEN** the records written before the replacement are still readable afterwards

### Requirement: A recorded failure names its own cause
When an operation fails, the record SHALL identify what actually failed. A failure that happens before any request leaves the system — an address that could not be built, configuration that is absent or invalid, a value rejected by the system itself — SHALL NOT be recorded as the remote party being unreachable or refusing the request. When a failure is classified into a broader category, the record SHALL keep the original cause that led to that classification.

#### Scenario: Failure before the request leaves
- **WHEN** an outbound call cannot be made because the address could not be built from configuration
- **THEN** the record says the request was never attempted and why, and does not attribute the failure to the destination

#### Scenario: Failure of an intermediate hop
- **WHEN** a call to an external provider fails at an intermediate component of the system rather than at the provider
- **THEN** the record identifies the component that failed, and does not attribute the failure to the provider

#### Scenario: Classified failure keeps its cause
- **WHEN** a failure is mapped onto a general category to decide how to react
- **THEN** the original cause reported by the failing party is preserved in the record alongside the category
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
