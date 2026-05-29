" move_single_char_left_right — h vs l. Narrower 2-cell sibling of 1A.1 (hjkl). Shared
" quality: single-char horizontal motion. Juxtaposed quality:
" direction (left vs right). Use this pinpoint as a fallback for
" learners who plateau on 1A.1 specifically on the horizontal axis.
"
" Design constraints:
"   - target on the SAME row as start (no vertical component)
"   - target Chebyshev distance ∈ {1, 2} from start on the col axis
"   - lines are spaceless filler so w/b are never shorter
"   - start col kept ≥3 from either edge so 0/^/$ are never shorter
"   - both h-items and l-items can occur at any column — there's no
"     start-column tell, the user has to read which side red sits on
"     (in this pinpoint the cue is just cursor vs target relative
"     position; no red — this is motion kind)

let s:chars = ['a','b','c','d','e','f','g','h','i','j','k','m','n','p',
  \ 'q','r','s','t','u','v','w','x','y','z',
  \ '2','3','4','5','6','7','8','9']

function! vimfluency#pinpoints#move_single_char_left_right#meta() abort
  " Aim ~ 1A.1's 60/min. Narrower discrimination = slightly easier
  " in principle, but a learner who reaches here is here because they
  " plateaued — keep the aim honest rather than inflated. Starting
  " guess, revise on data.
  return {'id': 'move_single_char_left_right', 'name': 'h l', 'aim': 60,
    \ 'allowed_keys': 'hl', 'prereqs': ['change_current_mode', 'insert_basic'],
    \ 'narrower_of': 'move_single_char_up_down_left_right', 'parallel_to': ['move_single_char_up_down'], 'keys': 'h/l', 'family': 'motion'}
endfunction

function! vimfluency#pinpoints#move_single_char_left_right#lesson() abort
  let buf = ['abcdef', 'ghijkl', 'mnopqr', 'stuvwx', 'yzabcd']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [3, 4],
    \  'prompt': 'h moves the cursor one column left; l one column right. They differ only by direction.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [3, 3],
    \  'prompt': 'Press h — moves cursor one column left.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 4], 'target': [3, 5],
    \  'prompt': 'Press l — moves cursor one column right.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 2], 'target': [3, 4],
    \  'prompt': 'Use l twice — motions repeat.'},
    \ {'kind': 'try', 'lines': buf, 'start': [3, 5], 'target': [3, 3],
    \  'prompt': 'Use h twice.'},
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

function! vimfluency#pinpoints#move_single_char_left_right#generate() abort
  let line_len = 20
  let n_lines = 7
  let lines = []
  for _ in range(n_lines)
    call add(lines, s:make_line(line_len))
  endfor

  " start row anywhere (no vertical component, so margin doesn't matter)
  let srow = 1 + s:rand(n_lines)
  " start col with margin 3 from either edge
  let scol = 4 + s:rand(line_len - 7)

  " col offset in {-2, -1, 1, 2}
  let dcol = s:rand(4)
  if dcol >= 2
    let dcol += 1
  endif
  let dcol -= 2

  let motion = dcol > 0 ? 'l' : 'h'
  let optimal_motions = abs(dcol)

  return {'lines': lines, 'start': [srow, scol], 'target': [srow, scol + dcol],
    \ 'expected_motion': motion, 'optimal_motions': optimal_motions}
endfunction
