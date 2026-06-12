" move_to_till_forward_backward — 4-way composite over f / F / t / T.
" Mixes the by-find-vs-till split (move_to_char_forward_backward,
" move_till_char_forward_backward) with the by-direction split
" (move_to_till_forward, move_to_till_backward). The cognitive task
" is: read the direction (cursor side), then pick find vs till by
" which search char does NOT repeat in the span (the 2026-06-11
" shapes — see move_to_till_backward for the worked rationale).
"
" Cheat-defense is inherited from the underlying generators —
" delegate to move_to_char_forward_backward.generate and
" move_till_char_forward_backward.generate at random. Both enforce
" the discriminative shape (the wrong member of the find/till pair
" always lands off-target), so every item in this 4-way mix forces
" BOTH axes. Optimal_motions is 1 for every item.

function! vimfluency#pinpoints#move_to_till_forward_backward#meta() abort
  return {'id': 'move_to_till_forward_backward',
    \ 'name': 'find char, 4-way (f / F / t / T)',
    \ 'aim': 35, 'allowed_keys': 'fFtT',
    \ 'prereqs': ['move_to_char_forward_backward',
    \             'move_till_char_forward_backward',
    \             'move_to_till_forward',
    \             'move_to_till_backward'],
    \ 'keys': 'f/F/t/T', 'family': 'motion',
    \ 'test_sequence': ['f', 't', 'F', 'T']}
endfunction

function! vimfluency#pinpoints#move_to_till_forward_backward#lesson() abort
  " The first frame names the discrimination rule. The four try frames
  " walk through one example of each motion in the same buffer so the
  " learner sees the off-by-one shift between f and t side by side.
  " The test phase that runs after these frames generates novel items
  " with no prompt naming the motion — that's where the discrimination
  " is exercised cold.
  let buf = ['the cat ran past us today']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 1],
    \  'prompt': [
    \    'f lands ON the next char; t lands ONE CELL BEFORE it.',
    \    'F and T are the backward versions.',
    \    '',
    \    'Two reads per item: direction first (is the target ahead or',
    \    'behind?), then find vs till — any target is reachable BOTH',
    \    'ways, so pick the motion whose search char does NOT appear',
    \    'again between you and the target. The repeated one stops',
    \    'too early.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 13],
    \  'prompt': 'Target is ON the p — use fp.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 12],
    \  'prompt': 'Target is ONE BEFORE the p — use tp.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 25], 'target': [1, 13],
    \  'prompt': 'Target is ON the p — use Fp (backward).'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 25], 'target': [1, 14],
    \  'prompt': 'Target is ONE AFTER the p — use Tp (backward).'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#move_to_till_forward_backward#generate() abort
  " 50/50 mix of f/F and t/T items. Each delegated generator already
  " handles its own cheat-defense, target uniqueness, and word-
  " margin constraints, so this composite inherits all of that. The
  " forward / backward direction within each is also 50/50 inside
  " the delegated generators, so the 4-way mix is roughly uniform.
  if s:rand(2) == 0
    return vimfluency#pinpoints#move_to_char_forward_backward#generate()
  else
    return vimfluency#pinpoints#move_till_char_forward_backward#generate()
  endif
endfunction
