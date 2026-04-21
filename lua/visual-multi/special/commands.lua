-- lua/visual-multi/special/commands.lua
-- Special commands that can be selected through the Tools Menu (<leader>x)
-- Equivalent to autoload/vm/special/commands.vim

local M = {}

-- Module references (set during init)
local State
local Global
local Funcs
local Search
local Edit

-- Buffer-local state references
local V -- b:VM_Selection (State buffer state)
local v -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)

-- Cached lambdas
local R_fn -- returns V.regions
local X_fn -- returns g:Vm.extend_mode

-- Script variables
local filter_type = 0
local source_buf = nil

-- Initialize module with V, F, G references
function M.init ()
  State = require ("visual-multi.state")
  Global = require ("visual-multi.global")
  Funcs = require ("visual-multi.funcs")
  Search = require ("visual-multi.search")
  Edit = require ("visual-multi.edit")

  V = State.get ()
  v = V.vars
  v_regions = V.regions

  R_fn = function ()
    return v_regions
  end

  X_fn = function ()
    return vim.g.Vm and vim.g.Vm.extend_mode or 0
  end

  M.set_commands ()
  return M
end

-- Set buffer-local commands
function M.set_commands ()
  vim.api.nvim_create_user_command ("VMFilterRegions", function (opts)
    M.filter_regions (0, opts.args, opts.args == "")
  end, { buffer = true, nargs = "?" })

  vim.api.nvim_create_user_command ("VMFilterLines", function ()
    M.filter_lines ()
  end, { buffer = true })

  vim.api.nvim_create_user_command ("VMRegionsToBuffer", function ()
    M.regions_to_buffer ()
  end, { buffer = true })

  vim.api.nvim_create_user_command ("VMMassTranspose", function ()
    M.mass_transpose ()
  end, { buffer = true })

  vim.api.nvim_create_user_command ("VMQfix", function (opts)
    M.qfix (not opts.bang)
  end, { buffer = true, bang = true })

  vim.api.nvim_create_user_command ("VMSort", function (opts)
    if opts.args and opts.args ~= "" then
      M.sort (opts.args)
    else
      M.sort ()
    end
  end, { buffer = true, nargs = "?" })
end

-- Unset buffer commands
function M.unset ()
  local commands = {
    "VMFilterRegions",
    "VMFilterLines",
    "VMRegionsToBuffer",
    "VMMassTranspose",
    "VMQfix",
    "VMSort",
  }
  for _, cmd in ipairs (commands) do
    pcall (vim.api.nvim_del_user_command, cmd)
  end
end

-- Tools menu
function M.menu ()
  local opts = {
    { "\"    - ", "Show VM registers" },
    { "i    - ", "Show regions info" },
    { "\n", "" },
    { "f    - ", "Filter regions by pattern or expression" },
    { "l    - ", "Filter lines with regions" },
    { "r    - ", "Regions contents to buffer" },
    { "q    - ", "Fill quickfix with regions lines" },
    { "Q    - ", "Fill quickfix with regions positions and contents" },
  }

  for _, o in ipairs (opts) do
    vim.api.nvim_echo ({ { o[1], "WarningMsg" }, { o[2], "Type" } }, false, {})
  end

  vim.api.nvim_echo ({ { "Enter an option: ", "Directory" } }, false, {})
  local c = vim.fn.nr2char (vim.fn.getchar ())

  if c == "\"" then
    vim.cmd ("redraw!")
    M.show_registers (0, "")
  elseif c == "i" then
    vim.cmd ("redraw!")
    M.regions_contents ()
  elseif c == "r" then
    vim.fn.feedkeys ("\r", "n")
    M.regions_to_buffer ()
  elseif c == "f" then
    vim.cmd ("redraw!")
    M.filter_regions (0, "", 1)
  elseif c == "l" then
    vim.fn.feedkeys ("\r", "n")
    M.filter_lines ()
  elseif c == "q" then
    vim.fn.feedkeys ("\r", "n")
    M.qfix (1)
  elseif c == "Q" then
    vim.fn.feedkeys ("\r", "n")
    M.qfix (0)
  else
    vim.fn.feedkeys ("\r", "n")
  end
