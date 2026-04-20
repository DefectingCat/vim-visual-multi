<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->
<!-- Parent: ../AGENTS.md -->

# lua/visual-multi/maps/

## Purpose
Lua mapping definitions for vim-visual-multi Neovim. This directory contains key-to-plug mapping dictionaries that translate user-facing key bindings to internal `<Plug>` commands.

## Key Files

| File | Description |
|------|-------------|
| `all.lua` | Key-to-plug mapping dictionaries - defines `permanent()` and `buffer()` functions returning mapping tables |

## Mapping Structure

Each mapping entry is a table with two elements:
- `[1]`: The key sequence (e.g., `"<C-n>"`, `"\\A"`)
- `[2]`: The mode (e.g., `"n"` for normal, `"x"` for visual, `"i"` for insert)

Example:
```lua
maps["Find Under"] = { "<C-n>", "n" }
maps["Visual Regex"] = { "\\/", "x" }
```

## Functions

### `M.permanent()`
Returns mappings that are always available (even when VM is not active in a buffer). Includes:
- Cursor creation: `Find Under` (`<C-n>`), `Add Cursor Down/Up`
- Selection: `Select All`, `Select h/l` (arrow keys)
- Visual mode: `Visual Regex`, `Visual All`, `Visual Add`, `Visual Find`, `Visual Cursors`
- Mouse mappings (when `vim.g.VM_mouse_mappings == 1`)

### `M.buffer()`
Returns mappings active only within a VM buffer. Categories include:
- **Basic**: `Switch Mode`, `Toggle Single Region`
- **Select**: `Find Next/Prev`, `Goto Next/Prev`, `Skip/Remove Region`
- **Utility**: `Tools Menu`, `Show Registers`, `Case Setting`, `Toggle Whole Word`
- **Commands**: `Undo`, `Redo`, `Surround`, `Merge Regions`, `Transpose`, `Align`
- **Arrows**: `Select Cursor Down/Up`, `Move Right/Left`
- **Insert**: `I Arrow w/b/W/B`, `I BS`, `I CtrlW/U`, `I Paste`
- **Edit**: `D`, `Y`, `x`, `J`, `~`, `Dot`, `Increase/Decrease`

## For AI Agents

### Adding a New Mapping

When adding a new mapping, the following is required:
1. Add a `<Plug>` definition in `plugs.lua`
2. Add the mapping key name to the `base` table (for permanent) or `buffer()` function
3. Format: `maps["Mapping Name"] = { "key", "mode" }`

### Mapping Name Convention
- Names match `<Plug>` definitions: `"Select Operator"` maps to `<Plug>(VM-Select-Operator)`
- Spaces in names correspond to hyphens in plug names

### Leader Configuration
```lua
local Vm = vim.g.Vm or {}
local leader_tbl = Vm.leader or {}
local leader = leader_tbl.default or "\\"  -- or leader_tbl.buffer
local visual = leader_tbl.visual or "\\"
```

### Default Mappings Control
- `vim.g.VM_default_mappings == 1`: Apply default key bindings
- `vim.g.VM_default_mappings == 0`: Only base mappings (empty strings)
- `vim.g.VM_mouse_mappings == 1`: Enable mouse mappings

### Insert Special Keys
Controlled by `vim.g.VM_insert_special_keys` table:
- `"c-a"`: Enable `<C-a>` in insert mode
- `"c-e"`: Enable `<C-e>` in insert mode
- `"c-v"`: Enable `<C-v>` paste in insert mode (default)

### Important Notes
- The `base` table defines all valid mapping names with empty mappings
- `permanent()` copies `base` then populates based on settings
- `buffer()` creates a fresh table each call
- Both functions return new tables (not references)

## Dependencies

### Used By
- `maps.lua` - Consumes these dictionaries to create buffer-local mappings
- `plugs.lua` - Defines the `<Plug>` commands these mappings reference

### Related Files
- `../maps.lua` - Mapping management (enable/disable, custom mappings)
- `../plugs.lua` - `<Plug>` command definitions
