" switch_between_many_modes — composite-discrimination drill that mixes
" all five canonical modes. Targets alternate strictly between Normal
" and one of the four non-Normal modes: after every non-Normal entry
" the next item demands a return to Normal; after every Normal
" landing the next item demands a fresh non-Normal entry. Each item
" is a single keystroke — the entry key (i / v / R / :) when going
" into a non-Normal mode, or Ctrl+[ when coming back to Normal.
"
" Why explicitly measure the Ctrl+[ transitions: under the predecessor
" switch_between_non_normal_modes the Ctrl+[ portion of every 2-stroke
" composite was attributed to the entry key it paired with, so the
" learner never saw a per-stroke rate for the leave-key on its own.
" Splitting them out makes Ctrl+[ a first-class measurement, and the
" alternating structure means each summary row reads honestly: one
" item = one stroke = one credit.
"
" Compared to the four atomic switch_mode_to_X drills, this drill
" adds the bookkeeping load — the learner has to track which mode
" they're in, what key to press next — without changing what any
" individual keystroke is. Prereqs are the atomics; they're
" diagnostic, not gating.
"
" Cheat-defense: the runner's no-repeat constraint (target !=
" current mode) and the natural alternation collaborate. The
" generator picks based on live mode() at call time, so the runner
" never has to reject the generator's choices.
"
" Per-item credit comes from check_mode_for_credit (training) or
" check_mode_for_learn_credit (lesson) the instant mode() flips to
" target — same code path as the atomic switch_mode_to_X drills.

let s:non_normal = ['i', 'v', 'r', 'c']

function! vimfluency#drills#switch_between_many_modes#meta() abort
  " Aim 70/min. Single-stroke transitions on the atomics aim at
  " 80/min; this drill adds discrimination overhead (deciding which
  " key to press next based on the prompt + current mode), so a
  " slightly lower starting guess.
  return {'id': 'switch_between_many_modes',
    \ 'name': 'switch between many modes (i v R : Ctrl+[)',
    \ 'aim': 70, 'allowed_keys': '', 'kind': 'mode_switch',
    \ 'prereqs': ['switch_mode_to_insert',
    \             'switch_mode_to_visual',
    \             'switch_mode_to_replace',
    \             'switch_mode_to_command_line'],
    \ 'keys': 'i/v/R/:/C-[', 'family': 'survival',
    \ 'stroke_counts': {'i': 1, 'v': 1, 'R': 1, ':': 1, 'C-[': 1},
    \ 'test_sequence': ['i', 'C-[', 'v', 'C-[', 'R', 'C-[', ':', 'C-[']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Map canonical target → the visible keystroke that produces the
" transition. 'n' is the Ctrl+[ exit; the four non-Normal canons map
" to their respective entry keys.
let s:expected_motion = {
  \ 'n': 'C-[', 'i': 'i', 'v': 'v', 'r': 'R', 'c': ':'}

" Canonicalize a vim mode() string the same way the runner does.
" Kept inline so the drill doesn't reach into runner internals.
function! s:mode_canon(raw) abort
  if empty(a:raw) | return 'n' | endif
  let c = a:raw[0]
  if c ==# 'i' | return 'i' | endif
  if c ==# 'R' | return 'r' | endif
  if c ==# 'c' | return 'c' | endif
  if c ==# 'v' || c ==# 'V' || c ==# "\<C-v>" | return 'v' | endif
  return 'n'
endfunction

function! vimfluency#drills#switch_between_many_modes#generate(...) abort
  " Strict alternation: from Normal pick any non-Normal entry; from
  " any non-Normal pick the Ctrl+[ exit back to Normal. mode() is
  " read live at generate-time so the alternation tracks the
  " learner's actual mode, not a side-channel state variable.
  " The optional first arg lets tests inject a canonical mode
  " explicitly (tests run from a script in Normal, so without the
  " hint the 'cur == non-Normal' branch is never exercised).
  let cur = a:0 > 0 ? a:1 : s:mode_canon(mode(1))
  if cur ==# 'n'
    let target = s:non_normal[s:rand(len(s:non_normal))]
  else
    let target = 'n'
  endif
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'target_mode_canon': target,
    \ 'expected_motion': s:expected_motion[target],
    \ 'optimal_motions': 1,
    \ 'prompt': 'Switch to ' . s:pretty(target) . ' mode',
    \ }
endfunction

function! s:pretty(canon) abort
  return get({'n': 'NORMAL', 'i': 'INSERT', 'v': 'VISUAL',
    \ 'r': 'REPLACE', 'c': 'COMMAND'}, a:canon, 'NORMAL')
endfunction

" Lesson walks the learner through one round of the alternation —
" four non-Normal entries each followed by a Ctrl+[ exit, so every
" key on the keymap (i / v / R / : / C-[) gets at least one try
" frame. The test phase randomizes via generate().
function! vimfluency#drills#switch_between_many_modes#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'This drill alternates: enter a non-Normal mode, return to',
    \    'Normal, enter another non-Normal mode, return to Normal …',
    \    '',
    \    '    i / v / R / :   →  enter the named non-Normal mode',
    \    '    Ctrl+[          →  back to Normal  (Esc also works)',
    \    '',
    \    'Every item is a single keystroke. The summary tracks each',
    \    'key independently, so you''ll see a per-key rate for the',
    \    'four entries AND for Ctrl+[.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'i', 'expected_motion': 'i', 'optimal_motions': 1,
    \  'prompt': 'Switch to INSERT mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'v', 'expected_motion': 'v', 'optimal_motions': 1,
    \  'prompt': 'Switch to VISUAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'r', 'expected_motion': 'R', 'optimal_motions': 1,
    \  'prompt': 'Switch to REPLACE mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'c', 'expected_motion': ':', 'optimal_motions': 1,
    \  'prompt': 'Switch to COMMAND mode.'},
    \ {'kind': 'try', 'lines': [],
    \  'target_mode_canon': 'n', 'expected_motion': 'C-[', 'optimal_motions': 1,
    \  'prompt': 'Back to NORMAL mode.'},
    \ ]
endfunction
