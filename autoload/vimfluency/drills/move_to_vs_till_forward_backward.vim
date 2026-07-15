" move_to_vs_till_forward_backward — 4-way composite over f / F / t / T.
" Mixes the by-find-vs-till split (move_to_char_forward_backward,
" move_till_char_forward_backward) with the by-direction split
" (move_to_vs_till_forward, move_to_vs_till_backward). The cognitive task
" is: read the direction (cursor side), then pick find vs till by
" which search char does NOT repeat in the span (the 2026-06-11
" shapes — see move_to_vs_till_backward for the worked rationale).
"
" Cheat-defense is inherited from the underlying generators —
" delegate to move_to_char_forward_backward.generate and
" move_till_char_forward_backward.generate at random. Both enforce
" the discriminative shape (the wrong member of the find/till pair
" always lands off-target), so every item in this 4-way mix forces
" BOTH axes. Optimal_motions is 1 for every item.

function! vimfluency#drills#move_to_vs_till_forward_backward#meta() abort
  return {'id': 'move_to_vs_till_forward_backward',
    \ 'name': 'find vs till, 4-way (f / F / t / T)',
    \ 'aim': 20, 'allowed_keys': 'fFtT',
    \ 'prereqs': ['move_to_vs_till_forward', 'move_to_vs_till_backward'],
    \ 'keys': 'f/F/t/T', 'family': 'motion',
    \ 'test_sequence': ['f', 't', 'F', 'T']}
endfunction

function! vimfluency#drills#move_to_vs_till_forward_backward#lesson() abort
  " Conforms to the move_to_vs_till_* sibling lessons: an empty-buffer
  " show frame that lists all four motions and states the two-axis read,
  " then one try frame per motion that DEMONSTRATES the discrimination —
  " the wrong member of the pair overshoots because its char repeats in
  " the span. Geometry reused from the _in_words siblings (verified).
  let buf_f = ['spend faster point']
  let buf_t = ['point faster spend']
  let buf_F = ['brain saved margin']
  let buf_T = ['fetch target results']
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'All four find/till keys together:',
    \    '',
    \    '    f{c}  →  lands ON the next c',
    \    '    t{c}  →  lands ONE CELL BEFORE the next c',
    \    '    F{c}  →  lands ON the previous c',
    \    '    T{c}  →  lands ONE CELL AFTER the previous c',
    \    '',
    \    'Two reads per item: direction (is the target ahead or behind?),',
    \    'then find vs till — any target is reachable both ways, so pick',
    \    'the motion whose char does NOT repeat in the span. The repeated',
    \    'one stops too early.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf_f, 'start': [1, 1], 'target': [1, 16],
    \  'expected_motion': 'f', 'optimal_motions': 1,
    \  'prompt': 'Ahead, target ON the i in "point" — unique, so fi lands. (tn would stop at the n in "spend".)'},
    \ {'kind': 'try', 'lines': buf_t, 'start': [1, 1], 'target': [1, 17],
    \  'expected_motion': 't', 'optimal_motions': 1,
    \  'prompt': 'Ahead, target the n in "spend" — an earlier n sits in "point", so fn stops there. Press td (the d to its right is unique ahead).'},
    \ {'kind': 'try', 'lines': buf_F, 'start': [1, 17], 'target': [1, 9],
    \  'expected_motion': 'F', 'optimal_motions': 1,
    \  'prompt': 'Behind, target the v — unique, so Fv lands on it. (Ta would stop after the a in "margin".)'},
    \ {'kind': 'try', 'lines': buf_T, 'start': [1, 19], 'target': [1, 9],
    \  'expected_motion': 'T', 'optimal_motions': 1,
    \  'prompt': 'Behind, target the r in "target" — r repeats in "results", so Fr stops there. Press Ta (the a to its left is nearest).'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_to_vs_till_forward_backward#generate() abort
  " 50/50 mix of f/F and t/T items. Each delegated generator already
  " handles its own cheat-defense, target uniqueness, and word-
  " margin constraints, so this composite inherits all of that. The
  " forward / backward direction within each is also 50/50 inside
  " the delegated generators, so the 4-way mix is roughly uniform.
  if s:rand(2) == 0
    return vimfluency#drills#move_to_char_forward_backward#generate()
  else
    return vimfluency#drills#move_till_char_forward_backward#generate()
  endif
endfunction
