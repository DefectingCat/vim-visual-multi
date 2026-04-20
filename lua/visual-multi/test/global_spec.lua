-- lua/visual-multi/test/global_spec.lua
-- Global class tests

local M = {}

local global = require('visual-multi.global')
local region = require('visual-multi.region')
local state = require('visual-multi.state')
local config = require('visual-multi.config')

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

function M.test_global_init()
  setup_test_buffer()
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  global.init()
  record("Global.init succeeds", true)
end

function M.test_global_new_region()
  setup_test_buffer()
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())
  region.init()
  global.init()

  vim.fn.cursor(1, 5)
  local R = global.new_region()

  record("Global.new_region returns region", R ~= nil)
  record("Region has valid index", R.index >= 0)
end

function M.test_global_new_cursor()
  setup_test_buffer()
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())
  region.init()
  global.init()

  vim.fn.cursor(1, 1)
  local R1 = global.new_cursor()

  -- Move to different position for second cursor
  vim.fn.cursor(1, 5)
  local R2 = global.new_cursor()

  record("Global.new_cursor creates cursor", R1 ~= nil)
  record("Second cursor has different id", R2.id ~= R1.id)
end

function M.test_global_active_regions()
  setup_test_buffer()
  config.setup({})
  local buf = vim.api.nvim_get_current_buf()
  local s = state.create(buf)
  region.init()
  global.init()

  -- Create some cursors
  vim.fn.cursor(1, 1)
  global.new_cursor()
  vim.fn.cursor(1, 5)
  global.new_cursor()
  vim.fn.cursor(2, 1)
  global.new_cursor()

  local regions = global.active_regions()
  record("active_regions returns list", regions ~= nil)
  record("active_regions has correct count", #regions == 3)
end

function M.test_global_select_region()
  setup_test_buffer()
  config.setup({})
  local buf = vim.api.nvim_get_current_buf()
  state.create(buf)
  region.init()
  global.init()

  -- Create cursors
  vim.fn.cursor(1, 1)
  global.new_cursor()
  vim.fn.cursor(2, 1)
  global.new_cursor()

  -- Select first region
  local R = global.select_region(0)
  record("select_region returns region", R ~= nil)
  record("select_region sets index", state.get().vars.index == 0)
end

function M.test_global_region_at_pos()
  setup_test_buffer()
  config.setup({})
  local buf = vim.api.nvim_get_current_buf()
  state.create(buf)
  region.init()
  global.init()

  -- Create cursor at line 1, col 5
  vim.fn.cursor(1, 5)
  global.new_cursor()

  -- Check if region found at same position
  vim.fn.cursor(1, 5)
  local R = global.region_at_pos()
  record("region_at_pos finds region", R ~= nil)

  -- Check if no region at different position
  vim.fn.cursor(2, 3)
  local R2 = global.region_at_pos()
  record("region_at_pos empty when no region", R2 == nil or next(R2) == nil)
end

function M.test_global_update_indices()
  setup_test_buffer()
  config.setup({})
  local buf = vim.api.nvim_get_current_buf()
  local s = state.create(buf)
  region.init()
  global.init()

  -- Create 3 cursors
  vim.fn.cursor(1, 1)
  global.new_cursor()
  vim.fn.cursor(1, 5)
  global.new_cursor()
  vim.fn.cursor(2, 1)
  global.new_cursor()

  global.update_indices()

  local regions = s.regions
  local indices_correct = true
  for i, r in ipairs(regions) do
    if r.index ~= i - 1 then
      indices_correct = false
      break
    end
  end
  record("update_indices sets correct indices", indices_correct)
end

function M.test_global_lines_with_regions()
  setup_test_buffer()
  config.setup({})
  local buf = vim.api.nvim_get_current_buf()
  local s = state.create(buf)
  region.init()
  global.init()

  -- Create cursors on lines 1 and 2
  vim.fn.cursor(1, 1)
  global.new_cursor()
  vim.fn.cursor(1, 5)
  global.new_cursor()
  vim.fn.cursor(2, 3)
  global.new_cursor()

  local lines = global.lines_with_regions(false)
  record("lines_with_regions returns dict", lines ~= nil)
  record("line 1 has 2 regions", lines[1] ~= nil and #lines[1] == 2)
  record("line 2 has 1 region", lines[2] ~= nil and #lines[2] == 1)
end

function M.run_all()
  M.pass_count = 0
  M.fail_count = 0
  M.results = {}

  print("\n=== Global Class Tests ===")
  M.test_global_init()
  M.test_global_new_region()
  M.test_global_new_cursor()
  M.test_global_active_regions()
  M.test_global_select_region()
  M.test_global_region_at_pos()
  M.test_global_update_indices()
  M.test_global_lines_with_regions()

  print("\n=== Global Test Report ===")
  print("Passed: " .. M.pass_count)
  print("Failed: " .. M.fail_count)

  return M.fail_count == 0
end

return M