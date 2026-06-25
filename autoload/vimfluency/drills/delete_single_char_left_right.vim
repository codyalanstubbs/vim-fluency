" delete_single_char_left_right — delete one char via motion (dl, dh). Composite-behavior
" drill pairing the delete operator with the single-char
" horizontal motions. Shared quality: delete one char via motion.
" Juxtaposed quality: direction.
"
" Note: dl and dh produce the same outcomes as x and X respectively.
" Both production paths exist in vim; this drill drills the
" operator-motion route. A separate x/X drill (the atomic edit
" route) lives in slice-01's scope but isn't shipped yet.
"
" Design constraints:
"   - single line of plain words, no leading or trailing whitespace
"   - cursor in the interior (col ≥ 2 and ≤ len - 1) so both
"     dl and dh have a real char to delete on either side

let s:words = ['def', 'class', 'return', 'import', 'from', 'while',
  \ 'if', 'else', 'for', 'in', 'True', 'False', 'None', 'self',
  \ 'data', 'value']

function! vimfluency#drills#delete_single_char_left_right#meta() abort
  return {'id': 'delete_single_char_left_right', 'name': 'delete one char (dl / dh)', 'aim': 40,
    \ 'allowed_keys': 'dlh', 'kind': 'editing',
    \ 'prereqs': ['move_single_char_left_right'],
    \ 'parallel_to': ['delete_to_word_start_forward_backward', 'delete_to_line_edges_start_end'], 'keys': 'dl/dh', 'family': 'delete',
    \ 'test_sequence': ['dl', 'dh']}
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

function! vimfluency#drills#delete_single_char_left_right#generate() abort
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

  " annotate_deletion: dl deletes the char UNDER the cursor, so its
  " red VfDeletion cell hides beneath the cursor block — without the
  " ▼ marker row the item looks target-less (2026-06-12 report).
  " Set on BOTH directions so the row's presence is never a tell;
  " the ▼ position relative to the cursor is the cue.
  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, target_col],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'annotate_deletion': 1,
    \ 'prompt': 'Delete the ▼-marked character using d + h or l.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_single_char_left_right#lesson() abort
  let buf = ['if data: return value']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 10],
    \  'prompt': [
    \    'Two single-char deletes:',
    \    '',
    \    '    dl   →   deletes the character under the cursor',
    \    '    dh   →   deletes the character before the cursor',
    \    '',
    \    'd + a single-char motion deletes one character.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 10],
    \  'expected_motion': 'dl', 'optimal_motions': 1,
    \  'target_lines': ['if data: eturn value'],
    \  'deletion_range': [[1, 10, 1]],
    \  'annotate_deletion': 1,
    \  'prompt': 'Press dl — deletes the char under the cursor (marked ▼). Cursor stays put; the next char slides under.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 9],
    \  'expected_motion': 'dh', 'optimal_motions': 1,
    \  'target_lines': ['if data:return value'],
    \  'deletion_range': [[1, 9, 1]],
    \  'annotate_deletion': 1,
    \  'prompt': 'Press dh — deletes the char before the cursor (marked ▼). Cursor moves left one column.'},
    \ ]
endfunction
