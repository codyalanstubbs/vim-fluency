" delete_to_line_edges_start_end — delete to line edge (d0, d$). Composite-behavior drill
" pairing the delete operator with the two line-edge motions. Shared
" quality: delete to a line edge. Juxtaposed quality: direction
" (line-start vs line-end).
"
" Replaces the unimplemented wide-grid spec row for "operator + line
" motion." Built under the exhaustive-hierarchy framework for the
" delete family's foundational char/line-motion layer.
"
" Design constraints:
"   - single line of plain words, no leading or trailing whitespace
"   - cursor in the interior (col ≥ 3 and ≤ len - 2) so neither
"     d0 nor d$ is a no-op
"   - target_lines computed from the deletion range so the runner's
"     editing-kind matcher credits on exact buffer state
"
" Cheat-defense:
"   - the two motions go to opposite ends of the same line, so the
"     learner can't infer the answer from cursor position alone —
"     the deletion-range highlight tells them which side to delete
"   - words varied per item so positional memorization fails

let s:words = ['def', 'class', 'return', 'import', 'from', 'while',
  \ 'if', 'else', 'for', 'in', 'True', 'False', 'None', 'self',
  \ 'data', 'value']

function! vimfluency#drills#delete_to_line_edges_start_end#meta() abort
  return {'id': 'delete_to_line_edges_start_end', 'name': 'delete to line edges (d0 / d$)', 'aim': 45,
    \ 'allowed_keys': 'd0$', 'kind': 'editing',
    \ 'prereqs': ['move_to_line_edges_start_end'],
    \ 'keys': 'd0/d$', 'family': 'delete',
    \ 'test_sequence': ['d0', 'd$']}
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

function! vimfluency#drills#delete_to_line_edges_start_end#generate() abort
  let line = s:make_line()
  let llen = len(line)
  " cursor in interior (≥ 3 from each edge for non-trivial deletions)
  let cursor_col = 3 + s:rand(llen - 4)

  " 50/50 direction
  let go_start = s:rand(2) == 0
  if go_start
    " d0 deletes [1, cursor-1]; cursor ends at col 1 of the remaining
    " line which is the original char at cursor_col, now at col 1.
    let motion = 'd0'
    let del_start = 1
    let del_len = cursor_col - 1
    let target_col = 1
  else
    " d$ deletes [cursor, llen]; cursor ends at col cursor-1 of the
    " remaining line (the last surviving char).
    let motion = 'd$'
    let del_start = cursor_col
    let del_len = llen - cursor_col + 1
    let target_col = cursor_col - 1
  endif

  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, target_col],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted range using d + a line-edge motion.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_to_line_edges_start_end#lesson() abort
  let buf = ['if data: return value']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 10],
    \  'prompt': [
    \    'Two line-edge deletes:',
    \    '',
    \    '    d0   →   deletes from the cursor back to column 1',
    \    '    d$   →   deletes from the cursor to the end of the line',
    \    '',
    \    'd takes a line-edge motion and deletes the range it covers.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 1],
    \  'expected_motion': 'd0', 'optimal_motions': 1,
    \  'target_lines': ['return value'],
    \  'deletion_range': [[1, 1, 9]],
    \  'prompt': 'Press d0 — deletes "if data: ". Cursor lands at column 1.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 9],
    \  'expected_motion': 'd$', 'optimal_motions': 1,
    \  'target_lines': ['if data: '],
    \  'deletion_range': [[1, 10, 12]],
    \  'prompt': 'Press d$ — deletes "return value". Cursor lands at the new last column.'},
    \ ]
endfunction
