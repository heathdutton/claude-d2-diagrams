# Architecture overview template

Output: `./diagrams/architecture-simplified.md`. Source: `./diagrams/architecture.md`, not the code. Readers: a newcomer, a stakeholder, or the README's hero diagram, all needing the system's shape at a glance.

## Distilling

- 3 to 8 components. Past 8 is not simplified yet, and fewer than 3 hides distinctions that matter.
- Group services by business capability: many endpoints become "API", many workers become "Background Processing". Different technologies stay separate.
- Every label names its technology in parentheses: "API (Go)", "Database (PostgreSQL)", "Event Stream (Kafka)".
- Follow the data: where it comes from, the two or three major steps, where it goes.
- Drop internal module structure, helpers, CI/CD, and monitoring unless one of them is the product.

## Skeleton

```markdown
# Architecture Overview

## System Summary
One or two sentences: what the system does and who uses it.

## Major Components

### Component (Technology)
**Purpose**: one sentence, in business terms
**Contains**: what's grouped here, if anything

## Data Flow
1. A user or system sends...
2. ...which processes and stores...
3. ...which triggers...

## Key Interactions
| From | To | What |
|------|----|------|
```
