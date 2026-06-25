" move_to_line_edges_all — line start/end. Move to col 1 (`0`), first non-blank (`^`), or end (`$`).

let s:words = ['def', 'class', 'return', 'import', 'from', 'while', 'if',
  \ 'else', 'for', 'in', 'True', 'False', 'None', 'self', 'data', 'value']

function! vimfluency#drills#move_to_line_edges_all#meta() abort
  return {'id': 'move_to_line_edges_all', 'name': 'line edges, all (0 ^ $ g_)', 'aim': 50,
    \ 'allowed_keys': '0^$g_',
    \ 'prereqs': ['move_to_line_edges_start_end',
    \             'move_to_line_edges_non_white_space'],
    \ 'keys': '0/^/$/g_', 'family': 'motion',
    \ 'test_sequence': ['0', '^', '$', 'g_']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_line() abort
  let indents = [0, 2, 4, 4, 8]
  let indent = repeat(' ', indents[s:rand(len(indents))])
  let n = 3 + s:rand(5)
  let parts = []
  for _ in range(n)
    call add(parts, s:words[s:rand(len(s:words))])
  endfor
  return indent . join(parts, ' ')
endfunction

function! vimfluency#drills#move_to_line_edges_all#lesson() abort
  " Each motion is introduced via a try frame so the learner sees the
  " cursor jump from their own keystroke. Two show frames remain for
  " the genuine juxtaposition rules — when no leading/trailing
  " whitespace is present, two motions collapse to the same column;
  " observing that equivalence is the point, not a motion. Trailing
  " whitespace is rendered with `·` so $ vs g_ is observable.
  return [
    \ {'kind': 'show', 'lines': ['    if x:    '], 'cursor': [1, 5],
    \  'prompt': [
    \    'Four line-edge moves:',
    \    '',
    \    '    0    →  moves the cursor to column 1',
    \    '    ^    →  moves the cursor to the first non-blank character',
    \    '    $    →  moves the cursor to the last column (whitespace counts)',
    \    '    g_   →  moves the cursor to the last non-blank character',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try',  'lines': ['    if x:'], 'start': [1, 5], 'target': [1, 1],
    \  'expected_motion': '0', 'optimal_motions': 1,
    \  'prompt': 'Press 0 — moves the cursor to column 1.'},
    \ {'kind': 'try',  'lines': ['        return value'], 'start': [1, 1], 'target': [1, 9],
    \  'expected_motion': '^', 'optimal_motions': 1,
    \  'prompt': 'Press ^ — moves the cursor to the first non-blank character.'},
    \ {'kind': 'try',  'lines': ['    if x:    '], 'start': [1, 5], 'target': [1, 13],
    \  'expected_motion': '$', 'optimal_motions': 1,
    \  'prompt': 'Press $ — moves the cursor to the last column (whitespace counts).'},
    \ {'kind': 'try',  'lines': ['    if x:    '], 'start': [1, 5], 'target': [1, 9],
    \  'expected_motion': 'g_', 'optimal_motions': 1,
    \  'prompt': 'Press g_ — moves the cursor to the last non-blank character.'},
    \ {'kind': 'show', 'lines': ['if x:'], 'cursor': [1, 1],
    \  'prompt': 'No leading whitespace → 0 and ^ would land on the same column.'},
    \ {'kind': 'show', 'lines': ['if x:'], 'cursor': [1, 5],
    \  'prompt': 'No trailing whitespace → $ and g_ would land on the same column.'},
    \ {'kind': 'try',  'lines': ['        if data:'], 'start': [1, 14], 'target': [1, 9],
    \  'expected_motion': '^', 'optimal_motions': 1,
    \  'prompt': 'Press ^ — moves the cursor to the first non-blank, even starting past it.'},
    \ ]
endfunction

function! vimfluency#drills#move_to_line_edges_all#generate() abort
  let line = s:make_line()
  " 50% of items get trailing whitespace so g_ and $ are distinct.
  " (When trailing ws is absent, last_nonblank == last_char and the
  " dedup below collapses them, so the item still tests $ or g_ — just
  " not their *distinction*.)
  if s:rand(2) == 0
    let line .= repeat(' ', 1 + s:rand(4))
  endif
  let llen = len(line)
  let scol = 1 + s:rand(llen)

  let stripped_left = substitute(line, '^\s\+', '', '')
  let first_nonblank = empty(stripped_left) ? 1 : (llen - len(stripped_left) + 1)

  let stripped_right = substitute(line, '\s\+$', '', '')
  let last_nonblank = empty(stripped_right) ? llen : len(stripped_right)

  let candidates = []
  for c in [1, first_nonblank, last_nonblank, llen]
    if c != scol && index(candidates, c) == -1
      call add(candidates, c)
    endif
  endfor
  let target_col = candidates[s:rand(len(candidates))]

  " Canonical motion: shortest single keystroke that reaches the target.
  " Order matters when positions collide (e.g. no leading ws → 0 wins).
  if target_col == 1
    let motion = '0'
  elseif target_col == first_nonblank
    let motion = '^'
  elseif target_col == last_nonblank && last_nonblank < llen
    let motion = 'g_'
  elseif target_col == llen
    let motion = '$'
  else
    let motion = '?'
  endif

  return {'lines': [line], 'start': [1, scol], 'target': [1, target_col],
    \ 'expected_motion': motion, 'optimal_motions': 1}
endfunction
