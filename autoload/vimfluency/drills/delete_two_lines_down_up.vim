" delete_two_lines_down_up — delete extending across lines (dj, dk). Composite-behavior
" drill pairing the delete operator with single-line vertical
" motions. Both forms are linewise: dj deletes the cursor's row +
" the next; dk deletes the cursor's row + the previous.
"
" Shared quality: linewise delete extending two rows. Juxtaposed
" quality: direction (down vs up).
"
" Design constraints:
"   - 5-line buffer so 3 survivors remain regardless of direction
"   - cursor on rows 2-3 so both directions have a real previous /
"     next line to extend into (rows 4 would clip dj-from-row-4
"     against the bottom edge, where vim's behavior gets weird)
"   - lines have no leading whitespace, so the cursor lands at col 1
"     of the surviving row after the linewise operation
"   - cue: highlight covers BOTH deleted rows; cursor's row tells
"     the learner which direction extends from there

let s:words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon',
  \ 'zeta', 'eta', 'theta', 'iota', 'kappa']

function! vimfluency#drills#delete_two_lines_down_up#meta() abort
  return {'id': 'delete_two_lines_down_up', 'name': 'delete two lines (dj / dk)', 'aim': 30,
    \ 'allowed_keys': 'djk', 'kind': 'editing',
    \ 'prereqs': ['move_single_char_up_down'], 'keys': 'dj/dk', 'family': 'delete',
    \ 'test_sequence': ['dj', 'dk']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_line() abort
  let n = 2 + s:rand(2)
  let parts = []
  for _ in range(n)
    call add(parts, s:words[s:rand(len(s:words))])
  endfor
  return join(parts, ' ')
endfunction

function! vimfluency#drills#delete_two_lines_down_up#generate() abort
  let lines = []
  for _ in range(5)
    call add(lines, s:make_line())
  endfor

  " cursor row 2 or 3 — both directions have room
  let cursor_row = 2 + s:rand(2)
  let go_down = s:rand(2) == 0

  if go_down
    " dj from row R deletes rows R and R+1. Survivors are rows [1..R-1] + [R+2..5].
    " Cursor lands at row R (which was row R+2), col 1.
    let motion = 'dj'
    let del_first = cursor_row
    let del_last = cursor_row + 1
    let target_row = cursor_row
  else
    " dk from row R deletes rows R-1 and R. Survivors are rows [1..R-2] + [R+1..5].
    " Cursor lands at row R-1 (which was row R+1), col 1.
    let motion = 'dk'
    let del_first = cursor_row - 1
    let del_last = cursor_row
    let target_row = cursor_row - 1
  endif

  " Compute surviving lines
  let target_lines = []
  for i in range(len(lines))
    let row = i + 1
    if row < del_first || row > del_last
      call add(target_lines, lines[i])
    endif
  endfor

  " deletion_range highlights every char in both deleted rows
  let deletion_range = []
  for row in [del_first, del_last]
    call add(deletion_range, [row, 1, len(lines[row - 1])])
  endfor

  return {
    \ 'lines': lines,
    \ 'target_lines': target_lines,
    \ 'start': [cursor_row, 1],
    \ 'target': [target_row, 1],
    \ 'deletion_range': deletion_range,
    \ 'prompt': 'Delete the highlighted rows using d + a vertical motion.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_two_lines_down_up#lesson() abort
  let buf = ['alpha beta', 'gamma delta', 'epsilon zeta', 'eta theta', 'iota kappa']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [3, 1],
    \  'prompt': 'd + a vertical motion is linewise — it deletes two whole rows. dj deletes the cursor row + the next; dk deletes the cursor row + the previous.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 1], 'target': [3, 1],
    \  'target_lines': ['alpha beta', 'gamma delta', 'iota kappa'],
    \  'deletion_range': [[3, 1, len(buf[2])], [4, 1, len(buf[3])]],
    \  'prompt': 'Press dj — deletes the cursor row and the next. Cursor lands on row 3 (what was row 5).'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 1], 'target': [2, 1],
    \  'target_lines': ['alpha beta', 'eta theta', 'iota kappa'],
    \  'deletion_range': [[2, 1, len(buf[1])], [3, 1, len(buf[2])]],
    \  'prompt': 'Press dk — deletes the cursor row and the previous. Cursor lands on row 2 (what was row 4).'},
    \ ]
endfunction
