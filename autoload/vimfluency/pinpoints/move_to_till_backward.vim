" move_to_till_backward — atomic 2-cell drill over the backward
" find/till pair (F, T). Both motions look BEHIND on the line for
" the previous occurrence of a target character; they differ in
" WHERE they land:
"
"   F{c} → lands ON the target char
"   T{c} → lands ONE CELL AFTER the target char
"
" Companion to move_to_till_forward (f / t). See that file for the
" larger pair-by-direction vs pair-by-find-vs-till context.
"
" Cheat-defense is delegated to the underlying generators
" (move_to_char_forward_backward, move_till_char_forward_backward).
" Re-roll until a backward motion lands.

function! vimfluency#pinpoints#move_to_till_backward#meta() abort
  return {'id': 'move_to_till_backward',
    \ 'name': 'find char backward (F / T)',
    \ 'aim': 50, 'allowed_keys': 'FT',
    \ 'prereqs': [], 'keys': 'F/T', 'family': 'motion',
    \ 'parallel_to': ['move_to_till_forward'],
    \ 'test_sequence': ['F', 'T']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#move_to_till_backward#generate() abort
  let attempts = 0
  while attempts < 30
    let attempts += 1
    if s:rand(2) == 0
      let item = vimfluency#pinpoints#move_to_char_forward_backward#generate()
    else
      let item = vimfluency#pinpoints#move_till_char_forward_backward#generate()
    endif
    if item.expected_motion ==# 'F' || item.expected_motion ==# 'T'
      return item
    endif
  endwhile
  " Fallback: hand-picked backward-F item. 'banana split query' — `l`
  " in 'split' is unique and interior; starting from end of line lets
  " Fl reach it backward.
  return {'lines': ['banana split query'],
    \ 'start': [1, 18], 'target': [1, 10],
    \ 'expected_motion': 'F', 'optimal_motions': 1}
endfunction

function! vimfluency#pinpoints#move_to_till_backward#lesson() abort
  let buf1 = ['the cat ran past us today']
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two backward-motion keys:',
    \    '',
    \    '    F{c}  →  lands ON the previous c',
    \    '    T{c}  →  lands ONE CELL AFTER the previous c',
    \    '',
    \    'Read the target''s position relative to the previous char to pick.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 25], 'target': [1, 13],
    \  'prompt': 'Target is ON the p — press Fp.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 25], 'target': [1, 14],
    \  'prompt': 'Target is ONE AFTER the p — press Tp.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 25], 'target': [1, 9],
    \  'prompt': 'Use Fr to reach the r in "ran".'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 25], 'target': [1, 10],
    \  'prompt': 'Use Tr to land just after the r — col 10 (the a).'},
    \ ]
endfunction
