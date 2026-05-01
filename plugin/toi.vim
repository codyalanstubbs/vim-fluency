" toi — fluency probe runner for vim pinpoints
" Loaded once at startup. All real work lives in autoload/toi.vim.

if exists('g:loaded_toi') | finish | endif
let g:loaded_toi = 1

if v:version < 801
  echohl WarningMsg
  echom 'toi requires Vim 8.1 or later'
  echohl None
  finish
endif

command! -nargs=* -complete=customlist,toi#complete Toi call toi#start(<f-args>)
command! ToiList call toi#list()
command! ToiQuit call toi#stop('user')
command! -nargs=? -complete=customlist,toi#complete ToiHistory call toi#history(<f-args>)
command! -nargs=1 -complete=customlist,toi#complete ToiLearn call toi#learn(<f-args>)

highlight default ToiTarget ctermbg=darkgreen guibg=#2d5a2d ctermfg=white guifg=white
highlight default ToiLearnShow ctermbg=darkcyan guibg=#2d4a5a ctermfg=white guifg=white
highlight default ToiDeletion ctermbg=darkred guibg=#5a2d2d ctermfg=white guifg=white
