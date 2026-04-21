-- lua/visual-multi/region.lua
-- Region class module - manages multi-cursor region positions, content, and highlighting

local M = {}

-- Module-level references, populated by M.init()
local state
local config
local vars -- state.vars
local regions -- state.regions
local funcs -- state.Funcs

-- Lambda equivalent: check if in extend mode
local function is_extend_mode ()
  return vars and vars.extend_mode == 1
end

function M.init ()
  -- Always use State.get() to get the correct reference
  state = require ("visual-multi.state").get ()
  vars = state.vars
  regions = state.regions
  funcs = state.Funcs
  config = require ("visual-multi.config")
end

-- Fix positions at end of line.
-- Equivalent to s:fix_pos(r) in VimScript.
local function fix_pos (r)
  local eol = vim.fn.col ({ r.l, "$" }) - 1
  local eoL = vim.fn.col ({ r.L, "$" }) - 1
  local multiline = config.get ("multiline") == 1 or vars.multiline == 1

  if not multiline then
    if r.a > eol then
      r.a = eol > 0 and eol or 1
    end
    if r.b > eoL then
      r.b = eoL > 0 and eoL or 1
    end
  else
    if r.a > eol + 1 then
      r.a = eol > 0 and (eol + 1) or 1
    end
    if r.b > eoL + 1 then
      r.b = eoL > 0 and (eoL + 1) or 1
    end
  end
end

-- Initialize region variables from cursor, offsets, or positions.
-- Equivalent to s:region_vars(r, cursor, ...) in VimScript.
--
-- r       : region table to populate
-- cursor  : if true, use current cursor position
-- l, L, a, b : optional explicit line/column arguments
local function region_vars (r, cursor, l, L, a, b)
  if l == nil then
    -- No extra arguments
    if cursor then
      --/////////// CURSOR ////////////
      r.l = vim.fn.line (".")
      r.L = r.l
      r.a = vim.fn.col (".")
      r.b = r.a

      fix_pos (r)

      r.txt = r:char () -- character under cursor in extend mode
      r.pat = M.pattern (r)

      r.A = r:A_ () -- byte offset a
      r.B = is_extend_mode () and r:B_ () or r.A -- byte offset b
      r.w = r.B - r.A + 1 -- width
      r.h = r.L - r.l -- height
      r.k = r.dir == 1 and r.a or r.b -- anchor
      r.K = r.dir == 1 and r.A or r.B -- anchor offset
    else
      --/////////// REGION ////////////
      r.l = vim.fn.line ("'[") -- starting line
      r.L = vim.fn.line ("']") -- ending line
      r.a = vim.fn.col ("'[") -- begin
      r.b = vim.fn.col ("']") -- end

      fix_pos (r)

      r.txt = vim.fn.getreg (vars.def_reg or "\"") -- text content
      r.pat = M.pattern (r) -- associated search pattern

      r.A = r:A_ () -- byte offset a
      r.B = r:B_ () -- byte offset b
      r.w = r.B - r.A + 1 -- width
      r.h = r.L - r.l -- height
      r.k = r.dir == 1 and r.a or r.b -- anchor
      r.K = r.dir == 1 and r.A or r.B -- anchor offset
    end
  else
    --///////// FROM ARGS ///////////
    r.l = l
    r.L = L
    r.a = a
    r.b = b

    fix_pos (r)
    r:update_content ()

    r.A = r:A_ () -- byte offset a
    r.B = r:B_ () -- byte offset b
    r.w = r.B - r.A + 1 -- width
    r.h = r.L - r.l -- height
    r.k = r.dir == 1 and r.a or r.b -- anchor
    r.K = r.dir == 1 and r.A or r.B -- anchor offset
  end

  -- used to keep the column during vertical cursors movement
  r.vcol = 0 -- vertical column
  r.ntabs = 0 -- number of tabs before cursor if noexpandtab
  r.bdiff = 0 -- bytes diff if multibyte characters before cursor
end

