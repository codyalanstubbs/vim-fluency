" force_quit_ex_vs_normal_zq — Discriminate :q! vs ZQ. Same EFFECT
" (discard changes and quit), different SYNTAX. ZQ is to :q! what ZZ
" is to :wq.
"
" Training shape: kind 'command'. Both items sit on a modified buffer;
" the GOAL line specifies which form to use.

let s:GOALS = {
  \ ':q!': [
  \   'Discard changes and quit using `:` (the Ex command).',
  \   'Open the command line; force-quit there.',
  \   'Use the Ex command form to throw away changes and exit.',
  \   ],
  \ 'ZQ': [
  \   'Discard changes and quit (no command line — use the normal-mode shortcut).',
  \   'Force-quit using the two-keystroke normal-mode shortcut.',
  \   'Discard changes and exit without opening the command line.',
  \   ],
  \ }

let s:CMDS = [':q!', 'ZQ']

function! vimfluency#pinpoints#force_quit_ex_vs_normal_zq#meta() abort
  return {'id': 'force_quit_ex_vs_normal_zq', 'name': 'discriminate :q! vs ZQ',
    \ 'aim': 35, 'allowed_keys': ':q!ZQ', 'kind': 'command',
    \ 'prereqs': [], 'keys': ':q!/ZQ', 'family': 'survival',
    \ 'test_sequence': [':q!', 'ZQ']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#force_quit_ex_vs_normal_zq#generate() abort
  let cmd = s:CMDS[s:rand(len(s:CMDS))]
  let goals = s:GOALS[cmd]
  let goal = goals[s:rand(len(goals))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'snippet': vimfluency#scenarios#snippet(),
    \ 'status_text': vimfluency#scenarios#modified_status(1 + s:rand(5)),
    \ 'goal': goal,
    \ 'expected_answer': cmd,
    \ 'expected_motion': cmd,
    \ 'optimal_motions': len(cmd),
    \ }
endfunction

function! vimfluency#pinpoints#force_quit_ex_vs_normal_zq#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  let status  = vimfluency#scenarios#modified_status(3)
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':q! vs ZQ.',
    \    'Both discard pending changes and quit — same effect.',
    \    ':q! is the Ex-command form (! is the force flag).',
    \    'ZQ is the normal-mode shortcut (mirrors ZZ for save+quit).',
    \    '',
    \    'Both items show a modified buffer; the Goal tells you which form:',
    \    '  Goal: Discard changes and quit using `:`           →  :q!',
    \    '  Goal: Discard changes and quit (no command line)   →  ZQ',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q!', 'expected_motion': ':q!', 'optimal_motions': 3,
    \  'snippet': snippet, 'status_text': status,
    \  'goal': 'Discard changes and quit using `:` (the Ex command).'},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'ZQ', 'expected_motion': 'ZQ', 'optimal_motions': 2,
    \  'snippet': snippet, 'status_text': status,
    \  'goal': 'Discard changes and quit (no command line — use the normal-mode shortcut).'},
    \ ]
endfunction
