" switch_mode_to_replace — atomic 2-cell mode discrimination:
" enter REPLACE mode, or return to NORMAL. Parallel-by-design with
" switch_mode_to_insert / _visual / _command_line.
"
" Note: REPLACE is entered with CAPITAL R (Shift+R). Lowercase r
" replaces a single char and returns to Normal — that's a different
" behavior (single-char replace) and lives in its own future pinpoint.

let s:targets = ['n', 'r']

function! vimfluency#pinpoints#switch_mode_to_replace#meta() abort
  return {'id': 'switch_mode_to_replace',
    \ 'name': 'switch mode to replace',
    \ 'aim': 80, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': [], 'keys': 'R/C-[', 'family': 'survival',
    \ 'parallel_to': ['switch_mode_to_insert',
    \                 'switch_mode_to_visual',
    \                 'switch_mode_to_command_line'],
    \ 'stroke_counts': {'to_r': 1, 'to_n': 1}}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#switch_mode_to_replace#generate() abort
  let target = s:targets[s:rand(len(s:targets))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'target_mode_canon': target,
    \ 'expected_motion': 'to_' . target,
    \ 'optimal_motions': 1,
    \ 'prompt': 'Switch to ' . s:pretty(target) . ' mode',
    \ }
endfunction

function! s:pretty(canon) abort
  return a:canon ==# 'n' ? 'NORMAL' : 'REPLACE'
endfunction

function! vimfluency#pinpoints#switch_mode_to_replace#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two keys, two modes:',
    \    '',
    \    '    R (capital)  →  REPLACE  (from Normal)',
    \    '    Ctrl+[       →  NORMAL   (from Replace; Esc also works)',
    \    '',
    \    'The next four frames practice the round trip.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'r', 'expected_motion': 'to_r', 'optimal_motions': 1,
    \  'prompt': 'Switch to REPLACE mode (capital R).'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'to_n', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'r', 'expected_motion': 'to_r', 'optimal_motions': 1,
    \  'prompt': 'Switch to REPLACE again.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'to_n', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL.'},
    \ ]
endfunction
