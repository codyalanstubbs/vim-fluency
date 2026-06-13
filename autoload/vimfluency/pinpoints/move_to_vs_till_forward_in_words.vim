" move_to_vs_till_forward_in_words — the realistic-content follow-on to
" move_to_vs_till_forward. Same f/t discrimination (pick the motion
" whose search char does NOT repeat between cursor and target), but
" embedded in real-word lines with variable geometry.
"
" Prereq: move_to_vs_till_forward (the constant-geometry version) — get
" the discrimination fluent there first, then add the skim load here.
"
" Shape constraints, enforced per generated item:
"   t-item: X (char AT target) occurs again strictly between cursor
"           and target → f{X} stops early. Z (char RIGHT of target)
"           does not occur in (cursor, target] → t{Z} lands exactly.
"   f-item: X unique in (cursor, target) → f{X} lands exactly.
"           Z occurs again in (cursor, target] → t{Z} stops early.
"
" Cheat-defense mirrors move_to_vs_till_backward_in_words.

let s:WORDS = ['return', 'import', 'while', 'range', 'class', 'value',
  \ 'array', 'result', 'parse', 'error', 'begin', 'label', 'count',
  \ 'frame', 'start', 'fetch', 'scope', 'plain', 'brain', 'focus',
  \ 'total', 'query', 'write', 'magic', 'cursor', 'target', 'finish',
  \ 'point', 'truck', 'noise', 'alpha', 'gamma', 'delta', 'south',
  \ 'north', 'visit', 'spend', 'phone', 'movie', 'happy', 'lucky',
  \ 'jumbo', 'flash', 'crisp', 'blank', 'globe']

function! vimfluency#pinpoints#move_to_vs_till_forward_in_words#meta() abort
  " Aim matches the backward in-words sibling. Starting guess.
  return {'id': 'move_to_vs_till_forward_in_words',
    \ 'name': 'find vs till in words, forward (f / t)',
    \ 'aim': 40, 'allowed_keys': 'ft',
    \ 'prereqs': ['move_to_vs_till_forward'],
    \ 'keys': 'f/t', 'family': 'motion',
    \ 'parallel_to': ['move_to_vs_till_backward_in_words'],
    \ 'test_sequence': ['f', 't']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" First column > a:after where a:ch occurs in a:line (1-indexed),
" or 0 when absent. Mirrors what f{ch}/t{ch} from a:after would find.
function! s:first_occurrence_after(line, ch, after) abort
  let llen = len(a:line)
  let c = a:after + 1
  while c <= llen
    if a:line[c - 1] ==# a:ch | return c | endif
    let c += 1
  endwhile
  return 0
endfunction

function! s:try_generate() abort
  let n_words = 4 + s:rand(3)
  let words = []
  for _ in range(n_words)
    call add(words, s:WORDS[s:rand(len(s:WORDS))])
  endfor
  let line = join(words, ' ')
  let llen = len(line)
  let want_t = s:rand(2) == 0

  " Candidate (target L, cursor C) pairs satisfying the shape.
  " L must have a non-space right-neighbor (word-interior on the
  " right side, L ≤ llen-1); C < L - 3; C not on X or Z.
  let candidates = []
  for L in range(5, llen - 1)
    let X = line[L - 1]
    let Z = line[L]
    if X ==# ' ' || Z ==# ' ' || X ==# Z | continue | endif
    for C in range(1, L - 4)
      let cch = line[C - 1]
      if cch ==# ' ' || cch ==# X || cch ==# Z | continue | endif
      " What would each motion actually do from C?
      let f_land = s:first_occurrence_after(line, X, C)
      let t_found = s:first_occurrence_after(line, Z, C)
      let t_land = t_found > 0 ? t_found - 1 : 0
      if want_t
        if t_land == L && f_land != L
          call add(candidates, [L, C])
        endif
      else
        if f_land == L && t_land != L
          call add(candidates, [L, C])
        endif
      endif
    endfor
  endfor

  if empty(candidates) | return {} | endif
  let [L, C] = candidates[s:rand(len(candidates))]
  return {'lines': [line],
    \ 'start': [1, C], 'target': [1, L],
    \ 'expected_motion': want_t ? 't' : 'f',
    \ 'optimal_motions': 1}
endfunction

function! vimfluency#pinpoints#move_to_vs_till_forward_in_words#generate() abort
  let attempts = 0
  while attempts < 30
    let attempts += 1
    let item = s:try_generate()
    if !empty(item)
      return item
    endif
  endwhile
  " Fallback: hand-verified f-item. 'spend faster point': target i
  " (col 16, unique forward from col 1); right-neighbor n repeats at
  " col 4 → tn stops early; fi lands exactly.
  return {'lines': ['spend faster point'],
    \ 'start': [1, 1], 'target': [1, 16],
    \ 'expected_motion': 'f', 'optimal_motions': 1}
endfunction

function! vimfluency#pinpoints#move_to_vs_till_forward_in_words#lesson() abort
  let buf_t = ['point faster spend']
  let buf_f = ['spend faster point']
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Same f/t rule as move_to_vs_till_forward, now inside real words:',
    \    '',
    \    '    f{c}  →  lands ON the next c',
    \    '    t{c}  →  lands ONE CELL BEFORE the next c',
    \    '',
    \    'Read the char under the target and the char to its right,',
    \    'then skim forward from your cursor: the one that repeats in',
    \    'the span stops too early — use the other one.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf_t, 'start': [1, 1], 'target': [1, 17],
    \  'prompt': 'Target is the n in "spend". An earlier n sits in "point" — fn stops there. Press td (the d right of it is unique ahead).'},
    \ {'kind': 'try', 'lines': buf_f, 'start': [1, 1], 'target': [1, 16],
    \  'prompt': 'Target is the i in "point" — unique ahead, so fi lands on it. (tn would stop at the n in "spend".)'},
    \ ]
endfunction
