# claude-d2-diagrams

A [Claude Code](https://code.claude.com) plugin that reads your codebase and draws its infrastructure and architecture with [D2](https://d2lang.com), then keeps those diagrams in step with the code as it changes.

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

Detailed diagrams are generated alongside these.

### Files generated

```
diagrams/
├── README.md                          landing page embedding every diagram
├── manifest.json                      commit the set was built from, and the paths it depends on
├── infrastructure.md / .d2 / -light.svg / -dark.svg
├── infrastructure-simplified.md / .d2 / -light.svg / -dark.svg
├── architecture.md / .d2 / -light.svg / -dark.svg
└── architecture-simplified.md / .d2 / -light.svg / -dark.svg
```

Your root `README.md` gets the two simplified diagrams and a link to the rest.

---

## Features

- Reads Terraform, OpenTofu, Pulumi, CloudFormation/CDK, Kubernetes, Helm, Docker, Compose, and PaaS configs, plus service entrypoints and dependency manifests
- Detailed docs where every claim cites the file it came from, plus 3 to 8 box overviews for newcomers
- 950+ icons (AWS, GCP, Azure, languages, databases), inlined so they show up on GitHub
- Light and dark SVGs, switched by GitHub's theme
- Animated traffic flow on every connection (respects `prefers-reduced-motion`)
- TALA layout, with ELK and dagre fallbacks
- An independent verifier checks citations against the code and inspects each render before anything is stamped
- Stays fresh: see below

---

## Staying fresh

`diagrams/manifest.json` records the commit the diagrams were built from and the source paths they depend on (IaC, service manifests, entrypoints, API specs). Ordinary code changes don't touch it. A new queue in Terraform does.

- **Every session:** when you open Claude Code in a repo whose diagrams have drifted, it says so in one line. Silent otherwise.
- **On demand:** `/d2:diagram` refreshes only what the changed files affect, editing docs and D2 sources in place so the diff shows the change in your system rather than a rewrite.
- **In CI:** `/d2:diagram --ci` installs a GitHub Actions workflow. On each push to the default branch it checks for drift with plain `git diff`, and only when something drifted does it run Claude and open a PR with the refreshed diagrams.

---

## Installation

```bash
claude plugin marketplace add https://github.com/heathdutton/claude-d2-diagrams
claude plugin install d2@claude-d2-diagrams
```

Or from a clone: `claude --plugin-dir ./claude-d2-diagrams`

**Requires:**
- [D2](https://d2lang.com) 0.9.0 or newer: `brew install d2`, or `curl -fsSL https://d2lang.com/install.sh | sh -s --`
- git, for drift tracking, and Python 3.9+, which inlines icons for GitHub. On macOS both come with the Command Line Tools (`xcode-select --install`).

---

## Usage

```bash
/d2:diagram                        # build, or refresh whatever drifted
/d2:diagram --check                # report drift, change nothing
/d2:diagram --full                 # rebuild everything from scratch
/d2:diagram --infrastructure-only  # one family only
/d2:diagram --architecture-only
/d2:diagram --scope=src/           # limit what gets read
/d2:diagram --ci                   # install the refresh workflow
```

---

## Customization

Create `./diagrams/rules.md`. It overrides naming, scope, icons and layout:

```markdown
## Naming
- Use "API Gateway" not "APIGW"

## Exclude
- test/
- examples/

## Include (even if not in IaC)
- Cloudflare CDN
- Datadog monitoring

## Icons
- MySQL: https://example.com/mysql.svg

## Layout
- elk
```

To restyle the animations, copy `assets/animations.css` to `./diagrams/animations.css` and edit it.

---

## Upgrading from 1.x

The first `/d2:diagram` run detects diagrams made before manifests existed. It refreshes the docs against the code, re-renders every SVG, and stamps a manifest. The re-render fixes two 1.x bugs: icons that came out blank or recolored, and dashed lines whose animation jumped once per loop. The `.diagram/` state folder is no longer used and can be deleted.

---

## License

MIT
