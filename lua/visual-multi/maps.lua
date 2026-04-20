-- lua/visual-multi/maps.lua
-- Maps module - mapping management for VM
-- Equivalent to autoload/vm/maps.vim

local M = {}

-- Module references
local State
local Global
local Funcs

-- Buffer-local state references
local V
local v

-- Global config variables
vim.g.VM_custom_noremaps = vim.g.VM_custom_noremaps or {}
vim.g.VM_custom_remaps = vim.g.VM_custom_remaps or {}
vim.g.VM_custom_motions = vim.g.VM_custom_motions or {}
vim.g.VM_check_mappings = vim.g.VM_check_mappings or 1
vim.g.VM_default_mappings = vim.g.VM_default_mappings or 1
vim.g.VM_mouse_mappings = vim.g.VM_mouse_mappings or 0

-- Maps object (dictionary for methods)
local Maps = {}

function M.init ()
  State = require ("visual-multi.state")
  Global = require ("visual-multi.global")
  Funcs = require ("visual-multi.funcs")

  V = State.get ()
  v = V.vars

  if not vim.b.VM_maps then
    M._build_buffer_maps ()
  end

  Maps.map_esc_and_toggle ()
  M._check_warnings ()
  return Maps
end

function M.default ()
  -- At vim start, permanent mappings are generated and applied
  M._build_permanent_maps ()
  for _, m in ipairs (vim.g.Vm.maps.permanent) do
    vim.fn.execute (m)
  end
end

function M.reset ()
  -- At VM reset, last buffer mappings are reset, and permanent maps are restored
  Maps.unmap_esc_and_toggle ()
  for _, m in ipairs (vim.g.Vm.maps.permanent) do
    vim.fn.execute (m)
  end
end

-- ===========================================================================
-- Mappings activation/deactivation
-- ===========================================================================

function Maps.enable ()
  -- Enable mappings in current buffer
  if vim.g.Vm.mappings_enabled ~= 1 then
    vim.g.Vm.mappings_enabled = 1
    Maps.start ()
  end
end

function Maps.disable (keep_permanent)
  -- Disable mappings in current buffer
  if vim.g.Vm.mappings_enabled == 1 then
    vim.g.Vm.mappings_enabled = 0
    Maps.stop (keep_permanent)
  end
end

function Maps.mappings_toggle ()
  -- Toggle mappings in current buffer
  if vim.g.Vm.mappings_enabled == 1 then
    Maps.disable (1)
  else
    Maps.enable ()
  end
end

-- ===========================================================================
-- Apply mappings
-- ===========================================================================

function Maps.start ()
  -- Apply mappings in current buffer
  for _, m in ipairs (vim.g.Vm.maps.permanent) do
    vim.fn.execute (m)
  end
  for _, m in ipairs (vim.b.VM_maps) do
    vim.fn.execute (m)
  end

  vim.fn.execute ("nmap <nowait> <buffer> : <Plug>(VM-:)")
  vim.fn.execute ("nmap <nowait> <buffer> / <Plug>(VM-/)")
  vim.fn.execute ("nmap <nowait> <buffer> ? <Plug>(VM-?)")

  -- User autocommand after mappings have been set
  vim.cmd ("silent doautocmd <nomodeline> User visual_multi_mappings")
end

function Maps.map_esc_and_toggle ()
  -- Esc and 'toggle' keys are handled separately
  if not vim.fn.has ("nvim") and not vim.fn.has ("gui_running") then
    vim.fn.execute ("nnoremap <nowait><buffer> <esc><esc> <esc><esc>")
  end
  vim.fn.execute ("nmap <nowait><buffer> " .. vim.g.Vm.maps.exit .. " <Plug>(VM-Exit)")
  vim.fn.execute ("nmap <nowait><buffer> " .. vim.g.Vm.maps.toggle .. " <Plug>(VM-Toggle-Mappings)")
end

