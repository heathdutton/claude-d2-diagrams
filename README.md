# claude-d2-diagrams

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that generates infrastructure and architecture diagrams (and documentation) from your codebase using [D2](https://d2lang.com/).

**Command:** `/d2:diagram`

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Example Output

### Infrastructure (Simplified)
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./examples/infrastructure-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./examples/infrastructure-simplified-light.svg">
  <img alt="Infrastructure Diagram" src="./examples/infrastructure-simplified-light.svg">
</picture>

### Architecture (Simplified)
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./examples/architecture-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./examples/architecture-simplified-light.svg">
  <img alt="Architecture Diagram" src="./examples/architecture-simplified-light.svg">
</picture>

More advanced/complex outputs will be generated as well.

### Files generated:

```
   diagrams/
  ├── 󰂺 README.md  <-- Will contain embedded diagrams
  ├── 󰕙 architecture-dark.svg
  ├── 󰕙 architecture-light.svg
  ├── 󰕙 architecture-simplified-dark.svg
  ├── 󰕙 architecture-simplified-light.svg
  ├──  architecture-simplified.d2
  ├──  architecture-simplified.md
  ├──  architecture.d2
  ├──  architecture.md
  ├── 󰕙 infrastructure-dark.svg
  ├── 󰕙 infrastructure-light.svg
  ├── 󰕙 infrastructure-simplified-dark.svg
  ├── 󰕙 infrastructure-simplified-light.svg
  ├──  infrastructure-simplified.d2
  ├──  infrastructure-simplified.md
  ├──  infrastructure.d2
  └──  infrastructure.md
```

---

## Features

- Scans Terraform, Kubernetes, Docker, CloudFormation, and code patterns
- 100+ icons (AWS, GCP, Azure, K8s, databases, languages)
- Dark/light theme support
- Animated traffic flow (respects `prefers-reduced-motion`)
- Self-contained SVGs with embedded icons
- D2 syntax validation with auto-fix

---

## Installation

```bash
git clone https://github.com/heathdutton/claude-d2-diagrams.git
claude --plugin-dir ./claude-d2-diagrams
```

**Requires [D2](https://d2lang.com/):**
```bash
brew install d2          # macOS
# or
curl -fsSL https://d2lang.com/install.sh | sh -s --  # Linux
```
Note: the plugin will guide you through installing D2 if not available.

---

## Usage

```bash
/d2:diagram                        # Full generation
/d2:diagram --incremental          # Only regenerate changes
/d2:diagram --infrastructure-only  # Skip architecture
/d2:diagram --architecture-only    # Skip infrastructure
/d2:diagram --scope=src/           # Limit scan to directory
```

---

## Customization

Create `./diagrams/rules.md` to customize. Example:

```markdown
## Naming
- Use "API Gateway" not "APIGW"

## Exclude
- test/
- examples/

## Include (even if not in IaC)
- Cloudflare CDN
- Datadog monitoring
```

---

## License

MIT
