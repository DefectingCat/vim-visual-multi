-- lua/visual-multi/vm.lua
-- Main VM module - initialization and lifecycle management
-- Equivalent to autoload/vm.vim

local M = {}

-- Module references
local State
local Config
local Funcs
local Global
local Search
local Edit
local Insert
local Maps
local Comp
local Themes
local Variables
local Region
local Commands
local Operators

-- Buffer-local state references
local V
local v

-- =============================================================================
-- Initialize global variables
-- =============================================================================

local function init_global_vars ()
  -- Global settings with defaults
  vim.g.VM_live_editing = vim.g.VM_live_editing or 1
  vim.g.VM_custom_commands = vim.g.VM_custom_commands or {}
  vim.g.VM_commands_aliases = vim.g.VM_commands_aliases or {}
  vim.g.VM_debug = vim.g.VM_debug or 0
  vim.g.VM_reselect_first = vim.g.VM_reselect_first or 0
  vim.g.VM_case_setting = vim.g.VM_case_setting or ""
  vim.g.VM_use_first_cursor_in_line = vim.g.VM_use_first_cursor_in_line or 0
  vim.g.VM_disable_syntax_in_imode = vim.g.VM_disable_syntax_in_imode or 0

  -- Reindentation after insert mode
  vim.g.VM_reindent_filetypes = vim.g.VM_reindent_filetypes or {}

  -- Initialize global Vm state if needed
  -- Note: vim.g doesn't support direct nested assignment in Neovim Lua
  local Vm = vim.g.Vm or {}
  if Vm.extend_mode == nil then
    Vm.extend_mode = 0
  end
  if Vm.finding == nil then
    Vm.finding = 0
  end
  if Vm.buffer == nil then
    Vm.buffer = 0
  end
  vim.g.Vm = Vm
end

-- Flag to track if startup initialization has been done
local startup_done = false

-- Initialize modules and global state at startup
local function init_startup ()
  if startup_done then
    return
  end
  startup_done = true

  init_global_vars ()

  -- Initialize themes
  Themes = require ("visual-multi/themes")
  Themes.init ()

  -- Initialize permanent plugs/mappings
  -- Note: This uses <SID> mappings which require a script context.
  -- In VimScript, vm#plugs#buffer() is called at script load time.
  -- For Lua, we need to defer this or handle it differently.
  -- For now, skip the permanent() call as it has <SID> issues in headless mode.
  -- The mappings are set up by the VimScript side or via plugin/vim-visual-multi.vim
end

-- Run startup initialization (safe to call multiple times)
init_startup ()

-- =============================================================================
-- Helper functions
-- =============================================================================

-- Enable hlsearch via feedkeys
local function enable_hls ()
  local mode = vim.fn.mode (1)
  if mode == "n" then
    vim.fn.feedkeys (vim.api.nvim_replace_termcodes ("<Plug>(VM-Hls)", true, false, true), "n")
  else
    vim.fn.timer_start (50, function ()
      enable_hls ()
    end)
  end
end

-- =============================================================================
-- Initialize buffer
-- =============================================================================

-- b:VM_Selection (= V) contains Regions, Vars (= v = plugin variables),
-- function classes (Global, Funcs, Edit, Search, Insert, etc)
--
-- Parameters:
--   cmd_type: if > 0, the search register will be set to an empty string
--             adding cursors uses 1, starting regex uses 2

