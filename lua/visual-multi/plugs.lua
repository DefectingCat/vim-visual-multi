-- lua/visual-multi/plugs.lua
-- Plugs module - mapping definitions for VM
-- Equivalent to autoload/vm/plugs.vim
-- Pure Lua implementation (no Vimscript dependencies)

local M = {}

-- Module references
local State
local Global
local Funcs

-- Buffer-local state references
local V
local v

function M.init ()
  State = require ("visual-multi.state")
  Global = require ("visual-multi.global")
  Funcs = require ("visual-multi.funcs")

  V = State.get ()
  v = V.vars

  return M
end

-- Helper: get VM buffer state
local function get_VM ()
  return vim.b.VM_Selection
end

-- Helper: call VM module method
local function call_VM (module, method, ...)
  local VM = get_VM ()
  if VM and VM[module] and VM[module][method] then
    return VM[module][method] (VM[module], ...)
  end
end

-- ===========================================================================
-- Permanent plugs (non-buffer keys)
-- ===========================================================================

function M.permanent ()
  -- Define <Plug> mappings using Lua callbacks
  local Commands = require ("visual-multi.commands")

  -- Visual find
  vim.keymap.set ("x", "<Plug>(VM-Visual-Find)", function ()
    -- Visual find operator - placeholder for now
    return "<Esc>:lua require('visual-multi.operators').find(1, 1)<CR>"
  end, { expr = true, silent = true })

  -- Add cursor at position
  vim.keymap.set ("n", "<Plug>(VM-Add-Cursor-At-Pos)", function ()
    Commands.add_cursor_at_pos (0)
  end, { silent = true })

  -- Add cursor at word
  vim.keymap.set ("n", "<Plug>(VM-Add-Cursor-At-Word)", function ()
    Commands.add_cursor_at_word (1, 1)
  end, { silent = true })

  -- Add cursor down/up
  vim.keymap.set ("n", "<Plug>(VM-Add-Cursor-Down)", function ()
    Commands.add_cursor_down (0, vim.v.count1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Add-Cursor-Up)", function ()
    Commands.add_cursor_up (0, vim.v.count1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Select-Cursor-Down)", function ()
    Commands.add_cursor_down (1, vim.v.count1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Select-Cursor-Up)", function ()
    Commands.add_cursor_up (1, vim.v.count1)
  end, { silent = true })

  -- Reselect last
  vim.keymap.set ("n", "<Plug>(VM-Reselect-Last)", function ()
    Commands.reselect_last ()
  end, { silent = true })

  -- Select all
  vim.keymap.set ("n", "<Plug>(VM-Select-All)", function ()
    Commands.find_all (0, 1)
  end, { silent = true })

  -- Visual all
  vim.keymap.set ("x", "<Plug>(VM-Visual-All)", function ()
    vim.cmd ([[execute "normal! \<Esc>"]])
    Commands.find_all (1, 1)
  end, { silent = true })

  -- Visual cursors
  vim.keymap.set ("x", "<Plug>(VM-Visual-Cursors)", function ()
    vim.cmd ([[execute "normal! \<Esc>"]])
    Commands.visual_cursors ()
  end, { silent = true })

  -- Visual add
  vim.keymap.set ("x", "<Plug>(VM-Visual-Add)", function ()
    vim.cmd ([[execute "normal! \<Esc>"]])
    Commands.visual_add ()
  end, { silent = true })

  -- Visual reduce
  vim.keymap.set ("x", "<Plug>(VM-Visual-Reduce)", function ()
    local Visual = require ("visual-multi.visual")
    Visual.reduce ()
  end, { silent = true })

  -- Find under (Ctrl-N)
  vim.keymap.set ("n", "<Plug>(VM-Find-Under)", function ()
    Commands.ctrln (vim.v.count1)
  end, { silent = true })

  -- Find subword under (visual mode)
  vim.keymap.set ("x", "<Plug>(VM-Find-Subword-Under)", function ()
    -- Get visual selection and find
    local _, l1, c1, _ = unpack (vim.fn.getpos ("'<"))
    local _, l2, c2, _ = unpack (vim.fn.getpos ("'>"))
    if l1 == l2 then
      local line = vim.fn.getline (l1)
      local word = line:sub (c1, c2)
      vim.cmd ([[execute "normal! \<Esc>"]])
      Commands.find_under (0, 1, word)
    end
  end, { silent = true })

  -- Regex search
  vim.keymap.set ("n", "<Plug>(VM-Start-Regex-Search)", function ()
    return Commands.find_by_regex (1)
  end, { expr = true, silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Slash-Search)", function ()
    return Commands.find_by_regex (3)
  end, { expr = true, silent = true })

  vim.keymap.set ("x", "<Plug>(VM-Visual-Regex)", function ()
    Commands.find_by_regex (2)
    vim.fn.feedkeys ("/", "n")
  end, { silent = true })

  -- Mouse mappings
  vim.keymap.set ("n", "<Plug>(VM-Left-Mouse)", "<LeftMouse>", { silent = true })
  vim.keymap.set (
    "n",
    "<Plug>(VM-Mouse-Cursor)",
    "<LeftMouse><Plug>(VM-Add-Cursor-At-Pos)",
    { silent = true }
  )
  vim.keymap.set (
    "n",
    "<Plug>(VM-Mouse-Word)",
    "<LeftMouse><Plug>(VM-Find-Under)",
    { silent = true }
  )
  vim.keymap.set ("n", "<Plug>(VM-Mouse-Column)", function ()
    Commands.mouse_column ()
  end, { silent = true })

  -- Select motions
  local select_motions = { "h", "j", "k", "l", "w", "W", "b", "B", "e", "E", "ge", "gE", "BBW" }
  for _, m in ipairs (select_motions) do
    vim.keymap.set ("n", "<Plug>(VM-Select-" .. m .. ")", function ()
      Commands.motion (m, vim.v.count1, 1, 0)
    end, { silent = true })
  end
