" move_repeat_last_find_vs_till_forward_backward — ; / , over the full
" f / F / t / T set. The ceiling of the repeat-find family: every item
" varies BOTH axes at once, so the learner makes the complete read
" before repeating:
"
"   direction — matches AHEAD (forward, f/t) or BEHIND (backward, F/T)?
"   family    — target ON the char (find, f/F) or BESIDE it (till, t/T)?
"
" then ; repeats that find the same way, , reverses it. Eight
" scenarios in all (f; f, F; F, t; t, T; T,), ~evenly mixed.
"
" Delegates 50/50 to the two family-discrimination drills
" (move_repeat_last_find_vs_till_forward / _backward), each of which
" delegates to two single-family generators — so the eight-way set is
" roughly uniform and every item is a fully cheat-defended,
" shape-verified single-drill item. The cpoptions ';'-strip and all
" geometry are inherited.
"
" This is the capstone; there is no harder repeat-find drill above it.

function! vimfluency#drills#move_repeat_last_find_vs_till_forward_backward#meta() abort
  return {'id': 'move_repeat_last_find_vs_till_forward_backward',
    \ 'name': 'repeat last find/till, all ways (; ,)',
    \ 'aim': 25, 'allowed_keys': ';,fFtT',
    \ 'prereqs': ['move_repeat_last_find_vs_till_forward', 'move_repeat_last_find_vs_till_backward'],
    \ 'parallel_to': ['move_repeat_last_find_forward_backward'], 'keys': ';/,', 'family': 'motion',
    \ 'test_sequence': [';', ',']}
endfunction

function! vimfluency#drills#move_repeat_last_find_vs_till_forward_backward#lesson() abort
  " buf1: search char 's' at cols 4 and 10 (p=4, q=10). The four try
  " frames cover all four setups with ; so the learner performs each:
  " the forward pair (cursor 2) splits f (on, target 10) vs t (before,
  " target 9); the backward pair (cursor 12) splits F (on, target 4) vs
  " T (after, target 5). The test phase then drills the full ; / , mix.
  let buf1 = ['kanslxqwzsmrbt']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 1],
    \  'prompt': [
    \    'Everything together. Each key combines direction + find/till:',
    \    '',
    \    '    f   →   match ahead, target ON the char',
    \    '    t   →   match ahead, target one cell before it',
    \    '    F   →   match behind, target ON the char',
    \    '    T   →   match behind, target one cell after it',
    \    '',
    \    'Pick the setup, then ; repeats it the same way, , reverses.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 2], 'target': [1, 10],
    \  'solve': ['fs', ';'],
    \  'waypoints': [[1, 4]],
    \  'prompt': 'Ahead, target ON the second s → fs (onto the first, 1), then ; (forward onto the second, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 2], 'target': [1, 9],
    \  'solve': ['ts', ';'],
    \  'waypoints': [[1, 3]],
    \  'prompt': 'Ahead, target one BEFORE the second s → ts (before the first, 1), then ; (forward to before the second, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 4],
    \  'solve': ['Fs', ';'],
    \  'waypoints': [[1, 10]],
    \  'prompt': 'Behind, target ON the first s → Fs (onto the second, 1), then ; (backward onto the first, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 5],
    \  'solve': ['Ts', ';'],
    \  'waypoints': [[1, 11]],
    \  'prompt': 'Behind, target one AFTER the first s → Ts (after the second, 1), then ; (backward to after the first, 2).'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_repeat_last_find_vs_till_forward_backward#generate() abort
  " 50/50 across the forward and backward family mixes; each is itself
  " a 4-way spread, so the result is ~uniform over all eight scenarios.
  if s:rand(2) == 0
    return vimfluency#drills#move_repeat_last_find_vs_till_forward#generate()
  else
    return vimfluency#drills#move_repeat_last_find_vs_till_backward#generate()
  endif
endfunction
