" copy_line_to_target — the first yank+paste drill: copy the "copy me"
" line onto the "paste here" line one row away. yy → j/k → P.
"
" Yank alone changes nothing observable, so (per the project's
" measurement rule) we only ever drill it as a visible combo: yank the
" cursor's line, step to the destination, paste it there. The buffer
" changes at the paste, and buffer-state credit does the rest — no
" register inspection needed. The combo is self-enforcing: the target
" needs THIS line's text at the destination, so a stale register just
" produces a wrong buffer.
"
" Deliberately concrete and small:
"   - the source line is always literally "copy me" (cursor starts here),
"   - the destination is always "paste here" (green), exactly ONE row
"     above or below the source,
"   - every other line is filler.
" So the only decision is: is the green line one step up or one step
" down? That's the discrimination axis (yyP↓ / yyP↑) — same keys, but it
" keeps per-direction stats and stops the anti-streak guard spinning on
" a lone motion.
"
" P (paste above), not p: stepping the cursor onto the green line and
" pressing P inserts the copy AT that line and leaves the cursor on the
" copy — so green marks the destination, where the copy lands, and where
" the cursor ends, all one cell. p (paste below) would land the copy a
" row past the cue. p vs P gets its own drill later.
"
" kind 'editing' + show_target: the buffer changes (editing credit path)
" but the green destination is the cue, so we opt back into the green
" cell the editing kind normally hides. No red range.
"
" Measurement: optimal = 2 — one j/k step + the paste. yy fires no event
" (no cursor move, no buffer change) so it isn't billed, consistent with
" the event model (dw is billed 1, not 2).

let s:SOURCE = 'copy me'
let s:DEST = 'paste here'
" filler words for the other lines.
let s:words = ['alpha', 'bravo', 'charlie', 'delta', 'echo',
  \ 'foxtrot', 'golf', 'hotel', 'india', 'juliet', 'kilo', 'lima',
  \ 'mike', 'november', 'oscar', 'papa', 'quebec', 'romeo']

function! vimfluency#drills#copy_line_to_target#meta() abort
  return {'id': 'copy_line_to_target', 'name': 'copy a line to the target (yy … P)',
    \ 'aim': 30, 'allowed_keys': 'yyPjk', 'kind': 'editing', 'show_target': 1,
    \ 'prereqs': ['move_single_char_up_down'], 'keys': 'yyP', 'family': 'yank',
    \ 'test_sequence': ['yyP↓', 'yyP↑']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" n distinct filler words.
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

function! vimfluency#drills#copy_line_to_target#generate() abort
  let n = 4 + s:rand(2)          " 4 or 5 lines
  let lines = s:filler(n)

  " Source row + direction, keeping the adjacent destination in range.
  let down = s:rand(2) == 0
  if down
    let s_row = 1 + s:rand(n - 1)   " 1 .. n-1
    let d_row = s_row + 1
  else
    let s_row = 2 + s:rand(n - 1)   " 2 .. n
    let d_row = s_row - 1
  endif
  let lines[s_row - 1] = s:SOURCE
  let lines[d_row - 1] = s:DEST

  " P inserts the yanked line AT d_row, pushing the old d_row down; the
  " cursor lands on the copy at d_row.
  let target_lines = copy(lines)
  call insert(target_lines, s:SOURCE, d_row - 1)

  return {
    \ 'lines': lines,
    \ 'target_lines': target_lines,
    \ 'start': [s_row, 1],
    \ 'target': [d_row, 1],
    \ 'show_target': 1,
    \ 'prompt': 'Copy the "copy me" line onto the green "paste here" line: yy, one step, P.',
    \ 'expected_motion': down ? 'yyP↓' : 'yyP↑',
    \ 'optimal_motions': 2,
    \ }
endfunction

function! vimfluency#drills#copy_line_to_target#lesson() abort
  " Try frames both directions; show_target draws the green destination
  " even though the frame changes the buffer (editing kind).
  return [
    \ {'kind': 'show', 'lines': ['alpha', 'copy me', 'paste here', 'bravo'], 'cursor': [2, 1],
    \  'prompt': [
    \    'Copy a whole line onto its neighbour in three moves:',
    \    '',
    \    '    yy        →   yank (copy) the line you''re on ("copy me")',
    \    '    j / k     →   step to the green line ("paste here")',
    \    '    P         →   paste it there',
    \    '',
    \    'P drops the copy ON the green line, pushing that line down.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['alpha', 'copy me', 'paste here', 'bravo'],
    \  'start': [2, 1], 'target': [3, 1], 'show_target': 1,
    \  'target_lines': ['alpha', 'copy me', 'copy me', 'paste here', 'bravo'],
    \  'expected_motion': 'yyP↓', 'optimal_motions': 2,
    \  'prompt': 'Green is one line down. yy, j, then P.'},
    \ {'kind': 'try', 'lines': ['alpha', 'paste here', 'copy me', 'bravo'],
    \  'start': [3, 1], 'target': [2, 1], 'show_target': 1,
    \  'target_lines': ['alpha', 'copy me', 'paste here', 'copy me', 'bravo'],
    \  'expected_motion': 'yyP↑', 'optimal_motions': 2,
    \  'prompt': 'Green is one line up. yy, k, then P.'},
    \ {'kind': 'try', 'lines': ['copy me', 'paste here', 'mike', 'oscar'],
    \  'start': [1, 1], 'target': [2, 1], 'show_target': 1,
    \  'target_lines': ['copy me', 'copy me', 'paste here', 'mike', 'oscar'],
    \  'expected_motion': 'yyP↓', 'optimal_motions': 2,
    \  'prompt': 'yy, j, P.'},
    \ {'kind': 'try', 'lines': ['mike', 'oscar', 'paste here', 'copy me'],
    \  'start': [4, 1], 'target': [3, 1], 'show_target': 1,
    \  'target_lines': ['mike', 'oscar', 'copy me', 'paste here', 'copy me'],
    \  'expected_motion': 'yyP↑', 'optimal_motions': 2,
    \  'prompt': 'yy, k, P.'},
    \ ]
endfunction
