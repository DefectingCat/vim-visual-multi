-- lua/visual-multi/commands.lua
-- Commands module - entry point for all VM commands
-- Equivalent to autoload/vm/commands.vim

local M = {}

-- Module references, populated by M.init()
local State
local Global
local Funcs
local Search
local Edit

-- Buffer-local state references
local V -- b:VM_Selection (State buffer state)
local v -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)

-- Cached lambdas (equivalent to VimScript s:R, s:X)
local R_fn -- returns V.regions
local X_fn -- returns g:Vm.extend_mode

function M.init ()
  State = require ("visual-multi.state")
  Global = require ("visual-multi.global")
  Funcs = require ("visual-multi.funcs")
  Search = require ("visual-multi.search")
  Edit = require ("visual-multi.edit")

  V = State.get ()
  v = V.vars
  v_regions = V.regions

  R_fn = function ()
    return v_regions
  end

  X_fn = function ()
    return vim.g.Vm and vim.g.Vm.extend_mode or 0
  end

  v.motion = ""
  return M
end

-- ===========================================================================
-- Initialize buffer for commands
-- @param whole: use word boundaries
-- @param type: 0 if a pattern will be added, 1 if not, 2 if using regex
-- @param extend_mode: 1 if forcing extend mode
-- Returns: 1 if VM was already active
-- ===========================================================================

local function s_init (whole, type, extend_mode)
  if extend_mode then
    vim.g.Vm.extend_mode = 1
  end

  if vim.g.Vm.buffer then
    if v.using_regex then
      M.regex_reset ()
    end
    v.whole_word = whole
    return 1 -- already initialized
  else
    local error = vim.fn["vm#init_buffer"] (type)
    if type (error) == "string" then
      error (error)
    end
    v.whole_word = whole
    return 0
  end
end

-- ===========================================================================
-- Add cursor at position
-- ===========================================================================

function M.add_cursor_at_pos (extend)
  -- Set extend mode if starting
  local already_active = s_init (0, 1, extend or false) == 0
    and vim.g.VM_add_cursor_at_pos_no_mappings == 0

  if already_active == 0 and vim.g.VM_add_cursor_at_pos_no_mappings then
    -- Disable mappings if option set
    if V.Maps and V.Maps.disable then
      V.Maps.disable (1)
    end
  end

  Global.new_cursor (1)
end

-- ===========================================================================
-- Add cursors vertically
-- ===========================================================================

local function first_line ()
  return vim.fn.line (".") == 1
end

local function last_line ()
  return vim.fn.line (".") == vim.fn.line ("$")
end

local function skip_shorter_lines ()
  -- When adding cursors below or above, don't add on shorter lines
  if vim.g.VM_skip_shorter_lines == 1 then
    local vcol = v.vertical_col
    local col = vim.fn.virtcol (".")
    local endline = vim.g.VM_skip_empty_lines == 1 and vim.fn.virtcol ("$")
      or (vim.fn.virtcol ("$") > 1 and vim.fn.virtcol ("$") or 2)

    -- Skip line
    if col < vcol or col == endline then
      return 1
    end
  end
  Global.new_cursor ()
end

local function went_too_far ()
  -- If gone too far, reselect region
  if not Global.region_at_pos () or vim.tbl_isempty (Global.region_at_pos ()) then
    Global.select_region (v.index)
  end
end

function M.add_cursor_down (extend, count)
  -- Add cursors vertically, downwards
  if last_line () then
    return
  end

  s_init (0, 1, X_fn () or extend)
  v.vertical_col = Funcs.get_vertcol ()
  Global.new_cursor ()

  local N = count
  while N > 0 do
    vim.cmd ("normal! j")
    if skip_shorter_lines () == 0 then
      N = N - 1
    end
    if last_line () then
      break
    end
  end

  went_too_far ()
end

function M.add_cursor_up (extend, count)
  -- Add cursors vertically, upwards
  if first_line () then
    return
  end

  s_init (0, 1, X_fn () or extend)
  v.vertical_col = Funcs.get_vertcol ()
  Global.new_cursor ()

  local N = count
  while N > 0 do
    vim.cmd ("normal! k")
    if skip_shorter_lines () == 0 then
      N = N - 1
    end
    if first_line () then
      break
    end
  end

  went_too_far ()