-- Find the search pattern associated with the region.
-- Equivalent to s:pattern(r) in VimScript.
function M.pattern (r)
  local search = vars.search
  if not search or (type (search) ~= "table" and search == "") then
    -- Escape pattern if needed (placeholder - use Search module when available)
    return r.txt or ""
  end

  -- If vars.search is a table, check if region text matches any pattern
  if type (search) == "table" then
    for _, p in ipairs (search) do
      if r.txt and vim.fn.match (r.txt, p) >= 0 then
        return p
      end
    end
  end

  -- Return current search pattern in regex mode
  if not r.pat then
    return vars.using_regex and (type (search) == "table" and search[1] or search) or ""
  end

  -- Return current pattern if one is present (in cursor mode text is empty)
  return r.pat
end

-- Create a new region from marks, offsets, or positions.
-- cursor  : boolean - if true, region is at current cursor position
-- ...     : either two byte offsets (A, B) or four positions (l, L, a, b)
function M.new (cursor, ...)
  local nargs = select ("#", ...)
  local l, L, a, b

  if nargs > 0 then
    if nargs == 2 then
      -- making a new region from offsets
      local A = select (1, ...)
      local B = select (2, ...)
      l = vim.fn.byte2line (A)
      a = A - vim.fn.line2byte (l) + 1
      L = vim.fn.byte2line (B)
      b = B - vim.fn.line2byte (L) + 1
    else
      -- making a new region from positions
      l = select (1, ...)
      L = select (2, ...)
      a = select (3, ...)
      b = select (4, ...)
    end
  end

  -- cursor or region?
  if nargs == 0 then
    cursor = cursor or false
  else
    cursor = cursor or (a == b and l == L)
  end

  -- Create the region
  local R
  if nargs == 0 and not cursor then
    -- Will be created from marks '[ and ']
    R = M.Region.new (true)
  elseif nargs == 0 then
    R = M.Region.new (cursor)
  else
    R = M.Region.new (false, l, L, a, b)
  end

  -- Update region index and ID count
  vars.index = R.index
  vars.ID = vars.ID + 1

  -- Keep regions list ordered
  if #regions == 0 or regions[vars.index].A < R.A then
    table.insert (regions, R)
  else
    local i = 1
    for _, r in ipairs (regions) do
      if r.A > R.A then
        table.insert (regions, i, R)
        break
      end
      i = i + 1
    end
    vars.index = i - 1 -- Convert to 0-based index
    -- update_indices placeholder (from Global module)
    -- if funcs and funcs.update_indices then funcs.update_indices(i) end
  end

  -- update_cursor_highlight placeholder (from Global module)
  -- if funcs and funcs.update_cursor_highlight then funcs.update_cursor_highlight() end

  return R
end

-- Region class
M.Region = {}

-- Create a new region instance.
-- cursor  : if true, initialize from current cursor position
-- l, L, a, b : optional explicit position arguments
function M.Region.new (cursor, ...)
  local R = {}

  -- Copy all methods from the prototype
  for k, v in pairs (M.Region) do
    R[k] = v
  end

  R.index = #regions
  R.dir = vars.direction
  R.id = vars.ID + 1

  R.matches = { region = {}, cursor = 0 }

  if select ("#", ...) == 0 then
    --/////// FROM MAPPINGS ///////
    region_vars (R, cursor)
  else
    --///////// FROM ARGS ///////////
    local l, L, a, b = select (1, ...)
    region_vars (R, cursor, l, L, a, b)
  end

  table.insert (vars.IDs_list, R.id)

  if not vars.eco then
    R:highlight ()
  end
  R:update_bytes_map ()

  return R
end

-- Check if region is empty (zero width).
function M.Region:empty ()
  return self.A == self.B
end

-- Calculate byte offset A from line and column.
function M.Region:A_ ()
  return vim.fn.line2byte (self.l) + self.a - 1
end

-- Calculate byte offset B from line and column.
-- Last byte of the last character in the region.
-- This will be greater than the column if character is multibyte.
function M.Region:B_ ()
  local bytes = 1
  if self.txt and #self.txt > 0 then
    bytes = vim.fn.strlen (self.txt:sub (-1))
  end
  return vim.fn.line2byte (self.L) + self.b + bytes - 2
