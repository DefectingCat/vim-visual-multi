<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# lua/

## Purpose
Lua/Neovim implementation of the vim-visual-multi multi-cursor plugin. This is a work-in-progress rewrite of the Vimscript implementation in `autoload/vm/`, designed for Neovim 0.5+ with native Lua support.

## Key Files

| File | Description |
|------|-------------|
| `visual-multi/init.lua` | Entry point with `setup()` and `init_buffer()` functions |
| `visual-multi/state.lua` | Buffer-local state management, replaces `b:VM_Selection` |
| `visual-multi/region.lua` | Region class - manages cursor positions, content, highlighting |
| `visual-multi/global.lua` | Global class - regions, modes, highlighting, region selection |
| `visual-multi/config.lua` | Configuration management, reads `g:VM_*` global variables |
| `visual-multi/funcs.lua` | Utility functions - position/byte conversions, registers |
| `visual-multi/maps.lua` | Mapping registration and buffer-local key bindings |
| `visual-multi/edit.lua` | Edit operations - delete, change, yank, paste |
| `visual-multi/search.lua` | Search pattern management for regex mode |
| `visual-multi/operators.lua` | Operator functions for motions and text objects |
| `visual-multi/insert.lua` | Insert mode handling for multi-cursor editing |
| `visual-multi/cursors.lua` | Cursor navigation and movement functions |
| `visual-multi/visual.lua` | Visual mode integration |
| `visual-multi/commands.lua` | Ex command implementations |
| `visual-multi/bytes.lua` | Byte offset calculations |
| `visual-multi/offset.lua` | Position/offset conversion utilities |
| `visual-multi/themes.lua` | Highlight group definitions |
| `visual-multi/plugs.lua` | `<Plug>` mapping definitions |
| `visual-multi/plugin.lua` | Plugin initialization |
| `visual-multi/vm.lua` | Main VM module coordination |
| `visual-multi/api_compat.lua` | API compatibility layer for Vimscript interop |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `visual-multi/` | Core Lua implementation modules |
| `visual-multi/maps/` | Key mapping definitions (see `visual-multi/maps/AGENTS.md`) |
| `visual-multi/special/` | Special commands - case conversion, etc. (see `visual-multi/special/AGENTS.md`) |
| `visual-multi/test/` | Unit tests with custom test runner (see `visual-multi/test/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- Module naming: `visual-multi.module` (e.g., `require("visual-multi.region")`)
- All modules return a table `M` with public functions
- Initialize modules via `.init()` before use - sets up internal references
- State is stored in `state.buffer_state[bufnr]` and synced to `vim.b.visual_multi_active`
- Run `scripts/lint-lua.sh` before committing Lua changes (StyLua formatting + LuaLS)
- Maintain API compatibility with Vimscript implementation in `autoload/vm/`

### Module Initialization Pattern
```lua
local M = {}
local state, config, vars, regions

function M.init()
  state = require("visual-multi.state").get()
  config = require("visual-multi.config")
  vars = state.vars
  regions = state.regions
end

return M
```

### State Management
- Buffer state: `state.get(bufnr)` returns table with `vars`, `regions`, `bytes`
- Global state: `vim.g.Vm` table for `extend_mode` and other globals
- Vimscript sync: `state.sync_to_vimscript()` / `state.sync_from_vimscript()`
- Check active: `vim.b.visual_multi_active == true`

### Region Data Structure
Each region has:
- Position: `l`, `L` (line start/end), `a`, `b` (column start/end)
- Byte offsets: `A`, `B`
- Metadata: `id`, `index`, `dir`, `txt`, `pat`, `w`, `h`
- Methods: `:highlight()`, `:remove()`, `:update()`, `:shift()`

### Testing Requirements
- Tests in `visual-multi/test/` use a custom test runner
- Run tests: `nvim -l lua/visual-multi/test/run_tests.lua`
- Test files follow `*_spec.lua` naming convention
- Each test module exports `run_all()` returning pass/fail status

### Common Patterns

**Create a new region:**
```lua
local region = require("visual-multi.region")
region.init()
local R = region.new(cursor)  -- cursor=true for cursor position, false for marks
```

**Get current buffer state:**
```lua
local state = require("visual-multi.state")
local s = state.get()
local regions = s.regions
local vars = s.vars
```

**Check extend mode:**
```lua
local is_extend = vim.g.Vm and vim.g.Vm.extend_mode == 1
```

### Key Dependencies
- Neovim 0.5+ for Lua API
- `vim.api`, `vim.fn`, `vim.b`, `vim.g` for Neovim interaction
- Parallel Vimscript implementation in `autoload/vm/` for reference

## Dependencies

### Internal
- `autoload/vm/` - Vimscript implementation (reference for API compatibility)
- `plugin/visual-multi.vim` - Plugin loader

### External
- Neovim 0.5+ with Lua support
- LuaLS for type checking (`.luarc.json`)
- StyLua for formatting (`stylua.toml`)

<!-- MANUAL: -->
