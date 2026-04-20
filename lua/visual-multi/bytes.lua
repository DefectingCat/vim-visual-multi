-- lua/visual-multi/bytes.lua
-- Lua replacement for Python vm.py module
-- Handles bytes map operations for region rebuilding

local M = {}

-- Rebuild regions from bytes map
-- Equivalent to py_rebuild_from_map in python/vm.py
function M.rebuild_from_map (bytes_map, range)
  -- Sort byte keys numerically
  local bys = {}
  for key, _ in pairs (bytes_map) do
    table.insert (bys, tonumber (key))
  end
  table.sort (bys)

  -- Filter by range if provided
  if range and #range >= 2 then
    local start = range[1]
    local end_ = range[2]
    bys = vim.tbl_filter (function (b)
      return b >= start and b <= end_
    end, bys)
  end

  if #bys == 0 then
    return {}
  end

  -- Build regions from consecutive bytes
  local regions = {}
  local start_pos = bys[1]
  local end_pos = bys[1]

  for i = 2, #bys do
    local b = bys[i]
    if b == end_pos + 1 then
      -- Consecutive byte, extend region
      end_pos = b
    else
      -- Gap found, create region
      table.insert (regions, { start_pos, end_pos })
      start_pos = b
      end_pos = b
    end
  end

  -- Add final region
  table.insert (regions, { start_pos, end_pos })

  return regions
end

-- Find lines with regions
-- Equivalent to py_lines_with_regions in python/vm.py
function M.lines_with_regions (regions, specific_line, reverse)
  local lines = {}

  for _, r in ipairs (regions) do
    local line = r.l

    -- Skip if not the specific line requested
    if specific_line and specific_line > 0 and line ~= specific_line then
      goto continue
    end

    -- Add region index to this line's list
    lines[line] = lines[line] or {}
    table.insert (lines[line], r.index)

    ::continue::
  end

  -- Sort indices for each line
  for line, indices in pairs (lines) do
    if #indices > 1 then
      if reverse then
        table.sort (indices, function (a, b)
          return a > b
        end)
      else
        table.sort (indices, function (a, b)
          return a < b
        end)
      end
    end
  end

  return lines
end

return M
