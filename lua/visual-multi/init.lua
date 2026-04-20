-- lua/visual-multi/init.lua
-- vim-visual-multi Lua rewrite entry point
-- Entry module for the multi-cursor plugin

local M = {}

M.version = "0.1.0-lua"
M.loaded = false

function M.setup (opts)
  opts = opts or {}

  -- Load configuration
  local config = require ("visual-multi.config")
  config.setup (opts)

  -- Initialize global state for extend_mode tracking
  vim.g.Vm = vim.g.Vm or {}
  vim.g.Vm.extend_mode = vim.g.Vm.extend_mode or 0

  -- Register commands (placeholder for Phase 4)
  -- VMTheme, VMDebug, VMClear, VMLive, VMRegisters, VMSearch

  M.loaded = true
  return M
end

function M.init_buffer (cmd_type)
  cmd_type = cmd_type or 0

  local state = require ("visual-multi.state")
  local config = require ("visual-multi.config")
  local region = require ("visual-multi.region")
  local global = require ("visual-multi.global")
  local funcs = require ("visual-multi.funcs")
  local bufnr = vim.api.nvim_get_current_buf ()

  -- Create buffer state
  local s = state.create (bufnr)

  -- Initialize modules with buffer state
  region.init ()
  global.init ()
  funcs.init ()

  -- Store module references in state
  s.Funcs = funcs
  s.Global = global
  s.Region = region

  -- Register autocmds for state sync
  state.register_autocmds (bufnr)

  -- Mark buffer as active
  vim.b.visual_multi_active = true

  return s
end

function M.reset ()
  local state = require ("visual-multi.state")
  local bufnr = vim.api.nvim_get_current_buf ()
  state.destroy (bufnr)
end

function M.is_active ()
  return vim.b.visual_multi_active == true
end

-- For VimScript compatibility
function M.get_global_state ()
  local state = require ("visual-multi.state")
  return state.get ()
end

-- Expose modules for external use
M.get_region = function ()
  return require ("visual-multi.region")
end

M.get_global = function ()
  return require ("visual-multi.global")
end

M.get_funcs = function ()
  return require ("visual-multi.funcs")
end

return M
