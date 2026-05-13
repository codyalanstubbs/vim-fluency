" T0.3b — Discriminate :wq vs :q!. The save-or-discard decision.
" Both quit; one writes first, one forces (discarding pending changes).
" Introduces the ! force flag.
"
" Probe shape: recall kind, binary discrimination.
"
" Cheat-defense: :wq and :q! are non-overlapping strings. The :
" prefix is shared but the body differs.

let s:items = [
  \ {'answer': ':wq', 'prompt': 'save and quit'},
  \ {'answer': ':q!', 'prompt': 'force quit (discard changes)'},
  \ ]

function! vimfluency#pinpoints#pT0_3b#meta() abort
  return {'id': 'T0.3b', 'name': 'discriminate :wq vs :q!',
    \ 'aim': 35, 'allowed_keys': ':wq!', 'kind': 'recall',
    \ 'prereqs': ['T0.3a']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#pT0_3b#generate() abort
  let pick = s:items[s:rand(len(s:items))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'prompt': ['Type the keystrokes to:', '', '    ' . pick.prompt],
    \ 'expected_answer': pick.answer,
    \ 'expected_motion': pick.answer,
    \ 'optimal_motions': len(pick.answer),
    \ }
endfunction

function! vimfluency#pinpoints#pT0_3b#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'T0.3b — :wq vs :q!.',
    \    ':wq writes then quits (the safe "save and exit").',
    \    ':q! quits and discards — the ! is the FORCE flag,',
    \    'which tells vim "yes, I really mean it, drop my changes".',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':wq', 'expected_motion': ':wq', 'optimal_motions': 3,
    \  'prompt': [
    \    ':wq saves the file then quits.',
    \    '',
    \    '    save and quit']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q!', 'expected_motion': ':q!', 'optimal_motions': 3,
    \  'prompt': [
    \    ':q! force-quits, discarding any unsaved changes.',
    \    '',
    \    '    force quit (discard changes)']},
    \ ]
endfunction
