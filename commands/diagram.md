---
description: Generate comprehensive infrastructure and architecture diagrams using D2
argument-hint: "[--incremental] [--infrastructure-only] [--architecture-only] [--scope=<path>] [--force]"
---

# /diagram - Generate Infrastructure & Architecture Diagrams

Generate comprehensive infrastructure and architecture diagrams using D2 (terrastruct/d2).

---

## Arguments

| Argument | Description |
|----------|-------------|
| `--incremental` | Only regenerate changed components |
| `--infrastructure-only` | Generate only infrastructure diagram |
| `--architecture-only` | Generate only architecture diagram |
| `--scope=<path>` | Limit analysis to specific directory |
| `--force` | Regenerate all, ignore cache |

---

## Overview

This command orchestrates multiple specialized agents to analyze a codebase and produce visual diagrams:

**Agents Used:**
- **Scanner** (sonnet) - Fast discovery of IaC and documentation
- **Documenter** (opus) - Deep analysis and documentation
- **Renderer** (sonnet) - D2 diagram generation
- **Verifier** (sonnet) - Quality validation

**Output:**
- `./diagrams/infrastructure.md` - Detailed infrastructure documentation
- `./diagrams/infrastructure-simplified.md` - High-level infrastructure overview
- `./diagrams/architecture.md` - Detailed architecture documentation
- `./diagrams/architecture-simplified.md` - High-level architecture overview
- `./diagrams/*.d2` - D2 source files (4 types)
- `./diagrams/*-light.svg` + `*-dark.svg` - Themed SVG diagrams (8 total)
- Main README.md - Simplified diagrams embedded with "More diagrams" link
- `./diagrams/README.md` - All diagrams (simple + detailed)

---

## State Management

The command uses two directories:

**`./diagrams/`** - Committed output and configuration:
```
./diagrams/
├── README.md                         # Landing page with all diagrams
├── rules.md                          # Project-specific customization (optional)
├── infrastructure.md                 # Detailed infrastructure
├── infrastructure.d2
├── infrastructure-*.svg
├── infrastructure-simplified.md      # High-level infrastructure
├── infrastructure-simplified.d2
├── infrastructure-simplified-*.svg
├── architecture.md                   # Detailed architecture
├── architecture.d2
├── architecture-*.svg
├── architecture-simplified.md        # High-level architecture
├── architecture-simplified.d2
└── architecture-simplified-*.svg
```

**`.diagram/`** - Ephemeral runtime state (gitignored):
```
.diagram/
├── state.json          # Progress checkpoints for resume
└── cache/              # Incremental mode cache
    ├── iac-hash.txt
    └── scan-results.json
```

**Note:** The `.diagram/` folder is automatically added to `.gitignore` if one exists. This folder can be safely deleted at any time - it only enables resume and incremental features.

### State File Format

```json
{
  "phase": "documenter",
  "completed": ["scanner"],
  "total": 6,
  "timestamp": "ISO8601",
  "args": {
    "incremental": false,
    "scope": null
  },
  "checkpoints": {
    "scanner": {"timestamp": "...", "result": "success"},
    "documenter": null
  }
}
```

---

## Execution Workflow

### Phase 0: Initialization

**IMPORTANT**: Before any work, initialize state tracking and ensure proper gitignore setup.

**STEP 1 - Create directories FIRST (use Bash tool, not Write):**
```bash
mkdir -p ./diagrams .diagram/cache
```

**STEP 2 - Add to .gitignore (use Bash tool):**
```bash
if [ -f ".gitignore" ] && ! grep -q "^\.diagram" .gitignore 2>/dev/null; then
  echo -e "\n# Diagram plugin ephemeral state\n.diagram/" >> .gitignore
fi
```

**STEP 3 - Note on icons:**

Icons are added directly to nodes using the `icon:` property. No need to copy icons.d2 to the project.
The `class:` property provides styling (stroke color, shape) while `icon:` provides the visual.

Example:
```d2
database: MySQL Config {
  class: mysql
  icon: https://icons.terrastruct.com/dev%2Fmysql.svg
}
```

See the Technology → Icon URL mapping in Phase 7 for all available icons.

**STEP 4 - Initialize state file (use Bash tool, NOT Write tool):**
```bash
echo '{"phase":"initialization","completed":[],"total":11}' > .diagram/state.json
```

**WHY BASH**: The Write tool will fail if the directory doesn't exist. Always use `mkdir -p` via Bash first, then write files.

**Check for project rules** (OPTIONAL - only if file exists):
```bash
# rules.md is OPTIONAL - do NOT error if missing
if [ -f "./diagrams/rules.md" ]; then
  echo "Project rules found - will apply customizations"
  # Read and incorporate rules into subsequent phases
else
  echo "No custom rules (./diagrams/rules.md not found - this is normal)"
fi
```

**IMPORTANT**: The rules.md file is user-created and optional. Do NOT attempt to read it unless you first confirm it exists with Glob or the bash check above.

---

### Phase 1: Discovery (Scanner Agent)

**Model hint**: Use haiku for fast parallel discovery.

**Delegate to Scanner agent** with prompt:

