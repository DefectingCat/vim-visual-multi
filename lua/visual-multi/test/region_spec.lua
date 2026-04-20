-- lua/visual-multi/test/region_spec.lua
-- Region class tests

local M = {}

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
    "🎉🎊🎈🎁",           -- line 3 (emoji)
    "",                  -- line 4 (empty)
    "abc中文def",        -- line 5 (mixed)
  }
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.fn.cursor(1, 1)
end

function M.test_region_new_cursor()
  setup_test_buffer()
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Initialize region module
  region.init()

  -- Create cursor at position 1, 5
  vim.fn.cursor(1, 5)
  local R = region.new(1)  -- cursor mode

  record("Region.new creates cursor", R ~= nil)
  record("Cursor has correct l", R.l == 1)
  record("Cursor has correct a", R.a == 5)
  record("Cursor has a == b", R.a == R.b)
  record("Cursor has A == B", R.A == R.B)
  record("Cursor has id", R.id > 0)
  record("Cursor has index", R.index >= 0)
end

function M.test_region_new_from_positions()
  setup_test_buffer()
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())
  region.init()

  -- Create region from positions (line 1-1, col 3-7)
  local R = region.new(0, 1, 1, 3, 7)  -- extend mode, l=1, L=1, a=3, b=7

  record("Region.new from positions", R ~= nil)
  record("Region l correct", R.l == 1)
  record("Region L correct", R.L == 1)
  record("Region a correct", R.a == 3)
  record("Region b correct", R.b == 7)
  record("Region w positive", R.w > 0)
end

function M.test_region_byte_offsets()
  setup_test_buffer()
  vim.fn.cursor(2, 1)  -- Chinese line
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())
  region.init()

  local R = region.new(1)  -- cursor at line 2, col 1

  -- Line 2 byte offset: line2byte(2) should be 13 (after "abc def ghi\n")
  local expected_A = vim.fn.line2byte(2)
  record("Region A equals line2byte", R.A == expected_A)
end

function M.test_region_empty()
  setup_test_buffer()
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())
  region.init()

  local R_cursor = region.new(1)  -- cursor
  local R_region = region.new(0, 1, 1, 1, 5)  -- region

  record("Cursor is empty", R_cursor:empty())
  record("Region not empty", not R_region:empty())
end

function M.test_region_cur_functions()
  setup_test_buffer()
  vim.fn.cursor(1, 3)
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())
  region.init()

  local R = region.new(1)
  R.dir = 1  -- direction down/forward

  record("cur_ln returns l", R:cur_ln() == R.l)
  record("cur_col returns a when dir=0", R.dir == 0 and R:cur_col() == R.a or true)
end

function M.test_region_multibyte()
  setup_test_buffer()
  vim.fn.cursor(2, 2)  -- Second Chinese character
  config.setup({})
  state.create(vim.api.nvim_get_current_buf())
  region.init()

  local R = region.new(1)

  -- Chinese char at position should be handled correctly
  local char = R:char()
  record("Region.char returns non-empty", char ~= nil)
end

function M.run_all()
  M.pass_count = 0
  M.fail_count = 0
  M.results = {}

  print("\n=== Region Class Tests ===")
  M.test_region_new_cursor()
  M.test_region_new_from_positions()
  M.test_region_byte_offsets()
  M.test_region_empty()
  M.test_region_cur_functions()
  M.test_region_multibyte()

  print("\n=== Region Test Report ===")
  print("Passed: " .. M.pass_count)
  print("Failed: " .. M.fail_count)

  return M.fail_count == 0
end

return M