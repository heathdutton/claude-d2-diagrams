#!/bin/bash
# optimize-svg.sh - Deduplicate embedded icons in SVG files
#
# D2's --bundle flag embeds each icon as a separate base64 image.
# This script deduplicates them using SVG's <defs> + <use> pattern.
#
# Usage: ./optimize-svg.sh <svg-file>
#        ./optimize-svg.sh --all <directory>

set -e

optimize_svg() {
    local svg_file="$1"
    local temp_file="${svg_file}.tmp"

    # Check if file exists
    if [ ! -f "$svg_file" ]; then
        echo "Error: File not found: $svg_file"
        return 1
    fi

    # Count icons before optimization
    local before_count=$(grep -o '<image ' "$svg_file" | wc -l | tr -d ' ')

    if [ "$before_count" -eq 0 ]; then
        echo "No embedded icons found in $svg_file"
        return 0
    fi

    # Use Python for robust SVG manipulation
    python3 << EOF
import re
import hashlib
from collections import defaultdict

# Read SVG
with open('$svg_file', 'r') as f:
    svg = f.read()

# Find all image elements with data URIs
image_pattern = r'<image ([^>]*href="(data:image[^"]+)"[^>]*)>'
matches = list(re.finditer(image_pattern, svg))

if len(matches) < 2:
    print(f"Only {len(matches)} image(s) found, no deduplication needed")
    exit(0)

# Group by data URI
uri_to_images = defaultdict(list)
for match in matches:
    full_attrs = match.group(1)
    data_uri = match.group(2)
    uri_hash = hashlib.md5(data_uri.encode()).hexdigest()[:8]
    uri_to_images[uri_hash].append({
        'full_match': match.group(0),
        'attrs': full_attrs,
        'uri': data_uri
    })

# Find duplicates
duplicates = {k: v for k, v in uri_to_images.items() if len(v) > 1}

if not duplicates:
    print("No duplicate icons found")
    exit(0)

# Build defs section
defs_content = []
replacements = []

for uri_hash, images in duplicates.items():
    # Create symbol from first occurrence
    first = images[0]
    symbol_id = f"icon-{uri_hash}"

    # Extract position attributes (x, y, width, height)
    x_match = re.search(r'x="([^"]+)"', first['attrs'])
    y_match = re.search(r'y="([^"]+)"', first['attrs'])
    w_match = re.search(r'width="([^"]+)"', first['attrs'])
    h_match = re.search(r'height="([^"]+)"', first['attrs'])

    width = w_match.group(1) if w_match else "24"
    height = h_match.group(1) if h_match else "24"

    # Create symbol with the embedded image (first occurrence keeps original structure)
    defs_content.append(f'<symbol id="{symbol_id}" viewBox="0 0 {width} {height}"><image width="{width}" height="{height}" href="{first["uri"]}"/></symbol>')

    # Replace all occurrences with <use>
    for img in images:
        x = re.search(r'x="([^"]+)"', img['attrs'])
        y = re.search(r'y="([^"]+)"', img['attrs'])
        w = re.search(r'width="([^"]+)"', img['attrs'])
        h = re.search(r'height="([^"]+)"', img['attrs'])

        x_val = x.group(1) if x else "0"
        y_val = y.group(1) if y else "0"
        w_val = w.group(1) if w else width
        h_val = h.group(1) if h else height

        use_element = f'<use href="#{symbol_id}" x="{x_val}" y="{y_val}" width="{w_val}" height="{h_val}"/>'
        replacements.append((img['full_match'], use_element))

# Insert defs after opening svg tag
defs_block = '<defs>' + ''.join(defs_content) + '</defs>'

# Find svg opening tag and insert defs
svg_tag_match = re.search(r'(<svg[^>]*>)', svg)
if svg_tag_match:
    insert_pos = svg_tag_match.end()
    svg = svg[:insert_pos] + defs_block + svg[insert_pos:]

# Apply replacements (from last to first to preserve positions)
for old, new in reversed(replacements):
    svg = svg.replace(old, new, 1)

# Write optimized SVG
with open('$svg_file', 'w') as f:
    f.write(svg)

saved = len(replacements) - len(duplicates)
print(f"Optimized: {len(duplicates)} unique icons, {saved} duplicates removed")
EOF

    # Count icons after optimization
    local after_count=$(grep -o '<use ' "$svg_file" | wc -l | tr -d ' ')
    echo "  Before: $before_count <image> elements"
    echo "  After: Using <defs>/<use> pattern"
}

# Main
if [ "$1" = "--all" ]; then
    if [ -z "$2" ]; then
        echo "Usage: $0 --all <directory>"
        exit 1
    fi

    find "$2" -name "*.svg" -type f | while read -r svg; do
        echo "Optimizing: $svg"
        optimize_svg "$svg"
    done
else
    if [ -z "$1" ]; then
        echo "Usage: $0 <svg-file>"
        echo "       $0 --all <directory>"
        exit 1
    fi

    optimize_svg "$1"
fi