end

-- ===========================================================================
-- Add cursor at word
-- ===========================================================================

function M.add_cursor_at_word (yank, search)
  -- Add a pattern for current word, place cursor at word begin
  s_init (0, 1, 0)

  if yank then
    vim.cmd ("keepjumps normal! viwy`[")
  end
  if search then
    Search.add ()
  end

  local R = Global.new_cursor ()
  R.pat = v.search[1]
  Funcs.restore_reg ()
  return R
end

-- ===========================================================================
-- Find by regex
-- ===========================================================================

function M.find_by_regex (mode)
  -- Entry point for VM regex search
  if not vim.g.Vm.buffer then
    s_init (0, 2, 1)
  end

  v.using_regex = mode
  v.regex_backup = vim.fn.getreg ("/") == "" and "\\%^" or vim.fn.getreg ("/")

  -- If visual regex, reposition cursor to beginning of selection
  if mode == 2 then
    vim.cmd ("keepjumps normal! `<")
  end

  -- Store position for restoration if search aborted
  M._regex_pos = vim.fn.winsaveview ()

  -- Set up command-line mappings for regex mode
  vim.fn.execute ("cnoremap <silent> <buffer> <cr> <cr>:call vm#commands#regex_done()<cr>")
  vim.fn.execute (
    "cnoremap <silent><nowait><buffer> <esc><esc> <C-u><C-r>=b:VM_Selection.Vars.regex_backup<cr><esc>:call vm#commands#regex_abort()<cr>"
  )
  vim.fn.execute (
    "cnoremap <silent><nowait><buffer> <esc> <C-u><C-r>=b:VM_Selection.Vars.regex_backup<cr><esc>:call vm#commands#regex_abort()<cr>"
  )

  Funcs.special_statusline ("VM-REGEX")
  return "/"
end

function M.regex_done ()
  -- Terminate the VM regex mode after entering search pattern
  v.visual_regex = v.using_regex == 2
  local extend_current = v.using_regex == 3
  M.regex_reset ()

  if v.visual_regex then
    Search.get_slash_reg ()
    vim.g.Vm.finding = 1
    vim.cmd ("silent keepjumps normal! gv")
    vim.cmd ("silent normal <Plug>(VM-Visual-Find)")
    return
  elseif extend_current then
    M.regex_motion (vim.fn.getreg ("/"), 1, 0)
    return
  elseif X_fn () == 1 then
    vim.cmd ("silent keepjumps normal! gny`]")
  else
    vim.cmd ("silent keepjumps normal! gny")
  end

  Search.get_slash_reg ()

  if X_fn () == 1 then
    Global.new_region ()
  else
    M.add_cursor_at_word (0, 0)
  end
end

function M.regex_abort ()
  -- Abort the VM regex mode
  vim.fn.winrestview (M._regex_pos)
  M.regex_reset ()

  if #R_fn () == 0 then
    vim.fn.feedkeys ("<esc>")
  else
    Funcs.msg ("Regex search aborted. ")
  end
end

function M.regex_reset (...)
  -- Reset the VM regex mode
  vim.fn.execute ("silent! cunmap <buffer> <cr>")
  vim.fn.execute ("silent! cunmap <buffer> <esc>")
  vim.fn.execute ("silent! cunmap <buffer> <esc><esc>")
  v.using_regex = 0
  if v.statusline_mode then
    v.statusline_mode = nil
  end
  if select ("#", ...) > 0 then
    return select (1, ...)
  end
end

-- ===========================================================================
-- Find commands (Ctrl-N, find under, find all)
-- ===========================================================================

local function is_r ()
  -- Check if cursor is on a region
  return vim.g.Vm.buffer
    and Global.region_at_pos ()
    and not vim.tbl_isempty (Global.region_at_pos ())
end

