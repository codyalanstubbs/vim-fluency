" T0.1 — Enter/leave insert mode. The four canonical insert-entry keys
" plus the closing Esc:  i  a  I  A.
"
" Probe shape: mode kind. The conceptual target is a GAP between two
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

" Single shared prompt — the visual cue (▶◀ + green range) carries the
" discriminative content; the prose just frames the task.
let s:PROMPT = 'Enter insert mode at the marked gap, then press Esc.'

function! vimfluency#pinpoints#pT0_1#meta() abort
  " Catalog aim 50/min. Insert-entry is purely motor (single key +
  " Esc) once the discrimination is automatic. Starting guess.
  return {'id': 'T0.1', 'name': 'enter / leave insert mode',
    \ 'aim': 50, 'allowed_keys': 'iaIA<Esc>', 'kind': 'mode',
    \ 'prereqs': []}
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
function! vimfluency#pinpoints#pT0_1#lesson() abort
  let inline = 'the quick brown fox'
  let indented = '    return value'
  let short = 'print hello'
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Insert mode is where typing adds text.',
    \    'Several keys enter insert mode; this lesson covers four:',
    \    '    i, a, I, A.',
    \    'Each opens the cursor in a different spot.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'To LEAVE insert mode: press Esc OR Ctrl-C.',
    \    'Both produce the same result here — the runner accepts either.',
    \    'Ctrl-C is often preferred: Esc is a long reach from home row,',
    \    'so it costs you a finger stretch on every exit.',
    \    'Use whichever feels faster.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 5], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [inline], 'expected_motion': 'i', 'optimal_motions': 2,
    \  'hide_target': 1,
    \  'prompt': [
    \    'In this lesson, each frame will prompt you to enter insert mode and leave it.',
    \    'Press i to enter, then Esc (or Ctrl-C) to leave.']},
    \ {'kind': 'show', 'lines': [inline], 'cursor': [1, 1],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'prompt': [
    \    'Nice. In the next frames you''ll learn WHERE each key opens insert.',
    \    'A ▶◀ above the buffer will mark the spot you should enter at.',
    \    'It points at the gap between two chars — that''s the insert position.',
    \    'Use the key that lands the cursor in the right spot relative to ▶◀.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 5], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [inline], 'expected_motion': 'i', 'optimal_motions': 2,
    \  'prompt': [
    \    'i opens insert BEFORE the cursor — your cursor sits under ◀.',
    \    'Press i then Esc.']},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 5], 'target': [1, 5],
    \  'enter_at_row': 1, 'enter_at_col': 6,
    \  'target_lines': [inline], 'expected_motion': 'a', 'optimal_motions': 2,
    \  'prompt': [
    \    'a opens insert AFTER the cursor — your cursor sits under ▶.',
    \    'Press a then Esc.']},
    \ {'kind': 'try', 'lines': [indented], 'start': [1, 12], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [indented], 'expected_motion': 'I', 'optimal_motions': 2,
    \  'prompt': [
    \    'I jumps to the first non-blank char — the gap is at the indent edge.',
    \    'Press I then Esc.']},
    \ {'kind': 'try', 'lines': [short], 'start': [1, 4], 'target': [1, 11],
    \  'enter_at_row': 1, 'enter_at_col': 12,
    \  'target_lines': [short], 'expected_motion': 'A', 'optimal_motions': 2,
    \  'prompt': [
    \    'A jumps to the END of the line — the gap sits past the last char.',
    \    'Press A then Esc.']},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 11], 'target': [1, 10],
    \  'enter_at_row': 1, 'enter_at_col': 11,
    \  'target_lines': [inline], 'expected_motion': 'i', 'optimal_motions': 2,
    \  'prompt': 'i again — cursor on the right of ▶◀.'},
    \ {'kind': 'try', 'lines': [inline], 'start': [1, 11], 'target': [1, 11],
    \  'enter_at_row': 1, 'enter_at_col': 12,
    \  'target_lines': [inline], 'expected_motion': 'a', 'optimal_motions': 2,
    \  'prompt': 'a again — cursor on the left of ▶◀.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:first_nonblank_col(line) abort
  let m = match(a:line, '\S')
  return m + 1
endfunction

function! vimfluency#pinpoints#pT0_1#generate() abort
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
      \ 'target': [1, c - 1],
      \ 'expected_motion': 'i',
      \ 'optimal_motions': 2,
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
      \ 'target': [1, c],
      \ 'expected_motion': 'a',
      \ 'optimal_motions': 2,
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
      \ 'target': [1, fnb - 1],
      \ 'expected_motion': 'I',
      \ 'optimal_motions': 2,
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
      \ 'target': [1, l],
      \ 'expected_motion': 'A',
      \ 'optimal_motions': 2,
      \ 'prompt': s:PROMPT,
      \ }
  endif
endfunction
