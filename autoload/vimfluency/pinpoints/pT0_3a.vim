" T0.3a — Discriminate :w vs :q. Foundation pair: which letter for
" which action. The action verb ('save' or 'quit') is the entire cue;
" the answer is the matching Ex command.
"
" Training shape: recall kind, binary discrimination. Each item picks
" one of the two; the learner reads a single-word prompt and types
" the answer. Auto-credits on exact match.
"
" Cheat-defense: there are only two answers, so there's no
" cross-item ambiguity. Prefix collisions don't matter — :w is not
" a prefix of :q.

let s:items = [
  \ {'answer': ':w', 'prompt': 'save'},
  \ {'answer': ':q', 'prompt': 'quit'},
  \ ]

function! vimfluency#pinpoints#pT0_3a#meta() abort
  " Binary discrimination is cognitively lighter than the original
  " 5-way pinpoint; aim sits a tick higher than the catalog's
  " original T0.3 baseline. Starting guess.
  return {'id': 'T0.3a', 'name': 'discriminate :w vs :q',
    \ 'aim': 40, 'allowed_keys': ':wq', 'kind': 'recall',
    \ 'prereqs': []}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#pT0_3a#generate() abort
  let pick = s:items[s:rand(len(s:items))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'prompt': ['Type the keystrokes to:', '', '    ' . pick.prompt],
    \ 'expected_answer': pick.answer,
    \ 'expected_motion': pick.answer,
    \ 'optimal_motions': len(pick.answer),
    \ }
endfunction

function! vimfluency#pinpoints#pT0_3a#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'T0.3a — :w vs :q.',
    \    ':w writes the file (saves it).',
    \    ':q quits the file.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':w', 'expected_motion': ':w', 'optimal_motions': 2,
    \  'prompt': [
    \    ':w writes the file to disk — saves, but stays open.',
    \    '',
    \    '    save']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':q', 'expected_motion': ':q', 'optimal_motions': 2,
    \  'prompt': [
    \    ':q quits the file.',
    \    '',
    \    '    quit']},
    \ ]
endfunction