function M.init_buffer (cmd_type)
  cmd_type = cmd_type or 0

  -- Clear any previous error message
  vim.v.errmsg = ""

  local ok, err = pcall (function ()
    -- If already initialized, return current instance
    if vim.b.visual_multi then
      return vim.b.VM_Selection
    end

    -- Load modules
    State = require ("visual-multi.state")
    Config = require ("visual-multi.config")
    Funcs = require ("visual-multi.funcs")
    Global = require ("visual-multi.global")
    Search = require ("visual-multi.search")
    Edit = require ("visual-multi.edit")
    Insert = require ("visual-multi.insert")
    Maps = require ("visual-multi.maps")
    Comp = require ("visual-multi.comp")
    Variables = require ("visual-multi.variables")
    Region = require ("visual-multi.region")

    -- Create buffer state
    vim.b.VM_Selection = {
      Vars = {},
      Regions = {},
      Bytes = {},
    }
    vim.b.visual_multi = 1

    -- Initialize debug and backup
    vim.b.VM_Debug = vim.b.VM_Debug or { lines = {} }
    vim.b.VM_Backup = {
      ticks = {},
      last = 0,
      first = vim.fn.undotree ().seq_cur,
    }

    -- Set local references
    V = vim.b.VM_Selection
    v = V.Vars

    -- Funcs module must be initialized first
    V.Funcs = Funcs.init ()

    -- Initialize plugin variables
    Variables.init_state (V)
    Variables.init ()

    -- Check filesize limit
    local filesize_limit = vim.g.VM_filesize_limit or 0
    if filesize_limit ~= 0 and Funcs.size () > filesize_limit then
      Variables.reset_globals ()
      vim.v.errmsg = "VM cannot start, buffer too big."
      return vim.v.errmsg
    end

    -- Init search register
    if cmd_type ~= 0 then
      vim.fn.setreg ("/", "")
    end

    -- Hooks and compatibility tweaks before applying mappings
    Comp.init ()

    -- Init class modules
    V.Maps = Maps.init ()
    V.Global = Global.init ()
    V.Search = Search.init ()
    V.Edit = Edit.init ()
    V.Insert = Insert.init ()

    -- Case module (from special/case)
    local ok_case, Case = pcall (require, "visual-multi.case")
    if ok_case then
      V.Case = Case.init and Case.init () or Case
    else
      -- Fallback: create minimal Case module
      V.Case = {
        menu = function ()
          print ("Case module not available")
        end,
      }
    end

    -- Enable mappings
    if V.Maps and V.Maps.enable then
      V.Maps.enable ()
    end

    -- Initialize region module
    Region.init ()

    -- Initialize commands module
    local ok_cmds, Commands = pcall (require, "visual-multi.commands")
    if ok_cmds and Commands.init then
      Commands.init ()
    end

    -- Initialize operators module
    local ok_ops, Operators = pcall (require, "visual-multi.operators")
    if ok_ops and Operators.init then
      Operators.init ()
    end

    -- Setup autocommands
    M.augroup (false)
    M.au_cursor (false)

    -- Set vim variables
    Variables.set ()

    -- Setup highlights
    local highlight_matches = vim.g.VM_highlight_matches or ""
    if highlight_matches ~= "" then
      if not vim.g.Vm.Search then
        Themes.init ()
      else
        Themes.search_highlight ()
      end
      vim.cmd ("hi clear Search")
      vim.cmd ("hi! " .. vim.g.Vm.Search)
    end

    -- Enable hlsearch if needed
    if not vim.v.hlsearch and cmd_type ~= 2 then
      enable_hls ()
    end

    -- Set statusline
    if V.Funcs and V.Funcs.set_statusline then
      V.Funcs.set_statusline (0)
    end

    -- Backup sync settings for the buffer
    if not vim.b.VM_sync_minlines then
      if V.Funcs and V.Funcs.sync_minlines then
        vim.b.VM_sync_minlines = V.Funcs.sync_minlines ()
      end
    end

    -- Store buffer number in global state
    vim.g.Vm.buffer = vim.fn.bufnr ("")

    return V
  end)

  if not ok then
    vim.v.errmsg = "VM cannot start, unhandled exception: " .. tostring (err)
    if Variables then
      Variables.reset_globals ()
    end
    return vim.v.errmsg
  end

  return err
end

-- =============================================================================
-- Reset
-- =============================================================================

