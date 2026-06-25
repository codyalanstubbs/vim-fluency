" move_repeat_last_find_forward — ; / , over a FORWARD find (f) only.
"
" The foundational repeat-find drill: the learner only ever sets up
" the repeat with lowercase `f` (no Shift, lands ON the char, the
" highest-fluency member of the f/F/t/T family in real data). With
" the setup motion held effortless and constant, the only thing left
" to discriminate is `;` vs `,`:
"
"   ;  repeats the last find in the SAME direction (continue forward)
"   ,  repeats it in the OPPOSITE direction (go back)
"
" Two scenarios, evenly mixed:
"
"   ;  scenario: cursor is BEFORE both occurrences of the search char.
"      f{c} lands on the first (waypoint 1); ; continues forward to
"      the second (target 2).
"   ,  scenario: cursor sits BETWEEN the two occurrences. f{c} lands
"      forward on the second (waypoint 1); , reverses backward to the
"      first (target 2).
"
" The cursor's position relative to the pair IS the discriminative
" cue — both occurrences ahead → ; ; straddling them → , — which is
" exactly how you choose between them in practice.
"
" Geometry is CONSTANT in SHAPE (the 2026-06 till-drill approach):
" two occurrences a fixed 6 columns apart, cursor a fixed offset from
" the pair, on a 15-char spaceless noise line. The cluster slides
" along the line by a small random offset so absolute columns never
" become a memorizable tell, but the spacing and cursor-relative
" position are constant so the learner reasons about nothing but
" ; vs ,. The search char is drawn from the home-row keys s / d / f
" so f{c} is an effortless left-hand roll.
"
" Harder sibling: move_repeat_last_find_forward_backward adds the
" backward find (F) as an alternate setup. Future siblings cover
" t / T (till) and the cross mixes, mirroring the move-to-till
" hierarchy.
"
" Cheat-defense:
"   - spaceless single-word line → w/b/e/ge never cheaply land on an
"     interior occurrence column
"   - occurrences kept interior (left margin >= 2, right margin >= 3)
"     so 0/^/$ never land on the target
"   - search char appears EXACTLY twice (noise pool excludes s/d/f),
"     so f{c} from before the pair lands on the first occurrence and
"     ; reaches the second with no stray match in between
"   - cursor->target distance is 8 (;) or 3 (,); the f{c}+;/, pair is
"     2 motion events, beating any hjkl chain
"   - the , target is also reachable by a direct backward F{c} in 1
"     event; like the harder sibling, that Tier-5-ish shortcut is
"     accepted (the runner credits motion count <= optimal 2)

let s:TARGETS = ['s', 'd', 'f']

" Noise pool = a-z minus the three search chars, so the chosen search
" char is the only one of s/d/f present and appears exactly twice.
let s:NOISE = ['a','b','c','e','g','h','i','j','k','m','n','o',
  \ 'p','q','r','t','u','v','w','x','y','z']

function! vimfluency#drills#move_repeat_last_find_forward#meta() abort
  return {'id': 'move_repeat_last_find_forward',
    \ 'name': 'repeat last find, forward (; ,)',
    \ 'aim': 40, 'allowed_keys': ';,f',
    \ 'prereqs': ['move_to_char_forward_backward'],
    \ 'parallel_to': [], 'keys': ';/,', 'family': 'motion',
    \ 'test_sequence': [';', ',']}
endfunction

function! vimfluency#drills#move_repeat_last_find_forward#lesson() abort
  " buf1: search char 's' at cols 4 and 10 (6 apart). Frames 2-3
  " demo ; and , from the two cursor placements. Frame 4 is the
  " payoff — a denser line where retyping fs would obviously waste.
  let buf1 = ['kanslxqwzsmrbt']
  let buf2 = ['wsxqsmrsktsb']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 1],
    \  'prompt': [
    \    'After an f{char} find, ; and , repeat it — no retyping the char:',
    \    '',
    \    '    ;   →   repeats the find in the SAME direction (forward again)',
    \    '    ,   →   repeats it in the OPPOSITE direction (back)',
    \    '',
    \    'With both matches ahead, ; walks through them; sitting between,',
    \    ', reverses.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 2], 'target': [1, 10],
    \  'solve': ['fs', ';'],
    \  'waypoints': [[1, 4]],
    \  'prompt': 'Both s''s are ahead. Press fs (lands on the first s, 1), then ; (jumps forward to the second s, 2).'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 7], 'target': [1, 4],
    \  'solve': ['fs', ','],
    \  'waypoints': [[1, 10]],
    \  'prompt': 'You sit between the two s''s. Press fs (lands forward on the second, 1), then , (reverses back to the first, 2).'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 1], 'target': [1, 5],
    \  'solve': ['fs', ';'],
    \  'waypoints': [[1, 2]],
    \  'prompt': 'Press fs then ; — fs lands on the first s (1); ; hops to the next (2). Keep pressing ; to walk them all.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_repeat_last_find_forward#generate() abort
  let llen = 15
  let target = s:TARGETS[s:rand(len(s:TARGETS))]
  " First occurrence p in {3,4,5,6}; second q = p + 6 in {9..12}.
  " p >= 3 keeps left margin >= 2; q <= 12 keeps right margin >= 3.
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
    " ; scenario: cursor 2 cols left of the pair, before both matches.
    let cursor_col = p - 2
    let waypoint_col = p
    let target_col = q
    let motion = ';'
    " Strip any single-motion shortcut to the target (see repeatfind).
    let line = vimfluency#repeatfind#decheat(line, cursor_col, target_col, waypoint_col, target)
  else
    " , scenario: cursor in the middle of the gap, between the matches.
    let cursor_col = p + 3
    let waypoint_col = q
    let target_col = p
    let motion = ','
  endif

  let item = {'lines': [line],
    \ 'start': [1, cursor_col], 'target': [1, target_col],
    \ 'waypoints': [[1, waypoint_col]],
    \ 'expected_motion': motion, 'optimal_motions': 2}
  " Demo keystroke plan: f{c} to the waypoint, then ; / , to the target.
  let item.solve = vimfluency#repeatfind#solve(item, 0, target)
  return item
endfunction
