<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->

# test/default/

## Key Files

| File | Description |
|------|-------------|
| `vimrc.vim` | Minimal vimrc for test isolation |

## For AI Agents

### Configuration Details
The `vimrc.vim` sets up a clean test environment:

| Setting | Value | Purpose |
|---------|-------|---------|
| `runtimepath` | `$VIMRUNTIME` + parent | Isolate from user config, load plugin from `../` |
| `packpath` | empty | Disable packages |
| `nocompatible` | enabled | Use Vim defaults |
| `ignorecase` + `smartcase` | enabled | Standard search behavior |
| `noswapfile` | enabled | Prevent swap file interference in tests |
| `loaded_remote_plugins` | 1 | Skip remote plugin loading |

### When Modifying
- Keep configuration minimal to avoid test pollution
- Any changes affect all tests that use this default vimrc
- Individual tests can override with their own `vimrc.vim`

### vimrunner Integration
The `VimrunnerPyEvaluateCommandOutput()` function is required by vimrunner to execute Vim commands and capture output during test execution.

<!-- MANUAL: -->
