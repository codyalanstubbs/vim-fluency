" copy_line_to_target — the first yank+paste drill: copy the current
" line and drop it on the marked line. yy → navigate → P.
"
" Yank alone changes nothing observable, so (per the project's
" measurement rule) we only ever drill it as a visible combo: yank the
" cursor's line, move to the green destination, paste it there. The
" buffer changes at the paste, and buffer-state credit does the rest —
" no register inspection needed. The combo is self-enforcing: the target
" needs THIS line's text at the destination, so a stale register just
" produces a wrong buffer.
"
" P (paste above), not p: navigating the cursor onto the green line and
" pressing P inserts the copy AT that line and leaves the cursor on the
" copy — so green marks the destination, where the copy lands, and where
" the cursor ends, all the same cell. p (paste below) would land the
" copy one row past the cue (an off-by-one the learner has to correct
" for). p vs P gets its own drill later.
"
" Direction is the discrimination axis (like dj/dk): the destination is
" above or below the source, so expected_motion is yyP↓ / yyP↑. Both are
" the same keys — the axis keeps per-line-direction stats and stops the
" anti-streak guard from spinning on a lone motion.
"
" kind 'editing' + show_target: the buffer changes (editing credit path)
" but the green destination is the cue, so we opt back into the green
" cell the editing kind normally hides. No red range.
"
" Measurement: optimal = |D - S| navigation steps + 1 paste. yy fires no
" event (no cursor move, no buffer change) so it isn't billed — a small
" undercount, consistent with the event model (dw is billed 1, not 2).
"
" No cheat gate in the text-object sense: the behavior is 'copy a line',
" credited by outcome. :t (ex copy) reaches the same buffer but costs
" more keystrokes; the runner credits it anyway (like dl vs x), and the
" yyP token still labels the intended combo.

let s:words = ['alpha', 'bravo', 'charlie', 'delta', 'echo',
  \ 'foxtrot', 'golf', 'hotel', 'india', 'juliet', 'kilo', 'lima',
  \ 'mike', 'november', 'oscar', 'papa', 'quebec', 'romeo']

function! vimfluency#drills#copy_line_to_target#meta() abort
  return {'id': 'copy_line_to_target', 'name': 'copy a line to the target (yy … P)',
    \ 'aim': 25, 'allowed_keys': 'yyPjk', 'kind': 'editing', 'show_target': 1,
    \ 'prereqs': ['move_single_char_up_down'], 'keys': 'yyP', 'family': 'yank',
    \ 'test_sequence': ['yyP↓', 'yyP↑']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" A column of n distinct one-word lines.
function! s:make_lines(n) abort
  let pool = copy(s:words)
  let lines = []
  while len(lines) < a:n
    let i = s:rand(len(pool))
    call add(lines, pool[i])
    call remove(pool, i)
  endwhile
  return lines
endfunction

function! vimfluency#drills#copy_line_to_target#generate() abort
  let n = 5 + s:rand(2)          " 5 or 6 lines
  let lines = s:make_lines(n)

  " Distinct source (cursor start) and destination (green) rows.
  let s_row = 1 + s:rand(n)
  let d_row = 1 + s:rand(n)
  while d_row == s_row
    let d_row = 1 + s:rand(n)
  endwhile

  " P inserts the yanked line AT d_row, pushing the old d_row down; the
  " cursor lands on the copy at d_row. (insert() before index d_row-1 —
  " a slice like lines[0:d_row-2] would wrap to the whole list at d_row=1.)
  let target_lines = copy(lines)
  call insert(target_lines, lines[s_row - 1], d_row - 1)

  let motion = d_row > s_row ? 'yyP↓' : 'yyP↑'

  return {
    \ 'lines': lines,
    \ 'target_lines': target_lines,
    \ 'start': [s_row, 1],
    \ 'target': [d_row, 1],
    \ 'show_target': 1,
    \ 'prompt': 'Copy your line to the green line: yy, move to it, then P.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': abs(d_row - s_row) + 1,
    \ }
endfunction

function! vimfluency#drills#copy_line_to_target#lesson() abort
  " Try frames both directions. show_target draws the green destination
  " even though the frame changes the buffer (editing kind).
  let buf = ['alpha', 'bravo', 'charlie', 'delta', 'echo']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [2, 1],
    \  'prompt': [
    \    'Copy a whole line somewhere else in three moves:',
    \    '',
    \    '    yy        →   yank (copy) the line you''re on',
    \    '    j / k     →   move to the line you want it on (the green one)',
    \    '    P         →   paste it there',
    \    '',
    \    'P drops the copy ON the line you moved to, pushing that line down.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [2, 1], 'target': [4, 1], 'show_target': 1,
    \  'target_lines': ['alpha', 'bravo', 'charlie', 'bravo', 'delta', 'echo'],
    \  'expected_motion': 'yyP↓', 'optimal_motions': 3,
    \  'prompt': 'yy, then jj down to the green line, then P — bravo lands there.'},
    \ {'kind': 'try', 'lines': buf, 'start': [4, 1], 'target': [1, 1], 'show_target': 1,
    \  'target_lines': ['delta', 'alpha', 'bravo', 'charlie', 'delta', 'echo'],
    \  'expected_motion': 'yyP↑', 'optimal_motions': 4,
    \  'prompt': 'yy, then kkk up to the green line, then P — delta lands on top.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [3, 1], 'show_target': 1,
    \  'target_lines': ['alpha', 'bravo', 'alpha', 'charlie', 'delta', 'echo'],
    \  'expected_motion': 'yyP↓', 'optimal_motions': 3,
    \  'prompt': 'yy, move down to green, P.'},
    \ {'kind': 'try', 'lines': buf, 'start': [5, 1], 'target': [2, 1], 'show_target': 1,
    \  'target_lines': ['alpha', 'echo', 'bravo', 'charlie', 'delta', 'echo'],
    \  'expected_motion': 'yyP↑', 'optimal_motions': 4,
    \  'prompt': 'yy, move up to green, P.'},
    \ ]
endfunction
