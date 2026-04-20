-- lua/visual-multi/plugs.lua
-- Plugs module - mapping definitions for VM
-- Equivalent to autoload/vm/plugs.vim

local M = {}

-- Module references
local State
local Global
local Funcs

-- Buffer-local state references
local V
local v

function M.init()
  State = require('visual-multi.state')
  Global = require('visual-multi.global')
  Funcs = require('visual-multi.funcs')

  V = State.get()
  v = V.vars

  return M
end

-- ===========================================================================
-- Permanent plugs (non-buffer keys)
-- ===========================================================================

function M.permanent()
  -- Plugs and mappings for non <buffer> keys
  vim.cmd([[
    xmap <expr><silent>     <Plug>(VM-Visual-Find)             vm#operators#find(1, 1)

    nnoremap <silent>       <Plug>(VM-Add-Cursor-At-Pos)       :call vm#commands#add_cursor_at_pos(0)<cr>
    nnoremap <silent>       <Plug>(VM-Add-Cursor-At-Word)      :call vm#commands#add_cursor_at_word(1, 1)<cr>
    nnoremap <silent>       <Plug>(VM-Add-Cursor-Down)         :<C-u>call vm#commands#add_cursor_down(0, v:count1)<cr>
    nnoremap <silent>       <Plug>(VM-Add-Cursor-Up)           :<C-u>call vm#commands#add_cursor_up(0, v:count1)<cr>
    nnoremap <silent>       <Plug>(VM-Select-Cursor-Down)      :<C-u>call vm#commands#add_cursor_down(1, v:count1)<cr>
    nnoremap <silent>       <Plug>(VM-Select-Cursor-Up)        :<C-u>call vm#commands#add_cursor_up(1, v:count1)<cr>

    nnoremap <silent>       <Plug>(VM-Reselect-Last)           :call vm#commands#reselect_last()<cr>
    nnoremap <silent>       <Plug>(VM-Select-All)              :call vm#commands#find_all(0, 1)<cr>
    xnoremap <silent><expr> <Plug>(VM-Visual-All)              <sid>Visual('all')
    xnoremap <silent>       <Plug>(VM-Visual-Cursors)          <Esc>:call vm#commands#visual_cursors()<cr>
    xnoremap <silent>       <Plug>(VM-Visual-Add)              <Esc>:call vm#commands#visual_add()<cr>
    xnoremap <silent>       <Plug>(VM-Visual-Reduce)           :<c-u>call vm#visual#reduce()<cr>

    nnoremap <silent>       <Plug>(VM-Find-Under)              :<c-u>call vm#commands#ctrln(v:count1)<cr>
    xnoremap <silent><expr> <Plug>(VM-Find-Subword-Under)      <sid>Visual('under')

    nnoremap <silent>       <Plug>(VM-Start-Regex-Search)      @=vm#commands#find_by_regex(1)<cr>
    nnoremap <silent>       <Plug>(VM-Slash-Search)            @=vm#commands#find_by_regex(3)<cr>
    xnoremap <silent>       <Plug>(VM-Visual-Regex)            :call vm#commands#find_by_regex(2)<cr>:call feedkeys('/', 'n')<cr>

    nnoremap <silent>       <Plug>(VM-Left-Mouse)              <LeftMouse>
    nmap     <silent>       <Plug>(VM-Mouse-Cursor)            <Plug>(VM-Left-Mouse)<Plug>(VM-Add-Cursor-At-Pos)
    nmap     <silent>       <Plug>(VM-Mouse-Word)              <Plug>(VM-Left-Mouse)<Plug>(VM-Find-Under)
    nnoremap <silent>       <Plug>(VM-Mouse-Column)            :call vm#commands#mouse_column()<cr>
  ]])

  -- Select motions
  vim.g.Vm.select_motions = {'h', 'j', 'k', 'l', 'w', 'W', 'b', 'B', 'e', 'E', 'ge', 'gE', 'BBW'}
  for _, m in ipairs(vim.g.Vm.select_motions) do
    vim.cmd("nnoremap <silent> <Plug>(VM-Select-" .. m .. ") :\\<C-u>call vm#commands#motion('" .. m .. "', v:count1, 1, 0)\\<cr>")
  end
