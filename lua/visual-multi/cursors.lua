-- lua/visual-multi/cursors.lua
-- Cursors module - operations at cursors (yank, delete, change)
-- Equivalent to autoload/vm/cursors.vim

local M = {}

-- Module references, populated by M.init()
local State
local Global
local Funcs
local Edit
local Insert

-- Buffer-local state references
local V -- b:VM_Selection (State buffer state)
local v -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)

-- Cached lambdas (equivalent to VimScript s:R, s:X)
local R_fn -- returns V.regions
local X_fn -- returns g:Vm.extend_mode

-- Recursive operations flag
local recursive

function M.init ()
  State = require ("visual-multi.state")
  Global = require ("visual-multi.global")
  Funcs = require ("visual-multi.funcs")
  Edit = require ("visual-multi.edit")
  Insert = require ("visual-multi.insert")

  V = State.get ()
  v = V.vars
  v_regions = V.regions

  R_fn = function ()
    return v_regions
  end

  X_fn = function ()
    return vim.g.Vm and vim.g.Vm.extend_mode or 0
  end

  -- Initialize Global module first
  Global.init ()

  recursive = vim.g.VM_recursive_operations_at_cursors or 1
  Global.cursor_mode ()

  return M
end

-- ===========================================================================
-- Operations at cursors (yank, delete, change)
-- ===========================================================================

function M.operation (op, n, register, ...)
  -- Operations at cursors (yank, delete, change)
  M.init ()
  local reg = register
  local oper = op

  -- Shortcut for command in a:1
  if select ("#", ...) > 0 then
    M._process (oper, select (1, ...), reg, 0)
    return
  end

  Funcs.msg ("[VM] ")

  -- Starting string
  local M_cmd = (n > 1 and n or "") .. (reg == v.def_reg and "" or "\"" .. reg) .. oper

  -- Preceding count
  local count = n > 1 and n or 1

  print (M_cmd)

  -- Read characters to complete the command
  while true do
    local c = vim.fn.nr2char (vim.fn.getchar ())

    -- Check for user operations
    local user_ops = vim.g.Vm.user_ops or {}
    local is_user_op = user_ops[M_cmd .. c] ~= nil

    if is_user_op then
      -- Let the entered characters be our operator
      print (c)
      M_cmd = M_cmd .. c
      oper = M_cmd
      if not user_ops[M_cmd] then
        -- Accepts a regular text object
        goto continue
      else
        -- Accepts a specific number of any characters
        local chars2read = user_ops[M_cmd]
        while chars2read > 0 do
          c = vim.fn.nr2char (vim.fn.getchar ())
          print (c)
          M_cmd = M_cmd .. c
          chars2read = chars2read - 1
        end
        break
      end
    elseif M._double (c) then
      print (c)
      M_cmd = M_cmd .. c
      c = vim.fn.nr2char (vim.fn.getchar ())
      print (c)
      M_cmd = M_cmd .. c
      break
    elseif oper == "c" and c:lower () == "r" then
      print (c)
      M_cmd = M_cmd .. c
      c = vim.fn.nr2char (vim.fn.getchar ())
      print (c)
      M_cmd = M_cmd .. c
      break
    elseif oper == "c" and c:lower () == "s" then
      print (c)
      M_cmd = M_cmd .. c
      c = vim.fn.nr2char (vim.fn.getchar ())
      print (c)
      M_cmd = M_cmd .. c
      c = vim.fn.nr2char (vim.fn.getchar ())
      print (c)
      M_cmd = M_cmd .. c
      break
    elseif oper == "y" and c:lower () == "s" then
      print (c)
      M_cmd = M_cmd .. c
      c = vim.fn.nr2char (vim.fn.getchar ())
      print (c)
      M_cmd = M_cmd .. c
      if M._double (c) then
        c = vim.fn.nr2char (vim.fn.getchar ())
        print (c)
        M_cmd = M_cmd .. c
      end
      c = vim.fn.nr2char (vim.fn.getchar ())
      print (c)
      if c == "<" or c == "t" then
        vim.cmd ("redraw")
        local tag = V.Edit.surround_tags ()
        if tag == "" then
          print (" ...Aborted")
          return
        else
          M_cmd = M_cmd .. tag
          print (c)
          break
        end
      else
        M_cmd = M_cmd .. c
        print (c)
        break
      end
    elseif oper == "d" and c == "s" then
      print (c)
      M_cmd = M_cmd .. c
      c = vim.fn.nr2char (vim.fn.getchar ())
      print (c)
      M_cmd = M_cmd .. c
      break
    elseif M._single (c) then
      print (c)
      M_cmd = M_cmd .. c
      break
    elseif tonumber (c) and tonumber (c) > 0 then
      print (c)
      M_cmd = M_cmd .. c

    -- If the entered char is the last character of the operator
    elseif oper:sub (-1) == c then
      print (c)
      M_cmd = M_cmd .. "_"
      break
    else
      print (" ...Aborted")
      return
    end

    ::continue::
  end

  M._process (oper, M_cmd, reg, count)