function M.ctrln (count)
  -- Ctrl-N command: find word under cursor
  s_init (1, 0, 0)
  local no_reselect = vim.g.VM_notify_previously_selected == 2

  if X_fn () == 0 and is_r () then
    local pos_data = vim.fn.getpos (".")
    local pos = { pos_data[2], pos_data[3] }
    vim.fn["vm#operators#select"] (1, "iw")
    Global.update_and_select_region (pos)
  else
    for i = 1, count do
      M.find_under (0, 1, 1)
      if no_reselect and v.was_region_at_pos then
        break
      end
    end
  end
end

function M.find_under (visual, whole, ...)
  -- Generic command that adds word under cursor
  s_init (whole, 0, 1)

  -- Ctrl-N command
  if select ("#", ...) > 0 and is_r () then
    return M.find_next (0, 0)
  end

  -- Yank and create region
  if not visual then
    vim.cmd ("normal! viwy`]")
  end

  -- Replace region if calling on existing region
  if is_r () then
    Global.region_at_pos ().remove ()
  end

  Search.add ()
  local R = Global.new_region ()
  Global.check_multiline (0, R)

  if select ("#", ...) > 0 and visual then
    return Global.region_at_pos ()
  else
    return Global.merge_overlapping (R)
  end
end

function M.find_all (visual, whole)
  -- Find all words under cursor or occurrences of visual selection
  s_init (whole, 0, 1)

  local pos_data = vim.fn.getpos (".")
  local pos = { pos_data[2], pos_data[3] }
  v.eco = 1

  if not visual then
    local R = Global.region_at_pos ()
    if not R or vim.tbl_isempty (R) then
      R = M.find_under (0, whole)
    end
    if R and R.pat then
      Search.update_patterns (R.pat)
    end
  else
    M.find_under (1, whole)
  end

  Search.join ()
  v.nav_direction = 1
  Global.erase_regions ()
  Global.get_all_regions ()

  v.restore_scroll = 1
  return Global.update_map_and_select_region (pos)
end

-- ===========================================================================
-- Find next/previous
-- ===========================================================================

local function get_next ()
  v.nav_direction = 1
  if X_fn () == 1 then
    vim.cmd ("silent keepjumps normal! ngny`]")
    return Global.new_region ()
  else
    vim.cmd ("silent keepjumps normal! ngny`[")
    return M.add_cursor_at_word (0, 0)
  end
end

local function get_prev ()
  v.nav_direction = 0
  if X_fn () == 1 then
    vim.cmd ("silent keepjumps normal! NgNy`]")
    return Global.new_region ()
  else
    vim.cmd ("silent keepjumps normal! NgNy`[")
    return M.add_cursor_at_word (0, 0)
  end
end

local function get_region (next)
  -- Call the needed function and notify if reselecting a region
  if vim.g.VM_notify_previously_selected == 0 then
    local ok, result
    if next then
      ok, result = pcall (get_next)
    else
      ok, result = pcall (get_prev)
    end
    if not ok then
      vim.cmd ("redraw")
      local dir = next and "BOTTOM" or "TOP"
      Funcs.msg (string.format ("Search hit %s without a match for %s", dir, vim.fn.getreg ("/")))
      return Global.select_region_at_pos (".")
    end
    return result
  end

  vim.cmd ("normal! m`")
  print ("\r")
  local R
  if next then
    R = get_next ()
  else
    R = get_prev ()
  end

  if v.was_region_at_pos then
    if vim.g.VM_notify_previously_selected == 2 then
      vim.cmd ("normal! ``")
      Funcs.msg ("Already selected")
      return Global.region_at_pos ()
    end
    Funcs.msg ("Already selected")
  end
  return R
end

local function navigate (force, dir)
  if force or vim.fn.getreg ("/") == "" then
    v.nav_direction = dir
    local r = Global.region_at_pos ()
    local i
    if not r or vim.tbl_isempty (r) then
      i = Global.nearest_region ().index
    else
      i = dir and (r.index + 1) or (r.index - 1)
    end
    Global.select_region (i)
    return 1
  end
end

local function skip ()
  local r = Global.region_at_pos ()
  if not r or vim.tbl_isempty (r) then
    navigate (1, v.nav_direction)
  else
    r.clear ()
  end
end

