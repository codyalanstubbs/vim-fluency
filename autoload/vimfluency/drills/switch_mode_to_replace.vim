" switch_mode_to_replace — atomic 2-cell mode discrimination:
" enter REPLACE mode, or return to NORMAL. Parallel-by-design with
" switch_mode_to_insert / _visual / _command_line.
"
" Note: REPLACE is entered with CAPITAL R (Shift+R). Lowercase r
" replaces a single char and returns to Normal — that's a different
" behavior (single-char replace) and lives in its own future drill.

let s:targets = ['n', 'r']

function! vimfluency#drills#switch_mode_to_replace#meta() abort
  return {'id': 'switch_mode_to_replace',
    \ 'name': 'switch mode to replace (R / Ctrl+[)',
    \ 'aim': 90, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': [], 'keys': 'R/C-[', 'family': 'survival',
    \ 'stroke_counts': {'R': 1, 'C-[': 1},
    \ 'test_sequence': ['R', 'C-[']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#switch_mode_to_replace#generate() abort
  let target = s:targets[s:rand(len(s:targets))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'target_mode_canon': target,
    \ 'expected_motion': target ==# 'r' ? 'R' : 'C-[',
    \ 'optimal_motions': 1,
    \ 'prompt': 'Switch to ' . s:pretty(target) . ' mode',
    \ }
endfunction

function! s:pretty(canon) abort
  return a:canon ==# 'n' ? 'NORMAL' : 'REPLACE'
endfunction

function! vimfluency#drills#switch_mode_to_replace#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two keys, two modes:',
    \    '',
    \    '    R        →  REPLACE  (from NORMAL; capital R, not r)',
    \    '    <C-[>    →  NORMAL   (from REPLACE; <Esc> also works)',
    \    '',
    \    'The next four frames practice the round trip.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'r', 'expected_motion': 'R', 'optimal_motions': 1,
    \  'prompt': 'Switch to REPLACE mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'r', 'expected_motion': 'R', 'optimal_motions': 1,
    \  'prompt': 'Switch to REPLACE mode again.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ ]
endfunction
