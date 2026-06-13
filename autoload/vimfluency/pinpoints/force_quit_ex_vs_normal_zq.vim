" force_quit_ex_vs_normal_zq — Discriminate :q! vs ZQ. Same effect
" (force quit), different syntax. The Goal text declares which form
" the learner should use — minimal pair:
"   :q!  →  'force quit Ex mode'
"   ZQ   →  'force quit Normal mode'

let s:GOALS = {
  \ ':q!': 'force quit Ex mode',
  \ 'ZQ':  'force quit Normal mode',
  \ }

let s:CMDS = [':q!', 'ZQ']

function! vimfluency#pinpoints#force_quit_ex_vs_normal_zq#meta() abort
  return {'id': 'force_quit_ex_vs_normal_zq', 'name': 'force quit, Ex vs normal (:q! / ZQ)',
    \ 'aim': 35, 'allowed_keys': ':q!ZQ', 'kind': 'command',
    \ 'prereqs': [], 'keys': ':q!/ZQ', 'family': 'survival',
    \ 'test_sequence': [':q!', 'ZQ']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#force_quit_ex_vs_normal_zq#generate() abort
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

function! vimfluency#pinpoints#force_quit_ex_vs_normal_zq#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':q! vs ZQ.',
    \    'Both discard pending changes and quit — same effect.',
    \    ':q! is the Ex-command form (! is the force flag).',
    \    'Ex commands run when you press <Enter>.',
    \    'ZQ is the normal-mode shortcut (mirrors ZZ for save+quit).',
    \    'It runs as soon as the Q lands — no <Enter> needed.',
    \    '',
    \    'Each item shows a snippet with the Goal as a code comment.',
    \    '  Goal: force quit Ex mode      →  :q!<Enter>',
    \    '  Goal: force quit Normal mode  →  ZQ',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q!', 'expected_motion': ':q!', 'optimal_motions': 3,
    \  'snippet': snippet, 'goal': s:GOALS[':q!']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'ZQ', 'expected_motion': 'ZQ', 'optimal_motions': 2,
    \  'snippet': snippet, 'goal': s:GOALS['ZQ']},
    \ ]
endfunction
