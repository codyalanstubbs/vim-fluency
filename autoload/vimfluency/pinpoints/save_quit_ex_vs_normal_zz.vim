" save_quit_ex_vs_normal_zz — Discriminate :wq vs ZZ. Same EFFECT (save
" and quit), different SYNTAX (Ex command vs normal-mode shortcut).
" The discrimination is whether to open the command line at all.
"
" Training shape: kind 'command'. Both items sit on a modified buffer;
" the GOAL line specifies which form to use.

let s:GOALS = {
  \ ':wq': [
  \   'Save and quit using `:` (the Ex command).',
  \   'Open the command line; save and quit there.',
  \   'Use the Ex command form to save and exit.',
  \   ],
  \ 'ZZ': [
  \   'Save and quit (no command line — use the normal-mode shortcut).',
  \   'Use the two-keystroke normal-mode shortcut to save and exit.',
  \   'Save and quit without opening the command line.',
  \   ],
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

function! vimfluency#pinpoints#save_quit_ex_vs_normal_zz#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  let status  = vimfluency#scenarios#modified_status(3)
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':wq vs ZZ.',
    \    'Both keystrokes save the file and quit — same effect.',
    \    ':wq is the Ex-command form (opens the command line).',
    \    'ZZ is the normal-mode shortcut (no command line, faster).',
    \    '',
    \    'Both items show a modified buffer; the Goal tells you which form:',
    \    '  Goal: Save and quit using `:`           →  :wq',
    \    '  Goal: Save and quit (no command line)   →  ZZ',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':wq', 'expected_motion': ':wq', 'optimal_motions': 3,
    \  'snippet': snippet, 'status_text': status,
    \  'goal': 'Save and quit using `:` (the Ex command).'},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'ZZ', 'expected_motion': 'ZZ', 'optimal_motions': 2,
    \  'snippet': snippet, 'status_text': status,
    \  'goal': 'Save and quit (no command line — use the normal-mode shortcut).'},
    \ ]
endfunction
