" switch_mode_to_visual — atomic 2-cell mode discrimination:
" enter VISUAL mode, or return to NORMAL. Parallel-by-design with
" switch_mode_to_insert / _replace / _command_line — same shape,
" different mode pair. v1 collapses visual sub-modes (v / V / Ctrl+V)
" into one canonical 'v' target; per-axis visual training has a
" natural home in a future visual-family pinpoint.

let s:targets = ['n', 'v']

function! vimfluency#pinpoints#switch_mode_to_visual#meta() abort
  return {'id': 'switch_mode_to_visual',
    \ 'name': 'switch mode to visual',
    \ 'aim': 80, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': [], 'keys': 'v/C-[', 'family': 'survival',
    \ 'parallel_to': ['switch_mode_to_insert',
    \                 'switch_mode_to_replace',
    \                 'switch_mode_to_command_line'],
    \ 'stroke_counts': {'v': 1, 'C-[': 1},
    \ 'test_sequence': ['v', 'C-[']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#switch_mode_to_visual#generate() abort
  let target = s:targets[s:rand(len(s:targets))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'target_mode_canon': target,
    \ 'expected_motion': target ==# 'v' ? 'v' : 'C-[',
    \ 'optimal_motions': 1,
    \ 'prompt': 'Switch to ' . s:pretty(target) . ' mode',
    \ }
endfunction

function! s:pretty(canon) abort
  return a:canon ==# 'n' ? 'NORMAL' : 'VISUAL'
endfunction

function! vimfluency#pinpoints#switch_mode_to_visual#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two keys, two modes:',
    \    '',
    \    '    v          →  VISUAL  (from Normal)',
    \    '    Ctrl+[     →  NORMAL  (from Visual; Esc also works)',
    \    '',
    \    'The next four frames practice the round trip.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'v', 'expected_motion': 'v', 'optimal_motions': 1,
    \  'prompt': 'Switch to VISUAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'v', 'expected_motion': 'v', 'optimal_motions': 1,
    \  'prompt': 'Switch to VISUAL again.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL.'},
    \ ]
endfunction
