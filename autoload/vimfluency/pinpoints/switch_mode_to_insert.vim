" switch_mode_to_insert — atomic 2-cell mode discrimination:
" enter INSERT mode, or return to NORMAL. Replaces the broader
" change_current_mode pinpoint with a tight 2-cell drill per the
" slice-01 exhaustive-hierarchy framework — each atomic mode-pair
" gets its own pinpoint. Between-non-Normal transitions live in
" switch_btwn_non_normal_modes (composite).
"
" Cells:
"   target = i  → press i  (from Normal)
"   target = n  → press Ctrl+[  (from Insert; Esc also works)
"
" Why Ctrl+[ as the canonical "back to Normal" key — and Esc as
" alternative: Ctrl+[ IS literally Esc. They emit the same byte
" (0x1B) at the terminal; vim can't tell them apart. The advantage
" of teaching Ctrl+[ is that it's home-row-friendly (no reach to
" the Esc key in the top-left corner), and once the learner knows
" they're the same byte they understand why both work everywhere
" Esc works. The runner's polling-based credit doesn't care which
" key the user pressed — it only sees mode() flip to 'n'.

let s:targets = ['n', 'i']

" expected_motion labels use the actual keystroke the learner pressed
" rather than the to_X canonical-target label. Honest display: the
" summary shows 'i' and 'C-[' instead of 'to_i' and 'to_n'.
function! vimfluency#pinpoints#switch_mode_to_insert#meta() abort
  return {'id': 'switch_mode_to_insert',
    \ 'name': 'switch mode to insert',
    \ 'aim': 80, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': [], 'keys': 'i/C-[', 'family': 'survival',
    \ 'stroke_counts': {'i': 1, 'C-[': 1}}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#switch_mode_to_insert#generate() abort
  let target = s:targets[s:rand(len(s:targets))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'target_mode_canon': target,
    \ 'expected_motion': target ==# 'i' ? 'i' : 'C-[',
    \ 'optimal_motions': 1,
    \ 'prompt': 'Switch to ' . s:pretty(target) . ' mode',
    \ }
endfunction

function! s:pretty(canon) abort
  return a:canon ==# 'n' ? 'NORMAL' : 'INSERT'
endfunction

" Lesson: rule statement, then drill the round trip four times. The
" lesson IS the training — the learner doesn't memorize the table,
" they internalize the rule by producing the behavior repeatedly.
function! vimfluency#pinpoints#switch_mode_to_insert#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Two keys, two modes:',
    \    '',
    \    '    i          →  INSERT  (from Normal)',
    \    '    Ctrl+[     →  NORMAL  (from Insert; Esc also works)',
    \    '',
    \    'The next four frames practice the round trip.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'i', 'expected_motion': 'i', 'optimal_motions': 1,
    \  'prompt': 'Switch to INSERT mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'i', 'expected_motion': 'i', 'optimal_motions': 1,
    \  'prompt': 'Switch to INSERT again.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL.'},
    \ ]
endfunction
