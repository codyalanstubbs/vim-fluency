" recognize_current_mode — Mode awareness. Given a SCREEN (a mock vim window with the
" bottom-of-screen indicator rendered as it would appear in real vim),
" name the mode. Recall training.
"
" Why this matters: the user's "current mode" is the most common
" source of vim confusion. Beginners press i, type a few chars, then
" press more letters expecting normal-mode commands and instead
" inject text everywhere. Mode awareness IS the unit of survival.
"
" UI design: the mock screen renders BELOW the input area via the
" recall renderer's prompt_after field. That puts the mode indicator
" at the literal bottom of the buffer — the same position the
" learner sees it in real vim. Describing the bottom of the screen
" in prose pulled the learner out of the environment we're trying
" to teach them in.
"
" Answer encoding: single keystroke per item, so the training measures
" pure recognition and isolates it from typing noise (no word-length
" overhead, no spelling typos to recover from). The mapping mirrors
" the actual vim keys for entering each mode:
"   n  → normal   (mnemonic: 'back to normal')
"   i  → insert   (i is the canonical insert-entry key)
"   v  → visual   (v is the canonical visual-entry key)
"   r  → replace  (first letter of the name; R is vim's actual
"                  replace-mode entry but we lowercase for the rule)
"   :  → command  (':' is literally the key that opens command mode)
"
" Cheat-defense:
"   - Each mock screen uniquely identifies one mode. '-- INSERT --'
"     only appears in insert mode; '-- VISUAL --', '-- REPLACE --'
"     similarly.
"   - Normal mode has no '-- TYPE --' indicator, so its mock ends
"     with the empty area (vim's '~' tilde rows above an empty
"     command line). The absence-of-indicator IS the cue.
"   - Command mode's mock shows ':' at the bottom — distinct from
"     any '-- WORD --' modeline.
"
" Out of scope for v1: visual-line vs visual-block discrimination,
" operator-pending (transient — hard to "show" in a static cue),
" terminal mode.

" Mock 'editor area' shown directly below the input line — '~' rows
" mark the empty buffer lines vim shows past end-of-file. The very
" last line is the mode indicator (or absent for normal, ':_' for
" command). The input row above acts visually as the buffer's only
" content line, so the whole stack reads like one continuous vim
" window.
let s:MOCK_TILDES = [
  \ '  ~',
  \ '  ~',
  \ '  ~',
  \ '  ~',
  \ ]

let s:items = [
  \ {'answer': 'n', 'modeline': ''},
  \ {'answer': 'i', 'modeline': '-- INSERT --'},
  \ {'answer': 'v', 'modeline': '-- VISUAL --'},
  \ {'answer': 'r', 'modeline': '-- REPLACE --'},
  \ {'answer': ':', 'modeline': ':_'},
  \ ]

function! vimfluency#pinpoints#recognize_current_mode#meta() abort
  " Single-keystroke answers, so aim climbs significantly above the
  " original 60/min for full mode names. Starting guess; revise on
  " data.
  return {'id': 'recognize_current_mode', 'name': 'mode awareness',
    \ 'aim': 120, 'allowed_keys': 'nivr:', 'kind': 'recall',
    \ 'prereqs': [], 'keys': 'n/i/v/r/:', 'family': 'survival'}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:mock_screen(modeline) abort
  let mock = copy(s:MOCK_TILDES)
  if !empty(a:modeline)
    call add(mock, '  ' . a:modeline)
  endif
  return mock
endfunction

function! vimfluency#pinpoints#recognize_current_mode#generate() abort
  let pick = s:items[s:rand(len(s:items))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'prompt': 'Press the key for the current mode:',
    \ 'prompt_after': s:mock_screen(pick.modeline),
    \ 'expected_answer': pick.answer,
    \ 'expected_motion': pick.answer,
    \ 'optimal_motions': 1,
    \ }
endfunction

" DI sequence: two short show frames frame the recognition pattern
" and teach the mode→key mapping, then one try frame per mode with
" the mock screen rendered below the input (same view the training
" presents).
function! vimfluency#pinpoints#recognize_current_mode#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'name the current mode by pressing ONE key.',
    \    'The key is (mostly) the first letter of the mode name:',
    \    '    n = normal',
    \    '    i = insert',
    \    '    v = visual',
    \    '    r = replace',
    \    '    : = command  (the key that opens command mode)',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Three patterns to recognize at the bottom of the screen:',
    \    '  - "-- MODE --" indicator   → insert, visual, or replace',
    \    '  - no indicator             → normal mode (the default)',
    \    '  - ":" prompt               → command mode',
    \    '',
    \    'Each try frame shows a mock vim screen below the input area.',
    \    'Look at the bottom of the mock; press the mode key.',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'n', 'expected_motion': 'n', 'optimal_motions': 1,
    \  'prompt': [
    \    'No "-- TYPE --" indicator at the bottom of the mock.',
    \    'This is NORMAL mode — press n.'],
    \  'prompt_after': s:mock_screen('')},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'i', 'expected_motion': 'i', 'optimal_motions': 1,
    \  'prompt': [
    \    '"-- INSERT --" at the bottom → press i.'],
    \  'prompt_after': s:mock_screen('-- INSERT --')},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'v', 'expected_motion': 'v', 'optimal_motions': 1,
    \  'prompt': [
    \    '"-- VISUAL --" at the bottom → press v.'],
    \  'prompt_after': s:mock_screen('-- VISUAL --')},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'r', 'expected_motion': 'r', 'optimal_motions': 1,
    \  'prompt': [
    \    '"-- REPLACE --" at the bottom → press r.'],
    \  'prompt_after': s:mock_screen('-- REPLACE --')},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':', 'expected_motion': ':', 'optimal_motions': 1,
    \  'prompt': [
    \    'A ":" prompt at the bottom — this is COMMAND mode.',
    \    'Press : (the key that opens command mode).'],
    \  'prompt_after': s:mock_screen(':_')},
    \ ]
endfunction
