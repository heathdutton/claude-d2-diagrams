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

# Check if we need to compile
need_compile=false
if [ ! -f "$GO_BINARY" ]; then
    need_compile=true
elif [ "$GO_SOURCE" -nt "$GO_BINARY" ]; then
    need_compile=true
fi

# If binary exists and is up to date, just run it
if [ "$need_compile" = false ]; then
    exec "$GO_BINARY" "$@"
fi

# Need to compile - check if Go is available
if ! command -v go &> /dev/null; then
    echo "Warning: Go not installed, skipping SVG icon inlining."
    echo "Icons may not display on GitHub. Install Go from https://go.dev/dl/ to enable."
    exit 0
fi

# Compile and run
echo "Compiling inline-svg-icons..."
go build -o "$GO_BINARY" "$GO_SOURCE"
exec "$GO_BINARY" "$@"
