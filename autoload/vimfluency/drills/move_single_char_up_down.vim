" move_single_char_up_down — j vs k. Narrower 2-cell sibling of move_single_char_up_down_left_right (hjkl). Shared
" quality: single-line vertical motion. Juxtaposed quality: direction
" (down vs up). Fallback for learners who plateau on move_single_char_up_down_left_right on the
" vertical axis.
"
" Design constraints:
"   - target on the SAME column as start (no horizontal component)
"   - target row offset ∈ {-2, -1, 1, 2}
"   - lines are equal length so j/k preserve column cleanly
"   - start row kept in interior (margin 2) so target is on a real
"     line

let s:chars = ['a','b','c','d','e','f','g','h','i','j','k','m','n','p',
  \ 'q','r','s','t','u','v','w','x','y','z',
  \ '2','3','4','5','6','7','8','9']

function! vimfluency#drills#move_single_char_up_down#meta() abort
  return {'id': 'move_single_char_up_down', 'name': 'move one char down / up (j / k)', 'aim': 60,
    \ 'allowed_keys': 'jk', 'prereqs': [],
    \ 'narrower_of': 'move_single_char_up_down_left_right', 'parallel_to': ['move_single_char_left_right'], 'keys': 'j/k', 'family': 'motion',
    \ 'test_sequence': ['j', 'k']}
endfunction

function! vimfluency#drills#move_single_char_up_down#lesson() abort
  let buf = ['abcdef', 'ghijkl', 'mnopqr', 'stuvwx', 'yzabcd']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [3, 4],
    \  'prompt': 'j moves the cursor one row down; k one row up. They differ only by direction.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [4, 4],
    \  'prompt': 'Press j — moves cursor one row down.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [2, 4],
    \  'prompt': 'Press k — moves cursor one row up.'},
    \ {'kind': 'try', 'lines': buf, 'start': [2, 4], 'target': [4, 4],
    \  'prompt': 'Use j twice.'},
    \ {'kind': 'try', 'lines': buf, 'start': [4, 4], 'target': [2, 4],
    \  'prompt': 'Use k twice.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_line(len) abort
  let s = ''
  for _ in range(a:len)
    let s .= s:chars[s:rand(len(s:chars))]
  endfor
  return s
endfunction

function! vimfluency#drills#move_single_char_up_down#generate() abort
  let line_len = 20
  let n_lines = 7
  let lines = []
  for _ in range(n_lines)
    call add(lines, s:make_line(line_len))
  endfor

  " start row in the interior (margin 2 above and below for offset-2)
  let srow = 3 + s:rand(n_lines - 4)
  " start col can be anywhere (no horizontal component)
  let scol = 1 + s:rand(line_len)

  " row offset in {-2, -1, 1, 2}
  let drow = s:rand(4)
  if drow >= 2
    let drow += 1
  endif
  let drow -= 2

  let motion = drow > 0 ? 'j' : 'k'
  let optimal_motions = abs(drow)

  return {'lines': lines, 'start': [srow, scol], 'target': [srow + drow, scol],
    \ 'expected_motion': motion, 'optimal_motions': optimal_motions}
endfunction
