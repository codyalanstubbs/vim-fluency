" move_to_word_end_forward_backward — e ge. Forward/backward to the end of a nearby word.
"
" Juxtaposition pair with 1B.1 (w/b): same landing concept (word
" boundary), but landing at the END instead of the start. Within
" this pinpoint the discrimination is direction (forward / backward),
" mirroring 1B.1's structure. The 1-keystroke vs 2-keystroke
" distinction (e is one keypress; ge is g + e) is what differs from
" 1B.1 — that's the structural reason these motions earn their own
" pinpoint instead of bundling with w/b.
"
" Design constraints to keep e/ge the canonical (motion-event-minimum)
" path:
"   - same alphabet and word geometry as 1B.1 (6-letter vowel-heavy,
"     10 words per line, 3-4 letters each)
"   - target is the END of word M; e × (dist+1) lands forward at
"     end-of-M from start-of-K, ge × dist lands backward
"   - The runner counts motion events, not keystrokes — so ge counts
"     as 1 motion despite being 2 keystrokes. That keeps ge as the
"     canonical answer for the backward case (b×dist + e is dist+1
"     events, more than ge×dist = dist events)

let s:chars = ['a', 'e', 'i', 'o', 'r', 's']

function! vimfluency#pinpoints#move_to_word_end_forward_backward#meta() abort
  " Aim slightly below 1B.1 because ge is two keystrokes, halving the
  " theoretical max rate on the backward half of the discrimination.
  " Starting guess; revise once the data accumulates.
  return {'id': 'move_to_word_end_forward_backward', 'name': 'e ge', 'aim': 40,
    \ 'allowed_keys': 'eg', 'prereqs': [],
    \ 'parallel_to': ['move_to_word_start_forward_backward'], 'keys': 'e/ge', 'family': 'motion'}
endfunction

function! vimfluency#pinpoints#move_to_word_end_forward_backward#lesson() abort
  " Same parallel-rule shape as 1B.1: try frames for each motion,
  " then a rule statement. Real words for readability; cheat-defense
  " irrelevant during teaching.
  let buf = ['alpha beta gamma delta epsilon']
  return [
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 5],
    \  'prompt': 'Press e — sends cursor to the end of the next word (or end of current word if you''re inside it).'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 7], 'target': [1, 5],
    \  'prompt': 'Press ge — two keys: g then e. Sends cursor backward to the end of the previous word.'},
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 5],
    \  'prompt': 'e and ge both land at word endings; e is forward (one key), ge is backward (two keys).'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 10],
    \  'prompt': 'Use e twice to land at the end of beta.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 16], 'target': [1, 10],
    \  'prompt': 'Use ge to step back to the end of beta.'},
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

function! vimfluency#pinpoints#move_to_word_end_forward_backward#generate() abort
  let n_words = 10
  let words = []
  for _ in range(n_words)
    call add(words, s:make_word())
  endfor
  let line = join(words, ' ')

  " 1-indexed col of each word's first and last char
  let starts = []
  let ends = []
  let col = 1
  for w in words
    call add(starts, col)
    call add(ends, col + len(w) - 1)
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
  let target_col = ends[M - 1]
  let motion = direction > 0 ? 'e' : 'ge'

  " Optimal motion-event count from start of word K to end of word M:
  "   forward (M > K):   e × (dist + 1)  — first e lands at end of K
  "                      itself, so reaching end of M = K+dist needs
  "                      dist+1 presses
  "   backward (M < K):  ge × dist       — each ge moves one word back
  let optimal_motions = direction > 0 ? dist + 1 : dist

  return {'lines': [line], 'start': [1, start_col], 'target': [1, target_col],
    \ 'expected_motion': motion, 'optimal_motions': optimal_motions}
endfunction