end

-- Show regions contents (equivalent to s:F.regions_contents())
function M.regions_contents ()
  local regions = R_fn ()
  if #regions == 0 then
    return
  end

  for _, r in ipairs (regions) do
    local info = string.format (
      "Region %d: line=%d-%d, col=%d-%d, text=\"%s\"",
      r.index,
      r.l,
      r.L,
      r.a,
      r.b,
      r.txt or ""
    )
    print (info)
  end
end

-- Filter lines containing regions, and paste them in a new buffer
function M.filter_lines ()
  local regions = R_fn ()
  if #regions == 0 then
    return
  end

  local lines_data = Global.lines_with_regions (0)
  local line_nums = {}
  for line, _ in pairs (lines_data) do
    table.insert (line_nums, line)
  end
  table.sort (line_nums)

  local txt = {}
  for _, l in ipairs (line_nums) do
    table.insert (txt, vim.fn.getline (l))
  end

  require ("visual-multi.vm").reset (true)
  source_buf = vim.fn.bufnr ("%")

  vim.cmd ("noautocmd keepalt botright new! VM\\ Filtered\\ Lines")
  vim.opt_local.statusline = "%#WarningMsg#VM Filtered Lines (:w updates lines!)"
  vim.b.VM_lines = line_nums
  vim.b.VM_buf = source_buf

  for _, t in ipairs (txt) do
    vim.fn.append (vim.fn.line ("$"), t)
  end
  vim.cmd ("1d _")

  M.temp_buffer ()
  vim.api.nvim_create_autocmd ("BufWriteCmd", {
    buffer = 0,
    callback = function ()
      M.save_lines ()
    end,
  })
end

-- Save filtered lines back to source buffer
function M.save_lines ()
  vim.opt_local.modified = false
  local line_nums = vim.b.VM_lines
  local num_lines = vim.fn.line ("$")

  if #line_nums ~= num_lines then
    return Funcs.msg ("Number of lines doesn't match, aborting")
  end

  local lines = {}
  for i = 1, num_lines do
    table.insert (lines, vim.fn.getline (i))
  end

  local buf = vim.b.VM_buf
  vim.cmd ("quit")
  vim.cmd (buf .. "b")

  for i, l in ipairs (line_nums) do
    vim.fn.setline (l, lines[i])
  end
end

-- Paste selected regions in a new buffer
function M.regions_to_buffer ()
  local regions = R_fn ()
  if X_fn () == 0 or #regions == 0 then
    return
  end

  local txt = {}
  for _, r in ipairs (regions) do
    local t = r.txt or ""
    if t:sub (-1) ~= "\n" then
      t = t .. "\n"
    end
    table.insert (txt, t)
  end

  require ("visual-multi.vm").reset (true)
  source_buf = vim.fn.bufnr ("%")

  vim.cmd ("noautocmd keepalt botright new! VM\\ Filtered\\ Regions")
  vim.opt_local.statusline = "%#WarningMsg#VM Filtered Regions (:w updates regions!)"
  vim.b.VM_regions = vim.deepcopy (regions)
  vim.b.VM_buf = source_buf

  for _, t in ipairs (txt) do
    vim.fn.append (vim.fn.line ("$"), t)
  end
  vim.cmd ("1d _")

  M.temp_buffer ()
  vim.api.nvim_create_autocmd ("BufWriteCmd", {
    buffer = 0,
    callback = function ()
      M.save_regions ()
    end,
  })
end

-- Save regions back to source buffer
function M.save_regions ()
  vim.opt_local.modified = false
  local saved_regions = vim.b.VM_regions
  local num_lines = vim.fn.line ("$")

  if #saved_regions ~= num_lines then
    return Funcs.msg ("Number of lines doesn't match number of regions")
  end

  local lines = {}
  for i = 1, num_lines do
    table.insert (lines, vim.fn.getline (i))
  end

  local buf = vim.b.VM_buf
  vim.cmd ("quit")
  vim.cmd (buf .. "b")

  -- Recreate regions
  for _, r in ipairs (saved_regions) do
    require ("visual-multi.region").new (false, r.l, r.L, r.a, r.b)
  end

  Global.extend_mode ()
  Edit.replace_regions_with_text (lines)
