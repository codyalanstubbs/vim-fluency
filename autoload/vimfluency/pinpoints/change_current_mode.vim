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

" Lesson: SHOW-ONLY for v1. The mode-entry rule is small enough that
" rule statements + the meta-rule for non-Normal starts cover it; the
" training then exercises the production. Try-frame support in the
" lesson runner for mode_switch is a follow-up (the existing learn
" runner only knows about insert events; visual/replace/command
" credit would need the same polling infrastructure replicated in the
" learn path). For now the learner reads the rules here and
" practices in :Vf change_current_mode.
function! vimfluency#pinpoints#change_current_mode#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Every vim mode has one common entry command.',
    \    'Memorize this table — the training exercises it:',
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
    \    'In the training, each prompt names a target mode. The',
    \    'starting mode is whatever the LAST item ended in — so',
    \    'youll practice real chained transitions.',
    \    '',
    \    'Press p to start training, or q to close the lesson.']},
    \ ]
endfunction
