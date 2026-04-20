-- lua/visual-multi/insert.lua
-- Insert class module - manages multi-cursor insert mode
-- Equivalent to autoload/vm/insert.vim

local M = {}

-- Module-level state
M.index = -1
M.cursors = {}
M.replace = 0
M.type = ''

-- Module references
local state
local config
local global
local funcs

-- Lambdas
local R_fn
local X_fn

-- Initialize module
function M.init()
  state = require('visual-multi.state')
  config = require('visual-multi.config')
  global = require('visual-multi.global')
  funcs = require('visual-multi.funcs')

  local V = state.get()
  V.vars.restart_insert = 0

  R_fn = function() return V.regions end
  X_fn = function() return vim.g.Vm and vim.g.Vm.extend_mode or 0 end

  return M
end

-- Cursor class (used internally during insert mode)
local Cursor = {}

function Cursor.new(ln, col)
  local C = {}
  C.index = #M.cursors
  C.txt = ''
  C.l = ln
  C.L = ln
  C.a = col
  C._a = col  -- updated position during insert
  C.active = (C.index == M.index)
  C.hl = vim.fn.matchaddpos('MultiCursor', {{C.l, C.a}}, 40)
  return C
end

function Cursor:update(ln, change)
  local C = self
  C._a = C.a + change
  vim.fn.matchdelete(C.hl)
  C.hl = vim.fn.matchaddpos('MultiCursor', {{C.l, C._a}}, 40)
end

-- Line class (used internally during insert mode)
local Line = {}

function Line.new(line_num, cursor)
  local L = {}
  L.l = line_num
  L.txt = vim.fn.getline(line_num)
  L.cursors = {cursor}
  return L
end

-- Update line in insert mode
function Line:update(change, text)
  local line_text = self.txt
  local I = M
  local extraChg = 0

  for _, c in ipairs(self.cursors) do
    if c.a > 1 then
      local insPoint = c.a + extraChg - 1
      local t1 = line_text:sub(1, insPoint)
      local t2 = line_text:sub(insPoint + 1)
      line_text = t1 .. text .. t2
    else
      line_text = text .. line_text
    end

    extraChg = extraChg + change
    c:update(self.l, extraChg)

    if c.active then
      I.col = c._a
    end
  end

  vim.fn.setline(self.l, line_text)
end

-- Update line in replace mode (key algorithm from insert.vim:512-535)
function Line:replace(change, replacementText, width)
  local c = self.cursors[0] or self.cursors[1]  -- single cursor in replace mode
  local original = M._lines[self.l]  -- original line backup
  local replaced = replacementText

  local text
  if c.a > 1 then
    -- Key: strpart for byte offset, strcharpart for character position
    local t1 = vim.fn.strpart(vim.fn.getline(c.l), 0, c.a - 1)
    -- strwidth(t1) + width: display width position
    local t2 = vim.fn.strcharpart(original, vim.fn.strwidth(t1) + width)
    text = t1 .. replaced .. t2
  else
    text = replaced .. vim.fn.strcharpart(original, width)
  end

  c:update(self.l, change)

  if c.active then
    M.col = c._a
  end

  vim.fn.setline(self.l, text)
end

-- Start insert mode with a key (i, I, a, A, o, O)
function M.key(type)
  if not self.type or self.type == '' then
    self.type = type
  end

  if self.replace == 1 then
    global.one_region_per_line()
  end

  -- Handle different insert types
  if type == 'I' then
    -- commands.merge_to_beol(0) - placeholder
    self:key('i')
  elseif type == 'A' then
    -- commands.merge_to_beol(1) - placeholder
    self:key('a')
  elseif type == 'a' then
    if X_fn() == 1 then
      global.change_mode()
    end
    -- Add extra spaces for 'a' mode
    self:start(true)
  else
    if X_fn() == 1 then
      global.change_mode()
    end
    self:start()
  end
end

