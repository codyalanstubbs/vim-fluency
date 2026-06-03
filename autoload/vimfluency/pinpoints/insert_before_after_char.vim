" insert_before_after_char — atomic 2-cell drill on the i / a
" entry-key pair. Cursor sits on a single character; the cue is a
" '▶◀' indicator row above the line, with the ▶ pointing at the
" column LEFT of the seam and the ◀ pointing at the column RIGHT
" of the seam. The discriminator is which arrow the cursor sits
" under:
"
"   cursor under ◀ (right side of seam) → i (insert BEFORE cursor)
"   cursor under ▶ (left side of seam)  → a (append AFTER cursor)
"
" Both keys produce identical post-typing buffers when targeted at
" the same seam — vim's `i` inserts at the cursor column, vim's
" `a` lands at the column AFTER the cursor and inserts there.
" That's why the cue has to single out a column rather than a
" character — the seam IS a column boundary, not a character.
"
" Lines have no leading whitespace, ruling out the I/A
" discriminations. Each item: press i or a, type 'foo'.

let s:lines = [
  \ 'the quick brown fox',
  \ 'vim makes editing fast',
  \ 'practice every single day',
  \ 'fluency requires repetition',
  \ ]

let s:INSERT_TEXT = 'foo'
let s:PROMPT = printf('Enter insert mode at the marked gap, then type %s.', s:INSERT_TEXT)

function! vimfluency#pinpoints#insert_before_after_char#meta() abort
  " Aim 60/min — single-axis discrimination (cursor under ◀ vs ▶),
  " plus a 3-char payload. Higher than insert_before_after_char_start_end_line's
  " 50/min because the discrimination set is narrower (2 cells vs 4).
  return {'id': 'insert_before_after_char',
    \ 'name': 'insert before / after char (i / a)',
    \ 'aim': 60, 'allowed_keys': 'iafo', 'kind': 'mode',
    \ 'prereqs': [], 'keys': 'i/a', 'family': 'survival',
    \ 'parallel_to': ['insert_start_end_line'],
    \ 'credit_on_text_typed': 1,
    \ 'test_sequence': ['i', 'a']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Insert s:INSERT_TEXT at the given 1-based column (the column at
" which typed chars appear in insert mode). Used to compute
" target_lines_after_type.
function! s:typed_at(line, col) abort
  return strpart(a:line, 0, a:col - 1) . s:INSERT_TEXT . strpart(a:line, a:col - 1)
endfunction

function! vimfluency#pinpoints#insert_before_after_char#generate() abort
  let key = ['i', 'a'][s:rand(2)]
  let line = s:lines[s:rand(len(s:lines))]
  if key ==# 'i'
    " S in [2, line_end] — see insert_before_after_char_start_end_line for the
    " S=1 / S=line_end carveouts (irrelevant here since we're 2-cell).
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
  else  " a
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
  endif
endfunction

" Lesson: rule statement plus two pairs of try frames juxtaposing i
" against a at adjacent columns of the same line. Same seam, same
" content — only the cursor's side of the seam changes.
function! vimfluency#pinpoints#insert_before_after_char#lesson() abort
  let line = 'the quick brown fox'
  let t = s:INSERT_TEXT
  let typed_at_5 = s:typed_at(line, 5)
  let typed_at_6 = s:typed_at(line, 6)
  let typed_at_11 = s:typed_at(line, 11)
  let typed_at_12 = s:typed_at(line, 12)
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two entry keys, distinguished by where the cursor sits:',
    \    '',
    \    '    cursor under ◀  →  press i (insert BEFORE cursor)',
    \    '    cursor under ▶  →  press a (append AFTER cursor)',
    \    '',
    \    printf('Each frame: press the key, then type %s.', t),
    \    'The lesson advances the moment the text appears.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [line], 'start': [1, 5], 'target': [1, 4],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': [line], 'target_lines_after_type': [typed_at_5],
    \  'expected_motion': 'i', 'optimal_motions': 4,
    \  'prompt': [
    \    'i opens insert BEFORE the cursor — your cursor sits under ◀.',
    \    printf('Press i, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [line], 'start': [1, 5], 'target': [1, 5],
    \  'enter_at_row': 1, 'enter_at_col': 6,
    \  'target_lines': [line], 'target_lines_after_type': [typed_at_6],
    \  'expected_motion': 'a', 'optimal_motions': 4,
    \  'prompt': [
    \    'a opens insert AFTER the cursor — your cursor sits under ▶.',
    \    printf('Press a, then type %s.', t)]},
    \ {'kind': 'try', 'lines': [line], 'start': [1, 11], 'target': [1, 10],
    \  'enter_at_row': 1, 'enter_at_col': 11,
    \  'target_lines': [line], 'target_lines_after_type': [typed_at_11],
    \  'expected_motion': 'i', 'optimal_motions': 4,
    \  'prompt': printf('i again — cursor on the right of ▶◀. Type %s.', t)},
    \ {'kind': 'try', 'lines': [line], 'start': [1, 11], 'target': [1, 11],
    \  'enter_at_row': 1, 'enter_at_col': 12,
    \  'target_lines': [line], 'target_lines_after_type': [typed_at_12],
    \  'expected_motion': 'a', 'optimal_motions': 4,
    \  'prompt': printf('a again — cursor on the left of ▶◀. Type %s.', t)},
    \ ]
endfunction
