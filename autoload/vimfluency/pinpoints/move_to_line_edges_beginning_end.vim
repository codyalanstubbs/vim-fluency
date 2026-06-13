" move_to_line_edges_beginning_end — 0 vs $. Narrower 2-cell sibling of move_to_line_edges_all (line start/end
" bundle). Shared quality: line-edge motion. Juxtaposed quality:
" direction (line-start vs line-end). Drops the whitespace-
" sensitivity axis (^ and g_) so the only thing the learner
" discriminates is which edge.
"
" Design constraints:
"   - single line; no leading or trailing whitespace, so the
"     whitespace-sensitivity axis can't surface here
"   - cursor starts in the interior (col ≥ 3 and ≤ len - 2) so
"     neither 0 nor $ is a no-op for any item
"   - target ∈ {1, line-len} — the two edges, randomly chosen

let s:words = ['def', 'class', 'return', 'import', 'from', 'while',
  \ 'if', 'else', 'for', 'in', 'True', 'False', 'None', 'self',
  \ 'data', 'value']

function! vimfluency#pinpoints#move_to_line_edges_beginning_end#meta() abort
  " Aim slightly above move_to_line_edges_all's 50/min — narrower discrimination,
  " no whitespace axis to read. Starting guess.
  return {'id': 'move_to_line_edges_beginning_end', 'name': 'line edges (0 / $)', 'aim': 55,
    \ 'allowed_keys': '0$', 'prereqs': [],
    \ 'narrower_of': 'move_to_line_edges_all',
    \ 'parallel_to': ['move_to_line_edges_non_white_space'],
    \ 'keys': '0/$', 'family': 'motion',
    \ 'test_sequence': ['0', '$']}
endfunction

function! vimfluency#pinpoints#move_to_line_edges_beginning_end#lesson() abort
  return [
    \ {'kind': 'show', 'lines': ['if data: return value'], 'cursor': [1, 10],
    \  'prompt': '0 sends cursor to column 1; $ sends cursor to the last column. They differ only by direction.'},
    \ {'kind': 'try', 'lines': ['if data: return value'], 'start': [1, 10], 'target': [1, 1],
    \  'prompt': 'Press 0 — sends cursor to column 1.'},
    \ {'kind': 'try', 'lines': ['if data: return value'], 'start': [1, 10], 'target': [1, 21],
    \  'prompt': 'Press $ — sends cursor to the last column.'},
    \ {'kind': 'try', 'lines': ['class Foo: pass'], 'start': [1, 7], 'target': [1, 1],
    \  'prompt': 'Press 0.'},
    \ {'kind': 'try', 'lines': ['class Foo: pass'], 'start': [1, 7], 'target': [1, 15],
    \  'prompt': 'Press $.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_line() abort
  let n = 3 + s:rand(5)
  let parts = []
  for _ in range(n)
    call add(parts, s:words[s:rand(len(s:words))])
  endfor
  return join(parts, ' ')
endfunction

function! vimfluency#pinpoints#move_to_line_edges_beginning_end#generate() abort
  let line = s:make_line()
  let llen = len(line)
  " cursor in interior — at least 2 cols from each edge so neither
  " 0 nor $ is a no-op
  let scol = 3 + s:rand(llen - 4)

  " 50/50 direction
  let go_start = s:rand(2) == 0
  let target_col = go_start ? 1 : llen
  let motion = go_start ? '0' : '$'

  return {'lines': [line], 'start': [1, scol], 'target': [1, target_col],
    \ 'expected_motion': motion, 'optimal_motions': 1}
endfunction
