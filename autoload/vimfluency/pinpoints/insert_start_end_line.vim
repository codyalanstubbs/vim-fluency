" insert_start_end_line — atomic 2-cell drill on the I / A
" entry-key pair. Both keys IGNORE the cursor's column and jump to
" a fixed line-edge position before entering insert mode:
"
"   I → jump to first non-blank, insert there (left edge of content)
"   A → jump to one past end of line, append there (right edge)
"
" The discriminator is which edge the '▶◀' indicator marks:
"
"   ▶◀ at the indent boundary  →  press I
"   ▶◀ past the last char      →  press A
"
" The cursor sits at a third, irrelevant column — far from BOTH
" edges — so the learner can't fall back on the cursor-under-▶/◀
" rule from insert_before_after_char.
"
" Lines: I items use indented content (first_nonblank > 1); A
" items use unindented short lines. Each item: press I or A, type
" 'foo'.

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

let s:INSERT_TEXT = 'foo'
let s:PROMPT = printf('Enter insert mode at the marked gap, then type %s.', s:INSERT_TEXT)

function! vimfluency#pinpoints#insert_start_end_line#meta() abort
  " Aim 60/min. Same shape as insert_before_after_char — 2-cell
  " discrimination plus 'foo' payload, 4 strokes per item.
  return {'id': 'insert_start_end_line',
    \ 'name': 'insert at line start / end (I / A)',
    \ 'aim': 60, 'allowed_keys': 'IAfo', 'kind': 'mode',
    \ 'prereqs': [], 'keys': 'I/A', 'family': 'survival',
    \ 'parallel_to': ['insert_before_after_char'],
    \ 'credit_on_text_typed': 1}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:first_nonblank_col(line) abort
  let m = match(a:line, '\S')
  return m + 1
endfunction

function! s:typed_at(line, col) abort
  return strpart(a:line, 0, a:col - 1) . s:INSERT_TEXT . strpart(a:line, a:col - 1)
endfunction

function! vimfluency#pinpoints#insert_start_end_line#generate() abort
  let key = ['I', 'A'][s:rand(2)]
  if key ==# 'I'
    let line = s:lines_indented[s:rand(len(s:lines_indented))]
    let fnb = s:first_nonblank_col(line)
    " Start column strictly to the right of first_nonblank so cursor
    " is visibly far from the indent edge.
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
    " Start col in [1, l-1] so cursor is visibly away from end edge.
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

" Lesson: rule statement plus two pairs of I / A try frames. The
" indented line makes the I gap visible at the indent boundary; the
" short line makes the A gap visible past the last char.
function! vimfluency#pinpoints#insert_start_end_line#lesson() abort
  let indented = '    return value'
  let short = 'print hello'
  let t = s:INSERT_TEXT
  let I_typed = s:typed_at(indented, 5)
  let A_typed = s:typed_at(short, 12)
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two entry keys, distinguished by which line edge the gap',
    \    'marker (▶◀) sits at:',
    \    '',
    \    '    ▶◀ at the indent boundary  →  press I',
    \    '    ▶◀ past the last char      →  press A',
    \    '',
    \    'Neither key cares where your cursor starts — both jump to',
    \    'their edge before opening insert.',
    \    '',
    \    printf('Each frame: press the key, then type %s.', t),
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [indented], 'start': [1, 12], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [indented], 'target_lines_after_type': [I_typed],
    \  'expected_motion': 'I', 'optimal_motions': 4,
    \  'prompt': [
    \    'I jumps to the first non-blank — the gap is at the indent edge.',
    \    printf('Press I, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [short], 'start': [1, 4], 'target': [1, 11],
    \  'enter_at_row': 1, 'enter_at_col': 12,
    \  'target_lines': [short], 'target_lines_after_type': [A_typed],
    \  'expected_motion': 'A', 'optimal_motions': 4,
    \  'prompt': [
    \    'A jumps to the END of the line — the gap sits past the last char.',
    \    printf('Press A, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [indented], 'start': [1, 14], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [indented], 'target_lines_after_type': [I_typed],
    \  'expected_motion': 'I', 'optimal_motions': 4,
    \  'prompt': printf('I again — gap at the indent edge. Type %s.', t)},
    \ {'kind': 'try', 'lines': [short], 'start': [1, 2], 'target': [1, 11],
    \  'enter_at_row': 1, 'enter_at_col': 12,
    \  'target_lines': [short], 'target_lines_after_type': [A_typed],
    \  'expected_motion': 'A', 'optimal_motions': 4,
    \  'prompt': printf('A again — gap past the last char. Type %s.', t)},
    \ ]
endfunction
