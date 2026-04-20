-- lua/visual-multi/state.lua
-- State management module - replaces b:VM_Selection

local M = {}

-- Buffer-local state storage
M.buffer_state = {}

-- Fields to sync with vim.b for VimScript compatibility
M.sync_fields = {
  'extend_mode',
  'finding',
  'insert',
  'index',
}

function M.get(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not M.buffer_state[bufnr] then
    return M.create(bufnr)
  end
  return M.buffer_state[bufnr]
end

function M.create(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local state = {
    vars = {
      index = -1,
      ID = 0,
      IDs_list = {},
      eco = 0,
      auto = 0,
      merge = 0,
      insert = 0,
      yanked = 0,
      direction = 1,
      single_region = 0,
      multiline = 0,
      search = '',
      pattern = '',
      oldreg = '',
      dot = '',
      deleting = 0,
      was_region_at_pos = 0,
      find_all_overlap = 0,
      no_search = 0,
      restore_index = nil,
      restore_scroll = 0,
    },
    regions = {},
    bytes = {},
    -- Class instances will be modules
    Funcs = nil,
    Global = nil,
    Search = nil,
    Edit = nil,
    Insert = nil,
    Maps = nil,
    Case = nil,
  }

  M.buffer_state[bufnr] = state

  -- Mark buffer as having VM active
  vim.b[bufnr].visual_multi_active = true

  return state
end

function M.destroy(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Clean up autocmds if registered
  if M.buffer_state[bufnr] and M.buffer_state[bufnr]._autocmd_ids then
    for _, id in ipairs(M.buffer_state[bufnr]._autocmd_ids) do
      vim.api.nvim_del_autocmd(id)
    end
  end

  M.buffer_state[bufnr] = nil
  vim.b[bufnr].visual_multi_active = nil
  vim.b[bufnr].VM_Selection = nil
end

-- Sync state to vim.b for VimScript compatibility
function M.sync_to_vimscript(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = M.get(bufnr)

  for _, field in ipairs(M.sync_fields) do
    vim.b[bufnr]['VM_' .. field] = state.vars[field]
  end
end

-- Sync state from vim.b
function M.sync_from_vimscript(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = M.get(bufnr)

  for _, field in ipairs(M.sync_fields) do
    local v = vim.b[bufnr]['VM_' .. field]
    if v ~= nil then
      state.vars[field] = v
    end
  end
end

-- Register autocmds for state sync
function M.register_autocmds(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = M.get(bufnr)
  state._autocmd_ids = {}

  -- TextChangedI: sync from vim.b
  local id1 = vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = bufnr,
    callback = function()
      M.sync_from_vimscript(bufnr)
    end
  })
  table.insert(state._autocmd_ids, id1)

  -- InsertLeave: sync to vim.b
  local id2 = vim.api.nvim_create_autocmd("InsertLeave", {
    buffer = bufnr,
    callback = function()
      M.sync_to_vimscript(bufnr)
    end
  })
  table.insert(state._autocmd_ids, id2)

  -- BufLeave: backup state
  local id3 = vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      M.backup_state(bufnr)
    end
  })
  table.insert(state._autocmd_ids, id3)

  -- BufEnter: restore state
  local id4 = vim.api.nvim_create_autocmd("BufEnter", {
    buffer = bufnr,
    callback = function()
      M.restore_state(bufnr)
    end
  })
  table.insert(state._autocmd_ids, id4)
end

function M.backup_state(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = M.get(bufnr)

  -- Store minimal state to vim.b for recovery
  vim.b[bufnr].VM_backup_index = state.vars.index
  vim.b[bufnr].VM_backup_extend_mode = vim.g.Vm and vim.g.Vm.extend_mode or 0
end

function M.restore_state(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Restore from backup if available
  if vim.b[bufnr].VM_backup_index then
    local state = M.get(bufnr)
    state.vars.index = vim.b[bufnr].VM_backup_index
  end
end

return M