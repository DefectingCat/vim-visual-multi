-- lua/visual-multi/variables.lua
-- Variables module - set/reset vim variables for VM
-- Equivalent to autoload/vm/variables.vim

local M = {}

-- Module references
local State
local Funcs

-- Buffer-local state references
local V
local v

function M.set ()
  local F = V.Funcs
  local vars = V.vars

  -- Disable folding, but keep winline
  if vim.o.foldenable then
    F.Scroll.get (1)
    vars.oldfold = 1
    vim.o.foldenable = false
    F.Scroll.restore ()
  end

  local case_setting = vim.g.VM_case_setting or ""
  if case_setting:lower () == "smart" then
    vim.o.smartcase = true
    vim.o.ignorecase = true
  elseif case_setting:lower () == "sensitive" then
    vim.o.smartcase = false
    vim.o.ignorecase = false
  elseif case_setting:lower () == "ignore" then
    vim.o.smartcase = false
    vim.o.ignorecase = true
  end

  -- Force default register
  vim.o.clipboard = ""

  -- Disable conceal
  local comp = require ("visual-multi.comp")
  vim.wo.conceallevel = comp.conceallevel () and 0 or vim.wo.conceallevel
  vim.wo.concealcursor = ""

  vim.o.virtualedit = "onemore"
  vim.o.whichwrap = "h,l,<,>"
  vim.o.lazyredraw = true

  local cmdheight = vim.g.VM_cmdheight or 1
  if cmdheight > 1 then
    vim.o.cmdheight = cmdheight
  end
end

function M.init ()
  local F = V.Funcs
  local vars = V.vars

  -- Init search
  vars.def_reg = F.default_reg ()
  vars.oldreg = F.get_reg ()
  vars.oldregs_1_9 = F.get_regs_1_9 ()
  vars.oldsearch = { vim.fn.getreg ("/"), vim.fn.getregtype ("/") }
  vars.noh = not vim.v.hlsearch and "noh|" or ""

  -- Store old vars
  vars.oldhls = vim.o.hlsearch
  vars.oldvirtual = vim.o.virtualedit
  vars.oldwhichwrap = vim.o.whichwrap
  vars.oldlz = vim.o.lazyredraw
  vars.oldch = vim.o.cmdheight
  vars.oldcase = { vim.o.smartcase, vim.o.ignorecase }
  vars.indentkeys = vim.bo.indentkeys
  vars.cinkeys = vim.bo.cinkeys
  vars.synmaxcol = vim.bo.synmaxcol
  vars.oldmatches = vim.fn.getmatches ()
  vars.clipboard = vim.o.clipboard
  vars.textwidth = vim.bo.textwidth
  vars.conceallevel = vim.wo.conceallevel
  vars.concealcursor = vim.wo.concealcursor
  vars.softtabstop = vim.bo.softtabstop
  vars.statusline = vim.o.statusline

  -- Init new vars
  vars.search = {}
  vars.IDs_list = {}
  vars.ID = 0
  vars.index = -1
  vars.direction = 1       -- [0/1]
  vars.nav_direction = 1   -- [0/1]
  vars.auto = 0            -- [0/1]
  vars.silence = 0         -- [0/1]
  vars.eco = 0             -- [0/1]
  vars.single_region = 0   -- [0/1]
  vars.using_regex = 0     -- [0/1]
  vars.multiline = 0       -- [0/1]
  vars.yanked = 0          -- [0/1]
  vars.merge = 0           -- [0/1]
  vars.insert = 0          -- [0/1]
  vars.whole_word = 0      -- [0/1]
  vars.winline = 0         -- [0/1]
  vars.restore_scroll = 0  -- [0/1]
  vars.find_all_overlap = 0 -- [0/1]
  vars.dot = ""
  vars.no_search = 0       -- [0/1]
  vars.visual_regex = 0    -- [0/1]
  vars.use_register = vars.def_reg
  vars.deleting = 0        -- [0/1]
  vars.vmarks = { vim.fn.getpos ("'<"), vim.fn.getpos ("'>") }
end

function M.reset ()
  local vars = V.vars

  if not vars.oldhls then
    vim.o.hlsearch = false
  end

  vim.o.virtualedit = vars.oldvirtual
  vim.o.whichwrap = vars.oldwhichwrap
  vim.o.smartcase = vars.oldcase[1]
  vim.o.ignorecase = vars.oldcase[2]
  vim.o.lazyredraw = vars.oldlz
  vim.o.cmdheight = vars.oldch
  vim.o.clipboard = vars.clipboard

  vim.bo.indentkeys = vars.indentkeys
  vim.bo.cinkeys = vars.cinkeys
  vim.bo.synmaxcol = vars.synmaxcol
  vim.bo.textwidth = vars.textwidth
  vim.bo.softtabstop = vars.softtabstop
  vim.wo.conceallevel = vars.conceallevel
  vim.wo.concealcursor = vars.concealcursor

  if vim.g.VM_set_statusline == nil or vim.g.VM_set_statusline == 2 then
    vim.o.statusline = vars.statusline
  end

  vim.b.VM_skip_reset_once_on_bufleave = nil
end

function M.reset_globals ()
  vim.b.VM_Backup = {}
  vim.b.VM_Selection = {}
  vim.g.Vm.buffer = 0      -- [0/1]
  vim.g.Vm.extend_mode = 0 -- [0/1]
  vim.g.Vm.finding = 0     -- [0/1]
end

-- Initialize module with state
function M.init_state (state)
  V = state
  v = V.vars
end

return M
