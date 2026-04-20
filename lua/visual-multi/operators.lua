-- lua/visual-multi/operators.lua
-- Operators module - select and find operators
-- Equivalent to autoload/vm/operators.vim

local M = {}

-- Module references, populated by M.init()
local State
local Global
local Funcs

-- Buffer-local state references
local V -- b:VM_Selection (State buffer state)
local v -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)

-- Cached lambdas (equivalent to VimScript s:R, s:single, s:double)
local R_fn -- returns V.regions
local single_fn -- single character motion check
local double_fn -- double character motion check

-- Temporary storage for find operation
local Bytes -- backup of V.Bytes for merge

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

  single_fn = function (c)
    local single_chars = vim.fn.split ("hljkwebWEB$^0{}()%nN", "\\zs")
    return vim.fn.index (single_chars, c) >= 0
  end

  double_fn = function (c)
    local double_chars = vim.fn.split ("iafFtTg", "\\zs")
    return vim.fn.index (double_chars, c) >= 0
  end

  return M
end

-- Initialize for operator mode
local function init_operator ()
  vim.g.Vm.extend_mode = 1
  if not vim.g.Vm.buffer then
    vim.fn["vm#init_buffer"] (0)
  end
end

-- ===========================================================================
-- Select operator
-- ===========================================================================

function M.select (count, ...)
  init_operator ()
  local pos_data = vim.fn.getpos (".")
  local pos = { pos_data[2], pos_data[3] }
  Funcs.Scroll.get (1)

  -- If argument provided, use it directly
  if select ("#", ...) > 0 then
    M._select (select (1, ...))
    return
  end

  local abort = false
  local s = ""
  local n = ""
  local x = count and count > 1 and count or 1
  vim.api.nvim_echo ({ { "Selecting: " .. (x > 1 and x or ""), "Type" } }, false, {})

  while true do
    local c_num = vim.fn.getchar ()

    if c_num == 27 then
      abort = true
      break
    else
      local c = vim.fn.nr2char (c_num)

      if tonumber (c) and tonumber (c) > 0 then
        n = n .. c
        vim.api.nvim_echo ({ { c, "Type" } }, false, {})
      elseif single_fn (c) then
        s = s .. c
        vim.api.nvim_echo ({ { c, "Type" } }, false, {})
        break
      elseif double_fn (c) or #s > 0 then
        s = s .. c
        vim.api.nvim_echo ({ { c, "Type" } }, false, {})
        if #s > 1 then
          break
        end
      else
        abort = true
        break
      end
    end
  end

  if abort then
    return
  end

  -- Change $ to g_
  s = s:gsub ("%$", "g_")

  local n_num = n ~= "" and tonumber (n) or 1
  local final_n = n_num * x > 1 and n_num * x or ""
  M._select (final_n .. s)
  Global.update_and_select_region (pos)
  Funcs.Scroll.restore ()
end

-- ===========================================================================
-- Internal select implementation
-- ===========================================================================

function M._select (obj)
  M._updatetime ()
  V.Maps.disable (1)

  local cmd
  if obj:match ("\"") or obj:match ("'") then
    cmd = "v" .. obj .. "y"
  else
    cmd = "y" .. obj
  end

  vim.cmd ("silent! nunmap <buffer> y")

  local Rs = vim.tbl_map (function (r)
    return { r.l, r.a }
  end, R_fn ())

  Global.erase_regions ()

  for _, r in ipairs (Rs) do
    vim.fn.cursor (r[1], r[2])
    vim.cmd ("normal " .. cmd)
    M._get_region (0)
  end

  V.Maps.enable ()
  Global.check_mutliline (1)

  vim.cmd ("nmap <silent><nowait><buffer> y <Plug>(VM-Yank)")

  if vim.tbl_isempty (v.search) then
    vim.fn.setreg ("/", "")
  end
  M._old_updatetime ()
end