end

-- Return the line where the active cursor/head is located.
function M.Region:cur_ln ()
  return self.dir == 1 and self.L or self.l
end

-- Return the column where the active cursor/head is located.
function M.Region:cur_col ()
  return self.dir == 1 and self.b or self.a
end

-- Return the byte offset of the active cursor/head.
function M.Region:cur_Col ()
  return self:cur_col () == self.b and self.B or self.A
end

-- Return the character under the active head.
-- Returns '' in cursor mode.
function M.Region:char ()
  if not is_extend_mode () then
    return ""
  end
  return funcs and funcs.char_at_pos (self.l, self:cur_col ())
    or M.char_at_pos (self.l, self:cur_col ())
end

-- Fallback char_at_pos when funcs module is not available.
-- Equivalent to s:F.char_at_pos(l, c) in VimScript.
function M.char_at_pos (lnum, col)
  return vim.fn.matchstr (vim.fn.getline (lnum), "\\%" .. col .. "c.")
end

-- Shift region offsets by integer values.
-- x, y : shift amounts for A and B respectively.
function M.Region:shift (x, y)
  local r = self

  r.A = r.A + x
  r.B = r.B + y

  r.l = vim.fn.byte2line (r.A)
  r.L = vim.fn.byte2line (r.B)
  r.a = r.A - vim.fn.line2byte (r.l) + 1
  r.b = r.B - vim.fn.line2byte (r.L) + 1

  if not vars.eco then
    r:update ()
  end
  return { r.l, r.L, r.a, r.b }
end

-- Remove a region and its id, then update indices.
function M.Region:remove ()
  self:remove_highlight ()
  table.remove (regions, self.index + 1) -- Lua is 1-indexed

  -- Remove id from IDs_list
  for i, id in ipairs (vars.IDs_list) do
    if id == self.id then
      table.remove (vars.IDs_list, i)
      break
    end
  end

  if #regions > 0 then
    -- update_indices placeholder
  else
    vars.index = -1
  end

  if vars.index >= #regions then
    vars.index = #regions - 1
  end
  return self
end

-- Clear the byte map as well, then remove.
function M.Region:clear (...)
  self:remove_from_byte_map (select ("#", ...) > 0)
  return self:remove ()
end

-- Remove a region from the bytes map.
function M.Region:remove_from_byte_map (all)
  if not is_extend_mode () then
    return
  end

  local Bytes = state.bytes
  if all then
    for b = self.A, self.B do
      Bytes[b] = nil
    end
  else
    for b = self.A, self.B do
      if Bytes[b] and Bytes[b] > 1 then
        Bytes[b] = Bytes[b] - 1
      else
        Bytes[b] = nil
      end
    end
  end
end

-- Move cursors, or extend regions by motion.
function M.Region:move (...)
  -- TODO: motion handling requires full motion system
end

-- Set vertical column if motion is j or k, and vcol not previously set.
function M.Region:set_vcol (...)
  -- TODO: requires motion context
end

-- Update region.
function M.Region:update ()
  if is_extend_mode () then
    self:update_region ()
  else
    self:update_cursor ()
  end
end

-- Update cursor vars from position [line, col] or offset.
function M.Region:update_cursor (...)
  local r = self

  if select ("#", ...) > 0 then
    local arg1 = select (1, ...)
    if type (arg1) == "number" then
      r.l = vim.fn.byte2line (arg1)
      r.a = arg1 - vim.fn.line2byte (r.l) + 1
    elseif type (arg1) == "table" then
      r.l = arg1[1]
      r.a = arg1[2]
    end
  end

  fix_pos (r)
  self:update_vars ()
end

-- Update cursor to current position.
function M.Region:update_cursor_pos ()
  local pos = vim.fn.getpos (".")
  self.l = pos[2]
  self.a = pos[3]
  fix_pos (self)
  self:update_vars ()
end

