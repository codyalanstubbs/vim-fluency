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
" Cheat-defense:
"   - Single line of plain words. Cursor placed on the deletion
"     target (on the char for x, anywhere on the line for dd) so
"     each motion is a single event; no navigation noise inflates
"     the per-motion timing.
"   - The probe's highlight is the cue: whole line → dd; single
"     char → x. The cursor sits on the target either way, so the
"     learner can't shortcut by reading cursor position alone — they
"     have to look at the deletion range.
"   - dl is event-equivalent to x. The runner credits success on
"     buffer match regardless, but learners almost always use x in
"     practice; per-motion stats get attributed to x correctly in
"     the typical case.

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

function! vimfluency#pinpoints#p2_1#generate() abort
  let line = s:make_line()
  let line_len = len(line)
  let pick_dd = s:rand(2) == 0

  if pick_dd
    " dd item: cursor anywhere on the line, highlight is the entire
    " line. After dd on a 1-line buffer the line goes empty and the
    " cursor lands at col 1.
    let cursor_col = 1 + s:rand(line_len)
    return {
      \ 'lines': [line],
      \ 'target_lines': [''],
      \ 'start': [1, cursor_col],
      \ 'target': [1, 1],
      \ 'deletion_range': [[1, 1, line_len]],
      \ 'expected_motion': 'dd',
      \ 'optimal_motions': 1,
      \ 'prompt': 'Delete the highlighted region.',
      \ }
  else
    " x item: cursor sits on the char to delete; highlight covers
    " just that one char. After x, vim leaves the cursor at the
    " same column unless the deleted char was the line's last —
    " then the cursor falls back to col-1.
    let target_col = 1 + s:rand(line_len)
    let target_line = strpart(line, 0, target_col - 1)
      \ . strpart(line, target_col)
    let cursor_after = target_col == line_len
      \ ? target_col - 1 : target_col
    return {
      \ 'lines': [line],
      \ 'target_lines': [target_line],
      \ 'start': [1, target_col],
      \ 'target': [1, cursor_after],
      \ 'deletion_range': [[1, target_col, 1]],
      \ 'expected_motion': 'x',
      \ 'optimal_motions': 1,
      \ 'prompt': 'Delete the highlighted region.',
      \ }
  endif
endfunction

function! vimfluency#pinpoints#p2_1#lesson() abort
  " Each operator gets its own try frame so the learner performs
  " the deletion and watches the buffer change. The closing show
  " frame names the discrimination rule. The auto-test phase that
  " follows the lesson generates novel items mixing both — that's
  " where the read-and-pick gets exercised cold.
  let buf = ['alpha beta gamma']
  let line_len = len(buf[0])
  return [
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 1],
    \  'target_lines': ['lpha beta gamma'],
    \  'deletion_range': [[1, 1, 1]],
    \  'prompt': 'Press x — deletes the single character under the cursor.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 5], 'target': [1, 1],
    \  'target_lines': [''],
    \  'deletion_range': [[1, 1, line_len]],
    \  'prompt': 'Press dd — deletes the entire line, regardless of where the cursor sits on it.'},
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 1],
    \  'prompt': 'x removes one character; dd removes the whole line. The probe''s highlight tells you which to use — single char or whole line.'},
    \ ]
endfunction
