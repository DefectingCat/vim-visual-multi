-- lua/visual-multi/icmds.lua
-- Icmds module - insert mode commands
-- Equivalent to autoload/vm/icmds.vim

local M = {}

-- Module references, populated by M.init()
local State
local Global
local Funcs

-- Buffer-local state references
local V        -- b:VM_Selection (State buffer state)
local v        -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)

-- Cached lambdas (equivalent to VimScript s:R, s:X)
local R_fn     -- returns V.regions

function M.init()
  State = require('visual-multi.state')
  Global = require('visual-multi.global')
  Funcs = require('visual-multi.funcs')

  V = State.get()
  v = V.vars
  v_regions = V.regions

  R_fn = function()
    return v_regions
  end

  return M
end

-- ===========================================================================
-- Lambda helpers
-- ===========================================================================

-- Check if cursor is at end of line
local function eol(r)
  return r.a == (vim.fn.col({r.l, '$'}) - 1)
end

-- Get indent for current line (used in expression register)
local function get_indent()
  vim.g.Vm.indent = vim.fn.getline('.')
  return ''
end

-- ===========================================================================
-- X command (delete/backspace in insert mode)
-- ===========================================================================

function M.x(cmd)
  local size = Funcs.size()
  local change = 0
  v.eco = 1

  if vim.tbl_isempty(v.storepos) then
    local pos_data = vim.fn.getpos('.')
    v.storepos = {pos_data[2], pos_data[3]}
  end

  local active = R_fn()[V.Insert.index]

  for _, r in ipairs(R_fn()) do
    if v.single_region and r ~= active then
      if r.l == active.l then
        r.shift(change, change)
      end
      goto continue
    end

    r.shift(change, change)
    Funcs.Cursor(r.A)

    -- We want to emulate the behaviour that <del> and <bs> have in insert
    -- mode, but implemented as normal mode commands

    if V.Insert.replace then
      -- In replace mode, we don't allow line joining
      if cmd == 'X' and r.a > 1 then
        local original = V.Insert._lines[r.l] -- the original line
        if vim.fn.strpart(vim.fn.getline(r.l), r.a):match('%s*$') then
          -- at EOL
          vim.fn.search('\\s*$', '', r.l)
        end
        -- FIXME this part is bugged with multibyte chars
        r.shift(-1, -1)
        if r.a > 1 then
          local t1 = vim.fn.strpart(vim.fn.getline('.'), 0, r.a - 1)
          local wd = vim.fn.strwidth(t1)
          local tc = vim.fn.strcharpart(original, wd, 1)
          local t2 = vim.fn.strcharpart(original, wd + 1)
          vim.fn.setline(r.l, t1 .. tc .. t2)
        else
          local pre = ''
          local post = original
          vim.fn.setline(r.l, pre .. post)
        end
      end
    elseif cmd == 'x' and eol(r) then
      -- at eol, join lines
      vim.cmd('keepjumps normal! gJ')
    elseif cmd == 'x' then
      -- normal delete
      vim.cmd('keepjumps normal! x')
    elseif cmd == 'X' and r.a == 1 then
      -- at bol, go up and join lines
      vim.cmd('keepjumps normal! kgJ')
      r.shift(-1, -1)
    else
      -- normal backspace
      vim.cmd('keepjumps normal! X')
      local w = vim.fn.strlen(vim.fn.getreg('-'))
      r.shift(-w, -w)
    end

    -- Update changed size
    change = Funcs.size() - size

    ::continue::
  end

  Global.merge_regions()
  Global.select_region(V.Insert.index)
end

-- ===========================================================================
-- Ctrl-W / Ctrl-U command
-- ===========================================================================

function M.cw(ctrlu)
  local size = Funcs.size()
  local change = 0
  v.eco = 1
  local pos_data = vim.fn.getpos('.')
  v.storepos = {pos_data[2], pos_data[3]}
  local keep_line = vim.g.VM_icw_keeps_line or 1

  for _, r in ipairs(R_fn()) do
    r.shift(change, change)

    -- TODO: deletion to line above can be bugged for now
    if keep_line and r.a == 1 then goto continue end

    Funcs.Cursor(r.A)

    if r.a > 1 and eol(r) then
      -- add extra space and move right
      V.Edit.extra_spaces.add(r)
      r.move('l')
    end

    local L = vim.fn.getline(r.l)
    local ws_only = r.a > 1 and not L:sub(1, r.a - 2):match('[^ \t]')

    if ctrlu then
      -- ctrl-u
      vim.cmd('keepjumps normal! d^')
    elseif r.a == 1 then
      -- at bol, go up and join lines
      vim.cmd('keepjumps normal! kgJ')
    elseif ws_only then
      -- whitespace only before, delete it
      vim.cmd('keepjumps normal! d0')
    else
      -- normal deletion
      vim.cmd('keepjumps normal! db')
    end
    r.update_cursor_pos()

    -- Update changed size
    change = Funcs.size() - size

    ::continue::
  end
  V.Insert.start(1)
