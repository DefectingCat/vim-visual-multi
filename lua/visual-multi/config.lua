-- lua/visual-multi/config.lua
-- Configuration management module - reads g:VM_* variables

local M = {}

-- Default values matching VimScript version
local defaults = {
  highlight_matches = "underline",
  live_editing = 1,
  custom_commands = {},
  commands_aliases = {},
  debug = 0,
  reselect_first = 0,
  case_setting = "",
  use_first_cursor_in_line = 0,
  disable_syntax_in_imode = 0,
  reindent_filetypes = {},
  persistent_registers = 0,
  filesize_limit = 0,
  use_python = 0, -- Lua version doesn't use Python
  silent_exit = 0,
  verbose_commands = 0,
  theme = "",
  leader = "\\",
  default_mappings = 1,
  mouse_mappings = 0,
  skip_empty_lines = 0,
  skip_shorter_lines = 1,
  sync_minlines = 100,
}

M.values = {}

function M.setup (opts)
  -- Merge opts with defaults and Vim global variables
  for key, default_val in pairs (defaults) do
    local vim_key = "VM_" .. key
    local vim_val = vim.g[vim_key]

    if vim_val ~= nil then
      M.values[key] = vim_val
    elseif opts[key] ~= nil then
      M.values[key] = opts[key]
    else
      M.values[key] = default_val
    end
  end

  return M
end

function M.get (key)
  if M.values[key] ~= nil then
    return M.values[key]
  end

  -- Try to read from Vim global
  local vim_key = "VM_" .. key
  local vim_val = vim.g[vim_key]

  if vim_val ~= nil then
    return vim_val
  end

  return defaults[key]
end

function M.set (key, value)
  M.values[key] = value
  -- Also set Vim global for VimScript compatibility
  vim.g["VM_" .. key] = value
end

return M