```
TASK: Rapid codebase scan for infrastructure and architecture artifacts.

NOTE: Existing documentation (docs/, diagrams/, *.md) are collected for REFERENCE ONLY.
They may be outdated. The code (IaC, source files) is the source of truth.

EXECUTE IN PARALLEL (spawn multiple Glob/Grep calls simultaneously):

Batch 1 - Infrastructure-as-Code:
- Glob: **/*.tf, **/*.tfvars
- Glob: **/Pulumi.yaml, **/Pulumi.yml
- Glob: **/*.template.yaml, **/*.template.json, **/cdk.json
- Glob: **/serverless.yml, **/serverless.yaml

Batch 2 - Container/Orchestration:
- Glob: **/Dockerfile*, **/docker-compose*.yml
- Glob: **/*.yaml then Grep for "apiVersion:" (Kubernetes)
- Glob: **/helmfile.yaml, **/Chart.yaml

Batch 3 - Documentation:
- Glob: **/README.md, **/ARCHITECTURE.md, **/INFRASTRUCTURE.md
- Glob: **/docs/**/*.md, **/diagrams/**/*

Batch 4 - Application Structure:
- Glob: **/package.json, **/go.mod, **/Cargo.toml, **/requirements.txt
- Glob: **/main.*, **/index.*, **/app.*

CONSTRAINTS:
- READ-ONLY: Do NOT modify any files
- SPEED: Prioritize breadth over depth
- DEDUP: Report each file only once

OUTPUT FORMAT (JSON):
{
  "iac": {"terraform": [], "kubernetes": [], "docker": [], "other": []},
  "docs": {"readme": [], "architecture": [], "other": []},
  "app": {"entrypoints": [], "configs": [], "dependencies": []},
  "stats": {"total_files": N, "scan_duration_ms": N}
}
```

**Update state after completion:**
```json
{
  "phase": "gate-check",
  "completed": ["scanner"],
  "checkpoints": {
    "scanner": {"timestamp": "...", "result": "success", "iac_count": N}
  }
}
```

---

### Phase 2: Gate Check

**Verify prerequisites before proceeding:**

1. **D2 Installation**
   ```bash
   which d2 && d2 --version
   ```

   If missing, attempt installation:
   ```bash
   # macOS
   brew install d2

   # Linux
   curl -fsSL https://d2lang.com/install.sh | sh -s --

   # Go
   go install oss.terrastruct.com/d2@latest
   ```

   **CRITICAL**: If D2 cannot be installed, ABORT with clear instructions.

2. **Discovery Results**
   - If NO IaC and NO clear architecture found:
     - Ask user if they want to proceed with code-only analysis
     - Or abort with explanation

3. **Incremental Check** (if `--incremental`)
   ```bash
   # Compare current IaC hash with cached
   find . -name "*.tf" -o -name "Dockerfile*" -o -name "*.yaml" | \
     xargs sha256sum | sha256sum > /tmp/current-hash.txt

   if diff -q .diagram/cache/iac-hash.txt /tmp/current-hash.txt; then
     echo "No changes detected - using cached scan"
   fi
   ```

**Update state:**
```json
{
  "phase": "documenter",
  "completed": ["scanner", "gate-check"]
}
```

---

### Phases 3 & 4: Documentation (PARALLEL)

**IMPORTANT: Run these two documentation tasks IN PARALLEL using two simultaneous Task tool calls.**

Both phases depend only on Scanner results - they do NOT depend on each other.
Spawn both agents in a single message to maximize parallelization.

---

### Phase 3: Infrastructure Documentation (Documenter Agent)

**Model hint**: Use opus for deep analysis.
**Run in parallel with Phase 4.**

**Delegate to Documenter agent** with prompt:

```
ULTRATHINK: Perform deep, systematic analysis of infrastructure before documenting.

SOURCE OF TRUTH HIERARCHY (CRITICAL):
1. **CODE IS KING** - IaC files (*.tf, Dockerfile, k8s manifests) are the authoritative source
2. **Existing docs are HINTS ONLY** - Any existing diagrams/, docs/, or *.md files may be OUTDATED
3. **When code contradicts docs, CODE WINS** - Always trust what the code actually defines
4. **Verify everything** - Don't copy from old docs; re-derive from code

REASONING PROCESS (follow these steps mentally before writing):

Step 1 - Inventory: Read EVERY IaC file from scanner results. For each file:
  - What resources does it define?
  - What are the explicit dependencies?
  - What are the implicit dependencies (naming conventions, references)?

Step 2 - Categorize: Group all discovered resources:
  - Compute: EC2, ECS, EKS, Lambda, containers, pods, VMs
  - Data: RDS, DynamoDB, Redis, Elasticsearch, S3, queues (SQS, Kafka)
  - Network: VPC, subnets, ALB/NLB, API Gateway, CloudFront, Route53
  - Security: IAM roles/policies, security groups, secrets, KMS
  - External: Third-party APIs, SaaS integrations, webhooks

Step 3 - Map Relationships: For EVERY resource, identify:
  - What does it connect TO? (outbound)
  - What connects to IT? (inbound)
  - Is this sync or async communication?
  - What data flows through this connection?

Step 4 - Verify Completeness: Cross-reference with application code:
  - Are there SDK calls to services not in IaC? (managed services, external APIs)
  - Are there environment variables referencing infrastructure?
  - Are there hardcoded endpoints or connection strings?

CONSTRAINTS:
- Do NOT guess or assume - if uncertain, note it as "UNVERIFIED: [reason]"
- Do NOT omit resources because they seem minor
- Do NOT skip resources in modules/includes - trace them
- EVERY claim must be traceable to a specific file:line

OUTPUT: Create ./diagrams/infrastructure.md with this structure:

# Infrastructure Documentation

## Overview
[2-3 sentence summary of the infrastructure]

## Components

### Compute
[For each: name, type, purpose, configuration highlights, file:line reference]

### Data Stores
[For each: name, type, purpose, configuration highlights, file:line reference]

### Networking
[For each: name, type, purpose, configuration highlights, file:line reference]

### Security
[For each: name, type, purpose, configuration highlights, file:line reference]

### External Services
[For each: name, type, purpose, how integrated, file:line reference]

## Relationships
[Mermaid-style relationship list or table showing all connections]

## Environment Differences
[If multiple environments detected: dev/staging/prod differences]

## Unverified Items
[List anything uncertain with reasoning]

SELF-CHECK before completing:
- [ ] Every IaC resource is documented
- [ ] Every relationship is bidirectional (A->B means B<-A documented)
- [ ] No guessing - uncertainties are flagged
- [ ] Word count exceeds 200
```

