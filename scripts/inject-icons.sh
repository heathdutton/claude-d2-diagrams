#!/bin/bash
# inject-icons.sh - Extract and inline only the needed icon classes into a D2 file
#
# Instead of copying icons.d2 to every project, this script:
# 1. Scans a D2 file for {class: xyz} references
# 2. Extracts only those class definitions from the plugin's icons.d2
# 3. Inlines them at the top of the D2 file
#
# Usage: ./inject-icons.sh <d2-file>
#        ./inject-icons.sh --all <directory>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICONS_FILE="$SCRIPT_DIR/../diagrams/icons.d2"

inject_icons() {
    local d2_file="$1"

    if [ ! -f "$d2_file" ]; then
        echo "Error: File not found: $d2_file"
        return 1
    fi

    if [ ! -f "$ICONS_FILE" ]; then
        echo "Error: Icons file not found: $ICONS_FILE"
        return 1
    fi

    # Extract all class names used in the D2 file
    local classes=$(grep -oE '\{class:\s*[a-zA-Z0-9_-]+' "$d2_file" | sed 's/{class:\s*//' | sort -u)

    if [ -z "$classes" ]; then
        echo "No icon classes found in $d2_file"
        return 0
    fi

    echo "Found classes: $classes"

    # Use Python to extract class definitions
    python3 << EOF
import re

# Read icons.d2
with open('$ICONS_FILE', 'r') as f:
    icons_content = f.read()

# Read target D2 file
with open('$d2_file', 'r') as f:
    d2_content = f.read()

# Classes to extract
classes = '''$classes'''.strip().split('\n')
classes = [c.strip() for c in classes if c.strip()]

# Remove any existing ...@icons.d2 import
d2_content = re.sub(r'^\s*\.\.\.@icons\.d2\s*\n?', '', d2_content, flags=re.MULTILINE)

# Extract class definitions from icons.d2
# Pattern matches: classname: { ... } with nested braces
extracted = []
for cls in classes:
    # Match the class definition with its content
    pattern = rf'^  {re.escape(cls)}:\s*\{{([^{{}}]*(?:\{{[^{{}}]*\}}[^{{}}]*)*)\}}'
    match = re.search(pattern, icons_content, re.MULTILINE)
    if match:
        extracted.append(f'  {cls}: {{{match.group(1)}}}')
    else:
        print(f"Warning: Class '{cls}' not found in icons.d2")

if not extracted:
    print("No matching classes found")
    exit(0)

# Build classes block
classes_block = "classes {\n" + "\n".join(extracted) + "\n}\n\n"

# Check if file already has a classes block
if re.search(r'^classes\s*\{', d2_content, re.MULTILINE):
    # Merge into existing classes block
    def merge_classes(match):
        existing = match.group(1)
        # Add new classes before closing brace
        return "classes {\n" + "\n".join(extracted) + "\n" + existing + "}"
    d2_content = re.sub(r'^classes\s*\{([^}]*)\}', merge_classes, d2_content, flags=re.MULTILINE)
else:
    # Prepend classes block
    d2_content = classes_block + d2_content

# Write back
with open('$d2_file', 'w') as f:
    f.write(d2_content)

print(f"Injected {len(extracted)} icon classes into $d2_file")
EOF
}

# Main
if [ "$1" = "--all" ]; then
    if [ -z "$2" ]; then
        echo "Usage: $0 --all <directory>"
        exit 1
    fi

    find "$2" -name "*.d2" -type f | while read -r d2; do
        echo "Processing: $d2"
        inject_icons "$d2"
    done
else
    if [ -z "$1" ]; then
        echo "Usage: $0 <d2-file>"
        echo "       $0 --all <directory>"
        exit 1
    fi

    inject_icons "$1"
fi
