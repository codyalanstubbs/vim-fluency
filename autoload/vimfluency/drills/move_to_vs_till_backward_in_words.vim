" move_to_vs_till_backward_in_words — the realistic-content follow-on to
" move_to_vs_till_backward. Same F/T discrimination (pick the motion
" whose search char does NOT repeat between target and cursor), but
" embedded in real-word lines with variable geometry: the learner
" has to find the target, read its char and left-neighbor, and skim
" a span whose length changes every item.
"
" Prereq: move_to_vs_till_backward (the constant-geometry version) — get
" the discrimination fluent there first, then add the skim load here.
"
" Shape constraints, enforced per generated item:
"   T-item: X (char AT target) occurs again strictly between target
"           and cursor → F{X} stops early. Y (char LEFT of target)
"           does not occur in [target, cursor) → T{Y} lands exactly.
"   F-item: X unique in (target, cursor) → F{X} lands exactly.
"           Y occurs again in [target, cursor) → T{Y} stops early.
"
" Cheat-defense:
"   - the wrong member of the pair always lands off-target (shape)
"   - distance cursor→target ≥ 4 → h-walk always costs more
"   - target is word-interior (never col 1 / line end), so 0/^/$/g_
"     never land on it
"   - cursor never starts on X or Y

let s:WORDS = ['return', 'import', 'while', 'range', 'class', 'value',
  \ 'array', 'result', 'parse', 'error', 'begin', 'label', 'count',
  \ 'frame', 'start', 'fetch', 'scope', 'plain', 'brain', 'focus',
  \ 'total', 'query', 'write', 'magic', 'cursor', 'target', 'finish',
  \ 'point', 'truck', 'noise', 'alpha', 'gamma', 'delta', 'south',
  \ 'north', 'visit', 'spend', 'phone', 'movie', 'happy', 'lucky',
  \ 'jumbo', 'flash', 'crisp', 'blank', 'globe']

function! vimfluency#drills#move_to_vs_till_backward_in_words#meta() abort
  " Aim a tick below the constant-geometry drill's 50/min — the skim
  " span varies and the content is wordy. Starting guess.
  return {'id': 'move_to_vs_till_backward_in_words',
    \ 'name': 'find vs till in words, backward (F / T)',
    \ 'aim': 20, 'allowed_keys': 'FT',
    \ 'prereqs': ['move_to_vs_till_backward'],
    \ 'keys': 'F/T', 'family': 'motion',
    \ 'parallel_to': ['move_to_vs_till_forward_in_words'],
    \ 'test_sequence': ['F', 'T']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Last column < a:before where a:ch occurs in a:line (1-indexed),
" or 0 when absent. Mirrors what F{ch}/T{ch} from a:before would find.
function! s:last_occurrence_before(line, ch, before) abort
  let c = a:before - 1
  while c >= 1
    if a:line[c - 1] ==# a:ch | return c | endif
    let c -= 1
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
  let want_T = s:rand(2) == 0

  " Candidate (target L, cursor C) pairs satisfying the shape.
  " L must be word-interior (char at L and L-1 both non-space,
  " L ≥ 2); C > L + 3; C not on X or Y.
  let candidates = []
  for L in range(2, llen - 4)
    let X = line[L - 1]
    let Y = line[L - 2]
    if X ==# ' ' || Y ==# ' ' || X ==# Y | continue | endif
    for C in range(L + 4, llen)
      let cch = line[C - 1]
      if cch ==# ' ' || cch ==# X || cch ==# Y | continue | endif
      " What would each motion actually do from C?
      let f_land = s:last_occurrence_before(line, X, C)
      let t_found = s:last_occurrence_before(line, Y, C)
      let t_land = t_found > 0 ? t_found + 1 : 0
      if want_T
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
    \ 'expected_motion': want_T ? 'T' : 'F',
    \ 'optimal_motions': 1}
endfunction

function! vimfluency#drills#move_to_vs_till_backward_in_words#generate() abort
  let attempts = 0
  while attempts < 30
    let attempts += 1
    let item = s:try_generate()
    if !empty(item)
      return item
    endif
  endwhile
  " Fallback: hand-verified F-item. 'brain saved margin': target v
  " (col 9, unique); left-neighbor a repeats at col 14 → Ta stops
  " early; Fv lands exactly.
  return {'lines': ['brain saved margin'],
    \ 'start': [1, 17], 'target': [1, 9],
    \ 'expected_motion': 'F', 'optimal_motions': 1}
endfunction

function! vimfluency#drills#move_to_vs_till_backward_in_words#lesson() abort
  let buf_T = ['fetch target results']
  let buf_F = ['brain saved margin']
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Same F/T rule as before, now inside real words:',
    \    '',
    \    '    F{c}  →  lands ON the previous c',
    \    '    T{c}  →  lands ONE CELL AFTER the previous c',
    \    '',
    \    'Read the char under the target and the char to its left,',
    \    'then skim back toward your cursor: the one that repeats in',
    \    'the span stops too early — use the other one.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf_T, 'start': [1, 19], 'target': [1, 9],
    \  'expected_motion': 'T', 'optimal_motions': 1,
    \  'prompt': 'Target is the r in "target". r repeats in "results" — Fr stops there. Press Ta (the a left of it is nearest).'},
    \ {'kind': 'try', 'lines': buf_F, 'start': [1, 17], 'target': [1, 9],
    \  'expected_motion': 'F', 'optimal_motions': 1,
    \  'prompt': 'Target is the v — unique, so Fv lands on it. (Ta would stop after the a in "margin".)'},
    \ ]
endfunction