**Apply project rules** (OPTIONAL - only if `./diagrams/rules.md` exists):
- First check: `test -f ./diagrams/rules.md` before attempting to read
- If exists: apply custom component naming, excluded paths, additional sections
- If missing: proceed without customization (this is normal for most projects)

**Update state:**
```json
{
  "phase": "architecture-documenter",
  "completed": ["scanner", "gate-check", "infrastructure-documenter"]
}
```

---

### Phase 4: Architecture Documentation (Documenter Agent)

**Model hint**: Use opus for deep analysis.
**Run in parallel with Phase 3.** Both detailed documentation phases run together.

**Delegate to Documenter agent** with prompt:

```
ULTRATHINK: Perform deep, systematic analysis of software architecture.

SOURCE OF TRUTH HIERARCHY (CRITICAL):
1. **CODE IS KING** - Source files, imports, configs are the authoritative source
2. **Existing docs are HINTS ONLY** - Any existing ARCHITECTURE.md, diagrams/, README may be OUTDATED
3. **When code contradicts docs, CODE WINS** - Old diagrams may show deleted services or wrong dependencies
4. **Verify everything** - Trace actual imports/calls; don't trust old documentation
5. **Old D2 files are suggestions** - Existing *.d2 files may be stale; regenerate from code analysis

REASONING PROCESS (follow these steps mentally before writing):

Step 1 - Identify Boundaries: Find all distinct services/modules:
  - Separate deployable units (microservices, lambdas, workers)
  - Logical modules within monoliths (packages, namespaces)
  - Shared libraries and utilities
  - For each: What is its single responsibility?

Step 2 - Trace Entry Points: For each service/module:
  - Where does execution begin? (main, index, handler, app)
  - What triggers it? (HTTP, event, schedule, queue)
  - What are the public interfaces? (APIs, exports, events emitted)

Step 3 - Map Dependencies: Build the dependency graph:
  - Internal: Which modules depend on which?
  - External: What third-party libraries are critical?
  - Runtime: What services must be running for this to work?
  - Draw arrows: caller -> callee

Step 4 - Understand Data Flow: Trace data through the system:
  - Where does data enter? (APIs, webhooks, uploads)
  - How is it transformed? (validation, enrichment, aggregation)
  - Where is it stored? (databases, caches, files)
  - Where does it exit? (responses, events, exports)

Step 5 - Identify Patterns: Recognize architectural patterns:
  - Layered? (presentation -> business -> data)
  - Event-driven? (pub/sub, event sourcing)
  - Microservices? (service mesh, API gateway)
  - Monolith? (modular or big ball of mud?)

CONSTRAINTS:
- Do NOT guess module purposes - read the code
- Do NOT assume standard patterns - verify them
- Do NOT skip "utility" or "common" modules - they often hide coupling
- EVERY module must have a clear, documented purpose

OUTPUT: Create ./diagrams/architecture.md with this structure:

# Software Architecture Documentation

## Overview
[2-3 sentence architecture summary - what pattern, how many services, key tech]

## System Context
[What external systems/users interact with this system?]

## Layers / Services

### [Layer/Service Name]
- **Purpose**: [Single sentence]
- **Technology**: [Language, framework, key libraries]
- **Entry Points**: [How is it invoked?]
- **Dependencies**: [What does it require?]
- **Interfaces**: [What does it expose?]
- **Location**: [file paths]

[Repeat for each layer/service]

## Data Flow

### [Flow Name, e.g., "User Registration"]
1. [Step 1: where data enters]
2. [Step 2: first transformation]
...
N. [Step N: final destination]

[Document 2-3 critical flows]

## API Contracts
[Key APIs with method, path, purpose - or reference to OpenAPI spec]

## Deployment Mapping
[How architecture maps to infrastructure from Phase 3]

## Technical Debt / Concerns
[Any architectural issues noticed - tight coupling, circular deps, etc.]

SELF-CHECK before completing:
- [ ] Every service/module has documented purpose
- [ ] Dependency directions are clear (who calls whom)
- [ ] At least 2 data flows documented
- [ ] Infrastructure mapping present
- [ ] Word count exceeds 200
```

**Update state:**
```json
{
  "phase": "simplified-docs",
  "completed": ["scanner", "gate-check", "infrastructure-documenter", "architecture-documenter"]
}
```

---

### Phases 5 & 6: Simplified Documentation (PARALLEL)

**IMPORTANT: Run both simplified documentation phases IN PARALLEL using two simultaneous Task tool calls.**

Both phases depend only on their respective detailed docs - they do NOT depend on each other.
Spawn both agents in a single message to maximize parallelization.

---

### Phase 5: Infrastructure Simplified (Documenter Agent)

**Model hint**: Use sonnet for efficient high-level synthesis.
**Run in parallel with Phase 6.** Uses ./diagrams/infrastructure.md as input.

**Delegate to Documenter agent** with prompt:

```
TASK: Create a simplified, high-level infrastructure diagram for stakeholders and quick onboarding.

SOURCE MATERIAL:
Read ./diagrams/infrastructure.md (detailed infrastructure) first.

GOAL: Distill the detailed infrastructure into 3-8 major components that capture the essence of the system.
This is for:
- New team member onboarding
- Executive/stakeholder presentations
- Main README.md hero diagram
- Quick mental model of "what runs where"

SIMPLIFICATION RULES:

1. **Aggregate Similar Resources**: Combine related infrastructure into logical groups
   - Multiple EC2 instances → "Application Servers"
   - Multiple RDS instances → "Database Cluster" (or separate if architecturally different)
   - Multiple Lambda functions → "Serverless Functions"
   - Multiple subnets → hide (unless public/private distinction matters)

2. **Hide Implementation Details**:
   - No instance types, sizes, or counts
   - No availability zones or regions (unless multi-region is key)
   - No security groups or IAM roles
   - No monitoring/logging infrastructure

3. **Focus on Major Boundaries**:
   - VPC as a container (if relevant)
   - External vs Internal
   - Data tier vs Application tier vs Edge
   - What talks to what at the highest level

4. **Include Technology Names**: Use clear labels with technology in parentheses
   - "Database (Aurora MySQL)" not just "Database"
   - "Cache (Redis)" not just "Cache"
   - "Message Queue (Kafka)" not just "Queue"
   - "State Store (DynamoDB)" not just "State"
   - This helps readers quickly understand what's actually running

5. **Target Components**: 3-8 boxes total
   - If you have more than 15, you're not simplifying enough
   - If you have fewer than 8, you might be hiding important distinctions

OUTPUT: Create ./diagrams/infrastructure-simplified.md with:

# Infrastructure Overview (Simplified)

## System Summary
[1-2 sentences: where does this run? cloud provider? key characteristics?]

## Major Components

### [Component Name]
**Purpose**: [One sentence - what infrastructure function]
**Contains**: [Brief list of what's aggregated here, if applicable]

[Repeat for 3-8 components]

## Data Flow
[Simple description: how traffic flows through the infrastructure]
1. External request hits...
2. ...routes to...
3. ...which accesses...

## Key Boundaries
| Boundary | Inside | Outside |
|----------|--------|---------|
| VPC | App servers, databases | Internet, users |
| ... | ... | ... |

SELF-CHECK:
- [ ] Component count is 3-8
- [ ] Labels include technology names in parentheses
- [ ] A technical person can understand what's running
- [ ] No unnecessary implementation details (instance sizes, versions)
- [ ] Major infrastructure tiers are represented
```

**Update state:**
```json
{
  "phase": "architecture-simplified",
  "completed": ["scanner", "gate-check", "infrastructure-documenter", "architecture-documenter", "infrastructure-simplified"]
}
```

---

### Phase 6: Architecture Simplified (Documenter Agent)

**Model hint**: Use sonnet for efficient high-level synthesis.
**Run in parallel with Phase 5.** Uses ./diagrams/architecture.md as input.

**Delegate to Documenter agent** with prompt:

```
TASK: Create a simplified, high-level architecture diagram for stakeholders and quick onboarding.

SOURCE MATERIAL:
Read ./diagrams/architecture.md (detailed architecture) first.

GOAL: Distill the detailed architecture into 3-8 major components that capture the essence of the system.
This is for:
- New team member onboarding
- Executive/stakeholder presentations
- README overview
- Quick mental model building

SIMPLIFICATION RULES:

1. **Aggregate Services**: Combine related microservices into logical groups
   - Multiple API endpoints → "API Gateway"
   - Multiple workers/processors → "Background Processing"
   - Multiple databases → keep separate if different technologies (e.g., "Database (MySQL)" vs "Cache (Redis)")

2. **Hide Internal Details**:
   - No internal module structure
   - No utility/helper services
   - No monitoring/logging infrastructure (unless core to product)
   - No CI/CD or deployment details

3. **Focus on Data Flow**:
   - Where does data come FROM? (Users, APIs, Events)
   - Where does data go TO? (Storage, External Systems, Users)
   - What are the 2-3 major data transformation steps?

4. **Include Technology Names**: Use clear labels with technology in parentheses
   - "Database (PostgreSQL)" not just "Database"
   - "Message Queue (RabbitMQ)" not just "Queue"
   - "Cache (Redis)" not just "Cache"
   - "Event Stream (Kafka)" not just "Events"
   - This helps readers quickly understand what's actually running

5. **Target Components**: 3-8 boxes total
   - If you have more than 15, you're not simplifying enough
   - If you have fewer than 8, you might be hiding important distinctions

OUTPUT: Create ./diagrams/architecture-simplified.md with:

# Architecture Overview (Simplified)

## System Summary
[1-2 sentences: what does this system do? who uses it?]

## Major Components

### [Component Name]
**Purpose**: [One sentence - what business function]
**Contains**: [Brief list of what's aggregated here, if applicable]

[Repeat for 3-8 components]

## Data Flow
[Simple numbered list: how data flows through the system]
1. User/External System sends request to...
2. ...processes and stores in...
3. ...which triggers...
4. ...returning response to...

## Key Interactions
| From | To | What |
|------|-----|------|
| Users | API | HTTP requests |
| API | Database | Read/Write |
| ... | ... | ... |

SELF-CHECK:
- [ ] Component count is 3-8
- [ ] Labels include technology names in parentheses
- [ ] A technical person can understand what's running
- [ ] No unnecessary implementation details (versions, configs)
- [ ] Major business capabilities are represented
```

**Update state:**
```json
{
  "phase": "renderer",
  "completed": ["scanner", "gate-check", "infrastructure-documenter", "architecture-documenter", "infrastructure-simplified", "architecture-simplified"]
}
```

---

### Phase 7: Diagram Generation (Renderer Agent)

**Model hint**: Use opus for reliable diagram generation with thorough icon handling.

**Delegate to Renderer agent** with prompt:

