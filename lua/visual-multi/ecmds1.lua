-- lua/visual-multi/ecmds1.lua
-- Ecmds1 module - edit commands #1 (yank, delete, paste, replace)
-- Equivalent to autoload/vm/ecmds1.vim

local M = {}

-- Module references
local State
local Global
local Funcs

-- Buffer-local state references
local V
local v
local v_regions

-- Cached lambdas
local R_fn
local X_fn
local min_fn

-- State
local old_text = {}

-- Edit object
local Edit = {}

function M.init ()
  State = require ("visual-multi.state")
  Global = require ("visual-multi.global")
  Funcs = require ("visual-multi.funcs")

  V = State.get ()
  v = V.vars
  v_regions = V.regions

  R_fn = function ()
    return v_regions
  end
  X_fn = function ()
    return vim.g.Vm and vim.g.Vm.extend_mode or 0
  end
  min_fn = function (n)
    return X_fn () == 1 and #R_fn () >= n
  end

  -- Merge with ecmds2
  local ecmds2 = require ("visual-multi.ecmds2")
  ecmds2.init ()
  for k, v2 in pairs (ecmds2.get_edit ()) do
    Edit[k] = v2
  end

  return Edit
end

-- Get Edit object
function M.get_edit ()
  return Edit
end

-- ===========================================================================
-- Yank
-- ===========================================================================

