" save_vs_quit — Discriminate :w vs :q. Foundation pair: which command
" matches which intent.
"
" Training shape: recall kind, binary discrimination. Each item picks
" one of the two commands, builds a realistic buffer scenario via
" vimfluency#scenarios (status header + code/text snippet + goal
" line), the learner reads the goal and types the answer. Auto-credits
" on exact match.
"
" Cheat-defense:
"   - modified=YES is only ever paired with :w (you can't :q a dirty
"     buffer in real vim — it errors out); modified=NO is only ever
"     paired with :q. So the status header is a load-bearing
"     discrimination cue, not decoration. The "cheat" of always typing
"     :w when modified and :q when clean is the correct behavioral
"     rule in real vim, which is the point.
"   - Snippet content rotates per item from a shared pool — keeps the
"     screen visually active so the learner re-engages with each item
"     rather than pattern-matching the static prompt of the old version.
"   - The two answers are non-overlapping strings; no prefix collision.

let s:GOALS = {
  \ ':w': [
  \   'Save your work and keep editing.',
  \   'Write your changes to disk.',
  \   'Save progress without closing the file.',
  \   ],
  \ ':q': [
  \   "You're done reading. Close the file.",
  \   'Nothing to save — just exit this buffer.',
  \   'Quit (the buffer is clean).',
  \   ],
  \ }

let s:CMDS = [':w', ':q']

function! vimfluency#pinpoints#save_vs_quit#meta() abort
  " Binary discrimination is cognitively lighter than the original
  " 5-way pinpoint; aim sits a tick higher than the catalog's
  " original T0.3 baseline. Starting guess.
  return {'id': 'save_vs_quit', 'name': 'discriminate :w vs :q',
    \ 'aim': 40, 'allowed_keys': ':wq', 'kind': 'recall',
    \ 'prereqs': [], 'keys': ':w/:q', 'family': 'survival',
    \ 'test_sequence': [':w', ':q']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#save_vs_quit#generate() abort
  let cmd = s:CMDS[s:rand(len(s:CMDS))]
  let goals = s:GOALS[cmd]
  let goal = goals[s:rand(len(goals))]
  let status = cmd ==# ':w'
    \ ? vimfluency#scenarios#modified_status(1 + s:rand(5))
    \ : vimfluency#scenarios#clean_status()
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

function! vimfluency#pinpoints#save_vs_quit#lesson() abort
  " Lesson keeps the parallel-rule-statement shape but switches the
  " try frames to the new scenario rendering so the learner sees the
  " same kind of cue the training will give them. Both try frames
  " reuse the same snippet — focuses the learner's eye on the
  " status header + goal as the moving parts.
  let snippet = vimfluency#scenarios#snippet()
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':w vs :q.',
    \    ':w writes the file (saves it).',
    \    ':q quits the file.',
    \    '',
    \    'Each item shows a buffer state above a snippet, then a Goal.',
    \    '  modified + want to save  →  :w',
    \    '  clean   + want to close  →  :q',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':w', 'expected_motion': ':w', 'optimal_motions': 2,
    \  'prompt': vimfluency#scenarios#compose(
    \    vimfluency#scenarios#modified_status(3), snippet,
    \    'Save your work and keep editing.')},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q', 'expected_motion': ':q', 'optimal_motions': 2,
    \  'prompt': vimfluency#scenarios#compose(
    \    vimfluency#scenarios#clean_status(), snippet,
    \    "You're done reading. Close the file.")},
    \ ]
endfunction
