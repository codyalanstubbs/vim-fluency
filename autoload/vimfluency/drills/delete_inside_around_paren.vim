" delete_inside_around_paren — di( / da(, the inner vs around discrimination
" for parentheses. A focused two-motion drill (like delete_inside_around_tag),
" the single-delimiter breakout of the delete_inside_around_brackets trio.
" da( takes the ( ) but NOT the surrounding whitespace, leaving a double gap.
" Shared generator + lesson: autoload/vimfluency/objpair.vim.

function! vimfluency#drills#delete_inside_around_paren#meta() abort
  return {'id': 'delete_inside_around_paren',
    \ 'name': 'delete inside vs around parens (di( / da()',
    \ 'aim': 48, 'allowed_keys': 'dia(', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_brackets'], 'keys': 'di(/da(', 'family': 'delete',
    \ 'narrower_of': 'delete_inside_around_brackets',
    \ 'test_sequence': ['di(', 'da(']}
endfunction

function! vimfluency#drills#delete_inside_around_paren#generate() abort
  return vimfluency#objpair#gen('(', ')', '(', 0)
endfunction

function! vimfluency#drills#delete_inside_around_paren#lesson() abort
  return vimfluency#objpair#lesson('(', ')', '(', 0)
endfunction
