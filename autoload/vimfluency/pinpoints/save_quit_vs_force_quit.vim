" save_quit_vs_force_quit — Discriminate :wq vs :q!. The save-or-discard
" decision; both quit, one writes first, one forces (discarding pending
" changes). Introduces the ! force flag.
"
" Training shape: recall kind, binary discrimination. Scenario layout
" matches save_vs_quit (status header + snippet + goal), but here
" BOTH commands sit on a modified buffer — the discrimination cue is
" entirely in the goal line:
"   "Save and quit."           → :wq
"   "Discard changes and quit." → :q!
"
" Cheat-defense:
"   - Status alone can't discriminate (both items show modified=YES).
"     The goal verb ('Save' vs 'Discard') is the load-bearing cue.
"   - :wq and :q! are non-overlapping after the leading ':'. The :
"     prefix is shared but the body differs.
"   - Snippets rotate per item so the screen stays visually active.

let s:GOALS = {
  \ ':wq': [
  \   'Save and quit.',
  \   'Save your changes and close the file.',
  \   'Commit your work and exit.',
  \   ],
  \ ':q!': [
  \   'Discard these changes and quit.',
  \   'Throw away the edits and exit — you regret them.',
  \   'Force-quit without saving.',
  \   ],
  \ }

let s:CMDS = [':wq', ':q!']

function! vimfluency#pinpoints#save_quit_vs_force_quit#meta() abort
  return {'id': 'save_quit_vs_force_quit', 'name': 'discriminate :wq vs :q!',
    \ 'aim': 35, 'allowed_keys': ':wq!', 'kind': 'recall',
    \ 'prereqs': [], 'keys': ':wq/:q!', 'family': 'survival',
    \ 'test_sequence': [':wq', ':q!']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#save_quit_vs_force_quit#generate() abort
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

function! vimfluency#pinpoints#save_quit_vs_force_quit#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  let status = vimfluency#scenarios#modified_status(3)
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':wq vs :q!.',
    \    ':wq writes then quits (the safe "save and exit").',
    \    ':q! quits and discards — the ! is the FORCE flag,',
    \    'which tells vim "yes, I really mean it, drop my changes".',
    \    '',
    \    "Both items show a modified buffer; the Goal line tells you",
    \    "whether to keep or throw away the changes:",
    \    "  Goal: Save and quit              →  :wq",
    \    "  Goal: Discard changes and quit   →  :q!",
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':wq', 'expected_motion': ':wq', 'optimal_motions': 3,
    \  'prompt': vimfluency#scenarios#compose(
    \    status, snippet, 'Save and quit.')},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q!', 'expected_motion': ':q!', 'optimal_motions': 3,
    \  'prompt': vimfluency#scenarios#compose(
    \    status, snippet, 'Discard these changes and quit.')},
    \ ]
endfunction
