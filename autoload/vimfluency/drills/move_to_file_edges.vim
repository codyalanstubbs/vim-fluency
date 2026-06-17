" move_to_file_edges — gg / G. Jump to the first line (gg) or the last
" line (G) of the file. The first FILE-level motion drill: where the
" line-edge and word motions move within a line, these jump the whole
" buffer. Parallel-by-design with move_to_line_edges_start_end (0/$):
" same 'jump to an edge' shape, file scope instead of line scope.
"
" Both land on the first non-blank column of the target line (vim's
" default startofline behavior), so with non-indented edge lines the
" target is column 1.
"
" Cheat-analysis — keep gg/G the strictly shortest path:
"
"   - j/k chain: the cursor starts >= 4 lines from each edge, so any
"     vertical key-spam is >= 4 motions vs the single gg/G jump.
"
"   - {/} (paragraph motions to file edges): a single { or } would
"     reach the top/bottom of the file in one motion IF there were no
"     blank line in the way. So every buffer carries one blank line
"     strictly between the cursor and the top, and one between the
"     cursor and the bottom — { stops at the upper blank, } at the
"     lower one, neither reaching line 1 / line n. Both blanks are
"     present in EVERY item (gg and G alike) so the blank positions
"     are not a tell.
"
"   - edge lines (line 1 and the last line) are never blank and never
"     indented, so gg/G land at column 1 and 0/^/$ on those lines are
"     irrelevant (the cursor isn't there yet).
"
"   - Residual, accepted: counts (`1G`, `NG`, `:1`/`:$`) reach an edge
"     in one motion — the Tier-5 count escape, same as the other
"     motion drills. And H/L (screen top/bottom) coincide with the
"     file edges when the whole file fits the window; there is no
"     terminal-independent defense for that, and a learner at the
"     gg/G stage won't reach for H/L, so it's left as an accepted tie.

let s:LINES = ['def main', 'import os', 'return val', 'while true',
  \ 'count = 0', 'parse args', 'open file', 'read data', 'close conn',
  \ 'exit code', 'check env', 'load conf', 'run task', 'save out',
  \ 'done here', 'next step', 'init repo', 'build app', 'fetch all',
  \ 'merge dev', 'set flags', 'find bug', 'ship it']

function! vimfluency#drills#move_to_file_edges#meta() abort
  return {'id': 'move_to_file_edges',
    \ 'name': 'go to file top/bottom (gg G)',
    \ 'aim': 50, 'allowed_keys': 'gG',
    \ 'prereqs': ['move_single_char_up_down'],
    \ 'parallel_to': ['move_to_line_edges_start_end'],
    \ 'keys': 'gg/G', 'family': 'motion',
    \ 'test_sequence': ['gg', 'G']}
endfunction

function! vimfluency#drills#move_to_file_edges#lesson() abort
  " 14-line buffer, blanks at 4 and 10, cursor mid-file (line 7). gg
  " jumps to line 1, G to line 14; { and } would stop at the blanks.
  let buf = ['def main', 'import os', 'return val', '', 'while true',
    \ 'count = 0', 'parse args', 'open file', 'read data', '',
    \ 'load conf', 'run task', 'save out', 'done here']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [7, 1],
    \  'prompt': [
    \    'Two whole-file jumps:',
    \    '',
    \    '    gg  →  first line of the file',
    \    '    G   →  last line of the file',
    \    '',
    \    'Read whether the target is at the top or the bottom, then',
    \    'jump there in one motion instead of holding j / k.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [7, 1], 'target': [1, 1],
    \  'prompt': 'Target is the first line — press gg.'},
    \ {'kind': 'try', 'lines': buf, 'start': [7, 1], 'target': [14, 1],
    \  'prompt': 'Target is the last line — press G.'},
    \ {'kind': 'try', 'lines': buf, 'start': [12, 1], 'target': [1, 1],
    \  'prompt': 'Near the bottom now — gg still jumps straight to the first line.'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#move_to_file_edges#generate() abort
  let n = 14 + s:rand(5)                    " 14..18 lines
  let lines = []
  for _ in range(n)
    call add(lines, s:LINES[s:rand(len(s:LINES))])
  endfor

  " Cursor in the interior, >= 4 lines from each edge.
  let cursor_line = 5 + s:rand(n - 8)       " 5 .. n-4
  " One blank strictly above the cursor, one strictly below — block
  " { / } from reaching the file edges; present in every item.
  let blank_above = 3 + s:rand(cursor_line - 3)             " 3 .. cursor_line-1
  let blank_below = (cursor_line + 1) + s:rand(n - 1 - cursor_line)  " cursor_line+1 .. n-1
  let lines[blank_above - 1] = ''
  let lines[blank_below - 1] = ''

  if s:rand(2) == 0
    let target_line = 1
    let motion = 'gg'
  else
    let target_line = n
    let motion = 'G'
  endif

  return {'lines': lines,
    \ 'start': [cursor_line, 1], 'target': [target_line, 1],
    \ 'expected_motion': motion, 'optimal_motions': 1}
endfunction
