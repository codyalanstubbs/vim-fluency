" delete_char_vs_line — Discriminate x vs dd. Single-char delete vs linewise delete,
" both immediate-action (no motion partner). The minimal pair is on
" the amount-to-delete axis: one character vs an entire line. Both
" are foundational delete operations; the discrimination is the
" most common confusion when learners first meet vim's operator
" model.
"
" Tier 2 design note: this departs from the catalog's original delete_char_vs_line
" (dd alone). Pure-fluency single-response training sessions don't have a
" cognitive task — the learner just smashes the same key. Pairing
" dd with x gives a real read-and-pick that fits the
" minimal-pair-pinpoint principle while staying inside tier 2's
" "operator without a motion" frame.
"
" Training design: 2-line buffer where the cursor sits on one line
" (always col 1) and the highlight is on the OTHER line — either a
" single char (col 1) or the whole line. The learner reads the
" highlight, moves one line up or down (j or k), and then presses
" the matching operator.
"
" The j/k step is intentional friction:
"   - The cursor and highlight sit on different lines, so the
"     cursor block can't obscure the highlight (the failure mode
"     we hit in the v1 design and in 4.d's degenerate green cell).
"   - The 1-line movement is irrelevant to the operator
"     discrimination but facilitates clear visual juxtaposition
"     between the two cases (whole-line red vs single-char red).
"   - It mirrors how a real edit happens: navigate first, then
"     operate.
"
" Per-motion accounting: expected_motion is the operator (x or dd)
" alone. The j/k navigation is folded into the operator's
" per-motion rate as overhead — a small inflation of the timing
" stat in exchange for a much clearer training. Acceptable tradeoff.
"
" Cheat-defense:
"   - For x items the highlight is always at col 1 of the target
"     line, so j/k (which preserves column) lands the cursor on the
"     highlighted char in one event. No extra navigation needed; x
"     is then 1 event. Total: 2.
"   - For dd items the cursor's column doesn't matter on the
"     target line — j/k + dd is 2 events. dd applies linewise.
"   - Alternative paths (V on target line then d, : commands, etc.)
"     all take more events; the runner's motion-event count makes
"     them less efficient.
"   - dl is event-equivalent to x on a single char. Buffer-state
"     match credits success regardless; per-motion stats get
"     attributed to x in the typical case.

let s:words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon',
  \ 'zeta', 'eta', 'theta', 'iota', 'kappa']

function! vimfluency#pinpoints#delete_char_vs_line#meta() abort
  " Discrimination training sessions carry a cognitive cost beyond fluency
  " training sessions (read the highlight, navigate, pick the operator), so
  " the aim is set lower than move_single_char_up_down_left_right's hjkl drill. Starting guess;
  " revise on data. Same band as move_to_till_forward_backward and indent_vs_dedent disc training sessions.
  return {'id': 'delete_char_vs_line', 'name': 'delete char vs line (x / dd)',
    \ 'aim': 35, 'allowed_keys': 'xdjk', 'kind': 'editing',
    \ 'prereqs': [], 'keys': 'x/dd', 'family': 'delete',
    \ 'test_sequence': ['x', 'dd']}
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

function! vimfluency#pinpoints#delete_char_vs_line#generate() abort
  let lines = s:make_distinct_lines()
  let cursor_line = 1 + s:rand(2)        " 1 or 2 — where cursor starts
  let target_line = cursor_line == 1 ? 2 : 1
  let target_text = lines[target_line - 1]
  let target_len = len(target_text)
  let pick_dd = s:rand(2) == 0

  if pick_dd
    " dd item: highlight covers the whole target line. After j/k +
    " dd, the target line is removed and only the cursor's original
    " line survives as the only buffer row, cursor at line 1 col 1.
    let surviving = lines[cursor_line - 1]
    return {
      \ 'lines': lines,
      \ 'target_lines': [surviving],
      \ 'start': [cursor_line, 1],
      \ 'target': [1, 1],
      \ 'deletion_range': [[target_line, 1, target_len]],
      \ 'expected_motion': 'dd',
      \ 'optimal_motions': 2,
      \ 'prompt': 'Delete the highlighted region.',
      \ }
  else
    " x item: highlight is a single char at col 1 of the target
    " line. j/k preserves column, so cursor lands directly on the
    " highlighted char. After x, the target line is one char
    " shorter, the other line is unchanged, cursor stays at col 1
    " of the target line.
    let new_target_text = strpart(target_text, 1)
    let new_lines = cursor_line == 1
      \ ? [lines[0], new_target_text]
      \ : [new_target_text, lines[1]]
    return {
      \ 'lines': lines,
      \ 'target_lines': new_lines,
      \ 'start': [cursor_line, 1],
      \ 'target': [target_line, 1],
      \ 'deletion_range': [[target_line, 1, 1]],
      \ 'expected_motion': 'x',
      \ 'optimal_motions': 2,
      \ 'prompt': 'Delete the highlighted region.',
      \ }
  endif
endfunction

function! vimfluency#pinpoints#delete_char_vs_line#lesson() abort
  " Each operator gets its own try frame so the learner performs
  " the navigation + deletion sequence and watches the buffer
  " change. The closing show frame names the discrimination rule
  " — both the navigation step (j/k) and the operator pick (x/dd).
  let buf = ['alpha beta gamma', 'delta epsilon zeta']
  return [
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [2, 1],
    \  'target_lines': ['alpha beta gamma', 'elta epsilon zeta'],
    \  'deletion_range': [[2, 1, 1]],
    \  'prompt': 'Move down (j) to line 2, then press x to delete the highlighted character.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 1],
    \  'target_lines': ['alpha beta gamma'],
    \  'deletion_range': [[2, 1, len(buf[1])]],
    \  'prompt': 'Move down (j) to line 2, then press dd to delete the entire line.'},
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 1],
    \  'prompt': 'x removes one character; dd removes the whole line. Move to the highlighted line (j or k), then read the highlight — single char vs whole line — to pick the operator.'},
    \ ]
endfunction
