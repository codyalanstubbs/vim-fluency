" switch_btwn_non_normal_modes — composite-discrimination drill that
" mixes all four atomic switch_mode_to_X pinpoints. Items target
" non-Normal modes only; from one non-Normal mode the user reaches
" another by pressing Ctrl+[ (back to Normal) then the new mode's
" entry key — a 2-stroke transition through Normal.
"
" Under the slice-01 framework this is a "composite-discrimination
" environment" — the broader, noisier drill on top of the atomic
" mode-pair pinpoints. Prereqs: the four atomics, diagnostic only.
"
" Caveat: the FIRST item of every session starts from Normal (the
" user just typed :Vf), so it's a degenerate 1-stroke entry rather
" than the real composite. From item 2 onward the user is in a
" non-Normal mode and the chain becomes honest. Over a 60-second
" session that's negligible noise.

let s:non_normal = ['i', 'v', 'r', 'c']

function! vimfluency#pinpoints#switch_btwn_non_normal_modes#meta() abort
  return {'id': 'switch_btwn_non_normal_modes',
    \ 'name': 'switch between non-Normal modes',
    \ 'aim': 40, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': ['switch_mode_to_insert',
    \             'switch_mode_to_visual',
    \             'switch_mode_to_replace',
    \             'switch_mode_to_command_line'],
    \ 'keys': 'i/v/R/:/C-[', 'family': 'survival',
    \ 'stroke_counts': {'to_i': 2, 'to_v': 2, 'to_r': 2, 'to_c': 2}}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#switch_btwn_non_normal_modes#generate() abort
  let target = s:non_normal[s:rand(len(s:non_normal))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'target_mode_canon': target,
    \ 'expected_motion': 'to_' . target,
    \ 'optimal_motions': 2,
    \ 'prompt': 'Switch to ' . s:pretty(target) . ' mode',
    \ }
endfunction

function! s:pretty(canon) abort
  return get({'i': 'INSERT', 'v': 'VISUAL', 'r': 'REPLACE',
    \ 'c': 'COMMAND'}, a:canon, 'INSERT')
endfunction

" Lesson teaches the 2-stroke pattern by drilling it. The first try
" frame is a 1-stroke entry (from Normal); every subsequent try is a
" real composite transition (Ctrl+[ + new key) because the user is
" still in the previous target's mode.
function! vimfluency#pinpoints#switch_btwn_non_normal_modes#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'To switch between non-Normal modes, go through Normal first:',
    \    '',
    \    '    Ctrl+[  →  back to Normal',
    \    '    then the entry key for the new mode  (i / v / R / :)',
    \    '',
    \    'Two strokes per transition. Esc also works in place of Ctrl+[.',
    \    '',
    \    'The try frames below chain through every non-Normal mode.',
    \    'After the first one-stroke entry, each transition is a real',
    \    'Ctrl+[-then-key composite.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'i', 'expected_motion': 'to_i', 'optimal_motions': 1,
    \  'prompt': 'Switch to INSERT mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'v', 'expected_motion': 'to_v', 'optimal_motions': 2,
    \  'prompt': 'Switch to VISUAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'r', 'expected_motion': 'to_r', 'optimal_motions': 2,
    \  'prompt': 'Switch to REPLACE mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'c', 'expected_motion': 'to_c', 'optimal_motions': 2,
    \  'prompt': 'Switch to COMMAND mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'i', 'expected_motion': 'to_i', 'optimal_motions': 2,
    \  'prompt': 'Back to INSERT.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'v', 'expected_motion': 'to_v', 'optimal_motions': 2,
    \  'prompt': 'Now VISUAL.'},
    \ ]
endfunction
