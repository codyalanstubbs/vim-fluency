" move_single_char_up_down_left_right — hjkl. Move cursor 1 or 2 cells in any direction (including diagonal).
"
" Design constraints to keep hjkl the strictly shortest path:
"   - target Chebyshev distance to start ∈ {1, 2}
"   - lines are spaceless filler chars, so w/b/W/B jump the whole line
"     (and are therefore never useful)
"   - start col is kept ≥3 chars from either line edge, so 0/^/$ are
"     never shorter than the equivalent run of h/l
"   - all lines are equal length, so j/k preserve column cleanly

let s:chars = ['a','b','c','d','e','f','g','h','i','j','k','m','n','p',
  \ 'q','r','s','t','u','v','w','x','y','z',
  \ '2','3','4','5','6','7','8','9']

function! vimfluency#drills#move_single_char_up_down_left_right#meta() abort
  return {'id': 'move_single_char_up_down_left_right', 'name': 'move one char, 4-way (hjkl)', 'aim': 60,
    \ 'allowed_keys': 'hjkl',
    \ 'prereqs': ['move_single_char_left_right', 'move_single_char_up_down'],
    \ 'keys': 'h/j/k/l', 'family': 'motion',
    \ 'test_sequence': ['h', 'j', 'k', 'l']}
endfunction

function! vimfluency#drills#move_single_char_up_down_left_right#lesson() abort
  " Rule-first intro, then each motion gets its own try frame so the
  " learner performs it. The tail chains motions into a diagonal.
  let buf = ['abcdef', 'ghijkl', 'mnopqr', 'stuvwx', 'yzabcd']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [3, 4],
    \  'prompt': [
    \    'Four single-char moves:',
    \    '',
    \    '    h   →   moves the cursor one column left',
    \    '    l   →   moves the cursor one column right',
    \    '    j   →   moves the cursor one row down',
    \    '    k   →   moves the cursor one row up',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [3, 3],
    \  'expected_motion': 'h', 'optimal_motions': 1,
    \  'prompt': 'Press h — moves the cursor one column left.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [3, 5],
    \  'expected_motion': 'l', 'optimal_motions': 1,
    \  'prompt': 'Press l — moves the cursor one column right.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [4, 4],
    \  'expected_motion': 'j', 'optimal_motions': 1,
    \  'prompt': 'Press j — moves the cursor one row down.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [2, 4],
    \  'expected_motion': 'k', 'optimal_motions': 1,
    \  'prompt': 'Press k — moves the cursor one row up.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 1], 'target': [3, 3],
    \  'expected_motion': 'l', 'optimal_motions': 2,
    \  'prompt': 'Press l twice.'},
    \ {'kind': 'try', 'lines': buf, 'start': [2, 4], 'target': [3, 5],
    \  'prompt': 'Press j then l — moves the cursor diagonally (down, then right).'},
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

function! vimfluency#drills#move_single_char_up_down_left_right#generate() abort
  let line_len = 20
  let n_lines = 7
  let lines = []
  for _ in range(n_lines)
    call add(lines, s:make_line(line_len))
  endfor

  " start row in the interior (margin 2 above and below for chebyshev-2)
  let srow = 3 + s:rand(3)
  " start col with margin 3 from either edge
  let scol = 4 + s:rand(line_len - 7)

  " offset in {-2..2} × {-2..2} excluding (0, 0)
  let drow = s:rand(5) - 2
  let dcol = s:rand(5) - 2
  while drow == 0 && dcol == 0
    let drow = s:rand(5) - 2
    let dcol = s:rand(5) - 2
  endwhile

  if drow == 0 && dcol > 0
    let motion = 'l'
  elseif drow == 0 && dcol < 0
    let motion = 'h'
  elseif dcol == 0 && drow > 0
    let motion = 'j'
  elseif dcol == 0 && drow < 0
    let motion = 'k'
  else
    let motion = 'diag'
  endif

  " Optimal motions using only hjkl (no count prefix) = manhattan distance.
  " Users who type counts like 2l will land below this — that's intentional;
  " counts are a separate skill (Tier 5).
  let optimal_motions = abs(drow) + abs(dcol)

  return {'lines': lines, 'start': [srow, scol], 'target': [srow + drow, scol + dcol],
    \ 'expected_motion': motion, 'optimal_motions': optimal_motions}
endfunction