function M.reset (silent)
  silent = silent or false

  if not vim.b.visual_multi then
    return {}
  end

  -- Ensure we have valid state
  V = vim.b.VM_Selection
  if not V then
    return {}
  end
  v = V.Vars

  -- Load modules
  Variables = Variables or require ("visual-multi.variables")
  Comp = Comp or require ("visual-multi.comp")

  -- Reset variables
  Variables.reset ()

  -- Reset regex in commands if available
  local ok_cmds, Commands = pcall (require, "visual-multi.commands")
  if ok_cmds and Commands.regex_reset then
    Commands.regex_reset ()
  end

  -- Remove highlight and backup regions
  if V.Global then
    if V.Global.remove_highlight then
      V.Global.remove_highlight ()
    end
    if V.Global.backup_last_regions then
      V.Global.backup_last_regions ()
    end
  end

  -- Restore registers
  if V.Funcs and V.Funcs.restore_regs then
    V.Funcs.restore_regs ()
  end

  -- Disable mappings
  if V.Maps and V.Maps.disable then
    V.Maps.disable (true)
  end

  -- Auto-end insert mode if active
  if V.Insert and V.Insert.auto_end then
    pcall (function ()
      V.Insert:auto_end ()
    end)
  end

  -- Reset maps
  Maps = Maps or require ("visual-multi.maps")
  Maps.reset ()

  -- Reset compatibility
  Comp.reset ()

  -- Teardown autocommands
  M.augroup (true)
  M.au_cursor (true)

  -- Reenable folding, but keep winline and open current fold
  if v.oldfold then
    if V.Funcs and V.Funcs.Scroll then
      V.Funcs.Scroll.get (1)
      vim.cmd ("normal! zizv")
      V.Funcs.Scroll.restore ()
    end
  end

  -- Restore search highlight
  local highlight_matches = vim.g.VM_highlight_matches or ""
  if highlight_matches ~= "" then
    vim.cmd ("hi clear Search")
    vim.cmd ("hi! " .. (vim.g.Vm.search_hi or "Search"))
  end

  -- Restore updatetime
  if vim.g.Vm.oldupdate and vim.o.updatetime ~= vim.g.Vm.oldupdate then
    vim.o.updatetime = vim.g.Vm.oldupdate
  end

  -- Exit compatibility
  Comp.exit ()

  -- Restore visual marks
  if V.Funcs and V.Funcs.restore_visual_marks then
    V.Funcs.restore_visual_marks ()
  end

  -- Message or redraw
  local silent_exit = vim.g.VM_silent_exit or 0
  if silent_exit == 0 and not silent then
    if V.Funcs and V.Funcs.msg then
      V.Funcs.msg ("Exited Visual-Multi.")
    end
  else
    vim.cmd ("redraw!")
  end

  -- Reset globals
  Variables.reset_globals ()

  -- Unset special commands if available
  local ok_scmd, SpecialCmds = pcall (require, "visual-multi.special.commands")
  if ok_scmd and SpecialCmds.unset then
    SpecialCmds.unset ()
  end

  -- Clear buffer variable
  vim.b.visual_multi = nil

  -- Garbage collect
  collectgarbage ()

  return {}
end

-- =============================================================================
-- Hard reset
-- =============================================================================

function M.hard_reset ()
  pcall (function ()
    M.reset (true)
  end)
  M.clearmatches ()
end

-- =============================================================================
-- Clear matches
-- =============================================================================

function M.clearmatches ()
  local matches = vim.fn.getmatches ()
  for _, m in ipairs (matches) do
    if m.group == "VM_Extend" or m.group == "MultiCursor" then
      pcall (function ()
        vim.fn.matchdelete (m.id)
      end)
    end
  end
end

-- =============================================================================
-- Autocommands
-- =============================================================================

-- Buffer-local callback functions
local function buffer_leave ()
  if vim.b.VM_skip_reset_once_on_bufleave then
    vim.b.VM_skip_reset_once_on_bufleave = nil
  else
    local selection = vim.b.VM_Selection or {}
    local vars = selection.Vars or {}
    if not vim.tbl_isempty (selection) and (vars.insert or 0) == 0 then
      M.reset (true)
    end
  end
end