end

-- Filter regions based on pattern or expression
function M.filter_regions (type, exp, prompt)
  if type == 0 or type > 2 then
    filter_type = 0
  else
    filter_type = type
  end

  local types = { "pattern", "!pattern", "expression" }
  local type_name = types[filter_type + 1]

  if prompt then
    -- Set up Ctrl-X mapping for cycling filter types
    vim.fn.execute (
      "cnoremap <buffer><nowait><silent><expr> <C-x> <SID>filter_regions(getcmdline())"
    )

    local result
    local ok, input_result = pcall (function ()
      return vim.fn.input ("Enter a filter (^X " .. type_name .. ") > ", exp, "command")
    end)

    vim.fn.execute ("silent! cunmap <buffer> <C-x>")

    if not ok or input_result == "" then
      exp = ""
    else
      exp = input_result
    end
  end

  if exp == "" or exp == nil then
    Funcs.msg ("Canceled.")
  else
    Global.filter_by_expression (exp, type_name)
    Global.update_and_select_region ()
  end
end

-- Helper for filter_regions Ctrl-X mapping (called from mapping)
function M._filter_regions_cmd (fill)
  filter_type = (filter_type + 1) % 3
  local args = filter_type .. ", '" .. fill .. "', 1"
  return "<C-U><Esc>:lua require('visual-multi.special.commands').filter_regions("
    .. args
    .. ")<cr>"
end

-- Mass transpose regions
function M.mass_transpose ()
  local regions = R_fn ()
  if #regions == 1 or X_fn () == 0 then
    print ("Not possible")
    return
  end

  local txt = Global.regions_text ()

  -- Create a list of unique region contents
  local unique = {}
  local seen = {}
  for _, t in ipairs (txt) do
    if not seen[t] then
      seen[t] = true
      table.insert (unique, t)
    end
  end

  if #unique == 1 then
    print ("Regions have the same content")
    return
  end

  -- Move first unique text to the bottom of the stack
  local old = vim.deepcopy (unique)
  table.insert (unique, table.remove (unique, 1))

  -- Create new text mapping
  local new_text = {}
  for _, t in ipairs (txt) do
    for i, u in ipairs (unique) do
      if u == t then
        table.insert (new_text, old[i])
        break
      end
    end
  end

  -- Fill register and paste new text
  Edit.fill_register ("\"", new_text, 0)
  Edit.paste (1, 0, 1, "\"")
end

-- Show debug messages
function M.debug ()
  if not vim.b.VM_Debug then
    return
  elseif vim.tbl_isempty (vim.b.VM_Debug.lines or {}) then
    vim.api.nvim_echo ({ { "[visual-multi] No errors", "Normal" } }, false, {})
    return
  end

  for _, line in ipairs (vim.b.VM_Debug.lines) do
    if line and line ~= "" then
      vim.api.nvim_echo ({ { line, "Normal" } }, false, {})
    end
  end
end

-- Fill quickfix list with regions
function M.qfix (full_line)
  require ("visual-multi.vm").reset ()
  local qfix = {}

  if full_line then
    local lines_data = Global.lines_with_regions (0)
    local line_nums = {}
    for line, _ in pairs (lines_data) do
      table.insert (line_nums, line)
    end
    table.sort (line_nums)

    for _, line in ipairs (line_nums) do
      table.insert (qfix, {
        bufnr = vim.fn.bufnr (""),
        lnum = line,
        col = 1,
        text = vim.fn.getline (line),
        valid = 1,
      })
    end
  else
    for _, r in ipairs (R_fn ()) do
      table.insert (qfix, {
        bufnr = vim.fn.bufnr (""),
        lnum = r.l,
        col = r.a,
        text = r.txt,
        valid = 1,
      })
    end
  end

  vim.fn.setqflist (qfix)
  vim.cmd ("copen")
  vim.cmd ("cc")
end

