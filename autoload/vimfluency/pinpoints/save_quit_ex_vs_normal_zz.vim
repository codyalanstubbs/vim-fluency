" save_quit_ex_vs_normal_zz — Discriminate :wq vs ZZ. Same effect
" (save and quit), different syntax. The Goal text declares which
" form the learner should use — minimal pair:
"   :wq  →  'save and quit Ex mode'
"   ZZ   →  'save and quit Normal mode'

let s:GOALS = {
  \ ':wq': 'save and quit Ex mode',
  \ 'ZZ':  'save and quit Normal mode',
  \ }

let s:CMDS = [':wq', 'ZZ']

function! vimfluency#pinpoints#save_quit_ex_vs_normal_zz#meta() abort
  return {'id': 'save_quit_ex_vs_normal_zz', 'name': 'discriminate :wq vs ZZ',
    \ 'aim': 35, 'allowed_keys': ':wqZ', 'kind': 'command',
    \ 'prereqs': [], 'keys': ':wq/ZZ', 'family': 'survival',
    \ 'test_sequence': [':wq', 'ZZ']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#save_quit_ex_vs_normal_zz#generate() abort
  let cmd = s:CMDS[s:rand(len(s:CMDS))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'snippet': vimfluency#scenarios#snippet(),
    \ 'goal': s:GOALS[cmd],
    \ 'expected_answer': cmd,
    \ 'expected_motion': cmd,
    \ 'optimal_motions': len(cmd),
    \ }
endfunction

function! vimfluency#pinpoints#save_quit_ex_vs_normal_zz#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':wq vs ZZ.',
    \    'Both keystrokes save the file and quit — same effect.',
    \    ':wq is the Ex-command form. Ex commands run when you press <Enter>.',
    \    'ZZ is the normal-mode shortcut. It runs as soon as the second Z lands.',
    \    '',
    \    'Each item shows a snippet with the Goal as a code comment.',
    \    '  Goal: save and quit Ex mode      →  :wq<Enter>',
    \    '  Goal: save and quit Normal mode  →  ZZ',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':wq', 'expected_motion': ':wq', 'optimal_motions': 3,
    \  'snippet': snippet, 'goal': s:GOALS[':wq']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'ZZ', 'expected_motion': 'ZZ', 'optimal_motions': 2,
    \  'snippet': snippet, 'goal': s:GOALS['ZZ']},
    \ ]
endfunction
