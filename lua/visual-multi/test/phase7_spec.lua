-- lua/visual-multi/test/phase7_spec.lua
-- Phase 7 module tests (vm, maps/all, special/case, special/commands)

local M = {}

M.results = {}
M.pass_count = 0
M.fail_count = 0

local function record(name, passed, detail)
  M.results[name] = { passed = passed, detail = detail or '' }
  if passed then
    M.pass_count = M.pass_count + 1
    print("[PASS] " .. name)
  else
    M.fail_count = M.fail_count + 1
    print("[FAIL] " .. name .. ": " .. (detail or ''))
  end
end

local function setup_test_buffer()
  local lines = {
    "abc def ghi",      -- line 1
    "你好世界测试",       -- line 2 (Chinese)
    "test test test",   -- line 3
    "",                  -- line 4 (empty)
    "abc中文def",        -- line 5 (mixed)
  }
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.fn.cursor(1, 1)
end

-- vm.lua module tests
function M.test_vm_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, vm = pcall(require, 'visual-multi.vm')
  record("VM module loads", ok)

  if ok then
    -- Check key methods exist
    record("VM has init_buffer", vm.init_buffer ~= nil)
    record("VM has reset", vm.reset ~= nil)
    record("VM has hard_reset", vm.hard_reset ~= nil)
    record("VM has clearmatches", vm.clearmatches ~= nil)
    record("VM has augroup", vm.augroup ~= nil)
    record("VM has au_cursor", vm.au_cursor ~= nil)

    -- Check global variables are initialized
    record("VM_live_editing exists", vim.g.VM_live_editing ~= nil)
    record("VM_debug exists", vim.g.VM_debug ~= nil)
  end
end

-- maps/all.lua module tests
function M.test_maps_all_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, maps_all = pcall(require, 'visual-multi.maps.all')
  record("Maps/All module loads", ok)

  if ok then
    -- Check key methods exist
    record("Maps/All has permanent", maps_all.permanent ~= nil)
    record("Maps/All has buffer", maps_all.buffer ~= nil)

    -- Test that permanent() returns a table
    local perm = maps_all.permanent()
    record("Permanent returns table", type(perm) == 'table')

    -- Test that buffer() returns a table
    local buf = maps_all.buffer()
    record("Buffer returns table", type(buf) == 'table')

    -- Check specific mappings exist
    record("Find Under mapping exists", perm["Find Under"] ~= nil)
    record("Switch Mode mapping exists", buf["Switch Mode"] ~= nil)
  end
end

-- special/case.lua module tests
function M.test_special_case_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, case = pcall(require, 'visual-multi.special.case')
  record("Special/Case module loads", ok)

  if ok then
    -- Check key methods exist
    record("Case has init", case.init ~= nil)
    record("Case has pascal", case.pascal ~= nil)
    record("Case has camel", case.camel ~= nil)
    record("Case has snake", case.snake ~= nil)
    record("Case has snake_upper", case.snake_upper ~= nil)
    record("Case has dash", case.dash ~= nil)
    record("Case has space", case.space ~= nil)
    record("Case has dot", case.dot ~= nil)
    record("Case has title", case.title ~= nil)
    record("Case has lower", case.lower ~= nil)
    record("Case has upper", case.upper ~= nil)
    record("Case has capitalize", case.capitalize ~= nil)
    record("Case has menu", case.menu ~= nil)
    record("Case has convert", case.convert ~= nil)

    -- Test case conversion functions
    record("Case.lower works", case.lower("HELLO") == "hello")
    record("Case.upper works", case.upper("hello") == "HELLO")
    record("Case.capitalize works", case.capitalize("hello") == "Hello")
  end
end

-- special/commands.lua module tests
function M.test_special_commands_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, commands = pcall(require, 'visual-multi.special.commands')
  record("Special/Commands module loads", ok)

  if ok then
    -- Check key methods exist
    record("Commands has init", commands.init ~= nil)
    record("Commands has menu", commands.menu ~= nil)
    record("Commands has filter_lines", commands.filter_lines ~= nil)
    record("Commands has regions_to_buffer", commands.regions_to_buffer ~= nil)
    record("Commands has filter_regions", commands.filter_regions ~= nil)
    record("Commands has mass_transpose", commands.mass_transpose ~= nil)
    record("Commands has debug", commands.debug ~= nil)
    record("Commands has qfix", commands.qfix ~= nil)
    record("Commands has show_registers", commands.show_registers ~= nil)
    record("Commands has search", commands.search ~= nil)
    record("Commands has sort", commands.sort ~= nil)
    record("Commands has live", commands.live ~= nil)
    record("Commands has unset", commands.unset ~= nil)
  end
end

-- Integration test
function M.test_integration()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Load all Phase 7 modules
  local ok1, vm = pcall(require, 'visual-multi.vm')
  local ok2, maps_all = pcall(require, 'visual-multi.maps.all')
  local ok3, case = pcall(require, 'visual-multi.special.case')
  local ok4, commands = pcall(require, 'visual-multi.special.commands')

  record("All Phase 7 modules load together", ok1 and ok2 and ok3 and ok4)
end

function M.run_all()
  M.pass_count = 0
  M.fail_count = 0
  M.results = {}

  print("\n=== Phase 7 Module Tests ===")
  M.test_vm_module()
  M.test_maps_all_module()
  M.test_special_case_module()
  M.test_special_commands_module()
  M.test_integration()

  print("\n=== Phase 7 Test Report ===")
  print("Passed: " .. M.pass_count)
  print("Failed: " .. M.fail_count)

  return M.fail_count == 0
end

return M
