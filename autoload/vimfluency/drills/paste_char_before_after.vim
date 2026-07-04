" paste_char_before_after — charwise p vs P: paste a yanked word AFTER
" the cursor (p) or BEFORE it (P). The charwise paste-family analog of
" insert_before_after_char's a/i, and it borrows that drill's cue exactly.
"
" The register is pre-loaded with the word (as if you'd just yiw'd it —
" the lesson intro shows the yank; the drill itself isolates the p/P
" discrimination). A ▶◀ indicator marks the seam where the word should
" land:
"   cursor under ▶ (left of the seam)  → p  (paste after the cursor)
"   cursor under ◀ (right of the seam) → P  (paste before the cursor)
"
" Both correct answers drop the word at the SAME seam — identical buffer
" AND cursor — so, like insert_before_after_char, the item fixes the
" cursor on one side of the seam and the learner reads the indicator to
" pick the key. The WRONG key lands the word one column off (a different
" buffer), so buffer-state credit discriminates.
"
" kind 'editing': normal-mode p/P change the buffer; on_change credits on
" buffer + cursor. enter_at_col is set only to drive the shared ▶◀
" indicator (s:mode_gap_indicator) — the mode-kind enter_at_col credit
" checks never run for editing kind. register_payload pre-seeds @\".
"
" Measurement: one paste = one event → optimal 1. Tokens are literal, so
" stroke_count reads p=1, P=2 (Shift).

let s:PAYLOAD = 'foo'
let s:lines = [
  \ 'the quick fox',
  \ 'vim edits fast',
  \ 'jump over here',
  \ 'save the file',
  \ ]

function! vimfluency#drills#paste_char_before_after#meta() abort
  return {'id': 'paste_char_before_after', 'name': 'paste word before / after cursor (p / P)',
    \ 'aim': 35, 'allowed_keys': 'pP', 'kind': 'editing',
    \ 'prereqs': ['paste_line_below_above'], 'keys': 'p/P', 'family': 'paste',
    \ 'test_sequence': ['p', 'P']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#drills#paste_char_before_after#generate() abort
  let line = s:lines[s:rand(len(s:lines))]
  let L = len(line)
  " Seam between column k and k+1, kept interior so both the ▶ column (k)
  " and the ◀ column (k+1) are real cells and the paste isn't at an edge.
  let k = 2 + s:rand(L - 3)      " k in [2, L-2]

  " The word lands at the seam either way (p from the left, P from the
  " right) — same buffer, same cursor.
  let target_line = strpart(line, 0, k) . s:PAYLOAD . strpart(line, k)
  let target_col = k + len(s:PAYLOAD)

  let is_p = s:rand(2) == 0
  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, is_p ? k : k + 1],
    \ 'target': [1, target_col],
    \ 'enter_at_col': k + 1,
    \ 'register_payload': s:PAYLOAD,
    \ 'prompt': printf('Paste "%s" at the seam: p if the cursor is under ▶, P if under ◀.', s:PAYLOAD),
    \ 'expected_motion': is_p ? 'p' : 'P',
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#paste_char_before_after#lesson() abort
  let t = s:PAYLOAD
  " line1 'the quick fox': seam k=3 (after "the"). line2 'vim edits fast':
  " seam k=9 (after "edits").
  return [
    \ {'kind': 'show', 'lines': ['the quick fox'], 'cursor': [1, 3],
    \  'prompt': [
    \    printf('Say you yanked a word with yiw — it''s in the register (here: "%s").', t),
    \    'Paste it either side of the cursor:',
    \    '',
    \    '    p   →   paste AFTER the cursor   (cursor under ▶)',
    \    '    P   →   paste BEFORE the cursor  (cursor under ◀)',
    \    '',
    \    'The ▶◀ marks the seam — you''ll see it on the next screen.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['the quick fox'], 'start': [1, 3], 'target': [1, 6],
    \  'enter_at_col': 4, 'register_payload': t,
    \  'target_lines': ['thefoo quick fox'],
    \  'expected_motion': 'p', 'optimal_motions': 1,
    \  'prompt': 'Cursor under ▶ → press p (paste after).'},
    \ {'kind': 'try', 'lines': ['the quick fox'], 'start': [1, 4], 'target': [1, 6],
    \  'enter_at_col': 4, 'register_payload': t,
    \  'target_lines': ['thefoo quick fox'],
    \  'expected_motion': 'P', 'optimal_motions': 1,
    \  'prompt': 'Cursor under ◀ → press P (paste before).'},
    \ {'kind': 'try', 'lines': ['vim edits fast'], 'start': [1, 9], 'target': [1, 12],
    \  'enter_at_col': 10, 'register_payload': t,
    \  'target_lines': ['vim editsfoo fast'],
    \  'expected_motion': 'p', 'optimal_motions': 1,
    \  'prompt': 'Under ▶ → p.'},
    \ {'kind': 'try', 'lines': ['vim edits fast'], 'start': [1, 10], 'target': [1, 12],
    \  'enter_at_col': 10, 'register_payload': t,
    \  'target_lines': ['vim editsfoo fast'],
    \  'expected_motion': 'P', 'optimal_motions': 1,
    \  'prompt': 'Under ◀ → P.'},
    \ ]
endfunction
