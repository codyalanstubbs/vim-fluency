" 1B.1 — w b e ge. Word-level cursor motion to start/end of a nearby word.
"
" Design constraints to keep word motions the strictly shortest path:
"   - single line of plain words separated by single spaces (no punctuation,
"     so vim's word definition is unambiguous)
"   - 6-letter alphabet means any single char appears ~6 times per line,
"     making f<c>;...;  routes longer than 2-4 word motions
"   - start cursor positioned mid-line so either forward or backward
"     direction is reachable at distance 2-4
"   - target is start (exercises w/b) or end (exercises e/ge) of word M,
"     direction and start/end randomized

let s:chars = ['a', 'e', 'i', 'o', 'r', 's']

function! vimfluency#pinpoints#p1B_1#meta() abort
  return {'id': '1B.1', 'name': 'w b e ge', 'aim': 45,
    \ 'allowed_keys': 'wbeg', 'prereqs': ['1A']}
endfunction

function! vimfluency#pinpoints#p1B_1#lesson() abort
  " Each motion is introduced via a try frame so the learner sees the
  " cursor jump from their own keystroke. Pair structure: w/b move
  " between word starts (forward / backward), e/ge between word ends.
  " One show frame remains for the meta-rule (no specific motion to
  " demo — the rule is about which motions move between which kind of
  " word boundary). Real words used so frames stay readable;
  " cheat-defense is irrelevant during teaching.
  let buf = ['alpha beta gamma delta epsilon']
  return [
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 7],
    \  'prompt': 'Press w — sends cursor to the start of the next word.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 7], 'target': [1, 1],
    \  'prompt': 'Press b — sends cursor to the start of the previous word.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 7], 'target': [1, 10],
    \  'prompt': 'Press e — sends cursor to the end of the next word.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 12], 'target': [1, 10],
    \  'prompt': 'Press ge — sends cursor to the end of the previous word.'},
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 12],
    \  'prompt': 'w and b move between word starts; e and ge move between word ends.'},
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

function! vimfluency#pinpoints#p1B_1#generate() abort
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

  " K (1-indexed word number) in middle range; dist 2-4 in either direction
  " is reachable when K ∈ [4, n_words-3]
  let K = 4 + s:rand(n_words - 6)
  let start_col = starts[K - 1]

  let dist = 2 + s:rand(3)
  let direction = s:rand(2) * 2 - 1
  if K + direction * dist < 1 || K + direction * dist > n_words
    let direction = -direction
  endif
  let M = K + direction * dist

  let pick_start = s:rand(2) == 0
  let target_col = pick_start ? starts[M - 1] : ends[M - 1]

  if pick_start
    let motion = direction > 0 ? 'w' : 'b'
  else
    let motion = direction > 0 ? 'e' : 'ge'
  endif

  " Optimal motion count from start of word K to {start,end} of word M:
  "   start of M:           dist (w * dist  or  b * dist)
  "   end of M, M >= K:     dist + 1 (e * (M-K+1))
  "   end of M, M <  K:     dist (ge * (K-M))
  let optimal_motions = pick_start
    \ ? dist
    \ : (direction > 0 ? dist + 1 : dist)

  return {'lines': [line], 'start': [1, start_col], 'target': [1, target_col],
    \ 'expected_motion': motion, 'optimal_motions': optimal_motions}
endfunction
