" move_repeat_last_find_backward — ; / , over a BACKWARD find (F) only.
"
" The backward mirror of move_repeat_last_find_forward. Setup is
" uppercase `F` (search backward, land ON the previous match). Adds
" the Shift key and backward direction; the find lands-on semantics
" stay simple (no off-by-one, unlike the till drills).
"
"   ;  repeats the last find in the SAME direction (continue backward)
"   ,  repeats it in the OPPOSITE direction (forward, like f)
"
" Two scenarios, evenly mixed:
"
"   ;  scenario: cursor is AFTER both occurrences. F{c} lands on the
"      nearest (second) match (waypoint 1); ; continues backward onto
"      the first match (target 2).
"   ,  scenario: cursor sits BETWEEN the two occurrences. F{c} lands
"      backward on the first match (waypoint 1); , reverses (like f)
"      onto the second match (target 2).
"
" Unlike the till family, f / F land directly ON the char, so ; / ,
" never hit the cpoptions ';' stuck-before-match quirk. (The runner
" strips ';' anyway, harmlessly.)
"
" Geometry is CONSTANT in SHAPE: two occurrences 6 columns apart on a
" 15-char spaceless noise line, cursor a fixed offset from the pair,
" cluster sliding by a small random offset. Search char from the
" home-row keys s / d / f.
"
" Cheat-defense:
"   - spaceless single-word line → w/b/e/ge never cheaply land on an
"     interior target column
"   - targets kept interior (cols 3..12 on a 15-char line) so 0/^/$
"     never reach them
"   - search char appears EXACTLY twice (noise pool excludes s/d/f)
"   - cursor->target distance is 8 (;) or 3 (,); the F{c}+;/, pair is
"     2 motion events, beating any hjkl chain
"   - the , target is also reachable by a direct forward f{c} in 1
"     event; like the other repeat drills, that shortcut is accepted
"     (the runner credits motion count <= optimal 2)

let s:TARGETS = ['s', 'd', 'f']

let s:NOISE = ['a','b','c','e','g','h','i','j','k','m','n','o',
  \ 'p','q','r','t','u','v','w','x','y','z']

function! vimfluency#drills#move_repeat_last_find_backward#meta() abort
  return {'id': 'move_repeat_last_find_backward',
    \ 'name': 'repeat last find, backward (; ,)',
    \ 'aim': 25, 'allowed_keys': ';,F',
    \ 'prereqs': ['move_repeat_last_find_forward', 'move_to_char_forward_backward'],
    \ 'parallel_to': ['move_repeat_last_find_forward'], 'keys': ';/,', 'family': 'motion',
    \ 'test_sequence': [';', ',']}
endfunction

function! vimfluency#drills#move_repeat_last_find_backward#lesson() abort
  " buf1: search char 's' at cols 4 and 10. Frame 2 demos ; (cursor
  " after both, col 12 → F lands on 10, ; back onto 4). Frame 3 demos ,
  " (cursor between, col 7 → F onto 4, , reverses forward onto 10).
  let buf1 = ['kanslxqwzsmrbt']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 14],
    \  'prompt': [
    \    'After F finds the previous match, ; and , repeat it — no retyping:',
    \    '',
    \    '    ;   →   repeats it backward again (onto the previous match)',
    \    '    ,   →   reverses, like f (onto the next forward match)',
    \    '',
    \    'With both matches behind you, ; walks back; sitting between,',
    \    ', goes forward instead.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 4],
    \  'solve': ['Fs', ';'],
    \  'waypoints': [[1, 10]],
    \  'prompt': 'Both s''s are behind you. Press Fs (lands on the nearer s, 1), then ; (jumps back onto the first s, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 7], 'target': [1, 10],
    \  'solve': ['Fs', ','],
    \  'waypoints': [[1, 4]],
    \  'prompt': 'You sit between the s''s. Press Fs (lands back on the first, 1), then , (reverses forward onto the second s, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 12], 'target': [1, 4],
    \  'solve': ['Fs', ';'],
    \  'waypoints': [[1, 10]],
    \  'prompt': 'Again Fs then ; — F is the backward f; ; keeps walking the matches the way you searched.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_repeat_last_find_backward#generate() abort
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
    " ; scenario: cursor 2 right of the pair. F{c} -> q, ; -> p.
    let cursor_col = q + 2
    let waypoint_col = q
    let target_col = p
    let motion = ';'
    " Strip any single-motion shortcut to the target (see repeatfind).
    let line = vimfluency#repeatfind#decheat(line, cursor_col, target_col, waypoint_col, target)
  else
    " , scenario: cursor in the gap. F{c} -> p, , (like f) -> q.
    let cursor_col = p + 3
    let waypoint_col = p
    let target_col = q
    let motion = ','
  endif

  let item = {'lines': [line],
    \ 'start': [1, cursor_col], 'target': [1, target_col],
    \ 'waypoints': [[1, waypoint_col]],
    \ 'expected_motion': motion, 'optimal_motions': 2}
  " Demo keystroke plan: F{c} to the waypoint, then ; / , to the target.
  let item.solve = vimfluency#repeatfind#solve(item, 0, target)
  return item
endfunction
