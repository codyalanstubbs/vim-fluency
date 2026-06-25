" undo_redo — Undo and redo. Two keys, one cognitive pair: u reverses the
" last edit; Ctrl-r reverses the last undo.
"
" Training shape: editing kind with pre-staged undo history. Each item
" declares a `history` (list of buffer states) and a `start_index`
" telling the runner which state to display. The runner stages the
" full history into the buffer's undo log behind the scenes, then
" applies enough undos to reach `start_index`. From there the user's
" `u` or Ctrl-r traverses the staged history in one keystroke.
"
" Why a 'history' field instead of just lines + target_lines:
"   - A fresh training buffer has no undo history, so `u` is a no-op
"     (vim beeps). Without pre-staging, the canonical answer key
"     does nothing.
"   - Pre-staging is the only way to make `u` and Ctrl-r each
"     reach a well-defined target state.
"
" Cheat-defense:
"   - The matcher checks target_lines + cursor, so any path that
"     ends at the target credits. With u, the canonical path is 1
"     keystroke; any cheat takes more, so the rate penalizes.
"   - Pressing the WRONG key for an item leaves the buffer at the
"     wrong state. For an undo-item, pressing Ctrl-r at the
"     displayed state is a no-op (no redo history above the staged
"     final state). For a redo-item, pressing u at the displayed
"     state goes further back, away from the target. Either way,
"     wrong-key paths don't credit.
"
" Per-motion bucket: 'u' and '<C-r>' — each tracked independently
" so the summary breaks them out.

" Pairs of (before, after) states. Each modification is small and
" visually obvious so the learner can see what would be undone /
" redone. All states are single-line for v1 simplicity (the staging
" mechanic assumes equal line count across states).
let s:pairs = [
  \ ['hello world',     'hello WORLD'],
  \ ['foo bar baz',     'foo BAR baz'],
  \ ['open file',       'open files'],
  \ ['save the buffer', 'SAVE the buffer'],
  \ ['edit text',       'edit TEXT'],
  \ ['print value',     'print VALUE'],
  \ ]

function! vimfluency#drills#undo_redo#meta() abort
  " Catalog aim 50/min. The motor task is a single keypress, so the
  " bottleneck is recognizing whether the situation calls for undo
  " or redo. Starting guess.
  return {'id': 'undo_redo', 'name': 'undo / redo (u / Ctrl-r)',
    \ 'aim': 50, 'allowed_keys': 'u<C-r>', 'kind': 'editing',
    \ 'prereqs': [], 'keys': 'u/C-r', 'family': 'survival',
    \ 'test_sequence': ['u', '<C-r>']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#undo_redo#generate() abort
  let pair = s:pairs[s:rand(len(s:pairs))]
  let key = ['u', '<C-r>'][s:rand(2)]
  if key ==# 'u'
    " Display pair[1] (the edited state); u reverts to pair[0].
    return {
      \ 'lines': [pair[1]],
      \ 'start': [1, 1],
      \ 'target': [1, 1],
      \ 'target_lines': [pair[0]],
      \ 'expected_motion': 'u',
      \ 'optimal_motions': 1,
      \ 'prompt': 'Undo the last edit.',
      \ 'history': [[pair[0]], [pair[1]]],
      \ 'start_index': 1,
      \ }
  else
    " Display pair[0] (after one undo); Ctrl-r restores pair[1].
    return {
      \ 'lines': [pair[0]],
      \ 'start': [1, 1],
      \ 'target': [1, 1],
      \ 'target_lines': [pair[1]],
      \ 'expected_motion': '<C-r>',
      \ 'optimal_motions': 1,
      \ 'prompt': 'Redo — restore the change you just undid.',
      \ 'history': [[pair[0]], [pair[1]]],
      \ 'start_index': 0,
      \ }
  endif
endfunction

" DI sequence: short intro, then try u, try Ctrl-r, plus a
" reinforcement pair so the learner sees each key twice in the
" setup phase.
function! vimfluency#drills#undo_redo#lesson() abort
  let pair_a = ['hello world',     'hello WORLD']
  let pair_b = ['foo bar baz',     'foo BAR baz']
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Undo and redo:',
    \    '  u      reverses the last edit (the most recent change to the buffer).',
    \    '  <C-r>  reverses the last undo (puts back what u just removed).',
    \    '',
    \    'In each try frame, the buffer is staged to LOOK like a recent edit',
    \    'just happened. Press the matching key.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [pair_a[1]],
    \  'start': [1, 1], 'target': [1, 1],
    \  'target_lines': [pair_a[0]],
    \  'expected_motion': 'u', 'optimal_motions': 1,
    \  'history': [[pair_a[0]], [pair_a[1]]],
    \  'start_index': 1,
    \  'prompt': [
    \    'The buffer shows the result of a recent edit.',
    \    'Press u to undo it.']},
    \ {'kind': 'try', 'lines': [pair_a[0]],
    \  'start': [1, 1], 'target': [1, 1],
    \  'target_lines': [pair_a[1]],
    \  'expected_motion': '<C-r>', 'optimal_motions': 1,
    \  'history': [[pair_a[0]], [pair_a[1]]],
    \  'start_index': 0,
    \  'prompt': [
    \    'You just undid an edit. The change is gone from the buffer,',
    \    'but vim still remembers it. Press <C-r> to bring it back.']},
    \ {'kind': 'try', 'lines': [pair_b[1]],
    \  'start': [1, 1], 'target': [1, 1],
    \  'target_lines': [pair_b[0]],
    \  'expected_motion': 'u', 'optimal_motions': 1,
    \  'history': [[pair_b[0]], [pair_b[1]]],
    \  'start_index': 1,
    \  'prompt': [
    \    'Another undo — same key.',
    \    'Press u.']},
    \ {'kind': 'try', 'lines': [pair_b[0]],
    \  'start': [1, 1], 'target': [1, 1],
    \  'target_lines': [pair_b[1]],
    \  'expected_motion': '<C-r>', 'optimal_motions': 1,
    \  'history': [[pair_b[0]], [pair_b[1]]],
    \  'start_index': 0,
    \  'prompt': [
    \    'Another redo — same key.',
    \    'Press <C-r>.']},
    \ ]
endfunction