end

-- ===========================================================================
-- Process the whole command
-- ===========================================================================

function M._process (op, M_cmd, reg, n)
  -- Process the whole command
  v.dot = M_cmd
  v.deleting = op == "d" or op == "c"

  if op == "d" then
    M._delete_at_cursors (M_cmd, reg, n)
  elseif op == "c" then
    M._change_at_cursors (M_cmd, reg, n)
  elseif op == "y" then
    M._yank_at_cursors (M_cmd, reg, n)
  else
    -- Custom operator: pass mapping as-is
    Edit.run_normal (M_cmd, { count = n, recursive = 1 })
  end
end

-- ===========================================================================
-- Parse command helper
-- @param M_cmd: the whole command
-- @param r: the register
-- @param n: count that comes before the operator
-- @param op: the operator
-- Returns: { text object, count }
-- ===========================================================================

function M._parse_cmd (M_cmd, r, n, op)
  -- Parse command, so that the exact count is found

  -- Remove register
  local Cmd = M_cmd:gsub (r, "")

  -- What comes after operator
  local Obj = Cmd:gsub ("^%d*" .. op .. "(.*)$", "%1")

  -- If object is n/N, ensure there is a search pattern
  if Obj:lower () == "n" and vim.fn.getreg ("/") == "" then
    vim.fn.setreg ("/", v.oldsearch[1])
  end

  -- Count that comes after operator
  local x = Obj:match ("^%d") and Obj:gsub ("^%d.*", "") or 0
  if x and tonumber (x) > 0 then
    Obj = Obj:gsub ("^" .. x, "")
  end

  -- Final count
  local final_n = n
  local N
  if x and tonumber (x) > 0 then
    N = final_n * tonumber (x)
  elseif n > 1 then
    N = n
  else
    N = 1
  end
  N = N > 1 and N or ""

  -- If the text object is the last character of the operator
  if Obj == op:sub (-1) then
    Obj = "_"
  end

  return { Obj, N }
end

-- ===========================================================================
-- Delete at cursors
-- ===========================================================================

function M._delete_at_cursors (M_cmd, reg, n)
  -- Delete operation at cursors
  local Cmd = M_cmd

  -- ds surround
  if Cmd:sub (1, 2) == "ds" then
    Edit.run_normal (Cmd)
    return
  end

  local parsed = M._parse_cmd (Cmd, "\"" .. reg, n, "d")
  local Obj = parsed[1]
  local N = parsed[2]

  -- For D, d$, dd: ensure there is only one region per line
  if Obj == "$" or Obj == "_" then
    Global.one_region_per_line ()
  end

  -- Use default register, pass register in options
  Edit.run_normal ("d" .. Obj, { count = N, store = reg, recursive = recursive })
  Global.reorder_regions ()
  Global.merge_regions ()
end

-- ===========================================================================
-- Yank at cursors
-- ===========================================================================

function M._yank_at_cursors (M_cmd, reg, n)
  -- Yank operation at cursors
  local Cmd = M_cmd

  -- ys surround
  if Cmd:sub (1, 2):lower () == "ys" then
    Edit.run_normal (Cmd)
    return
  end

  -- Reset dot for yank command
  v.dot = ""

  Global.change_mode ()

  local parsed = M._parse_cmd (Cmd, "\"" .. reg, n, "y")
  local Obj = parsed[1]
  local N = parsed[2]

  -- For Y, y$, yy, ensure there is only one region per line
  if Obj == "$" or Obj == "_" then
    Global.one_region_per_line ()
  end

  Edit.run_normal ("y" .. Obj, { count = N, store = reg, vimreg = 1 })
