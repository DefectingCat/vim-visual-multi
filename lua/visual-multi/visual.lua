-- lua/visual-multi/visual.lua
-- Visual module - commands to add/subtract regions with visual selection
-- Equivalent to autoload/vm/visual.vim

local M = {}

-- Module references, populated by M.init()
local State
local Global
local Funcs

-- Buffer-local state references
local V -- b:VM_Selection (State buffer state)
local v -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)

-- Cached lambdas (equivalent to VimScript s:R, s:X)
local R_fn -- returns V.regions
local X_fn -- returns g:Vm.extend_mode

-- Temporary storage for visual operations
local Bytes -- backup of V.bytes for merge

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

  return M
end

-- ===========================================================================
-- Add visually selected region to current regions
-- ===========================================================================

function M.add (mode)
  -- Add visually selected region to current regions
  local X = M._backup_map ()
  local pos_data = vim.fn.getpos (".")
  local pos = { pos_data[2], pos_data[3] }

  if mode == "v" then
    M._vchar ()
  elseif mode == "V" then
    M._vline ()
  else
    v.direction = M._vblock (1)
  end

  M._visual_merge ()

  if mode == "V" then
    Global.split_lines ()
    Global.remove_empty_lines ()
  elseif mode == "v" then
    for _, r in ipairs (R_fn ()) do
      if r.h then
        v.multiline = 1
        break
      end
    end
  end

  Global.update_and_select_region (pos)
end

-- ===========================================================================
-- Subtract visually selected region from current regions
-- ===========================================================================

function M.subtract (mode)
  -- Subtract visually selected region from current regions
  local X = M._backup_map ()

  if mode == "v" then
    M._vchar ()
  elseif mode == "V" then
    M._vline ()
  else
    M._vblock (1)
  end

  M._visual_subtract ()
  Global.update_and_select_region ({ id = v.IDs_list[#v.IDs_list] })
  if X then
    Global.cursor_mode ()
  end
end

-- ===========================================================================
-- Remove regions outside of visual selection
-- ===========================================================================

function M.reduce ()
  -- Remove regions outside of visual selection
  local X = M._backup_map ()
  Global.rebuild_from_map (Bytes, { Funcs.pos2byte ("'<"), Funcs.pos2byte ("'>") })
  if X then
    Global.cursor_mode ()
  end
  Global.update_and_select_region ()
end

-- ===========================================================================
-- Create cursors, one for each line of the visual selection
-- ===========================================================================

function M.cursors (mode)
  -- Create cursors, one for each line of the visual selection
  M.init ()
  local pos_data = vim.fn.getpos (".")
  local pos = { pos_data[2], pos_data[3] }
  local start_pos = vim.fn.getpos ("'<")
  local end_pos = vim.fn.getpos ("'>")
  local start = { start_pos[2], start_pos[3] }
  local end_pos_data = { end_pos[2], end_pos[3] }

  M._create_cursors (start, end_pos_data)

  if
    mode == "V" and (vim.g.VM_autoremove_empty_lines == nil or vim.g.VM_autoremove_empty_lines == 1)
  then
    Global.remove_empty_lines ()
  end

  Global.update_and_select_region (pos)
end

-- ===========================================================================
-- Split regions with regex pattern
-- ===========================================================================

function M.split ()
  -- Split regions with regex pattern
  M.init ()
  if #R_fn () == 0 then
    return
  end
  if X_fn () == 0 then
    Funcs.msg ("Not in cursor mode.")
    return
  end

  vim.cmd ("echohl Type")
  local pat = vim.fn.input ("Pattern to remove > ")
  vim.cmd ("echohl None")
  if pat == "" then
    Funcs.msg ("Command aborted.")
    return
  end

  local start_r = R_fn ()[1] -- first region
  local stop_r = R_fn ()[#R_fn ()] -- last region

  Funcs.Cursor (start_r.A)
  -- Search method: accept at cursor position
  if vim.fn.search (pat, "nczW", stop_r.L) == 0 then
    Funcs.msg ("\t\tPattern not found")
    Global.select_region (v.index)
    return
  end

  M._backup_map ()

  -- Backup old patterns and create new regions
  local oldsearch = vim.deepcopy (v.search)
  V.Search.get_slash_reg (pat)

  Global.get_all_regions (start_r.A, stop_r.B)

  -- Subtract regions and rebuild from map
  M._visual_subtract ()
  V.Search.join (oldsearch)
  Global.update_and_select_region ()
end

-- ===========================================================================
-- Helper functions
-- ===========================================================================

-- Characterwise selection
function M._vchar ()
  vim.cmd ("silent keepjumps normal! `<y`>`]")
  Global.check_mutliline (0, Global.new_region ())
end

-- Linewise selection
function M._vline ()
  vim.cmd ("silent keepjumps normal! '<y'>`]")
  Global.new_region ()
end

-- Blockwise selection
function M._vblock (extend)
  local start_pos = vim.fn.getpos ("'<")
  local end_pos = vim.fn.getpos ("'>")
  local start = { start_pos[2], start_pos[3] }
  local end_data = { end_pos[2], end_pos[3] }

  local inverted
  if start[2] > end_data[2] then
    -- Swap columns because top-right or bottom-left corner is selected
    local temp = start[2]
    start[2] = end_data[2]
    end_data[2] = temp
    inverted = vim.fn.line (".") == vim.fn.line ("'>")
  else
    inverted = vim.fn.line (".") == vim.fn.line ("'<")
  end

  local block_width = math.abs (vim.fn.virtcol ("'>") - vim.fn.virtcol ("'<"))

  M._create_cursors (start, end_data)

  if extend and block_width > 0 then
    require ("visual-multi.commands").motion ("l", block_width, 1, 0)
  end
  return not inverted
end

-- Backup map for temporary regions
function M._backup_map ()
  -- Use temporary regions, they will be merged later
  M.init ()
  local X = Global.extend_mode ()
  Bytes = vim.deepcopy (V.bytes)
  Global.erase_regions ()
  v.no_search = 1
  v.eco = 1
  return X
end

-- Merge regions
function M._visual_merge ()
  local new_map = vim.deepcopy (V.bytes)
  V.bytes = Bytes
  Global.merge_maps (new_map)
end

-- Subtract regions
function M._visual_subtract ()
  local new_map = vim.deepcopy (V.bytes)
  V.bytes = Bytes
  Global.subtract_maps (new_map)
end

-- Create cursors that span over visual selection
function M._create_cursors (start, end_data)
  vim.fn.cursor (start[1], start[2])

  if end_data[1] > start[1] then
    while vim.fn.line (".") < end_data[1] do
      require ("visual-multi.commands").add_cursor_down (0, 1)
    end
  elseif not Global.region_at_pos () then
    -- Ensure there's at least a cursor
    Global.new_cursor ()
  end
end

return M
