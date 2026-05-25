" 4.4 — delete one char via motion (dl, dh). Composite-behavior
" pinpoint pairing the delete operator with the single-char
" horizontal motions. Shared quality: delete one char via motion.
" Juxtaposed quality: direction.
"
" Note: dl and dh produce the same outcomes as x and X respectively.
" Both production paths exist in vim; this pinpoint drills the
" operator-motion route. A separate x/X pinpoint (the atomic edit
" route) lives in slice-01's scope but isn't shipped yet.
"
" Design constraints:
"   - single line of plain words, no leading or trailing whitespace
"   - cursor in the interior (col ≥ 2 and ≤ len - 1) so both
"     dl and dh have a real char to delete on either side

let s:words = ['def', 'class', 'return', 'import', 'from', 'while',
  \ 'if', 'else', 'for', 'in', 'True', 'False', 'None', 'self',
  \ 'data', 'value']

function! vimfluency#pinpoints#p4_4#meta() abort
  return {'id': '4.4', 'name': 'dl dh', 'aim': 40,
    \ 'allowed_keys': 'dlh', 'kind': 'editing',
    \ 'prereqs': ['1A.3'],
    \ 'parallel_to': ['4.1', '4.3']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_line() abort
  let n = 3 + s:rand(5)
  let parts = []
  for _ in range(n)
    call add(parts, s:words[s:rand(len(s:words))])
  endfor
  return join(parts, ' ')
endfunction

function! vimfluency#pinpoints#p4_4#generate() abort
  let line = s:make_line()
  let llen = len(line)
  " cursor in interior — both sides have a deletable char
  let cursor_col = 2 + s:rand(llen - 2)

  " 50/50 direction
  let go_right = s:rand(2) == 0
  if go_right
    " dl deletes the char at cursor. Cursor stays at cursor_col;
    " what's now there is the char that used to be at cursor_col+1.
    let motion = 'dl'
    let del_start = cursor_col
    let target_col = cursor_col
  else
    " dh deletes the char before cursor. Cursor moves to cursor_col-1;
    " what's now there is the char that used to be at cursor_col.
    let motion = 'dh'
    let del_start = cursor_col - 1
    let target_col = cursor_col - 1
  endif
  let del_len = 1

  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, target_col],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted character using d + h or l.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#pinpoints#p4_4#lesson() abort
  let buf = ['if data: return value']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 10],
    \  'prompt': 'd + a single-char motion deletes one character. dl deletes the char under cursor; dh deletes the char before.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 10],
    \  'target_lines': ['if data: eturn value'],
    \  'deletion_range': [[1, 10, 1]],
    \  'prompt': 'Press dl — deletes the r under cursor. Cursor stays put; the next char slides under.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 9],
    \  'target_lines': ['if data:return value'],
    \  'deletion_range': [[1, 9, 1]],
    \  'prompt': 'Press dh — deletes the space before cursor. Cursor moves left one column.'},
    \ ]
endfunction
