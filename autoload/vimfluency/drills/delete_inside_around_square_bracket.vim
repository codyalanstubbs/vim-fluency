" delete_inside_around_square_bracket — di[ / da[, the inner vs around
" discrimination for square brackets. Focused two-motion breakout of the
" delete_inside_around_brackets trio. da[ takes the [ ] but NOT the
" surrounding whitespace (double gap).
" Shared generator + lesson: autoload/vimfluency/objpair.vim.

function! vimfluency#drills#delete_inside_around_square_bracket#meta() abort
  return {'id': 'delete_inside_around_square_bracket',
    \ 'name': 'delete inside vs around square brackets (di[ / da[)',
    \ 'aim': 48, 'allowed_keys': 'dia[', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_around_tag'], 'keys': 'di[/da[', 'family': 'delete',
    \ 'test_sequence': ['di[', 'da[']}
endfunction

function! vimfluency#drills#delete_inside_around_square_bracket#generate() abort
  return vimfluency#objpair#gen('[', ']', '[', 0)
endfunction

function! vimfluency#drills#delete_inside_around_square_bracket#lesson() abort
  return vimfluency#objpair#lesson('[', ']', '[', 0)
endfunction
