" insert_before_after_char_start_end_line — composite drill over all
" four positional insert-entry keys (i / a / I / A). Mixes the two
" atomic discriminations from insert_before_after_char (i vs a) and
" insert_start_end_line (I vs A) into a single 4-way cell so the
" learner has to distinguish across both axes at once.
"
" Training shape: mode kind. The conceptual target is a GAP between two
" cells (insertion points are between chars, not on them), so the
" cue is an indicator row above the content with '▶◀' pointing inward
" at the gap's flanking columns. The content row stays uncolored —
" the discriminator is the arrows' position relative to the cursor.
"
" Discrimination by (cursor, gap) geometry:
"   - cursor under ◀ (right side of seam) → `i` (insert before cursor)
"   - cursor under ▶ (left side of seam)  → `a` (append after cursor)
"   - cursor far from arrows, ▶◀ near indent boundary → `I`
"   - cursor far from arrows, ▶◀ at end of line       → `A`
"
" Per-key generator constraints (derived from the InsertEnter-col
" matcher, which is the actual cheat-defense):
"   - i items: line has no leading whitespace; 2 ≤ S ≤ line_end
"   - a items: line has no leading whitespace; 1 ≤ S < line_end
"     (excluding S=line_end so `a` and `A` aren't observationally
"     identical: both would InsertEnter at line_end+1)
"   - I items: line HAS leading whitespace (fnb > 1); S ∉ {fnb-1, fnb}
"     (so `i` and `a` from the same S land at different cols than
"     `I` does)
"   - A items: 1 ≤ S < line_end (excluding S=line_end as above)
"
" Cheat-defense at the InsertEnter level: the runner matches both
" enter_at_col and post-Esc cursor pos. Most non-canonical key
" sequences produce a different InsertEnter col, so they don't
" credit even when the post-Esc cursor happens to land at T.
" Paths that DO match (e.g. `^i<Esc>` for an I item — same
" InsertEnter col, same post-Esc col) take more keystrokes and lose
" on rate; the SCC errors line surfaces them.
"
" Per-motion bucket: i, a, I, A — each tracked independently so the
" summary surfaces which entry key is slowest.
"
" Post-Esc cursor (no typing): verified empirically via :feedkeys
"   - i at col X (X>1):  X-1
"   - i at col 1:        1
"   - a at col X:        X
"   - I (first_nonblank=N, N>1):  N-1
"   - A (line len L):    L

" Phrases for i/a items. No leading whitespace.
let s:lines_inline = [
  \ 'the quick brown fox',
  \ 'vim makes editing fast',
  \ 'practice every single day',
  \ 'fluency requires repetition',
  \ ]

" Indented lines for I items. Indent width varies so first_nonblank
" isn't constant across items.
let s:lines_indented = [
  \ '    return value',
  \ '        if condition',
  \ '  def helper',
  \ '      foo bar baz',
  \ ]

" Lines for A items. No trailing whitespace.
let s:lines_endable = [
  \ 'print hello',
  \ 'open file',
  \ 'edit text',
  \ 'save buffer',
  \ ]

" The learner types this fixed test string after each entry key so
" the runner can credit on a buffer match rather than on Esc.
" Esc/Ctrl-[ get their own drill via switch_mode_to_insert; this
" one focuses on the entry-key discrimination (where each key lands
" the cursor for insertion).
let s:INSERT_TEXT = 'foo'

" Single shared prompt — the visual cue (▶◀ + green range) carries the
" discriminative content; the prose just frames the task.
let s:PROMPT = printf('Enter insert mode at the marked gap, then type %s.', s:INSERT_TEXT)

function! vimfluency#drills#insert_before_after_char_start_end_line#meta() abort
  " Catalog aim 50/min — slightly below either atomic's 60/min
  " because the 4-way decision (which axis × which side) adds
  " discrimination load. 4 strokes per item (entry key + 'foo').
  "
  " credit_on_text_typed — both training and lesson advance the
  " moment the buffer matches the post-insertion target (the
  " learner pressed the right entry key AND typed the expected
  " text in the right spot). No Esc round-trip; mode-leave fluency
  " is measured separately in switch_mode_to_insert.
  return {'id': 'insert_before_after_char_start_end_line',
    \ 'name': 'enter insert mode (i / a / I / A)',
    \ 'aim': 50, 'allowed_keys': 'iaIAfo', 'kind': 'mode',
    \ 'prereqs': ['insert_before_after_char', 'insert_start_end_line'],
    \ 'keys': 'i/a/I/A',
    \ 'family': 'survival', 'credit_on_text_typed': 1,
    \ 'test_sequence': ['i', 'a', 'I', 'A']}
