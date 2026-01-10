#!/bin/bash
# Check if D2 is installed and available

if command -v d2 &> /dev/null; then
  D2_VERSION=$(d2 --version 2>/dev/null | head -1)
  echo "D2 available: $D2_VERSION"
  exit 0
fi

# D2 not found - provide installation guidance
cat << 'EOF'
D2 is not installed. The /diagram command requires D2 to generate diagrams.

Install D2 via one of:
  brew install d2                                      # macOS
  curl -fsSL https://d2lang.com/install.sh | sh -s --  # Linux
  go install oss.terrastruct.com/d2@latest             # Go / Win

EOF

# Exit 0 (non-blocking) - just a warning, don't prevent session start
# The /diagram command will attempt installation if needed
exit 0
