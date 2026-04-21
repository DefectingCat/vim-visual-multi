-- lua/visual-multi/comp.lua
-- Comp module - compatibility with other plugins
-- Equivalent to autoload/vm/comp.vim

local M = {}

-- Plugin compatibility dictionary
local plugins = {
  ctrlsf = {
    test = function ()
      return vim.bo.ft == "ctrlsf"
    end,
    enable = "call ctrlsf#buf#ToggleMap(1)",
    disable = "call ctrlsf#buf#ToggleMap(0)",
  },
  AutoPairs = {
    test = function ()
      return vim.b.autopairs_enabled and vim.fn.exists ("*AutoPairsTryInit") == 1
    end,
    enable = "unlet b:autopairs_loaded | call AutoPairsTryInit() | let b:autopairs_enabled = 1",
    disable = "let b:autopairs_enabled = 0",
  },
  smartinput = {
    test = function ()
      return vim.g.loaded_smartinput and vim.g.loaded_smartinput == 1
    end,
    enable = "unlet! b:smartinput_disabled",
    disable = "let b:smartinput_disabled = 1",
  },
  tagalong = {
    test = function ()
      return vim.b.tagalong_initialized ~= nil
    end,
    enable = "TagalongInit",
    disable = "TagalongDeinit",
  },
}

-- Merge with user-defined plugins
local user_plugins = vim.g.VM_plugins_compatibilty or {}
for k, v in pairs (user_plugins) do
  plugins[k] = v
end

-- State variables
local disabled_deoplete = false
local disabled_ncm2 = false

-- Module references
local V
local v

function M.init ()
  V = require ("visual-multi.state").get ()
  v = V.vars
  v.disabled_plugins = {}

  vim.cmd ("silent! call VM_Start()")
  vim.cmd ("silent doautocmd <nomodeline> User visual_multi_start")

  if vim.g.loaded_youcompleteme then
    vim.g.VM_use_first_cursor_in_line = 1
  end

  if vim.b.doge_interactive then
    vim.fn["doge#deactivate"] ()
  end

  for plugin, p in pairs (plugins) do
    if p.test () then
      vim.cmd (p.disable)
      table.insert (v.disabled_plugins, plugin)
    end
  end
end

function M.icmds ()
  -- Insert mode starts: temporarily disable autocompletion engines
  if vim.g.loaded_deoplete and vim.fn["deoplete#is_enabled"] () then
    vim.fn["deoplete#disable"] ()
    disabled_deoplete = true
  elseif vim.b.ncm2_enable then
    vim.b.ncm2_enable = 0
    disabled_ncm2 = true
  end
end

function M.TextChangedI ()
  -- Insert mode change: re-enable autocompletion engines
  if vim.g.loaded_deoplete and disabled_deoplete then
    vim.fn["deoplete#enable"] ()
    disabled_deoplete = false
  elseif disabled_ncm2 then
    vim.b.ncm2_enable = 1
    disabled_ncm2 = false
  end
end

function M.conceallevel ()
  -- indentLine compatibility
  return vim.b.indentLine_ConcealOptionSet and vim.b.indentLine_ConcealOptionSet
end

function M.iobj ()
  -- Inner text objects that should avoid using the select operator
  return vim.g.loaded_targets and { "q" } or {}
end

function M.reset ()
  -- Called during VM exit
  if vim.g.loaded_deoplete and disabled_deoplete then
    vim.fn["deoplete#enable"] ()
    disabled_deoplete = false
  elseif disabled_ncm2 then
    vim.b.ncm2_enable = 1
    disabled_ncm2 = false
  end

  -- Restore plugins functionality if necessary
  for plugin, _ in pairs (plugins) do
    if vim.fn.index (v.disabled_plugins, plugin) >= 0 then
      vim.cmd (plugins[plugin].enable)
    end
  end
end

function M.exit ()
  -- Called last on VM exit
  vim.cmd ("silent! call VM_Exit()")
  vim.cmd ("silent doautocmd <nomodeline> User visual_multi_exit")
end

function M.add_line ()
  -- Ensure a line is added with these text objects, while changing in cursor mode
  local l = {}
  if vim.g.loaded_textobj_indent then
    vim.list_extend (l, { "ii", "ai", "iI", "aI" })
  end
  if vim.g.loaded_textobj_function then
    vim.list_extend (l, { "if", "af", "iF", "aF" })
  end
  return l
end

function M.no_reindents ()
  -- Don't reindent for filetypes
  return { "ctrlsf" }
end

return M
