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
lua-language-server --check lua/ 2>&1

echo ""
echo "========================"
echo "Done."
