" move_repeat_last_till_forward_backward — ; / , over BOTH till
" directions (t and T). The discrimination tier of the till-repeat
" family: the learner reads whether the two matches sit ahead of the
" cursor (forward till t) or behind it (backward till T), sets up with
" the right one, then repeats with ; / ,.
"
" Four scenarios, ~evenly mixed (delegated to the two single-direction
" drills, each already a 50/50 ; / , mix):
"
"   t;  matches ahead, continue forward
"   t,  cursor between, t forward then reverse back
"   T;  matches behind, continue backward
"   T,  cursor between, T backward then reverse forward
"
" The setup direction is never named — the cursor's position relative
" to the pair is the cue (left of both → t, right of both → T, between
" → whichever way you start). ; / , then repeat that till.
"
" Geometry, cheat-defense, and the cpoptions ';'-strip are all
" inherited from the two delegated generators (move_repeat_last_till_
" forward and move_repeat_last_till_backward) — constant-shape lines,
" home-row search chars, matches 6 columns apart. See those files for
" the worked landings.

function! vimfluency#drills#move_repeat_last_till_forward_backward#meta() abort
  return {'id': 'move_repeat_last_till_forward_backward',
    \ 'name': 'repeat last till, both ways (; ,)',
    \ 'aim': 32, 'allowed_keys': ';,tT',
    \ 'prereqs': ['move_repeat_last_till_forward', 'move_repeat_last_till_backward'],
    \ 'parallel_to': ['move_repeat_last_find_forward_backward'], 'keys': ';/,', 'family': 'motion',
    \ 'test_sequence': [';', ',']}
endfunction

function! vimfluency#drills#move_repeat_last_till_forward_backward#lesson() abort
  " buf1: search char 's' at cols 4 and 10 (p=4, q=10). The four try
  " frames walk t; / t, / T; / T, on the same line so the learner
  " sees the direction choice flip with the cursor's position.
  let buf1 = ['kanslxqwzsmrbt']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 1],
    \  'prompt': [
    \    'Both till directions in one drill:',
    \    '',
    \    '    t   →   forward, lands one cell before — matches both AHEAD',
    \    '    T   →   backward, lands one cell after — matches both BEHIND',
    \    '',
    \    'Sitting between the matches, start with whichever side you face.',
    \    'Then ; repeats that till the same way, , reverses it.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 2], 'target': [1, 9],
    \  'waypoints': [[1, 3]],
    \  'prompt': 'Both s''s ahead → ts (lands one before the first, 1), then ; (forward to one before the second, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 5],
    \  'waypoints': [[1, 11]],
    \  'prompt': 'Both s''s behind → Ts (lands one after the nearer, 1), then ; (backward to one after the first, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 8], 'target': [1, 5],
    \  'waypoints': [[1, 9]],
    \  'prompt': 'Between, facing forward → ts (one before the second, 1), then , (reverse back to one after the first, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 6], 'target': [1, 9],
    \  'waypoints': [[1, 5]],
    \  'prompt': 'Between, facing back → Ts (one after the first, 1), then , (reverse forward to one before the second, 2).'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_repeat_last_till_forward_backward#generate() abort
  " 50/50 mix of forward-till and backward-till items; each delegated
  " generator is itself a 50/50 ; / , mix, so the 4-way set is roughly
  " uniform. Both are independently cheat-defended and shape-verified.
  if s:rand(2) == 0
    return vimfluency#drills#move_repeat_last_till_forward#generate()
  else
    return vimfluency#drills#move_repeat_last_till_backward#generate()
  endif
endfunction
