-- lua/visual-multi/plugin.lua
-- Plugin entry point - initialization and commands
-- Equivalent to plugin/visual-multi.vim

local M = {}

-- Initialize plugin
function M.setup ()
  -- Check Neovim version
  if vim.fn.has ("nvim-0.5") == 0 then
    vim.notify ("[vim-visual-multi] Neovim 0.5+ is required", vim.log.levels.ERROR)
    return
  end

  -- Prevent double loading (but allow explicit setup call)
  local was_loaded = vim.g.loaded_visual_multi
  if was_loaded then
    -- Already loaded via plugin/visual-multi.vim, but still run mappings
    local ok_maps, maps = pcall (require, "visual-multi.maps")
    if ok_maps and maps.default then
      maps.default ()
    end
    M.define_commands ()
    return
  end
  vim.g.loaded_visual_multi = 1

  -- Initialize global Vm state (must be done before maps.default())
  local Vm = {
    hi = {},
    buffer = 0,
    extend_mode = 0,
    finding = 0,
    mappings_enabled = 0,
    last_ex = "",
    last_normal = "",
    last_visual = "",
    registers = { ['"'] = {}, ["-"] = {} },
    oldupdate = vim.fn.exists ("##TextYankPost") == 1 and 0 or vim.o.updatetime,
    maps = { permanent = {} },
    unmaps = {},
  }
  vim.g.Vm = Vm

  -- Set default for highlight matches
  vim.g.VM_highlight_matches = vim.g.VM_highlight_matches or "underline"

  -- Set default for persistent registers
  vim.g.VM_persistent_registers = vim.g.VM_persistent_registers or 0

  -- Define default highlights
  vim.cmd ([[
    hi default link VM_Mono IncSearch
    hi default link VM_Cursor Visual
    hi default link VM_Extend PmenuSel
    hi default link VM_Insert DiffChange
    hi link MultiCursor VM_Cursor
  ]])

  -- Initialize global mappings
  local ok_maps, maps = pcall (require, "visual-multi.maps")
  if ok_maps and maps.default then
    maps.default ()
  end

  -- Setup autocommands for register persistence
  local group = vim.api.nvim_create_augroup ("VM_start", { clear = true })

  vim.api.nvim_create_autocmd ("VimEnter", {
    group = group,
    pattern = "*",
    callback = function ()
      M.vm_registers ()
    end,
  })

  vim.api.nvim_create_autocmd ("VimLeavePre", {
    group = group,
    pattern = "*",
    callback = function ()
      M.vm_persist ()
    end,
  })

  -- Define user commands
  M.define_commands ()
end

-- Define user commands
function M.define_commands ()
  -- VMTheme command
  vim.api.nvim_create_user_command ("VMTheme", function (opts)
    local themes = require ("visual-multi.themes")
    themes.load (opts.args)
  end, {
    nargs = "?",
    complete = function (_, cmdline, _)
      local themes = require ("visual-multi.themes")
      return themes.complete (cmdline, "", 0)
    end,
  })

  -- VMDebug command
  vim.api.nvim_create_user_command ("VMDebug", function ()
    local commands = require ("visual-multi.special.commands")
    commands.debug ()
  end, { bar = true })

  -- VMClear command
  vim.api.nvim_create_user_command ("VMClear", function ()
    local vm = require ("visual-multi.vm")
    vm.hard_reset ()
  end, { bar = true })

  -- VMLive command
  vim.api.nvim_create_user_command ("VMLive", function ()
    local commands = require ("visual-multi.special.commands")
    commands.live ()
  end, { bar = true })

  -- VMRegisters command
  vim.api.nvim_create_user_command ("VMRegisters", function (opts)
    local commands = require ("visual-multi.special.commands")
    commands.show_registers (opts.bang, opts.args)
  end, { bang = true, nargs = "?" })

  -- VMSearch command
  vim.api.nvim_create_user_command ("VMSearch", function (opts)
    local commands = require ("visual-multi.special.commands")
    commands.search (opts.bang, opts.line1, opts.line2, opts.args)
  end, { bang = true, nargs = "?", range = true })

  -- Deprecated VMFromSearch command
  vim.api.nvim_create_user_command ("VMFromSearch", function (opts)
    vim.notify (
      "[visual-multi] VMFromSearch is deprecated, use VMSearch instead",
      vim.log.levels.WARN
    )
  end, { bang = true })
end

-- Register persistence functions
function M.vm_registers ()
  if vim.g.VM_PERSIST and not vim.g.VM_persistent_registers then
    vim.g.VM_PERSIST = nil
  elseif vim.g.VM_PERSIST then
    local Vm = vim.g.Vm or {}
    Vm.registers = vim.deepcopy (vim.g.VM_PERSIST)
    vim.g.Vm = Vm
  end
end

function M.vm_persist ()
  if vim.g.VM_PERSIST and not vim.g.VM_persistent_registers then
    vim.g.VM_PERSIST = nil
  elseif vim.g.VM_persistent_registers then
    local Vm = vim.g.Vm or {}
    vim.g.VM_PERSIST = vim.deepcopy (Vm.registers)
  end
end

-- VMInfos() equivalent
function M.infos ()
  if not vim.b.VM_Selection or vim.tbl_isempty (vim.b.VM_Selection) then
    return {}
  end

  local VM = vim.b.VM_Selection
  local Vm = vim.g.Vm or {}
  local m = Vm.mappings_enabled and "M" or "m"
  local s = VM.Vars.single_region and "S" or "s"
  local l = VM.Vars.multiline and "V" or "v"

  return {
    current = VM.Vars.index + 1,
    total = #VM.Regions,
    ratio = string.format ("%d / %d", VM.Vars.index + 1, #VM.Regions),
    patterns = VM.Vars.search,
    status = m .. s .. l,
  }
end

-- Expose VMInfos globally
function _G.VMInfos ()
  return M.infos ()
end

return M
