-- lua/visual-multi/offset.lua
-- Byte offset calculation module
-- Handles conversion between position and byte offsets

local M = {}

-- Convert [line, col] position to byte offset
function M.pos2byte(pos)
  if type(pos) == "table" then
    local line = pos[1]
    local col = pos[2]
    return vim.fn.line2byte(line) + col - 1
  else
    -- Handle mark string like '.', '[', ']'
    local p = vim.fn.getpos(pos)
    return vim.fn.line2byte(p[2]) + math.min(p[3], vim.fn.col({p[2], '$'})) - 1
  end
end

-- Convert byte offset to [line, col] position
function M.byte2pos(offset)
  local line = vim.fn.byte2line(offset)
  local col = offset - vim.fn.line2byte(line) + 1
  return {line, col}
end

-- Get current cursor position as byte offset
function M.curs2byte()
  local pos = vim.fn.getcurpos()
  return vim.fn.line2byte(pos[2]) + pos[3] - 1
end

-- Get line end position as byte offset
function M.line_end_byte(line)
  return vim.fn.line2byte(line + 1) - 1
end

-- Get line start position as byte offset
function M.line_start_byte(line)
  return vim.fn.line2byte(line)
end

-- Calculate byte offset for a region
function M.region_bytes(line, col_start, col_end)
  local start_byte = vim.fn.line2byte(line) + col_start - 1
  local end_byte = vim.fn.line2byte(line) + col_end - 1
  return start_byte, end_byte
end

return M