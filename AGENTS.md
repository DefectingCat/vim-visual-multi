<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# vim-visual-multi

## Purpose
A Vim/Neovim plugin for simultaneous multi-cursor editing. Provides visual-multi mode analogous to visual-block, but works primarily from normal mode. Supports cursor mode (normal-like) and extend mode (visual-like) with comprehensive editing operations.

## Key Files

| File | Description |
|------|-------------|
| `README.md` | Plugin documentation and usage guide |
| `LICENSE` | MIT license |
| `tutorialrc` | Tutorial configuration for `vim -Nu tutorialrc` |
| `run_tests` | Test runner script |
| `.luarc.json` | LuaLS configuration for Neovim development |
| `stylua.toml` | StyLua formatter configuration |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `lua/` | Lua implementation for Neovim (see `lua/AGENTS.md`) |
| `plugin/` | Plugin loader and mappings (see `plugin/AGENTS.md`) |
| `doc/` | Vim help documentation (see `doc/AGENTS.md`) |
| `test/` | Integration tests (see `test/AGENTS.md`) |
| `python/` | Python helper module (see `python/AGENTS.md`) |
| `scripts/` | Development scripts (see `scripts/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- This is a Lua/Neovim implementation of the multi-cursor plugin
- Run `scripts/lint-lua.sh` before committing Lua changes

### Testing Requirements
- Run tests via `./run_tests` or `python test/test.py`
- Lua tests in `lua/visual-multi/test/` use custom test runner
- Each test in `test/tests/` has `commands.py`, `input_file.txt`, `expected_output_file.txt`

### Common Patterns
- Lua modules use `visual-multi.module` naming
- State is stored in `vim.b.visual_multi_active`
- Regions are the core data structure representing cursor selections

## Dependencies

### Internal
- `lua/visual-multi/` — core modules
- `lua/visual-multi/maps/` — mapping definitions
- `lua/visual-multi/special/` — special commands (case conversion, etc.)

### External
- Neovim 0.5+ for Lua support
- Python 3 optional for integration tests

<!-- MANUAL: -->
