" save_quit_ex_vs_normal_zz — Discriminate :wq vs ZZ. Same EFFECT (save
" and quit), different SYNTAX (Ex command vs normal-mode shortcut).
" The discrimination is whether to open the command line at all.
"
" Training shape: recall kind, binary discrimination. Scenario layout
" matches the rest of the save/quit family. Both items show a
" modified buffer ('save and quit' is what's happening); the GOAL
" line tells the learner which form to use:
"   "Save and quit using `:`"      → :wq
"   "Save and quit (no command line)" → ZZ
"
" Cheat-defense:
"   - The two answers share no common substring; the prompt's
"     "using `:`" vs "no command line" wording is the cue.
"   - Snippets rotate so the screen stays visually active.

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
    \ 'aim': 35, 'allowed_keys': ':wqZ', 'kind': 'recall',
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
  let status = vimfluency#scenarios#modified_status(1 + s:rand(5))
  let snippet = vimfluency#scenarios#snippet()
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'prompt': vimfluency#scenarios#compose(status, snippet, goal),
    \ 'expected_answer': cmd,
    \ 'expected_motion': cmd,
    \ 'optimal_motions': len(cmd),
    \ }
endfunction

function! vimfluency#pinpoints#save_quit_ex_vs_normal_zz#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  let status = vimfluency#scenarios#modified_status(3)
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
    \  'prompt': vimfluency#scenarios#compose(
    \    status, snippet, 'Save and quit using `:` (the Ex command).')},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'ZZ', 'expected_motion': 'ZZ', 'optimal_motions': 2,
    \  'prompt': vimfluency#scenarios#compose(
    \    status, snippet, 'Save and quit (no command line — use the normal-mode shortcut).')},
    \ ]
endfunction
