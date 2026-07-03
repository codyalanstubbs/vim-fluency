" paste_line_below_above — discriminate p vs P, linewise. After yanking
" the current line, p drops the copy on the line BELOW, P on the line
" you're ON (pushing you down). The classic before/after paste split, the
" paste-family analog of insert_before_after_char's i vs a.
"
" The subtlety that shapes the whole drill: yyp and yyP produce the
" IDENTICAL buffer (two adjacent copies) — they differ ONLY in where the
" cursor lands (the lower copy for p, the upper copy for P). So credit is
" by cursor position, and the cue can't be a single green cell: P's
" destination is the cursor's own line, where a one-cell highlight hides
" under the cursor. Instead the whole DESTINATION LINE lights up
" (target_full_line), visible either way:
"   green on the line BELOW you  → the copy goes there   → yyp
"   green on the line you're ON  → the copy takes your spot → yyP
"
" kind 'editing' + show_target + target_full_line: the buffer changes,
" but the green destination line is the cue (no red range), and it's a
" whole-line highlight so it reads even under the cursor.
"
" Measurement: yy fires no event; the paste is one → optimal 1. The
" stroke_count column reads the literal tokens: yyp = 3, yyP = 4 (P needs
" Shift). Buffer-state credit accepts any equivalent route; the token
" labels the intended combo.

let s:words = ['alpha', 'bravo', 'charlie', 'delta', 'echo',
  \ 'foxtrot', 'golf', 'hotel', 'india', 'juliet', 'kilo', 'lima',
  \ 'mike', 'november', 'oscar', 'papa', 'quebec', 'romeo']

function! vimfluency#drills#paste_line_below_above#meta() abort
  return {'id': 'paste_line_below_above', 'name': 'paste line below vs above (p / P)',
    \ 'aim': 35, 'allowed_keys': 'yypP', 'kind': 'editing',
    \ 'show_target': 1, 'target_full_line': 1,
    \ 'prereqs': ['copy_line_to_target'], 'keys': 'yyp/yyP', 'family': 'paste',
    \ 'test_sequence': ['yyp', 'yyP']}
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

function! vimfluency#drills#paste_line_below_above#generate() abort
  let n = 4 + s:rand(2)          " 4 or 5 lines
  let lines = s:filler(n)
  let below = s:rand(2) == 0     " p (below) vs P (above/here)

  " Source row: for p we duplicate downward (need a row below to land on
  " for the cue to sit below the cursor); for P the copy takes the
  " cursor's own row, so any row works.
  if below
    let s_row = 1 + s:rand(n - 1)   " 1 .. n-1 (a line exists below)
    let d_row = s_row + 1
    let motion = 'yyp'
  else
    let s_row = 1 + s:rand(n)        " any row
    let d_row = s_row                " the copy lands on the cursor's line
    let motion = 'yyP'
  endif

  " Cursor starts off column 1 so nothing distracts; column is irrelevant
  " to linewise yy/p/P. (The whole-line highlight is the cue regardless.)
  let start_col = 1 + s:rand(len(lines[s_row - 1]) - 1)

  " yyp and yyP both yield the same buffer: the source line duplicated,
  " two copies adjacent. Only item.target (the cursor) differs.
  let target_lines = copy(lines)
  call insert(target_lines, lines[s_row - 1], s_row - 1)

  return {
    \ 'lines': lines,
    \ 'target_lines': target_lines,
    \ 'start': [s_row, start_col],
    \ 'target': [d_row, 1],
    \ 'show_target': 1,
    \ 'target_full_line': 1,
    \ 'prompt': 'Duplicate your line onto the green line: yy, then p (below) or P (here).',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#paste_line_below_above#lesson() abort
  return [
    \ {'kind': 'show', 'lines': ['alpha', 'bravo', 'charlie', 'delta'], 'cursor': [2, 1],
    \  'prompt': [
    \    'Yank a line, then paste the copy on one of two sides:',
    \    '',
    \    '    yy p   →   copy goes on the line BELOW you',
    \    '    yy P   →   copy goes on the line you''re ON (you slide down)',
    \    '',
    \    'The whole green line shows where the copy should land:',
    \    '    green below you   → p',
    \    '    green on your line → P',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['alpha', 'bravo', 'charlie', 'delta'],
    \  'start': [2, 3], 'target': [3, 1], 'show_target': 1, 'target_full_line': 1,
    \  'target_lines': ['alpha', 'bravo', 'bravo', 'charlie', 'delta'],
    \  'expected_motion': 'yyp', 'optimal_motions': 1,
    \  'prompt': 'Green is the line below. yy, then p.'},
    \ {'kind': 'try', 'lines': ['alpha', 'bravo', 'charlie', 'delta'],
    \  'start': [2, 3], 'target': [2, 1], 'show_target': 1, 'target_full_line': 1,
    \  'target_lines': ['alpha', 'bravo', 'bravo', 'charlie', 'delta'],
    \  'expected_motion': 'yyP', 'optimal_motions': 1,
    \  'prompt': 'Green is your own line. yy, then P — bravo takes this spot, you slide down.'},
    \ {'kind': 'try', 'lines': ['mike', 'oscar', 'papa', 'quebec'],
    \  'start': [3, 2], 'target': [4, 1], 'show_target': 1, 'target_full_line': 1,
    \  'target_lines': ['mike', 'oscar', 'papa', 'papa', 'quebec'],
    \  'expected_motion': 'yyp', 'optimal_motions': 1,
    \  'prompt': 'Green below → yy, p.'},
    \ {'kind': 'try', 'lines': ['mike', 'oscar', 'papa', 'quebec'],
    \  'start': [3, 2], 'target': [3, 1], 'show_target': 1, 'target_full_line': 1,
    \  'target_lines': ['mike', 'oscar', 'papa', 'papa', 'quebec'],
    \  'expected_motion': 'yyP', 'optimal_motions': 1,
    \  'prompt': 'Green on your line → yy, P.'},
    \ ]
endfunction
