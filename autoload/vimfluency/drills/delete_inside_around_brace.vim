" delete_inside_around_brace — di{ / da{, the inner vs around discrimination
" for braces. Focused two-motion breakout of the delete_inside_around_brackets
" trio. da{ takes the { } but NOT the surrounding whitespace (double gap).
" Shared generator + lesson: autoload/vimfluency/objpair.vim.

function! vimfluency#drills#delete_inside_around_brace#meta() abort
  return {'id': 'delete_inside_around_brace',
    \ 'name': 'delete inside vs around braces (di{ / da{)',
    \ 'aim': 48, 'allowed_keys': 'dia{', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_brackets'], 'keys': 'di{/da{', 'family': 'delete',
    \ 'narrower_of': 'delete_inside_around_brackets',
    \ 'test_sequence': ['di{', 'da{']}
endfunction

function! vimfluency#drills#delete_inside_around_brace#generate() abort
  return vimfluency#objpair#gen('{', '}', '{', 0)
endfunction

function! vimfluency#drills#delete_inside_around_brace#lesson() abort
  return vimfluency#objpair#lesson('{', '}', '{', 0)
endfunction
