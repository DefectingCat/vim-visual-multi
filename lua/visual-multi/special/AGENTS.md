<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->
<!-- Parent: ../AGENTS.md -->

# lua/visual-multi/special/

## Purpose
Special Lua commands for Neovim - case conversion utilities (based on vim-abolish) and tools menu commands (filtering, sorting, quickfix integration). These commands are accessible through the Tools Menu (`<leader>x`) and case conversion menu.

## Key Files

| File | Description |
|------|-------------|
| `case.lua` | Case conversion module - converts region text between camelCase, PascalCase, snake_case, SNAKE_UPPERCASE, dash-case, dot.case, space case, Title Case, lowercase, UPPERCASE |
| `commands.lua` | Special commands module - tools menu, filter regions/lines, regions to buffer, mass transpose, quickfix, sort, search, registers display |

## For AI Agents

### Case Conversion (case.lua)

**Available case types:**
- `lower` / `upper` - lowercase / UPPERCASE
- `capitalize` - Capitalize first letter
- `title` - Title Case
- `camel` - camelCase
- `pascal` - PascalCase
- `snake` - snake_case
- `snake_upper` - SNAKE_UPPERCASE
- `dash` - dash-case
- `dot` - dot.case
- `space` - space case

**Usage:**
```lua
local case = require("visual-multi.special.case")
case.init()

-- Convert a single word
local result = case.camel("some_word")  -- "someWord"

-- Convert all regions to a specific case
case.convert("snake")  -- Converts all region contents to snake_case

-- Show interactive menu
case.menu()  -- Prompts user to select case type
```

**Menu key mappings:**
| Key | Case Type |
|-----|-----------|
| `u` | lowercase |
| `U` | UPPERCASE |
| `C` | Capitalize |
| `t` | Title Case |
| `c` | camelCase |
| `P` | PascalCase |
| `s` | snake_case |
| `S` | SNAKE_UPPERCASE |
| `-` | dash-case |
| `.` | dot.case |
| `Space` | space case |

### Special Commands (commands.lua)

**Tools Menu options (`M.menu()`):**
| Key | Command | Description |
|-----|---------|-------------|
| `"` | Show registers | Display VM register contents |
| `i` | Regions info | Show detailed info for each region |
| `f` | Filter regions | Filter regions by pattern or Lua expression |
| `l` | Filter lines | Extract lines with regions to new buffer |
| `r` | Regions to buffer | Copy region contents to new buffer |
| `q` | Quickfix (lines) | Fill quickfix with lines containing regions |
| `Q` | Quickfix (positions) | Fill quickfix with region positions and contents |

**User Commands (buffer-local):**
- `:VMFilterRegions [pattern]` - Filter regions by pattern/expression
- `:VMFilterLines` - Filter lines containing regions
- `:VMRegionsToBuffer` - Copy regions to new buffer
- `:VMMassTranspose` - Transpose region contents
- `:VMQfix[!]` - Fill quickfix (with `!` for positions)
- `:VMSort [flags]` - Sort regions alphabetically

**Usage:**
```lua
local commands = require("visual-multi.special.commands")
commands.init()

-- Show tools menu
commands.menu()

-- Filter regions by pattern
commands.filter_regions(0, "error", false)  -- Keep regions matching "error"

-- Sort regions
commands.sort()  -- Alphabetical sort
commands.sort("r")  -- Reverse sort

-- Mass transpose (cycle region contents)
commands.mass_transpose()

-- Fill quickfix with region positions
commands.qfix(false)  -- Position-based
commands.qfix(true)   -- Line-based
```

### Module Initialization

Both modules require `init()` to set up internal references:
```lua
local case = require("visual-multi.special.case").init()
local commands = require("visual-multi.special.commands").init()
```

The `init()` function populates module references to `State`, `Global`, `Funcs`, and other core modules, plus cached lambdas for accessing `V.regions` and `g:Vm.extend_mode`.

### Filter Types

The filter_regions function supports three filter types (cycled with Ctrl-X):
1. `pattern` - Keep regions matching pattern
2. `!pattern` - Keep regions NOT matching pattern
3. `expression` - Lua expression evaluation (region available as `r`)

### Temporary Buffers

`filter_lines()` and `regions_to_buffer()` create temporary buffers with:
- `buftype = "acwrite"` - Write triggers BufWriteCmd
- `bufhidden = "wipe"` - Delete on hide
- `:w` writes changes back to source buffer

## Dependencies

### Internal
- `visual-multi.state` - Buffer state access
- `visual-multi.global` - Region operations, filtering
- `visual-multi.funcs` - Utility functions, messaging
- `visual-multi.search` - Pattern search
- `visual-multi.edit` - Text replacement operations

### External
- Neovim's `vim.fn.substitute()` for case conversion regex
- `vim.api.nvim_create_user_command()` for command registration

## Notes

- Case conversion based on vim-abolish by Tim Pope
- Both modules follow the standard module pattern with `init()` returning the module
- Commands are buffer-local and cleaned up by `M.unset()` when VM exits
- The `§` register is reserved/skipped in register display
