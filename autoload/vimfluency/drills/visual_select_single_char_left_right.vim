" visual_select_single_char_left_right — vh vs vl. Foundational v-family
" pair: charwise visual selection extended one column in either direction.
" Shared quality: charwise visual selection with a single-column extension.
" Juxtaposed quality: direction (left vs right).
"
" Production path: the learner presses v (enter charwise visual mode),
" then h or l (extend selection one column). The runner's visual_motion
" kind credits when mode() == 'v' AND the selection's anchor + endpoint
" match the item's expected_selection_start / expected_selection_end.
"
" Design constraints:
"   - target on the SAME row as start (no vertical component — that's vj/vk's job)
"   - target Chebyshev distance ∈ {1} on the col axis (single-column extension)
"   - lines are spaceless filler so vw/vb are never shorter
"   - start col kept ≥3 from either edge so v0/v^/v$ are never shorter
"   - both vh-items and vl-items can occur at any column — the green
"     VfTarget cell marks where the selection should END; the cursor
"     starts at the anchor, so direction is read off "is the highlight
"     left or right of the cursor"

let s:chars = ['a','b','c','d','e','f','g','h','i','j','k','m','n','p',
  \ 'q','r','s','t','u','v','w','x','y','z',
  \ '2','3','4','5','6','7','8','9']

function! vimfluency#drills#visual_select_single_char_left_right#meta() abort
  " Aim is a starting guess. Visual-mode entry adds cognitive load over
  " a pure h/l motion, so the aim is set below move_single_char_left_right's
  " 60/min but above delete_single_char_left_right's 40/min — visual is
  " lighter than delete because there's no operator+motion fusion.
  return {'id': 'visual_select_single_char_left_right',
    \ 'name': 'extend selection left / right (vh / vl)', 'aim': 50,
    \ 'allowed_keys': 'vhl', 'kind': 'visual_motion',
    \ 'prereqs': ['switch_mode_to_visual', 'move_single_char_left_right'],
    \ 'parallel_to': ['delete_single_char_left_right'],
    \ 'keys': 'vh/vl', 'family': 'v',
    \ 'test_sequence': ['vh', 'vl']}
endfunction

function! vimfluency#drills#visual_select_single_char_left_right#lesson() abort
  let buf = ['abcdef', 'ghijkl', 'mnopqr', 'stuvwx', 'yzabcd']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [3, 4],
    \  'prompt': [
    \    'Visual selection — v starts it, then h / l extend it:',
    \    '',
    \    '    vh   →   extends the selection one column left',
    \    '    vl   →   extends the selection one column right',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [3, 5],
    \  'expected_selection_start': [3, 4], 'expected_selection_end': [3, 5],
    \  'expected_sub_mode': 'v',
    \  'expected_motion': 'vl', 'optimal_motions': 2,
    \  'prompt': 'Press v then l — extends the visual selection one column right.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [3, 3],
    \  'expected_selection_start': [3, 4], 'expected_selection_end': [3, 3],
    \  'expected_sub_mode': 'v',
    \  'expected_motion': 'vh', 'optimal_motions': 2,
    \  'prompt': 'Press v then h — extends the visual selection one column left.'},
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

function! vimfluency#drills#visual_select_single_char_left_right#generate() abort
  let line_len = 20
  let n_lines = 7
  let lines = []
  for _ in range(n_lines)
    call add(lines, s:make_line(line_len))
  endfor

  " start row anywhere (no vertical component)
  let srow = 1 + s:rand(n_lines)
  " start col with margin 3 from either edge so v0/v$ are never shorter
  let scol = 4 + s:rand(line_len - 7)

  " direction: -1 (vh) or +1 (vl)
  let dcol = s:rand(2) == 0 ? -1 : 1
  let motion = dcol > 0 ? 'vl' : 'vh'
  let target_col = scol + dcol

  return {
    \ 'lines': lines,
    \ 'start': [srow, scol],
    \ 'target': [srow, target_col],
    \ 'expected_selection_start': [srow, scol],
    \ 'expected_selection_end': [srow, target_col],
    \ 'expected_sub_mode': 'v',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 2,
    \ }
endfunction
