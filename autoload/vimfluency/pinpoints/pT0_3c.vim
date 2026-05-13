" T0.3c — Discriminate :wq vs ZZ. Same EFFECT (save and quit),
" different SYNTAX (Ex command vs normal-mode shortcut). The
" discrimination is whether to open the command line at all.
"
" Probe shape: recall kind, binary discrimination.
"
" Cheat-defense: the two answers share no common substring; the
" prompt's parenthetical ('Ex command' vs 'normal-mode') is the
" cue.

let s:items = [
  \ {'answer': ':wq', 'prompt': 'save and quit (Ex command)'},
  \ {'answer': 'ZZ',  'prompt': 'save and quit (normal-mode)'},
  \ ]

function! vimfluency#pinpoints#pT0_3c#meta() abort
  return {'id': 'T0.3c', 'name': 'discriminate :wq vs ZZ',
    \ 'aim': 35, 'allowed_keys': ':wqZ', 'kind': 'recall',
    \ 'prereqs': ['T0.3b']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#pT0_3c#generate() abort
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

function! vimfluency#pinpoints#pT0_3c#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'T0.3c — :wq vs ZZ.',
    \    'Both keystrokes save the file and quit — same effect.',
    \    ':wq is the Ex-command form (opens the command line).',
    \    'ZZ is the normal-mode shortcut (no command line, faster).',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':wq', 'expected_motion': ':wq', 'optimal_motions': 3,
    \  'prompt': [
    \    'Ex-command form for save and quit.',
    \    '',
    \    '    save and quit (Ex command)']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'ZZ', 'expected_motion': 'ZZ', 'optimal_motions': 2,
    \  'prompt': [
    \    'Normal-mode shortcut for save and quit.',
    \    'No colon, no command line — just two Z presses.',
    \    '',
    \    '    save and quit (normal-mode)']},
    \ ]
endfunction
