-- lua/visual-multi/funcs.lua
-- Utility functions module - equivalent to autoload/vm/funcs.vim

local M = {}

local state = require('visual-multi.state')
local config = require('visual-multi.config')

-- Initialize module with buffer state reference
function M.init()
  -- Store reference to state module
  M._state = state
  return M
end

-- Convert position to byte offset
-- pos can be: number (offset), list [line, col], or mark string
function M.pos2byte(pos)
  if type(pos) == 'number' then
    return pos
  elseif type(pos) == 'table' then
    return vim.fn.line2byte(pos[0] or pos[1]) + (pos[1] or pos[2]) - 1
  else
    -- mark like '[', ']
    local mark_pos = vim.fn.getpos(pos)
    local line = mark_pos[2]
    local col = math.min(mark_pos[3], vim.fn.col({line, '$'}))
    return vim.fn.line2byte(line) + col - 1
  end
end

-- Return current cursor position as byte offset
function M.curs2byte()
  local pos = vim.fn.getcurpos()
  return vim.fn.line2byte(pos[2]) + pos[3] - 1
end

-- Convert byte offset to position [line, col]
function M.byte2pos(byte)
  local line = vim.fn.byte2line(byte)
  local col = byte - vim.fn.line2byte(line) + 1
  return {line, col}
end

-- Move cursor to byte offset
function M.Cursor(A)
  local ln = vim.fn.byte2line(A)
  local cl = A - vim.fn.line2byte(ln) + 1
  vim.fn.cursor(ln, cl)
  return {ln, cl}
end

-- Get vertical column (curswant)
function M.get_vertcol()
  local curswant = vim.fn.getcurpos()[5]
  if curswant > vim.fn.col('$') then
    vim.fn.cursor(vim.fn.getpos('.')[2], vim.fn.getpos('.')[3])
    curswant = vim.fn.getcurpos()[5]
  end
  return curswant
end

-- Check if no regions exist
function M.no_regions()
  local s = state.get()
  if #s.regions == 0 then
    s.vars.index = -1
    return 1
  end
  return 0
end

-- Get character under cursor
function M.char_under_cursor()
  return vim.fn.matchstr(vim.fn.getline('.'), '\\%' .. vim.fn.col('.') .. 'c.')
end

-- Get character at position
function M.char_at_pos(l, c)
  return vim.fn.matchstr(vim.fn.getline(l), '\\%' .. c .. 'c.')
end

-- Get default register
function M.default_reg()
  return '"'
end

-- Get file size in bytes
function M.size()
  return vim.fn.line2byte(vim.fn.line('$') + 1) - 1
end

-- Get register contents
function M.get_reg(reg)
  reg = reg or config.get('def_reg') or '"'
  return {reg, vim.fn.getreg(reg), vim.fn.getregtype(reg)}
end

-- Get registers 1-9
function M.get_regs_1_9()
  local regs = {}
  for r = 1, 9 do
    table.insert(regs, {r, vim.fn.getreg(tostring(r)), vim.fn.getregtype(tostring(r))})
  end
  return regs
end

-- Set register
function M.set_reg(text)
  local reg = config.get('def_reg') or '"'
  vim.fn.setreg(reg, text, 'v')
end

-- Restore register from backup
function M.restore_reg()
  local s = state.get()
  local r = s.vars.oldreg
  if r then
    vim.fn.setreg(r[1] or r[0], r[2] or r[1], r[3] or r[2])
  end
end

-- Restore all registers
function M.restore_regs()
  M.restore_reg()

  local s = state.get()
  -- Restore regs 1-9
  if s.vars.oldregs_1_9 then
    for _, r in ipairs(s.vars.oldregs_1_9) do
      vim.fn.setreg(r[1] or r[0], r[2] or r[1], r[3] or r[2])
    end
  end

  -- Restore search register
  if s.vars.oldsearch then
    local s_search = s.vars.oldsearch
    vim.fn.setreg('/', s_search[1] or s_search[0], s_search[2] or s_search[1])
  end
end

-- Restore visual marks
function M.restore_visual_marks()
  local s = state.get()
  if s.vars.vmarks then
    vim.fn.setpos("'<", s.vars.vmarks[0] or s.vars.vmarks[1])
    vim.fn.setpos("'>", s.vars.vmarks[1] or s.vars.vmarks[2])
  end
end

-- Find region by ID
function M.region_with_id(id)
  local s = state.get()
  for _, r in ipairs(s.regions) do
    if r.id == id then
      return r
    end
  end
  return nil
end

-- Check if VM should quit (no active regions)
function M.should_quit()
  local s = state.get()
  return #s.regions == 0
end

-- Get syntax at position
function M.syntax(pos)
  local line, col
  if type(pos) == 'table' then
    line = pos[0] or pos[1]
    col = pos[1] or pos[2]
  else
    line = vim.fn.line(pos)
    col = vim.fn.col(pos)
  end
  return vim.fn.synIDattr(vim.fn.synID(line, col, 1), "name")
end

-- Evaluate expression for filtering
function M.get_expr(x)
  local N = #state.get().regions

  -- Replace placeholders
  local result = x
  result = vim.fn.substitute(result, '\\C%r', 's.regions[i]', 'g')
  result = vim.fn.substitute(result, '\\C%l', 'r.l', 'g')
  result = vim.fn.substitute(result, '\\C%L', 'r.L', 'g')
  result = vim.fn.substitute(result, '\\C%a', 'r.a', 'g')
  result = vim.fn.substitute(result, '\\C%b', 'r.b', 'g')
  result = vim.fn.substitute(result, '\\C%w', 'r.w', 'g')
  result = vim.fn.substitute(result, '\\C%h', 'r.h', 'g')
  result = vim.fn.substitute(result, '\\C%t', 'r.txt', 'g')
  result = vim.fn.substitute(result, '\\C%n', 'r.index', 'g')
  result = vim.fn.substitute(result, '\\C%N', tostring(N), 'g')
  result = vim.fn.substitute(result, '\\C%i', 'i', 'g')

  return result
end

-- Message display
function M.msg(text)
  print(text)
end

-- Scroll helper class
M.Scroll = {}

function M.Scroll.get()
  local s = state.get()
  s.vars.scroll = {
    line = vim.fn.winline(),
    col = vim.fn.wincol(),
    topline = vim.fn.line('w0'),
    botline = vim.fn.line('w$'),
  }
end

function M.Scroll.restore()
  local s = state.get()
  if s.vars.scroll and s.vars.restore_scroll then
    -- Attempt to restore scroll position
    local winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_call(winid, function()
      vim.fn.cursor(s.vars.scroll.topline or 1, 1)
      vim.fn.cursor(s.vars.scroll.line or 1, s.vars.scroll.col or 1)
    end)
    s.vars.restore_scroll = 0
  end
end

return M