-- ===========================================================================
-- Remove mappings
-- ===========================================================================

function Maps.stop (keep_permanent)
  -- Remove mappings in current buffer
  for _, m in ipairs (vim.g.Vm.unmaps) do
    vim.fn.execute (m)
  end
  for _, m in ipairs (vim.b.VM_unmaps) do
    vim.fn.execute (m)
  end

  vim.fn.execute ("nunmap <buffer> :")
  vim.fn.execute ("nunmap <buffer> /")
  vim.fn.execute ("nunmap <buffer> ?")
  vim.fn.execute ("silent! cunmap <buffer> <cr>")
  vim.fn.execute ("silent! cunmap <buffer> <esc>")

  -- Restore permanent mappings
  if keep_permanent then
    for _, m in ipairs (vim.g.Vm.maps.permanent) do
      vim.fn.execute (m)
    end
  end
end

function Maps.unmap_esc_and_toggle ()
  -- Esc and 'toggle' keys are handled separately
  vim.fn.execute ("silent! nunmap <buffer> " .. vim.g.Vm.maps.toggle)
  vim.fn.execute ("silent! nunmap <buffer> " .. vim.g.Vm.maps.exit)
  if not vim.fn.has ("nvim") and not vim.fn.has ("gui_running") then
    vim.fn.execute ("silent! nunmap <buffer> <esc><esc>")
  end
end

-- ===========================================================================
-- Map helper functions
-- ===========================================================================

function M._build_permanent_maps ()
  -- Run at vim start. Generate permanent mappings and integrate custom ones.

  -- Set default VM leader
  local ldr = vim.g.VM_leader or "\\"
  vim.g.Vm.leader = type (ldr) == "string" and { default = ldr, visual = ldr, buffer = ldr }
    or vim.tbl_extend ("keep", ldr, { default = "\\", visual = "\\", buffer = "\\" })

  -- Init vars and generate base permanent maps
  vim.g.VM_maps = vim.g.VM_maps or {}
  vim.g.Vm.maps = { permanent = {} }
  vim.g.Vm.unmaps = {}

  -- Get permanent maps from all#permanent module
  local maps = vim.fn["vm#maps#all#permanent"] ()

  -- Integrate custom maps
  for key, _ in pairs (vim.g.VM_maps) do
    if maps[key] then
      maps[key][1] = vim.g.VM_maps[key]
    end
  end

  -- Generate list of 'exe' commands for map assignment
  for key, val in pairs (maps) do
    local mapping = M._assign (key, val, false)
    if mapping ~= "" then
      table.insert (vim.g.Vm.maps.permanent, mapping)
    end
  end

  -- Generate list of 'exe' commands for unmappings
  for key, val in pairs (maps) do
    table.insert (vim.g.Vm.unmaps, M._unmap (val, false))
  end

  -- Store some mappings that need special handling
  vim.g.Vm.maps.toggle = vim.g.VM_maps["Toggle Mappings"] or (vim.g.Vm.leader.buffer .. "<Space>")
  vim.g.Vm.maps.exit = vim.g.VM_maps["Exit"] or "<Esc>"
  vim.g.Vm.maps.surround = vim.g.VM_maps["Surround"] or "S"
end

