" save_quit_vs_force_quit — Discriminate :wq vs :q!. The save-or-discard
" decision; both quit, one writes first, one forces (discards
" changes). Introduces the ! force flag.
"
" Goal text is the single discriminative cue — minimal pair:
"   :wq  →  'save and quit'
"   :q!  →  'force quit'

let s:GOALS = {
  \ ':wq': 'save and quit',
  \ ':q!': 'force quit',
  \ }

let s:CMDS = [':wq', ':q!']

function! vimfluency#drills#save_quit_vs_force_quit#meta() abort
  return {'id': 'save_quit_vs_force_quit', 'name': 'save & quit vs force quit (:wq / :q!)',
    \ 'aim': 35, 'allowed_keys': ':wq!', 'kind': 'command',
    \ 'prereqs': [], 'keys': ':wq/:q!', 'family': 'survival',
    \ 'test_sequence': [':wq', ':q!']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#save_quit_vs_force_quit#generate() abort
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

function! vimfluency#drills#save_quit_vs_force_quit#lesson() abort
  let snippet = vimfluency#scenarios#snippet()
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    ':wq vs :q!:',
    \    '',
    \    '    :wq   →   writes the file, then quits (the safe save-and-quit)',
    \    '    :q!   →   quits and discards unsaved changes (! = force flag)',
    \    '',
    \    'Both are Ex commands — type them, then press <CR> to run.',
    \    '',
    \    'Each item shows a snippet with the Goal as a code comment.',
    \    '  Goal: save and quit  →  :wq<CR>',
    \    '  Goal: force quit     →  :q!<CR>',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':wq', 'expected_motion': ':wq', 'optimal_motions': 3,
    \  'snippet': snippet, 'goal': s:GOALS[':wq']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q!', 'expected_motion': ':q!', 'optimal_motions': 3,
    \  'snippet': snippet, 'goal': s:GOALS[':q!']},
    \ ]
endfunction
