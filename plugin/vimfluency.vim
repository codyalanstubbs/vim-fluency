" vimfluency — fluency probe runner for vim pinpoints
" Loaded once at startup. All real work lives in autoload/vimfluency.vim.

if exists('g:loaded_vimfluency') | finish | endif
let g:loaded_vimfluency = 1

if v:version < 801
  echohl WarningMsg
  echom 'vimfluency requires Vim 8.1 or later'
  echohl None
  finish
endif

command! -nargs=* -complete=customlist,vimfluency#complete Vf call vimfluency#start(<f-args>)
command! VfList call vimfluency#list()
command! VfQuit call vimfluency#stop('user')
command! -nargs=? -complete=customlist,vimfluency#complete VfHistory call vimfluency#history(<f-args>)
command! -nargs=1 -complete=customlist,vimfluency#complete VfLearn call vimfluency#learn(<f-args>)
command! -nargs=1 -complete=customlist,vimfluency#complete VfChart call vimfluency#chart(<f-args>)

highlight default VfTarget ctermbg=darkgreen guibg=#2d5a2d ctermfg=white guifg=white
highlight default VfLearnShow ctermbg=darkcyan guibg=#2d4a5a ctermfg=white guifg=white
highlight default VfDeletion ctermbg=darkred guibg=#5a2d2d ctermfg=white guifg=white