```
TASK: Generate accurate D2 diagrams from documentation. Think carefully about D2 syntax.

STEP 1 - Review Documentation:
Read all 4 documentation files thoroughly:
- ./diagrams/infrastructure.md (detailed)
- ./diagrams/infrastructure-simplified.md (high-level)
- ./diagrams/architecture.md (detailed)
- ./diagrams/architecture-simplified.md (high-level)
Extract: all components, all relationships, groupings.

STEP 2 - Plan Diagram Structure:
Before writing D2, mentally plan:
- What are the top-level containers/groups?
- What nodes go in each group?
- What are ALL the connections?
- What labels clarify the connections?

STEP 3 - Write D2 with Correct Syntax:

**TECHNOLOGY → ICON MAPPING:**

For icons to appear in bundled SVGs, add BOTH `class:` (for styling) and `icon:` (for the image):

| Technology | Class | Icon URL |
|------------|-------|----------|
| MySQL | `mysql` | `https://icons.terrastruct.com/dev%2Fmysql.svg` |
| PostgreSQL | `postgresql` | `https://icons.terrastruct.com/dev%2Fpostgresql.svg` |
| Redis | `redis` | `https://icons.terrastruct.com/dev%2Fredis.svg` |
| MongoDB | `mongodb` | `https://icons.terrastruct.com/dev%2Fmongodb.svg` |
| Elasticsearch | `elasticsearch` | `https://icons.terrastruct.com/dev%2Felasticsearch.svg` |
| DynamoDB | `aws-dynamodb` | `https://icons.terrastruct.com/aws%2FDatabase%2FAmazon-DynamoDB.svg` |
| S3 | `aws-s3` | `https://icons.terrastruct.com/aws%2FStorage%2FAmazon-Simple-Storage-Service-S3.svg` |
| RDS/Aurora | `aws-rds` | `https://icons.terrastruct.com/aws%2FDatabase%2FAmazon-RDS.svg` |
| ElastiCache | `aws-elasticache` | `https://icons.terrastruct.com/aws%2FDatabase%2FAmazon-ElastiCache.svg` |
| Docker | `container` | `https://icons.terrastruct.com/dev%2Fdocker.svg` |
| Kubernetes | `kubernetes` | `https://icons.terrastruct.com/dev%2Fkubernetes.svg` |
| Go | `golang` | `https://icons.terrastruct.com/dev%2Fgo.svg` |
| Python | `python` | `https://icons.terrastruct.com/dev%2Fpython.svg` |
| Node.js | `nodejs` | `https://icons.terrastruct.com/dev%2Fnodejs.svg` |
| Users | `users` | `https://icons.terrastruct.com/essentials%2F359-users.svg` |
| Server | `server` | `https://icons.terrastruct.com/tech%2F022-server.svg` |
| Grafana | `grafana` | `https://icons.terrastruct.com/dev%2Fgrafana.svg` |
| Prometheus | `prometheus` | `https://icons.terrastruct.com/dev%2Fprometheus.svg` |

For classes without working icon URLs (Kafka, Datadog, etc.), use `class:` only for shape/styling.

**LABEL BEST PRACTICES:**
- Use SINGLE-LINE labels to avoid icon/text overlap
- Good: `config: MySQL Config`
- Bad: `config: Configuration (MySQL)\nFlows, steps`

**D2 SYNTAX EXAMPLE:**
```d2
direction: down

# Nodes with icons (class for style, icon for visual)
sources: Lead Sources {
  class: users
  icon: https://icons.terrastruct.com/essentials%2F359-users.svg
}

database: MySQL Config {
  class: mysql
  icon: https://icons.terrastruct.com/dev%2Fmysql.svg
}

# Nodes without icons (class provides shape/color only)
external: DataDog APM {class: cloud}
broker: Kafka Broker {class: queue}
```

# Containers/Groups
vpc: AWS VPC {
  subnet-a: Subnet A {
    instance-1: EC2
  }
}

# Connections (CRITICAL: use -> not other arrows)
web-server -> postgres: "reads/writes"
api -> cache: "gets" {style.stroke-dash: 5}

# Connection styles for async
queue -> worker: "processes" {
  style: {
    stroke-dash: 5
    stroke: "#666"
  }
}

COMMON D2 ERRORS TO AVOID:
- Do NOT use "=>" use "->"
- Do NOT use quotes around node IDs, only labels
- Do NOT forget colons after node IDs when adding properties
- Do NOT use invalid shape names (valid: rectangle, cylinder, queue, cloud, etc.)
- Do NOT leave dangling connections (every -> must have valid source and target)

MINIMIZING CONNECTION BENDS:
- Define connected nodes near each other in source (layout engine uses source order as hint)
- Always use `direction: down` or `direction: right` at diagram start
- Group related nodes in containers - connections within containers route better
- Define nodes in data flow order (input → processing → output)

STEP 4 - Create Infrastructure Diagram (Detailed):
Create ./diagrams/infrastructure.d2:
- **ICONS ARE REQUIRED**: Every technology node MUST have both `class:` (styling) and `icon:` (URL) properties
- Use the Technology → Icon URL table above for icon URLs
- Group by: VPC/Region/Environment boundaries
- Include: ALL compute, data, network, security components
- Connect: ALL relationships from documentation
- Label: Connection purposes (e.g., "HTTP", "SQL", "events")

STEP 5 - Create Infrastructure Diagram (Simplified):
Create ./diagrams/infrastructure-simplified.d2:
- **ICONS ARE REQUIRED**: Every technology node MUST have both `class:` and `icon:` properties
- GOAL: 3-8 boxes - high-level but informative infrastructure view
- Include technology names: "Database (Aurora MySQL)", "Cache (Redis)", "Queue (Kafka)"
- Aggregate similar resources but keep different technologies separate
- Show major tiers (Edge, App, Data) with enough detail to be useful
- Use the icon URL table for each node's icon

STEP 6 - Create Architecture Diagram (Detailed):
Create ./diagrams/architecture.d2:
- **ICONS ARE REQUIRED**: Every technology node MUST have both `class:` and `icon:` properties
- Structure: Layers (top-to-bottom) or Service Mesh
- Include: ALL services/modules
- Connect: ALL dependencies
- Distinguish: Sync (solid) vs Async (dashed) connections

