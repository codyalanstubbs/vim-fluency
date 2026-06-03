" open_line_above_below — Open new line. The two openers: o (below) and O (above),
" plus the closing Esc.
"
" Training shape: mode kind. The conceptual target is a gap between two
" ROWS. We cue it by marking the two rows that bracket the gap with
" a '⏵' indicator in column 1, leaving non-bracket rows with a single
" leading space so word columns stay aligned:
"
"      foxy
"     ⏵soxy      ← upper bracket
"     ⏵roxy      ← lower bracket
"      poxy
"
" The cursor sits on ONE of the two bracket rows. The OTHER row's '⏵'
" position tells you the direction:
"   - other ⏵ is BELOW cursor → press o (open below)
"   - other ⏵ is ABOVE cursor → press O (open above)
"
" Why this design (vs. an inline ─── separator):
"   - The indicators are part of the content rows, so they shift
"     coherently with the row through any edit — no need to think
"     about how a decoration row drifts post-press.
"   - The two markers mirror T0.1's '▶◀' seam cue: both indicators
"     converge on the gap, just rotated 90°. Two rows of '⏵' bracket
"     a horizontal seam the same way two arrows brackets a vertical
"     one.
"
" Cheat-defense at the runner level (mirrors T0.1):
"   - InsertEnter row + final target_lines + post-Esc cursor must all
"     match. Pressing the wrong key from the canonical start row
"     produces a different post-press buffer.
"   - Cheat paths like `jO` for an o-item (or `ko` for an O-item)
"     navigate to the OTHER bracket row first, then press the other
"     key — the resulting buffer matches, so the cheat credits, but
"     at 3 motions instead of 2 the SCC errors line surfaces it.

let s:words = [
  \ 'alpha', 'beta', 'gamma', 'delta', 'epsilon',
  \ 'zeta', 'eta', 'theta', 'iota', 'kappa',
  \ ]
let s:MARK = '⏵'
let s:NO_MARK = ' '

" Same fixed test string as insert_before_after_char_start_end_line — the learner types this
" into the freshly opened line so the runner can credit on a buffer
" match rather than on the leave-mode keystroke. Esc/Ctrl-[ get
" their own pinpoint via switch_mode_to_insert; this one focuses on
" the o/O direction discrimination.
let s:INSERT_TEXT = 'foo'

function! vimfluency#pinpoints#open_line_above_below#meta() abort
  " Catalog aim 40/min. Same shape as insert_before_after_char_start_end_line post-redesign:
  " each item is 4 strokes (the o or O opener plus the 3 chars of
  " 'foo'). The buffer change makes the cue (and any failure)
  " visible — slightly below insert_before_after_char_start_end_line's aim because the eye
  " has to verify TWO rows for the direction cue.
  return {'id': 'open_line_above_below', 'name': 'open new line (o / O)',
    \ 'aim': 40, 'allowed_keys': 'oOfo', 'kind': 'mode',
    \ 'prereqs': ['insert_before_after_char_start_end_line'], 'keys': 'o/O', 'family': 'survival',
    \ 'credit_on_text_typed': 1}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Pick n distinct words from the pool (no repetitions in one item).
function! s:pick_distinct(n, pool) abort
  let pool = copy(a:pool)
  let result = []
  while len(result) < a:n && !empty(pool)
    let i = s:rand(len(pool))
    call add(result, remove(pool, i))
  endwhile
  return result
endfunction

" Build the pre-press buffer rows. Bracket rows (1-indexed `upper` and
" `upper + 1`) get the '⏵' prefix; the rest get a single space so
" content columns line up.
function! s:build_lines(words, upper) abort
  let lines = []
  let n = len(a:words)
  for i in range(n)
    let row = i + 1
    let prefix = (row == a:upper || row == a:upper + 1) ? s:MARK : s:NO_MARK
    call add(lines, prefix . a:words[i])
  endfor
  return lines
endfunction

