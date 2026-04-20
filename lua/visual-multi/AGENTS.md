<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->
<!-- Parent: ../AGENTS.md -->

# lua/visual-multi/

## Purpose
Core Lua modules for the vim-visual-multi Neovim implementation. This directory contains the main multi-cursor functionality including region management, editing operations, cursor navigation, insert mode handling, and plugin integration.

## Key Files

### Entry Points and Initialization
| File | Description |
|------|-------------|
| `init.lua` | Module entry point with `setup()` for configuration and `init_buffer()` for buffer initialization |
| `vm.lua` | Main VM module - initialization lifecycle, buffer state management, reset operations |
| `plugin.lua` | Plugin loader - defines user commands (VMTheme, VMDebug, VMClear, VMLive, VMRegisters, VMSearch) |
| `api_compat.lua` | API compatibility verification - tests Neovim Lua API behavior for byte/position operations |

### State and Configuration
| File | Description |
|------|-------------|
| `state.lua` | Buffer-local state storage - replaces `b:VM_Selection`, manages `vars`, `regions`, `bytes` tables |
| `config.lua` | Configuration management - reads `g:VM_*` globals, provides `get()`/`set()` accessors |
| `variables.lua` | Vim variable management - sets/resets options (foldenable, smartcase, virtualedit, etc.) |

### Core Classes
| File | Description |
|------|-------------|
| `region.lua` | Region class - manages cursor/selection positions, byte offsets, highlighting, content |
| `global.lua` | Global class - region creation/selection, mode switching, highlighting, merging operations |
| `funcs.lua` | Utility functions - position/byte conversions, registers, scroll handling, messages |
| `edit.lua` | Edit operations - `run_normal()`, `run_visual()`, `process()` for command execution over regions |
| `cursors.lua` | Cursor operations - yank/delete/change at cursors, motion parsing, text object handling |
| `insert.lua` | Insert mode - multi-cursor text insertion, live editing, Cursor/Line inner classes |
| `search.lua` | Search management - pattern escaping, register handling, pattern rewriting/validation |
| `commands.lua` | Command implementations - add cursor, find operations, motions, alignment, undo/redo |

### Operators and Visual Mode
| File | Description |
|------|-------------|
| `operators.lua` | Operator functions - select operator (`s`), find operator (`m`), after-yank handling |
| `visual.lua` | Visual mode integration - add/subtract regions from visual selection, cursor creation |

### Mappings and Commands
| File | Description |
|------|-------------|
| `maps.lua` | Mapping management - buffer-local key bindings, enable/disable, custom mappings integration |
| `plugs.lua` | `<Plug>` definitions - permanent and buffer-local plug mappings for all VM commands |

### Edit Commands
| File | Description |
|------|-------------|
| `ecmds1.lua` | Edit commands #1 - yank, delete, paste, replace operations |
| `ecmds2.lua` | Edit commands #2 - duplicate, change, surround, rotate, transpose, align, shift, numbers |
| `icmds.lua` | Insert mode commands - backspace/delete, Ctrl-W/U, paste, return, line insertion |

### Utilities
| File | Description |
|------|-------------|
| `bytes.lua` | Byte map operations - `rebuild_from_map()` and `lines_with_regions()` (Python replacement) |
| `offset.lua` | Position/offset conversion - `pos2byte()`, `byte2pos()`, `curs2byte()` |
| `themes.lua` | Theme definitions - highlight groups for cursor/extend/insert modes, multiple color schemes |
| `comp.lua` | Plugin compatibility - handles AutoPairs, deoplete, ncm2, YouCompleteMe, tagalong, etc. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `maps/` | Key-to-plug mapping dictionaries (see `maps/AGENTS.md`) |
| `special/` | Special commands - case conversion, tools menu, filtering (see `special/AGENTS.md`) |
| `test/` | Unit tests with custom test runner (see `test/AGENTS.md`) |

## For AI Agents