function Edit.yank (reg, silent, ...)
  -- Yank the regions contents in a VM register
  local register = (v.use_register ~= v.def_reg) and v.use_register or reg

  if X_fn () == 0 then
    require ("visual-multi.cursors").operation ("y", vim.v.count, register)
    return
  end
  if not min_fn (1) then
    Funcs.msg ("No regions selected.")
    return
  end

  -- Write custom and possibly vim registers
  local text, type = Edit.fill_register (register, Global.regions_text (), false)

  -- Restore default register if a different register was provided
  if register ~= v.def_reg then
    Funcs.restore_reg ()
  end

  -- Reset temp register
  v.use_register = v.def_reg

  if not silent then
    Funcs.msg ("Yanked the content of " .. #R_fn () .. " regions.")
  end
  if select ("#", ...) > 0 then
    Global.change_mode ()
  end
end

-- ===========================================================================
-- Delete
-- ===========================================================================

function Edit.delete (X, register, count, manual)
  -- Delete the selected text and change to cursor mode
  -- Return the deleted text
  if Funcs.no_regions () then
    return
  end
  if v.direction == 0 then
    require ("visual-multi.commands").invert_direction ()
  end

  if not X then
    -- Ask for motion
    require ("visual-multi.cursors").operation ("d", count, register)
    return
  end

  local winline = vim.fn.winline ()
  local size = Funcs.size ()
  local change = 0
  local ix = Global.select_region_at_pos (".").index
  old_text = Global.regions_text ()
  local retVal = vim.deepcopy (old_text)
  v.deleting = 1

  -- Manual deletion: backup current regions
  if manual then
    Global.backup_regions ()
  end

  for _, r in ipairs (R_fn ()) do
    r.shift (change, change)
    Edit.extra_spaces.add (r)
    vim.fn.cursor (r.l, r.a)
    if r.w == 1 then
      vim.cmd ("normal! \"_dl")
    else
      vim.cmd ("normal! m[")
      vim.fn.cursor (r.L, r.b > 1 and r.b + 1 or 1)
      vim.cmd ("normal! m]`[\"_d`]")
    end

    -- Update changed size
    change = Funcs.size () - size
  end

  -- Write custom and possibly vim registers
  Edit.fill_register (register, old_text, manual)

  Global.change_mode ()
  Global.select_region (ix)

  if manual then
    Edit.extra_spaces.remove ()
    Global.update_and_select_region ()
  end
  if register == "_" then
    Funcs.restore_reg ()
  end
  Funcs.Scroll.force (winline)
  old_text = {}
  return retVal
end

function Edit.xdelete (key, cnt)
  -- Delete with 'x' or 'X' key, use black hole register in extend mode
  if X_fn () == 1 then
    Edit.delete (1, "_", cnt, 1)
  else
    Edit.run_normal (key, { count = cnt, recursive = 0 })
  end
end

-- ===========================================================================
-- Paste
-- ===========================================================================

function Edit.paste (before, vim_reg, reselect, register, ...)
  -- Perform a paste of the appropriate type
  -- @param before: 'P' or 'p' behaviour
  -- @param vim_reg: if forcing regular vim registers
  -- @param reselect: trigger reselection if run from extend mode
  -- @param register: the register being used
  -- @param ...: optional list with replacement text for regions
  local X = X_fn ()
  v.use_register = register
  local use_vim_reg = vim_reg
    or not vim.g.Vm.registers[register]
    or vim.tbl_isempty (vim.g.Vm.registers[register])
  local vim_V = use_vim_reg and vim.fn.getregtype (register) == "V"

  if #old_text == 0 then
    old_text = Global.regions_text ()
  end

  if vim_V then
    Edit.run_normal ("\"" .. register .. "p", { recursive = 0 })
    return
  elseif select ("#", ...) > 0 then
    v.new_text = select (1, ...)
  elseif use_vim_reg then
    v.new_text = Edit.convert_vimreg (vim_reg)
  else
    v.new_text = M._fix_regions_text (vim.g.Vm.registers[register])
  end

  Global.backup_regions ()

  if X then
    Edit.delete (1, "_", 1, 0)
  end

  Edit.block_paste (before)

  v.W = Edit.store_widths (v.new_text)
  Edit.post_process ((X and 1 or reselect), not before)
  old_text = {}
end

function Edit.block_paste (before)
  -- Paste the new text (list-type) at cursors
  local size = Funcs.size ()
  local text = vim.deepcopy (v.new_text)
  local change = 0
  v.eco = 1

  for _, r in ipairs (R_fn ()) do
    if #text > 0 then
      r.shift (change, change)
      vim.fn.cursor (r.l, r.a)
      local s = table.remove (text, 1)
      Funcs.set_reg (s)

      if before then
        vim.cmd ("normal! P")
      else
        vim.cmd ("normal! p")
        if v.dont_move_cursors == 0 then
          r.update_cursor_pos ()
        end
      end

      -- Update changed size
      change = Funcs.size () - size
    else
      break
    end
  end
  v.dont_move_cursors = 0
  Funcs.restore_reg ()
end

-- ===========================================================================
-- Replace
-- ===========================================================================

function Edit.replace_chars ()
  -- Replace single characters or selections with character
  if X_fn () == 1 then
    local char = vim.fn.nr2char (vim.fn.getchar ())
    if char:upper () == "<ESC>" then
      return
    end

    if v.multiline == 1 then
      Funcs.toggle_option ("multiline")
      Global.remove_empty_lines ()
    end

    v.W = Edit.store_widths ()
    v.new_text = {}

    for i = 1, #v.W do
      local r = ""
      while #r < v.W[i] do
        r = r .. char
      end
      v.W[i] = v.W[i] - 1
      table.insert (v.new_text, r)
    end

    Edit.delete (1, "_", 1, 0)
    Edit.block_paste (true)
    Edit.post_process (1, 0)
  else
    Funcs.msg ("Replace char... ")
    local char = vim.fn.nr2char (vim.fn.getchar ())
    if char:upper () == "<ESC>" then
      Funcs.msg ("Canceled.")
      return
    end
    Edit.run_normal ("r" .. char, { recursive = 0, stay_put = 1 })
  end
end

function Edit.replace ()
  -- Replace a pattern in all regions, or start replace mode
  if X_fn () == 0 then
    V.Insert.replace = 1
    return V.Insert.key ("i")
  end

  local ix = v.index
  Funcs.Scroll.get ()

  vim.cmd ("echohl Type")
  local pat = vim.fn.input ("Pattern to replace > ")
  if pat == "" then
    Funcs.msg ("Command aborted.")
    return
  end
  local repl = vim.fn.input ("Replacement > ")
  if repl == "" then
    Funcs.msg ("Hit Enter for an empty replacement... ")
    if vim.fn.getchar () ~= 13 then
      Funcs.msg ("Command aborted.")
      return
    end
  end
  vim.cmd ("echohl None")

  local text = Global.regions_text ()
  local T = {}
  for _, t in ipairs (text) do
    table.insert (T, vim.fn.substitute (t, "\\C" .. pat, repl, "g"))
  end
  Edit.replace_regions_with_text (T)
  Global.select_region (ix)
end

function Edit.replace_expression ()
  -- Replace all regions with the result of an expression
  if X_fn () == 0 then
    return
  end
  local ix = v.index
  Funcs.Scroll.get ()

  vim.cmd ("echohl Type")
  local expr = vim.fn.input ("Expression > ", "", "expression")
  vim.cmd ("echohl None")
  if expr == "" then
    Funcs.msg ("Command aborted.")
    return
  end

  local T = {}
  expr = Funcs.get_expr (expr)
  for _, r in ipairs (R_fn ()) do
    local result = vim.fn.eval (expr)
    if type (result) ~= "string" then
      result = tostring (result)
    end
    table.insert (T, result)
  end
  Edit.replace_regions_with_text (T)
  Global.select_region (ix)
end

-- ===========================================================================
-- Helper functions
-- ===========================================================================

function M._fix_regions_text (replacement)
  -- Ensure there are enough elements for all regions
  local L = replacement
  local i = #R_fn () - #L

  while i > 0 do
    if #old_text > 0 then
      table.insert (L, old_text[#old_text - i + 1] or "")
    else
      table.insert (L, "")
    end
    i = i - 1
  end
  return L
end

function Edit.convert_vimreg (as_block)
  -- Fill the content to paste with the chosen vim register
  local text = {}
  local block = vim.fn.char2nr (vim.fn.getregtype (v.use_register):sub (1, 1)) == 22

  if block then
    -- Default register is of block type, assign a line to each region
    local width = vim.fn.getregtype (v.use_register):sub (2)
    local content = vim.split (vim.fn.getreg (v.use_register), "\n")

    -- Ensure all regions have the same width, fill the rest with spaces
    if as_block then
      for t = 1, #content do
        while #content[t] < tonumber (width) do
          content[t] = content[t] .. " "
        end
      end
    end

    M._fix_regions_text (content)

    for n = 1, #R_fn () do
      table.insert (text, content[n] or "")
    end
  else
    for n = 1, #R_fn () do
      table.insert (text, vim.fn.getreg (v.use_register))
    end
  end
  return text
end

function Edit.store_widths (...)
  -- Build a list that holds the widths(integers) of each region
  -- It will be used for various purposes (reselection, paste as block...)
  local W = {}
  local x = X_fn ()
  local use_text = false
  local use_list = false
  local text_val, list

  if select ("#", ...) > 0 then
    local arg = select (1, ...)
    if type (arg) == "string" then
      text_val = #arg - 1
      use_text = true
    else
      list = arg
      use_list = true
    end
  end

  -- Mismatching blocks must be corrected
  if use_list then
    M._fix_regions_text (list)
  end

  for _, r in ipairs (R_fn ()) do
    local w
    if use_list then
      w = #(list[r.index + 1] or "")
    end
    if use_text then
      table.insert (W, text_val)
    elseif use_list then
      table.insert (W, w > 0 and w - 1 or 0)
    else
      table.insert (W, r.w)
    end
  end
  return W
end

function Edit.fill_register (reg, text, force_ow)
  -- Write custom and possibly vim registers

  -- If doing a change/deletion, write the VM - register
  if v.deleting == 1 then
    vim.g.Vm.registers["-"] = text
    v.deleting = 0
  end

  if reg == "_" then
    return
  end

  local reg_name = reg == "" and "\"" or reg
  local temp_reg = reg_name == "§"
  local overwrite = reg_name == v.def_reg or reg_name == "+" or (force_ow and not temp_reg)
  local maxw = 0
  for _, t in ipairs (text) do
    maxw = math.max (maxw, #t)
  end
  local type = v.multiline == 1 and "V" or (#R_fn () > 1 and "b" .. maxw or "v")

  -- Set VM register, overwrite backup register unless temporary
  if not temp_reg then
    vim.g.Vm.registers[v.def_reg] = text
    v.oldreg = { v.def_reg, table.concat (text, "\n"), type }
  end
  -- Don't store the system register
  if reg_name ~= "+" then
    vim.g.Vm.registers[reg_name] = text
  end

  -- Vim register is overwritten if unnamed, or if forced
  if overwrite then
    vim.fn.setreg (reg_name, table.concat (text, "\n"), type)
  end

  return { text, type }
end

function Edit.replace_regions_with_text (text, ...)
  -- Paste a custom list of strings into current regions
  Edit.fill_register ("\"", text, false)
  local before = select ("#", ...) == 0 or not select (1, ...)
  Edit.paste (before, false, X_fn (), "\"")
end

return M
