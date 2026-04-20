-- lua/visual-multi/special/case.lua
-- Case conversion module (based on vim-abolish by Tim Pope)
-- Equivalent to autoload/vm/special/case.vim

local M = {}

-- Module references, populated by M.init()
local State
local Global
local Funcs

-- Buffer-local state references
local V        -- b:VM_Selection (State buffer state)
local v        -- V.vars (plugin variables)
local v_regions -- V.regions (regions table)

-- Cached lambdas (equivalent to VimScript s:R, s:X)
local R_fn     -- returns V.regions
local X_fn     -- returns g:Vm.extend_mode

-- Initialize module with buffer state
function M.init()
  State = require('visual-multi.state')
  Global = require('visual-multi.global')
  Funcs = require('visual-multi.funcs')

  V = State.get()
  v = V.vars
  v_regions = V.regions

  R_fn = function()
    return v_regions
  end

  X_fn = function()
    return vim.g.Vm and vim.g.Vm.extend_mode or 0
  end

  return M
end

-- ===========================================================================
-- Case conversion functions
-- ===========================================================================

-- Convert word to PascalCase
function M.pascal(word)
  return vim.fn.substitute(M.camel(word), '^.', '\\u&', '')
end

-- Convert word to camelCase
function M.camel(word)
  local w = vim.fn.substitute(word, '[.-]', '_', 'g')
  w = vim.fn.substitute(w, ' ', '_', 'g')
  if not w:find('_') and w:match('%l') then
    return vim.fn.substitute(w, '^.', '\\l&', '')
  else
    return vim.fn.substitute(w, '\\C\\(_\\)\\=\\(.\\)', '\\=submatch(1)=="" and string.lower(submatch(2)) or string.upper(submatch(2))', 'g')
  end
end

-- Convert word to snake_case
function M.snake(word)
  local w = vim.fn.substitute(word, '::', '/', 'g')
  w = vim.fn.substitute(w, '\\(\\u\\+\\)\\(\\u\\l\\)', '\\1_\\2', 'g')
  w = vim.fn.substitute(w, '\\(\\l\\|\\d\\)\\(\\u\\)', '\\1_\\2', 'g')
  w = vim.fn.substitute(w, '[.-]', '_', 'g')
  w = vim.fn.substitute(w, ' ', '_', 'g')
  w = string.lower(w)
  return w
end

-- Convert word to SNAKE_UPPERCASE
function M.snake_upper(word)
  return string.upper(M.snake(word))
end

-- Convert word to dash-case
function M.dash(word)
  return vim.fn.substitute(M.snake(word), '_', '-', 'g')
end

-- Convert word to space case
function M.space(word)
  return vim.fn.substitute(M.snake(word), '_', ' ', 'g')
end

-- Convert word to dot.case
function M.dot(word)
  return vim.fn.substitute(M.snake(word), '_', '.', 'g')
end

-- Convert word to Title Case
function M.title(word)
  return vim.fn.substitute(M.space(word), '\\(\\<\\w\\)', '\\=string.upper(submatch(1))', 'g')
end

-- Convert word to lowercase
function M.lower(word)
  return string.lower(word)
end

-- Convert word to UPPERCASE
function M.upper(word)
  return string.upper(word)
end

-- Capitalize first letter
function M.capitalize(word)
  if #word == 0 then return word end
  return string.upper(word:sub(1, 1)) .. string.lower(word:sub(2))
end

-- ===========================================================================
-- Interactive menu
-- ===========================================================================

-- Show interactive menu for case conversion
function M.menu()
  local verbose = vim.g.VM_verbose_commands or 0

  if verbose ~= 0 then
    vim.cmd('echohl WarningMsg | echo "\\tCase Conversion\\n---------------------------------"')
    vim.cmd('echohl WarningMsg | echo "u         " | echohl Type | echon "lowercase"       | echohl None')
    vim.cmd('echohl WarningMsg | echo "U         " | echohl Type | echon "UPPERCASE"       | echohl None')
    vim.cmd('echohl WarningMsg | echo "C         " | echohl Type | echon "Capitalize"      | echohl None')
    vim.cmd('echohl WarningMsg | echo "t         " | echohl Type | echon "Title Case"      | echohl None')
    vim.cmd('echohl WarningMsg | echo "c         " | echohl Type | echon "camelCase"       | echohl None')
    vim.cmd('echohl WarningMsg | echo "P         " | echohl Type | echon "PascalCase"      | echohl None')
    vim.cmd('echohl WarningMsg | echo "s         " | echohl Type | echon "snake_case"      | echohl None')
    vim.cmd('echohl WarningMsg | echo "S         " | echohl Type | echon "SNAKE_UPPERCASE" | echohl None')
    vim.cmd('echohl WarningMsg | echo "-         " | echohl Type | echon "dash-case"       | echohl None')
    vim.cmd('echohl WarningMsg | echo ".         " | echohl Type | echon "dot.case"        | echohl None')
    vim.cmd('echohl WarningMsg | echo "<space>   " | echohl Type | echon "space case"      | echohl None')
    vim.cmd('echohl WarningMsg | echo "---------------------------------"')
    vim.cmd('echohl Directory  | echo "Enter an option: " | echohl None')
  else
    vim.cmd('echohl Constant | echo "Case conversion: " | echohl None | echon "(u/U/C/t/c/P/s/S/-/./ )"')
  end

  local c = vim.fn.nr2char(vim.fn.getchar())
  local case_map = {
    ['u'] = 'lower',
    ['U'] = 'upper',
    ['C'] = 'capitalize',
    ['t'] = 'title',
    ['c'] = 'camel',
    ['P'] = 'pascal',
    ['s'] = 'snake',
    ['S'] = 'snake_upper',
    ['-'] = 'dash',
    ['k'] = 'remove',
    ['.'] = 'dot',
    [' '] = 'space',
  }

  if case_map[c] then
    M.convert(case_map[c])
  end

  if verbose ~= 0 then
    vim.fn.feedkeys('\\<cr>', 'n')
  end
end

-- ===========================================================================
-- Convert all regions
-- ===========================================================================

-- Convert all regions to the specified case type
-- @param type string: the case conversion type (lower, upper, camel, etc.)
function M.convert(type)
  local regions = R_fn()
  if #regions == 0 then return end

  -- In cursor mode, select word under cursor first
  if X_fn() == 0 then
    -- Call vm#operators#select equivalent
    -- This selects the word under cursor for each region
    local ok, operators = pcall(require, 'visual-multi.operators')
    if ok and operators.select then
      operators.select(1, 'iw')
    end
  end

  local text = {}
  vim.g.Vm = vim.g.Vm or {}
  vim.g.Vm.registers = vim.g.Vm.registers or {}
  vim.g.Vm.registers['"'] = text

  for _, r in ipairs(regions) do
    local converted = M[type](r.txt)
    table.insert(text, converted)
  end

  -- Paste the converted text
  if V.Edit and V.Edit.paste then
    V.Edit.paste(1, 0, 1, '"')
  end
end

return M
