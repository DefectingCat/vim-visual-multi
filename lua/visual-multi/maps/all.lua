-- lua/visual-multi/maps/all.lua
-- Key -> plug mappings for visual-multi
-- Converted from autoload/vm/maps/all.vim
--
-- Key -> plug:
--       'Select Operator' ->    <Plug>(VM-Select-Operator)
--
-- Contents of lists:
--       [1]: mapping
--       [2]: mode
--
-- When adding a new mapping, the following is required:
--       1. add a <Plug> with a command
--       2. add the reformatted plug name in this file (permanent or buffer section)

local M = {}

-- Base mappings dictionary with all key names and empty mappings
local base = {
  ["Reselect Last"] = { "", "n" },
  ["Add Cursor At Pos"] = { "", "n" },
  ["Add Cursor At Word"] = { "", "n" },
  ["Start Regex Search"] = { "", "n" },
  ["Select All"] = { "", "n" },
  ["Add Cursor Down"] = { "", "n" },
  ["Add Cursor Up"] = { "", "n" },
  ["Visual Regex"] = { "", "x" },
  ["Visual All"] = { "", "x" },
  ["Visual Add"] = { "", "x" },
  ["Visual Find"] = { "", "x" },
  ["Visual Cursors"] = { "", "x" },
  ["Find Under"] = { "", "n" },
  ["Find Subword Under"] = { "", "x" },
  ["Select Cursor Down"] = { "", "n" },
  ["Select Cursor Up"] = { "", "n" },
  ["Select j"] = { "", "n" },
  ["Select k"] = { "", "n" },
  ["Select l"] = { "", "n" },
  ["Select h"] = { "", "n" },
  ["Select w"] = { "", "n" },
  ["Select b"] = { "", "n" },
  ["Select E"] = { "", "n" },
  ["Select BBW"] = { "", "n" },
  ["Mouse Cursor"] = { "", "n" },
  ["Mouse Word"] = { "", "n" },
  ["Mouse Column"] = { "", "n" },
}

--- Default permanent mappings dictionary.
--- @return table mappings dictionary
function M.permanent ()
  -- Copy base mappings
  local maps = {}
  for k, v in pairs (base) do
    maps[k] = { v[1], v[2] }
  end

  local Vm = vim.g.Vm or {}
  local leader_tbl = Vm.leader or {}
  local leader = leader_tbl.default or "\\"
  local visual = leader_tbl.visual or "\\"

  -- map <c-n> in any case
  maps["Find Under"][1] = "<C-n>"
  maps["Find Subword Under"][1] = "<C-n>"

  -- Default to 1 if not set (matching maps.lua initialization)
  local default_mappings = vim.g.VM_default_mappings
  if default_mappings == nil then
    default_mappings = 1
  end

  if default_mappings == 1 then
    maps["Reselect Last"][1] = leader .. "gS"
    maps["Add Cursor At Pos"][1] = leader .. "\\"
    maps["Start Regex Search"][1] = leader .. "/"
    maps["Select All"][1] = leader .. "A"
    maps["Add Cursor Down"][1] = "<C-Down>"
    maps["Add Cursor Up"][1] = "<C-Up>"
    maps["Select l"][1] = "<S-Right>"
    maps["Select h"][1] = "<S-Left>"
    maps["Visual Regex"][1] = visual .. "/"
    maps["Visual All"][1] = visual .. "A"
    maps["Visual Add"][1] = visual .. "a"
    maps["Visual Find"][1] = visual .. "f"
    maps["Visual Cursors"][1] = visual .. "c"
  end

  if vim.g.VM_mouse_mappings == 1 then
    maps["Mouse Cursor"][1] = "<C-LeftMouse>"
    maps["Mouse Word"][1] = "<C-RightMouse>"
    maps["Mouse Column"][1] = "<M-C-RightMouse>"
  end

  return maps
end

