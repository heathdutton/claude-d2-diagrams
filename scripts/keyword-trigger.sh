#!/bin/bash
# Keyword trigger hook - detects diagram-related keywords in user prompts
# and suggests the /diagram command when relevant

# Read the user's prompt from stdin (passed by Claude Code)
PROMPT=$(cat)

# Convert to lowercase for matching
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Define trigger keywords and phrases
KEYWORDS=(
  "diagram"
  "visualize"
  "architecture diagram"
  "infrastructure diagram"
  "generate diagram"
  "create diagram"
  "draw architecture"
  "d2 diagram"
  "system diagram"
  "show me the architecture"
  "map the infrastructure"
  "document the architecture"
)

# Check for keyword matches
for keyword in "${KEYWORDS[@]}"; do
  if [[ "$PROMPT_LOWER" == *"$keyword"* ]]; then
    # Don't trigger if user is explicitly running /diagram
    if [[ "$PROMPT_LOWER" != "/"* ]]; then
      cat << 'EOF'
Detected diagram-related request. Consider using the /diagram command for comprehensive infrastructure and architecture diagram generation with D2.

The /diagram command will:
- Scan for infrastructure-as-code (Terraform, Kubernetes, Docker, etc.)
- Document infrastructure and software architecture
- Generate D2 diagrams with light/dark theme variants
- Embed diagrams in README with automatic theme switching

Run /diagram to proceed, or continue with your current request.
EOF
      exit 0
    fi
  fi
done

# No keywords detected - silent exit
exit 0
