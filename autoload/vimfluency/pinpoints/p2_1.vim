" 2.1 — Discriminate x vs dd. Single-char delete vs linewise delete,
" both immediate-action (no motion partner). The minimal pair is on
" the amount-to-delete axis: one character vs an entire line. Both
" are foundational delete operations; the discrimination is the
" most common confusion when learners first meet vim's operator
" model.
"
" Tier 2 design note: this departs from the catalog's original 2.1
" (dd alone). Pure-fluency single-response probes don't have a
" cognitive task — the learner just smashes the same key. Pairing
" dd with x gives a real read-and-pick that fits the
" minimal-pair-pinpoint principle while staying inside tier 2's
" "operator without a motion" frame. CATALOG.md updated.
"
" Buffer shape note: items use a 2-line buffer, not 1-line. dd in a
" 1-line buffer leaves vim's minimum '' (works in standalone probes
" where the content is the only buffer line); but in the lesson
" buffer the content sits below header rows, and dd of the only
" content line removes it entirely — the content area goes empty
" and the runner's getline(header_offset+1,'$') returns []. A
" 2-line buffer survives dd in either context: vim removes the
" target line, the other survives, the cursor lands on the
" surviving line, and target_lines stays a non-empty list.
"
" Cheat-defense:
"   - Single-line content per item, but two such lines in the
"     buffer. Cursor on the target line.
"   - For x: cursor sits on the char to delete; one event.
"   - For dd: cursor anywhere on the target line; one event.
"   - The probe's highlight is the cue: whole line → dd; single
"     char → x. Cursor on the target line either way; the learner
"     can't shortcut by reading cursor position alone.
"   - dl is event-equivalent to x. The runner credits success on
"     buffer match regardless; per-motion stats get attributed to
"     x in the typical case.

let s:words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon',
  \ 'zeta', 'eta', 'theta', 'iota', 'kappa']

function! vimfluency#pinpoints#p2_1#meta() abort
  " Discrimination probes carry a cognitive cost beyond fluency
  " probes (read the highlight, pick the operator), so the aim is
  " set lower than 1A.1's hjkl drill. Starting guess; revise on
  " data. Same band as the 1C.4 disc probe (35).
  return {'id': '2.1', 'name': 'discriminate x vs dd',
    \ 'aim': 40, 'allowed_keys': 'xd', 'kind': 'editing',
    \ 'prereqs': ['T0']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_line() abort
  let n = 2 + s:rand(2)  " 2 or 3 words
  let words = []
  for _ in range(n)
    call add(words, s:words[s:rand(len(s:words))])
  endfor
  return join(words, ' ')
endfunction

function! s:make_distinct_lines() abort
  let a = s:make_line()
  let b = s:make_line()
  while b ==# a
    let b = s:make_line()
  endwhile
  return [a, b]
endfunction

function! vimfluency#pinpoints#p2_1#generate() abort
  let lines = s:make_distinct_lines()
  let K = 1 + s:rand(2)  " target line index (1 or 2)
  let target_line = lines[K - 1]
  let target_len = len(target_line)
  let pick_dd = s:rand(2) == 0

  if pick_dd
    " dd item: cursor anywhere on line K; highlight covers all of
    " line K. After dd, line K is removed, the other line survives
    " and becomes the buffer's only content row, cursor lands at
    " col 1 of that surviving line.
    let cursor_col = 1 + s:rand(target_len)
    let surviving = lines[K == 1 ? 1 : 0]
    return {
      \ 'lines': lines,
      \ 'target_lines': [surviving],
      \ 'start': [K, cursor_col],
      \ 'target': [1, 1],
      \ 'deletion_range': [[K, 1, target_len]],
      \ 'expected_motion': 'dd',
      \ 'optimal_motions': 1,
      \ 'prompt': 'Delete the highlighted region.',
      \ }
  else
    " x item: cursor on the char to delete in line K. Other line
    " is unchanged. After x, vim leaves the cursor at the same
    " column unless the deleted char was last on the line — then
    " the cursor falls back to col-1.
    let target_col = 1 + s:rand(target_len)
    let new_line = strpart(target_line, 0, target_col - 1)
      \ . strpart(target_line, target_col)
    let cursor_after = target_col == target_len
      \ ? target_col - 1 : target_col
    let new_lines = K == 1 ? [new_line, lines[1]] : [lines[0], new_line]
    return {
      \ 'lines': lines,
      \ 'target_lines': new_lines,
      \ 'start': [K, target_col],
      \ 'target': [K, cursor_after],
      \ 'deletion_range': [[K, target_col, 1]],
      \ 'expected_motion': 'x',
      \ 'optimal_motions': 1,
      \ 'prompt': 'Delete the highlighted region.',
      \ }
  endif
endfunction

function! vimfluency#pinpoints#p2_1#lesson() abort
  " Each operator gets its own try frame so the learner performs
  " the deletion and watches the buffer change. Two-line content
  " for the same reason the generator uses two lines: dd needs a
  " survivor line in the lesson buffer so the runner's
  " target_lines check can match a non-empty list.
  let buf = ['alpha beta gamma', 'delta epsilon zeta']
  let after_x = ['lpha beta gamma', 'delta epsilon zeta']
  let after_dd = ['delta epsilon zeta']
  return [
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 1],
    \  'target_lines': after_x,
    \  'deletion_range': [[1, 1, 1]],
    \  'prompt': 'Press x — deletes the single character under the cursor.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 5], 'target': [1, 1],
    \  'target_lines': after_dd,
    \  'deletion_range': [[1, 1, len(buf[0])]],
    \  'prompt': 'Press dd — deletes the entire line, regardless of where the cursor sits on it.'},
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 1],
    \  'prompt': 'x removes one character; dd removes the whole line. The probe''s highlight tells you which to use — single char or whole line.'},
    \ ]
endfunction
