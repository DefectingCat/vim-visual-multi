-- lua/visual-multi/global.lua
-- Global class for visual-multi
-- Manages regions, modes, highlighting, and region selection

local M = {}

-- Module references (set during init)
local Region
local State
local Config
local Bytes
local Offset

-- Buffer-local state references (set during init)
local V -- b:VM_Selection (State buffer state)
local v -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)
local v_bytes -- V.bytes (bytes map)

-- Cached lambdas
local X_fn -- returns g:Vm.extend_mode
local R_fn -- returns V.regions

-- Initialize module with buffer state
function M.init ()
  Region = require ("visual-multi.region")
  State = require ("visual-multi.state")
  Config = require ("visual-multi.config")
  Bytes = require ("visual-multi.bytes")
  Offset = require ("visual-multi.offset")

  V = State.get ()
  v = V.vars
  v_regions = V.regions
  v_bytes = V.bytes

  X_fn = function ()
    return vim.g.Vm and vim.g.Vm.extend_mode or 0
  end

  R_fn = function ()
    return v_regions
  end

  return M
end

-- ===========================================================================
-- Regions creation and access
-- ===========================================================================

-- Get the region under cursor, or create a new one if there is none.
function M.new_region ()
  local R = M.region_at_pos ()
  if not R or vim.tbl_isempty (R) then
    R = Region.new (0)
    v.was_region_at_pos = 0
  else
    v.was_region_at_pos = 1
  end

  if v.eco == 0 then
    M.select_region (R.index)
    if V.Search then
      V.Search.update_patterns ()
    end
  end

  return R
end

-- Create a new cursor if there isn't already a region.
-- @param toggle (boolean) if truthy and region exists, clear it
function M.new_cursor (toggle)
  local R = M.region_at_pos ()

  if not R or vim.tbl_isempty (R) then
    return Region.new (1)
  elseif toggle then
    R:clear ()
  end

  -- If should_quit, reset (handled by caller)
  return R
end

-- Return current working set of regions.
function M.active_regions ()
  if v.single_region == 1 then
    return { v_regions[v.index + 1] }
  else
    return v_regions
  end
end

-- Get all regions, optionally between two byte offsets.
-- This scans the buffer for all matches and creates regions.
function M.get_all_regions (start_byte, end_byte)
  local ows = vim.o.wrapscan
  local ei = vim.o.eventignore
  vim.o.wrapscan = true
  vim.o.eventignore = "all"

  local start = start_byte or 1
  local end_ = end_byte or 0

  -- Position at start byte
  if start > 1 then
    local pos = Offset.byte2pos (start)
    vim.fn.cursor (pos[1], pos[2])
  end

  -- Yank current match and create region
  vim.cmd ("silent keepjumps normal! ygn")
  local R = M.new_region ()

  while true do
    local ok, err = pcall (function ()
      vim.cmd ("silent keepjumps normal! nygn")
      local current_byte = Offset.pos2byte ("'[")
      if start_byte and current_byte > end_ then
        error ("past end")
      end
      R = M.new_region ()
      if v.find_all_overlap == 0 and M.overlapping_regions (R) then
        v.find_all_overlap = 1
      end
    end)
    if not ok then
      break
    end
  end

  vim.o.wrapscan = ows
  vim.o.eventignore = ei

  return R
end

-- ===========================================================================
-- Change mode
-- ===========================================================================

-- Change from extend to cursor mode and vice versa.
-- Merge cursors if transitioning from cursor mode, but reset direction
-- transitioning from extend mode.
function M.change_mode (called_manually)
  if X_fn () == 0 then
    M.merge_cursors ()
  else
    M.backup_last_regions ()
  end

  local cur_mode = X_fn ()
  vim.g.Vm = vim.g.Vm or {}
  vim.g.Vm.extend_mode = cur_mode == 0 and 1 or 0

  local ix = v.index
  -- Scroll save/restore
  if X_fn () == 1 then
    M.update_regions ()
  else
    M.collapse_regions ()
  end

  local R = M.select_region (ix)

  if called_manually then
    v.restore_scroll = 1
  end

  return R
end

