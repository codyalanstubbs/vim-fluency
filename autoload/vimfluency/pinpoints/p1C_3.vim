" 1C.3 — ; / , (repeat last find).
"
" `;` repeats the last f/F/t/T in the same direction.
" `,` repeats it in the opposite direction.
"
" The probe (and test phase) only generate ; items because , is rarely
" strictly optimal — its real value is correcting an overshoot in live
" editing, not navigating to a known target. The lesson teaches both,
" but every probed item is reached via fc;/Fc; (2 motions, 3 keys).
"
" Design constraints to keep fc;/Fc; the strictly shortest path:
"
"   - single line (no j/k cheats).
"
"   - distance from start to target >= 5 columns. fc; = 2 motion events;
"     hjkl chain >= 5 events; fc; wins clearly.
"
"   - target column is the SECOND occurrence of the chosen char going in
"     the chosen direction (forward → cols[1]; backward → cols[-2]). The
"     char appears >= 2 times in the line; target is interior to its
"     word with margin >= 2 from each edge so w/b/e/ge alternatives need
"     >= 3 events.
"
"   - cursor sits strictly on the OUTSIDE of all occurrences in the
"     chosen direction (forward: cursor < cols[0]; backward: cursor >
"     cols[-1]) so fc/Fc lands on the first occurrence and ; advances to
"     the second. Otherwise fc could skip the first and ; could overshoot.
"
"   - cursor never starts on whitespace or on the target character.
"
"   - 2fc/2Fc with a count is a 1-event alternative that the runner
"     can't distinguish — accepted as a Tier 5 escape; for a 1C.3-only
"     learner who hasn't done counts yet, fc;/Fc; is the natural answer.

let s:WORDS = ['return', 'import', 'while', 'range', 'class', 'value',
  \ 'array', 'result', 'parse', 'error', 'begin', 'label', 'count',
  \ 'frame', 'start', 'fetch', 'scope', 'plain', 'brain', 'focus',
  \ 'total', 'query', 'write', 'magic', 'cursor', 'target', 'finish',
  \ 'point', 'truck', 'noise', 'alpha', 'gamma', 'delta', 'south',
  \ 'north', 'visit', 'spend', 'phone', 'movie', 'happy', 'lucky',
  \ 'jumbo', 'flash', 'crisp', 'blank', 'globe']

function! vimfluency#pinpoints#p1C_3#meta() abort
  return {'id': '1C.3', 'name': 'repeat last find (; ,)',
    \ 'aim': 40, 'allowed_keys': ';,fFtT'}
endfunction

function! vimfluency#pinpoints#p1C_3#lesson() abort
  " Frame 1 is the rule statement (no specific motion to demo).
  " Frames 2-4 are tries where the learner performs the full sequence
  " (fc; / Fc; / fc,) and watches the cursor jump twice from their own
  " keystrokes. Frame 5 lets them feel the payoff with a many-match
  " char where retyping fa over and over would obviously waste keys.
  let buf1 = ['the cat ran past us today']
  let buf2 = ['banana split soda']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 1],
    \  'prompt': '; repeats your last f/F/t/T in the same direction. , repeats it in the opposite direction. No need to retype the character.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 5], 'target': [1, 16],
    \  'prompt': 'Press ft then ; — ft lands on the t in cat, ; jumps forward to the t in past.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 25], 'target': [1, 16],
    \  'prompt': 'Press Ft then ; — Ft lands on the t in today, ; jumps backward to the t in past.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 5], 'target': [1, 1],
    \  'prompt': 'Press ft then , — ft lands on the t in cat, , reverses direction back to the t in the.'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 1], 'target': [1, 4],
    \  'prompt': 'Press fa then ; — banana has 4 a''s; ; jumps from one to the next without retyping a.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:has_margin(col, word_starts, word_ends) abort
  for wi in range(len(a:word_starts))
    let ws = a:word_starts[wi]
    let we = a:word_ends[wi]
    if a:col >= ws && a:col <= we
      return (a:col - ws >= 2) && (we - a:col >= 2)
    endif
  endfor
  return 0
endfunction

function! s:try_generate() abort
  let n_words = 5 + s:rand(3)
  let words = []
  for _ in range(n_words)
    call add(words, s:WORDS[s:rand(len(s:WORDS))])
  endfor
  let line = join(words, ' ')
  let llen = len(line)

  let positions = {}
  for i in range(llen)
    let ch = line[i]
    if ch ==# ' ' | continue | endif
    if !has_key(positions, ch) | let positions[ch] = [] | endif
    call add(positions[ch], i + 1)
  endfor

  let word_starts = []
  let word_ends = []
  let cumcol = 1
  for w in words
    call add(word_starts, cumcol)
    call add(word_ends, cumcol + len(w) - 1)
    let cumcol += len(w) + 1
  endfor

  " 0 = forward (fc;), 1 = backward (Fc;)
  let direction = s:rand(2)

  let candidates = []
  for [ch, cols] in items(positions)
    if len(cols) < 2 | continue | endif
    if direction == 0
      let target_col = cols[1]
    else
      let target_col = cols[-2]
    endif
    if !s:has_margin(target_col, word_starts, word_ends) | continue | endif
    call add(candidates, [ch, target_col, cols])
  endfor

  if empty(candidates) | return {} | endif
  let pick = candidates[s:rand(len(candidates))]
  let target_char = pick[0]
  let target_col = pick[1]
  let cols_for_char = pick[2]

  let valid_starts = []
  for sc in range(1, llen)
    if direction == 0
      if sc >= cols_for_char[0] | continue | endif
    else
      if sc <= cols_for_char[-1] | continue | endif
    endif
    if abs(target_col - sc) < 5 | continue | endif
    let ch = line[sc - 1]
    if ch ==# ' ' || ch ==# target_char | continue | endif
    call add(valid_starts, sc)
  endfor

  if empty(valid_starts) | return {} | endif
  let start_col = valid_starts[s:rand(len(valid_starts))]

  return {'lines': [line], 'start': [1, start_col], 'target': [1, target_col],
    \ 'expected_motion': ';', 'optimal_motions': 2}
endfunction

function! vimfluency#pinpoints#p1C_3#generate() abort
  let attempts = 0
  while attempts < 30
    let attempts += 1
    let item = s:try_generate()
    if !empty(item)
      return item
    endif
  endwhile
  " Fallback: 'system pretend' — 'e' appears at cols 5, 10, 12. fe;
  " from col 1 lands on col 5 then col 10 (interior to 'pretend' with
  " margins 2 and 4). Distance 9.
  return {'lines': ['system pretend'],
    \ 'start': [1, 1], 'target': [1, 10],
    \ 'expected_motion': ';', 'optimal_motions': 2}
endfunction
