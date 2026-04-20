<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# python/

## Purpose
Python helper module for enhanced performance in Vim. Provides optimized operations for region management that are called from the Vimscript implementation. Optional dependency - the plugin functions without Python support.

## Key Files

| File | Description |
|------|-------------|
| `vm.py` | Python module with optimized region operations |

## For AI Agents

### Working In This Directory
- This module interfaces with Vim via the `vim` Python module
- Functions are called from Vimscript via `pyeval()` or `:python` commands
- Maintain backward compatibility with Python 3.6+
- The plugin works without Python; this module provides performance optimization only

### Function Reference

| Function | Purpose |
|----------|---------|
| `py_rebuild_from_map()` | Rebuild regions from a bytes map, optionally within a range |
| `py_lines_with_regions()` | Find lines containing regions, sorted by index |
| `evint(exp)` | Evaluate Vim expression as integer |
| `ev(exp)` | Evaluate Vim expression |
| `let(name, value)` | Set Vim variable from Python |

### Calling Convention
- Vimscript sets `l:dict` and `l:range` before calling `py_rebuild_from_map()`
- Regions are accessed via `s:R()` which returns the region list
- Results are passed back via `let()` to set Vim variables

### Dependencies

#### Internal
- Called from `autoload/vm/` Vimscript modules
- Uses `vim` module (provided by Vim/Neovim with Python support)

#### External
- Python 3.6+ (optional)

<!-- MANUAL: -->
