" save_vs_quit — Discriminate :w vs :q.
"
" Training shape: kind 'command'. The learner reads a snippet whose
" first line is a language-appropriate code comment stating the
" Goal, then types the matching vim command. The Goal text is the
" single discriminative cue — minimal pair:
"   :w  →  'save'
"   :q  →  'quit'
"
" Cheat-defense: only one axis varies (the goal word). Snippets
" rotate per item for visual variety but the snippet content
" doesn't influence which command is correct.

let s:GOALS = {
  \ ':w': 'save',
  \ ':q': 'quit',
  \ }

let s:CMDS = [':w', ':q']

function! vimfluency#pinpoints#save_vs_quit#meta() abort
  return {'id': 'save_vs_quit', 'name': 'save vs quit (:w / :q)',
    \ 'aim': 40, 'allowed_keys': ':wq', 'kind': 'command',
    \ 'prereqs': [], 'keys': ':w/:q', 'family': 'survival',
    \ 'test_sequence': [':w', ':q']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#save_vs_quit#generate() abort
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

function! vimfluency#pinpoints#save_vs_quit#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':w vs :q.',
    \    ':w writes the file (saves it).',
    \    ':q quits the file.',
    \    '',
    \    "Both are Ex commands — type them, then press <Enter> to run.",
    \    '',
    \    'Each item shows a snippet with the Goal as a code comment.',
    \    '  Goal: save  →  :w<Enter>',
    \    '  Goal: quit  →  :q<Enter>',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':w', 'expected_motion': ':w', 'optimal_motions': 2,
    \  'snippet': snippet, 'goal': s:GOALS[':w']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q', 'expected_motion': ':q', 'optimal_motions': 2,
    \  'snippet': snippet, 'goal': s:GOALS[':q']},
    \ ]
endfunction
