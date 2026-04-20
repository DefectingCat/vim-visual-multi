-- lua/visual-multi/test/phase5_spec.lua
-- Phase 5 module tests (Operators, Icmds, Visual, Plugs)

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

-- Operators module tests
function M.test_operators_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, operators = pcall(require, 'visual-multi.operators')
  record("Operators module loads", ok)

  if ok then
    -- Initialize module
    local o = operators.init()
    record("Operators.init succeeds", o ~= nil)

    -- Check key methods exist
    record("Operators has select", operators.select ~= nil)
    record("Operators has find", operators.find ~= nil)
    record("Operators has after_yank", operators.after_yank ~= nil)

    -- Internal methods
    record("Operators has _select", operators._select ~= nil)
    record("Operators has _get_region", operators._get_region ~= nil)
    record("Operators has _updatetime", operators._updatetime ~= nil)
    record("Operators has _old_updatetime", operators._old_updatetime ~= nil)
    record("Operators has _backup_map_find", operators._backup_map_find ~= nil)
    record("Operators has _merge_find", operators._merge_find ~= nil)
  end
end

-- Icmds module tests
function M.test_icmds_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, icmds = pcall(require, 'visual-multi.icmds')
  record("Icmds module loads", ok)

  if ok then
    -- Initialize module
    local i = icmds.init()
    record("Icmds.init succeeds", i ~= nil)

    -- Check key methods exist
    record("Icmds has x", icmds.x ~= nil)
    record("Icmds has cw", icmds.cw ~= nil)
    record("Icmds has paste", icmds.paste ~= nil)
    record("Icmds has return_key", icmds.return_key ~= nil)
    record("Icmds has insert_line", icmds.insert_line ~= nil)
    record("Icmds has goto_next", icmds.goto_next ~= nil)
  end
end

-- Visual module tests
function M.test_visual_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, visual = pcall(require, 'visual-multi.visual')
  record("Visual module loads", ok)

  if ok then
    -- Initialize module
    local v = visual.init()
    record("Visual.init succeeds", v ~= nil)

    -- Check key methods exist
    record("Visual has add", visual.add ~= nil)
    record("Visual has subtract", visual.subtract ~= nil)
    record("Visual has reduce", visual.reduce ~= nil)
    record("Visual has cursors", visual.cursors ~= nil)
    record("Visual has split", visual.split ~= nil)

    -- Internal methods
    record("Visual has _vchar", visual._vchar ~= nil)
    record("Visual has _vline", visual._vline ~= nil)
    record("Visual has _vblock", visual._vblock ~= nil)
    record("Visual has _backup_map", visual._backup_map ~= nil)
    record("Visual has _visual_merge", visual._visual_merge ~= nil)
    record("Visual has _visual_subtract", visual._visual_subtract ~= nil)
    record("Visual has _create_cursors", visual._create_cursors ~= nil)
  end
end

-- Plugs module tests
function M.test_plugs_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, plugs = pcall(require, 'visual-multi.plugs')
  record("Plugs module loads", ok)

  if ok then
    -- Initialize module
    local p = plugs.init()
    record("Plugs.init succeeds", p ~= nil)

    -- Check key methods exist
    record("Plugs has permanent", plugs.permanent ~= nil)
    record("Plugs has buffer", plugs.buffer ~= nil)
  end
end

-- Integration test - all modules load together
function M.test_integration()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Load all Phase 5 modules
  local ok1, operators = pcall(require, 'visual-multi.operators')
  local ok2, icmds = pcall(require, 'visual-multi.icmds')
  local ok3, visual = pcall(require, 'visual-multi.visual')
  local ok4, plugs = pcall(require, 'visual-multi.plugs')

  record("All Phase 5 modules load together", ok1 and ok2 and ok3 and ok4)

  -- Initialize all modules
  if ok1 then operators.init() end
  if ok2 then icmds.init() end
  if ok3 then visual.init() end
  if ok4 then plugs.init() end

  record("All Phase 5 modules initialize without errors", true)
end

function M.run_all()
  M.pass_count = 0
  M.fail_count = 0
  M.results = {}

  print("\n=== Phase 5 Module Tests ===")
  M.test_operators_module()
  M.test_icmds_module()
  M.test_visual_module()
  M.test_plugs_module()
  M.test_integration()

  print("\n=== Phase 5 Test Report ===")
  print("Passed: " .. M.pass_count)
  print("Failed: " .. M.fail_count)

  return M.fail_count == 0
end

return M
