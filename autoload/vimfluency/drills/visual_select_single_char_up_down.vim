" visual_select_single_char_up_down — vj vs vk. Foundational v-family
" pair: charwise visual selection extended one row in either direction.
" Shared quality: charwise visual selection that crosses one line
" boundary. Juxtaposed quality: direction (down vs up).
"
" Production path: the learner presses v (enter charwise visual mode),
" then j or k (extend selection one row). The selection wraps the
" end-of-line and continues to the matching column on the next/prev
" row. The runner's visual_motion kind credits when mode() == 'v' AND
" anchor + cursor positions match expected.
"
" Design constraints:
"   - target on the SAME column as start (no horizontal component —
"     that's vh/vl's job)
"   - target row offset ∈ {-1, +1} (single-line extension only)
"   - lines are equal length so j/k preserve column cleanly (no edge-
"     clipping where the cursor would snap to a shorter line)
"   - start row kept in the interior (margin 1 above and below) so
"     vj-row+1 and vk-row-1 both land on a real line
"   - start col can be anywhere — direction is read off "is the target
"     cell above or below" rather than column position

let s:chars = ['a','b','c','d','e','f','g','h','i','j','k','m','n','p',
  \ 'q','r','s','t','u','v','w','x','y','z',
  \ '2','3','4','5','6','7','8','9']

function! vimfluency#drills#visual_select_single_char_up_down#meta() abort
  " Aim mirrors vh/vl (50/min). Vertical visual extension is
  " structurally the same effort — enter visual, press one direction
  " key. Starting guess; revise on data.
  return {'id': 'visual_select_single_char_up_down',
    \ 'name': 'extend selection down / up (vj / vk)', 'aim': 50,
    \ 'allowed_keys': 'vjk', 'kind': 'visual_motion',
    \ 'prereqs': ['switch_mode_to_visual', 'move_single_char_up_down'],
    \ 'parallel_to': ['delete_two_lines_down_up',
    \                  'visual_select_single_char_left_right'],
    \ 'keys': 'vj/vk', 'family': 'v',
    \ 'test_sequence': ['vj', 'vk']}
endfunction

function! vimfluency#drills#visual_select_single_char_up_down#lesson() abort
  let buf = ['abcdef', 'ghijkl', 'mnopqr', 'stuvwx', 'yzabcd']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [3, 4],
    \  'prompt': [
    \    'v starts charwise visual selection at the cursor.',
    \    'j extends the selection one row down.',
    \    'k extends the selection one row up.',
    \    '',
    \    '  vj → selection wraps to the same column on the next row',
    \    '  vk → selection wraps to the same column on the prev row',
    \    '',
    \    'Press <Space> to continue.']},
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

function! vimfluency#drills#visual_select_single_char_up_down#generate() abort
  let line_len = 20
  let n_lines = 7
  let lines = []
  for _ in range(n_lines)
    call add(lines, s:make_line(line_len))
  endfor

  " start row in interior (margin 1 above and below for ±1 extension)
  let srow = 2 + s:rand(n_lines - 2)
  " start col anywhere (no horizontal component)
  let scol = 1 + s:rand(line_len)

  " direction: -1 (vk) or +1 (vj)
  let drow = s:rand(2) == 0 ? -1 : 1
  let motion = drow > 0 ? 'vj' : 'vk'
  let target_row = srow + drow

  return {
    \ 'lines': lines,
    \ 'start': [srow, scol],
    \ 'target': [target_row, scol],
    \ 'expected_selection_start': [srow, scol],
    \ 'expected_selection_end': [target_row, scol],
    \ 'expected_sub_mode': 'v',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 2,
    \ }
endfunction
