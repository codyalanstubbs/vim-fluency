" move_to_word_start_forward_backward — w b. Forward/backward to the start of a nearby word.
"
" Juxtaposition pair: same landing position (word start), opposite
" direction. The discrimination axis is purely direction. The end-of-
" word motions (e, ge) live in 1B.2 — they form their own pair with
" the same direction discrimination at a different landing position.
"
" Design constraints to keep w/b the strictly shortest path:
"   - single line of plain words separated by single spaces (no
"     punctuation, so vim's word definition is unambiguous)
"   - 6-letter alphabet means any single char appears ~6 times per
"     line, making f<c>;...; routes longer than 2-4 word motions
"   - start cursor positioned mid-line so either forward or backward
"     direction is reachable at distance 2-4
"   - target is the start of word M; w*dist or b*dist is the canonical
"     path (1 motion per word), and dist motion events is also the
"     minimum reachable (no shorter route exists with the alphabet's
"     density making f-routes longer)

let s:chars = ['a', 'e', 'i', 'o', 'r', 's']

function! vimfluency#pinpoints#move_to_word_start_forward_backward#meta() abort
  return {'id': 'move_to_word_start_forward_backward', 'name': 'w b', 'aim': 45,
    \ 'allowed_keys': 'wb', 'prereqs': ['move_single_char_up_down_left_right'],
    \ 'parallel_to': ['move_to_word_end_forward_backward'], 'family': 'motion'}
endfunction

function! vimfluency#pinpoints#move_to_word_start_forward_backward#lesson() abort
  " Each motion gets a try frame so the learner sees the cursor jump
  " from their own keystroke. Rule statement at the end names the
  " parallel structure. Real words used so frames stay readable;
  " cheat-defense is irrelevant during teaching.
  let buf = ['alpha beta gamma delta epsilon']
  return [
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 7],
    \  'prompt': 'Press w — sends cursor to the start of the next word.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 7], 'target': [1, 1],
    \  'prompt': 'Press b — sends cursor to the start of the previous word.'},
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 7],
    \  'prompt': 'w and b move between word starts; w is forward, b is backward.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 12],
    \  'prompt': 'Use w twice to skip a word.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 18], 'target': [1, 7],
    \  'prompt': 'Use b twice.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_word() abort
  let n = 3 + s:rand(2)  " 3 or 4 letters
  let s = ''
  for _ in range(n)
    let s .= s:chars[s:rand(len(s:chars))]
  endfor
  return s
endfunction

function! vimfluency#pinpoints#move_to_word_start_forward_backward#generate() abort
  let n_words = 10
  let words = []
  for _ in range(n_words)
    call add(words, s:make_word())
  endfor
  let line = join(words, ' ')

  " 1-indexed col of each word's first char
  let starts = []
  let col = 1
  for w in words
    call add(starts, col)
    let col += len(w) + 1
  endfor

  " K (1-indexed word number) in middle range; dist 2-4 in either
  " direction is reachable when K ∈ [4, n_words-3].
  let K = 4 + s:rand(n_words - 6)
  let start_col = starts[K - 1]

  let dist = 2 + s:rand(3)
  let direction = s:rand(2) * 2 - 1
  if K + direction * dist < 1 || K + direction * dist > n_words
    let direction = -direction
  endif
  let M = K + direction * dist
  let target_col = starts[M - 1]
  let motion = direction > 0 ? 'w' : 'b'

  return {'lines': [line], 'start': [1, start_col], 'target': [1, target_col],
    \ 'expected_motion': motion, 'optimal_motions': dist}
endfunction