STEP 7 - Create Architecture Diagram (Simplified):
Create ./diagrams/architecture-simplified.d2:
- **ICONS ARE REQUIRED**: Every technology node MUST have both `class:` and `icon:` properties
- GOAL: 3-8 boxes - high-level but informative architecture view
- Include technology names: "API Gateway", "Database (PostgreSQL)", "Cache (Redis)"
- Group related services but keep different technologies separate
- Show major data flows with enough detail to understand the system

STEP 8 - Validate Before Rendering:
Mental check for each diagram:
- [ ] Every node from docs is in diagram
- [ ] Every relationship from docs is connected
- [ ] No orphan nodes (everything connects to something)
- [ ] Labels are meaningful, not generic
- [ ] Simplified diagrams have 3-8 nodes with technology names
- [ ] **EVERY technology node has an `icon:` property with a URL** (CRITICAL)

STEP 9 - Render SVGs (RUN ALL 8 IN PARALLEL):
Execute these 8 commands simultaneously using parallel Bash tool calls:

# Theme 0 = Neutral Default (light), Theme 200 = Dark Mauve (dark)
# IMPORTANT: Use --bundle to embed icons in SVGs (avoids CORS issues on GitHub Pages)
# Infrastructure (detailed)
d2 --bundle ./diagrams/infrastructure.d2 ./diagrams/infrastructure-light.svg --theme 0 --layout elk --animate-interval=1200
d2 --bundle ./diagrams/infrastructure.d2 ./diagrams/infrastructure-dark.svg --theme 200 --layout elk --animate-interval=1200
# Infrastructure (simplified)
d2 --bundle ./diagrams/infrastructure-simplified.d2 ./diagrams/infrastructure-simplified-light.svg --theme 0 --layout elk --animate-interval=1200
d2 --bundle ./diagrams/infrastructure-simplified.d2 ./diagrams/infrastructure-simplified-dark.svg --theme 200 --layout elk --animate-interval=1200
# Architecture (detailed)
d2 --bundle ./diagrams/architecture.d2 ./diagrams/architecture-light.svg --theme 0 --layout elk --animate-interval=1200
d2 --bundle ./diagrams/architecture.d2 ./diagrams/architecture-dark.svg --theme 200 --layout elk --animate-interval=1200
# Architecture (simplified)
d2 --bundle ./diagrams/architecture-simplified.d2 ./diagrams/architecture-simplified-light.svg --theme 0 --layout elk --animate-interval=1200
d2 --bundle ./diagrams/architecture-simplified.d2 ./diagrams/architecture-simplified-dark.svg --theme 200 --layout elk --animate-interval=1200

These are independent operations - run them all in one message with 8 Bash tool calls.

ERROR RECOVERY:
- If elk layout fails: retry with --layout dagre
- If syntax error: read error message, fix specific line, retry
- Max 3 retry attempts per diagram
- If still failing: simplify diagram (remove problematic elements, note in output)
```

**Update state:**
```json
{
  "phase": "enhancer",
  "completed": ["scanner", "gate-check", "infrastructure-documenter", "architecture-documenter", "infrastructure-simplified", "architecture-simplified", "renderer"]
}
```

---

### Phase 8: SVG Enhancement (Enhancer Agent)

**Model hint**: Use sonnet for reliable SVG processing.

**Step 1 - Inline SVG icons for GitHub compatibility:**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/inline-svg-icons.sh --all ./diagrams/
```
GitHub strips `<image>` tags for security. This converts them to inline `<svg>` elements which GitHub allows.

**Step 2 - Add CSS animations:**
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/enhance-svg.sh --all ./diagrams/
```

**IMPORTANT**: Always use the plugin's built-in scripts. Do NOT write scripts to the target repository.

The enhance script:
1. Reads CSS from `./diagrams/animations.css`
2. Injects it into each SVG after the `<svg>` tag
3. Uses identical CSS for light and dark themes (D2 handles theme colors)
4. Protects text elements from animation side effects

**CSS Design Principles:**
- Only animate connection paths (`path[marker-end]`)
- Use opacity animations, not filters (filters can affect nested text)
- Same CSS for light and dark - never override D2's colors
- Explicit text protection rules

**Alternative - Delegate to Enhancer agent** if script fails:

```
Enhance the generated SVG diagrams with CSS animations.

DESIGN RULES:
1. Use `path[marker-end]` selector for connections
2. Do NOT use filter effects (can bleed into text)
3. Do NOT override colors - D2 handles themes
4. Always include text protection rules

Files to enhance (all 8):
- ./diagrams/infrastructure-light.svg
- ./diagrams/infrastructure-dark.svg
- ./diagrams/infrastructure-simplified-light.svg
- ./diagrams/infrastructure-simplified-dark.svg
- ./diagrams/architecture-light.svg
- ./diagrams/architecture-dark.svg
- ./diagrams/architecture-simplified-light.svg
- ./diagrams/architecture-simplified-dark.svg

