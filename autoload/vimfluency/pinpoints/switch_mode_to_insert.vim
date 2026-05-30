" switch_mode_to_insert — atomic 2-cell mode discrimination:
" enter INSERT mode, or return to NORMAL. Replaces the broader
" change_current_mode pinpoint with a tight 2-cell drill per the
" slice-01 exhaustive-hierarchy framework — each atomic mode-pair
" gets its own pinpoint. Between-non-Normal transitions live in
" switch_btwn_non_normal_modes (composite).
"
" Cells:
"   target = i  → press i  (from Normal)
"   target = n  → press Ctrl+C  (from Insert; Esc also works)
"
" Why Ctrl+C as the canonical "back to Normal" key — and Esc as
" alternative: Ctrl+C is the more common cross-editor convention
" for "cancel current action" and works from every vim mode without
" the InsertLeave-firing semantics that complicate the existing
" `mode` kind. The runner's polling-based credit treats both
" identically: both flip mode() to 'n', the timer credits on
" detecting the transition.

let s:targets = ['n', 'i']

function! vimfluency#pinpoints#switch_mode_to_insert#meta() abort
  return {'id': 'switch_mode_to_insert',
    \ 'name': 'switch mode to insert',
    \ 'aim': 80, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': [], 'keys': 'i/C-c', 'family': 'survival',
    \ 'stroke_counts': {'to_i': 1, 'to_n': 1}}
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
    \ 'expected_motion': 'to_' . target,
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
    \    '    Ctrl+C     →  NORMAL  (from Insert; Esc also works)',
    \    '',
    \    'The next four frames practice the round trip.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'i', 'expected_motion': 'to_i', 'optimal_motions': 1,
    \  'prompt': 'Switch to INSERT mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'to_n', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'i', 'expected_motion': 'to_i', 'optimal_motions': 1,
    \  'prompt': 'Switch to INSERT again.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'to_n', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL.'},
    \ ]
endfunction
