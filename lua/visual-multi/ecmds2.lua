-- lua/visual-multi/ecmds2.lua
-- Ecmds2 module - edit commands #2 (special commands)
-- Equivalent to autoload/vm/ecmds2.vim

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

-- Edit object
local Edit = {}

function M.init()
  State = require('visual-multi.state')
  Global = require('visual-multi.global')
  Funcs = require('visual-multi.funcs')

  V = State.get()
  v = V.vars
  v_regions = V.regions

  R_fn = function() return v_regions end
  X_fn = function() return vim.g.Vm and vim.g.Vm.extend_mode or 0 end

  return Edit
end

function M.get_edit()
  return Edit
end

-- ===========================================================================
-- Duplicate
-- ===========================================================================

function Edit.duplicate()
  if not M._min(1) then return end

  Edit.yank('§', true)
  Global.change_mode()
  Edit.paste(true, false, true, '§')
end

-- ===========================================================================
-- Change
-- ===========================================================================

function Edit.change(X, count, reg, smart_case)
  if #R_fn() == 0 then return end
  if not v.direction then
    vim.fn['vm#commands#invert_direction']()
  end
  if smart_case and not v.smart_case_change then
    v.smart_case_change = 1
  end
  if X then
    -- Delete existing region contents and leave the cursors
    local use_reg = reg ~= v.def_reg and reg or '_'
    v.changed_text = Edit.delete(true, use_reg, true, false)
    V.Insert.key('i')
  else
    vim.fn['vm#cursors#operation']('c', count, reg)
  end
end

-- ===========================================================================
-- Non-live edit mode
-- ===========================================================================

function Edit.apply_change()
  V.Insert.auto_end()
  Edit.skip_index = v.index
  Edit.process('normal! .')
  -- Reset index to skip
  Edit.skip_index = -1
end

-- ===========================================================================
-- Special commands
-- ===========================================================================

function Edit.surround()
  if #R_fn() == 0 then return end
  if not X_fn() then
    vim.fn['vm#operators#select'](1, 'iw')
  end

  if not v.direction then
    vim.fn['vm#commands#invert_direction']()
  end
  v.W = Edit.store_widths()
  local reselect = true

  local c = vim.fn.nr2char(vim.fn.getchar())

  if c == '<' or c == 't' then
    reselect = false
    c = Edit.surround_tags()
    if c == '' then
      vim.cmd('redraw')
      vim.cmd('echo')
      return
    end
  end

  local S = vim.g.Vm.maps.surround

  vim.cmd('silent! nunmap <buffer> ' .. S)

  Edit.run_visual(S .. c, true)

  if vim.fn.index({'[', '{', '('}, c) >= 0 then
    for i, _ in ipairs(v.W) do
      v.W[i] = v.W[i] + 3
    end
  else
    for i, _ in ipairs(v.W) do
      v.W[i] = v.W[i] + 1
    end
  end

  if reselect then
    Edit.post_process(1, 0)
  else
    Edit.post_process(0)
  end

  vim.cmd('nmap <silent> <nowait> <buffer> ' .. S .. ' <Plug>(VM-Surround)')
end

function Edit.surround_tags()
  local c = '<'
  print(c)

  while true do
    local ch = vim.fn.getchar()
    if ch == 27 then -- ESC
      return ''
    end
    if ch == vim.fn.char2nr('<BS>') then
      if #c > 1 then
        c = c:sub(1, -2)
      else
        -- No more chars
        return ''
      end
    else
      c = c .. vim.fn.nr2char(ch)
      if ch == 62 or ch == 13 then -- > or CR
        break
      end
    end
    vim.cmd('redraw')
    print(c)
  end

  return c
end

-- ===========================================================================
-- Rotate / Transpose
-- ===========================================================================

function Edit.rotate()
  -- Non-inline transposition
  if not M._min(2) then return end

  Edit.yank('"', true)

  local t = table.remove(vim.g.Vm.registers[v.def_reg], 1)
  table.insert(vim.g.Vm.registers[v.def_reg], t)
  Edit.paste(true, false, true, '"')
end

