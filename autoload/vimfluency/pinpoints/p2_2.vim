" 2.2 — Discriminate >> vs <<. Indent vs dedent the cursor's line.
" Real direction discrimination on the indentation axis. Both
" doubled-key operators, both produce visible buffer changes (whole
" line shifts left or right by one shiftwidth), neither enters
" insert mode. Mirrors 1B.1's forward/backward direction pair at the
" operator layer.
"
" Probe design: 2-line buffer where line 1 is the line to modify and
" line 2 is a reference at the target indent. Same content on both
" lines so the only visible difference is indent depth. The user
" compares line 1's indent to line 2's, picks the operator that
" closes the gap.
"
" The runner sets shiftwidth=4 expandtab on probe/lesson buffers
" (autoload/vimfluency.vim's setup hooks) so each item is exactly
" one shiftwidth's worth of difference and the user's vimrc doesn't
" change probe behavior.
"
" Cheat-defense:
"   - Items only ever differ by exactly one shiftwidth, so >> or <<
"     once is the canonical 1-event answer.
"   - Alternatives (i + spaces + Esc, :s/^/    /, V then >) all take
"     more events; the runner's motion-event count makes them less
"     efficient.
"   - Cursor on line 1 means a misfire >> on line 2 (after a k) is
"     two events and produces wrong target_lines, so the runner
"     won't credit it.

let s:words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon',
  \ 'zeta', 'eta', 'theta', 'iota', 'kappa']

function! vimfluency#pinpoints#p2_2#meta() abort
  " Disc-band aim, matching 1C.4 and 2.1. Read-and-pick costs more
  " than pure motor; revise on data.
  return {'id': '2.2', 'name': 'discriminate >> vs <<',
    \ 'aim': 35, 'allowed_keys': '><', 'kind': 'editing',
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

function! vimfluency#pinpoints#p2_2#generate() abort
  let SW = 4
  let text = s:make_line()
  let pick_indent = s:rand(2) == 0  " true → >>, false → <<

  " Pick a base indent in {0, 4} so neither line ends up with crazy
  " whitespace, and pair it so line 1 and line 2 differ by exactly
  " one shiftwidth in the chosen direction.
  let base = SW * s:rand(2)
  if pick_indent
    let l1_indent = base
    let l2_indent = base + SW
  else
    let l1_indent = base + SW
    let l2_indent = base
  endif

  let l1 = repeat(' ', l1_indent) . text
  let l2 = repeat(' ', l2_indent) . text
  let new_l1 = repeat(' ', l2_indent) . text

  " Cursor on line 1 at first non-blank. After >> or <<, vim places
  " the cursor at first non-blank of the modified line.
  let start_col = l1_indent + 1
  let target_col = l2_indent + 1

  return {
    \ 'lines': [l1, l2],
    \ 'target_lines': [new_l1, l2],
    \ 'start': [1, start_col],
    \ 'target': [1, target_col],
    \ 'expected_motion': pick_indent ? '>>' : '<<',
    \ 'optimal_motions': 1,
    \ 'prompt': 'Match the indent of line 2 (the reference). Cursor is on line 1.',
    \ }
endfunction

function! vimfluency#pinpoints#p2_2#lesson() abort
  " Try frames in both directions, then a rule-statement show frame.
  " The lesson teaches the 2-line "match the reference" convention
  " that the probe will reuse — line 1 is the active line, line 2
  " is the indent target.
  let buf_indent = ['    alpha beta', '        alpha beta']
  let buf_dedent = ['        alpha beta', '    alpha beta']
  let after_indent = ['        alpha beta', '        alpha beta']
  let after_dedent = ['    alpha beta', '    alpha beta']
  return [
    \ {'kind': 'try', 'lines': buf_indent,
    \  'start': [1, 5], 'target': [1, 9],
    \  'target_lines': after_indent,
    \  'prompt': 'Press >> — indents the cursor''s line by one shiftwidth (4 spaces). Match line 2.'},
    \ {'kind': 'try', 'lines': buf_dedent,
    \  'start': [1, 9], 'target': [1, 5],
    \  'target_lines': after_dedent,
    \  'prompt': 'Press << — dedents the cursor''s line by one shiftwidth. Match line 2.'},
    \ {'kind': 'show', 'lines': buf_indent, 'cursor': [1, 5],
    \  'prompt': '>> indents the cursor''s line; << dedents it. Compare to the reference (line 2) and pick the direction that closes the gap.'},
    \ ]
endfunction
