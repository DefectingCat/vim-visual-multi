-- lua/visual-multi/themes.lua
-- Themes module - highlighting for VM
-- Equivalent to autoload/vm/themes.vim

local M = {}

-- Theme definitions
local Themes = {}

-- Light and dark theme lists
Themes._light = { "sand", "paper", "lightblue1", "lightblue2", "lightpurple1", "lightpurple2" }
Themes._dark =
  { "iceblue", "ocean", "neon", "purplegray", "nord", "codedark", "spacegray", "olive", "sand" }

-- Set up autocommand for ColorScheme
vim.api.nvim_create_autocmd ("ColorScheme", {
  pattern = "*",
  callback = function ()
    M.init ()
  end,
  group = vim.api.nvim_create_augroup ("VM_reset_theme", { clear = true }),
})

function M.init ()
  if not vim.g.Vm then
    return
  end

  if vim.g.VM_highlight_matches and vim.g.VM_highlight_matches ~= "" then
    local out = vim.fn.execute ("highlight Search")
    local hi
    if out:match (" links to ") then
      hi = out:gsub ("^.*links to ", "")
      vim.g.Vm.search_hi = "link Search " .. hi
    else
      hi = out:gsub ("^.*xxx ", "")
      hi = hi:gsub ("%^.", "")
      vim.g.Vm.search_hi = "Search " .. hi
    end

    M.search_highlight ()
  end

  local theme = vim.g.VM_theme or ""

  if theme == "default" then
    vim.cmd ([[
      hi! link VM_Mono ErrorMsg
      hi! link VM_Cursor Visual
      hi! link VM_Extend PmenuSel
      hi! link VM_Insert DiffChange
      hi! link MultiCursor VM_Cursor
    ]])
  elseif Themes[theme] then
    Themes[theme] ()
  end
end

function M.search_highlight ()
  -- Init Search highlight
  local hl = vim.g.VM_highlight_matches
  if hl == "underline" then
    vim.g.Vm.Search = "Search term=underline cterm=underline gui=underline"
  elseif hl == "red" then
    vim.g.Vm.Search = "Search ctermfg=196 guifg=#ff0000"
  elseif hl:match ("^hi!?%s") then
    vim.g.Vm.Search = hl:gsub ("^hi!?", "")
  else
    vim.g.Vm.Search = "Search term=underline cterm=underline gui=underline"
  end
end

function M.load (theme)
  -- Load a theme or set default
  if theme == "" or theme == "default" then
    vim.g.VM_theme = "default"
  elseif not vim.tbl_contains (vim.tbl_keys (Themes), theme) then
    print ("No such theme.")
    return
  else
    vim.g.VM_theme = theme
  end
  M.init ()
end

function M.complete (A, L, P)
  local valid = vim.o.background == "light" and Themes._light or Themes._dark
  local result = {}
  for _, v in ipairs (valid) do
    if v:match (A) then
      table.insert (result, v)
    end
  end
  table.sort (result)
  return result
end

function M.statusline ()
  if not vim.b.visual_multi or vim.b.visual_multi == 0 then
    return ""
  end
  local v = vim.b.VM_Selection.Vars
  local vm = vim.fn.VMInfos ()
  local color = "%#VM_Extend#"
  local single = (vim.b.VM_Selection.Vars.single_region == 1) and "%#VM_Mono# SINGLE " or ""
  local mode

  local ok, result = pcall (function ()
    if v.insert == 1 then
      if vim.b.VM_Selection.Insert.replace then
        mode = "V-R"
        color = "%#VM_Mono#"
      else
        mode = "V-I"
        color = "%#VM_Cursor#"
      end
    else
      local mode_map = {
        n = "V-M",
        v = "V",
        V = "V-L",
        ["\22"] = "V-B", -- <C-v>
      }
      mode = mode_map[vim.fn.mode ()] or "V-M"
    end
  end)
  if not ok then
    mode = "V-M"
  end

  mode = v.statusline_mode or mode
  local patterns = vim.inspect (vm.patterns):sub (1, vim.fn.winwidth (0) - 30)

  return string.format (
    "%s %s %s %s %s%s %s %%=%%l:%%c %s %s",
    color,
    mode,
    "%#VM_Insert#",
    vm.ratio,
    single,
    "%#TabLine#",
    patterns,
    color,
    vm.status .. " "
  )
end

-- ===========================================================================
-- Theme definitions
-- ===========================================================================

function Themes.iceblue ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=24                   guibg=#005f87
    hi! VM_Cursor ctermbg=31    ctermfg=237    guibg=#0087af    guifg=#87dfff
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=180   ctermfg=235    guibg=#dfaf87    guifg=#262626
  ]])
end

function Themes.ocean ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=25                   guibg=#005faf
    hi! VM_Cursor ctermbg=39    ctermfg=239    guibg=#87afff    guifg=#4e4e4e
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=186   ctermfg=239    guibg=#dfdf87    guifg=#4e4e4e
  ]])
