" move_repeat_last_till_forward — ; / , over a FORWARD till (t) only.
"
" The till sibling of move_repeat_last_find_forward. Same ;/,
" discrimination, but the setup is lowercase `t` (lands ONE CELL
" BEFORE the next char) instead of `f` (lands ON it). That off-by-one
" is the only thing added: get the find (f) version to aim first, then
" this drill layers the till landing on top.
"
"   ;  repeats the last till in the SAME direction (continue forward)
"   ,  repeats it in the OPPOSITE direction (go back, like T)
"
" Two scenarios, evenly mixed:
"
"   ;  scenario: cursor is BEFORE both occurrences of the search char.
"      t{c} lands one before the first (waypoint 1); ; continues
"      forward to one before the second (target 2).
"   ,  scenario: cursor sits BETWEEN the two occurrences. t{c} lands
"      forward one before the second (waypoint 1); , reverses (like T)
"      to one AFTER the first (target 2).
"
" The , landing is the subtle one: , repeats t in the opposite
" direction, which behaves like T — it lands on the FAR side of the
" backward match (one cell after it), not one before.
"
" cpoptions gotcha: ; / , after t/T only skip to the NEXT match when
" the vi-compat cpoptions ';' flag is OFF (its default). The runner
" strips ';' for the session (vimfluency#start / learn), so the skip
" is reliable regardless of the user's vimrc; without that, ; would
" stick in place and the item could never be credited.
"
" Geometry is CONSTANT in SHAPE (same approach as the find sibling):
" two occurrences 6 columns apart on a 15-char spaceless noise line,
" cursor a fixed offset from the pair, cluster sliding by a small
" random offset so absolute columns aren't a tell. Search char from
" the home-row keys s / d / f so t{c} is an effortless roll.
"
" Cheat-defense:
"   - spaceless single-word line → w/b/e/ge never cheaply land on an
"     interior target column
"   - targets kept interior (cols 4..11 on a 15-char line) so 0/^/$
"     never reach them
"   - search char appears EXACTLY twice (noise pool excludes s/d/f)
"   - cursor->target distance is 7 (;) or 3 (,); the t{c}+;/, pair is
"     2 motion events, beating any hjkl chain
"   - the , target is also reachable by a direct backward T{c} in 1
"     event; like the find sibling, that shortcut is accepted (the
"     runner credits motion count <= optimal 2)

let s:TARGETS = ['s', 'd', 'f']

let s:NOISE = ['a','b','c','e','g','h','i','j','k','m','n','o',
  \ 'p','q','r','t','u','v','w','x','y','z']

function! vimfluency#drills#move_repeat_last_till_forward#meta() abort
  return {'id': 'move_repeat_last_till_forward',
    \ 'name': 'repeat last till, forward (; ,)',
    \ 'aim': 38, 'allowed_keys': ';,t',
    \ 'prereqs': ['move_repeat_last_find_forward', 'move_till_char_forward_backward'],
    \ 'parallel_to': ['move_repeat_last_find_forward'], 'keys': ';/,', 'family': 'motion',
    \ 'test_sequence': [';', ',']}
endfunction

function! vimfluency#drills#move_repeat_last_till_forward#lesson() abort
  " buf1: search char 's' at cols 4 and 10. Frame 2 demos ; (cursor
  " before both → t lands p-1, ; skips to q-1). Frame 3 demos , (cursor
  " between → t lands q-1, , reverses like T to p+1). Frame 4 contrasts
  " with the find version so the off-by-one is explicit.
  let buf1 = ['kanslxqwzsmrbt']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 1],
    \  'prompt': [
    \    't{char} lands ONE CELL BEFORE the next match. ; and , repeat',
    \    'it just like they repeat f — no retyping the char:',
    \    '',
    \    '    ;  repeats forward again (one before the next match)',
    \    '    ,  reverses (like T: one AFTER the previous match)',
    \    '',
    \    'Same read as the find version — both matches ahead means ;,',
    \    'sitting between them means , — but the cursor lands beside',
    \    'the match, not on it.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 2], 'target': [1, 9],
    \  'waypoints': [[1, 3]],
    \  'prompt': 'Both s''s are ahead. Press ts (lands one before the first s, col 3 = 1), then ; (skips to one before the second s, col 9 = 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 8], 'target': [1, 5],
    \  'waypoints': [[1, 9]],
    \  'prompt': 'You sit between the s''s. Press ts (lands one before the second, col 9 = 1), then , (reverses like T — one AFTER the first s, col 5 = 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 2], 'target': [1, 9],
    \  'waypoints': [[1, 3]],
    \  'prompt': 'Again ts then ; — note you stop one short of each s. With f you''d land ON them; with t you land just before.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_repeat_last_till_forward#generate() abort
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

  if s:rand(2) == 0
    " ; scenario: cursor 2 left of the pair. t{c} -> p-1, ; -> q-1.
    let cursor_col = p - 2
    let waypoint_col = p - 1
    let target_col = q - 1
    let motion = ';'
  else
    " , scenario: cursor in the gap. t{c} -> q-1, , (like T) -> p+1.
    let cursor_col = p + 4
    let waypoint_col = q - 1
    let target_col = p + 1
    let motion = ','
  endif

  return {'lines': [join(chars, '')],
    \ 'start': [1, cursor_col], 'target': [1, target_col],
    \ 'waypoints': [[1, waypoint_col]],
    \ 'expected_motion': motion, 'optimal_motions': 2}
endfunction