function M.find_next (skip_flag, nav)
  -- Find next region, always downwards
  if (nav or skip_flag) and Funcs.no_regions () then
    return
  end

  -- Write search pattern if not navigating and no search set
  if X_fn () == 1 and not nav then
    Search.add_if_empty ()
  end

  if not Search.validate () and not nav then
    return
  end

  if navigate (nav, 1) then
    return 0 -- just navigate to next
  elseif skip_flag then
    skip () -- skip current match
  end

  return get_region (1)
end

function M.find_prev (skip_flag, nav)
  -- Find previous region, always upwards
  if (nav or skip_flag) and Funcs.no_regions () then
    return
  end

  -- Write search pattern if not navigating and no search set
  if X_fn () == 1 and not nav then
    Search.add_if_empty ()
  end

  if not Search.validate () and not nav then
    return
  end

  local r = Global.region_at_pos ()
  if not r or vim.tbl_isempty (r) then
    r = Global.select_region (v.index)
  end
  local pos
  if r and not vim.tbl_isempty (r) then
    pos = { r.l, r.a }
  else
    local pos_data = vim.fn.getpos (".")
    pos = { pos_data[2], pos_data[3] }
  end

  if navigate (nav, 0) then
    return 0 -- just navigate to previous
  elseif skip_flag then
    skip () -- skip current match
  end

  -- Move to beginning of current match
  vim.fn.cursor (pos)
  return get_region (0)
end

function M.skip (just_remove)
  -- Skip region and get next, respecting current direction
  if Funcs.no_regions () then
    return
  end

  if just_remove then
    local r = Global.region_at_pos ()
    if r and not vim.tbl_isempty (r) then
      return Global.remove_last_region (r.id)
    end
  elseif v.nav_direction then
    return M.find_next (1, 0)
  else
    return M.find_prev (1, 0)
  end
end

-- ===========================================================================
-- Cycle regions (seek down/up)
-- ===========================================================================

function M.seek_down ()
  local nR = #R_fn ()
  if nR == 0 then
    return
  end

  -- Don't jump down if nothing else to seek
  if Funcs.Scroll.can_see_eof () == 0 then
    local r = Global.region_at_pos ()
    if r and not vim.tbl_isempty (r) and r.index ~= nR - 1 then
      vim.cmd ("keepjumps normal! <C-f>")
    end
  end

  local end_line = vim.fn.getpos (".")[2]
  for _, r in ipairs (R_fn ()) do
    if r.l >= end_line then
      return Global.select_region (r.index)
    end
  end
  return Global.select_region (nR - 1)
end

function M.seek_up ()
  if #R_fn () == 0 then
    return
  end

  -- Don't jump up if nothing else to seek
  if Funcs.Scroll.can_see_bof () == 0 then
    local r = Global.region_at_pos ()
    if r and not vim.tbl_isempty (r) and r.index ~= 0 then
      vim.cmd ("keepjumps normal! <C-b>")
    end
  end

  local end_line = vim.fn.getpos (".")[2]
  local regions = R_fn ()
  for i = #regions, 1, -1 do
    local r = regions[i]
    if r.l <= end_line then
      return Global.select_region (r.index)
    end
  end
  return Global.select_region (0)
end

-- ===========================================================================
-- Motion commands
-- ===========================================================================

local function symbol (motion)
  return vim.fn.index ({ "^", "0", "%", "$" }, motion) >= 0
end

local function horizontal (motion)
  return vim.fn.index ({ "h", "l" }, motion) >= 0
end

local function vertical (motion)
  return vim.fn.index ({ "j", "k" }, motion) >= 0
end

function M.motion (motion, count, select_flag, single)
  -- Entry point for motions in VM
  s_init (0, 1, select_flag)

  -- Create cursor if needed
  if not vim.g.Vm.buffer or Funcs.no_regions () or (single and not is_r ()) then
    Global.new_cursor ()
  end

  if motion == "|" and count <= 1 then
    v.motion = vim.fn.virtcol (".") .. motion
  else
    v.motion = count > 1 and (count .. motion) or motion
  end

  if symbol (motion) then
    v.merge = 1
  end
  if select_flag and X_fn () == 0 then
    vim.g.Vm.extend_mode = 1
  end

  if select_flag and not v.multiline and vertical (motion) then
    Funcs.toggle_option ("multiline")
  end

  M._call_motion (single)
