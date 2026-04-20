-- lua/visual-multi/search.lua
-- Search class for visual-multi
-- Manages search patterns, registers, and pattern updates

local M = {}

-- Module-level references, populated by M.init()
local State
local Global
local Config
local V    -- b:VM_Selection (State buffer state)
local v    -- V.vars (plugin variables)
local R_fn -- returns V.regions

-- Initialize module with buffer state
function M.init()
  State = require('visual-multi.state')
  Global = require('visual-multi.global')
  Config = require('visual-multi.config')

  V = State.get()
  v = V.vars
  R_fn = function()
    return V.regions
  end

  -- Ensure search is a table (list of patterns)
  if type(v.search) ~= 'table' then
    v.search = {}
  end

  return M
end

-- ===========================================================================
-- Search pattern management
-- ===========================================================================

-- Escape special characters for use in a search pattern.
-- Equivalent to s:Search.escape_pattern(t) in VimScript.
function M.escape_pattern(text)
  local escaped = vim.fn.escape(text, '\\/.*$^~[]')
  return vim.fn.substitute(escaped, '\n', '\\n', 'g')
end

-- Local helper: check if pattern exists in search list
local function pattern_exists(pat)
  for _, p in ipairs(v.search) do
    if p == pat then return true end
  end
  return false
end

-- Local helper: update search patterns and the @/ register.
-- Equivalent to s:update_search(p) in VimScript.
local function update_search(pat)
  if v.no_search then return end

  -- Add pattern if not already in list
  if pat and pat ~= '' and not pattern_exists(pat) then
    table.insert(v.search, 1, pat)
  end

  if v.eco == 1 then
    -- Eco mode: set @/ to first pattern only
    if #v.search > 0 then
      vim.fn.setreg('/', v.search[1])
    end
  else
    M.join()
  end
end

-- Get a search pattern from a register.
-- Equivalent to s:Search.get_pattern(register) in VimScript.
function M.get_pattern(register)
  local text = vim.fn.getreg(register)
  local t = M.escape_pattern(text)
  local pat = v.whole_word and ('\\<' .. t .. '\\>') or t

  -- If whole word, ensure the pattern can actually be found
  local found = vim.fn.search(pat, 'ncw')
  if found == 0 then
    pat = t
  end

  return pat
end

-- Add a new search pattern.
-- Equivalent to s:Search.add(...) in VimScript.
function M.add(...)
  local pat
  if select('#', ...) > 0 then
    pat = select(1, ...)
  else
    pat = M.get_pattern(v.def_reg or '"')
  end
  update_search(pat)
end

-- Add a new search pattern, only if no pattern is set.
-- Equivalent to s:Search.add_if_empty(...) in VimScript.
function M.add_if_empty(...)
  if #v.search == 0 then
    if select('#', ...) > 0 then
      M.add(select(1, ...))
    else
      local regions = R_fn()
      if regions[v.index + 1] then
        M.add(regions[v.index + 1].pat)
      end
    end
  end
end

-- Ensure there is an active search pattern.
-- Equivalent to s:Search.ensure_is_set(...) in VimScript.
function M.ensure_is_set(...)
  if #v.search == 0 then
    local regions = R_fn()
    if #regions == 0 or not regions[1] or (regions[1].txt and regions[1].txt == '') then
      M.get_slash_reg()
    else
      M.add(M.escape_pattern(regions[1].txt))
    end
  end
end

-- Get a new search pattern from the selected region, with a fallback.
-- Equivalent to s:Search.get_from_region() in VimScript.
function M.get_from_region()
  local r = Global.region_at_pos()
  if r and not vim.tbl_isempty(r) then
    local pat = M.escape_pattern(r.txt)
    update_search(pat)
    return
  end

  -- Fallback to first region.txt or @/, if no active search
  if #v.search == 0 then
    M.ensure_is_set()
  end
end

-- Get pattern from current "/" register. Use backup register if empty.
-- Equivalent to s:Search.get_slash_reg(...) in VimScript.
function M.get_slash_reg(...)
  if select('#', ...) > 0 then
    vim.fn.setreg('/', select(1, ...))
  end

  local slash = vim.fn.getreg('/')
  -- Remove \%V (visual-only marker) from pattern
  slash = vim.fn.substitute(slash, '\\%V', '', 'g')
  update_search(slash)

  if #v.search == 0 and v.oldsearch then
    local old = vim.fn.substitute(v.oldsearch[1] or v.oldsearch[0] or '', '\\%V', '', 'g')
    update_search(old)
  end
end

-- Join current patterns into the @/ register.
-- Equivalent to s:Search.join(...) in VimScript.
function M.join(...)
  if select('#', ...) > 0 then
    v.search = select(1, ...)
  end
  vim.fn.setreg('/', table.concat(v.search, '\\|'))
end

-- Update the search patterns if the active search isn't listed.
-- Equivalent to s:Search.update_patterns(...) in VimScript.
function M.update_patterns(...)
  local current
  if select('#', ...) > 0 then
    current = { select(1, ...) }
  else
    local slash = vim.fn.getreg('/')
    current = vim.fn.split(slash, '\\|')
  end

  for _, p in ipairs(current) do
    if vim.fn.index(v.search, p) >= 0 then
      return
    end
  end

  if select('#', ...) > 0 then
    M.get_from_region()
  else
    M.get_slash_reg()
  end
end

-- ===========================================================================
-- Validation and rewrite
-- ===========================================================================

