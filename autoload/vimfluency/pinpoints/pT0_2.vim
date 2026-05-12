" T0.2 — Open new line. The two openers: o (below) and O (above),
" plus the closing Esc.
"
" Probe shape: mode kind. Like T0.1 but the buffer changes when the
" key fires — o/O insert a blank line. The runner credits when:
"   1. InsertEnter fires at the new line's (row, col 1),
"   2. target_lines matches the post-open buffer state,
"   3. post-Esc cursor lands at item.target.
"
" Discrimination, by direction-from-cursor:
"   - o → blank line BELOW the cursor's line
"   - O → blank line ABOVE the cursor's line
" Both produce the same final buffer state when paired with the
" appropriate starting line — the differentiator is which line the
" cursor began on.
"
" Cheat-defense:
"   - o items: cursor starts on line 1 of a 2-line buffer. Pressing o
"     adds line 2 (blank) and pushes 'def' to line 3 → target_lines.
"     Pressing O from line 1 instead would push 'abc' down → buffer
"     ['', 'abc', 'def'] (mismatch).
"   - O items: cursor starts on line 2 of a 2-line buffer. Pressing O
"     adds line 2 (blank), pushes 'def' to line 3 → target_lines.
"     Pressing o from line 2 puts the blank at the bottom →
"     ['abc', 'def', ''] (mismatch).
"   - Cheat path `jO` for an o-item (move down then O above the new
"     position) — same end state, 3 motions vs optimal 2; rate
"     penalty is the disincentive.
"
" Lines chosen are short, distinct, lowercase: enough that the learner
" can read the buffer state at a glance.

let s:line_pairs = [
  \ ['abc', 'def'],
  \ ['foo', 'bar'],
  \ ['hello', 'world'],
  \ ['print', 'value'],
  \ ['open', 'close'],
  \ ]

function! vimfluency#pinpoints#pT0_2#meta() abort
  " Catalog aim 40/min. Slightly below T0.1's 50 because the buffer
  " change makes the cue (and any failure) more visible — there's
  " more for the eye to verify before committing.
  return {'id': 'T0.2', 'name': 'open new line (o / O)',
    \ 'aim': 40, 'allowed_keys': 'oO<Esc>', 'kind': 'mode',
    \ 'prereqs': ['T0.1']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#pT0_2#generate() abort
  let pair = s:line_pairs[s:rand(len(s:line_pairs))]
  let key = ['o', 'O'][s:rand(2)]
  " Both keys produce the same 3-line target state ([pair[0], '', pair[1]])
  " — only the starting cursor row differs. That's the cheat-defense:
  " the WRONG key from the same start row produces a different buffer.
  let target_lines = [pair[0], '', pair[1]]
  if key ==# 'o'
    let start_row = 1
    let prompt = 'Open a new line BELOW the current line, then leave insert (Esc).'
  else
    let start_row = 2
    let prompt = 'Open a new line ABOVE the current line, then leave insert (Esc).'
  endif
  " hide_target: opt out of the green-cell target. T0.2's post-action
  " target sits on a brand-new blank line that doesn't exist
  " pre-action; if we asked matchaddpos to paint at [2, 1] before the
  " key is pressed, it'd highlight 'd' of 'def' (for o items) which
  " is misleading, and it would be invisible after the open (empty
  " cell). The directional prompt is the cue for T0.2.
  return {
    \ 'lines': pair,
    \ 'start': [start_row, 1],
    \ 'enter_at_row': 2,
    \ 'enter_at_col': 1,
    \ 'target_lines': target_lines,
    \ 'target': [2, 1],
    \ 'hide_target': 1,
    \ 'expected_motion': key,
    \ 'optimal_motions': 2,
    \ 'prompt': prompt,
    \ }
endfunction
