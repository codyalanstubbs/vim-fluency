" T0.5 — Mode awareness. Given a cue (the bottom-of-screen modeline
" message vim shows in each mode), name the mode. Recall probe.
"
" Why this matters: the user's "current mode" is the most common
" source of vim confusion. Beginners press i, type a few chars, then
" press more letters expecting normal-mode commands and instead
" inject text everywhere. Mode awareness IS the unit of survival.
"
" Probe shape: recall kind. The buffer renders a mock vim modeline as
" the cue; the learner types the mode name in lowercase. Auto-credits
" on exact match.
"
" Cheat-defense:
"   - Each cue uniquely identifies one mode. -- INSERT -- only fires
"     in insert mode; -- VISUAL --, -- REPLACE -- similarly.
"   - Normal mode has no -- TYPE -- indicator, so its cue describes
"     the state-without-message (cursor is a solid block, no modeline
"     message). This is the "blank modeline" cue.
"   - Command mode's cue is the colon prompt at the bottom — distinct
"     from any modeline message.
"   - Lowercase canonical answers. Uppercase (INSERT) won't match;
"     forces the learner to internalize the lowercase convention used
"     throughout vim docs and most tutorials.
"
" Out of scope for v1: visual-line vs visual-block discrimination,
" operator-pending (transient — hard to "show" in a static cue),
" terminal mode. Add these when the catalog expands T0.5.

let s:items = [
  \ {'answer': 'normal',
  \  'cue': '(no -- TYPE -- indicator; cursor is a solid block)'},
  \ {'answer': 'insert',
  \  'cue': '-- INSERT --'},
  \ {'answer': 'visual',
  \  'cue': '-- VISUAL --'},
  \ {'answer': 'replace',
  \  'cue': '-- REPLACE --'},
  \ {'answer': 'command',
  \  'cue': ':_  (cursor on a colon line at the bottom of the screen)'},
  \ ]

function! vimfluency#pinpoints#pT0_5#meta() abort
  " Catalog aim is 60/min — high because the per-item task is
  " purely recognition (no motion to perform). Starting guess.
  return {'id': 'T0.5', 'name': 'mode awareness',
    \ 'aim': 60, 'allowed_keys': 'a-z', 'kind': 'recall',
    \ 'prereqs': []}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" DI sequence: two short show frames frame the recognition pattern
" (most modes use '-- MODE --'; normal has no indicator; command
" shows ':'), then one try frame per mode. Five mode names, five
" try frames.
function! vimfluency#pinpoints#pT0_5#lesson() abort
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'T0.5 — name the current mode from a screen cue.',
    \    'Vim shows which mode you''re in at the bottom of the screen.',
    \    'Recognize the cue, type the mode name (lowercase, one word).',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Three patterns to know:',
    \    '  - "-- MODE --" at the bottom → insert, visual, or replace',
    \    '  - no indicator at the bottom  → normal mode (the default)',
    \    '  - ":" prompt at the bottom    → command mode (Ex command)',
    \    '',
    \    'Press <Space> to begin.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'normal', 'expected_motion': 'normal', 'optimal_motions': 6,
    \  'prompt': [
    \    'No "-- TYPE --" indicator at the bottom; cursor is a solid block.',
    \    'This is NORMAL mode — the default vim starts in.',
    \    '',
    \    '    (no indicator)']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'insert', 'expected_motion': 'insert', 'optimal_motions': 6,
    \  'prompt': [
    \    'Bottom of the screen shows "-- INSERT --".',
    \    'Typing now adds characters to the buffer.',
    \    '',
    \    '    -- INSERT --']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'visual', 'expected_motion': 'visual', 'optimal_motions': 6,
    \  'prompt': [
    \    'Bottom of the screen shows "-- VISUAL --".',
    \    'A range of text is selected; the next operator applies to it.',
    \    '',
    \    '    -- VISUAL --']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'replace', 'expected_motion': 'replace', 'optimal_motions': 7,
    \  'prompt': [
    \    'Bottom of the screen shows "-- REPLACE --".',
    \    'Typing overwrites existing characters instead of inserting.',
    \    '',
    \    '    -- REPLACE --']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': 'command', 'expected_motion': 'command', 'optimal_motions': 7,
    \  'prompt': [
    \    'Cursor is on a ":" line at the bottom — this is COMMAND mode.',
    \    'You type Ex commands here (e.g. :w, :q, :s/foo/bar/).',
    \    '',
    \    '    :_']},
    \ ]
endfunction

function! vimfluency#pinpoints#pT0_5#generate() abort
  let pick = s:items[s:rand(len(s:items))]
  let prompt_lines = [
    \ '  Name the mode shown at the bottom of the screen (one word, lowercase):',
    \ '',
    \ '    ' . pick.cue,
    \ ]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'prompt': prompt_lines,
    \ 'expected_answer': pick.answer,
    \ 'expected_motion': pick.answer,
    \ 'optimal_motions': len(pick.answer),
    \ }
endfunction