-- Check whether the current search is valid. If not, clear invalid patterns.
-- Equivalent to s:Search.validate() in VimScript.
function M.validate()
  if v.eco == 1 or #v.search == 0 then
    return false
  end

  M.join()

  -- Pattern found, ok
  if vim.fn.search(vim.fn.getreg('/'), 'cnw') > 0 then
    return true
  end

  -- Remove invalid patterns one by one
  local i = 1
  while i <= #v.search do
    local p = v.search[i]
    if vim.fn.search(vim.fn.getreg('/'), 'cnw') == 0 then
      table.remove(v.search, i)
    else
      i = i + 1
    end
  end

  M.join()
  return true
end

-- Local helper: check if a pattern has been rewritten by selected text.
-- Equivalent to s:pattern_rewritten(t, i) in VimScript.
local function pattern_rewritten(text, index)
  local slash = vim.fn.getreg('/')
  if slash == '' then return false end

  local old_pat = v.search[index]
  if text:find(old_pat, 1, true) or old_pat:find(text, 1, true) then
    local old = old_pat
    v.search[index] = text
    if Global and Global.update_region_patterns then
      Global.update_region_patterns(text)
    end
    M.join()
    if State.Funcs and State.Funcs.msg then
      State.Funcs.msg('Pattern updated:   [' .. old .. ']  ->  [' .. text .. ']\n')
    end
    return true
  end
  return false
end

-- Rewrite patterns if substrings of the selected text.
-- Equivalent to s:Search.rewrite(last) in VimScript.
function M.rewrite(is_last)
  local r = Global.region_at_pos()
  if not r or vim.tbl_isempty(r) then return end

  local t = M.escape_pattern(r.txt)

  if is_last then
    -- Add a new pattern if not found among existing ones
    if not pattern_rewritten(t, 1) then
      M.add(t)
    end
  else
    -- Rewrite if found among any pattern, else do nothing
    for i = 1, #v.search do
      if pattern_rewritten(t, i) then
        break
      end
    end
  end
end

-- ===========================================================================
-- Search menu and options
-- ===========================================================================

-- Remove a search pattern, and optionally its associated regions.
-- Equivalent to s:Search.remove(also_regions) in VimScript.
function M.remove(also_regions)
  local pats = v.search

  if #pats == 0 then
    if State.Funcs and State.Funcs.msg then
      State.Funcs.msg('No search patterns yet.')
    end
    return
  end

  if State.Funcs and State.Funcs.msg then
    State.Funcs.msg('Which index? ' .. vim.inspect(v.search))
  end

  local c = vim.fn.nr2char(vim.fn.getchar())
  if c == vim.fn.nr2char(27) then -- <Esc>
    if State.Funcs and State.Funcs.msg then
      State.Funcs.msg('\tCanceled.\n')
    end
    return
  end

  local i = tonumber(c)
  if not i or i < 0 or i >= #pats then
    if State.Funcs and State.Funcs.msg then
      State.Funcs.msg('\tWrong index\n')
    end
    return
  end

  if State.Funcs and State.Funcs.msg then
    State.Funcs.msg('\n')
  end

  local pat = pats[i + 1] -- Lua is 1-indexed
  table.remove(pats, i + 1)

  -- Update @/ register
  if #pats == 0 then
    vim.fn.setreg('/', '')
  else
    vim.fn.setreg('/', pats[1])
  end

  if also_regions then
    local regions = R_fn()
    local removed = 0
    for j = #regions, 1, -1 do
      if regions[j].pat == pat then
        if regions[j].remove then
          regions[j]:remove()
        end
        removed = removed + 1
      end
    end

    if removed > 0 and Global and Global.update_and_select_region then
      Global.update_and_select_region()
    end
  end
end

-- Cycle case settings (smartcase -> case sensitive -> ignorecase -> smartcase).
-- Equivalent to s:Search.case() in VimScript.
function M.case()
  if vim.o.smartcase then
    -- smartcase -> case sensitive
    vim.o.smartcase = false
    vim.o.ignorecase = false
    if State.Funcs and State.Funcs.msg then
      State.Funcs.msg('Search ->   case sensitive')
    end
  elseif not vim.o.ignorecase then
    -- case sensitive -> ignorecase
    vim.o.ignorecase = true
    if State.Funcs and State.Funcs.msg then
      State.Funcs.msg('Search ->   ignore case')
    end
  else
    -- ignorecase -> smartcase
    vim.o.smartcase = true
    vim.o.ignorecase = true
    if State.Funcs and State.Funcs.msg then
      State.Funcs.msg('Search ->   smartcase')
    end
  end
end

-- Display search menu and handle user input.
-- Equivalent to s:Search.menu() in VimScript.
function M.menu()
  local lines = {
    '1 - Rewrite Last Search',
    '2 - Rewrite All Search',
    '3 - Read From Search',
    '4 - Add To Search',
    '5 - Remove Search',
    '6 - Remove Search Regions',
    'Enter an option: ',
  }
  if State.Funcs and State.Funcs.msg then
    State.Funcs.msg(table.concat(lines, '\n'))
  end

  local c = vim.fn.nr2char(vim.fn.getchar())

  if c == '1' then
    M.rewrite(true)
  elseif c == '2' then
    M.rewrite(false)
  elseif c == '3' then
    M.get_slash_reg()
  elseif c == '4' then
    M.get_from_region()
  elseif c == '5' then
    M.remove(false)
  elseif c == '6' then
    M.remove(true)
  end

  vim.fn.feedkeys('\r', 'n')
end

return M