end

-- ===========================================================================
-- Buffer plugs (buffer-local keys)
-- ===========================================================================

function M.buffer ()
  local Commands = require ("visual-multi.commands")
  local Operators = require ("visual-multi.operators")
  local Visual = require ("visual-multi.visual")
  local Icmds = require ("visual-multi.icmds")
  local Edit = require ("visual-multi.edit")
  local Insert = require ("visual-multi.insert")
  local Cursors = require ("visual-multi.cursors")
  local Search = require ("visual-multi.search")
  local Case = require ("visual-multi.special.case")
  local SpecialCommands = require ("visual-multi.special.commands")
  local VM = require ("visual-multi.vm")

  -- Initialize motion lists
  vim.g.Vm.motions = {
    "h",
    "j",
    "k",
    "l",
    "w",
    "W",
    "b",
    "B",
    "e",
    "E",
    ",",
    ";",
    "$",
    "0",
    "^",
    "%",
    "ge",
    "gE",
    "\\|",
  }
  vim.g.Vm.find_motions = { "f", "F", "t", "T" }
  vim.g.Vm.tobj_motions = {
    ["{"] = "{",
    ["}"] = "}",
    ["("] = "(",
    [")"] = ")",
    ["g{"] = "[{",
    ["g}"] = "]}",
    ["g)"] = "])",
    ["g("] = "[(",
  }

  -- Select operator
  vim.keymap.set ("n", "<Plug>(VM-Select-Operator)", function ()
    Operators.select (vim.v.count)
  end, { silent = true })

  -- Find operator
  vim.keymap.set ("n", "<Plug>(VM-Find-Operator)", function ()
    return Operators.find (1, 0)
  end, { expr = true, silent = true })

  -- Visual subtract
  vim.keymap.set ("x", "<Plug>(VM-Visual-Subtract)", function ()
    Visual.subtract (vim.fn.visualmode ())
  end, { silent = true })

  -- Split regions
  vim.keymap.set ("n", "<Plug>(VM-Split-Regions)", function ()
    Visual.split ()
  end, { silent = true })

  -- Remove empty lines
  vim.keymap.set ("n", "<Plug>(VM-Remove-Empty-Lines)", function ()
    Commands.remove_empty_lines ()
  end, { silent = true })

  -- Regex motion
  vim.keymap.set ("n", "<Plug>(VM-Goto-Regex)", function ()
    Commands.regex_motion ("", vim.v.count1, 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Goto-Regex!)", function ()
    Commands.regex_motion ("", vim.v.count1, 1)
  end, { silent = true })

  -- Toggle mappings
  vim.keymap.set ("n", "<Plug>(VM-Toggle-Mappings)", function ()
    local VM = get_VM ()
    if VM and VM.Maps and VM.Maps.mappings_toggle then
      VM.Maps:mappings_toggle ()
    end
  end, { silent = true })

  -- Toggle options
  vim.keymap.set ("n", "<Plug>(VM-Toggle-Multiline)", function ()
    call_VM ("Funcs", "toggle_option", "multiline")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Toggle-Whole-Word)", function ()
    call_VM ("Funcs", "toggle_option", "whole_word")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Toggle-Single-Region)", function ()
    call_VM ("Funcs", "toggle_option", "single_region")
  end, { silent = true })

  -- Search commands
  vim.keymap.set ("n", "<Plug>(VM-Case-Setting)", function ()
    call_VM ("Search", "case")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Rewrite-Last-Search)", function ()
    call_VM ("Search", "rewrite", 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Rewrite-All-Search)", function ()
    call_VM ("Search", "rewrite", 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Read-From-Search)", function ()
    call_VM ("Search", "get_slash_reg")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Add-Search)", function ()
    call_VM ("Search", "get_from_region")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Remove-Search)", function ()
    call_VM ("Search", "remove", 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Remove-Search-Regions)", function ()
    call_VM ("Search", "remove", 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Search-Menu)", function ()
    call_VM ("Search", "menu")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Case-Conversion-Menu)", function ()
    call_VM ("Case", "menu")
  end, { silent = true })

  -- Info and tools
  vim.keymap.set ("n", "<Plug>(VM-Show-Regions-Info)", function ()
    call_VM ("Funcs", "regions_contents")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Show-Registers)", "<cmd>VMRegisters<CR>", { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Tools-Menu)", function ()
    SpecialCommands.menu ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Filter-Regions)", function ()
    SpecialCommands.filter_regions (0, "", 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Regions-To-Buffer)", function ()
    SpecialCommands.regions_to_buffer ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Filter-Lines)", function ()
    SpecialCommands.filter_lines (0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Filter-Lines-Strip)", function ()
    SpecialCommands.filter_lines (1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Merge-Regions)", function ()
    call_VM ("Global", "merge_regions")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Switch-Mode)", function ()
    call_VM ("Global", "change_mode", 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Exit)", function ()
    local noh = ""
    local VM = get_VM ()
    if VM and VM.Vars then
      noh = VM.Vars.noh or ""
    end
    VM.reset ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Undo)", function ()
    Commands.undo ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Redo)", function ()
    Commands.redo ()
  end, { silent = true })

  -- Navigation
  vim.keymap.set ("n", "<Plug>(VM-Goto-Next)", function ()
    Commands.find_next (0, 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Goto-Prev)", function ()
    Commands.find_prev (0, 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Find-Next)", function ()
    Commands.find_next (0, 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Find-Prev)", function ()
    Commands.find_prev (0, 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Seek-Up)", function ()
    Commands.seek_up ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Seek-Down)", function ()
    Commands.seek_down ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Skip-Region)", function ()
    Commands.skip (0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Remove-Region)", function ()
    Commands.skip (1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Remove-Last-Region)", function ()
    call_VM ("Global", "remove_last_region")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Remove-Every-n-Regions)", function ()
    Commands.remove_every_n_regions (vim.v.count)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Show-Infoline)", function ()
    call_VM ("Funcs", "infoline")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-One-Per-Line)", function ()
    call_VM ("Global", "one_region_per_line")
    call_VM ("Global", "update_and_select_region")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Hls)", "<cmd>set hls<CR>", { silent = true })

  -- Motion mappings
  for _, m in ipairs (vim.g.Vm.motions) do
    vim.keymap.set ("n", "<Plug>(VM-Motion-" .. m .. ")", function ()
      Commands.motion (m, vim.v.count1, 0, 0)
    end, { silent = true })

    vim.keymap.set ("n", "<Plug>(VM-Single-Motion-" .. m .. ")", function ()
      Commands.motion (m, vim.v.count1, 0, 1)
    end, { silent = true })
  end

  for _, m in ipairs (vim.g.Vm.find_motions) do
    vim.keymap.set ("n", "<Plug>(VM-Motion-" .. m .. ")", function ()
      Commands.find_motion (m, "")
    end, { silent = true })
  end

  for m, val in pairs (vim.g.Vm.tobj_motions) do
    vim.keymap.set ("n", "<Plug>(VM-Motion-" .. m .. ")", function ()
      Commands.motion (val, vim.v.count1, 0, 0)
    end, { silent = true })
  end

  for _, m in ipairs (vim.g.Vm.select_motions or {}) do
    vim.keymap.set ("n", "<Plug>(VM-Single-Select-" .. m .. ")", function ()
      Commands.motion (m, vim.v.count1, 1, 1)
    end, { silent = true })
  end

  -- Edit commands
  vim.keymap.set ("n", "<Plug>(VM-Shrink)", function ()
    Commands.shrink_or_enlarge (1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Enlarge)", function ()
    Commands.shrink_or_enlarge (0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Merge-To-Eol)", function ()
    Commands.merge_to_beol (1, 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Merge-To-Bol)", function ()
    Commands.merge_to_beol (0, 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-D)", function ()
    Cursors.operation ("d", 0, vim.v.register, "d$")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Y)", function ()
    Cursors.operation ("y", 0, vim.v.register, "y$")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-x)", function ()
    Edit.xdelete ("x", vim.v.count1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-X)", function ()
    Edit.xdelete ("X", vim.v.count1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-J)", function ()
    Edit.run_normal ("J", { count = vim.v.count1, recursive = false })
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-~)", function ()
    Edit.run_normal ("~", { recursive = false })
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-&)", function ()
    Edit.run_normal ("&", { recursive = false, silent = true })
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Del)", function ()
    Edit.run_normal ("x", { count = vim.v.count1, recursive = false })
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Dot)", function ()
    Edit.dot ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Increase)", function ()
    Commands.increase_or_decrease (1, 0, vim.v.count1, false)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Decrease)", function ()
    Commands.increase_or_decrease (0, 0, vim.v.count1, false)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-gIncrease)", function ()
    Commands.increase_or_decrease (1, 0, vim.v.count1, true)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-gDecrease)", function ()
    Commands.increase_or_decrease (0, 0, vim.v.count1, true)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Alpha-Increase)", function ()
    Commands.increase_or_decrease (1, 1, vim.v.count1, false)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Alpha-Decrease)", function ()
    Commands.increase_or_decrease (0, 1, vim.v.count1, false)
  end, { silent = true })

  -- Insert mode keys
  vim.keymap.set ("n", "<Plug>(VM-a)", function ()
    Insert.key ("a")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-A)", function ()
    Insert.key ("A")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-i)", function ()
    Insert.key ("i")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-I)", function ()
    Insert.key ("I")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-o)", function ()
    Insert.key ("o")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-O)", function ()
    Insert.key ("O")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-c)", function ()
    Edit.change (vim.g.Vm.extend_mode, vim.v.count1, vim.v.register, 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-gc)", function ()
    Edit.change (vim.g.Vm.extend_mode, vim.v.count1, vim.v.register, 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-gu)", function ()
    Cursors.operation ("gu", vim.v.count1, vim.v.register)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-gU)", function ()
    Cursors.operation ("gU", vim.v.count1, vim.v.register)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-C)", function ()
    Cursors.operation ("c", 0, vim.v.register, "c$")
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Delete)", function ()
    Edit.delete (vim.g.Vm.extend_mode, vim.v.register, vim.v.count1, 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Delete-Exit)", function ()
    Edit.delete (vim.g.Vm.extend_mode, vim.v.register, vim.v.count1, 1)
    VM.reset ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Replace-Characters)", function ()
    Edit.replace_chars ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Replace)", function ()
    Edit.replace ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Transform-Regions)", function ()
    Edit.replace_expression ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-p-Paste)", function ()
    Edit.paste (vim.g.Vm.extend_mode, 0, vim.g.Vm.extend_mode, vim.v.register)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-P-Paste)", function ()
    Edit.paste (1, 0, vim.g.Vm.extend_mode, vim.v.register)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-p-Paste-Vimreg)", function ()
    Edit.paste (vim.g.Vm.extend_mode, 1, vim.g.Vm.extend_mode, vim.v.register)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-P-Paste-Vimreg)", function ()
    Edit.paste (1, 1, vim.g.Vm.extend_mode, vim.v.register)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Yank)", function ()
    -- Yank operator
    Cursors.operation ("y", 0, vim.v.register)
  end, { silent = true, expr = true })

  vim.keymap.set ("n", "<Plug>(VM-Move-Right)", function ()
    Edit.shift (1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Move-Left)", function ()
    Edit.shift (0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Transpose)", function ()
    Edit.transpose ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Rotate)", function ()
    Edit.rotate ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Duplicate)", function ()
    Edit.duplicate ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Align)", function ()
    Commands.align ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Align-Char)", function ()
    Commands.align_char (vim.v.count1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Align-Regex)", function ()
    Commands.align_regex ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Numbers)", function ()
    Edit.numbers (vim.v.count1, 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Numbers-Append)", function ()
    Edit.numbers (vim.v.count1, 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Zero-Numbers)", function ()
    Edit.numbers (vim.v.count, 0)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Zero-Numbers-Append)", function ()
    Edit.numbers (vim.v.count, 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Run-Dot)", function ()
    Edit.run_normal (".", { count = vim.v.count1, recursive = false })
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Surround)", function ()
    Edit.surround ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Run-Macro)", function ()
    Edit.run_macro ()
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Run-Ex)", function ()
    return Edit.ex ()
  end, { silent = true, expr = true })

  vim.keymap.set ("n", "<Plug>(VM-Run-Last-Ex)", function ()
    Edit.run_ex (vim.g.Vm.last_ex)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Run-Normal)", function ()
    Edit.run_normal (-1, { count = vim.v.count1 })
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Run-Last-Normal)", function ()
    Edit.run_normal (
      vim.g.Vm.last_normal[0],
      { count = vim.v.count1, recursive = vim.g.Vm.last_normal[1] }
    )
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Run-Visual)", function ()
    Edit.run_visual (-1, 1)
  end, { silent = true })

  vim.keymap.set ("n", "<Plug>(VM-Run-Last-Visual)", function ()
    Edit.run_visual (vim.g.Vm.last_visual[0], vim.g.Vm.last_visual[1])
  end, { silent = true })

  -- Insert mode mappings
  local function insert_key (key)
    return function ()
      Icmds.insert (key)
    end
  end

  vim.keymap.set ("i", "<Plug>(VM-I-Arrow-w)", insert_key ("w"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Arrow-b)", insert_key ("b"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Arrow-W)", insert_key ("W"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Arrow-B)", insert_key ("B"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Arrow-e)", insert_key ("e"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Arrow-ge)", insert_key ("ge"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Arrow-E)", insert_key ("E"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Arrow-gE)", insert_key ("gE"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Left-Arrow)", insert_key ("h"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Right-Arrow)", insert_key ("l"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Up-Arrow)", insert_key ("k"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Down-Arrow)", insert_key ("j"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Return)", insert_key ("cr"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-BS)", insert_key ("X"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Paste)", insert_key ("c-v"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlW)", insert_key ("c-w"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlU)", insert_key ("c-u"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlD)", insert_key ("x"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Del)", insert_key ("x"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Home)", insert_key ("0"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-End)", insert_key ("A"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlE)", insert_key ("A"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Ctrl^)", insert_key ("I"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlA)", insert_key ("I"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlB)", insert_key ("h"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlF)", insert_key ("l"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlC)", "<Esc>", { silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-CtrlO)", insert_key ("O"), { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Next)", function ()
    return Icmds.goto_next (1)
  end, { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Prev)", function ()
    return Icmds.goto_next (0)
  end, { expr = true, silent = true })
  vim.keymap.set ("i", "<Plug>(VM-I-Replace)", insert_key ("ins"), { expr = true, silent = true })

  -- Cmdline
  vim.keymap.set ("n", "<Plug>(VM-:)", function ()
    return Commands.regex_reset (":")
  end, { expr = true })

  vim.keymap.set ("n", "<Plug>(VM-/)", function ()
    return Commands.regex_reset ("/")
  end, { expr = true })

  vim.keymap.set ("n", "<Plug>(VM-?)", function ()
    return Commands.regex_reset ("?")
  end, { expr = true })
end

return M
