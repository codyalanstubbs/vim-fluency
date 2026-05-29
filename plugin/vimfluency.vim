" vimfluency — fluency training runner for vim pinpoints
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
command! -nargs=1 -complete=customlist,vimfluency#complete VfChartZoom call vimfluency#chart_zoom(<f-args>)
command! -nargs=+ -complete=customlist,vimfluency#complete VfSetAim call vimfluency#set_aim(<f-args>)
command! -nargs=1 -complete=customlist,vimfluency#complete VfResetAim call vimfluency#reset_aim(<f-args>)
command! -nargs=1 VfSetDuration call vimfluency#set_duration(<f-args>)
command! VfResetDuration call vimfluency#reset_duration()

" High-contrast highlights so the target character stays legible against
" any colorscheme. Saturated bg + dark fg = "highlighter pen" look.
" Target/show use Light* cterm variants (color 10/11) — plain Green is
" color 2, which some terminals render as a muddy yellow-green that
" washes out a black foreground.
" Deletion uses plain Red (color 1) with a white foreground: LightRed
" is so washed out it reads as pink, which is too close to a white
" cursor block to discriminate. A deep red with white text reads as
" "danger/delete" and stays clearly distinct from the cursor.
highlight default VfTarget     cterm=bold gui=bold ctermbg=LightGreen ctermfg=Black guibg=#5fff5f guifg=#000000
highlight default VfLearnShow  cterm=bold gui=bold ctermbg=LightCyan  ctermfg=Black guibg=#5fffff guifg=#000000
highlight default VfDeletion   cterm=bold gui=bold ctermbg=Red        ctermfg=White guibg=#d70000 guifg=#ffffff
