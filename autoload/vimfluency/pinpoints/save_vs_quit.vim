" save_vs_quit — Discriminate :w vs :q. Foundation pair: which command
" matches which intent.
"
" Training shape: kind 'command' — the learner sees a realistic
" snippet with a status header ('modified · 3 unsaved changes' or
" 'clean · no unsaved changes') and a goal line, then types the
" matching vim command. The Ex-command capture (input()-based fake
" cmdline) makes it FEEL like real cmdline without quitting vim.
" Free-operant: a wrong command echoes a hint; the learner keeps
" going. No '> ' answer line.
"
" Cheat-defense:
"   - modified=YES is only ever paired with :w (you can't :q a dirty
"     buffer in real vim — it errors out); modified=NO is only ever
"     paired with :q. The 'cheat' of mapping status → command is the
"     correct behavioral rule, which is the point.
"   - Snippets rotate per item from a shared pool — keeps the screen
"     visually active so the learner re-engages with each item.

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
  return {'id': 'save_vs_quit', 'name': 'discriminate :w vs :q',
    \ 'aim': 40, 'allowed_keys': ':wq', 'kind': 'command',
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
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'snippet': vimfluency#scenarios#snippet(),
    \ 'status_text': status,
    \ 'goal': goal,
    \ 'expected_answer': cmd,
    \ 'expected_motion': cmd,
    \ 'optimal_motions': len(cmd),
    \ }
endfunction

function! vimfluency#pinpoints#save_vs_quit#lesson() abort
  " Show frames keep the parallel rule statements; try frames carry
  " snippet/status_text/goal so the lesson try phase renders the same
  " live-buffer scenario the training will give.
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
    \  'snippet': snippet,
    \  'status_text': vimfluency#scenarios#modified_status(3),
    \  'goal': 'Save your work and keep editing.'},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q', 'expected_motion': ':q', 'optimal_motions': 2,
    \  'snippet': snippet,
    \  'status_text': vimfluency#scenarios#clean_status(),
    \  'goal': "You're done reading. Close the file."},
    \ ]
endfunction