function! vimfluency#pinpoints#open_line_above_below#generate() abort
  let n_words = 4
  let words = s:pick_distinct(n_words, s:words)
  " upper bracket row (1-indexed) in [1, n_words - 1]; lower bracket
  " is upper + 1. The gap sits between them.
  let upper = 1 + s:rand(n_words - 1)
  let lines = s:build_lines(words, upper)
  let key = ['o', 'O'][s:rand(2)]
  let start_row = (key ==# 'o') ? upper : upper + 1
  " Both keys land the new blank between the two bracket rows; the
  " runner distinguishes them via the cursor's starting row (cheat-
  " defense for wrong-key-from-canonical-start).
  let target_row = upper + 1
  " target_lines is the post-entry-key buffer (blank line opened);
  " target_lines_after_type is the post-typing buffer (blank line
  " replaced with the test string). The credit_on_text_typed flow
  " matches against target_lines_after_type; target_lines doubles
  " as the runner's "skip me, this is the auto-line-insert"
  " sentinel for the first-TextChangedI guard.
  let target_lines = lines[:upper - 1] + [''] + lines[upper:]
  let target_lines_after_type =
    \ lines[:upper - 1] + [s:INSERT_TEXT] + lines[upper:]
  return {
    \ 'lines': lines,
    \ 'start': [start_row, 2],
    \ 'enter_at_row': target_row,
    \ 'enter_at_col': 1,
    \ 'target_lines': target_lines,
    \ 'target_lines_after_type': target_lines_after_type,
    \ 'target': [target_row, 1],
    \ 'hide_target': 1,
    \ 'expected_motion': key,
    \ 'optimal_motions': 4,
    \ 'prompt': printf('Open a new line at the gap between the ⏵ rows, then type %s.', s:INSERT_TEXT),
    \ }
endfunction

" DI sequence: T0.1 is a prereq, so the learner already knows insert
" mode and Esc/Ctrl-C. T0.2's lesson focuses on the new concepts —
" the bracketed-gap indicator and the o/O direction rule.
function! vimfluency#pinpoints#open_line_above_below#lesson() abort
  let demo = [' alpha', '⏵beta', '⏵gamma', ' delta']
  let target = [' alpha', '⏵beta', '', '⏵gamma', ' delta']
  let target_typed = [' alpha', '⏵beta', s:INSERT_TEXT, '⏵gamma', ' delta']
  let t = s:INSERT_TEXT
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'open new lines.',
    \    'o opens a NEW LINE below the cursor and enters insert mode.',
    \    'O opens a NEW LINE above the cursor and enters insert mode.',
    \    '',
    \    printf('You''ll type %s on the new line to confirm; no Esc needed.', t),
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'show', 'lines': demo, 'cursor': [2, 2],
    \  'prompt': [
    \    'Two ⏵ markers on adjacent rows BRACKET the gap between them.',
    \    'Your cursor will sit on ONE of those rows; the OTHER ⏵',
    \    'tells you the direction:',
    \    '  - other ⏵ is BELOW your cursor → press o (open below)',
    \    '  - other ⏵ is ABOVE your cursor → press O (open above)',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': demo, 'start': [2, 2],
    \  'enter_at_row': 3, 'enter_at_col': 1,
    \  'target_lines': target, 'target_lines_after_type': target_typed,
    \  'target': [3, 1], 'expected_motion': 'o', 'optimal_motions': 4,
    \  'hide_target': 1,
    \  'prompt': [
    \    'Cursor sits on the UPPER ⏵ row — the other ⏵ is below you.',
    \    printf('Press o, then type %s.', t)]},
    \ {'kind': 'try', 'lines': demo, 'start': [3, 2],
    \  'enter_at_row': 3, 'enter_at_col': 1,
    \  'target_lines': target, 'target_lines_after_type': target_typed,
    \  'target': [3, 1], 'expected_motion': 'O', 'optimal_motions': 4,
    \  'hide_target': 1,
    \  'prompt': [
    \    'Cursor sits on the LOWER ⏵ row — the other ⏵ is above you.',
    \    printf('Press O, then type %s.', t)]},
    \ {'kind': 'try', 'lines': demo, 'start': [2, 2],
    \  'enter_at_row': 3, 'enter_at_col': 1,
    \  'target_lines': target, 'target_lines_after_type': target_typed,
    \  'target': [3, 1], 'expected_motion': 'o', 'optimal_motions': 4,
    \  'hide_target': 1,
    \  'prompt': printf('o again — cursor on upper ⏵, other ⏵ below. Type %s.', t)},
    \ {'kind': 'try', 'lines': demo, 'start': [3, 2],
    \  'enter_at_row': 3, 'enter_at_col': 1,
    \  'target_lines': target, 'target_lines_after_type': target_typed,
    \  'target': [3, 1], 'expected_motion': 'O', 'optimal_motions': 4,
    \  'hide_target': 1,
    \  'prompt': printf('O again — cursor on lower ⏵, other ⏵ above. Type %s.', t)},
    \ ]
endfunction
