-- lua/visual-multi/edit.lua
-- Edit class - command execution over regions
-- Equivalent to autoload/vm/edit.vim

local M = {}
M.skip_index = -1

-- Module references, populated by M.init()
local State
local Global
local Region
local Funcs
local Config
local Bytes

-- Buffer-local state references
local V        -- b:VM_Selection (State buffer state)
local v        -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)

-- Cached lambdas (equivalent to VimScript s:R, s:X)
local R_fn     -- returns V.regions
local X_fn     -- returns g:Vm.extend_mode

function M.init()
  State = require('visual-multi.state')
  Global = require('visual-multi.global')
  Region = require('visual-multi.region')
  Funcs = require('visual-multi.funcs')
  Config = require('visual-multi.config')

  V = State.get()
  v = V.vars
  v_regions = V.regions

  R_fn = function()
    return v_regions
  end

  X_fn = function()
    return vim.g.Vm and vim.g.Vm.extend_mode or 0
  end

  -- Initialize script variables (matching VimScript init)
  v.new_text = {}
  v.W = {}
  v.storepos = {}
  v.extra_spaces = {}

  -- can_multiline controls whether multiline is allowed during commands
  M._can_multiline = 0

  return M
end

-- ===========================================================================
-- run_normal: Execute normal command over regions
-- Equivalent to s:Edit.run_normal(cmd, ...) in VimScript
-- ===========================================================================
function M.run_normal(cmd, opts)
  opts = opts or {}

  -- cmd == -1 means prompt user for input
  if cmd == -1 then
    -- Placeholder: statusline display for NORMAL mode
    local bang = opts.recursive == false and '!' or ''
    local input_cmd = vim.fn.input(':normal' .. bang .. ' ')
    if input_cmd == '' or input_cmd == nil then
      Funcs.msg('Normal command aborted.')
      return
    end
    cmd = input_cmd

  -- ~ command in extend mode -> run as visual command
  elseif cmd == '~' and X_fn() == 1 then
    return M.run_visual('~', 0)

  -- Empty command
  elseif cmd == nil or cmd == '' then
    Funcs.msg('No last command.')
    return
  end

  -- defaults: commands are recursive, count=1, vim registers untouched
  local args = {
    recursive = opts.recursive ~= nil and opts.recursive or true,
    count = opts.count or 1,
    vimreg = opts.vimreg or false,
    gcount = opts.gcount or 0,
    silent = Config.get('silent_ex_commands') or 0,
  }

  -- Override with provided opts
  if opts.store ~= nil then args.store = opts.store end
  if opts.stay_put ~= nil then args.stay_put = opts.stay_put end
  if opts.vimreg ~= nil then args.vimreg = opts.vimreg end

  -- If it's a VM internal operation (store == '§'), never use recursive mappings
  if args.store == '\167' then  -- '§' character
    args.recursive = false
  end

  local n = args.count > 1 and tostring(args.count) or ''
  local c = args.recursive and ('normal ' .. n .. cmd) or ('normal! ' .. n .. cmd)
  if args.silent then
    c = 'silent! ' .. c
  end

  -- Switch to cursor mode
  Global.cursor_mode()

  -- Before commands
  M.before_commands()

  local errors = ''

  -- Execute: special handler for x/X, or general processing
  local ok, err = pcall(function()
    if cmd:lower() == 'x' then
      M._bs_del(n .. cmd)
    elseif args.gcount and args.gcount ~= 0 then
      M.process(cmd, args)
    else
      M.process(c, args)
    end
  end)
  if not ok then
    errors = err or vim.v.errmsg
  end

  -- Store for dot command replay
  g_Vm = vim.g.Vm or {}
  g_Vm.last_normal = {cmd, args.recursive}
  v.dot = {cmd, args.recursive}
  v.merge = 1

  -- After commands
  M.after_commands(0)

  if errors ~= '' then
    Funcs.msg('[visual-multi] errors while executing ' .. c)
  end
end

-- ===========================================================================
-- run_visual: Execute visual command over selections
-- Equivalent to s:Edit.run_visual(cmd, recursive, ...) in VimScript
-- ===========================================================================
function M.run_visual(cmd, recursive, opts)
  opts = opts or {}

  if X_fn() == 0 then
    Funcs.msg('Not possible in cursor mode.')
    return
  end

  -- cmd == -1 means prompt user for input
  if not opts._has_cmd and cmd == -1 then
    -- Placeholder: statusline display for VISUAL mode
    local bang = recursive == false and '!' or ''
    local input_cmd = vim.fn.input(':visual' .. bang .. ' ')
    if input_cmd == '' or input_cmd == nil then
      Funcs.msg('Visual command aborted.')
      return
    end
    cmd = input_cmd

  elseif cmd == nil or cmd == '' then
    Funcs.msg('Command not found.')
    return
  end

  -- Before commands
  M.before_commands()

  local errors = ''

  -- Execute visual command
  local ok, err = pcall(function()
    M._process_visual(cmd, recursive)
  end)
  if not ok then
    errors = err or vim.v.errmsg
  end

  -- Store for replay
  local g_Vm = vim.g.Vm or {}
  g_Vm.last_visual = {cmd, recursive}

  -- After commands
  M.after_commands(0)

  -- Reselect if needed
  if not M._visual_reselect(cmd) then
    Global.change_mode()
  end

  if errors ~= '' then
    Funcs.msg('[visual-multi] errors while executing ' .. cmd)
  end
