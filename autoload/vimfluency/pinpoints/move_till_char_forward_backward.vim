" move_till_char_forward_backward — t{char} / T{char}. Find a target character on the current line,
" but land one column shy of it (t = before, T = after).
"
" Where 1C.1's f/F land ON the char, t/T land NEXT TO it. The training target
" is the LANDING column (X-1 forward, X+1 backward) — not the char itself.
"
" Design constraints to keep t/T the strictly shortest path:
"
"   - single line (no j/k cheats).
"
"   - distance from start to target landing >= 3 columns (so t/T's 2
"     keystrokes beats the equivalent hjkl chain).
"
"   - target char interior to its word with direction-specific margins:
"       forward (t):  X - W_start >= 3  AND  W_end - X >= 1
"       backward (T): X - W_start >= 1  AND  W_end - X >= 3
"     These ensure the LANDING (X-1 forward, X+1 backward) sits >=2 from
"     either word edge, defeating w/b/e/ge alternatives. Word length >= 5
"     is enough for at least one direction to have candidates.
"
"   - target character appears EXACTLY ONCE in the line, so t{c} from any
"     position to its left lands directly at X-1 (no `;` needed) and
"     T{c} from any position to its right lands directly at X+1.
"     Also defeats the f-cheat: fc lands ON the unique c (one column past
"     the t-landing), so fc + h = 3 keys vs tc = 2 keys. Tc analogously.
"
"   - cursor never starts on whitespace or on the target character.
"
"   - lines have no leading or trailing whitespace, so 0/^/$/g_ all land
"     on positions outside the candidate landing range.

let s:WORDS = ['return', 'import', 'result', 'parser', 'broken', 'hammer',
  \ 'bridge', 'change', 'system', 'matrix', 'rocket', 'silver',
  \ 'helmet', 'pencil', 'forest', 'window', 'object', 'chance',
  \ 'damage', 'native', 'mental', 'modern', 'normal', 'random',
  \ 'simple', 'square', 'strong', 'travel', 'classes', 'imports',
  \ 'returns', 'fingers', 'mention', 'natural', 'patient', 'pretend',
  \ 'broaden', 'protect', 'failure', 'rainbow', 'opinion', 'warning',
  \ 'history', 'forward', 'channel', 'monster']

function! vimfluency#pinpoints#move_till_char_forward_backward#meta() abort
  return {'id': 'move_till_char_forward_backward', 'name': 'find char (t T)',
    \ 'aim': 45, 'allowed_keys': 'tT', 'prereqs': ['move_to_char_forward_backward'],
    \ 'parallel_to': ['move_to_char_forward_backward'], 'family': 'motion'}
endfunction

function! vimfluency#pinpoints#move_till_char_forward_backward#lesson() abort
  " Each motion via try frame so the learner sees the off-by-one
  " landing from their own keystroke. Frame 3 deliberately calls back
  " to f (the 1C.1 prereq) to make the discrimination concrete: same
  " buffer, same cursor, same target char, but f lands ON and t lands
  " BEFORE.
  let buf1 = ['the cat ran past us today']
  let buf2 = ['split banana']
  return [
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 1], 'target': [1, 12],
    \  'prompt': 'Press tp — t lands on the cell BEFORE the next p (col 12, the space).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 25], 'target': [1, 14],
    \  'prompt': 'Press Tp — T lands on the cell AFTER the previous p (col 14, the a).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 1], 'target': [1, 13],
    \  'prompt': 'Compare with f: press fp — f lands ON the p (col 13). t lands BEFORE.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 25], 'target': [1, 10],
    \  'prompt': 'Use Tr to land just after the r in ran — col 10 (the a).'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 1], 'target': [1, 7],
    \  'prompt': 'Use ta — banana has 3 a''s; t lands before the FIRST one (col 7, the b).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 1], 'target': [1, 17],
    \  'prompt': 'Use tu to land before us — col 17 (the space).'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:try_generate() abort
  let n_words = 5 + s:rand(3)
  let words = []
  for _ in range(n_words)
    call add(words, s:WORDS[s:rand(len(s:WORDS))])
  endfor
  let line = join(words, ' ')
  let llen = len(line)

  let counts = {}
  for i in range(llen)
    let ch = line[i]
    let counts[ch] = get(counts, ch, 0) + 1
  endfor

  let word_starts = []
  let word_ends = []
  let cumcol = 1
  for w in words
    call add(word_starts, cumcol)
    call add(word_ends, cumcol + len(w) - 1)
    let cumcol += len(w) + 1
  endfor

  " 0 = forward (t), 1 = backward (T)
  let direction = s:rand(2)

  " Find candidate char-cols X with appropriate word-margin and uniqueness.
  let candidates = []
  for wi in range(n_words)
    let ws = word_starts[wi]
    let we = word_ends[wi]
    if direction == 0
      let lo = ws + 3
      let hi = we - 1
    else
      let lo = ws + 1
      let hi = we - 3
    endif
    if hi < lo | continue | endif
    for x in range(lo, hi)
      let ch = line[x - 1]
      if ch ==# ' ' | continue | endif
      if counts[ch] == 1
        call add(candidates, x)
      endif
    endfor
  endfor

  if empty(candidates) | return {} | endif
  let target_char_col = candidates[s:rand(len(candidates))]
  let target_char = line[target_char_col - 1]
  let landing_col = direction == 0 ? target_char_col - 1 : target_char_col + 1

  " Forward: cursor LEFT of landing by >= 3, so cursor <= target_char_col - 4.
  " Backward: cursor RIGHT of landing by >= 3, so cursor >= target_char_col + 4.
  let valid_starts = []
  for sc in range(1, llen)
    if direction == 0
      if sc > target_char_col - 4 | continue | endif
    else
      if sc < target_char_col + 4 | continue | endif
    endif
    let ch = line[sc - 1]
    if ch ==# ' ' || ch ==# target_char | continue | endif
    call add(valid_starts, sc)
  endfor

  if empty(valid_starts) | return {} | endif
  let start_col = valid_starts[s:rand(len(valid_starts))]
  let motion = direction == 0 ? 't' : 'T'

  return {'lines': [line], 'start': [1, start_col], 'target': [1, landing_col],
    \ 'expected_motion': motion, 'optimal_motions': 1}
endfunction

function! vimfluency#pinpoints#move_till_char_forward_backward#generate() abort
  let attempts = 0
  while attempts < 30
    let attempts += 1
    let item = s:try_generate()
    if !empty(item)
      return item
    endif
  endwhile
  " Fallback: 'patient mention'. 'o' at col 14 of 'mention' is unique
  " and satisfies forward-margin (X-ws=5, we-X=1). Landing col 13.
  return {'lines': ['patient mention'],
    \ 'start': [1, 1], 'target': [1, 13],
    \ 'expected_motion': 't', 'optimal_motions': 1}
endfunction
