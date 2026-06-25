" save_quit_vs_zz — Discriminate :wq vs ZZ. Same effect
" (save and quit), different syntax. The Goal text declares which
" form the learner should use — minimal pair:
"   :wq  →  'save and quit Ex mode'
"   ZZ   →  'save and quit Normal mode'

let s:GOALS = {
  \ ':wq': 'save and quit Ex mode',
  \ 'ZZ':  'save and quit NORMAL mode',
  \ }

let s:CMDS = [':wq', 'ZZ']

function! vimfluency#drills#save_quit_vs_zz#meta() abort
  return {'id': 'save_quit_vs_zz', 'name': 'save & quit, Ex vs normal (:wq / ZZ)',
    \ 'aim': 35, 'allowed_keys': ':wqZ', 'kind': 'command',
    \ 'prereqs': [], 'keys': ':wq/ZZ', 'family': 'survival',
    \ 'test_sequence': [':wq', 'ZZ']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#save_quit_vs_zz#generate() abort
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

function! vimfluency#drills#save_quit_vs_zz#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':wq vs ZZ:',
    \    '',
    \    '    :wq   →   save and quit — Ex command, runs when you press <CR>',
    \    '    ZZ    →   save and quit — NORMAL-mode shortcut, runs at once',
    \    '',
    \    'Same effect, two forms.',
    \    '',
    \    'Each item shows a snippet with the Goal as a code comment.',
    \    '  Goal: save and quit Ex mode      →  :wq<CR>',
    \    '  Goal: save and quit NORMAL mode  →  ZZ',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':wq', 'expected_motion': ':wq', 'optimal_motions': 3,
    \  'snippet': snippet, 'goal': s:GOALS[':wq']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'ZZ', 'expected_motion': 'ZZ', 'optimal_motions': 2,
    \  'snippet': snippet, 'goal': s:GOALS['ZZ']},
    \ ]
endfunction
