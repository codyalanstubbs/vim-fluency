" switch_mode_to_command_line — atomic 2-cell mode discrimination:
" enter COMMAND-LINE mode, or return to NORMAL. Parallel-by-design
" with switch_mode_to_insert / _visual / _replace.
"
" From Command-line mode, Ctrl+[ cancels and returns to Normal
" (same as <Esc>). Pressing <CR> would EXECUTE whatever's been
" typed — including an empty command, which just beeps. For the
" "switch back to Normal" target the canonical exits are Ctrl+[
" and Esc; the runner's mode() polling treats both identically.

let s:targets = ['n', 'c']

function! vimfluency#drills#switch_mode_to_command_line#meta() abort
  return {'id': 'switch_mode_to_command_line',
    \ 'name': 'switch mode to command line (: / Ctrl+[)',
    \ 'aim': 80, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': [], 'keys': ':/C-[', 'family': 'survival',
    \ 'parallel_to': ['switch_mode_to_insert',
    \                 'switch_mode_to_visual',
    \                 'switch_mode_to_replace'],
    \ 'stroke_counts': {':': 1, 'C-[': 1},
    \ 'test_sequence': [':', 'C-[']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#switch_mode_to_command_line#generate() abort
  let target = s:targets[s:rand(len(s:targets))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'target_mode_canon': target,
    \ 'expected_motion': target ==# 'c' ? ':' : 'C-[',
    \ 'optimal_motions': 1,
    \ 'prompt': 'Switch to ' . s:pretty(target) . ' mode',
    \ }
endfunction

function! s:pretty(canon) abort
  return a:canon ==# 'n' ? 'NORMAL' : 'COMMAND'
endfunction

function! vimfluency#drills#switch_mode_to_command_line#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two keys, two modes:',
    \    '',
    \    '    :        →  COMMAND  (from NORMAL)',
    \    '    <C-[>    →  NORMAL   (from COMMAND; <Esc> also works)',
    \    '',
    \    'The next four frames practice the round trip.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'c', 'expected_motion': ':', 'optimal_motions': 1,
    \  'prompt': 'Switch to COMMAND mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'c', 'expected_motion': ':', 'optimal_motions': 1,
    \  'prompt': 'Switch to COMMAND mode again.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ ]
endfunction
