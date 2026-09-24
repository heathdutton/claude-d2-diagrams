# Infrastructure template

Output: `./diagrams/infrastructure.md`. Readers: engineers who need what runs where, and the renderer, which draws a node for every component and an edge for every relationship listed here.

## What to trace

- **Inventory**: every resource in the IaC files, including ones defined inside modules and includes. Follow each module to its source.
- **Categorize**:
  - Compute: VMs, containers, functions, pods
  - Data: databases, caches, object stores, queues and streams
  - Network: VPCs, subnets that matter, load balancers, gateways, CDN, DNS
  - Security: IAM roles, secrets, KMS, security groups (only where they gate a connection)
  - External: third-party APIs and SaaS
- **Relationships**: for each resource, what it connects to and what connects to it, whether the connection is sync or async, and what flows over it.
- **Beyond the IaC**: SDK clients, environment variables and connection strings in app code that name infrastructure the IaC doesn't declare (managed services, external APIs). Mark these as found in code.

## Skeleton

```markdown
# Infrastructure

## Overview
Two or three sentences: provider(s), regions or environments, the overall shape.

## Components

### Compute
- **name** (type): purpose; configuration that matters. `path:line`

### Data Stores
### Networking
### Security
### External Services

## Relationships
| From | To | Protocol / mode | What flows |
|------|----|-----------------|------------|

## Environment Differences
Only if the code defines more than one environment.

## Unverified
Claims the code doesn't settle, each with the reason.
```

Leave an empty category out rather than writing "None".