endfunction

" DI sequence: three short show frames introduce the ▶◀ cue, then
" one try frame per key. Each try frame demonstrates a single rule:
"   - i  → opens insert BEFORE the cursor's char (cursor under ◀)
"   - a  → opens insert AFTER the cursor's char  (cursor under ▶)
"   - I  → opens insert at the first non-blank   (gap at indent edge)
"   - A  → opens insert at the END of the line   (gap past last char)
" Two extra try frames re-juxtapose i vs a so the cursor-side
" discriminator is seen twice. Test phase randomizes.
"
" Prompts are lists of short lines (≤ ~60 chars each) so the lesson
" buffer stays readable at any zoom — the runner splices each line
" into its own row of the header.

" Insert s:INSERT_TEXT at the given 1-based column (the column at
" which typed chars appear in insert mode). Returns the post-typing
" line. Used by both the lesson and the generator to compute the
" target_lines_after_type field.
function! s:typed_at(line, col) abort
  return strpart(a:line, 0, a:col - 1) . s:INSERT_TEXT . strpart(a:line, a:col - 1)
endfunction

function! vimfluency#drills#insert_before_after_char_start_end_line#lesson() abort
  let inline = 'the quick brown fox'
  let indented = '    return value'
  let short = 'print hello'
  let t = s:INSERT_TEXT
  " Pre-compute each frame's post-typing line. target_lines stays at
  " the original (used by InsertLeave's post-Esc verification, which
  " is the fallback path); target_lines_after_type is what the
  " TextChangedI handler matches against to credit mid-insert.
  let i1_typed = s:typed_at(inline, 5)
  let a1_typed = s:typed_at(inline, 6)
  let I_typed  = s:typed_at(indented, 5)
  let A_typed  = s:typed_at(short, 12)
  let i2_typed = s:typed_at(inline, 11)
  let a2_typed = s:typed_at(inline, 12)

  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Four keys that open INSERT, each at a different spot:',
    \    '',
    \    '    i   →   before the cursor',
    \    '    a   →   after the cursor',
    \    '    I   →   at the first non-blank (line start)',
    \    '    A   →   at the end of the line',
    \    '',
    \    printf('In every try frame, type %s; no <Esc> needed (a separate lesson).', t),
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 5], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [inline], 'target_lines_after_type': [i1_typed],
    \  'expected_motion': 'i', 'optimal_motions': 4, 'hide_target': 1,
    \  'prompt': [
    \    'A ▶◀ above the buffer will mark the spot to enter at.',
    \    'It points at the gap between two chars — the insert position.',
    \    '',
    \    printf('Press i, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 5], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [inline], 'target_lines_after_type': [i1_typed],
    \  'expected_motion': 'i', 'optimal_motions': 4,
    \  'prompt': [
    \    'i opens INSERT before the cursor — your cursor sits under ◀.',
    \    printf('Press i, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 5], 'target': [1, 5],
    \  'enter_at_row': 1, 'enter_at_col': 6,
    \  'target_lines': [inline], 'target_lines_after_type': [a1_typed],
    \  'expected_motion': 'a', 'optimal_motions': 4,
    \  'prompt': [
    \    'a opens INSERT after the cursor — your cursor sits under ▶.',
    \    printf('Press a, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [indented], 'start': [1, 12], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [indented], 'target_lines_after_type': [I_typed],
    \  'expected_motion': 'I', 'optimal_motions': 4,
    \  'prompt': [
    \    'I opens INSERT at the first non-blank — the gap is at the indent edge.',
    \    printf('Press I, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [short], 'start': [1, 4], 'target': [1, 11],
    \  'enter_at_row': 1, 'enter_at_col': 12,
    \  'target_lines': [short], 'target_lines_after_type': [A_typed],
    \  'expected_motion': 'A', 'optimal_motions': 4,
    \  'prompt': [
    \    'A opens INSERT at the end of the line — the gap sits past the last char.',
    \    printf('Press A, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 11], 'target': [1, 10],
    \  'enter_at_row': 1, 'enter_at_col': 11,
    \  'target_lines': [inline], 'target_lines_after_type': [i2_typed],
    \  'expected_motion': 'i', 'optimal_motions': 4,
    \  'prompt': printf('i again — cursor on the right of ▶◀. Type %s.', t)},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 11], 'target': [1, 11],
    \  'enter_at_row': 1, 'enter_at_col': 12,
    \  'target_lines': [inline], 'target_lines_after_type': [a2_typed],
    \  'expected_motion': 'a', 'optimal_motions': 4,
    \  'prompt': printf('a again — cursor on the left of ▶◀. Type %s.', t)},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:first_nonblank_col(line) abort
  let m = match(a:line, '\S')
  return m + 1
endfunction

function! vimfluency#drills#insert_before_after_char_start_end_line#generate() abort
  let key = ['i', 'a', 'I', 'A'][s:rand(4)]
  if key ==# 'i'
    let line = s:lines_inline[s:rand(len(s:lines_inline))]
    " S in [2, line_end]
    let c = 2 + s:rand(len(line) - 1)
    return {
      \ 'lines': [line],
      \ 'start': [1, c],
      \ 'enter_at_row': 1,
      \ 'enter_at_col': c,
      \ 'target_lines': [line],
      \ 'target_lines_after_type': [s:typed_at(line, c)],
      \ 'target': [1, c - 1],
      \ 'expected_motion': 'i',
      \ 'optimal_motions': 4,
      \ 'prompt': s:PROMPT,
      \ }
  elseif key ==# 'a'
    let line = s:lines_inline[s:rand(len(s:lines_inline))]
    " S in [1, line_end - 1]
    let c = 1 + s:rand(len(line) - 1)
    return {
      \ 'lines': [line],
      \ 'start': [1, c],
      \ 'enter_at_row': 1,
      \ 'enter_at_col': c + 1,
      \ 'target_lines': [line],
      \ 'target_lines_after_type': [s:typed_at(line, c + 1)],
      \ 'target': [1, c],
      \ 'expected_motion': 'a',
      \ 'optimal_motions': 4,
      \ 'prompt': s:PROMPT,
      \ }
  elseif key ==# 'I'
    let line = s:lines_indented[s:rand(len(s:lines_indented))]
    let fnb = s:first_nonblank_col(line)
    " S must avoid fnb-1 (collides with `a` at same S) and fnb
    " (collides with `i` at same S). Pick S strictly to the right of
    " first_nonblank: [fnb+1, line_end].
    let c = fnb + 1 + s:rand(max([len(line) - fnb, 1]))
    if c > len(line) | let c = len(line) | endif
    return {
      \ 'lines': [line],
      \ 'start': [1, c],
      \ 'enter_at_row': 1,
      \ 'enter_at_col': fnb,
      \ 'target_lines': [line],
      \ 'target_lines_after_type': [s:typed_at(line, fnb)],
      \ 'target': [1, fnb - 1],
      \ 'expected_motion': 'I',
      \ 'optimal_motions': 4,
      \ 'prompt': s:PROMPT,
      \ }
  else  " A
    let line = s:lines_endable[s:rand(len(s:lines_endable))]
    let l = len(line)
    " S in [1, line_end - 1]
    let c = 1 + s:rand(l - 1)
    return {
      \ 'lines': [line],
      \ 'start': [1, c],
      \ 'enter_at_row': 1,
      \ 'enter_at_col': l + 1,
      \ 'target_lines': [line],
      \ 'target_lines_after_type': [s:typed_at(line, l + 1)],
      \ 'target': [1, l],
      \ 'expected_motion': 'A',
      \ 'optimal_motions': 4,
      \ 'prompt': s:PROMPT,
      \ }
  endif
endfunction