-- Initialize and start insert mode
function M:start(add_spaces)
  add_spaces = add_spaces or false

  global.merge_cursors()

  local I = self
  I._index = I._index or -1

  local V = state.get()
  local regions = R_fn()

  -- Apply settings and select region
  local R = self:apply_settings()

  I.index = R.index
  I.begin = {R.l, R.a}
  I.cursors = {}
  I.lines = {}
  I.change = 0
  I.col = vim.fn.col('.')
  I.reupdate = false

  -- Remove current regions highlight
  global.remove_highlight()

  -- Create cursors and line objects
  for _, r in ipairs(regions) do
    local C = Cursor.new(r.l, r.a)
    table.insert(I.cursors, C)

    if not I.lines[r.l] then
      I.lines[r.l] = Line.new(r.l, C)
      C.nth = 0
    else
      C.nth = #I.lines[r.l].cursors
      table.insert(I.lines[r.l].cursors, C)
    end

    if C.index == I.index then
      I.nth = C.nth
    end
  end

  -- Backup original lines for replace mode
  if self.replace == 1 and not I._lines then
    I._lines = {}
    for l, line_obj in pairs(I.lines) do
      I._lines[l] = line_obj.txt
    end
  end

  -- Start tracking text changes
  V.vars.insert = 1
  self:auto_start()

  -- Update cursor highlight
  global.update_cursor_highlight()

  -- Start insert/replace mode
  if self.replace == 1 then
    vim.cmd('startreplace')
  else
    vim.cmd('startinsert')
  end
end

-- Apply/disable settings related to insert mode
function M:apply_settings()
  local V = state.get()

  -- Get winline backup if first time
  if not V.vars.winline_insert then
    V.vars.winline_insert = vim.fn.winline()
    global.backup_regions()
  end

  -- Select appropriate region
  local R
  if config.get('use_first_cursor_in_line') == 1 or self.replace == 1 then
    R = global.select_region_at_pos('.')
    local line_regions = global.lines_with_regions(false, R.l)
    if line_regions[R.l] then
      local ix = line_regions[R.l][1] or line_regions[R.l][0]
      R = global.select_region(ix)
    end
  elseif V.vars.insert == 1 then
    local i = self.index >= #R_fn() and (#R_fn() - 1) or self.index
    R = global.select_region(i)
  else
    R = global.select_region_at_pos('.')
  end

  return R
end

-- Update text on TextChangedI event
function M:update_text(insert_leave)
  insert_leave = insert_leave or false

  local V = state.get()
  if not config.get('live_editing') and not insert_leave then
    return
  end

  local I = self
  local L = I.lines

  local ln = vim.fn.line('.')
  local coln = vim.fn.col('.')

  -- Calculate position
  local pos = I.begin[2] + I.change * I.nth

  -- Get inserted text
  local text
  if insert_leave then
    local extra = self.cur_char_bytes() - 1
    text = vim.fn.getline(ln):sub(pos, coln + extra)
    coln = coln + extra
  elseif coln > 1 then
    text = vim.fn.getline(ln):sub(pos, coln - 1)
  else
    text = ''
  end

  -- Update change
  I.change = coln - pos + (insert_leave and 1 or 0)

  -- Update lines
  if I.replace == 1 then
    local width = vim.fn.strwidth(text)
    for l in pairs(L) do
      L[l]:replace(I.change, text, width)
    end
  else
    for l in pairs(L) do
      L[l]:update(I.change, text)
    end
  end

  -- Restore cursor position
  vim.fn.cursor(ln, I.col)
end

-- Called on InsertLeave
function M:stop()
  local V = state.get()

  if self.reupdate then
    self:update_text(1)
    self.reupdate = false
  end

  self:clear_hi()
  self:auto_end()

  local regions = R_fn()
  for i, r in ipairs(regions) do
    local c = self.cursors[i]
    if c then
      r:update_cursor({c.l, c._a})
    end
  end

  if V.vars.restart_insert then
    V.vars.restart_insert = 0
    return
  end

  -- Reset insert mode variables
  V.vars.eco = 1
  V.vars.insert = 0
  V.vars.winline_insert = nil

  global.select_region(self.index)

  -- Reset type and replace
  self.replace = 0
  self.type = ''
  self._lines = nil
end

-- Clear cursors highlight
function M:clear_hi()
  for _, c in ipairs(self.cursors) do
    vim.fn.matchdelete(c.hl)
  end
end

-- Initialize autocommands
function M:auto_start()
  local bufnr = vim.api.nvim_get_current_buf()
  local V = state.get()

  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = bufnr,
    callback = function()
      M:update_text(0)
    end,
    group = "VM_insert"
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = bufnr,
    callback = function()
      M:stop()
    end,
    group = "VM_insert"
  })

  vim.api.nvim_create_autocmd("InsertCharPre", {
    buffer = bufnr,
    callback = function()
      M.reupdate = true
    end,
    group = "VM_insert"
  })
end

-- Terminate autocommands
function M:auto_end()
  vim.api.nvim_del_augroup_by_name("VM_insert")
end

-- Bytesize of character under cursor
function M.cur_char_bytes()
  return vim.fn.strlen(vim.fn.matchstr(vim.fn.getline('.'), '\\%' .. vim.fn.col('.') .. 'c.'))
end

return M