" change_current_mode — mode-production training. The prompt names a
" target mode; the learner changes into it by pressing the entry
" key(s). Each item's START mode is whatever the previous item ended
" in (since the user is already there after the last credit), so
" practice covers REAL between-mode transitions, not just "from
" Normal" entries.
"
" Replaces the older `recognize_current_mode` pinpoint (which was a
" recognition task — given a screen, type the mode key). Production
" is the more useful behavior to train: in real vim use the learner
" doesn't read a "-- INSERT --" indicator to figure out what mode
" they're in; they want to GET to a specific mode quickly.
"
" Five canonical modes:
"   n  Normal      enter via <Esc>            (always)
"   i  Insert      enter via i                (from Normal)
"   v  Visual      enter via v                (from Normal; collapses
"                  v/V/<C-v> — visual sub-modes get their own pinpoint
"                  in a future visual-family slice)
"   r  Replace     enter via R                (from Normal)
"   c  Command     enter via :                (from Normal)
"
" From any non-Normal mode, the user must press <Esc> first, then the
" entry key — so non-Normal → non-Normal transitions are 2 strokes.
" The runner tracks this in `optimal_motions` (1 for to-Normal or
" from-Normal, 2 otherwise) so the per-motion breakdown stays
" honest about transition cost.
"
" The runner credits via timer-polling vim's mode(1) every 50ms — see
" s:check_mode_for_credit in autoload/vimfluency.vim. Item-to-item
" continuity is enforced by the generation loop in s:next_item, which
" regenerates until target != current mode (so no back-to-back targets
" and no zero-work items).
"
" Cheat-defense: the prompt names ONE mode. The only way to reach it
" is to actually be in that mode. No surrogate cue.

let s:modes = ['n', 'i', 'v', 'r', 'c']

function! vimfluency#pinpoints#change_current_mode#meta() abort
  " stroke_counts declares the optimistic per-target count: 1 stroke
  " when starting from Normal. The runner's optimal_motions on each
  " item reflects the actual transition cost (2 for between-non-
  " normal transitions), so the SCC efficiency calculation stays
  " accurate; stroke_count is for the VfList breakdown's per-target
  " stroke_rate column, where "rate per stroke" reads as the per-
  " entry-key throughput.
  return {'id': 'change_current_mode', 'name': 'change current mode',
    \ 'aim': 60, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': [], 'keys': '<Esc>/i/v/R/:', 'family': 'survival',
    \ 'stroke_counts': {'to_n': 1, 'to_i': 1, 'to_v': 1,
    \                   'to_r': 1, 'to_c': 1}}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" generate() picks a target uniformly at random. The runner's
" generation loop rejects target == current mode (no-repeat /
" no-zero-work constraint), so over the long run each non-current
" mode appears roughly equally — the active mode rotates.
function! vimfluency#pinpoints#change_current_mode#generate() abort
  let target = s:modes[s:rand(len(s:modes))]
  " optimal_motions is set conservatively to 1 here; the runner
  " refines it to the actual transition cost (1 or 2) at credit time
  " via s:mode_switch_strokes. The accumulated total_motions /
  " total_optimal_motions on the session record uses the runtime
  " value, so efficiency stays correct.
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'target_mode_canon': target,
    \ 'expected_motion': 'to_' . target,
    \ 'optimal_motions': 1,
    \ 'prompt': 'Switch to ' . s:mode_pretty(target) . ' mode',
    \ }
endfunction

function! s:mode_pretty(canon) abort
  return get({'n': 'NORMAL', 'i': 'INSERT', 'v': 'VISUAL',
    \ 'r': 'REPLACE', 'c': 'COMMAND'}, a:canon, 'NORMAL')
endfunction

" Lesson: 2 show frames (rules + meta-rule) then 8 try frames that
" walk the learner through each entry + the <Esc>-back-to-Normal pair.
" The try-frame sequence is intentional:
"
"   3. try i  (start: Normal)  → press i                  (1 stroke)
"   4. try n  (start: Insert)  → press <Esc>              (1 stroke)
"   5. try v  (start: Normal)  → press v                  (1 stroke)
"   6. try n  (start: Visual)  → press <Esc>              (1 stroke)
"   7. try r  (start: Normal)  → press R                  (1 stroke)
"   8. try n  (start: Replace) → press <Esc>              (1 stroke)
"   9. try c  (start: Normal)  → press :                  (1 stroke)
"  10. try n  (start: Command) → press <Esc> or <CR>      (1 stroke)
"
" Every transition is a 1-stroke trip through Normal, which keeps the
" first encounter with each entry key clean. Two-stroke chains
" (<Esc>+key between non-Normal modes) get drilled in the test phase
" and at training time, where the chain is honest.
function! vimfluency#pinpoints#change_current_mode#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Every vim mode has one common entry command.',
    \    'Memorize this table — youll practice it next:',
    \    '',
    \    '    Normal:   <Esc>   (works from any mode)',
    \    '    Insert:   i       (from Normal)',
    \    '    Visual:   v       (from Normal)',
    \    '    Replace:  R       (capital R, from Normal)',
    \    '    Command:  :       (from Normal)',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'The meta-rule: from a NON-Normal mode, press <Esc> first.',
    \    '',
    \    '  - Insert → Visual    = <Esc> v   (2 strokes)',
    \    '  - Visual → Command   = <Esc> :   (2 strokes)',
    \    '  - Anywhere → Normal  = <Esc>     (1 stroke)',
    \    '  - Normal → anything  = the entry key alone   (1 stroke)',
    \    '',
    \    'The try frames below walk you through each entry and back.',
    \    'After you reach the prompted mode the lesson auto-advances —',
    \    'no need to press Space.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'i', 'expected_motion': 'to_i', 'optimal_motions': 1,
    \  'prompt': 'Switch to INSERT mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'to_n', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'v', 'expected_motion': 'to_v', 'optimal_motions': 1,
    \  'prompt': 'Switch to VISUAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'to_n', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'r', 'expected_motion': 'to_r', 'optimal_motions': 1,
    \  'prompt': 'Switch to REPLACE mode (capital R).'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'to_n', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'c', 'expected_motion': 'to_c', 'optimal_motions': 1,
    \  'prompt': 'Switch to COMMAND mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'to_n', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ ]
endfunction
