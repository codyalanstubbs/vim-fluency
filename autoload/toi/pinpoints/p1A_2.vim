" 1A.2 — line start/end. Move to col 1 (`0`), first non-blank (`^`), or end (`$`).

let s:words = ['def', 'class', 'return', 'import', 'from', 'while', 'if',
  \ 'else', 'for', 'in', 'True', 'False', 'None', 'self', 'data', 'value']

function! toi#pinpoints#p1A_2#meta() abort
  return {'id': '1A.2', 'name': 'line start/end (0 ^ $ g_)', 'aim': 50, 'allowed_keys': '0^$g_'}
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

function! toi#pinpoints#p1A_2#lesson() abort
  " DI-style sequence: parallel rule statements (one keystroke + one
  " destination per frame), juxtaposition frames showing when pairs
  " collapse, then 'try it' frames covering each motion at least once.
  " Trailing whitespace is rendered with `·` so the $ vs g_ distinction
  " is observable.
  return [
    \ {'kind': 'show', 'lines': ['    if x:'], 'cursor': [1, 1],
    \  'prompt': '0 sends cursor to column 1.'},
    \ {'kind': 'show', 'lines': ['    if x:'], 'cursor': [1, 5],
    \  'prompt': '^ sends cursor to the first non-blank character.'},
    \ {'kind': 'show', 'lines': ['    if x:    '], 'cursor': [1, 13],
    \  'prompt': '$ sends cursor to the last character (whitespace counts).'},
    \ {'kind': 'show', 'lines': ['    if x:    '], 'cursor': [1, 9],
    \  'prompt': 'g_ sends cursor to the last non-blank character.'},
    \ {'kind': 'show', 'lines': ['if x:'], 'cursor': [1, 1],
    \  'prompt': 'No leading whitespace → 0 and ^ are the same column.'},
    \ {'kind': 'show', 'lines': ['if x:'], 'cursor': [1, 5],
    \  'prompt': 'No trailing whitespace → $ and g_ are the same column.'},
    \ {'kind': 'try',  'lines': ['        return value'], 'start': [1, 1], 'target': [1, 9],
    \  'prompt': 'Use ^ to skip the indent.'},
    \ {'kind': 'try',  'lines': ['    name = data'], 'start': [1, 5], 'target': [1, 1],
    \  'prompt': 'Use 0 to reach column 1.'},
    \ {'kind': 'try',  'lines': ['    return result    '], 'start': [1, 5], 'target': [1, 17],
    \  'prompt': 'Use g_ to skip trailing whitespace.'},
    \ {'kind': 'try',  'lines': ['    return result    '], 'start': [1, 5], 'target': [1, 21],
    \  'prompt': 'Use $ to land on the trailing whitespace.'},
    \ {'kind': 'try',  'lines': ['        if data:'], 'start': [1, 14], 'target': [1, 9],
    \  'prompt': '^ works even when you start past the first non-blank.'},
    \ ]
endfunction

function! toi#pinpoints#p1A_2#generate() abort
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