end

-- ===========================================================================
-- Change at cursors
-- ===========================================================================

function M._change_at_cursors (M_cmd, reg, n)
  -- Change operation at cursors
  local Cmd = M_cmd

  -- cs surround
  if Cmd:sub (1, 2):lower () == "cs" then
    Edit.run_normal (Cmd)
    return
  end

  -- cr coerce (vim-abolish)
  if Cmd:sub (1, 2):lower () == "cr" then
    vim.fn.feedkeys ("<Plug>(VM-Run-Normal)" .. Cmd .. "<cr>")
    return
  end

  local parsed = M._parse_cmd (Cmd, "\"" .. reg, n, "c")
  local Obj = parsed[1]
  local N = parsed[2]

  -- Convert w,W to e,E (if motions)
  if Obj == "w" then
    Obj = "e"
    v.dot = v.dot:gsub ("w", "e")
  elseif Obj == "W" then
    Obj = "E"
    v.dot = v.dot:gsub ("W", "E")
  end

  -- For c$, cc, ensure there is only one region per line
  if Obj == "$" or Obj == "_" then
    Global.one_region_per_line ()
  end

  -- Replace c with d because we're doing delete followed by insert
  Obj = Obj:gsub ("^c", "d")

  -- Use _ register unless a register has been specified
  local use_reg = reg ~= v.def_reg and reg or "_"

  if Obj == "_" then
    require ("visual-multi.commands").motion ("^", 1, 0, 0)
    require ("visual-multi.operators").select (1, "$")
    v.changed_text = Edit.delete (1, use_reg, 1, 0)
    Insert.key ("i")
  elseif vim.fn.index ({ "ip", "ap" }, Obj) >= 0 then
    Edit.run_normal ("d" .. Obj, { count = N, store = use_reg, recursive = recursive })
    Insert.key ("O")
  elseif recursive and vim.fn.index (require ("visual-multi.comp").add_line (), Obj) >= 0 then
    Edit.run_normal ("d" .. Obj, { count = N, store = use_reg })
    Insert.key ("O")
  elseif Obj == "$" then
    require ("visual-multi.operators").select (1, "$")
    v.changed_text = Edit.delete (1, use_reg, 1, 0)
    Insert.key ("i")
  elseif Obj == "l" then
    Global.extend_mode ()
    if N and tonumber (N) > 1 then
      require ("visual-multi.commands").motion ("l", tonumber (N) - 1, 0, 0)
    end
    vim.fn.feedkeys ("\"" .. use_reg .. "c")
  elseif M._forward (Obj) or (M._ia (Obj) and not M._inside (Obj)) then
    require ("visual-multi.operators").select (1, N .. Obj)
    vim.fn.feedkeys ("\"" .. use_reg .. "c")
  else
    Edit.run_normal ("d" .. Obj, { count = N, store = use_reg, recursive = recursive })
    Global.merge_regions ()
    Insert.key ("i")
  end
end

-- ===========================================================================
-- Lambda helpers (motion/text object classification)
-- ===========================================================================

-- Motions that move the cursor forward
function M._forward (c)
  return vim.fn.index (vim.fn.split ("weWE%", "\\zs"), c) >= 0
end

-- Text objects starting with 'i' or 'a'
function M._ia (c)
  return vim.fn.index ({ "i", "a" }, c:sub (1, 1)) >= 0
end

-- Inside brackets/quotes/tags
function M._inside (c)
  if c:sub (1, 1) ~= "i" then
    return false
  end
  local inner = c:sub (2, 2)
  local valid_inner = vim.fn.split ("bBt[](){}\"" .. "'" .. "`<>", "\\zs")
  -- Also check comp.iobj()
  local iobj = require ("visual-multi.comp").iobj ()
  return vim.fn.index (valid_inner, inner) >= 0 or vim.fn.index (iobj, inner) >= 0
end

-- Single character motions
function M._single (c)
  return vim.fn.index (vim.fn.split ("hljkwebWEB$^0{}()%nN_", "\\zs"), c) >= 0
end

-- Motions that expect a second character
function M._double (c)
  return vim.fn.index (vim.fn.split ("iafFtTg", "\\zs"), c) >= 0
end

return M
