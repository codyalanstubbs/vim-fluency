" move_to_vs_till_backward — atomic 2-cell drill over the backward
" find/till pair (F, T). Both motions look BEHIND on the line for
" the previous occurrence of a search character; they differ in
" WHERE they land:
"
"   F{c} → lands ON the previous c
"   T{c} → lands ONE CELL AFTER the previous c
"
" THE DISCRIMINATION THIS DRILLS: any target cell is reachable two
" ways — F with the target's own char (X), or T with the char to its
" left (Y). The correct pick is the one whose search char does NOT
" occur again between the target and the cursor; the repeated one
" makes the motion stop too early (wasted motions to recover).
"
"   T-item:  q q q   q X n   n X n   n n C      ← X repeats → F{X}
"            (Y at target-1 is unique)             stops early; T{Y} ✓
"   F-item:  q q q   Y X Y   n n n   n n C      ← Y repeats → T{Y}
"            (X unique in the span)                stops early; F{X} ✓
"
" Item geometry is CONSTANT by design (2026-06-11 diary): 15-col
" line of four 3-char blocks, cursor always col 15, target always
" col 6. Four random letters per item give just enough noise that
" the learner must actually read the chars; everything else is held
" still so the skim-and-pick discrimination is the only moving part.
" Drill integrity over natural-looking content — same trade as
" the vowel-soup alphabet in move_to_word_start_forward_backward.
" The realistic-content version of this drill is
" move_to_vs_till_backward_in_words (prereq: this one).
"
" Cheat-defense:
"   - the wrong member of the F/T pair always lands off-target (the
"     repeat is placed between target and cursor) — that's the core
"     shape, not an afterthought
"   - distance cursor→target = 9 → an h-walk costs 9 keystrokes
"   - blocks of letters (no real words) keep b/ge/w/e from landing
"     anywhere near the target's interior position
"   - 0/^ land col 1 ≠ 6; $ lands col 15 (already there)
"   - cursor cell is a noise letter ≠ X and ≠ Y

let s:LETTERS = ['a','b','c','d','e','f','g','h','j','k','m','n',
  \ 'p','q','r','s','t','u','v','w','x','y','z']

" Non-space columns the X/Y repeat may occupy: strictly between the
" target (col 6) and the cursor (col 15), skipping the space cols
" 8 and 12 and the col-7 slot's neighbors' specifics handled below.
let s:REPEAT_COLS = [7, 9, 10, 11, 13, 14]

function! vimfluency#drills#move_to_vs_till_backward#meta() abort
  return {'id': 'move_to_vs_till_backward',
    \ 'name': 'find vs till, backward (F / T)',
    \ 'aim': 20, 'allowed_keys': 'FT',
    \ 'prereqs': [], 'keys': 'F/T', 'family': 'motion',
    \ 'parallel_to': ['move_to_vs_till_forward'],
    \ 'test_sequence': ['F', 'T']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Four distinct random letters: [X, Y, noise1, noise2]
function! s:pick_letters() abort
  let pool = copy(s:LETTERS)
  let picked = []
  for _ in range(4)
    let i = s:rand(len(pool))
    call add(picked, remove(pool, i))
  endfor
  return picked
endfunction

function! vimfluency#drills#move_to_vs_till_backward#generate() abort
  let [X, Y, n1, n2] = s:pick_letters()
  let is_T = s:rand(2) == 0
  let repeat_col = s:REPEAT_COLS[s:rand(len(s:REPEAT_COLS))]

  " cells[c] for c 1..15; spaces at 4, 8, 12.
  let cells = {}
  for c in [1, 2, 3, 7, 9, 10, 11, 13, 14, 15]
    let cells[c] = s:rand(2) ? n1 : n2
  endfor
  let cells[4] = ' ' | let cells[8] = ' ' | let cells[12] = ' '
  let cells[5] = Y
  let cells[6] = X
  " T-item: X repeats between target and cursor → F{X} stops early,
  " T{Y} is the clean answer. F-item: Y repeats instead → T{Y} stops
  " early, F{X} is clean.
  let cells[repeat_col] = is_T ? X : Y

  let line = ''
  for c in range(1, 15)
    let line .= cells[c]
  endfor

  return {'lines': [line],
    \ 'start': [1, 15], 'target': [1, 6],
    \ 'expected_motion': is_T ? 'T' : 'F',
    \ 'optimal_motions': 1}
endfunction

function! vimfluency#drills#move_to_vs_till_backward#lesson() abort
  " Both try frames use the SAME target cell — the only thing that
  " changes between them is which char repeats in the span. That's
  " the juxtaposition: identical geometry, opposite answer.
  let buf_T = ['aaa abc cbd ddd']
  let buf_F = ['aaa aba ccd ddd']
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two backward-motion keys:',
    \    '',
    \    '    F{c}  →  lands ON the previous c',
    \    '    T{c}  →  lands ONE CELL AFTER the previous c',
    \    '',
    \    'Any target is reachable BOTH ways: F with the char under the',
    \    'target, T with the char to its left. Pick the one whose char',
    \    'does NOT appear again between the target and your cursor —',
    \    'the repeated one stops too early.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf_T, 'start': [1, 15], 'target': [1, 6],
    \  'expected_motion': 'T', 'optimal_motions': 1,
    \  'prompt': 'Target is the b. Another b sits between it and you — Fb stops there. The a to its left is nearest — press Ta.'},
    \ {'kind': 'try', 'lines': buf_F, 'start': [1, 15], 'target': [1, 6],
    \  'expected_motion': 'F', 'optimal_motions': 1,
    \  'prompt': 'Same target cell — but now the a repeats (col 7), so Ta stops early. The b is unique — press Fb.'},
    \ ]
endfunction
