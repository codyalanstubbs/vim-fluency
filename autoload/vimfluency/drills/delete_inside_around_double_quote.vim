" delete_inside_around_double_quote — di" / da", the inner vs around
" discrimination for double quotes. Focused two-motion breakout of the
" delete_inside_around_quotes trio. Unlike the bracket objects, da" EATS
" one trailing space (like daw), leaving a single gap.
" Shared generator + lesson: autoload/vimfluency/objpair.vim.

function! vimfluency#drills#delete_inside_around_double_quote#meta() abort
  return {'id': 'delete_inside_around_double_quote',
    \ 'name': 'delete inside vs around double quotes (di" / da")',
    \ 'aim': 48, 'allowed_keys': 'dia"', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_quotes'], 'keys': 'di"/da"', 'family': 'delete',
    \ 'narrower_of': 'delete_inside_around_quotes',
    \ 'test_sequence': ['di"', 'da"']}
endfunction

function! vimfluency#drills#delete_inside_around_double_quote#generate() abort
  return vimfluency#objpair#gen('"', '"', '"', 1)
endfunction

function! vimfluency#drills#delete_inside_around_double_quote#lesson() abort
  return vimfluency#objpair#lesson('"', '"', '"', 1)
endfunction
