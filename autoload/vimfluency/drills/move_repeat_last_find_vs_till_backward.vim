" move_repeat_last_find_vs_till_backward — ; / , over a backward find
" (F) OR a backward till (T). The backward mirror of
" move_repeat_last_find_vs_till_forward: both setups go backward, so
" direction is fixed — the learner reads whether the target sits ON
" the search char (use F) or ONE CELL AFTER it (use T), then repeats
" with ; / ,.
"
" Four scenarios, ~evenly mixed (delegated to the two backward
" single-family drills, each a 50/50 ; / , mix):
"
"   F;  matches behind, land ON, continue backward
"   F,  cursor between, land ON backward then reverse forward
"   T;  matches behind, land AFTER, continue backward
"   T,  cursor between, land AFTER backward then reverse forward
"
" The families never cross-solve: F{c}; on a T-item lands ON the char
" (one before the T-item's target), and T{c}; on an F-item lands one
" past — so the wrong choice visibly misses and the discrimination is
" real.
"
" Geometry, cheat-defense, and the cpoptions ';'-strip are inherited
" from the two delegated generators (move_repeat_last_find_backward
" and move_repeat_last_till_backward). See those files for the
" landings.

function! vimfluency#drills#move_repeat_last_find_vs_till_backward#meta() abort
  return {'id': 'move_repeat_last_find_vs_till_backward',
    \ 'name': 'repeat last find vs till, backward (; ,)',
    \ 'aim': 28, 'allowed_keys': ';,FT',
    \ 'prereqs': ['move_repeat_last_find_backward', 'move_repeat_last_till_backward'],
    \ 'parallel_to': ['move_repeat_last_find_vs_till_forward'], 'keys': ';/,', 'family': 'motion',
    \ 'test_sequence': [';', ',']}
endfunction

function! vimfluency#drills#move_repeat_last_find_vs_till_backward#lesson() abort
  " buf1: search char 's' at cols 4 and 10 (p=4, q=10). Frames 2-3 are
  " the key juxtaposition: identical cursor (col 12), the ONLY change is
  " F (land on, target 4) vs T (land after, target 5). Frames 4-5 cover
  " the , cases.
  let buf1 = ['kanslxqwzsmrbt']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 14],
    \  'prompt': [
    \    'Both setups go backward now — the question is F vs T:',
    \    '',
    \    '    target lands ON the char       → F (find)',
    \    '    target lands ONE CELL AFTER it  → T (till)',
    \    '',
    \    'Then ; repeats it backward, , reverses forward. Read where the',
    \    'target sits relative to the char to pick F or T.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 4],
    \  'waypoints': [[1, 10]],
    \  'prompt': 'Target is ON the first s. Press Fs (lands on the second s, 1), then ; (backward onto the first s, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 5],
    \  'waypoints': [[1, 11]],
    \  'prompt': 'Same cursor — but the target is one AFTER the first s. Press Ts (lands after the second s, 1), then ; (backward to one after the first, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 7], 'target': [1, 10],
    \  'waypoints': [[1, 4]],
    \  'prompt': 'Target is ON the second s, ahead. Press Fs (backward onto the first s, 1), then , (reverse forward onto the second, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 6], 'target': [1, 9],
    \  'waypoints': [[1, 5]],
    \  'prompt': 'Target is one BEFORE the second s. Press Ts (after the first s, 1), then , (reverse forward to one before the second, 2).'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_repeat_last_find_vs_till_backward#generate() abort
  " 50/50 mix of backward-find and backward-till items; each delegated
  " generator is itself a 50/50 ; / , mix, so the 4-way set is roughly
  " uniform. Both are independently cheat-defended and shape-verified.
  if s:rand(2) == 0
    return vimfluency#drills#move_repeat_last_find_backward#generate()
  else
    return vimfluency#drills#move_repeat_last_till_backward#generate()
  endif
endfunction
