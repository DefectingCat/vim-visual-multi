-- lua/visual-multi/test/phase6_spec.lua
-- Phase 6 module tests (Comp, Ecmds1, Ecmds2, Themes, Variables)

local M = {}

M.results = {}
M.pass_count = 0
M.fail_count = 0

local function record (name, passed, detail)
  M.results[name] = { passed = passed, detail = detail or "" }
  if passed then
    M.pass_count = M.pass_count + 1
    print ("[PASS] " .. name)
  else
    M.fail_count = M.fail_count + 1
    print ("[FAIL] " .. name .. ": " .. (detail or ""))
  end
end

local function setup_test_buffer ()
  local lines = {
    "abc def ghi", -- line 1
    "你好世界测试", -- line 2 (Chinese)
    "test test test", -- line 3
    "", -- line 4 (empty)
    "abc中文def", -- line 5 (mixed)
  }
  vim.api.nvim_buf_set_lines (0, 0, -1, false, lines)
  vim.fn.cursor (1, 1)
end

-- Comp module tests
function M.test_comp_module ()
  setup_test_buffer ()
  local config = require ("visual-multi.config")
  local state = require ("visual-multi.state")

  config.setup ({})
  state.create (vim.api.nvim_get_current_buf ())

  -- Module loading test
  local ok, comp = pcall (require, "visual-multi.comp")
  record ("Comp module loads", ok)

  if ok then
    -- Check key methods exist
    record ("Comp has init", comp.init ~= nil)
    record ("Comp has icmds", comp.icmds ~= nil)
    record ("Comp has TextChangedI", comp.TextChangedI ~= nil)
    record ("Comp has conceallevel", comp.conceallevel ~= nil)
    record ("Comp has iobj", comp.iobj ~= nil)
    record ("Comp has reset", comp.reset ~= nil)
    record ("Comp has exit", comp.exit ~= nil)
    record ("Comp has add_line", comp.add_line ~= nil)
    record ("Comp has no_reindents", comp.no_reindents ~= nil)
  end
end

-- Ecmds1 module tests
function M.test_ecmds1_module ()
  setup_test_buffer ()
  local config = require ("visual-multi.config")
  local state = require ("visual-multi.state")

  config.setup ({})
  state.create (vim.api.nvim_get_current_buf ())

  -- Module loading test
  local ok, ecmds1 = pcall (require, "visual-multi.ecmds1")
  record ("Ecmds1 module loads", ok)

  if ok then
    -- Check key methods exist
    record ("Ecmds1 has init", ecmds1.init ~= nil)
    record ("Ecmds1 has get_edit", ecmds1.get_edit ~= nil)

    -- Edit methods
    local edit = ecmds1.get_edit and ecmds1.get_edit () or {}
    record ("Ecmds1 has Edit.yank", edit.yank ~= nil)
    record ("Ecmds1 has Edit.delete", edit.delete ~= nil)
    record ("Ecmds1 has Edit.xdelete", edit.xdelete ~= nil)
    record ("Ecmds1 has Edit.paste", edit.paste ~= nil)
    record ("Ecmds1 has Edit.block_paste", edit.block_paste ~= nil)
    record ("Ecmds1 has Edit.replace_chars", edit.replace_chars ~= nil)
    record ("Ecmds1 has Edit.replace", edit.replace ~= nil)
    record ("Ecmds1 has Edit.replace_expression", edit.replace_expression ~= nil)
  end
end

-- Ecmds2 module tests
function M.test_ecmds2_module ()
  setup_test_buffer ()
  local config = require ("visual-multi.config")
  local state = require ("visual-multi.state")

  config.setup ({})
  state.create (vim.api.nvim_get_current_buf ())

  -- Module loading test
  local ok, ecmds2 = pcall (require, "visual-multi.ecmds2")
  record ("Ecmds2 module loads", ok)

  if ok then
    -- Check key methods exist
    record ("Ecmds2 has init", ecmds2.init ~= nil)
    record ("Ecmds2 has get_edit", ecmds2.get_edit ~= nil)

    -- Edit methods
    local edit = ecmds2.get_edit and ecmds2.get_edit () or {}
    record ("Ecmds2 has Edit.duplicate", edit.duplicate ~= nil)
    record ("Ecmds2 has Edit.change", edit.change ~= nil)
    record ("Ecmds2 has Edit.surround", edit.surround ~= nil)
    record ("Ecmds2 has Edit.rotate", edit.rotate ~= nil)
    record ("Ecmds2 has Edit.transpose", edit.transpose ~= nil)
    record ("Ecmds2 has Edit.align", edit.align ~= nil)
    record ("Ecmds2 has Edit.shift", edit.shift ~= nil)
    record ("Ecmds2 has Edit.numbers", edit.numbers ~= nil)
  end
end

-- Themes module tests
function M.test_themes_module ()
  setup_test_buffer ()
  local config = require ("visual-multi.config")
  local state = require ("visual-multi.state")

  config.setup ({})
  state.create (vim.api.nvim_get_current_buf ())

  -- Module loading test
  local ok, themes = pcall (require, "visual-multi.themes")
  record ("Themes module loads", ok)

  if ok then
    -- Check key methods exist
    record ("Themes has init", themes.init ~= nil)
    record ("Themes has search_highlight", themes.search_highlight ~= nil)
    record ("Themes has load", themes.load ~= nil)
    record ("Themes has complete", themes.complete ~= nil)
    record ("Themes has statusline", themes.statusline ~= nil)
  end
end

-- Variables module tests
function M.test_variables_module ()
  setup_test_buffer ()
  local config = require ("visual-multi.config")
  local state = require ("visual-multi.state")

  config.setup ({})
  state.create (vim.api.nvim_get_current_buf ())

  -- Module loading test
  local ok, variables = pcall (require, "visual-multi.variables")
  record ("Variables module loads", ok)

  if ok then
    -- Check key methods exist
    record ("Variables has set", variables.set ~= nil)
    record ("Variables has init", variables.init ~= nil)
    record ("Variables has reset", variables.reset ~= nil)
    record ("Variables has reset_globals", variables.reset_globals ~= nil)
  end
end

-- Integration test
function M.test_integration ()
  setup_test_buffer ()
  local config = require ("visual-multi.config")
  local state = require ("visual-multi.state")

  config.setup ({})
  state.create (vim.api.nvim_get_current_buf ())

  -- Load all Phase 6 modules
  local ok1, comp = pcall (require, "visual-multi.comp")
  local ok2, ecmds1 = pcall (require, "visual-multi.ecmds1")
  local ok3, ecmds2 = pcall (require, "visual-multi.ecmds2")
  local ok4, themes = pcall (require, "visual-multi.themes")
  local ok5, variables = pcall (require, "visual-multi.variables")

  record ("All Phase 6 modules load together", ok1 and ok2 and ok3 and ok4 and ok5)
end

function M.run_all ()
  M.pass_count = 0
  M.fail_count = 0
  M.results = {}

  print ("\n=== Phase 6 Module Tests ===")
  M.test_comp_module ()
  M.test_ecmds1_module ()
  M.test_ecmds2_module ()
  M.test_themes_module ()
  M.test_variables_module ()
  M.test_integration ()

  print ("\n=== Phase 6 Test Report ===")
  print ("Passed: " .. M.pass_count)
  print ("Failed: " .. M.fail_count)

  return M.fail_count == 0
end

return M
