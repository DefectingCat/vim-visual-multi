<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# doc

## Key Files

| File | Description |
|------|-------------|
| `visual-multi.txt` | Main help file - table of contents, introduction, modes, mappings, commands, registers |
| `vm-mappings.txt` | Complete mappings reference, including default mappings, visual mode, buffer mappings, Colemak support |
| `vm-settings.txt` | Configuration options, highlight groups, theme customization |
| `vm-ex-commands.txt` | Ex commands reference (:VMDebug, :VMClear, :VMSearch, etc.) |
| `vm-faq.txt` | Frequently asked questions about errors, mappings, functions, customization |
| `vm-troubleshooting.txt` | Known issues, plugin compatibility, autocompletion issues |

## Help Tag Format

Vim help files use a specific format:

```
*tag-name*    Description text
```

- Tags are enclosed in asterisks `*tag*`
- Tags must be unique across all help files
- Cross-references use pipes: `|tag-name|`
- Sections are separated by `===...===` lines (78 chars)
- Subsections use `---...---` lines
- Code blocks use `>` to start and `<` to end
- Modeline at end: ` vim: ft=help et sw=2 ts=2 sts=2 tw=79`

## For AI Agents

### When Editing Help Files
- Maintain Vim help file format conventions
- Keep line width at 78-79 characters for body text
- Use proper tag naming: `vm-` prefix for plugin-specific tags
- Preserve existing tag names (they are referenced from other files)
- Update "Last change:" dates when modifying files
- Run `:helptags doc/` after adding/modifying tags

### Tag Naming Conventions
- Main concepts: `vm-concept` (e.g., `vm-modes`, `vm-regions`)
- Commands: `:CommandName` (e.g., `:VMDebug`, `:VMSearch`)
- Settings: `g:VM_setting_name` (e.g., `g:VM_leader`, `g:VM_maps`)
- Mappings: `vm-mappings-category` (e.g., `vm-mappings-buffer`)
- FAQ entries: `vm-faq-topic` (e.g., `vm-faq-mappings`)

### Cross-File References
- `visual-multi.txt` is the entry point with table of contents
- Other files are linked via `|tag|` references
- Main file references: `|vm-settings|`, `|vm-mappings-all|`, `|vm-faq|`, etc.

## Dependencies

### Internal
- All files reference tags defined in other help files
- `visual-multi.txt` serves as the index pointing to specialized files

### External
- References Vim built-in help tags (e.g., `|normal-mode|`, `|visual-mode|`)
- Plugin references: `|vim-surround|`, `|vim-abolish|`

<!-- MANUAL: -->
