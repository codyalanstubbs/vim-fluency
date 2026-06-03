" move_to_till_forward — atomic 2-cell drill over the forward
" find/till pair (f, t). Both motions look ahead on the line for the
" next occurrence of a target character; they differ in WHERE they
" land:
"
"   f{c} → lands ON the target char
"   t{c} → lands ONE CELL BEFORE the target char
"
" Companion to move_to_till_backward (F / T). The pair-by-direction
" decomposition lives in parallel with the pair-by-find-vs-till
" split (move_to_char_forward_backward = f / F, and
" move_till_char_forward_backward = t / T). Both decompositions are
" prereqs of move_to_till_forward_backward.
"
" Cheat-defense is delegated to the underlying generators
" (move_to_char_forward_backward, move_till_char_forward_backward).
" We pull items from each, re-rolling until a forward-direction
" motion comes out — both generators flip direction 50/50 internally,
" so ~50% acceptance gives a clean fallback path within a few rolls.

function! vimfluency#pinpoints#move_to_till_forward#meta() abort
  " Aim 50/min, matching move_to_char_forward_backward. Single
  " 2-cell discrimination, single keystroke per item.
  return {'id': 'move_to_till_forward',
    \ 'name': 'find char forward (f / t)',
    \ 'aim': 50, 'allowed_keys': 'ft',
    \ 'prereqs': [], 'keys': 'f/t', 'family': 'motion',
    \ 'parallel_to': ['move_to_till_backward'],
    \ 'test_sequence': ['f', 't']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#move_to_till_forward#generate() abort
  " Re-roll until a forward-direction item lands. The underlying
  " generators each flip 50/50, so ~25% of mixed rolls match the
  " forward filter — 30 attempts is plenty.
  let attempts = 0
  while attempts < 30
    let attempts += 1
    if s:rand(2) == 0
      let item = vimfluency#pinpoints#move_to_char_forward_backward#generate()
    else
      let item = vimfluency#pinpoints#move_till_char_forward_backward#generate()
    endif
    if item.expected_motion ==# 'f' || item.expected_motion ==# 't'
      return item
    endif
  endwhile
  " Fallback (vanishingly rare): a hand-picked forward-f item.
  " 'banana split query' — `l` in 'split' is unique and interior.
  return {'lines': ['banana split query'],
    \ 'start': [1, 1], 'target': [1, 10],
    \ 'expected_motion': 'f', 'optimal_motions': 1}
endfunction

function! vimfluency#pinpoints#move_to_till_forward#lesson() abort
  let buf1 = ['the cat ran past us today']
  let buf2 = ['split banana']
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two forward-motion keys:',
    \    '',
    \    '    f{c}  →  lands ON the next c',
    \    '    t{c}  →  lands ONE CELL BEFORE the next c',
    \    '',
    \    'Read the target''s position relative to the next char to pick.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 1], 'target': [1, 13],
    \  'prompt': 'Target is ON the p — press fp.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 1], 'target': [1, 12],
    \  'prompt': 'Target is ONE BEFORE the p — press tp.'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 1], 'target': [1, 8],
    \  'prompt': 'banana has 3 a''s ahead. fa lands on the FIRST one (col 8).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 1], 'target': [1, 17],
    \  'prompt': 'Use tu to land just before "us" — col 17 (the space).'},
    \ ]
endfunction