end

-- ===========================================================================
-- Buffer plugs (buffer-local keys)
-- ===========================================================================

function M.buffer()
  -- Plugs and mappings for <buffer> keys
  vim.g.Vm.motions = {'h', 'j', 'k', 'l', 'w', 'W', 'b', 'B', 'e', 'E', ',', ';', '$', '0', '^', '%', 'ge', 'gE', '\\|'}
  vim.g.Vm.find_motions = {'f', 'F', 't', 'T'}
  vim.g.Vm.tobj_motions = {
    ['{'] = '{', ['}'] = '}',
    ['('] = '(', [')'] = ')',
    ['g{'] = '[{', ['g}'] = ']}',
    ['g)'] = '])', ['g('] = '[('
  }

  vim.cmd([[
    nnoremap <silent>       <Plug>(VM-Select-Operator)         :<c-u>call vm#operators#select(v:count)<cr>
    nmap <expr><silent>     <Plug>(VM-Find-Operator)           vm#operators#find(1, 0)

    xnoremap <silent>       <Plug>(VM-Visual-Subtract)         :<c-u>call vm#visual#subtract(visualmode())<cr>
    nnoremap                <Plug>(VM-Split-Regions)           :<c-u>call vm#visual#split()<cr>
    nnoremap <silent>       <Plug>(VM-Remove-Empty-Lines)      :<c-u>call vm#commands#remove_empty_lines()<cr>
    nnoremap <silent>       <Plug>(VM-Goto-Regex)              :<c-u>call vm#commands#regex_motion('', v:count1, 0)<cr>
    nnoremap <silent>       <Plug>(VM-Goto-Regex!)             :<c-u>call vm#commands#regex_motion('', v:count1, 1)<cr>

    nnoremap <silent>       <Plug>(VM-Toggle-Mappings)         :call b:VM_Selection.Maps.mappings_toggle()<cr>
    nnoremap <silent>       <Plug>(VM-Toggle-Multiline)        :call b:VM_Selection.Funcs.toggle_option('multiline')<cr>
    nnoremap <silent>       <Plug>(VM-Toggle-Whole-Word)       :call b:VM_Selection.Funcs.toggle_option('whole_word')<cr>
    nnoremap <silent>       <Plug>(VM-Toggle-Single-Region)    :call b:VM_Selection.Funcs.toggle_option('single_region')<cr>
    nnoremap <silent>       <Plug>(VM-Case-Setting)            :call b:VM_Selection.Search.case()<cr>
    nnoremap <silent>       <Plug>(VM-Rewrite-Last-Search)     :call b:VM_Selection.Search.rewrite(1)<cr>
    nnoremap <silent>       <Plug>(VM-Rewrite-All-Search)      :call b:VM_Selection.Search.rewrite(0)<cr>
    nnoremap <silent>       <Plug>(VM-Read-From-Search)        :call b:VM_Selection.Search.get_slash_reg()<cr>
    nnoremap <silent>       <Plug>(VM-Add-Search)              :call b:VM_Selection.Search.get_from_region()<cr>
    nnoremap <silent>       <Plug>(VM-Remove-Search)           :call b:VM_Selection.Search.remove(0)<cr>
    nnoremap <silent>       <Plug>(VM-Remove-Search-Regions)   :call b:VM_Selection.Search.remove(1)<cr>
    nnoremap <silent>       <Plug>(VM-Search-Menu)             :call b:VM_Selection.Search.menu()<cr>
    nnoremap <silent>       <Plug>(VM-Case-Conversion-Menu)    :call b:VM_Selection.Case.menu()<cr>

    nnoremap <silent>       <Plug>(VM-Show-Regions-Info)       :call b:VM_Selection.Funcs.regions_contents()<cr>
    nnoremap <silent>       <Plug>(VM-Show-Registers)          :VMRegisters<cr>
    nnoremap <silent>       <Plug>(VM-Tools-Menu)              :call vm#special#commands#menu()<cr>
    nnoremap <silent>       <Plug>(VM-Filter-Regions)          :call vm#special#commands#filter_regions(0, '', 1)<cr>
    nnoremap <silent>       <Plug>(VM-Regions-To-Buffer)       :call vm#special#commands#regions_to_buffer()<cr>
    nnoremap <silent>       <Plug>(VM-Filter-Lines)            :call vm#special#commands#filter_lines(0)<cr>
    nnoremap <silent>       <Plug>(VM-Filter-Lines-Strip)      :call vm#special#commands#filter_lines(1)<cr>
    nnoremap <silent>       <Plug>(VM-Merge-Regions)           :call b:VM_Selection.Global.merge_regions()<cr>
    nnoremap <silent>       <Plug>(VM-Switch-Mode)             :call b:VM_Selection.Global.change_mode(1)<cr>
    nnoremap <silent>       <Plug>(VM-Exit)                    :<c-u><C-r>=b:VM_Selection.Vars.noh<CR>call vm#reset()<cr>
    nnoremap <silent>       <Plug>(VM-Undo)                    :call vm#commands#undo()<cr>
    nnoremap <silent>       <Plug>(VM-Redo)                    :call vm#commands#redo()<cr>

    nnoremap <silent>       <Plug>(VM-Goto-Next)               :call vm#commands#find_next(0, 1)<cr>
    nnoremap <silent>       <Plug>(VM-Goto-Prev)               :call vm#commands#find_prev(0, 1)<cr>
    nnoremap <silent>       <Plug>(VM-Find-Next)               :call vm#commands#find_next(0, 0)<cr>
    nnoremap <silent>       <Plug>(VM-Find-Prev)               :call vm#commands#find_prev(0, 0)<cr>
    nnoremap <silent>       <Plug>(VM-Seek-Up)                 :call vm#commands#seek_up()<cr>
    nnoremap <silent>       <Plug>(VM-Seek-Down)               :call vm#commands#seek_down()<cr>
    nnoremap <silent>       <Plug>(VM-Skip-Region)             :call vm#commands#skip(0)<cr>
    nnoremap <silent>       <Plug>(VM-Remove-Region)           :call vm#commands#skip(1)<cr>
    nnoremap <silent>       <Plug>(VM-Remove-Last-Region)      :call b:VM_Selection.Global.remove_last_region()<cr>
    nnoremap <silent>       <Plug>(VM-Remove-Every-n-Regions)  :<c-u>call vm#commands#remove_every_n_regions(v:count)<cr>
    nnoremap <silent>       <Plug>(VM-Show-Infoline)           :call b:VM_Selection.Funcs.infoline()<cr>
    nnoremap <silent>       <Plug>(VM-One-Per-Line)            :call b:VM_Selection.Global.one_region_per_line()<bar>call b:VM_Selection.Global.update_and_select_region()<cr>

    nnoremap <silent>       <Plug>(VM-Hls)                     :set hls<cr>
  ]])

  -- Motion mappings
  for _, m in ipairs(vim.g.Vm.motions) do
    vim.cmd("nnoremap <silent> <Plug>(VM-Motion-" .. m .. ") :\\<C-u>call vm#commands#motion('" .. m .. "', v:count1, 0, 0)\\<cr>")
    vim.cmd("nnoremap <silent> <Plug>(VM-Single-Motion-" .. m .. ") :\\<C-u>call vm#commands#motion('" .. m .. "',v:count1, 0, 1)\\<cr>")
  end

  for _, m in ipairs(vim.g.Vm.find_motions) do
    vim.cmd("nnoremap <silent> <Plug>(VM-Motion-" .. m .. ") :call vm#commands#find_motion('" .. m .. "', '')\\<cr>")
  end

  local tobj = vim.g.Vm.tobj_motions
  for m, val in pairs(tobj) do
    vim.cmd("nnoremap <silent> <Plug>(VM-Motion-" .. m .. ") :\\<C-u>call vm#commands#motion('" .. val .. "', v:count1, 0, 0)\\<cr>")
  end

  for _, m in ipairs(vim.g.Vm.select_motions) do
    vim.cmd("nnoremap <silent> <Plug>(VM-Single-Select-" .. m .. ") :\\<C-u>call vm#commands#motion('" .. m .. "', v:count1, 1, 1)\\<cr>")
  end

  -- User operators
  vim.g.Vm.user_ops = {}
  for _, op in ipairs(vim.g.VM_user_operators or {}) do
    local key, val
    if type(op) == 'table' then
      key = next(op)
      val = op[key]
    else
      key = op
      val = 0
    end
    vim.g.Vm.user_ops[key] = val
    vim.cmd("nnoremap <silent> <Plug>(VM-User-Operator-" .. key .. ") :\\<C-u>call <sid>Operator('" .. key .. "', v:count1, v:register)\\<cr>")
  end

  -- Custom remaps
  local remaps = vim.g.VM_custom_remaps or {}
  for m, val in pairs(remaps) do
    vim.cmd("nmap <silent> <Plug>(VM-Remap-" .. val .. ") " .. val)
  end

  -- Custom noremaps
  local noremaps = vim.g.VM_custom_noremaps or {}
  for _, m in pairs(noremaps) do
    vim.cmd("nnoremap <silent> <Plug>(VM-Normal!-" .. m .. ") :\\<C-u>call b:VM_Selection.Edit.run_normal('" .. m .. "', {'count': v:count1, 'recursive': 0})\\<cr>")
  end

  -- Custom commands
  local cm = vim.g.VM_custom_commands or {}
  for m, val in pairs(cm) do
    vim.cmd("nnoremap <silent> <Plug>(VM-" .. m .. ") " .. val)
  end

  -- Edit commands
  vim.cmd([[
    nnoremap <silent>        <Plug>(VM-Shrink)                  :call vm#commands#shrink_or_enlarge(1)<cr>
    nnoremap <silent>        <Plug>(VM-Enlarge)                 :call vm#commands#shrink_or_enlarge(0)<cr>
    nnoremap <silent>        <Plug>(VM-Merge-To-Eol)            :call vm#commands#merge_to_beol(1, 0)<cr>
    nnoremap <silent>        <Plug>(VM-Merge-To-Bol)            :call vm#commands#merge_to_beol(0, 0)<cr>

    nnoremap <silent>        <Plug>(VM-D)                       :<C-u>call vm#cursors#operation('d', 0, v:register, 'd$')<cr>
    nnoremap <silent>        <Plug>(VM-Y)                       :<C-u>call vm#cursors#operation('y', 0, v:register, 'y$')<cr>
    nnoremap <silent>        <Plug>(VM-x)                       :<C-u>call b:VM_Selection.Edit.xdelete('x', v:count1)<cr>
    nnoremap <silent>        <Plug>(VM-X)                       :<C-u>call b:VM_Selection.Edit.xdelete('X', v:count1)<cr>
    nnoremap <silent>        <Plug>(VM-J)                       :<C-u>call b:VM_Selection.Edit.run_normal('J', {'count': v:count1, 'recursive': 0})<cr>
    nnoremap <silent>        <Plug>(VM-~)                       :<C-u>call b:VM_Selection.Edit.run_normal('~', {'recursive': 0})<cr>
    nnoremap <silent>        <Plug>(VM-&)                       :<C-u>call b:VM_Selection.Edit.run_normal('&', {'recursive': 0, 'silent': 1})<cr>
    nnoremap <silent>        <Plug>(VM-Del)                     :<C-u>call b:VM_Selection.Edit.run_normal('x', {'count': v:count1, 'recursive': 0})<cr>
    nnoremap <silent>        <Plug>(VM-Dot)                     :<C-u>call b:VM_Selection.Edit.dot()<cr>
    nnoremap <silent>        <Plug>(VM-Increase)                :<C-u>call vm#commands#increase_or_decrease(1, 0, v:count1, v:false)<cr>
    nnoremap <silent>        <Plug>(VM-Decrease)                :<C-u>call vm#commands#increase_or_decrease(0, 0, v:count1, v:false)<cr>
    nnoremap <silent>        <Plug>(VM-gIncrease)               :<C-u>call vm#commands#increase_or_decrease(1, 0, v:count1, v:true)<cr>
    nnoremap <silent>        <Plug>(VM-gDecrease)               :<C-u>call vm#commands#increase_or_decrease(0, 0, v:count1, v:true)<cr>
    nnoremap <silent>        <Plug>(VM-Alpha-Increase)          :<C-u>call vm#commands#increase_or_decrease(1, 1, v:count1, v:false)<cr>
    nnoremap <silent>        <Plug>(VM-Alpha-Decrease)          :<C-u>call vm#commands#increase_or_decrease(0, 1, v:count1, v:false)<cr>
    nnoremap <silent>        <Plug>(VM-a)                       :<C-u>call b:VM_Selection.Insert.key('a')<cr>
    nnoremap <silent>        <Plug>(VM-A)                       :<C-u>call b:VM_Selection.Insert.key('A')<cr>
    nnoremap <silent>        <Plug>(VM-i)                       :<C-u>call b:VM_Selection.Insert.key('i')<cr>
    nnoremap <silent>        <Plug>(VM-I)                       :<C-u>call b:VM_Selection.Insert.key('I')<cr>
    nnoremap <silent>        <Plug>(VM-o)                       :<C-u>call <sid>O(0)<cr>
    nnoremap <silent>        <Plug>(VM-O)                       :<C-u>call <sid>O(1)<cr>
    nnoremap <silent>        <Plug>(VM-c)                       :<C-u>call b:VM_Selection.Edit.change(g:Vm.extend_mode, v:count1, v:register, 0)<cr>
    nnoremap <silent>        <Plug>(VM-gc)                      :<C-u>call b:VM_Selection.Edit.change(g:Vm.extend_mode, v:count1, v:register, 1)<cr>
    nnoremap <silent>        <Plug>(VM-gu)                      :<C-u>call <sid>Operator('gu', v:count1, v:register)<cr>
    nnoremap <silent>        <Plug>(VM-gU)                      :<C-u>call <sid>Operator('gU', v:count1, v:register)<cr>
    nnoremap <silent>        <Plug>(VM-C)                       :<C-u>call vm#cursors#operation('c', 0, v:register, 'c$')<cr>
    nnoremap <silent>        <Plug>(VM-Delete)                  :<C-u>call b:VM_Selection.Edit.delete(g:Vm.extend_mode, v:register, v:count1, 1)<cr>
    nnoremap <silent>        <Plug>(VM-Delete-Exit)             :<C-u>call b:VM_Selection.Edit.delete(g:Vm.extend_mode, v:register, v:count1, 1)<cr>:call vm#reset()<cr>
    nnoremap <silent>        <Plug>(VM-Replace-Characters)      :<C-u>call b:VM_Selection.Edit.replace_chars()<cr>
    nnoremap <silent>        <Plug>(VM-Replace)                 :<C-u>call b:VM_Selection.Edit.replace()<cr>
    nnoremap <silent>        <Plug>(VM-Transform-Regions)       :<C-u>call b:VM_Selection.Edit.replace_expression()<cr>
    nnoremap <silent>        <Plug>(VM-p-Paste)                 :call b:VM_Selection.Edit.paste(g:Vm.extend_mode, 0, g:Vm.extend_mode, v:register)<cr>
    nnoremap <silent>        <Plug>(VM-P-Paste)                 :call b:VM_Selection.Edit.paste(               1, 0, g:Vm.extend_mode, v:register)<cr>
    nnoremap <silent>        <Plug>(VM-p-Paste-Vimreg)          :call b:VM_Selection.Edit.paste(g:Vm.extend_mode, 1, g:Vm.extend_mode, v:register)<cr>
    nnoremap <silent>        <Plug>(VM-P-Paste-Vimreg)          :call b:VM_Selection.Edit.paste(               1, 1, g:Vm.extend_mode, v:register)<cr>
    nnoremap <silent> <expr> <Plug>(VM-Yank)                    <SID>Yank()

    nnoremap <silent>        <Plug>(VM-Move-Right)              :call b:VM_Selection.Edit.shift(1)<cr>
    nnoremap <silent>        <Plug>(VM-Move-Left)               :call b:VM_Selection.Edit.shift(0)<cr>
    nnoremap <silent>        <Plug>(VM-Transpose)               :call b:VM_Selection.Edit.transpose()<cr>
    nnoremap <silent>        <Plug>(VM-Rotate)                  :call b:VM_Selection.Edit.rotate()<cr>
    nnoremap <silent>        <Plug>(VM-Duplicate)               :call b:VM_Selection.Edit.duplicate()<cr>

    nnoremap <silent>        <Plug>(VM-Align)                   :<C-u>call vm#commands#align()<cr>
    nnoremap <silent>        <Plug>(VM-Align-Char)              :<C-u>call vm#commands#align_char(v:count1)<cr>
    nnoremap <silent>        <Plug>(VM-Align-Regex)             :<C-u>call vm#commands#align_regex()<cr>
    nnoremap <silent>        <Plug>(VM-Numbers)                 :<C-u>call b:VM_Selection.Edit.numbers(v:count1, 0)<cr>
    nnoremap <silent>        <Plug>(VM-Numbers-Append)          :<C-u>call b:VM_Selection.Edit.numbers(v:count1, 1)<cr>
    nnoremap <silent>        <Plug>(VM-Zero-Numbers)            :<C-u>call b:VM_Selection.Edit.numbers(v:count, 0)<cr>
    nnoremap <silent>        <Plug>(VM-Zero-Numbers-Append)     :<C-u>call b:VM_Selection.Edit.numbers(v:count, 1)<cr>
    nnoremap <silent>        <Plug>(VM-Run-Dot)                 :<C-u>call b:VM_Selection.Edit.run_normal('.', {'count': v:count1, 'recursive': 0})<cr>
    nnoremap <silent>        <Plug>(VM-Surround)                :<c-u>call b:VM_Selection.Edit.surround()<cr>
    nnoremap <silent>        <Plug>(VM-Run-Macro)               :<c-u>call b:VM_Selection.Edit.run_macro()<cr>
    nnoremap <silent>        <Plug>(VM-Run-Ex)                  @=b:VM_Selection.Edit.ex()<CR>
    nnoremap <silent>        <Plug>(VM-Run-Last-Ex)             :<C-u>call b:VM_Selection.Edit.run_ex(g:Vm.last_ex)<cr>
    nnoremap <silent>        <Plug>(VM-Run-Normal)              :<C-u>call b:VM_Selection.Edit.run_normal(-1, {'count': v:count1})<cr>
    nnoremap <silent>        <Plug>(VM-Run-Last-Normal)         :<C-u>call b:VM_Selection.Edit.run_normal(g:Vm.last_normal[0], {'count': v:count1, 'recursive': g:Vm.last_normal[1]})<cr>
    nnoremap <silent>        <Plug>(VM-Run-Visual)              :call b:VM_Selection.Edit.run_visual(-1, 1)<cr>
    nnoremap <silent>        <Plug>(VM-Run-Last-Visual)         :call b:VM_Selection.Edit.run_visual(g:Vm.last_visual[0], g:Vm.last_visual[1])<cr>
  ]])

  -- Insert mode mappings
  vim.cmd([[
    inoremap <silent><expr> <Plug>(VM-I-Arrow-w)          <sid>Insert('w')
    inoremap <silent><expr> <Plug>(VM-I-Arrow-b)          <sid>Insert('b')
    inoremap <silent><expr> <Plug>(VM-I-Arrow-W)          <sid>Insert('W')
    inoremap <silent><expr> <Plug>(VM-I-Arrow-B)          <sid>Insert('B')
    inoremap <silent><expr> <Plug>(VM-I-Arrow-e)          <sid>Insert('e')
    inoremap <silent><expr> <Plug>(VM-I-Arrow-ge)         <sid>Insert('ge')
    inoremap <silent><expr> <Plug>(VM-I-Arrow-E)          <sid>Insert('E')
    inoremap <silent><expr> <Plug>(VM-I-Arrow-gE)         <sid>Insert('gE')
    inoremap <silent><expr> <Plug>(VM-I-Left-Arrow)       <sid>Insert('h')
    inoremap <silent><expr> <Plug>(VM-I-Right-Arrow)      <sid>Insert('l')
    inoremap <silent><expr> <Plug>(VM-I-Up-Arrow)         <sid>Insert('k')
    inoremap <silent><expr> <Plug>(VM-I-Down-Arrow)       <sid>Insert('j')
    inoremap <silent><expr> <Plug>(VM-I-Return)           <sid>Insert('cr')
    inoremap <silent><expr> <Plug>(VM-I-BS)               <sid>Insert('X')
    inoremap <silent><expr> <Plug>(VM-I-Paste)            <sid>Insert('c-v')
    inoremap <silent><expr> <Plug>(VM-I-CtrlW)            <sid>Insert('c-w')
    inoremap <silent><expr> <Plug>(VM-I-CtrlU)            <sid>Insert('c-u')
    inoremap <silent><expr> <Plug>(VM-I-CtrlD)            <sid>Insert('x')
    inoremap <silent><expr> <Plug>(VM-I-Del)              <sid>Insert('x')
    inoremap <silent><expr> <Plug>(VM-I-Home)             <sid>Insert('0')
    inoremap <silent><expr> <Plug>(VM-I-End)              <sid>Insert('A')
    inoremap <silent><expr> <Plug>(VM-I-CtrlE)            <sid>Insert('A')
    inoremap <silent><expr> <Plug>(VM-I-Ctrl^)            <sid>Insert('I')
    inoremap <silent><expr> <Plug>(VM-I-CtrlA)            <sid>Insert('I')
    inoremap <silent><expr> <Plug>(VM-I-CtrlB)            <sid>Insert('h')
    inoremap <silent><expr> <Plug>(VM-I-CtrlF)            <sid>Insert('l')
    inoremap <silent>       <Plug>(VM-I-CtrlC)            <Esc>
    inoremap <silent><expr> <Plug>(VM-I-CtrlO)            <sid>Insert('O')
    inoremap <silent><expr> <Plug>(VM-I-Next)             vm#icmds#goto(1)
    inoremap <silent><expr> <Plug>(VM-I-Prev)             vm#icmds#goto(0)
    inoremap <silent><expr> <Plug>(VM-I-Replace)          <sid>Insert('ins')
  ]])

  -- Cmdline
  vim.cmd([[
    nnoremap         <expr> <Plug>(VM-:)                  vm#commands#regex_reset(':')
    nnoremap         <expr> <Plug>(VM-/)                  vm#commands#regex_reset('/')
    nnoremap         <expr> <Plug>(VM-?)                  vm#commands#regex_reset('?')
  ]])
end

return M