end

-- ===========================================================================
-- process: Execute command at cursors
-- Equivalent to s:Edit.process(cmd, ...) in VimScript
-- ===========================================================================
function M.process(cmd, args)
  args = args or {}

  v.eco = 1             -- turn on eco mode
  local change = 0      -- each cursor will update this value
  local txt = {}        -- if text is deleted, it will be stored here
  local size = Funcs.size()  -- initial buffer size

  if #v.storepos == 0 then
    v.storepos = vim.fn.getpos('.')[2]  -- [line, col] -> just store line for simplicity
  end

  local backup_txt = args.store ~= nil    -- deleting regions, store their text
  local write_reg = backup_txt and args.store ~= '_'  -- also write vim register unless _
  local stay_put = args.stay_put or false -- don't move the cursors after command

  -- We want CursorMoved, even if cursor doesn't move (for older Neovim without TextYankPost)
  local do_cursor_moved = not vim.fn.has('textyankpost') or vim.fn.has('textyankpost') == 0

  -- used by g<C-A>, g<C-X>
  local gcount = 0
  if args.gcount and args.gcount ~= 0 then
    gcount = args.count and args.count or 1
  end

  -- Store old register if we need to backup text
  if backup_txt then
    v._oldreg = {vim.fn.getreg('"'), vim.fn.getregtype('"')}
    vim.fn.setreg('"', '')
  end
  local must_restore_register = false

  -- Backup regions
  Global.backup_regions()

  for i, r in ipairs(R_fn()) do
    -- used in non-live edit, currently disabled
    if v.auto == 0 and r.index == M.skip_index then goto continue end

    -- update cursor position on the base of previous text changes
    r:shift(change, change)

    -- execute command at cursor
    vim.fn.cursor(r.l, r.a)

    if gcount ~= 0 then
      local tick = vim.fn.getbufinfo()[1].changedtick
      local ok, _ = pcall(function()
        vim.cmd('normal! ' .. gcount .. ' ' .. cmd)
      end)
      if vim.fn.getbufinfo()[1].changedtick > tick then
        gcount = gcount + (args.count or 1)
      end
    else
      local ok, _ = pcall(function()
        vim.cmd(cmd)
      end)
    end

    -- store deleted text during deletions/changes at cursors
    if backup_txt then
      if vim.fn.getreg('"') == '' then
        backup_txt = false
        write_reg = false
        must_restore_register = true
      else
        table.insert(txt, vim.fn.getreg(v.def_reg or '"'))
      end
    end

    -- update new cursor position after the command, unless specified
    local diff = Funcs.curs2byte() - r.A
    if not stay_put then
      r:shift(diff, diff)
    end

    -- update changed size
    change = Funcs.size() - size

    -- let's force CursorMoved in case some yank command needs it
    if diff == 0 and do_cursor_moved then
      vim.cmd('silent! doautocmd <nomodeline> CursorMoved')
    end

    ::continue::
  end

  if must_restore_register then
    local oldreg = v._oldreg
    vim.fn.setreg('"', oldreg[1], oldreg[2])

  elseif write_reg then
    -- fill VM register after deletions/changes at cursors
    -- overwrite vim register if requested
    M._fill_register(args.store, txt, args.vimreg)
  end

  -- the original regions text could used by commands
  if backup_txt then
    v.changed_text = txt
  end
end

-- ===========================================================================
-- _process_visual: Process a visual command over selections
-- Equivalent to s:Edit.process_visual(cmd, recursive) in VimScript
-- ===========================================================================
function M._process_visual(cmd, recursive)
  v.eco = 1             -- turn on eco mode
  local change = 0      -- each cursor will update this value
  local size = Funcs.size()  -- initial buffer size
  v.storepos = vim.fn.getpos('.')[2]

  local c = recursive and ('normal ' .. cmd) or ('normal! ' .. cmd)

  Global.backup_regions()

  for _, r in ipairs(R_fn()) do
    r:shift(change, change)
    -- Mark start of selection
    vim.fn.cursor(r.L, r.b)
    vim.cmd('normal! m`')
    -- Select region
    vim.fn.cursor(r.l, r.a)
    vim.cmd('normal! v``')
    -- Execute command
    vim.cmd(c)

    -- update changed size
    change = Funcs.size() - size
  end
end

-- ===========================================================================
-- post_process: Operations after command execution
-- Equivalent to s:Edit.post_process(reselect, ...) in VimScript
-- ===========================================================================
function M.post_process(reselect, change_offset)
  if reselect then
    Global.extend_mode()
    for _, r in ipairs(R_fn()) do
      local w_offset = v.W[r.index] or 0
      r:shift(change_offset, change_offset + w_offset)
    end
  end

  -- remove extra spaces that may have been added
  M.extra_spaces.remove()

  -- update, restore position and clear vars
  local pos
  if #v.storepos == 0 then
    pos = '.'
  else
    pos = v.storepos
  end
  Global.update_and_select_region(pos)
  v.storepos = {}
