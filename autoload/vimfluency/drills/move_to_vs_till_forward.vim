" move_to_vs_till_forward — atomic 2-cell drill over the forward
" find/till pair (f, t). Both motions look AHEAD on the line for the
" next occurrence of a search character; they differ in WHERE they
" land:
"
"   f{c} → lands ON the next c
"   t{c} → lands ONE CELL BEFORE the next c
"
" THE DISCRIMINATION THIS DRILLS: any target cell is reachable two
" ways — f with the target's own char (X), or t with the char to its
" right (Z). The correct pick is the one whose search char does NOT
" occur again between the cursor and the target; the repeated one
" makes the motion stop too early (wasted motions to recover).
"
"   t-item:  C n n   n X n   n X Z   n n n      ← X repeats → f{X}
"            (Z at target+1 is unique)             stops early; t{Z} ✓
"   f-item:  C n n   n Z n   n X Z   n n n      ← Z repeats → t{Z}
"            (X unique in the span)                stops early; f{X} ✓
"
" Item geometry is CONSTANT, mirroring move_to_vs_till_backward
" (see that file for the 2026-06-11 diary rationale): 15-col line of
" four 3-char blocks, cursor always col 1, target always col 10.
" Four random letters per item provide the noise. The
" realistic-content version is move_to_vs_till_forward_in_words
" (prereq: this one).
"
" Cheat-defense:
"   - the wrong member of the f/t pair always lands off-target — the
"     repeat between cursor and target is the core shape
"   - distance cursor→target = 9 → an l-walk costs 9 keystrokes
"   - letter blocks (not words) keep w/e/b from landing near the
"     target's interior position
"   - $/g_ land col 15 ≠ 10; 0/^ land col 1 (already there)
"   - cursor cell is a noise letter ≠ X and ≠ Z

let s:LETTERS = ['a','b','c','d','e','f','g','h','j','k','m','n',
  \ 'p','q','r','s','t','u','v','w','x','y','z']

" Non-space columns the X/Z repeat may occupy: strictly between the
" cursor (col 1) and the target (col 10), skipping space cols 4 and 8.
let s:REPEAT_COLS = [2, 3, 5, 6, 7, 9]

function! vimfluency#drills#move_to_vs_till_forward#meta() abort
  " Aim 50/min, matching move_to_vs_till_backward. Single 2-cell
  " discrimination, single chord per item.
  return {'id': 'move_to_vs_till_forward',
    \ 'name': 'find vs till, forward (f / t)',
    \ 'aim': 20, 'allowed_keys': 'ft',
    \ 'prereqs': ['move_to_char_forward_backward', 'move_till_char_forward_backward'],
    \ 'keys': 'f/t', 'family': 'motion',
    \ 'parallel_to': ['move_to_vs_till_backward'],
    \ 'test_sequence': ['f', 't']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Four distinct random letters: [X, Z, noise1, noise2]
function! s:pick_letters() abort
  let pool = copy(s:LETTERS)
  let picked = []
  for _ in range(4)
    let i = s:rand(len(pool))
    call add(picked, remove(pool, i))
  endfor
  return picked
endfunction

function! vimfluency#drills#move_to_vs_till_forward#generate() abort
  let [X, Z, n1, n2] = s:pick_letters()
  let is_t = s:rand(2) == 0
  let repeat_col = s:REPEAT_COLS[s:rand(len(s:REPEAT_COLS))]

  " cells[c] for c 1..15; spaces at 4, 8, 12.
  let cells = {}
  for c in [1, 2, 3, 5, 6, 7, 9, 13, 14, 15]
    let cells[c] = s:rand(2) ? n1 : n2
  endfor
  let cells[4] = ' ' | let cells[8] = ' ' | let cells[12] = ' '
  let cells[10] = X
  let cells[11] = Z
  " t-item: X repeats between cursor and target → f{X} stops early,
  " t{Z} is the clean answer. f-item: Z repeats instead → t{Z} stops
  " early, f{X} is clean.
  let cells[repeat_col] = is_t ? X : Z

  let line = ''
  for c in range(1, 15)
    let line .= cells[c]
  endfor

  return {'lines': [line],
    \ 'start': [1, 1], 'target': [1, 10],
    \ 'expected_motion': is_t ? 't' : 'f',
    \ 'optimal_motions': 1}
endfunction

function! vimfluency#drills#move_to_vs_till_forward#lesson() abort
  " Both try frames use the SAME target cell — the only thing that
  " changes between them is which char repeats in the span. That's
  " the juxtaposition: identical geometry, opposite answer.
  let buf_t = ['ddd dbc cba aaa']
  let buf_f = ['ddd dcc aba aaa']
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two forward-motion keys:',
    \    '',
    \    '    f{c}  →  lands ON the next c',
    \    '    t{c}  →  lands ONE CELL BEFORE the next c',
    \    '',
    \    'Any target is reachable BOTH ways: f with the char under the',
    \    'target, t with the char to its right. Pick the one whose char',
    \    'does NOT appear again between your cursor and the target —',
    \    'the repeated one stops too early.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf_t, 'start': [1, 1], 'target': [1, 10],
    \  'expected_motion': 't', 'optimal_motions': 1,
    \  'prompt': 'Target is the b. Another b sits between you and it — fb stops there. The a to its right is unique ahead — press ta.'},
    \ {'kind': 'try', 'lines': buf_f, 'start': [1, 1], 'target': [1, 10],
    \  'expected_motion': 'f', 'optimal_motions': 1,
    \  'prompt': 'Same target cell — but now the a repeats (col 9), so ta stops early. The b is unique — press fb.'},
    \ ]
endfunction