function M._build_buffer_maps ()
  -- Run once per buffer. Generate buffer mappings and integrate custom ones.
  vim.b.VM_maps = {}
  vim.b.VM_unmaps = {}
  local check_maps = vim.b.VM_check_mappings or vim.g.VM_check_mappings
  local force_maps = vim.b.VM_force_maps or vim.g.VM_force_maps or {}

  -- Generate base buffer maps
  local maps = vim.fn["vm#maps#all#buffer"] ()

  -- Integrate motions
  for _, m in ipairs (vim.g.Vm.motions) do
    maps["Motion " .. m] = { m, "n" }
  end
  for _, m in ipairs (vim.g.Vm.find_motions) do
    maps["Motion " .. m] = { m, "n" }
  end
  for m, val in pairs (vim.g.Vm.tobj_motions) do
    maps["Motion " .. val] = { m, "n" }
  end

  -- Integrate user operators
  for op, _ in pairs (vim.g.Vm.user_ops) do
    -- Don't map operator if it starts with key that would interfere
    if vim.fn.index ({ "y", "c", "d" }, op:sub (1, 1)) == -1 then
      maps["User Operator " .. op] = { op, "n" }
    end
  end

  -- Integrate custom motions and commands
  for m, val in pairs (vim.g.VM_custom_motions) do
    maps["Motion " .. val] = { m, "n" }
  end
  for m, val in pairs (vim.g.VM_custom_noremaps) do
    maps["Normal! " .. val] = { m, "n" }
  end
  for m, val in pairs (vim.g.VM_custom_remaps) do
    maps["Remap " .. val] = { m, "n" }
  end
  for m, val in pairs (vim.g.VM_custom_commands or {}) do
    maps[m] = { m, "n" }
  end

  -- Integrate custom remappings
  for key, _ in pairs (vim.g.VM_maps) do
    if maps[key] then
      maps[key][1] = vim.g.VM_maps[key]
    end
  end

  -- Generate list of 'exe' commands for map assignment
  for key, val in pairs (maps) do
    local mapping = M._assign (key, val, true, check_maps, force_maps)
    if mapping ~= "" then
      table.insert (vim.b.VM_maps, mapping)
    else
      -- Remove the mapping so it won't be unmapped either
      maps[key] = nil
    end
  end

  -- Generate list of 'exe' commands for unmappings
  for key, val in pairs (maps) do
    table.insert (vim.b.VM_unmaps, M._unmap (val, true))
  end
end

function M._assign (plug, key, buffer, ...)
  -- Create a map command that will be executed
  local k = key[1]
  if k == "" or not k then
    return ""
  end
  local m = key[2]

  -- Check if mapping can be applied (only for buffer mappings)
  if select ("#", ...) > 0 then
    local check_maps = select (1, ...)
    local force_maps = select (2, ...) or {}
    if check_maps and vim.fn.index (force_maps, k) < 0 then
      local K = vim.fn.maparg (k, m, 0, 1)
      if K and not vim.tbl_isempty (K) and K.buffer then
        local b = "b" .. vim.fn.bufnr ("%") .. ": "
        local rhs = K.rhs or "<Lua callback>"
        if m ~= "i" then
          local s = b .. "Could not map: " .. k .. " (" .. plug .. ")  ->  " .. rhs
          table.insert (vim.b.VM_Debug.lines, s)
          return ""
        else
          local s = b .. "Overwritten imap: " .. k .. " (" .. plug .. ")  ->  " .. rhs
          table.insert (vim.b.VM_Debug.lines, s)
        end
      end
    end
  end

  local p = plug:gsub (" ", "-")
  local map_prefix = buffer and "<buffer><nowait> " or "<nowait> "
  return m .. "map " .. map_prefix .. k .. " <Plug>(VM-" .. p .. ")"
end

function M._unmap (key, buffer)
  -- Create an unmap command that will be executed
  local k = key[1]
  if k == "" or not k then
    return ""
  end
  local m = key[2]
  local b = buffer and " <buffer> " or " "
  return "silent! " .. m .. "unmap" .. b .. k
end

function M._check_warnings ()
  -- Notify once per buffer if errors have happened
  if
    vim.g.VM_show_warnings == 1
    and vim.b.VM_Debug
    and vim.b.VM_Debug.lines
    and #vim.b.VM_Debug.lines > 0
    and not vim.b.VM_Debug.maps_warning
  then
    vim.b.VM_Debug.maps_warning = 1
    Funcs.msg ("VM has started with warnings. :VMDebug for more info")
  end
end

-- Export Maps methods
M.Maps = Maps

return M
