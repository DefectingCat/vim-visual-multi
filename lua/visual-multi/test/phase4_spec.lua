-- lua/visual-multi/test/phase4_spec.lua
-- Phase 4 module tests (Commands, Maps, Cursors)

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

-- Commands module tests
function M.test_commands_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, commands = pcall(require, 'visual-multi.commands')
  record("Commands module loads", ok)

  if ok then
    -- Initialize module
    local c = commands.init()
    record("Commands.init succeeds", c ~= nil)

    -- Check key methods exist
    record("Commands has add_cursor_at_pos", commands.add_cursor_at_pos ~= nil)
    record("Commands has add_cursor_down", commands.add_cursor_down ~= nil)
    record("Commands has add_cursor_up", commands.add_cursor_up ~= nil)
    record("Commands has add_cursor_at_word", commands.add_cursor_at_word ~= nil)

    -- Find methods
    record("Commands has ctrln", commands.ctrln ~= nil)
    record("Commands has find_under", commands.find_under ~= nil)
    record("Commands has find_all", commands.find_all ~= nil)
    record("Commands has find_next", commands.find_next ~= nil)
    record("Commands has find_prev", commands.find_prev ~= nil)

    -- Motion methods
    record("Commands has motion", commands.motion ~= nil)
    record("Commands has merge_to_beol", commands.merge_to_beol ~= nil)
    record("Commands has find_motion", commands.find_motion ~= nil)
    record("Commands has regex_motion", commands.regex_motion ~= nil)
    record("Commands has align", commands.align ~= nil)

    -- Regex methods
    record("Commands has find_by_regex", commands.find_by_regex ~= nil)
    record("Commands has regex_done", commands.regex_done ~= nil)
    record("Commands has regex_abort", commands.regex_abort ~= nil)
    record("Commands has regex_reset", commands.regex_reset ~= nil)

    -- Miscellaneous methods
    record("Commands has invert_direction", commands.invert_direction ~= nil)
    record("Commands has reset_direction", commands.reset_direction ~= nil)
    record("Commands has split_lines", commands.split_lines ~= nil)
    record("Commands has reselect_last", commands.reselect_last ~= nil)
    record("Commands has undo", commands.undo ~= nil)
    record("Commands has redo", commands.redo ~= nil)

    -- Seek methods
    record("Commands has seek_down", commands.seek_down ~= nil)
    record("Commands has seek_up", commands.seek_up ~= nil)

    -- Skip methods
    record("Commands has skip", commands.skip ~= nil)
  end
end

-- Maps module tests
function M.test_maps_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, maps = pcall(require, 'visual-multi.maps')
  record("Maps module loads", ok)

  if ok then
    -- Check key methods exist
    record("Maps has init", maps.init ~= nil)
    record("Maps has default", maps.default ~= nil)
    record("Maps has reset", maps.reset ~= nil)

    -- Maps.Maps sub-object methods
    record("Maps.Maps exists", maps.Maps ~= nil)
    if maps.Maps then
      record("Maps.Maps has enable", maps.Maps.enable ~= nil)
      record("Maps.Maps has disable", maps.Maps.disable ~= nil)
      record("Maps.Maps has mappings_toggle", maps.Maps.mappings_toggle ~= nil)
      record("Maps.Maps has start", maps.Maps.start ~= nil)
      record("Maps.Maps has stop", maps.Maps.stop ~= nil)
      record("Maps.Maps has map_esc_and_toggle", maps.Maps.map_esc_and_toggle ~= nil)
      record("Maps.Maps has unmap_esc_and_toggle", maps.Maps.unmap_esc_and_toggle ~= nil)
    end

    -- Helper functions
    record("Maps has _build_permanent_maps", maps._build_permanent_maps ~= nil)
    record("Maps has _build_buffer_maps", maps._build_buffer_maps ~= nil)
    record("Maps has _assign", maps._assign ~= nil)
    record("Maps has _unmap", maps._unmap ~= nil)
    record("Maps has _check_warnings", maps._check_warnings ~= nil)
  end
end

-- Cursors module tests
function M.test_cursors_module()
  setup_test_buffer()
  local config = require('visual-multi.config')
  local state = require('visual-multi.state')

  config.setup({})
  state.create(vim.api.nvim_get_current_buf())

  -- Module loading test
  local ok, cursors = pcall(require, 'visual-multi.cursors')
  record("Cursors module loads", ok)

  if ok then
    -- Initialize module
    local c = cursors.init()
    record("Cursors.init succeeds", c ~= nil)

    -- Check key methods exist
    record("Cursors has operation", cursors.operation ~= nil)

    -- Internal methods
    record("Cursors has _process", cursors._process ~= nil)
    record("Cursors has _parse_cmd", cursors._parse_cmd ~= nil)
    record("Cursors has _delete_at_cursors", cursors._delete_at_cursors ~= nil)
    record("Cursors has _yank_at_cursors", cursors._yank_at_cursors ~= nil)
    record("Cursors has _change_at_cursors", cursors._change_at_cursors ~= nil)

    -- Lambda helpers
    record("Cursors has _forward", cursors._forward ~= nil)
    record("Cursors has _ia", cursors._ia ~= nil)
    record("Cursors has _inside", cursors._inside ~= nil)
    record("Cursors has _single", cursors._single ~= nil)
    record("Cursors has _double", cursors._double ~= nil)
  end
end

-- Helper function tests
function M.test_helper_functions()
  setup_test_buffer()
  local ok, cursors = pcall(require, 'visual-multi.cursors')
  if not ok then
    record("Cursors helper tests skipped", false, "module not loaded")
    return
  end

  cursors.init()

  -- Test _forward
  record("_forward('w') returns true", cursors._forward('w') == true)
  record("_forward('h') returns false", cursors._forward('h') == false)

  -- Test _ia
  record("_ia('iw') returns true", cursors._ia('iw') == true)
  record("_ia('w') returns false", cursors._ia('w') == false)

  -- Test _single
  record("_single('h') returns true", cursors._single('h') == true)
  record("_single('f') returns false", cursors._single('f') == false)

  -- Test _double
  record("_double('f') returns true", cursors._double('f') == true)
  record("_double('h') returns false", cursors._double('h') == false)
end

function M.run_all()
  M.pass_count = 0
  M.fail_count = 0
  M.results = {}

  print("\n=== Phase 4 Module Tests ===")
  M.test_commands_module()
  M.test_maps_module()
  M.test_cursors_module()
  M.test_helper_functions()

  print("\n=== Phase 4 Test Report ===")
  print("Passed: " .. M.pass_count)
  print("Failed: " .. M.fail_count)

  return M.fail_count == 0
end

return M