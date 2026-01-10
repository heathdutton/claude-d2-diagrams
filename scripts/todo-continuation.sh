#!/bin/bash
# Todo continuation enforcement hook
# Prevents the diagram command from stopping with incomplete phases

# Check for diagram state file
STATE_DIR=".diagram"
STATE_FILE="$STATE_DIR/state.json"

# If no state directory, diagram command hasn't started - allow stop
if [[ ! -d "$STATE_DIR" ]]; then
  exit 0
fi

# If no state file, nothing to enforce
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse state file for incomplete phases
# Expected format: {"phase": "current", "completed": ["phase1", "phase2"], "total": 6}
if command -v jq &> /dev/null; then
  CURRENT_PHASE=$(jq -r '.phase // "unknown"' "$STATE_FILE" 2>/dev/null)
  COMPLETED_COUNT=$(jq -r '.completed | length // 0' "$STATE_FILE" 2>/dev/null)
  TOTAL_PHASES=$(jq -r '.total // 6' "$STATE_FILE" 2>/dev/null)
else
  # Fallback: grep-based parsing
  CURRENT_PHASE=$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"$/\1/')
  COMPLETED_COUNT=$(grep -o '"completed"' "$STATE_FILE" | wc -l)
  TOTAL_PHASES=6
fi

# Check if all phases are complete
if [[ "$COMPLETED_COUNT" -lt "$TOTAL_PHASES" ]]; then
  cat << EOF
Diagram generation incomplete. Do not stop.

Current phase: $CURRENT_PHASE
Completed: $COMPLETED_COUNT / $TOTAL_PHASES phases

Remaining work must be completed:
- Phase 1: Discovery (IaC, docs, D2 verification)
- Phase 2: Gate Check (verify prerequisites)
- Phase 3: Infrastructure Documentation
- Phase 4: Architecture Documentation
- Phase 5: Diagram Generation (D2 to SVG)
- Phase 6: README Integration

Continue working on the current phase until all phases are complete.
EOF
  exit 1
fi

# All phases complete - allow stop
echo "All diagram phases complete. Cleaning up state."
rm -f "$STATE_FILE"
exit 0
