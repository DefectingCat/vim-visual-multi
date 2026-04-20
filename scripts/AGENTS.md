<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# scripts/

## Purpose
Development utility scripts for linting, formatting, and project maintenance.

## Key Files

| File | Description |
|------|-------------|
| `lint-lua.sh` | Run lua-language-server diagnostics on Lua files |

## For AI Agents

### Working In This Directory
- Scripts are development tools, not runtime dependencies
- `lint-lua.sh` requires `lua-language-server` (install via `pacman -S lua-language-server`)
- Run linting before committing Lua changes to catch issues early

### lint-lua.sh Behavior
- Checks `lua/` directory for LSP warnings and errors
- Filters expected warnings: `undefined-global`, `need-check-nil`
- Exit code 1 if lua-language-server is not installed
- Use `scripts/lint-lua.sh` from project root

### Common Tasks
```bash
# Check Lua files for issues
./scripts/lint-lua.sh

# Install required tool
pacman -S lua-language-server
```

## Dependencies

### External
- `lua-language-server` — Lua LSP for diagnostics