--- Default buffer mappings dictionary.
--- @return table mappings dictionary
function M.buffer ()
  local maps = {}

  local Vm = vim.g.Vm or {}
  local leader_tbl = Vm.leader or {}
  local leader = leader_tbl.buffer or "\\"
  local visual = leader_tbl.visual or "\\"

  -- basic
  maps["Switch Mode"] = { "<Tab>", "n" }
  maps["Toggle Single Region"] = { leader .. "<CR>", "n" }

  -- select
  maps["Find Next"] = { "n", "n" }
  maps["Find Prev"] = { "N", "n" }
  maps["Goto Next"] = { "]", "n" }
  maps["Goto Prev"] = { "[", "n" }
  maps["Seek Up"] = { "<C-b>", "n" }
  maps["Seek Down"] = { "<C-f>", "n" }
  maps["Skip Region"] = { "q", "n" }
  maps["Remove Region"] = { "Q", "n" }
  maps["Remove Last Region"] = { leader .. "q", "n" }
  maps["Remove Every n Regions"] = { leader .. "R", "n" }
  maps["Select Operator"] = { "s", "n" }
  maps["Find Operator"] = { "m", "n" }

  -- utility
  maps["Tools Menu"] = { leader .. "`", "n" }
  maps["Show Registers"] = { leader .. "\"", "n" }
  maps["Case Setting"] = { leader .. "c", "n" }
  maps["Toggle Whole Word"] = { leader .. "w", "n" }
  maps["Case Conversion Menu"] = { leader .. "C", "n" }
  maps["Search Menu"] = { leader .. "S", "n" }
  maps["Rewrite Last Search"] = { leader .. "r", "n" }
  maps["Show Infoline"] = { leader .. "l", "n" }
  maps["One Per Line"] = { leader .. "L", "n" }
  maps["Filter Regions"] = { leader .. "f", "n" }
  maps["Toggle Multiline"] = { "M", "n" }

  -- commands
  maps["Undo"] = { "", "n" }
  maps["Redo"] = { "", "n" }
  maps["Surround"] = { "S", "n" }
  maps["Merge Regions"] = { leader .. "m", "n" }
  maps["Transpose"] = { leader .. "t", "n" }
  maps["Rotate"] = { "", "n" }
  maps["Duplicate"] = { leader .. "d", "n" }
  maps["Align"] = { leader .. "a", "n" }
  maps["Split Regions"] = { leader .. "s", "n" }
  maps["Visual Subtract"] = { visual .. "s", "x" }
  maps["Visual Reduce"] = { visual .. "r", "x" }
  maps["Run Normal"] = { leader .. "z", "n" }
  maps["Run Last Normal"] = { leader .. "Z", "n" }
  maps["Run Visual"] = { leader .. "v", "n" }
  maps["Run Last Visual"] = { leader .. "V", "n" }
  maps["Run Ex"] = { leader .. "x", "n" }
  maps["Run Last Ex"] = { leader .. "X", "n" }
  maps["Run Macro"] = { leader .. "@", "n" }
  maps["Run Dot"] = { leader .. ".", "n" }
  maps["Align Char"] = { leader .. "<", "n" }
  maps["Align Regex"] = { leader .. ">", "n" }
  maps["Numbers"] = { leader .. "N", "n" }
  maps["Numbers Append"] = { leader .. "n", "n" }
  maps["Zero Numbers"] = { leader .. "0N", "n" }
  maps["Zero Numbers Append"] = { leader .. "0n", "n" }
  maps["Shrink"] = { leader .. "-", "n" }
  maps["Enlarge"] = { leader .. "+", "n" }
  maps["Goto Regex"] = { leader .. "g", "n" }
  maps["Goto Regex!"] = { leader .. "G", "n" }
  maps["Slash Search"] = { "g/", "n" }

  -- arrows
  maps["Select Cursor Down"] = { "<M-C-Down>", "n" }
  maps["Select Cursor Up"] = { "<M-C-Up>", "n" }
  maps["Add Cursor Down"] = { "<C-Down>", "n" }
  maps["Add Cursor Up"] = { "<C-Up>", "n" }
  maps["Select j"] = { "<S-Down>", "n" }
  maps["Select k"] = { "<S-Up>", "n" }
  maps["Select l"] = { "<S-Right>", "n" }
  maps["Select h"] = { "<S-Left>", "n" }
  maps["Single Select l"] = { "<M-Right>", "n" }
  maps["Single Select h"] = { "<M-Left>", "n" }
  maps["Select e"] = { "", "n" }
  maps["Select ge"] = { "", "n" }
  maps["Select w"] = { "", "n" }
  maps["Select b"] = { "", "n" }
  maps["Select E"] = { "", "n" }
  maps["Select BBW"] = { "", "n" }
  maps["Move Right"] = { "<M-S-Right>", "n" }
  maps["Move Left"] = { "<M-S-Left>", "n" }

  -- insert
  maps["I Arrow w"] = { "<C-Right>", "i" }
  maps["I Arrow b"] = { "<C-Left>", "i" }
  maps["I Arrow W"] = { "<C-S-Right>", "i" }
  maps["I Arrow B"] = { "<C-S-Left>", "i" }
  maps["I Arrow ge"] = { "<C-Up>", "i" }
  maps["I Arrow e"] = { "<C-Down>", "i" }
  maps["I Arrow gE"] = { "<C-S-Up>", "i" }
  maps["I Arrow E"] = { "<C-S-Down>", "i" }
  maps["I Left Arrow"] = { "<Left>", "i" }
  maps["I Right Arrow"] = { "<Right>", "i" }
  maps["I Up Arrow"] = { "<Up>", "i" }
  maps["I Down Arrow"] = { "<Down>", "i" }
  maps["I Return"] = { "<CR>", "i" }
  maps["I BS"] = { "<BS>", "i" }
  maps["I CtrlW"] = { "<C-w>", "i" }
  maps["I CtrlU"] = { "<C-u>", "i" }
  maps["I CtrlD"] = { "<C-d>", "i" }
  maps["I Ctrl^"] = { "<C-^>", "i" }
  maps["I Del"] = { "<Del>", "i" }
  maps["I Home"] = { "<Home>", "i" }
  maps["I End"] = { "<End>", "i" }
  maps["I CtrlB"] = { "<C-b>", "i" }
  maps["I CtrlF"] = { "<C-f>", "i" }
  maps["I CtrlC"] = { "<C-c>", "i" }
  maps["I CtrlO"] = { "<C-o>", "i" }
  maps["I Replace"] = { "<Insert>", "i" }

  -- insert special keys (controlled by g:VM_insert_special_keys)
  local insert_keys = vim.g.VM_insert_special_keys or { "c-v" }
  if type (insert_keys) == "table" then
    if vim.tbl_contains (insert_keys, "c-a") then
      maps["I CtrlA"] = { "<C-a>", "i" }
    end
    if vim.tbl_contains (insert_keys, "c-e") then
      maps["I CtrlE"] = { "<C-e>", "i" }
    end
    if vim.tbl_contains (insert_keys, "c-v") then
      maps["I Paste"] = { "<C-v>", "i" }
    end
  end

  -- edit
  maps["D"] = { "D", "n" }
  maps["Y"] = { "Y", "n" }
  maps["x"] = { "x", "n" }
  maps["X"] = { "X", "n" }
  maps["J"] = { "J", "n" }
  maps["~"] = { "~", "n" }
  maps["&"] = { "&", "n" }
  maps["Del"] = { "<del>", "n" }
  maps["Dot"] = { ".", "n" }
  maps["Increase"] = { "<C-a>", "n" }
  maps["Decrease"] = { "<C-x>", "n" }
  maps["gIncrease"] = { "g<C-a>", "n" }
  maps["gDecrease"] = { "g<C-x>", "n" }
  maps["Alpha Increase"] = { leader .. "<C-a>", "n" }
  maps["Alpha Decrease"] = { leader .. "<C-x>", "n" }
  maps["a"] = { "a", "n" }
  maps["A"] = { "A", "n" }
  maps["i"] = { "i", "n" }
  maps["I"] = { "I", "n" }
  maps["o"] = { "o", "n" }
  maps["O"] = { "O", "n" }
  maps["c"] = { "c", "n" }
  maps["gc"] = { "gc", "n" }
  maps["gu"] = { "gu", "n" }
  maps["gU"] = { "gU", "n" }
  maps["C"] = { "C", "n" }
  maps["Delete"] = { "d", "n" }
  maps["Replace Characters"] = { "r", "n" }
  maps["Replace"] = { "R", "n" }
  maps["Transform Regions"] = { leader .. "e", "n" }
  maps["p Paste"] = { "p", "n" }
  maps["P Paste"] = { "P", "n" }
  maps["Yank"] = { "y", "n" }

  return maps
end

return M
