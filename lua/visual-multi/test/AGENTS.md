<!-- Generated: 2026-04-20 | Updated: 2026-04-20 -->
<!-- Parent: ../AGENTS.md -->

# lua/visual-multi/test/

## Purpose
Lua unit tests using a custom test runner (not busted framework despite naming convention). Each test module exports `run_all()` returning boolean pass/fail status. Tests cover core module functionality including region management, cursor operations, edit commands, and plugin integration.

## Key Files

| File | Description |
|------|-------------|
| `run_tests.lua` | Main test runner - loads and executes all test modules, reports aggregate results |
| `init_spec.lua` | Module loading tests for visual-multi, config, state, offset, bytes modules |
| `region_spec.lua` | Region class tests - cursor creation, positions, byte offsets, empty check, multibyte handling |
| `global_spec.lua` | Global class tests - initialization, region/cursor creation, active regions, selection, line operations |
| `phase3_spec.lua` | Phase 3 module tests - Search, Edit, Insert |
| `phase4_spec.lua` | Phase 4 module tests - Commands, Maps, Cursors |
| `phase5_spec.lua` | Phase 5 module tests - Operators, Icmds, Visual, Plugs |
| `phase6_spec.lua` | Phase 6 module tests - Comp, Ecmds1, Ecmds2, Themes, Variables |
| `phase7_spec.lua` | Phase 7 module tests - vm, maps/all, special/case, special/commands |

## Test Framework

This is a custom test framework, not busted. Key patterns:

```lua
local M = {}
M.results = {}
M.pass_count = 0
M.fail_count = 0

local function record(name, passed, detail)
  M.results[name] = { passed = passed, detail = detail or "" }
  if passed then
    M.pass_count = M.pass_count + 1
    print("[PASS] " .. name)
  else
    M.fail_count = M.fail_count + 1
    print("[FAIL] " .. name .. ": " .. (detail or ""))
  end
end

function M.run_all()
  -- Run tests, return true if all passed
  return M.fail_count == 0
end

return M
```

## For AI Agents

### Running Tests
```bash
nvim --headless -c "set rtp+=." -c "lua require('visual-multi.test.run_tests').run_all()" -c "qa!"
```

### Running Individual Test Modules
```bash
nvim --headless -c "set rtp+=." -c "lua require('visual-multi.test.region_spec').run_all()" -c "qa!"
```

### Test Buffer Setup
Most tests use a standard buffer with multibyte content:
```lua
local function setup_test_buffer()
  local lines = {
    "abc def ghi",     -- line 1 (ASCII)
    "你好世界测试",     -- line 2 (Chinese)
    "test test test",  -- line 3
    "",                -- line 4 (empty)
    "abc中文def",      -- line 5 (mixed)
  }
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.fn.cursor(1, 1)
end
```

### Test Module Requirements
1. Export `run_all()` function returning boolean
2. Track `pass_count` and `fail_count` in module table
3. Call `config.setup({})` and `state.create(buf)` before testing
4. Initialize modules under test with `.init()` before calling methods

### Adding New Tests
1. Create `*_spec.lua` file following existing patterns
2. Add entry to `test_modules` table in `run_tests.lua`
3. Ensure proper setup/teardown of buffer state

### Common Test Patterns
- Use `pcall(require, "module")` for safe module loading
- Check method existence: `record("has method", module.method ~= nil)`
- Verify return values with assertions in test functions

## Dependencies

### Internal
- `visual-multi.config` - Configuration setup
- `visual-multi.state` - Buffer state creation
- All modules being tested (region, global, commands, etc.)

### External
- Neovim 0.5+ with Lua support
- `vim.api`, `vim.fn` for buffer and cursor operations