end

function M.merge_to_beol (eol)
  -- Entry point for 0/^/$ motions
  if Funcs.no_regions () then
    return
  end
  Global.cursor_mode ()

  v.motion = eol and "<End>" or "^"
  v.merge = 1
  M._call_motion ()
end

function M.find_motion (motion, char)
  -- Entry point for f/F/t/T motions
  if Funcs.no_regions () then
    return
  end

  if char ~= "" then
    v.motion = motion .. char
  else
    v.motion = motion .. vim.fn.nr2char (vim.fn.getchar ())
  end

  M._call_motion ()
end

function M.regex_motion (regex, count, remove)
  -- Entry point for Goto-Regex motion
  if Funcs.no_regions () then
    return
  end

  local pattern = regex == "" and Funcs.search_chars (count) or regex
  local case_flag = ""
  if vim.g.VM_case_setting == "sensitive" then
    case_flag = "\\C"
  elseif vim.g.VM_case_setting == "ignore" then
    case_flag = "\\c"
  end

  if pattern == "" then
    return Funcs.msg ("Cancel")
  end

  Funcs.Scroll.get ()
  local R = R_fn ()[v.index + 1] -- Lua 1-indexed, v.index is 0-indexed
  local X = X_fn ()
  M._before_move ()

  local regions
  if v.single_region then
    regions = { R }
  else
    regions = R_fn ()
  end

  if v.direction == 1 then
    for _, r in ipairs (regions) do
      vim.fn.cursor (r.L, r.b)
      local endl = v.multiline and regex ~= "" and vim.fn.line ("$") or r.L
      if vim.fn.search (pattern .. case_flag, "z", endl) == 0 then
        if remove then
          r.remove ()
        end
        goto continue_forward
      end
      if X == 1 then
        r.L = vim.fn.getpos (".")[2]
        r.b = vim.fn.getpos (".")[3]
        r.update_region ()
      else
        r.update_cursor_pos ()
      end
      ::continue_forward::
    end
  else
    for _, r in ipairs (regions) do
      vim.fn.cursor (r.l, r.a)
      local endl = v.multiline and regex ~= "" and vim.fn.line ("$") or r.l
      if vim.fn.search (pattern .. case_flag, "b", endl) == 0 then
        if remove then
          r.remove ()
        end
        goto continue_backward
      end
      if X == 1 then
        r.l = vim.fn.getpos (".")[2]
        r.a = vim.fn.getpos (".")[3]
        r.update_region ()
      else
        r.update_cursor_pos ()
      end
      ::continue_backward::
    end
  end

  -- If using slash-search, merge regions
  if regex ~= "" then
    v.merge = 1
    if not remove then
      Global.update_regions ()
    end
  end

  -- Update variables, facing direction, highlighting
  M._after_move (R)
end

-- ===========================================================================
-- Motion event helpers
-- ===========================================================================

function M._call_motion (...)
  if Funcs.no_regions () then
    return
  end
  Funcs.Scroll.get ()
  local R = R_fn ()[v.index + 1]

  local regions
  if select ("#", ...) > 0 and select (1, ...) or v.single_region then
    regions = { R }
  else
    regions = R_fn ()
  end

  M._before_move ()

  for _, r in ipairs (regions) do
    r.move ()
  end

  -- Update variables, facing direction, highlighting
  M._after_move (R)
end

function M._before_move ()
  Global.reset_byte_map (0)
  if X_fn () == 0 then
    v.merge = 1
  end
end

function M._after_move (R)
  v.direction = R.dir
  v.restore_scroll = not v.insert

  if v.merge then
    Global.select_region (R.index)
    Funcs.Scroll.get (1)
    Global.update_and_select_region (R.A)
  else
    Funcs.restore_reg ()
    Global.update_highlight ()
    Global.select_region (R.index)
  end
end

-- ===========================================================================
-- Align commands
-- ===========================================================================

function M.align ()
  if Funcs.no_regions () then
    return
  end
  v.restore_index = v.index
  Funcs.Scroll.get (1)
  Edit.align ()
  Funcs.Scroll.restore ()
end