-- ===========================================================================
-- After yank callback
-- ===========================================================================

function M.after_yank ()
  -- Find operator
  if vim.g.Vm.finding then
    vim.g.Vm.finding = 0
    M.find (0, v.visual_regex)
    v.visual_regex = 0
    M._old_updatetime ()
    vim.cmd ("nmap <silent> <nowait> <buffer> y <Plug>(VM-Yank)")
  end
end

-- ===========================================================================
-- Get region with select operator
-- ===========================================================================

function M._get_region (add_pattern)
  -- Create region with select operator
  local R = Global.region_at_pos ()
  if R and not vim.tbl_isempty (R) then
    return R
  end

  R = vim.fn["vm#region#new"] (0)
  -- R.txt can be different because yank != visual yank
  R.update_content ()
  if add_pattern then
    V.Search.add_if_empty ()
  end
  Funcs.restore_reg ()
  return R
end

-- ===========================================================================
-- Find operator
-- ===========================================================================

function M.find (start, visual, ...)
  if start then
    if not vim.g.Vm.buffer then
      M._backup_map_find ()
      if visual then
        -- Use search register if just starting from visual mode
        V.Search.get_slash_reg (v.oldsearch[1])
      end
    else
      V.Search.ensure_is_set ()
      M._backup_map_find ()
    end

    M._updatetime ()
    vim.g.Vm.finding = 1
    v.vblock = visual and vim.fn.mode () == "\22" -- <C-v>
    vim.cmd ("silent! nunmap <buffer> y")
    return "y"
  end

  -- Set the cursor to the start of the yanked region, then find occurrences until end mark is met
  local end_pos = vim.fn.getpos ("']")
  local endline, endcol = end_pos[2], end_pos[3]
  vim.cmd ("keepjumps normal! `[")
  local start_pos = vim.fn.getpos (".")
  local startline, startcol = start_pos[2], start_pos[3]

  if vim.fn.search (vim.fn.join (v.search, "\\|"), "znp", endline) == 0 then
    M._merge_find ()
    if #R_fn () == 0 then
      vim.fn["vm#reset"] (1)
    end
    return
  end

  local ows = vim.o.wrapscan
  vim.o.wrapscan = false
  vim.cmd ("silent keepjumps normal! ygn")

  if v.vblock then
    local R = vim.fn.getpos (".")[3]
    if not (R < startcol or R > endcol) then
      Global.new_region ()
    end
  else
    Global.new_region ()
  end

  while true do
    if vim.fn.search (vim.fn.join (v.search, "\\|"), "znp", endline) == 0 then
      break
    end
    vim.cmd ("silent keepjumps normal! nygn")
    if vim.fn.getpos ("'[")[2] > endline then
      break
    elseif v.vblock then
      local R = vim.fn.getpos (".")[3]
      if not (R < startcol or R > endcol) then
        Global.new_region ()
      end
    else
      Global.new_region ()
    end
  end

  vim.o.wrapscan = ows
  M._merge_find ()
end

-- ===========================================================================
-- Helper functions
-- ===========================================================================

function M._updatetime ()
  -- If not using TextYankPost, use CursorHold and reduce &updatetime
  if vim.g.Vm.oldupdate then
    vim.o.updatetime = 100
  end
end

function M._old_updatetime ()
  -- Restore old &updatetime value
  if vim.g.Vm.oldupdate then
    vim.o.updatetime = vim.g.Vm.oldupdate
  end
end

function M._backup_map_find ()
  -- Use temporary regions, they will be merged later
  init_operator ()
  Bytes = vim.deepcopy (V.Bytes)
  V.regions = {}
  V.Bytes = {}
  v.index = -1
  v.no_search = 1
  v.eco = 1
end

function M._merge_find ()
  local new_map = vim.deepcopy (V.Bytes)
  V.Bytes = Bytes
  Global.merge_maps (new_map)
end

return M
