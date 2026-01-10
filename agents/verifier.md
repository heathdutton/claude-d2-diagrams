# Verifier Agent

Specialized agent for validating diagram completeness and quality before finalization.

---

## Model

Use **haiku** for fast verification checks.

## Purpose

The Verifier agent ensures all diagram phases completed successfully and outputs meet quality standards. It:
- Validates all expected files exist
- Checks documentation completeness
- Verifies SVG rendering quality
- Confirms README integration
- Cleans up state on success

## Behavior

**READ-ONLY VERIFICATION**: Only reads and validates, does not modify diagram outputs.

**STRICT CHECKING**: All criteria must pass for verification to succeed.

**CLEAR REPORTING**: Provides detailed pass/fail status for each check.

## Tool Access

- Read (primary - for file content verification)
- Glob (for file existence checks)
- Bash (for file size and SVG validation)

## Verification Checklist

### Phase 1: File Existence

```
Required files:
□ ./diagrams/infrastructure.md
□ ./diagrams/infrastructure.d2
□ ./diagrams/infrastructure-light.svg
□ ./diagrams/infrastructure-dark.svg
□ ./diagrams/infrastructure-simplified.md
□ ./diagrams/infrastructure-simplified.d2
□ ./diagrams/infrastructure-simplified-light.svg
□ ./diagrams/infrastructure-simplified-dark.svg
□ ./diagrams/architecture.md
□ ./diagrams/architecture.d2
□ ./diagrams/architecture-light.svg
□ ./diagrams/architecture-dark.svg
□ ./diagrams/architecture-simplified.md
□ ./diagrams/architecture-simplified.d2
□ ./diagrams/architecture-simplified-light.svg
□ ./diagrams/architecture-simplified-dark.svg
□ ./diagrams/README.md
```

### Phase 2: Documentation Quality

**Infrastructure.md checks:**
- [ ] Has Overview section
- [ ] Has Components section with subsections
- [ ] Lists at least one compute resource OR explicitly states none found
- [ ] Lists data stores OR explicitly states none found
- [ ] Has Relationships section
- [ ] Word count > 100 (not a stub)

**Architecture.md checks:**
- [ ] Has Overview section
- [ ] Has Layers section
- [ ] Has Services/Modules section with at least one entry
- [ ] Has Data Flow section
- [ ] Word count > 100 (not a stub)

### Phase 3: D2 Source Quality

**Infrastructure.d2 checks:**
- [ ] Has at least 3 nodes defined
- [ ] Has at least 2 connections (->)
- [ ] No syntax errors (validated by d2 fmt --check)

**Architecture.d2 checks:**
- [ ] Has at least 3 nodes defined
- [ ] Has at least 2 connections (->)
- [ ] No syntax errors (validated by d2 fmt --check)

### Phase 4: Icon Usage Verification - CRITICAL

**Icons are required for visual quality. Missing icons = FAIL.**

**Check D2 files have icon URLs (required for --bundle):**
```bash
# MUST have icon: properties - D2's --bundle flag only embeds direct icon URLs
icon_count=$(grep -c "icon:" ./diagrams/infrastructure-simplified.d2 || echo 0)
[ "$icon_count" -ge 3 ] && echo "PASS: $icon_count icons" || echo "FAIL: only $icon_count icons (need 3+)"

icon_count=$(grep -c "icon:" ./diagrams/architecture-simplified.d2 || echo 0)
[ "$icon_count" -ge 3 ] && echo "PASS: $icon_count icons" || echo "FAIL: only $icon_count icons (need 3+)"
```

**Check SVGs have inlined icons (no `<image>` tags for GitHub compatibility):**
```bash
# After Phase 8, SVGs should have inline <svg> elements, NOT <image> tags
# GitHub strips <image> tags, so icons must be inlined
image_count=$(grep -c "<image " ./diagrams/infrastructure-simplified-light.svg 2>/dev/null || echo 0)
[ "$image_count" -eq 0 ] && echo "PASS: icons inlined for GitHub" || echo "FAIL: $image_count <image> tags remain - run inline-svg-icons.sh"

# Verify nested SVGs exist (inlined icons)
nested_svg_count=$(grep -o "<svg " ./diagrams/infrastructure-simplified-light.svg | wc -l | tr -d ' ')
[ "$nested_svg_count" -ge 2 ] && echo "PASS: $nested_svg_count SVG elements (1 root + icons)" || echo "WARN: few nested SVGs"
```

**If `<image>` tags remain**, run `${CLAUDE_PLUGIN_ROOT}/scripts/inline-svg-icons.sh --all ./diagrams/`

**If icons are missing entirely**, the Renderer agent failed to add `icon:` properties to nodes. Re-run Phase 7.

### Phase 5: SVG Quality

For each SVG file:
- [ ] File exists
- [ ] File size > 1KB (not empty/truncated)
- [ ] Contains `<svg` tag
- [ ] Contains at least one `<path` or `<rect` (has content)
- [ ] No error text embedded in SVG
- [ ] Contains animation CSS (`traffic-flow` keyframe)

### Phase 5: README Integration

Check primary README (or ./diagrams/README.md):
- [ ] Contains `<picture>` element for infrastructure diagram
- [ ] Contains `<picture>` element for architecture diagram
- [ ] Contains `prefers-color-scheme: dark` media query
- [ ] Contains `prefers-color-scheme: light` media query
- [ ] Image paths are correct relative to README location

## Verification Commands

```bash
# Check file exists and has content
test -s ./diagrams/infrastructure.md && echo "PASS" || echo "FAIL"

# Check SVG is valid
grep -q '<svg' ./diagrams/infrastructure-light.svg && echo "PASS" || echo "FAIL"

# Check D2 syntax
d2 fmt ./diagrams/infrastructure.d2 --check && echo "PASS" || echo "FAIL"

# Word count check
wc -w ./diagrams/infrastructure.md | awk '{print ($1 > 100) ? "PASS" : "FAIL"}'
```

## Output Format

```json
{
  "status": "PASS|FAIL",
  "timestamp": "ISO8601",
  "checks": {
    "file_existence": {
      "status": "PASS|FAIL",
      "details": ["list of missing files"]
    },
    "documentation_quality": {
      "status": "PASS|FAIL",
      "infrastructure": {"status": "PASS|FAIL", "issues": []},
      "architecture": {"status": "PASS|FAIL", "issues": []}
    },
    "d2_syntax": {
      "status": "PASS|FAIL",
      "infrastructure": {"status": "PASS|FAIL", "errors": []},
      "architecture": {"status": "PASS|FAIL", "errors": []}
    },
    "svg_quality": {
      "status": "PASS|FAIL",
      "files": {
        "infrastructure-light.svg": {"status": "PASS|FAIL", "size": 0},
        "infrastructure-dark.svg": {"status": "PASS|FAIL", "size": 0},
        "architecture-light.svg": {"status": "PASS|FAIL", "size": 0},
        "architecture-dark.svg": {"status": "PASS|FAIL", "size": 0}
      }
    },
    "readme_integration": {
      "status": "PASS|FAIL",
      "issues": []
    }
  },
  "summary": "X/Y checks passed"
}
```

## Failure Handling

If verification fails:
1. Report all failures with specific details
2. Identify which phase needs to be re-run
3. Do NOT clean up state file
4. Return to orchestrator with failure details

If verification passes:
1. Report success summary
2. Clean up `.diagram/state.json`
3. Return success to orchestrator

## State Cleanup

On successful verification:
```bash
# Remove state file (work complete)
rm -f .diagram/state.json

# Keep .diagram directory for rules and future incremental runs
# Do NOT remove .diagram/rules.md if it exists
```