CSS source: ./diagrams/animations.css
```

**Verify after enhancement:**
- [ ] Open SVG in browser directly (not in <img> tag)
- [ ] Connection lines show moving dashed animation
- [ ] Text is clearly readable (especially in dark mode)
- [ ] Contains "D2 Diagram Animations" marker
- [ ] Contains "prefers-reduced-motion" accessibility rule

**Animation types applied:**

| Element Type | Animation | CSS Selector |
|-------------|-----------|--------------|
| Connection arrows | Moving dashes (1s) | `path[marker-end]` |
| Async connections | Slower dashes (2s) | `path[marker-end][stroke-dasharray]` |
| Cylinder shapes | Subtle opacity pulse | `.shape-cylinder > path:first-of-type` |
| Queue shapes | Subtle opacity pulse | `.shape-queue > path:first-of-type` |

**Update state:**
```json
{
  "phase": "readme-integration",
  "completed": ["scanner", "gate-check", "infrastructure-documenter", "architecture-documenter", "infrastructure-simplified", "architecture-simplified", "renderer", "enhancer"]
}
```

---

### Phase 9: README Integration

This phase updates TWO readme files:
1. **Main README.md** - Simplified diagrams for quick overview
2. **./diagrams/README.md** - All diagrams (simplified + detailed)

---

#### Step 1: Update Main README.md (if exists)

Check if a README.md exists at repo root:
```bash
test -f README.md && echo "exists" || echo "none"
```

**If README.md exists**, find a suitable location (after description, before detailed sections) and add:

```markdown
## System Overview

### Infrastructure
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./diagrams/infrastructure-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./diagrams/infrastructure-simplified-light.svg">
  <img alt="Infrastructure Overview" src="./diagrams/infrastructure-simplified-light.svg">
</picture>

### Architecture
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./diagrams/architecture-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./diagrams/architecture-simplified-light.svg">
  <img alt="Architecture Overview" src="./diagrams/architecture-simplified-light.svg">
</picture>

[More diagrams →](./diagrams/README.md)
```

**Placement rules:**
- If README has a "## Features" section, insert BEFORE it
- If README has "## Installation", insert BEFORE it
- If README has "## Getting Started", insert BEFORE it
- Otherwise, add after the first paragraph or heading
- Do NOT replace existing diagram sections - update them in place

**If README.md doesn't exist**, skip this step.

---

#### Step 2: Create ./diagrams/README.md

Create the diagrams landing page with ALL diagrams:

```markdown
# System Diagrams

Auto-generated diagrams for this project. View the [main README](../README.md) for project overview.

---

## Infrastructure

### Overview (Simplified)
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./infrastructure-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./infrastructure-simplified-light.svg">
  <img alt="Infrastructure Overview" src="./infrastructure-simplified-light.svg">
</picture>

[View simplified documentation](./infrastructure-simplified.md)

### Detailed
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./infrastructure-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./infrastructure-light.svg">
  <img alt="Infrastructure Diagram" src="./infrastructure-light.svg">
</picture>

[View detailed documentation](./infrastructure.md)

---

## Architecture

### Overview (Simplified)
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./architecture-simplified-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./architecture-simplified-light.svg">
  <img alt="Architecture Overview" src="./architecture-simplified-light.svg">
</picture>

[View simplified documentation](./architecture-simplified.md)

### Detailed
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./architecture-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="./architecture-light.svg">
  <img alt="Architecture Diagram" src="./architecture-light.svg">
</picture>

