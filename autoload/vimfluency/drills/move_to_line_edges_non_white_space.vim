" move_to_line_edges_non_white_space — atomic 2-cell drill over
" the non-blank line-edge motions. Parallel-by-design with
" move_to_line_edges_start_end (0 / $).
"
"   ^   → first NON-BLANK char on the line (skips leading whitespace)
"   g_  → last NON-BLANK char on the line  (skips trailing whitespace)
"
" Both motions are line-edge motions like 0 / $ but bias toward
" code-style "real content" boundaries. The discriminator is which
" non-blank edge to head for.
"
" Design constraints:
"   - line has BOTH leading and trailing whitespace, so ^ ≠ 0 and
"     g_ ≠ $; the whitespace-sensitivity axis is the whole point.
"   - trailing whitespace is visible in the runner via the
"     listchars=trail:· setting on mode-kind buffers — the cue is
"     observable, not silent.
"   - cursor starts in the interior (between first_nonblank and
"     last_nonblank + 1) so neither motion is a no-op.
"   - target ∈ {first_nonblank, last_nonblank}, picked 50/50.

let s:words = ['def', 'class', 'return', 'import', 'from', 'while',
  \ 'if', 'else', 'for', 'in', 'True', 'False', 'None', 'self',
  \ 'data', 'value']

function! vimfluency#drills#move_to_line_edges_non_white_space#meta() abort
  " Aim 55/min, same as move_to_line_edges_start_end. Narrower
  " 2-cell discrimination, single keystroke per item (g_ is 2
  " physical keys but the runner credits it as one motion since the
  " behavior is atomic — see the canonical-motion convention in
  " move_to_line_edges_all).
  return {'id': 'move_to_line_edges_non_white_space',
    \ 'name': 'non-blank line edges (^ / g_)',
    \ 'aim': 50, 'allowed_keys': '^g_', 'prereqs': [],
    \ 'keys': '^/g_', 'family': 'motion',
    \ 'test_sequence': ['^', 'g_']}
endfunction

function! vimfluency#drills#move_to_line_edges_non_white_space#lesson() abort
  let buf = ['    if data: return    ']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 10],
    \  'prompt': [
    \    'Two non-blank line-edge moves:',
    \    '',
    \    '    ^    →  moves the cursor to the first non-blank character',
    \    '    g_   →  moves the cursor to the last non-blank character',
    \    '',
    \    'Both skip whitespace; trailing whitespace shows as · so g_ vs $ is visible.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 5],
    \  'expected_motion': '^', 'optimal_motions': 1,
    \  'prompt': 'Press ^ — moves the cursor to the first non-blank (the i of "if").'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 19],
    \  'expected_motion': 'g_', 'optimal_motions': 1,
    \  'prompt': 'Press g_ — moves the cursor to the last non-blank (the n of "return").'},
    \ {'kind': 'try', 'lines': ['  class Foo:   '], 'start': [1, 6], 'target': [1, 3],
    \  'expected_motion': '^', 'optimal_motions': 1,
    \  'prompt': 'Press ^.'},
    \ {'kind': 'try', 'lines': ['  class Foo:   '], 'start': [1, 6], 'target': [1, 12],
    \  'expected_motion': 'g_', 'optimal_motions': 1,
    \  'prompt': 'Press g_.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_line() abort
  let indents = [2, 4, 4, 8]
  let indent = repeat(' ', indents[s:rand(len(indents))])
  let n = 3 + s:rand(4)
  let parts = []
  for _ in range(n)
    call add(parts, s:words[s:rand(len(s:words))])
  endfor
  " Always trailing whitespace — that's the whole point.
  let trail = repeat(' ', 1 + s:rand(4))
  return indent . join(parts, ' ') . trail
endfunction

function! vimfluency#drills#move_to_line_edges_non_white_space#generate() abort
  let line = s:make_line()
  let llen = len(line)
  let stripped_left = substitute(line, '^\s\+', '', '')
  let first_nonblank = llen - len(stripped_left) + 1
  let stripped_right = substitute(line, '\s\+$', '', '')
  let last_nonblank = len(stripped_right)

  " Cursor in interior — strictly between fnb and lnb so neither
  " ^ nor g_ is a no-op.
  let lo = first_nonblank + 1
  let hi = last_nonblank - 1
  if hi < lo
    " Fallback: pick a deterministic interior col on a known good line.
    let line = '    return value    '
    let llen = len(line)
    let first_nonblank = 5
    let last_nonblank = 16
    let lo = 6
    let hi = 15
  endif
  let scol = lo + s:rand(hi - lo + 1)

  let go_start = s:rand(2) == 0
  let target_col = go_start ? first_nonblank : last_nonblank
  let motion = go_start ? '^' : 'g_'

  return {'lines': [line], 'start': [1, scol], 'target': [1, target_col],
    \ 'expected_motion': motion, 'optimal_motions': 1}
endfunction
