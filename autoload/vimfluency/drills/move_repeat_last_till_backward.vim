" move_repeat_last_till_backward — ; / , over a BACKWARD till (T) only.
"
" The backward mirror of move_repeat_last_till_forward. Setup is
" uppercase `T` (search backward, land ONE CELL AFTER the previous
" match). Adds the Shift key and the backward direction on top of the
" till off-by-one — get the forward till (t) version to aim first.
"
"   ;  repeats the last till in the SAME direction (continue backward)
"   ,  repeats it in the OPPOSITE direction (forward, like t)
"
" Two scenarios, evenly mixed:
"
"   ;  scenario: cursor is AFTER both occurrences of the search char.
"      T{c} lands one after the nearest (second) match (waypoint 1); ;
"      continues backward to one after the first match (target 2).
"   ,  scenario: cursor sits BETWEEN the two occurrences. T{c} lands
"      one after the first match (waypoint 1); , reverses (like t)
"      to one BEFORE the second match (target 2).
"
" The , landing mirrors the forward drill's: , repeats T in the
" opposite direction, behaving like t — it lands one cell BEFORE the
" forward match.
"
" cpoptions gotcha (same as the forward till drill): ; / , after t/T
" only skip to the next match with the vi-compat cpoptions ';' flag
" OFF. The runner strips ';' for the session, so the skip is reliable
" regardless of the user's vimrc.
"
" Geometry is CONSTANT in SHAPE: two occurrences 6 columns apart on a
" 15-char spaceless noise line, cursor a fixed offset from the pair,
" cluster sliding by a small random offset. Search char from the
" home-row keys s / d / f.
"
" Cheat-defense:
"   - spaceless single-word line → w/b/e/ge never cheaply land on an
"     interior target column
"   - targets kept interior (cols 4..11 on a 15-char line) so 0/^/$
"     never reach them
"   - search char appears EXACTLY twice (noise pool excludes s/d/f)
"   - cursor->target distance is 7 (;) or 3 (,); the T{c}+;/, pair is
"     2 motion events, beating any hjkl chain
"   - the , target is also reachable by a direct forward t{c} in 1
"     event; like the other repeat drills, that shortcut is accepted
"     (the runner credits motion count <= optimal 2)

let s:TARGETS = ['s', 'd', 'f']

let s:NOISE = ['a','b','c','e','g','h','i','j','k','m','n','o',
  \ 'p','q','r','t','u','v','w','x','y','z']

function! vimfluency#drills#move_repeat_last_till_backward#meta() abort
  return {'id': 'move_repeat_last_till_backward',
    \ 'name': 'repeat last till, backward (; ,)',
    \ 'aim': 35, 'allowed_keys': ';,T',
    \ 'prereqs': ['move_repeat_last_till_forward', 'move_till_char_forward_backward'],
    \ 'parallel_to': ['move_repeat_last_till_forward'], 'keys': ';/,', 'family': 'motion',
    \ 'test_sequence': [';', ',']}
endfunction

function! vimfluency#drills#move_repeat_last_till_backward#lesson() abort
  " buf1: search char 's' at cols 4 and 10. Frame 2 demos ; (cursor
  " after both, col 12 → T lands 11, ; skips to 5). Frame 3 demos ,
  " (cursor between, col 6 → T lands 5, , reverses like t to 9).
  let buf1 = ['kanslxqwzsmrbt']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 14],
    \  'prompt': [
    \    'T{char} searches BACKWARD and lands ONE CELL AFTER the previous',
    \    'match. ; and , repeat it — no retyping the char:',
    \    '',
    \    '    ;  repeats backward again (one after the previous match)',
    \    '    ,  reverses (like t: one BEFORE the forward match)',
    \    '',
    \    'You sit to the right of both matches → ; walks them backward;',
    \    'sitting between them → , goes forward instead.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 5],
    \  'waypoints': [[1, 11]],
    \  'prompt': 'Both s''s are behind you. Press Ts (lands one after the nearer s, 1), then ; (skips back to one after the first s, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 6], 'target': [1, 9],
    \  'waypoints': [[1, 5]],
    \  'prompt': 'You sit between the s''s. Press Ts (lands one after the first, 1), then , (reverses like t — one BEFORE the second s, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 5],
    \  'waypoints': [[1, 11]],
    \  'prompt': 'Again Ts then ; — T lands just past each match going back, the mirror of t going forward.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_repeat_last_till_backward#generate() abort
  let llen = 15
  let target = s:TARGETS[s:rand(len(s:TARGETS))]
  " First occurrence p in {3,4,5,6}; second q = p + 6 in {9..12}.
  let p = 3 + s:rand(4)
  let q = p + 6

  let chars = []
  for _ in range(llen)
    call add(chars, s:NOISE[s:rand(len(s:NOISE))])
  endfor
  let chars[p - 1] = target
  let chars[q - 1] = target
  let line = join(chars, '')

  if s:rand(2) == 0
    " ; scenario: cursor 2 right of the pair. T{c} -> q+1, ; -> p+1.
    let cursor_col = q + 2
    let waypoint_col = q + 1
    let target_col = p + 1
    let motion = ';'
    " Strip any single-motion shortcut to the target (see repeatfind).
    let line = vimfluency#repeatfind#decheat(line, cursor_col, target_col, waypoint_col, target)
  else
    " , scenario: cursor in the gap. T{c} -> p+1, , (like t) -> q-1.
    let cursor_col = p + 2
    let waypoint_col = p + 1
    let target_col = q - 1
    let motion = ','
  endif

  return {'lines': [line],
    \ 'start': [1, cursor_col], 'target': [1, target_col],
    \ 'waypoints': [[1, waypoint_col]],
    \ 'expected_motion': motion, 'optimal_motions': 2}
endfunction
