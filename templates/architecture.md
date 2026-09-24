# Architecture template

Output: `./diagrams/architecture.md`. Readers: engineers building a mental model of the software, and the renderer, which draws a node for every service or module and an edge for every dependency listed here.

## What to trace

- **Boundaries**: deployable units (services, functions, workers), the major modules inside a monolith, and shared libraries that couple them. Give each a single responsibility.
- **Entry points**: where execution starts (main, handler, app factory) and what triggers it: HTTP, queue, schedule, event.
- **Dependencies**: caller to callee between services and modules, plus the runtime services each needs up. Trace imports and calls, since "utility" and "common" packages are where hidden coupling lives.
- **Data flow**: two or three flows that matter to the product. Trace each from where data enters, through its transformations, to where it's stored and where it leaves.
- **Pattern**: layered, event-driven, microservices, modular monolith. Name the pattern the code shows, and where it departs from it.

## Skeleton

```markdown
# Software Architecture

## Overview
Two or three sentences: pattern, number of services, key technology.

## System Context
Users and external systems, and how each interacts.

## Services

### name
- **Purpose**: one sentence
- **Technology**: language, framework, key libraries
- **Entry points**: how it's invoked, `path` + symbol
- **Dependencies**: what it calls or needs running
- **Interfaces**: what it exposes
- **Location**: `path/`

## Data Flow

### flow name
1. where it enters
2. each transformation
3. where it lands

## API Contracts
Key endpoints (method, path, purpose), or a pointer to the OpenAPI/proto files.

## Deployment Mapping
Which infrastructure component each service runs on.

## Concerns
Coupling, cycles or inconsistencies the code shows.

## Unverified
Claims the code doesn't settle, each with the reason.
```