-- Get region content if in extend mode.
function M.Region:update_content ()
  local r = self
  vim.fn.cursor (r.l, r.a)
  vim.cmd ("keepjumps normal! m[")
  vim.fn.cursor (r.L, r.b + 1)
  vim.cmd ("silent keepjumps normal! m]`[y`]")
  r.txt = vim.fn.getreg (vars.def_reg or "\"")

  local multiline = config.get ("multiline") == 1 or vars.multiline == 1
  if multiline and r.b == vim.fn.col ({ r.L, "$" }) then
    r.txt = r.txt .. "\n"
  else
    -- If last character is multibyte, it won't be yanked, add it manually
    local lastchar = M.char_at_pos (r.L, r.b)
    if vim.fn.strlen (lastchar) > 1 then
      r.txt = r.txt .. lastchar
    end
  end
  r.pat = M.pattern (r)
end

-- Update the main region positions.
function M.Region:update_region (...)
  local r = self

  if select ("#", ...) == 4 then
    r.l = select (1, ...)
    r.L = select (2, ...)
    r.a = select (3, ...)
    r.b = select (4, ...)
  end

  fix_pos (r)
  r:update_content ()
  r:update_vars ()
end

-- Update the rest of the region variables.
function M.Region:update_vars ()
  local r = self
  vars.index = r.index

  ----------- cursor mode ----------------------------
  if not is_extend_mode () then
    r.L = r.l
    r.b = r.a
    r.A = r:A_ ()
    r.B = r.A
    r.k = r.a
    r.K = r.A
    r.w = 0
    r.h = 0
    r.txt = ""
    r.pat = M.pattern (r)

    ----------- extend mode ----------------------------
  else
    r.A = r:A_ ()
    r.B = r:B_ ()
    r.w = r.B - r.A + 1
    r.h = r.L - r.l
    r.k = r.dir == 1 and r.a or r.b
    r.K = r.dir == 1 and r.A or r.B

    r:update_bytes_map ()
  end
end

-- Create the highlight entries.
function M.Region:highlight ()
  if vars.eco then
    return
  end

  local R = self

  -------------------- cursor mode ----------------------------
  if not is_extend_mode () then
    if R.a == 1 then
      R.matches.cursor = vim.fn.matchadd ("MultiCursor", "\\%" .. R.l .. "l\\%1c")
    else
      R.matches.cursor = vim.fn.matchaddpos ("MultiCursor", { { R.l, R.a } }, 40)
    end
    return
  end

  -------------------- extend mode ----------------------------
  local max = R.L - R.l
  local region = {}
  local cursor = { R:cur_ln (), R:cur_col () }

  -- skip the for loop if single line
  if max == 0 then
    region = { { R.l, R.a, vim.fn.strlen (vim.fn.getline (R.l)) } }
  else
    max = max + 1
  end

  -- define highlight
  for n = 0, max - 1 do
    local line
    if n == 0 then
      line = { R.l, R.a, vim.fn.strlen (vim.fn.getline (R.l)) }
    elseif n < max - 1 then
      line = { R.l + n }
    else
      line = { R.L, 1, R.b }
    end
    table.insert (region, line)
  end

  -- build a list of highlight entries, one for each possible line
  for _, line in ipairs (region) do
    table.insert (R.matches.region, vim.fn.matchaddpos ("VM_Extend", { line }, 30))
  end
  R.matches.cursor = vim.fn.matchaddpos ("MultiCursor", { cursor }, 40)
end

-- Remove the highlight entries.
function M.Region:remove_highlight ()
  local r = self.matches.region
  local c = self.matches.cursor

  for _, m in ipairs (r) do
    vim.fn.matchdelete (m)
  end
  vim.fn.matchdelete (c)
end

-- Update the region highlight.
function M.Region:update_highlight ()
  self:remove_highlight ()
  self:highlight ()
end

-- Update bytes map for region.
function M.Region:update_bytes_map ()
  if not is_extend_mode () then
    return
  end

  local Bytes = state.bytes
  for b = self.A, self.B do
    Bytes[b] = (Bytes[b] or 0) + 1
  end
end

return M