function Edit.transpose()
  if not M._min(2) then return end
  local rlines = Global.lines_with_regions(0)
  local klines = {}
  for k, _ in pairs(rlines) do
    table.insert(klines, k)
  end
  table.sort(klines)

  -- Check if there is the same nr of regions in each line
  local inline = #klines > 1
  if inline then
    local n = 0
    for _, l in ipairs(klines) do
      local nr = #rlines[l]

      if nr == 1 then
        inline = false
        break
      elseif n == 0 then
        n = nr -- Set required n regions x line
      elseif nr ~= n then
        inline = false
        break
      end
    end
  end

  -- Non-inline transposition
  if not inline then
    return Edit.rotate()
  end

  Edit.yank('"', true)

  -- Inline transpositions
  for _, l in ipairs(klines) do
    local t = table.remove(vim.g.Vm.registers[v.def_reg], rlines[l][#rlines[l]] + 1)
    table.insert(vim.g.Vm.registers[v.def_reg], rlines[l][1] + 1, t)
  end
  Edit.delete(true, '_', false, 0)
  Edit.paste(true, false, true, '"')
end

-- ===========================================================================
-- Align
-- ===========================================================================

function Edit.align()
  if v.multiline then
    return Funcs.msg('Not possible, multiline is enabled.')
  end
  Global.cursor_mode()

  Edit.run_normal('D', {store = '§'})
  local max = 0
  for _, r in ipairs(R_fn()) do
    max = math.max(max, vim.fn.virtcol({r.l, r.a}))
  end
  local reg = vim.g.Vm.registers['§']
  for _, r in ipairs(R_fn()) do
    local spaces = ''
    local L = vim.fn.getline(r.l)
    if L == '' then
      while #spaces < max do
        spaces = spaces .. ' '
      end
      vim.fn.setline(r.l, L:sub(1, r.a - 1) .. spaces .. L:sub(r.a) .. (reg[r.index + 1] or ''))
      r.update_cursor({r.l, r.a + #spaces - 1})
    else
      while #spaces < (max - vim.fn.virtcol({r.l, r.a})) do
        spaces = spaces .. ' '
      end
      vim.fn.setline(r.l, L:sub(1, r.a - 1) .. spaces .. L:sub(r.a) .. (reg[r.index + 1] or ''))
      r.update_cursor({r.l, r.a + #spaces})
    end
  end
  Global.update_and_select_region()
  vim.fn['vm#commands#motion']('l', 1, 0, 0)
end

-- ===========================================================================
-- Shift
-- ===========================================================================

function Edit.shift(dir)
  if not M._min(1) then return end

  Edit.yank('"', true)
  if dir then
    v.dont_move_cursors = 1
    Edit.paste(false, false, true, '"')
  else
    Edit.delete(true, '_', false, 0)
    vim.fn['vm#commands#motion']('h', 1, 0, 0)
    Edit.paste(true, false, true, '"')
  end
end

-- ===========================================================================
-- Insert numbers
-- ===========================================================================

function Edit._numbers(start, step, separator, append)
  local start_num = tonumber(start) or 0
  local step_num = tonumber(step) or 1

  -- Build string from expression
  local text = {}
  for n = 0, #R_fn() - 1 do
    local t
    if append then
      t = separator .. tostring(start_num + step_num * n)
    else
      t = tostring(start_num + step_num * n) .. separator
    end
    table.insert(text, t)
  end

  -- Paste string before/after the cursor/selection
  if X_fn() then
    local new_text = {}
    for i, r in ipairs(R_fn()) do
      if append then
        table.insert(new_text, (r.txt or '') .. text[i])
      else
        table.insert(new_text, text[i] .. (r.txt or ''))
      end
    end
    Edit.replace_regions_with_text(new_text)
  else
    Edit.replace_regions_with_text(text, append)
  end
end

function Edit.numbers(start, app)
  if #R_fn() == 0 then return end

  -- Fill the command line with [count]/default_step
  local x = vim.fn.input('Expression > ', start .. '/1/')

  if x == '' then
    return Funcs.msg('Canceled')
  end

  -- First char must be a digit or a negative sign
  if not x:match('^%d') and not x:match('^%-') then
    return Funcs.msg('Invalid expression')
  end

  -- Evaluate terms of the expression
  -- / is the separator, it must be escaped \/ to be used
  local parts = vim.split(x, '/', true)
  local i = 1
  while i < #parts do
    if parts[i]:sub(-1) == '\\' then
      parts[i] = parts[i]:sub(1, -2) .. '/' .. table.remove(parts, i + 1)
    else
      i = i + 1
    end
  end
  -- Filter empty strings
  local filtered = {}
  for _, p in ipairs(parts) do
    if p ~= '' then
      table.insert(filtered, p)
    end
  end
  parts = filtered
  local n = #parts

  -- True for a number, false for a separator
  local function isNum(s)
    return s:match('^%d') or s:match('^%-?%d')
  end

  if n == 1 then
    Edit._numbers(parts[1], 1, '', app)
  elseif n == 2 then
    if isNum(parts[2]) then
      Edit._numbers(parts[1], parts[2], '', app)
    else
      Edit._numbers(parts[1], 1, parts[2], app)
    end
  elseif n == 3 then
    Edit._numbers(parts[1], parts[2], parts[3], app)
  end
end

-- ===========================================================================
-- Helper
-- ===========================================================================

function M._min(n)
  return X_fn() and #R_fn() >= n
end

return M