local function buffer_enter ()
  local selection = vim.b.VM_Selection
  if not selection or vim.tbl_isempty (selection) then
    vim.b.VM_Selection = {}
  end
end

local function cursor_moved ()
  V = vim.b.VM_Selection
  if not V then
    return
  end
  v = V.Vars
  if not v then
    return
  end

  if v.eco == 0 then
    -- If currently on a region, set the index to this region
    -- so that it's possible to select next/previous from it
    if V.Global and V.Global.region_at_pos then
      local r = V.Global.region_at_pos ()
      if r and not vim.tbl_isempty (r) then
        v.index = r.index
      end
    end
  end
end

local function set_reg ()
  -- Replace old default register if yanking in VM outside a region or cursor
  V = vim.b.VM_Selection
  if not V then
    return
  end
  v = V.Vars
  if not v then
    return
  end

  if v.yanked then
    v.yanked = 0
    vim.g.Vm.registers = vim.g.Vm.registers or {}
    vim.g.Vm.registers["\""] = {}
    if V.Funcs and V.Funcs.get_reg then
      v.oldreg = V.Funcs.get_reg (vim.v.register)
    end
  end
end

function M.augroup (end_)
  if end_ then
    -- Teardown
    pcall (function ()
      vim.api.nvim_del_augroup_by_name ("VM_global")
    end)
    return
  end

  -- Setup autocommands
  local group = vim.api.nvim_create_augroup ("VM_global", { clear = true })

  vim.api.nvim_create_autocmd ("BufLeave", {
    group = group,
    pattern = "*",
    callback = buffer_leave,
  })

  vim.api.nvim_create_autocmd ("BufEnter", {
    group = group,
    pattern = "*",
    callback = buffer_enter,
  })

  -- TextYankPost or fallback
  if vim.fn.exists ("##TextYankPost") == 1 then
    vim.api.nvim_create_autocmd ("TextYankPost", {
      group = group,
      buffer = 0,
      callback = function ()
        set_reg ()
        -- Call operators.after_yank if available
        local ok, Operators = pcall (require, "visual-multi.operators")
        if ok and Operators.after_yank then
          Operators.after_yank ()
        end
      end,
    })
  else
    vim.api.nvim_create_autocmd ("CursorMoved", {
      group = group,
      buffer = 0,
      callback = function ()
        set_reg ()
        local ok, Operators = pcall (require, "visual-multi.operators")
        if ok and Operators.after_yank then
          Operators.after_yank ()
        end
      end,
    })

    vim.api.nvim_create_autocmd ("CursorHold", {
      group = group,
      buffer = 0,
      callback = function ()
        local ok, Operators = pcall (require, "visual-multi.operators")
        if ok and Operators.after_yank then
          Operators.after_yank ()
        end
      end,
    })
  end
end

function M.au_cursor (end_)
  if end_ then
    -- Teardown
    pcall (function ()
      vim.api.nvim_del_augroup_by_name ("VM_cursormoved")
    end)
    return
  end

  -- Setup cursor movement autocommands
  local group = vim.api.nvim_create_augroup ("VM_cursormoved", { clear = true })

  vim.api.nvim_create_autocmd ("CursorMoved", {
    group = group,
    buffer = 0,
    callback = function ()
      cursor_moved ()
      V = vim.b.VM_Selection
      if V and V.Funcs and V.Funcs.set_statusline then
        V.Funcs.set_statusline (2)
      end
    end,
  })

  vim.api.nvim_create_autocmd ("CursorHold", {
    group = group,
    buffer = 0,
    callback = function ()
      V = vim.b.VM_Selection
      if V and V.Funcs and V.Funcs.set_statusline then
        V.Funcs.set_statusline (1)
      end
    end,
  })
end

-- =============================================================================
-- Module exports
-- =============================================================================

-- For compatibility with vim.fn.vm#init_buffer()
function M._vim_init_buffer (cmd_type)
  return M.init_buffer (cmd_type)
end

-- For compatibility with vim.fn.vm#reset()
function M._vim_reset (silent)
  return M.reset (silent)
end

return M
