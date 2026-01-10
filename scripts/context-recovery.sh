#!/bin/bash
# Context window recovery hook
# Detects context limit issues and provides recovery guidance

# This hook monitors for context-related errors and provides
# strategies for continuing diagram generation with limited context

ERROR_MSG="${CLAUDE_ERROR_MESSAGE:-}"

# Check for context/token limit indicators
if [[ "$ERROR_MSG" == *"context"* ]] || \
   [[ "$ERROR_MSG" == *"token"* ]] || \
   [[ "$ERROR_MSG" == *"limit"* ]] || \
   [[ "$ERROR_MSG" == *"too long"* ]]; then

  cat << 'EOF'
Context window limit detected during diagram generation.

Recovery strategies:

1. INCREMENTAL MODE: Use --incremental flag to process one component at a time
   /diagram --incremental

2. CHECKPOINT RESUME: If state was saved, resume from last checkpoint
   Check .diagram/state.json for progress

3. SCOPED ANALYSIS: Focus on specific directories
   /diagram --scope=src/
   /diagram --scope=infrastructure/

4. SIMPLIFIED OUTPUT: Generate only infrastructure OR architecture
   /diagram --infrastructure-only
   /diagram --architecture-only

5. MANUAL COMPACTION: Run /compact then retry /diagram

Current state preserved in .diagram/ directory.
Review .diagram/state.json to see completed phases.
EOF
  exit 0
fi

exit 0
