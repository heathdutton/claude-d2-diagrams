# README embeds

GitHub picks the variant through `<picture>` and `prefers-color-scheme`, which follows the viewer's GitHub theme. A single SVG with d2's `--dark-theme` would follow the OS setting instead, so the two files stay separate.

Embed only the families this run covers.

## Landing page: `./diagrams/README.md`

Write it in full in a build. In a refresh, add only the embeds `verify.sh` reported missing.

```markdown
# System Diagrams

Generated from the code by `/d2:diagram`, which refreshes them when the infrastructure or service layout changes. Project overview: [README](../README.md).

## Infrastructure

### Overview
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./infrastructure-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./infrastructure-simplified-light.svg">
  <img alt="Infrastructure overview" src="./infrastructure-simplified-light.svg">
</picture>

[Overview notes](./infrastructure-simplified.md)

### Detailed
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./infrastructure-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./infrastructure-light.svg">
  <img alt="Infrastructure diagram" src="./infrastructure-light.svg">
</picture>

[Infrastructure documentation](./infrastructure.md)

## Architecture

### Overview
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./architecture-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./architecture-simplified-light.svg">
  <img alt="Architecture overview" src="./architecture-simplified-light.svg">
</picture>

[Overview notes](./architecture-simplified.md)

### Detailed
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./architecture-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./architecture-light.svg">
  <img alt="Architecture diagram" src="./architecture-light.svg">
</picture>

[Architecture documentation](./architecture.md)
```

## Root `README.md`

Only if it exists. If it already embeds `diagrams/*-simplified-*.svg`, update that section in place. Otherwise insert this before the first of `## Features`, `## Installation` or `## Getting Started`, or after the opening paragraph when none of those exist:

```markdown
## System Overview

### Infrastructure
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./diagrams/infrastructure-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./diagrams/infrastructure-simplified-light.svg">
  <img alt="Infrastructure overview" src="./diagrams/infrastructure-simplified-light.svg">
</picture>

### Architecture
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./diagrams/architecture-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./diagrams/architecture-simplified-light.svg">
  <img alt="Architecture overview" src="./diagrams/architecture-simplified-light.svg">
</picture>

[More diagrams](./diagrams/README.md)
```

Done when `verify.sh` reports no missing embed.
