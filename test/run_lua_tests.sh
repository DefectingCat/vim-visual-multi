#!/bin/bash
# Run Lua tests for visual-multi

cd "$(dirname "$0")/.."

PROJECT_DIR="/home/xfy/Developer/vim-visual-multi"

echo "Running visual-multi Lua tests..."

# Run basic module tests
nvim --headless -c "lua vim.opt.rtp:prepend('$PROJECT_DIR'); require('visual-multi.test.init_spec').run()" -c "qa!" 2>&1

# Run API compatibility tests
echo ""
echo "Running API compatibility tests..."
nvim --headless -c "lua vim.opt.rtp:prepend('$PROJECT_DIR'); require('visual-multi.api_compat').run_all()" -c "qa!" 2>&1

# Run Region class tests
echo ""
echo "Running Region class tests..."
nvim --headless -c "lua vim.opt.rtp:prepend('$PROJECT_DIR'); require('visual-multi.test.region_spec').run_all()" -c "qa!" 2>&1

# Run Global class tests
echo ""
echo "Running Global class tests..."
nvim --headless -c "lua vim.opt.rtp:prepend('$PROJECT_DIR'); require('visual-multi.test.global_spec').run_all()" -c "qa!" 2>&1

echo ""
echo "Tests complete."