-- lua/visual-multi/init.lua
-- vim-visual-multi Lua rewrite entry point
-- Entry module for the multi-cursor plugin

local M = {}

M.version = "0.1.0-lua"
M.loaded = false

function M.setup (opts)
  opts = opts or {}

  -- Delegate to plugin module
  local plugin = require ("visual-multi.plugin")
  plugin.setup (opts)

  M.loaded = true
  return M
end

function M.init_buffer (cmd_type)
  local vm = require ("visual-multi.vm")
  return vm.init_buffer (cmd_type)
end

function M.reset ()
  local vm = require ("visual-multi.vm")
  return vm.reset ()
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