end

-- ===========================================================================
-- Paste command
-- ===========================================================================

function M.paste()
  Global.select_region(-1)
  V.Edit.paste(1, 0, 1, '"')
  Global.select_region(V.Insert.index)
end

-- ===========================================================================
-- Return (Enter) command
-- ===========================================================================

function M.return_key()
  -- Invert regions order, so that they are processed from bottom to top
  V.regions = vim.fn.reverse(R_fn())

  for _, r in ipairs(R_fn()) do
    vim.fn.cursor(r.l, r.a)
    local rline = vim.fn.getline('.')

    -- We also consider at EOL cursors that have trailing spaces after them
    -- If not at EOL, CR will cut the line and carry over the remaining text
    local at_eol = rline:sub(r.a):match('^%s*$') ~= nil

    -- If carrying over some text, delete it now, for better indentexpr
    -- Otherwise delete the trailing spaces that would be left at EOL
    if not at_eol then
      vim.cmd('keepjumps normal! d$')
    else
      vim.cmd('keepjumps normal! "_d$')
    end

    -- Append a line and get the indent
    vim.cmd('noautocmd exe "silent keepjumps normal! o\\<C-R>=<SID>get_indent()\\<CR>"')

    -- Fill the line with tabs or spaces, according to the found indent
    -- An extra space must be added, if not carrying over any text
    -- Also keep the indent whitespace only, removing any non-space character
    -- Such as comments, and everything after them
    local extra_space = at_eol and ' ' or ''
    local indent = vim.g.Vm.indent:gsub('%S+.*', '')
    vim.fn.setline('.', indent .. extra_space)

    -- If carrying over some text, paste it after the indent
    -- But strip preceding whitespace found in the text
    if not at_eol then
      local reg_content = vim.fn.getreg('"'):gsub('^%s*', '')
      vim.fn.setreg('"', reg_content)
      vim.cmd('keepjumps normal! $p')
    end

    -- Cursor line will be moved down by the next cursors
    r.update_cursor({vim.fn.line('.') + r.index, #indent + 1})
  end

  -- Reorder regions
  V.regions = vim.fn.reverse(R_fn())

  -- Ensure cursors are at indent level
  vim.cmd('keepjumps normal ^')
end

-- ===========================================================================
-- Insert line (above or below)
-- ===========================================================================

function M.insert_line(above)
  -- Invert regions order, so that they are processed from bottom to top
  V.regions = vim.fn.reverse(R_fn())

  for _, r in ipairs(R_fn()) do
    -- Append a line below or above
    vim.fn.cursor(r.l, r.a)
    local cmd = above and 'O' or 'o'
    vim.cmd('noautocmd exe "silent keepjumps normal! ' .. cmd .. '\\<C-R>=<SID>get_indent()\\<CR>"')

    -- Remove comment or other chars, fill the line with tabs or spaces
    local indent = vim.g.Vm.indent:gsub('[^ \t].*', '')
    vim.fn.setline('.', indent .. ' ')

    -- Cursor line will be moved down by the next cursors
    r.update_cursor({vim.fn.line('.') + r.index, #indent + 1})
    table.insert(v.extra_spaces, r.index)
  end

  -- Reorder regions
  V.regions = vim.fn.reverse(R_fn())

  -- Ensure cursors are at indent level
  vim.cmd('keepjumps normal ^')
end

-- ===========================================================================
-- Goto next/prev region (used in single region mode)
-- ===========================================================================

function M.goto_next(next)
  -- Used in single region mode
  v.single_mode_running = 1
  local t = ":call b:VM_Selection.Insert.key('" .. V.Insert.type .. "')\\<cr>"
  if next then
    return "<Esc>:call vm#commands#find_next(0,1)\\<cr>" .. t
  else
    return "<Esc>:call vm#commands#find_prev(0,1)\\<cr>" .. t
  end
end

return M
