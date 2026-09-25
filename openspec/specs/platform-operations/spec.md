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
