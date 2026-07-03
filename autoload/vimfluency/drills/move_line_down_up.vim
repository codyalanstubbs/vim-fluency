" move_line_down_up — move a whole line one row, by cut-and-paste. The
" classic ddp / ddkP idioms:
"
"   ddp    →   move the line DOWN one (swap with the line below)
"   ddkP   →   move the line UP one   (swap with the line above)
"
" dd cuts the line into the register (the delete-into-register
" interaction), then p/P drops it back one row over. Observable combo:
" the buffer changes, buffer-state credit does the rest.
"
" The green line marks where your line should end up (the neighbour it
" swaps with): green below → ddp, green above → ddkP. It's a whole-line
" highlight (target_full_line) so it reads clearly; the green is always
" an adjacent row, never under the cursor.
"
" Two vim gotchas the generator works around:
"   - ddP and ddkp are no-ops (they paste the line right back). Only
"     ddp / ddkP actually move it.
"   - dd lands the cursor on the line BELOW the deleted one — except on
"     the LAST line, where it lands on the previous line, so ddkP would
"     overshoot. So the UP mover is never the last line (R in [2,n-1]);
"     the DOWN mover is never the last line either (nothing to swap with
"     below), R in [1,n-1].
"
" kind 'editing' + show_target + target_full_line: buffer changes, but
" the green destination line is the cue (no red range).
"
" Measurement: ddp is two events (dd, p) → optimal 2; ddkP is three (dd,
" k, P) → optimal 3. Tokens are literal keys, so stroke_count reads
" ddp=3, ddkP=5 (P needs Shift).

let s:words = ['alpha', 'bravo', 'charlie', 'delta', 'echo',
  \ 'foxtrot', 'golf', 'hotel', 'india', 'juliet', 'kilo', 'lima',
  \ 'mike', 'november', 'oscar', 'papa', 'quebec', 'romeo']

function! vimfluency#drills#move_line_down_up#meta() abort
  return {'id': 'move_line_down_up', 'name': 'move a line down / up (ddp / ddkP)',
    \ 'aim': 30, 'allowed_keys': 'ddpkP', 'kind': 'editing',
    \ 'show_target': 1, 'target_full_line': 1,
    \ 'prereqs': ['delete_char_vs_line', 'paste_line_below_above'],
    \ 'keys': 'ddp/ddkP', 'family': 'paste',
    \ 'test_sequence': ['ddp', 'ddkP']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:filler(n) abort
  let pool = copy(s:words)
  let out = []
  while len(out) < a:n
    let i = s:rand(len(pool))
    call add(out, pool[i])
    call remove(pool, i)
  endwhile
  return out
endfunction

function! vimfluency#drills#move_line_down_up#generate() abort
  let n = 4 + s:rand(2)          " 4 or 5 lines
  let lines = s:filler(n)
  let down = s:rand(2) == 0

  if down
    let r = 1 + s:rand(n - 1)    " 1 .. n-1 (a line exists below)
    let dest = r + 1
    let motion = 'ddp'
    let optimal = 2
  else
    let r = 2 + s:rand(n - 2)    " 2 .. n-1 (not first — need a line
                                 " above; not last — dd cursor gotcha)
    let dest = r - 1
    let motion = 'ddkP'
    let optimal = 3
  endif
  let lines[r - 1] = 'move me'

  " The move swaps the mover with its neighbour.
  let target_lines = copy(lines)
  let tmp = target_lines[r - 1]
  let target_lines[r - 1] = target_lines[dest - 1]
  let target_lines[dest - 1] = tmp

  return {
    \ 'lines': lines,
    \ 'target_lines': target_lines,
    \ 'start': [r, 1],
    \ 'target': [dest, 1],
    \ 'show_target': 1,
    \ 'target_full_line': 1,
    \ 'prompt': 'Move the "move me" line onto the green line: ddp (down) or ddkP (up).',
    \ 'expected_motion': motion,
    \ 'optimal_motions': optimal,
    \ }
endfunction

function! vimfluency#drills#move_line_down_up#lesson() abort
  return [
    \ {'kind': 'show', 'lines': ['alpha', 'move me', 'charlie', 'delta'], 'cursor': [2, 1],
    \  'prompt': [
    \    'Move a line one row by cutting and pasting it:',
    \    '',
    \    '    ddp    →   move it DOWN (swap with the line below)',
    \    '    ddkP   →   move it UP   (swap with the line above)',
    \    '',
    \    'dd cuts the line; p drops it back one row down, kP one row up.',
    \    'The green line is where it should end up:',
    \    '    green below → ddp     green above → ddkP',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['alpha', 'move me', 'charlie', 'delta'],
    \  'start': [2, 1], 'target': [3, 1], 'show_target': 1, 'target_full_line': 1,
    \  'target_lines': ['alpha', 'charlie', 'move me', 'delta'],
    \  'expected_motion': 'ddp', 'optimal_motions': 2,
    \  'prompt': 'Green is below. Press ddp — the line drops down one.'},
    \ {'kind': 'try', 'lines': ['alpha', 'move me', 'charlie', 'delta'],
    \  'start': [2, 1], 'target': [1, 1], 'show_target': 1, 'target_full_line': 1,
    \  'target_lines': ['move me', 'alpha', 'charlie', 'delta'],
    \  'expected_motion': 'ddkP', 'optimal_motions': 3,
    \  'prompt': 'Green is above. Press ddkP — the line climbs up one.'},
    \ {'kind': 'try', 'lines': ['mike', 'oscar', 'move me', 'papa'],
    \  'start': [3, 1], 'target': [4, 1], 'show_target': 1, 'target_full_line': 1,
    \  'target_lines': ['mike', 'oscar', 'papa', 'move me'],
    \  'expected_motion': 'ddp', 'optimal_motions': 2,
    \  'prompt': 'Green below → ddp.'},
    \ {'kind': 'try', 'lines': ['mike', 'move me', 'oscar', 'papa'],
    \  'start': [2, 1], 'target': [1, 1], 'show_target': 1, 'target_full_line': 1,
    \  'target_lines': ['move me', 'mike', 'oscar', 'papa'],
    \  'expected_motion': 'ddkP', 'optimal_motions': 3,
    \  'prompt': 'Green above → ddkP.'},
    \ ]
endfunction