-- Show VM registers in the command line
function M.show_registers (delete, args)
  if delete then
    if args ~= "" then
      -- Don't delete " or - registers, they are reset anyway at VM restart
      if args ~= "\"" and args ~= "-" then
        vim.g.Vm.registers[args] = nil
      end
    else
      vim.g.Vm.registers = { ["\""] = {}, ["-"] = {} }
    end
    return
  elseif args ~= "" then
    if not vim.g.Vm.registers or not vim.g.Vm.registers[args] then
      print ("[visual-multi] invalid register")
      return
    else
      registers = { args }
    end
  else
    if not vim.g.Vm.registers then
      vim.g.Vm.registers = { ["\""] = {}, ["-"] = {} }
    end
    registers = vim.tbl_keys (vim.g.Vm.registers)
  end

  vim.api.nvim_echo ({ { " Register\tLine\t--- Register contents ---", "Label" } }, false, {})

  for _, r in ipairs (registers) do
    -- Skip temporary register
    if r == "§" then
      goto continue
    end

    vim.api.nvim_echo ({ { "\n    " .. r, "Directory" } }, false, {})

    local reg_data = vim.g.Vm.registers[r] or {}
    for l, s in ipairs (reg_data) do
      vim.api.nvim_echo ({
        { "\t\t" .. l .. "\t", "WarningMsg" },
        { tostring (s), "Normal" },
      }, false, {})
    end

    ::continue::
  end
end

-- Search pattern in range
function M.search (bang, l1, l2, pattern)
  local just_started = not vim.b.visual_multi or vim.b.visual_multi == 0
  local pat = pattern ~= "" and pattern or vim.fn.getreg ("/")
  local pos = { vim.fn.getcurpos ()[2], vim.fn.getcurpos ()[3] }
  local view = vim.fn.winsaveview ()

  local ok, err = pcall (function ()
    require ("visual-multi.vm").init_buffer (1)
    vim.g.Vm.extend_mode = 1

    if vim.fn.search (pat, "n") == 0 then
      error ("not found")
    end

    if just_started then
      Search.get_slash_reg (pat)
    else
      Search.add (pat)
    end

    if bang then
      local r = require ("visual-multi.commands").find_next (0, 0)
    elseif l1 == 1 and l2 == vim.fn.line ("$") then
      require ("visual-multi.commands").find_next (0, 0)
      local r = require ("visual-multi.commands").find_all (0, 0)
    else
      local start = vim.fn.line2byte (l1)
      local end_ = vim.fn.line2byte (l2) + vim.fn.col ({ l2, "$" }) - 1
      local r = Global.get_all_regions (start, end_)
    end

    require ("visual-multi.commands").reset_direction (1)
    vim.fn.winrestview (view)
    Global.select_region_at_pos ({ r.l, r.a })
  end)

  if not ok then
    if just_started then
      vim.cmd ("VMClear")
    end
    vim.fn.setpos (".", { 0, pos[1], pos[2], 0 })
    vim.fn.winrestview (view)
    vim.cmd ("redraw")
    print ("[visual multi] pattern not found")
    if not just_started then
      Global.select_region_at_pos (".")
    end
  end
end

-- Sort regions
function M.sort (...)
  local args = { ... }
  if #args > 0 then
    Edit.replace_regions_with_text (vim.fn.sort (Global.regions_text (), args[1]))
  else
    Edit.replace_regions_with_text (vim.fn.sort (Global.regions_text ()))
  end
end

-- Toggle live editing
function M.live ()
  vim.g.VM_live_editing = vim.g.VM_live_editing == nil and false or not vim.g.VM_live_editing
  local active = vim.g.VM_live_editing and "active" or "inactive"
  Funcs.msg ("live editing is " .. active)
end

-- Set up temporary buffer options
function M.temp_buffer ()
  vim.opt_local.buftype = "acwrite"
  vim.opt_local.bufhidden = "wipe"
  vim.opt_local.swapfile = false
  vim.opt_local.buflisted = false
  vim.opt_local.modified = false
  vim.b.VM_buf = source_buf
end

return M