function M.align_char (count)
  if Funcs.no_regions () then
    return
  end
  Global.cursor_mode ()

  v.restore_index = v.index
  Funcs.Scroll.get (1)
  local n = count
  local s = n > 1 and "s" or ""
  print ("Align with " .. n .. " char" .. s .. " > ")

  local C = {}
  while n > 0 do
    local c = vim.fn.nr2char (vim.fn.getchar ())
    if c == "<esc>" then
      print (" ...Aborted")
      return
    else
      table.insert (C, c)
      n = n - 1
      print (c)
    end
  end

  local search_method = "czp" -- accept at cursor position

  while #C > 0 do
    local c = table.remove (C, 1)

    -- Remove region if match not found
    for _, r in ipairs (R_fn ()) do
      vim.fn.cursor (r.l, r.a)
      if vim.fn.search (c, search_method, r.l) == 0 then
        r.remove ()
        goto continue_align
      end
      r.update_cursor ({ r.l, vim.fn.getpos (".")[3] })
      ::continue_align::
    end

    Edit.align ()
    search_method = "zp" -- don't accept at cursor position
  end
  Funcs.Scroll.restore ()
end

function M.align_regex ()
  if Funcs.no_regions () then
    return
  end
  Global.cursor_mode ()
  v.restore_index = v.index
  Funcs.Scroll.get (1)

  local rx = vim.fn.input ("Align with regex > ")
  if rx == "" then
    print (" ...Aborted")
    return
  end

  for _, r in ipairs (R_fn ()) do
    vim.fn.cursor (r.l, r.a)
    if vim.fn.search (rx, "czp", r.l) == 0 then
      r.remove ()
      goto continue_align_regex
    end
    r.update_cursor ({ r.l, vim.fn.getpos (".")[3] })
    ::continue_align_regex::
  end
  Edit.align ()
  Funcs.Scroll.restore ()
end

-- ===========================================================================
-- Miscellaneous commands
-- ===========================================================================

function M.invert_direction (...)
  -- Invert direction and reselect region
  if Funcs.no_regions () or v.auto then
    return
  end

  for _, r in ipairs (R_fn ()) do
    r.dir = not r.dir
  end

  -- Invert anchor
  if v.direction == 1 then
    v.direction = 0
    for _, r in ipairs (R_fn ()) do
      r.k = r.b
      r.K = r.B
    end
  else
    v.direction = 1
    for _, r in ipairs (R_fn ()) do
      r.k = r.a
      r.K = r.A
    end
  end

  if select ("#", ...) == 0 then
    return
  end
  Global.update_highlight ()
  Global.select_region (v.index)
end

function M.reset_direction (...)
  -- Resets regions facing
  if Funcs.no_regions () or v.auto then
    return
  end

  v.direction = 1
  for _, r in ipairs (R_fn ()) do
    r.dir = 1
    r.k = r.a
    r.K = r.A
  end

  if select ("#", ...) == 0 then
    return
  end
  Global.update_highlight ()
  Global.select_region (v.index)
end

function M.split_lines ()
  -- Split regions so they don't cross line boundaries
  if Funcs.no_regions () then
    return
  end
  Global.split_lines ()
  if vim.g.VM_autoremove_empty_lines == 1 then
    Global.remove_empty_lines ()
  end
  Global.update_and_select_region ()
end

function M.remove_empty_lines ()
  -- Remove selections that consist of empty lines
  Global.remove_empty_lines ()
  Global.update_and_select_region ()
end

function M.visual_cursors ()
  -- Create a column of cursors from visual mode
  s_init (0, 1, 0)
  vim.fn["vm#visual#cursors"] (vim.fn.visualmode ())
end

function M.visual_add ()
  -- Convert a visual selection to a VM selection
  s_init (0, 1, 1)
  vim.fn["vm#visual#add"] (vim.fn.visualmode ())
end

function M.remove_every_n_regions (count)
  -- Remove every n regions
  if Funcs.no_regions () then
    return
  end
  local R = R_fn ()
  local i = 1
  local cnt = count < 2 and 2 or count
  for n = 1, #R do
    if n % cnt == 0 then
      R[n - i].remove ()
      i = i + 1
    end
  end
  Global.update_and_select_region ({ index = 0 })
