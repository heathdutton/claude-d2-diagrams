#!/bin/bash
# inline-svg-icons.sh - Wrapper for the Go-based SVG icon inliner
#
# This script compiles and runs the Go program that converts <image> tags
# to inline <svg> elements for GitHub compatibility.
#
# Usage: ./inline-svg-icons.sh <svg-file>
#        ./inline-svg-icons.sh --all <directory>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GO_SOURCE="$SCRIPT_DIR/inline-svg-icons.go"
GO_BINARY="$SCRIPT_DIR/.inline-svg-icons"

# Check if Go is available
if ! command -v go &> /dev/null; then
    echo "Error: Go is required but not installed."
    echo "Install Go from https://go.dev/dl/ or via your package manager."
    exit 1
fi

# Compile if binary doesn't exist or source is newer
if [ ! -f "$GO_BINARY" ] || [ "$GO_SOURCE" -nt "$GO_BINARY" ]; then
    echo "Compiling inline-svg-icons..."
    go build -o "$GO_BINARY" "$GO_SOURCE"
fi

# Run the binary with all arguments
exec "$GO_BINARY" "$@"