end

-- ===========================================================================
-- before_commands: Disable mappings and run user autocommand
-- Equivalent to s:Edit.before_commands() in VimScript
-- ===========================================================================
function M.before_commands()
  v.auto = 1
  v.eco = 1

  M._old_multiline = v.multiline
  v.multiline = M._can_multiline
  M._can_multiline = 0

  -- User autocommand before running commands
  vim.cmd('silent doautocmd <nomodeline> User visual_multi_before_cmd')

  -- Disable mappings (Maps module may not exist yet, use safe calls)
  if V.Maps and V.Maps.disable then
    V.Maps.disable(0)
  end
  if V.Maps and V.Maps.unmap_esc_and_toggle then
    V.Maps.unmap_esc_and_toggle()
  end
end

-- ===========================================================================
-- after_commands: Trigger post processing and reenable mappings
-- Equivalent to s:Edit.after_commands(reselect, ...) in VimScript
-- ===========================================================================
function M.after_commands(reselect, change_offset)
  v.multiline = M._old_multiline

  if reselect then
    M.post_process(1, change_offset)
  else
    M.post_process(0)
  end

  -- Reenable mappings
  if V.Maps and V.Maps.enable then
    V.Maps.enable()
  end
  if V.Maps and V.Maps.map_esc_and_toggle then
    V.Maps.map_esc_and_toggle()
  end

  -- User autocommand after running commands
  vim.cmd('silent doautocmd <nomodeline> User visual_multi_after_cmd')
end

-- ===========================================================================
-- Extra spaces sub-module
-- Equivalent to s:Edit.extra_spaces in VimScript
-- ===========================================================================
M.extra_spaces = {}

function M.extra_spaces.remove(line_offset)
  -- Extra spaces at EOL may have been added and must be removed.
  -- Remove the extra space only if it comes after r.b, and it's just before \n
  for _, i in ipairs(v.extra_spaces) do
    -- some region has been removed for some reason (merge, ...)
    if i >= #R_fn() then break end

    local l = R_fn()[i + 1].L + (line_offset or 0)
    local line_text = vim.fn.getline(l)
    if #line_text > 0 and line_text:sub(-1) == ' ' then
      vim.fn.setline(l, line_text:sub(1, -2))
    end
  end
  v.extra_spaces = {}
end

function M.extra_spaces.add(r, insert_mode)
  -- It may be necessary to add spaces over empty lines, or if at EOL.
  -- add space if empty line(>) or eol(=)
  -- optional arg is when called in insert mode (cursors are different)
  local end_pos, line_num
  if insert_mode then
    end_pos = r._a
    line_num = r.l
  else
    end_pos = r.b
    line_num = r.L
  end

  local line_text = vim.fn.getline(line_num)
  -- use vim.fn.strwidth because multibyte chars cause problems at EOL
  -- this will result in more extra spaces than necessary but no big deal
  if end_pos >= vim.fn.strwidth(line_text) then
    vim.fn.setline(line_num, line_text .. ' ')
    table.insert(v.extra_spaces, r.index)
  end
end

-- ===========================================================================
-- Helpers (internal)
-- ===========================================================================

-- Special handler for x/X normal commands, and <BS>/<Del> insert commands.
-- Equivalent to s:bs_del(cmd) in VimScript
function M._bs_del(cmd)
  if v.insert == 1 then
    -- Delegate to icmds module if available
    if V.Icmds and V.Icmds.x then
      return V.Icmds.x(cmd)
    end
    -- Fallback: try vim fn
    if vim.fn['vm#icmds#x'] then
      return vim.fn['vm#icmds#x'](cmd)
    end
  else
    M.process('normal! ' .. cmd)
  end

  if cmd == 'x' then
    for _, r in ipairs(R_fn()) do
      if r.a == vim.fn.col({r.L, '$'}) then
        r:shift(-1, -1)
      end
    end
  end

  Global.merge_regions()
end

-- Ensure selections are reselected after some commands.
-- Equivalent to s:visual_reselect(cmd) in VimScript
function M._visual_reselect(cmd)
  local reselect = cmd == '~' or cmd:lower():find('[u]')
  return X_fn() == 1 and reselect
end

-- Fill VM register after deletions/changes at cursors.
-- Equivalent to fill_register method (from ecmds/vim version)
function M._fill_register(store_reg, txt, vimreg)
  if #txt == 0 then return end

  local reg = store_reg or v.def_reg or '"'
  local text = table.concat(txt, '\n')

  -- Write to VM register (placeholder - full register handling in registers module)
  if vimreg then
    vim.fn.setreg(reg, text)
  else
    -- Store in VM internal register
    v._vm_reg = v._vm_reg or {}
    v._vm_reg[reg] = text
  end
end

return M
