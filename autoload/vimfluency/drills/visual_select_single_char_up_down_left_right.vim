" visual_select_single_char_up_down_left_right — vh / vj / vk / vl.
" Broader-drill v-family drill that mixes all four single-cell
" charwise selection extensions. Parallel by design with the
" motion-family broader drill (move_single_char_up_down_left_right):
" same 4-direction discrimination structure, applied to a visual-mode
" selection instead of a cursor move.
"
" Production path: the learner presses v, then one of h/l/j/k to
" extend the selection by exactly one cell in the chosen direction.
" The runner's visual_motion kind credits when mode() == 'v' AND
" anchor + cursor positions match the item's expected range.
"
" Design constraints (keep v + one direction key strictly shortest):
"   - target Chebyshev distance to start == 1 (single-cell extension
"     in exactly one cardinal direction; no diagonals)
"   - lines are spaceless filler chars, so vw / vb jump past the
"     adjacent target and are therefore never useful
"   - start col kept ≥3 chars from either line edge, so v0 / v^ / v$
"     can never land the target cell with fewer keystrokes
"   - start row kept ≥1 from top/bottom so vj / vk both have a real
"     row to extend to
"   - lines are equal length so vj / vk preserve column cleanly
"     (no shorter-line snap)

let s:chars = ['a','b','c','d','e','f','g','h','i','j','k','m','n','p',
  \ 'q','r','s','t','u','v','w','x','y','z',
  \ '2','3','4','5','6','7','8','9']

function! vimfluency#drills#visual_select_single_char_up_down_left_right#meta() abort
  " Aim mirrors the foundational pairs (50/min). Broader drill adds
  " direction-pick load, but the per-cell motion is identical to
  " the 2-cell drills — same starting guess until data says
  " otherwise.
  return {'id': 'visual_select_single_char_up_down_left_right',
    \ 'name': 'extend selection, 4-way (vh vj vk vl)', 'aim': 50,
    \ 'allowed_keys': 'vhjkl', 'kind': 'visual_motion',
    \ 'prereqs': ['visual_select_single_char_left_right',
    \              'visual_select_single_char_up_down'],
    \ 'parallel_to': ['move_single_char_up_down_left_right'],
    \ 'keys': 'vh/vj/vk/vl', 'family': 'v',
    \ 'test_sequence': ['vh', 'vj', 'vk', 'vl']}
endfunction

function! vimfluency#drills#visual_select_single_char_up_down_left_right#lesson() abort
  let buf = ['abcdef', 'ghijkl', 'mnopqr', 'stuvwx', 'yzabcd']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [3, 4],
    \  'prompt': [
    \    'v starts charwise visual selection at the cursor.',
    \    'After v, one of h / l / j / k extends the selection one cell:',
    \    '',
    \    '  vh → one column left',
    \    '  vl → one column right',
    \    '  vj → one row down (same column)',
    \    '  vk → one row up   (same column)',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [3, 3],
    \  'expected_selection_start': [3, 4], 'expected_selection_end': [3, 3],
    \  'expected_sub_mode': 'v',
    \  'expected_motion': 'vh', 'optimal_motions': 2,
    \  'prompt': 'Press v then h — extends the visual selection one column left.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [3, 5],
    \  'expected_selection_start': [3, 4], 'expected_selection_end': [3, 5],
    \  'expected_sub_mode': 'v',
    \  'expected_motion': 'vl', 'optimal_motions': 2,
    \  'prompt': 'Press v then l — extends the visual selection one column right.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [4, 4],
    \  'expected_selection_start': [3, 4], 'expected_selection_end': [4, 4],
    \  'expected_sub_mode': 'v',
    \  'expected_motion': 'vj', 'optimal_motions': 2,
    \  'prompt': 'Press v then j — extends the visual selection one row down.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [2, 4],
    \  'expected_selection_start': [3, 4], 'expected_selection_end': [2, 4],
    \  'expected_sub_mode': 'v',
    \  'expected_motion': 'vk', 'optimal_motions': 2,
    \  'prompt': 'Press v then k — extends the visual selection one row up.'},
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

function! vimfluency#drills#visual_select_single_char_up_down_left_right#generate() abort
  let line_len = 20
  let n_lines = 7
  let lines = []
  for _ in range(n_lines)
    call add(lines, s:make_line(line_len))
  endfor

  " start row in interior (margin 1 above and below for ±1 vertical)
  let srow = 2 + s:rand(n_lines - 2)
  " start col with margin 3 from either edge (so v0 / v$ are never shorter)
  let scol = 4 + s:rand(line_len - 7)

  " uniform pick from the 4 cardinal directions
  let dir = s:rand(4)
  let drow = 0
  let dcol = 0
  let motion = ''
  if     dir == 0 | let dcol = -1 | let motion = 'vh'
  elseif dir == 1 | let dcol =  1 | let motion = 'vl'
  elseif dir == 2 | let drow = -1 | let motion = 'vk'
  else            | let drow =  1 | let motion = 'vj'
  endif

  return {
    \ 'lines': lines,
    \ 'start': [srow, scol],
    \ 'target': [srow + drow, scol + dcol],
    \ 'expected_selection_start': [srow, scol],
    \ 'expected_selection_end': [srow + drow, scol + dcol],
    \ 'expected_sub_mode': 'v',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 2,
    \ }
endfunction
