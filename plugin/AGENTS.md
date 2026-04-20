<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# plugin/

## Key Files

| File | Description |
|------|-------------|
| `visual-multi.vim` | Plugin loader; version check, initialization, command definitions, highlights, global state |

## Initialization Flow

```
visual-multi.vim loaded
        │
        ├─ Version check (Vim 8+ required)
        │
        ├─ Neovim path:
        │   └─ lua require('visual-multi.plugin').setup()
        │
        └─ Vim8 path:
            ├─ Define commands (VMTheme, VMDebug, VMClear, etc.)
            ├─ Set default highlights
            ├─ Initialize g:Vm global state
            ├─ Load permanent and default mappings
            └─ Setup register persistence autocmds
```

## Commands Defined (Vim8 only)

| Command | Description |
|---------|-------------|
| `VMTheme [name]` | Load color theme |
| `VMDebug` | Toggle debug mode |
| `VMClear` | Hard reset plugin state |
| `VMLive` | Toggle live preview mode |
| `VMRegisters[!] [reg]` | Show registers contents |
| `VMSearch[!] [pattern]` | Search and create cursors |
| `VMFromSearch` | Deprecated: use VMSearch instead |

## For AI Agents

### When Modifying This File
- Maintain dual initialization paths (Neovim Lua vs Vim8 Vimscript)
- Preserve backward compatibility with Vim 8+
- Keep global state structure in sync with `autoload/` expectations

### Dependencies
- Neovim → `lua/visual-multi/plugin.lua` (setup function)
- Vim8 → `autoload/vm/plugs.vim`, `autoload/vm/maps.vim`, `autoload/vm/themes.vim`

### Testing Changes
- Test in both Vim 8+ and Neovim
- Verify commands are defined: `:command VMTheme`
- Check plugin loads without errors: `vim -Nu NONE -c 'so plugin/visual-multi.vim'`

<!-- MANUAL: -->
