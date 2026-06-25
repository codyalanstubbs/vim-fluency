" move_to_char_forward_backward — f{char} / F{char}. Find a target character on the current line.
"
" Design constraints to keep f/F the strictly shortest path:
"
"   - single line (no j/k cheats).
"
"   - distance from start to target ≥ 4 columns, so f/F's 2 keystrokes
"     beat the equivalent hjkl chain (≥ 4 keys).
"
"   - target column is INTERIOR to its word, with margin ≥ 2 from BOTH
"     word edges. Defeats the word-motion alternatives:
"       w + l × n: lands at word start, then n h/l moves to target.
"                  Margin ≥ 2 → ≥ 3 keystrokes total. f/F = 2 wins.
"       e + h × n: lands at word end, then n h moves to target.
"                  Margin ≥ 2 → ≥ 3 keystrokes total. f/F = 2 wins.
"       b/ge + ll/hh: backward variants with the same margin logic.
"     Word length ≥ 5 is required for the interior range to be non-empty.
"
"   - target character appears EXACTLY ONCE in the line, so f{c} from any
"     position to its left lands directly on it (no `;` needed) and F{c}
"     from any position to its right does the same.
"
"   - cursor never starts on whitespace or on the target character itself
"     (avoids ambiguity in what "next" / "previous" means to the learner).
"
"   - lines have no leading or trailing whitespace, so 0/^/$/g_ all land
"     on positions outside the candidate target range (col 1 or llen,
"     while target is always strictly interior to a word).
"
"   - the TILL alternative must miss (2026-06-11 shapes): any target is
"     also reachable with t/T using the target's neighbor char. Start
"     candidates where that till motion would land exactly on the target
"     are rejected, so f/F is the only clean single-chord answer. The
"     cursor also never starts on the relevant neighbor char.

let s:WORDS = ['return', 'import', 'while', 'range', 'class', 'value',
  \ 'array', 'result', 'parse', 'error', 'begin', 'label', 'count',
  \ 'frame', 'start', 'fetch', 'scope', 'plain', 'brain', 'focus',
  \ 'total', 'query', 'write', 'magic', 'cursor', 'target', 'finish',
  \ 'point', 'truck', 'noise', 'alpha', 'gamma', 'delta', 'south',
  \ 'north', 'visit', 'spend', 'phone', 'movie', 'happy', 'lucky',
  \ 'jumbo', 'flash', 'crisp', 'blank', 'globe']

function! vimfluency#drills#move_to_char_forward_backward#meta() abort
  return {'id': 'move_to_char_forward_backward', 'name': 'find char (f / F)',
    \ 'aim': 50, 'allowed_keys': 'fF', 'prereqs': ['move_single_char_up_down_left_right'],
    \ 'parallel_to': ['move_till_char_forward_backward'], 'keys': 'f/F', 'family': 'motion',
    \ 'test_sequence': ['f', 'F']}
endfunction

function! vimfluency#drills#move_to_char_forward_backward#lesson() abort
  " Rule-first intro, then each motion via a try frame so the learner
  " sees the cursor jump from their own keystroke — including the
  " "multiple-matches" rule, where staring at a static buffer doesn't
  " communicate which match the cursor lands on.
  let buf1 = ['the cat ran past']
  let buf2 = ['split banana']
  let buf3 = ['crab swim soft']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 1],
    \  'prompt': [
    \    'Two find moves:',
    \    '',
    \    '    f{c}   →   moves the cursor to the next {c}',
    \    '    F{c}   →   moves the cursor to the previous {c}',
    \    '',
    \    'Each lands ON the first match in that direction.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 1], 'target': [1, 13],
    \  'prompt': 'Press fp — moves the cursor to the next p.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 16], 'target': [1, 13],
    \  'prompt': 'Press Fp — moves the cursor to the previous p.'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 1], 'target': [1, 8],
    \  'prompt': 'Press fa — moves the cursor to the first a ahead, never a later match.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 16], 'target': [1, 9],
    \  'prompt': 'Press Fr — moves the cursor to the r in ran.'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 12], 'target': [1, 3],
    \  'prompt': 'Press Fl — moves the cursor to the l in split.'},
    \ {'kind': 'try', 'lines': buf3, 'start': [1, 1], 'target': [1, 9],
    \  'prompt': 'Press fm — moves the cursor to the m in swim.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" First column > a:after holding a:ch (1-indexed), 0 when absent.
function! s:first_after(line, ch, after) abort
  let c = a:after + 1
  let llen = len(a:line)
  while c <= llen
    if a:line[c - 1] ==# a:ch | return c | endif
    let c += 1
  endwhile
  return 0
endfunction

" Last column < a:before holding a:ch (1-indexed), 0 when absent.
function! s:last_before(line, ch, before) abort
  let c = a:before - 1
  while c >= 1
    if a:line[c - 1] ==# a:ch | return c | endif
    let c -= 1
  endwhile
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

  let candidates = []
  for wi in range(n_words)
    let ws = word_starts[wi]
    let we = word_ends[wi]
    if we - ws < 4 | continue | endif
    for c in range(ws + 2, we - 2)
      let ch = line[c - 1]
      if ch ==# ' ' | continue | endif
      if counts[ch] == 1
        call add(candidates, c)
      endif
    endfor
  endfor

  if empty(candidates) | return {} | endif
  let target_col = candidates[s:rand(len(candidates))]
  let target_char = line[target_col - 1]

  let valid_starts = []
  for sc in range(1, llen)
    if abs(sc - target_col) < 4 | continue | endif
    let ch = line[sc - 1]
    if ch ==# ' ' || ch ==# target_char | continue | endif
    " Shape filter: the till alternative (t/T with the target's
    " neighbor char) must NOT land on the target from this start;
    " otherwise the item is answerable with either member of the
    " find/till pair and the discrimination isn't drilled.
    if sc < target_col
      " forward f-item — till alternative is t{right-neighbor}
      let nb = line[target_col]
      if ch ==# nb | continue | endif
      let found = s:first_after(line, nb, sc)
      if found > 0 && found - 1 == target_col | continue | endif
    else
      " backward F-item — till alternative is T{left-neighbor}
      let nb = line[target_col - 2]
      if ch ==# nb | continue | endif
      let found = s:last_before(line, nb, sc)
      if found > 0 && found + 1 == target_col | continue | endif
    endif
    call add(valid_starts, sc)
  endfor

  if empty(valid_starts) | return {} | endif
  let start_col = valid_starts[s:rand(len(valid_starts))]
  let motion = start_col < target_col ? 'f' : 'F'

  return {'lines': [line], 'start': [1, start_col], 'target': [1, target_col],
    \ 'expected_motion': motion, 'optimal_motions': 1}
endfunction

function! vimfluency#drills#move_to_char_forward_backward#generate() abort
  let attempts = 0
  while attempts < 30
    let attempts += 1
    let item = s:try_generate()
    if !empty(item)
      return item
    endif
  endwhile
  " Fallback in the unlikely event of no candidate after 30 attempts.
  " 'spend faster point': i in 'point' (col 16) is unique → fi lands
  " exactly; its right-neighbor n repeats at col 4 → tn stops early.
  return {'lines': ['spend faster point'],
    \ 'start': [1, 1], 'target': [1, 16],
    \ 'expected_motion': 'f', 'optimal_motions': 1}
endfunction