[View detailed documentation](./architecture.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [infrastructure-simplified.md](./infrastructure-simplified.md) | High-level infrastructure overview |
| [infrastructure.md](./infrastructure.md) | Detailed infrastructure components |
| [architecture-simplified.md](./architecture-simplified.md) | High-level architecture overview |
| [architecture.md](./architecture.md) | Detailed software architecture |

## Regenerating

\`\`\`
/d2:diagram              # Full regeneration
/d2:diagram --incremental # Only changed components
\`\`\`
```

**Update state:**
```json
{
  "phase": "verification",
  "completed": ["scanner", "gate-check", "infrastructure-documenter", "architecture-documenter", "infrastructure-simplified", "architecture-simplified", "renderer", "enhancer", "readme-integration"]
}
```

---

### Phase 10: Verification (Verifier Agent)

**Model hint**: Use haiku for fast verification.

**Delegate to Verifier agent** with prompt:

```
TASK: Verify all outputs meet quality standards. Be thorough but fast.

CHECKLIST (check each, report pass/fail):

1. FILE EXISTENCE (16 diagram files + 1 README):
   [ ] ./diagrams/README.md exists
   [ ] ./diagrams/infrastructure.md exists
   [ ] ./diagrams/infrastructure.d2 exists
   [ ] ./diagrams/infrastructure-light.svg exists
   [ ] ./diagrams/infrastructure-dark.svg exists
   [ ] ./diagrams/infrastructure-simplified.md exists
   [ ] ./diagrams/infrastructure-simplified.d2 exists
   [ ] ./diagrams/infrastructure-simplified-light.svg exists
   [ ] ./diagrams/infrastructure-simplified-dark.svg exists
   [ ] ./diagrams/architecture.md exists
   [ ] ./diagrams/architecture.d2 exists
   [ ] ./diagrams/architecture-light.svg exists
   [ ] ./diagrams/architecture-dark.svg exists
   [ ] ./diagrams/architecture-simplified.md exists
   [ ] ./diagrams/architecture-simplified.d2 exists
   [ ] ./diagrams/architecture-simplified-light.svg exists
   [ ] ./diagrams/architecture-simplified-dark.svg exists

2. DOCUMENTATION QUALITY:
   [ ] infrastructure.md has Overview section
   [ ] infrastructure.md has Components section
   [ ] infrastructure.md word count > 150
   [ ] infrastructure-simplified.md has System Summary section
   [ ] infrastructure-simplified.md has Major Components section
   [ ] infrastructure-simplified.md documents 3-8 components with technology names
   [ ] architecture.md has Overview section
   [ ] architecture.md has Layers/Services section
   [ ] architecture.md word count > 150
   [ ] architecture-simplified.md has System Summary section
   [ ] architecture-simplified.md has Major Components section
   [ ] architecture-simplified.md documents 3-8 components with technology names

3. D2 SYNTAX (run these commands for all 4 D2 files):
   [ ] d2 fmt ./diagrams/infrastructure.d2 --check (exit 0)
   [ ] d2 fmt ./diagrams/infrastructure-simplified.d2 --check (exit 0)
   [ ] d2 fmt ./diagrams/architecture.d2 --check (exit 0)
   [ ] d2 fmt ./diagrams/architecture-simplified.d2 --check (exit 0)
   [ ] infrastructure.d2 has >= 3 nodes
   [ ] infrastructure.d2 has >= 2 connections (->)
   [ ] infrastructure-simplified.d2 has 3-8 nodes with technology names in labels
   [ ] infrastructure-simplified.d2 has >= 2 connections (->)
   [ ] architecture.d2 has >= 3 nodes
   [ ] architecture.d2 has >= 2 connections (->)
   [ ] architecture-simplified.d2 has 3-8 nodes with technology names in labels
   [ ] architecture-simplified.d2 has >= 2 connections (->)

4. SVG QUALITY (all 8 SVG files):
   [ ] All SVG files > 1KB
   [ ] All SVGs contain <svg tag
   [ ] All SVGs contain "traffic-flow" (animation CSS)
   [ ] All SVGs contain "prefers-reduced-motion" (accessibility)
   [ ] No SVG contains "error" or "Error"

5. README INTEGRATION:
   [ ] ./diagrams/README.md exists
   [ ] Contains <picture> elements for all 4 diagram types
   [ ] Contains both simplified and detailed sections
   [ ] Contains prefers-color-scheme media queries
   [ ] Contains links to all 4 documentation files (.md)
   [ ] All srcset paths are valid relative paths

6. MAIN README (if exists):
   [ ] Contains simplified diagrams (infrastructure-simplified, architecture-simplified)
   [ ] Contains "More diagrams" link to ./diagrams/README.md
   [ ] Uses correct relative paths (./diagrams/*.svg)

OUTPUT FORMAT (JSON):
{
  "status": "PASS" | "FAIL",
  "checks": {
    "file_existence": {"pass": N, "fail": N, "issues": []},
    "documentation": {"pass": N, "fail": N, "issues": []},
    "d2_syntax": {"pass": N, "fail": N, "issues": []},
    "svg_quality": {"pass": N, "fail": N, "issues": []},
    "readme": {"pass": N, "fail": N, "issues": []}
  },
  "summary": "X/Y checks passed",
  "action": "cleanup" | "remediate"
}

ON SUCCESS (all checks pass):
- Remove .diagram/state.json
- Report completion summary

ON FAILURE (any check fails):
- Keep .diagram/state.json
- List specific failures with remediation steps
- Do NOT clean up state
```

---

## Project Rules (./diagrams/rules.md)

Users can create `./diagrams/rules.md` to customize behavior (this file is committed with your diagrams):

```markdown
# Diagram Generation Rules

## Naming Conventions
- Use "API Gateway" not "APIGW"
- Use full service names, not abbreviations

## Excluded Paths
- Ignore test/ directory
- Ignore examples/

## Additional Components
Include these even if not in IaC:
- Cloudflare (external CDN)
- Datadog (monitoring)

## Style Overrides
- Use blue tones for our brand
- Group by team ownership

## Icons
- Disable icons (removes icon requirement and validation warnings)
- OR: Custom icon mapping:
  - MySQL → https://example.com/custom-mysql-icon.svg
  - Redis → https://example.com/custom-redis-icon.svg

## Documentation Sections
Add these custom sections:
- Team Ownership
- SLA Requirements
```

### Icon Customization

By default, icons are **required** on all technology nodes. To customize:

**Disable icons entirely:**
```markdown
## Icons
- Disable icons
```

**Use custom icon URLs:**
```markdown
## Icons
- MySQL → https://example.com/mysql.svg
- PostgreSQL → https://example.com/postgres.svg
```

When icons are disabled:
- The `icon:` property is not added to nodes
- Validation warnings for missing icons are suppressed
- Diagrams rely on `shape:` and `class:` for visual distinction

---

## Error Handling

| Error | Recovery |
|-------|----------|
| D2 not installable | Abort with manual install instructions |
| No IaC found | Offer code-only analysis or abort |
| D2 syntax error | Auto-fix and retry (3 attempts) |
| Render failure | Fall back to dagre layout |
| Context limit | Use --incremental or --scope |
| Large codebase | Split into focused diagrams |

---

## Output Summary

When complete, report:
1. Files created/modified (with paths)
2. Components discovered (counts by type)
3. Verification status (pass/fail details)
4. Warnings or items needing manual review
5. Suggestions for improvements

```
Diagram Generation Complete
===========================
Files created:
  README.md (updated with simplified diagrams)
  ./diagrams/README.md (landing page with all diagrams)

  Infrastructure (detailed):
    ./diagrams/infrastructure.md (2,500 words)
    ./diagrams/infrastructure.d2
    ./diagrams/infrastructure-light.svg
    ./diagrams/infrastructure-dark.svg

  Infrastructure (simplified):
    ./diagrams/infrastructure-simplified.md (350 words)
    ./diagrams/infrastructure-simplified.d2
    ./diagrams/infrastructure-simplified-light.svg
    ./diagrams/infrastructure-simplified-dark.svg

  Architecture (detailed):
    ./diagrams/architecture.md (3,000 words)
    ./diagrams/architecture.d2
    ./diagrams/architecture-light.svg
    ./diagrams/architecture-dark.svg

  Architecture (simplified):
    ./diagrams/architecture-simplified.md (450 words)
    ./diagrams/architecture-simplified.d2
    ./diagrams/architecture-simplified-light.svg
    ./diagrams/architecture-simplified-dark.svg

Components documented:
  Compute: 8 resources
  Data stores: 4 resources
  Networking: 6 resources
  Services: 12 modules

Verification: PASSED (all checks)

Main README: Updated with simplified diagrams
All diagrams: ./diagrams/README.md
```
