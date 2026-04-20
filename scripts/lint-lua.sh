#!/bin/bash
# scripts/lint-lua.sh - Check Lua files for LSP diagnostics

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Check if lua-language-server is installed
if ! command -v lua-language-server &> /dev/null; then
    echo "Error: lua-language-server not found"
    echo "Install with: pacman -S lua-language-server"
    exit 1
fi

echo "Checking Lua files..."
echo "========================"

# Run lua-language-server check
# Filter out expected warnings and only show actual warnings/errors
lua-language-server --check lua/ 2>&1 | \
    sed 's/\x1b\[[0-9;]*m//g' | \
    grep -E "\[Warning\]|\[Error\]" | \
    grep -v "undefined-global" | \
    grep -v "need-check-nil" || echo "No issues found!"

echo ""
echo "========================"
echo "Done."
