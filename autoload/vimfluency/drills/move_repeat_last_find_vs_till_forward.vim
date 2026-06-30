" move_repeat_last_find_vs_till_forward — ; / , over a forward find
" (f) OR a forward till (t). The family-discrimination tier: both
" setups go forward, so direction is no longer the question — the
" learner must read whether the target sits ON the search char (use
" f) or ONE CELL BEFORE it (use t), then repeat with ; / ,.
"
" This is the subtle one. f and t differ only by the off-by-one
" landing; mixing them forces the learner to read the target's
" relationship to the char rather than defaulting to one motion.
"
" Four scenarios, ~evenly mixed (delegated to the two forward
" single-family drills, each a 50/50 ; / , mix):
"
"   f;  matches ahead, land ON, continue forward
"   f,  cursor between, land ON forward then reverse back
"   t;  matches ahead, land BEFORE, continue forward
"   t,  cursor between, land BEFORE forward then reverse back
"
" The families never cross-solve: f{c}; on a t-item lands ON the char
" (one past the t-item's target), and t{c}; on an f-item lands one
" short — so the wrong choice visibly misses, and the discrimination
" is real.
"
" Geometry, cheat-defense, and the cpoptions ';'-strip are inherited
" from the two delegated generators (move_repeat_last_find_forward and
" move_repeat_last_till_forward). See those files for the landings.

function! vimfluency#drills#move_repeat_last_find_vs_till_forward#meta() abort
  return {'id': 'move_repeat_last_find_vs_till_forward',
    \ 'name': 'repeat last find vs till, forward (; ,)',
    \ 'aim': 20, 'allowed_keys': ';,ft',
    \ 'prereqs': ['move_repeat_last_find_forward', 'move_repeat_last_till_forward'],
    \ 'parallel_to': [], 'keys': ';/,', 'family': 'motion',
    \ 'test_sequence': [';', ',']}
endfunction

function! vimfluency#drills#move_repeat_last_find_vs_till_forward#lesson() abort
  " buf1: search char 's' at cols 4 and 10 (p=4, q=10). Frames 2-3 are
  " the key juxtaposition: identical cursor (col 2), the ONLY change is
  " f (land on, target 10) vs t (land before, target 9). Frames 4-5
  " cover the , cases.
  let buf1 = ['kanslxqwzsmrbt']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 1],
    \  'prompt': [
    \    'Both setups go forward now — the question is f vs t:',
    \    '',
    \    '    f   →   target lands ON the char (find)',
    \    '    t   →   target lands ONE CELL BEFORE the char (till)',
    \    '',
    \    'Then ; repeats it forward, , reverses. Read where the target',
    \    'sits relative to the char to pick f or t.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 2], 'target': [1, 10],
    \  'solve': ['fs', ';'],
    \  'waypoints': [[1, 4]],
    \  'prompt': 'Target is ON the second s. Press fs (lands on the first s, 1), then ; (forward onto the second s, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 2], 'target': [1, 9],
    \  'solve': ['ts', ';'],
    \  'waypoints': [[1, 3]],
    \  'prompt': 'Same cursor — but the target is one BEFORE the second s. Press ts (lands before the first s, 1), then ; (stops before the second, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 7], 'target': [1, 4],
    \  'solve': ['fs', ','],
    \  'waypoints': [[1, 10]],
    \  'prompt': 'Target is ON the first s, behind you. Press fs (forward onto the second s, 1), then , (reverse back onto the first, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 8], 'target': [1, 5],
    \  'solve': ['ts', ','],
    \  'waypoints': [[1, 9]],
    \  'prompt': 'Target is one AFTER the first s. Press ts (before the second s, 1), then , (reverse to one after the first, 2).'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_repeat_last_find_vs_till_forward#generate() abort
  " 50/50 mix of forward-find and forward-till items; each delegated
  " generator is itself a 50/50 ; / , mix, so the 4-way set is roughly
  " uniform. Both are independently cheat-defended and shape-verified.
  if s:rand(2) == 0
    return vimfluency#drills#move_repeat_last_find_forward#generate()
  else
    return vimfluency#drills#move_repeat_last_till_forward#generate()
  endif
endfunction