-- Set cursor mode. Return true if mode had to be changed.
function M.cursor_mode ()
  if X_fn () == 1 then
    M.change_mode ()
    return true
  end
  return false
end

-- Set extend mode. Return true if mode had to be changed.
function M.extend_mode ()
  if X_fn () == 0 then
    M.change_mode ()
    return true
  end
  return false
end

-- ===========================================================================
-- Highlight
-- ===========================================================================

-- Update highlight for all regions.
function M.update_highlight ()
  if v.eco == 1 then
    return
  end

  M.remove_highlight ()
  for _, r in ipairs (R_fn ()) do
    if r.highlight then
      r:highlight ()
    end
  end

  M.update_cursor_highlight ()
end

-- Set cursor highlight, depending on extending mode.
function M.update_cursor_highlight ()
  if v.eco == 1 then
    return
  end

  vim.api.nvim_exec ("highlight clear MultiCursor", false)

  if v.insert == 1 then
    vim.api.nvim_exec ("highlight! link MultiCursor VM_Insert", false)
  elseif X_fn () == 0 and M.all_empty () then
    vim.api.nvim_exec ("highlight! link MultiCursor VM_Mono", false)
  else
    vim.api.nvim_exec ("highlight! link MultiCursor VM_Cursor", false)
  end
end

-- Remove all regions' highlight.
function M.remove_highlight ()
  for _, r in ipairs (R_fn ()) do
    if r.remove_highlight then
      r:remove_highlight ()
    end
  end
  M.clear_matches ()
end

-- Clear all vim match highlights
function M.clear_matches ()
  -- vim.fn.getmatches() returns list of matches with 'id' field
  local matches = vim.fn.getmatches ()
  for _, m in ipairs (matches) do
    if m.id and m.id > 0 then
      vim.fn.matchdelete (m.id)
    end
  end
end

-- ===========================================================================
-- Region functions
-- ===========================================================================

-- If not all regions are empty, turn on extend mode.
function M.all_empty ()
  for _, r in ipairs (R_fn ()) do
    if r.a ~= r.b then
      if X_fn () == 0 then
        vim.g.Vm = vim.g.Vm or {}
        vim.g.Vm.extend_mode = 1
      end
      return false
    end
  end
  return true
end

-- Force regions update.
function M.update_regions ()
  if v.eco == 1 then
    return
  end

  if X_fn () == 1 then
    for _, r in ipairs (R_fn ()) do
      if r.update_region then
        r:update_region ()
      end
    end
  else
    for _, r in ipairs (R_fn ()) do
      if r.update_cursor then
        r:update_cursor ()
      end
    end
  end

  M.update_highlight ()
end

-- Select a region by index and return it.
function M.select_region (i)
  local regions = R_fn ()
  if #regions == 0 then
    return nil
  end

  -- Wrap around if index exceeds region count
  local idx = i
  if idx >= #regions then
    idx = 0
  end

  local R = regions[idx + 1] -- Lua is 1-indexed
  vim.fn.cursor (R:cur_ln (), R:cur_col ())
  v.index = R.index

  return R
end

-- Try to select a region at the given position.
function M.select_region_at_pos (pos)
  local r = M.region_at_pos (pos)
  if r and not vim.tbl_isempty (r) then
    return M.select_region (r.index)
  else
    local nearest = M.nearest_region (pos)
    if nearest then
      return M.select_region (nearest.index)
    end
  end
  return nil
end

-- Return the region at position, or nil if not found.
-- @param pos optional: can be a string mark ('.', '[', etc.),
--   a [ln, col] table, a byte offset number, or nil for cursor position
function M.region_at_pos (pos)
  local byte_pos

  if pos == nil then
    byte_pos = Offset.curs2byte ()
  elseif type (pos) == "number" then
    byte_pos = pos
  elseif type (pos) == "string" then
    byte_pos = Offset.pos2byte (pos)
  elseif type (pos) == "table" then
    byte_pos = Offset.pos2byte (pos)
  else
    byte_pos = Offset.curs2byte ()
  end

  if X_fn () == 1 and not v_bytes[byte_pos] then
    return nil
  end

  for _, r in ipairs (R_fn ()) do
    if byte_pos >= r.A and byte_pos <= r.B then
      return r
    end
  end

  return nil
