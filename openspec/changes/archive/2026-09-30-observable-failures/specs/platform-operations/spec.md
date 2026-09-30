# Spec Delta

## ADDED Requirements

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
