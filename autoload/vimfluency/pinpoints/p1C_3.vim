" 1C.3 — ; / , (repeat last find).
"
" `;` repeats the last f/F/t/T in the same direction.
" `,` repeats it in the opposite direction.
"
" The training and test phase generate four scenarios in a roughly even
" mix:
"
"   forward ;  (fc;): cursor before the two occurrences;
"                     target = second forward, waypoint = first forward.
"   backward ; (Fc;): cursor after the two occurrences;
"                     target = second back, waypoint = first back.
"   forward ,  (fc,): cursor between the two occurrences;
"                     target = first occurrence (the one BEHIND cursor),
"                     waypoint = second occurrence (where fc lands first).
"   backward , (Fc,): cursor between the two occurrences;
"                     target = second occurrence (AHEAD of cursor),
"                     waypoint = first occurrence (where Fc lands first).
"
" The , scenarios are visually scaffolded by the waypoint annotation —
" the user sees "1 here, 2 here" with the cursor between them and infers
" the reverse-direction sequence. , isn't strictly optimal vs a direct
" fc/Fc (which reaches either occurrence in 1 motion), so the test
" phase credits both the canonical fc, and the direct-find shortcut as
" first-try-correct (motion count <= optimal_motions=2). The lesson
" setup teaches the , semantics explicitly.
"
" Cheat-defense:
"
"   - single line (no j/k cheats).
"
"   - distance from cursor to target >= 3 columns. fc;/fc, = 2 motion
"     events; hjkl chain >= 3 events; canonical sequence wins.
"
"   - target column interior to its word with margin >= 2 from each
"     edge so w/b/e/ge alternatives need >= 3 events.
"
"   - waypoint and target separated by >= 2 columns so a w-then-l-chain
"     to target via the waypoint position needs >= 3 events.
"
"   - cursor never starts on whitespace or on the target character.
"
"   - 2fc / 2Fc with a count is a 1-event alternative the runner can't
"     distinguish — accepted as a Tier 5 escape; the lesson assumes a
"     learner without counts will use the canonical sequence.

let s:WORDS = ['return', 'import', 'while', 'range', 'class', 'value',
  \ 'array', 'result', 'parse', 'error', 'begin', 'label', 'count',
  \ 'frame', 'start', 'fetch', 'scope', 'plain', 'brain', 'focus',
  \ 'total', 'query', 'write', 'magic', 'cursor', 'target', 'finish',
  \ 'point', 'truck', 'noise', 'alpha', 'gamma', 'delta', 'south',
  \ 'north', 'visit', 'spend', 'phone', 'movie', 'happy', 'lucky',
  \ 'jumbo', 'flash', 'crisp', 'blank', 'globe']

function! vimfluency#pinpoints#p1C_3#meta() abort
  return {'id': '1C.3', 'name': 'repeat last find (; ,)',
    \ 'aim': 40, 'allowed_keys': ';,fFtT', 'prereqs': ['1C.1', '1C.2']}
endfunction

function! vimfluency#pinpoints#p1C_3#lesson() abort
  " Frame 1 is the rule statement (no specific motion to demo).
  " Frames 2-5 are tries where the learner performs the full sequence
  " (fc; / Fc; / fc, / Fc,) and watches the cursor jump twice from
  " their own keystrokes. Frame 6 lets them feel the payoff with a
  " many-match char where retyping fa over and over would obviously
  " waste keys.
  let buf1 = ['the cat ran past us today']
  let buf2 = ['banana split soda']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 1],
    \  'prompt': '; repeats your last f/F/t/T in the same direction. , repeats it in the opposite direction. No need to retype the character.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 5], 'target': [1, 16],
    \  'waypoints': [[1, 7]],
    \  'prompt': 'Press ft then ; — ft lands on the t in cat (1), ; jumps forward to the t in past (2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 25], 'target': [1, 16],
    \  'waypoints': [[1, 21]],
    \  'prompt': 'Press Ft then ; — Ft lands on the t in today (1), ; jumps backward to the t in past (2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 11], 'target': [1, 7],
    \  'waypoints': [[1, 16]],
    \  'prompt': 'Press ft then , — ft lands on the t in past (1), , reverses direction back to the t in cat (2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 11], 'target': [1, 16],
    \  'waypoints': [[1, 7]],
    \  'prompt': 'Press Ft then , — Ft lands on the t in cat (1), , reverses direction forward to the t in past (2).'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 1], 'target': [1, 4],
    \  'waypoints': [[1, 2]],
    \  'prompt': 'Press fa then ; — fa lands on the first a in banana (1); ; jumps to the next a (2) without retyping.'},
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

  " 0 = forward ; (fc;), 1 = backward ; (Fc;),
  " 2 = forward , (fc,), 3 = backward , (Fc,)
  let scenario = s:rand(4)
  let expected_motion = (scenario < 2) ? ';' : ','

  let candidates = []
  for [ch, cols] in items(positions)
    if len(cols) < 2 | continue | endif
    if scenario == 0
      let target_col = cols[1]
      let waypoint_col = cols[0]
    elseif scenario == 1
      let target_col = cols[-2]
      let waypoint_col = cols[-1]
    elseif scenario == 2
      " fc, : cursor between cols[0] and cols[1]; fc lands on cols[1],
      " then , reverses to backward and lands on cols[0].
      let target_col = cols[0]
      let waypoint_col = cols[1]
    else
      " Fc, : cursor between cols[0] and cols[1]; Fc lands on cols[0],
      " then , reverses to forward and lands on cols[1].
      let target_col = cols[1]
      let waypoint_col = cols[0]
    endif
    if !s:has_margin(target_col, word_starts, word_ends) | continue | endif
    if abs(target_col - waypoint_col) < 2 | continue | endif
    call add(candidates, [ch, target_col, waypoint_col, cols])
  endfor

  if empty(candidates) | return {} | endif
  let pick = candidates[s:rand(len(candidates))]
  let target_char = pick[0]
  let target_col = pick[1]
  let waypoint_col = pick[2]
  let cols_for_char = pick[3]

  let valid_starts = []
  for sc in range(1, llen)
    if scenario == 0
      if sc >= cols_for_char[0] | continue | endif
    elseif scenario == 1
      if sc <= cols_for_char[-1] | continue | endif
    else
      " , scenarios: cursor strictly between cols[0] and cols[1].
      if sc <= cols_for_char[0] || sc >= cols_for_char[1] | continue | endif
    endif
    if abs(target_col - sc) < 3 | continue | endif
    let ch = line[sc - 1]
    if ch ==# ' ' || ch ==# target_char | continue | endif
    call add(valid_starts, sc)
  endfor

  if empty(valid_starts) | return {} | endif
  let start_col = valid_starts[s:rand(len(valid_starts))]

  return {'lines': [line], 'start': [1, start_col], 'target': [1, target_col],
    \ 'waypoints': [[1, waypoint_col]],
    \ 'expected_motion': expected_motion, 'optimal_motions': 2}
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
    \ 'waypoints': [[1, 5]],
    \ 'expected_motion': ';', 'optimal_motions': 2}
endfunction
