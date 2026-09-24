# Infrastructure overview template

Output: `./diagrams/infrastructure-simplified.md`. Source: `./diagrams/infrastructure.md`, not the code. Readers: a newcomer, a stakeholder, or the README's hero diagram, all needing "what runs where" at a glance.

## Distilling

- 3 to 8 components. Past 8 is not simplified yet, and fewer than 3 hides distinctions that matter.
- Aggregate like with like: many instances become "Application Servers" and many functions become "Serverless Functions". Different technologies stay separate, so Postgres and Redis are two boxes.
- Every label names its technology in parentheses: "Database (Aurora MySQL)", "Cache (Redis)", "Queue (SQS)".
- Keep the tiers (edge, application, data) and the boundaries (VPC, internal vs external) that shape the picture.
- Drop instance sizes, counts, availability zones, IAM, security groups, and monitoring unless one of them is the point of the system.

## Skeleton

```markdown
# Infrastructure Overview

## System Summary
One or two sentences: where it runs and what's distinctive.

## Major Components

### Component (Technology)
**Purpose**: one sentence
**Contains**: what's aggregated here, if anything

## Data Flow
1. A request enters at...
2. ...routes to...
3. ...which reads and writes...

## Key Boundaries
| Boundary | Inside | Outside |
|----------|--------|---------|
```