end

function Themes.neon ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=26    ctermfg=109    guibg=#005fdf    guifg=#89afaf
    hi! VM_Cursor ctermbg=39    ctermfg=239    guibg=#00afff    guifg=#4e4e4e
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=221   ctermfg=239    guibg=#ffdf5f    guifg=#4e4e4e
  ]])
end

function Themes.lightblue1 ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=153                  guibg=#afdfff
    hi! VM_Cursor ctermbg=111   ctermfg=239    guibg=#87afff    guifg=#4e4e4e
    hi! VM_Insert ctermbg=180   ctermfg=235    guibg=#dfaf87    guifg=#262626
    hi! VM_Mono   ctermbg=167   ctermfg=253    guibg=#df5f5f    guifg=#dadada cterm=bold term=bold gui=bold
  ]])
end

function Themes.lightblue2 ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=117                  guibg=#87dfff
    hi! VM_Cursor ctermbg=111   ctermfg=239    guibg=#87afff    guifg=#4e4e4e
    hi! VM_Insert ctermbg=180   ctermfg=235    guibg=#dfaf87    guifg=#262626
    hi! VM_Mono   ctermbg=167   ctermfg=253    guibg=#df5f5f    guifg=#dadada cterm=bold term=bold gui=bold
  ]])
end

function Themes.purplegray ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=60                   guibg=#544a65
    hi! VM_Cursor ctermbg=103   ctermfg=54     guibg=#8787af    guifg=#5f0087
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=141   ctermfg=235    guibg=#af87ff    guifg=#262626
  ]])
end

function Themes.nord ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=239                  guibg=#434C5E
    hi! VM_Cursor ctermbg=245   ctermfg=24     guibg=#8a8a8a    guifg=#005f87
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=131   ctermfg=235    guibg=#AF5F5F    guifg=#262626
  ]])
end

function Themes.codedark ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=242                  guibg=#264F78
    hi! VM_Cursor ctermbg=239   ctermfg=252    guibg=#6A7D89    guifg=#C5D4DD
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=131   ctermfg=235    guibg=#AF5F5F    guifg=#262626
  ]])
end

function Themes.spacegray ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=237                  guibg=#404040
    hi! VM_Cursor ctermbg=242   ctermfg=239    guibg=Grey50     guifg=#4e4e4e
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=131   ctermfg=235    guibg=#AF5F5F    guifg=#262626
  ]])
end

function Themes.sand ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=143   ctermfg=0      guibg=darkkhaki  guifg=black
    hi! VM_Cursor ctermbg=64    ctermfg=186    guibg=olivedrab  guifg=khaki
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=131   ctermfg=235    guibg=#AF5F5F    guifg=#262626
  ]])
end

function Themes.paper ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=250   ctermfg=16     guibg=#bfbcaf    guifg=black
    hi! VM_Cursor ctermbg=239   ctermfg=188    guibg=#4c4e50    guifg=#d8d5c7
    hi! VM_Insert ctermbg=167   ctermfg=253    guibg=#df5f5f    guifg=#dadada cterm=bold term=bold gui=bold
    hi! VM_Mono   ctermbg=16    ctermfg=188    guibg=#000000    guifg=#d8d5c7
  ]])
end

function Themes.olive ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=3     ctermfg=0      guibg=olive      guifg=black
    hi! VM_Cursor ctermbg=64    ctermfg=186    guibg=olivedrab  guifg=khaki
    hi! VM_Insert ctermbg=239                  guibg=#4c4e50
    hi! VM_Mono   ctermbg=131   ctermfg=235    guibg=#AF5F5F    guifg=#262626
  ]])
end

function Themes.lightpurple1 ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=225                  guibg=#ffdfff
    hi! VM_Cursor ctermbg=183   ctermfg=54     guibg=#dfafff    guifg=#5f0087 cterm=bold term=bold gui=bold
    hi! VM_Insert ctermbg=146   ctermfg=235    guibg=#afafdf    guifg=#262626
    hi! VM_Mono   ctermbg=135   ctermfg=225    guibg=#af5fff    guifg=#ffdfff cterm=bold term=bold gui=bold
  ]])
end

function Themes.lightpurple2 ()
  vim.cmd ([[
    hi! VM_Extend ctermbg=189                  guibg=#dfdfff
    hi! VM_Cursor ctermbg=183   ctermfg=54     guibg=#dfafff    guifg=#5f0087 cterm=bold term=bold gui=bold
    hi! VM_Insert ctermbg=225   ctermfg=235    guibg=#ffdfff    guifg=#262626
    hi! VM_Mono   ctermbg=135   ctermfg=225    guibg=#af5fff    guifg=#ffdfff cterm=bold term=bold gui=bold
  ]])
end

return M
