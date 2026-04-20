"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" File:         visual-multi.vim
" Description:  multiple selections in vim (Lua entry point)
" Mantainer:    Gianmaria Bajo <mg1979.git@gmail.com>
" Url:          https://github.com/mg979/vim-visual-multi
" Licence:      The MIT License (MIT)
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Guard {{{
if !has('nvim')
  echomsg '[vim-visual-multi] Neovim is required'
  finish
endif

if exists("g:loaded_visual_multi")
  finish
endif
let g:loaded_visual_multi = 1

let s:save_cpo = &cpo
set cpo&vim
"}}}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Initialize via Lua
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

lua require('visual-multi.plugin').setup()

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: ft=vim et sw=2 ts=2 sts=2 fdm=marker