end

function M.mouse_column ()
  -- Create a column of cursors with the mouse
  s_init (0, 1, 0)
  local start_data = vim.fn.getpos (".")
  local start = { start_data[2], start_data[3] }
  vim.cmd ("normal! <LeftMouse>")
  local end_data = vim.fn.getpos (".")
  local end_pos = { end_data[2], end_data[3] }

  if start[1] < end_pos[1] then
    vim.fn.cursor (start[1], start[2])
    while vim.fn.getpos (".")[2] < end_pos[1] do
      M.add_cursor_down (0, 1)
    end
    if vim.fn.getpos (".")[2] > end_pos[1] then
      M.skip (1)
    end
  else
    vim.fn.cursor (start[1], start[2])
    while vim.fn.getpos (".")[2] > end_pos[1] do
      M.add_cursor_up (0, 1)
    end
    if vim.fn.getpos (".")[2] < end_pos[1] then
      M.skip (1)
    end
  end
end

function M.shrink_or_enlarge (shrink)
  -- Reduce/enlarge selection size by 1
  if Funcs.no_regions () then
    return
  end
  Global.extend_mode ()

  local dir = v.direction

  v.motion = shrink and (dir and "h" or "l") or (dir and "l" or "h")
  M._call_motion ()

  M.invert_direction ()

  v.motion = shrink and (dir and "l" or "h") or (dir and "h" or "l")
  M._call_motion ()

  if v.direction ~= dir then
    M.invert_direction (1)
  end
end

function M.increase_or_decrease (increase, all_types, count, g_flag)
  local oldnr = vim.bo.nrformats
  if all_types then
    vim.opt_local.nrformats:append ("alpha")
  end
  local map = increase and "<c-a>" or "<c-x>"
  Edit.run_normal (map, { count = count, recursive = false, gcount = g_flag })
  if all_types then
    vim.bo.nrformats = oldnr
  end
end

-- ===========================================================================
-- Reselect last regions, undo, redo
-- ===========================================================================

function M.reselect_last ()
  local was_active = s_init (0, 1, 0)
  local last_backup = vim.b.VM_LastBackup
  if not last_backup or not last_backup.regions or #last_backup.regions == 0 then
    return Funcs.exit ("No regions to restore")
  end

  if was_active and X_fn () == 0 then
    Global.erase_regions ()
  elseif was_active then
    return Funcs.msg ("Not in extend mode.")
  end

  local ok, err = pcall (function ()
    for _, r in ipairs (vim.b.VM_LastBackup.regions) do
      vim.fn["vm#region#new"] (1, r.A, r.B)
    end
    vim.g.Vm.extend_mode = vim.b.VM_LastBackup.extend
    v.search = vim.b.VM_LastBackup.search
  end)
  if not ok then
    return Funcs.exit ("Error while restoring regions.")
  end

  Global.update_and_select_region ({ index = vim.b.VM_LastBackup.index })
end

function M.undo ()
  local first = vim.b.VM_Backup.first
  local ticks = vim.b.VM_Backup.ticks
  local idx = vim.fn.index (ticks, vim.b.VM_Backup.last)

  local ok, err = pcall (function ()
    if idx <= 0 then
      if vim.fn.undotree ().seq_cur ~= first then
        vim.cmd ("undo " .. first)
        Global.restore_regions (0)
      end
    else
      vim.cmd ("undo " .. ticks[idx])
      Global.restore_regions (idx)
      vim.b.VM_Backup.last = ticks[idx]
    end
  end)
  if not ok then
    Funcs.msg ("[visual-multi] errors during undo operation.")
  end
end

function M.redo ()
  local ticks = vim.b.VM_Backup.ticks
  local idx = vim.fn.index (ticks, vim.b.VM_Backup.last)

  local ok, err = pcall (function ()
    if idx ~= #ticks - 1 then
      vim.cmd ("undo " .. ticks[idx + 1])
      Global.restore_regions (idx + 1)
      vim.b.VM_Backup.last = ticks[idx + 1]
    end
  end)
  if not ok then
    Funcs.msg ("[visual-multi] errors during redo operation.")
  end
end

return M