### Module Architecture
All modules follow a consistent pattern:
```lua
local M = {}

-- Module references (set by init())
local State, Global, Config, Region, Funcs
local V  -- buffer state
local v  -- V.vars
local v_regions  -- V.regions

function M.init()
  State = require("visual-multi.state")
  Global = require("visual-multi.global")
  -- ... other requires
  V = State.get()
  v = V.vars
  v_regions = V.regions
  return M
end

-- Public functions...

return M
```

### Initialization Order
1. `vm.init_buffer()` creates buffer state via `state.create()`
2. Module references stored in state: `V.Funcs`, `V.Global`, `V.Search`, `V.Edit`, `V.Insert`, `V.Maps`
3. `Region.init()` called after state is available
4. Maps enabled via `V.Maps.enable()`

### State Access Pattern
```lua
local state = require("visual-multi.state")
local s = state.get()  -- current buffer state
local regions = s.regions  -- list of Region tables
local vars = s.vars     -- plugin variables (index, ID, search, etc.)
local bytes = s.bytes   -- byte map for overlap detection
```

### Region Structure
Each region in `s.regions` is a table with:
- **Position**: `l`, `L` (start/end line), `a`, `b` (start/end column)
- **Byte offsets**: `A`, `B` (calculated via `:A_()` and `:B_()`)
- **Metadata**: `id`, `index`, `dir` (direction), `txt` (content), `pat` (pattern)
- **Dimensions**: `w` (width in bytes), `h` (height in lines)
- **Methods**: `:highlight()`, `:remove()`, `:update()`, `:shift()`, `:clear()`

### Extend Mode
The global `vim.g.Vm.extend_mode` determines cursor vs selection mode:
- `0` = cursor mode (zero-width regions)
- `1` = extend mode (selections with width)

### Common Operations

**Create a new cursor:**
```lua
local Global = require("visual-multi.global")
Global.init()
Global.new_cursor(toggle)  -- toggle: if true and region exists, clear it
```

**Create a new region:**
```lua
local Region = require("visual-multi.region")
Region.init()
local R = Region.new(cursor)  -- cursor=true for current position, false for marks ['[, ']
```

**Execute normal command over regions:**
```lua
local Edit = require("visual-multi.edit")
Edit.init()
Edit.run_normal("dw", { count = 1, recursive = true })
```

**Check current mode:**
```lua
local is_extend = vim.g.Vm and vim.g.Vm.extend_mode == 1
```

### Testing Requirements
- Tests located in `test/` directory
- Custom test runner (not busted framework despite task description)
- Run tests: `nvim -l lua/visual-multi/test/run_tests.lua`
- Test modules export `run()` or `run_all()` returning boolean pass/fail
- Use `assert()` for test assertions

### Linting and Formatting
- Run `scripts/lint-lua.sh` before committing Lua changes
- Uses StyLua for formatting (config in `stylua.toml`)
- Uses LuaLS for type checking (config in `.luarc.json`)

### API Compatibility
- Maintain compatibility with Vimscript implementation in `autoload/vm/`
- Buffer state synced to `vim.b.VM_Selection` for Vimscript interop
- Global state in `vim.g.Vm` table
- Functions like `vm#init_buffer()` callable from Vimscript

## Dependencies

### Internal
- `autoload/vm/` - Vimscript implementation (reference)
- `plugin/visual-multi.vim` - Plugin loader for Vim8

### External
- Neovim 0.5+ with Lua support
- `vim.api`, `vim.fn`, `vim.b`, `vim.g` for Neovim interaction

## Common Gotchas

1. **Index Base**: Region indices are 0-based (matching VimScript), but Lua arrays are 1-based
2. **Byte vs Character**: Use byte offsets (`A`, `B`) for position calculations, not character positions
3. **Module Init**: Always call `.init()` on modules before using them - they set up internal references
4. **Buffer State**: Check `vim.b.visual_multi_active` before accessing `V` or `v`
5. **Lambda Caching**: Modules cache frequently-used functions like `R_fn` (returns regions) and `X_fn` (returns extend_mode)

<!-- MANUAL: -->
