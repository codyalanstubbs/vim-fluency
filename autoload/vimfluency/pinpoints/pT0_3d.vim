" T0.3d — Discriminate :q! vs ZQ. Same as T0.3c (Ex vs normal-mode
" shortcut) but for force-quit. ZQ is to :q! what ZZ is to :wq.
"
" Training shape: recall kind, binary discrimination.
"
" Cheat-defense: the two answers share no common substring.

let s:items = [
  \ {'answer': ':q!', 'prompt': 'force quit (Ex command)'},
  \ {'answer': 'ZQ',  'prompt': 'force quit (normal-mode)'},
  \ ]

function! vimfluency#pinpoints#pT0_3d#meta() abort
  return {'id': 'T0.3d', 'name': 'discriminate :q! vs ZQ',
    \ 'aim': 35, 'allowed_keys': ':q!ZQ', 'kind': 'recall',
    \ 'prereqs': ['T0.3b']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#pT0_3d#generate() abort
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

function! vimfluency#pinpoints#pT0_3d#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'T0.3d — :q! vs ZQ.',
    \    'Both discard pending changes and quit — same effect.',
    \    ':q! is the Ex-command form (! is the force flag).',
    \    'ZQ is the normal-mode shortcut (mirrors ZZ for save+quit).',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q!', 'expected_motion': ':q!', 'optimal_motions': 3,
    \  'prompt': [
    \    'Ex-command form for force-quit.',
    \    '',
    \    '    force quit (Ex command)']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'ZQ', 'expected_motion': 'ZQ', 'optimal_motions': 2,
    \  'prompt': [
    \    'Normal-mode shortcut for force-quit.',
    \    '',
    \    '    force quit (normal-mode)']},
    \ ]
endfunction