end

-- Return the nearest region at position.
function M.nearest_region (pos)
  local regions = R_fn ()
  if #regions == 0 then
    return nil
  end

  local byte_pos
  if pos == nil then
    byte_pos = Offset.curs2byte ()
  elseif type (pos) == "number" then
    byte_pos = pos
  elseif type (pos) == "string" then
    byte_pos = Offset.pos2byte (pos)
  elseif type (pos) == "table" then
    byte_pos = Offset.pos2byte (pos)
  else
    byte_pos = Offset.curs2byte ()
  end

  -- Before first region
  if byte_pos <= regions[1].A then
    return regions[1]
  end

  -- After last region
  if byte_pos >= regions[#regions].B then
    return regions[#regions]
  end

  -- Between regions
  for _, r in ipairs (regions) do
    if byte_pos <= r.B then
      return r
    end
  end

  return regions[#regions]
end

-- Reset index to current region, 0, or max - 1.
function M.reset_index ()
  local regions = R_fn ()
  if #regions == 0 then
    v.index = -1
    return
  end

  local r = M.region_at_pos ()
  if r and not vim.tbl_isempty (r) then
    v.index = r.index
  elseif vim.fn.line (".") >= regions[#regions].L then
    v.index = #regions - 1
  else
    v.index = 0
  end
end

-- Check if a region has overlapping regions.
function M.overlapping_regions (R)
  if not R then
    return false
  end
  for b = R.A, R.B do
    if v_bytes[b] and v_bytes[b] > 1 then
      return true
    end
  end
  return false
end

-- ===========================================================================
-- Update and select
-- ===========================================================================

-- Update regions and select region at position, index or id.
function M.update_and_select_region (arg)
  if v.merge == 1 then
    v.merge = 0
    return M.merge_regions ()
  end

  M.remove_highlight ()
  M.reset_byte_map (false)
  M.reset_vars ()
  M.update_indices ()
  M.update_regions ()

  local nR = #R_fn ()
  if nR == 0 then
    return nil
  end

  if Config.get ("reselect_first") == 0 then
    if v.restore_index ~= nil then
      local i = v.restore_index >= nR and (nR - 1) or v.restore_index
      local R = M.select_region (i)
      v.restore_index = nil
      return R
    elseif arg then
      if type (arg) ~= "table" or arg.index == nil then
        -- Treat as position
        return M.select_region_at_pos (arg)
      elseif arg.index then
        local i = arg.index >= nR and (nR - 1) or arg.index
        return M.select_region (i)
      elseif arg.id then
        -- Find region with id
        for _, r in ipairs (R_fn ()) do
          if r.id == arg.id then
            return M.select_region (r.index)
          end
        end
      end
    else
      return M.select_region_at_pos (".")
    end
  else
    return M.select_region (0)
  end

  return nil
end

-- Update only the bytes map, skipping region update.
function M.update_map_and_select_region (pos)
  if v.find_all_overlap == 1 then
    v.find_all_overlap = 0
    return M.merge_regions ()
  end

  M.reset_vars ()
  M.update_indices ()
  M.reset_byte_map (true)
  M.update_highlight ()

  local target = pos or "."
  return M.select_region_at_pos (target)
end

-- ===========================================================================
-- Region management
-- ===========================================================================

-- Erase all regions.
function M.erase_regions ()
  M.remove_highlight ()
  V.regions = {}
  v_regions = V.regions
  V.bytes = {}
  v_bytes = V.bytes
  v.index = -1
end

-- Store a copy of the current regions.
function M.backup_regions ()
  local tick = vim.fn.undotree ().seq_cur
  -- Access backup from buffer variable
  local backup = vim.b.VM_Backup or { ticks = {}, last = nil }
  local index = -1
  for i, t in ipairs (backup.ticks) do
    if t == backup.last then
      index = i
    end
  end

  if index < #backup.ticks then
    backup.ticks = vim.list_slice (backup.ticks, 1, index)
  end

  table.insert (backup.ticks, tick)

  -- Deep copy regions
  local regions_copy = vim.deepcopy (R_fn ())
  backup[tick] = { regions = regions_copy, X = X_fn () }
  backup.last = tick
  vim.b.VM_Backup = backup
end

-- Create a backup of last set of regions.
function M.backup_last_regions ()
  vim.b.VM_LastBackup = {
    extend = vim.g.Vm and vim.g.Vm.extend_mode or 0,
    regions = vim.tbl_map (function (val)
      return { A = val.A, B = val.B }
    end, vim.deepcopy (R_fn ())),
    search = v.search,
    index = v.index,
  }
  v.direction = 1
end

-- Collapse regions to cursors and turn off extend mode.
function M.collapse_regions ()
  M.reset_byte_map (false)

  for _, r in ipairs (R_fn ()) do
    local col = r.dir == 1 and r.a or r.b
    r:update_cursor ({ r.l, col })
  end

  vim.g.Vm = vim.g.Vm or {}
  vim.g.Vm.extend_mode = 0
  M.update_highlight ()
end

-- ===========================================================================
-- Byte map and variables
-- ===========================================================================

-- Reset byte map for all regions.
function M.reset_byte_map (update)
  V.bytes = {}
  v_bytes = V.bytes

  if update == 1 then
    for _, r in ipairs (M.active_regions ()) do
      if r.update_bytes_map then
        r:update_bytes_map ()
      end
    end
  end
end

-- Reset variables during final regions update.
function M.reset_vars ()
  if v.eco == 0 and v.auto == 0 then
    return
  end

  v.auto = 0
  v.eco = 0
  v.no_search = 0
end

-- Adjust region indices.
function M.update_indices (from_index)
  local regions = R_fn ()
  if from_index then
    local i = from_index
    for j = from_index + 1, #regions do
      regions[j].index = i
      i = i + 1
    end
    return
  end

  for i, r in ipairs (regions) do
    r.index = i - 1 -- 0-based index
  end
end

-- ===========================================================================
-- Merging regions
-- ===========================================================================

-- Merge overlapping cursors.
function M.merge_cursors ()
  local ids_to_remove = {}
  local last_A = 0

  -- We only check offset r.A, since for cursors r.A == r.B
  for _, r in ipairs (R_fn ()) do
    if r.A == last_A then
      table.insert (ids_to_remove, r.id)
    end
    last_A = r.A
  end

  M.remove_regions_by_id (ids_to_remove)
  local pos = { vim.fn.line ("."), vim.fn.col (".") }
  return M.update_and_select_region (pos)
end

-- Merge overlapping regions.
function M.merge_regions ()
  local regions = R_fn ()
  if #regions == 0 then
    return {}
  end
  if X_fn () == 0 then
    return M.merge_cursors ()
  end

  v.eco = 1
  local pos = { vim.fn.line ("."), vim.fn.col (".") }
  M.rebuild_from_map (v_bytes)
  return M.update_map_and_select_region (pos)
end

-- Merge temporary and primary regions maps.
function M.merge_maps (map)
  for b, count in pairs (map) do
    local num_b = tonumber (b) or b
    v_bytes[num_b] = (v_bytes[num_b] or 0) + count
  end

  if vim.tbl_isempty (v_bytes) then
    return {}
  end

  local pos = { vim.fn.line ("."), vim.fn.col (".") }
  M.rebuild_from_map (v_bytes)
  return M.update_map_and_select_region (pos)
end

-- Subtract temporary map from primary region map.
function M.subtract_maps (map)
  for b, _ in pairs (map) do
    local num_b = tonumber (b) or b
    v_bytes[num_b] = nil
  end
  return M.merge_regions ()
end

-- Rebuild regions from bytes map.
function M.rebuild_from_map (map, range)
  local bys = {}
  for key, _ in pairs (map) do
    table.insert (bys, tonumber (key))
  end
  table.sort (bys)

  -- Filter by range if provided
  if range and #range >= 2 then
    local start = range[1]
    local end_ = range[2]
    bys = vim.tbl_filter (function (b)
      return b >= start and b <= end_
    end, bys)
  end

  if #bys == 0 then
    return
  end

  local A = bys[1]
  local B = bys[1]

  M.erase_regions ()

  for i = 2, #bys do
    local b = bys[i]
    if b == B + 1 then
      -- Consecutive byte, extend region
      B = b
    else
      -- Gap found, create region
      Region.new (0, A, B)
      A = b
      B = b
    end
  end

  -- Add final region
  Region.new (0, A, B)
end

-- Remove a list of regions by id.
function M.remove_regions_by_id (ids)
  for _, id in ipairs (ids) do
    local r = M.region_with_id (id)
    if r and r.remove then
      r:remove ()
    end
  end
end

-- Find region with a given id.
function M.region_with_id (id)
  for _, r in ipairs (R_fn ()) do
    if r.id == id then
      return r
    end
  end
  return nil
end

-- Remove last region and reselect the previous one.
function M.remove_last_region (target_id)
  local id = target_id or (v.IDs_list[#v.IDs_list] or nil)
  if not id then
    return nil
  end

  for _, r in ipairs (R_fn ()) do
    if r.id == id then
      if r.clear then
        r:clear ()
      end
      break
    end
  end

  -- If should_quit, return nil (reset)
  if #R_fn () == 0 then
    return nil
  end

  -- Reselect previous region
  local idx
  if target_id then
    local r = M.region_with_id (target_id)
    idx = r and (r.index > 0 and r.index - 1 or 0) or 0
  else
    idx = v.index
  end

  return M.select_region (idx)
end

-- ===========================================================================
-- Utility functions
-- ===========================================================================

-- Reorder regions so that their byte offsets are consecutive.
function M.reorder_regions ()
  local regions = R_fn ()
  local As = {}
  for _, r in ipairs (regions) do
    table.insert (As, r.A)
  end
  table.sort (As)

  local new_regions = {}
  local remaining_As = vim.deepcopy (As)

  while #remaining_As > 0 do
    for _, r in ipairs (regions) do
      if r.A == remaining_As[1] then
        table.insert (new_regions, r)
        table.remove (remaining_As, 1)
        break
      end
    end
  end

  V.regions = new_regions
  v_regions = V.regions
  M.update_indices ()
  M.reset_index ()
end

-- Remove all regions in each line, except the first one.
function M.one_region_per_line ()
  local new_regions = {}
  local lines = {}

  for _, r in ipairs (R_fn ()) do
    if vim.fn.index (lines, r.l) < 0 then
      table.insert (new_regions, r)
      table.insert (lines, r.l)
    end
  end

  M.erase_regions ()
  V.regions = new_regions
  v_regions = V.regions
  M.update_indices ()
end

-- Return a list with all regions' contents.
function M.regions_text ()
  local texts = {}
  for _, r in ipairs (M.active_regions ()) do
    table.insert (texts, r.txt or "")
  end
  return texts
end

-- Check if multiline must be enabled.
function M.check_multiline (region)
  if v.multiline == 0 then
    local regions_to_check
    if region and type(region) == "table" then
      regions_to_check = { region }
    else
      regions_to_check = R_fn ()
    end
    for _, r in ipairs (regions_to_check) do
      if r.h and r.h > 0 then
        v.multiline = 1
        break
      end
    end
  end
end

-- Merge overlapping regions.
function M.merge_overlapping (R)
  -- Simple implementation: just return the region for now
  -- Full implementation would merge overlapping regions
  return R
end

-- Find lines with regions.
function M.lines_with_regions (reverse, specific_line)
  local lines = {}

  for _, r in ipairs (R_fn ()) do
    if specific_line and r.l ~= specific_line then
      goto continue
    end

    lines[r.l] = lines[r.l] or {}
    table.insert (lines[r.l], r.index)

    ::continue::
  end

  for line, indices in pairs (lines) do
    if #indices > 1 then
      if reverse then
        table.sort (indices, function (a, b)
          return a > b
        end)
      else
        table.sort (indices, function (a, b)
          return a < b
        end)
      end
    end
  end

  return lines
end

-- Update the patterns for the appropriate regions.
function M.update_region_patterns (pat)
  for _, r in ipairs (R_fn ()) do
    if r.pat then
      if r.pat:find (pat) or pat:find (r.pat) then
        r.pat = pat
      end
    end
  end
end

return M
