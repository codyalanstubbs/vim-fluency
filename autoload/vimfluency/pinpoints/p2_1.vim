" 2.1 — Delete line (dd). The d operator in linewise form. First
" pinpoint in the catalog where d is introduced as a standalone
" skill; before this, d only appeared inside the 4.1 composite,
" which made the 4.1 lesson the de-facto place d got taught.
"
" Tier 2 design note: this is a single-response fluency pinpoint,
" not a juxtaposition discrimination. The user always produces dd;
" the variation is in cursor line position and buffer content. PT
" supports both genres — discrimination probes build read-and-pick
" speed, fluency probes build motor speed on a known response.
" Cross-operator discrimination (d vs c) belongs in a separate
" disc probe (2.D, not yet built).
"
" Cheat-defense:
"   - dd is the canonical motion-event-minimum answer for "delete
"     the cursor's current line." Visual+d (Vd) takes one extra
"     event; count-prefixed dd (1dd) takes more keystrokes for the
"     same result.
"   - Lines vary in content (random word combinations) so the user
"     has to read the buffer rather than memorize positions.
"   - Cursor position varies across lines and within columns of
"     each line.

let s:words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon',
  \ 'zeta', 'eta', 'theta', 'iota', 'kappa']

function! vimfluency#pinpoints#p2_1#meta() abort
  return {'id': '2.1', 'name': 'delete line (dd)',
    \ 'aim': 50, 'allowed_keys': 'd', 'kind': 'editing',
    \ 'prereqs': ['T0']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_line() abort
  let n = 2 + s:rand(2)  " 2 or 3 words
  let words = []
  for _ in range(n)
    call add(words, s:words[s:rand(len(s:words))])
  endfor
  return join(words, ' ')
endfunction

function! vimfluency#pinpoints#p2_1#generate() abort
  let n_lines = 4 + s:rand(3)  " 4–6 lines
  let lines = []
  let seen = {}
  while len(lines) < n_lines
    let l = s:make_line()
    if !has_key(seen, l)
      let seen[l] = 1
      call add(lines, l)
    endif
  endwhile

  " Cursor on some line K, at any column on that line.
  let K = 1 + s:rand(n_lines)
  let cursor_col = 1 + s:rand(len(lines[K - 1]))

  " After dd of line K:
  "   K < n_lines  → cursor lands on (new) line K, col 1
  "   K == n_lines → cursor lands on (new) last line K-1, col 1
  " Use remove() rather than slice concat — vim slices are end-
  " inclusive, so lines[:K-2] for K=1 evaluates to the full list.
  let target_lines = copy(lines)
  call remove(target_lines, K - 1)
  let target_line = K < n_lines ? K : K - 1

  return {
    \ 'lines': lines,
    \ 'target_lines': target_lines,
    \ 'start': [K, cursor_col],
    \ 'target': [target_line, 1],
    \ 'deletion_range': [[K, 1, len(lines[K - 1])]],
    \ 'prompt': 'Press dd to delete the highlighted line.',
    \ 'expected_motion': 'dd',
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#pinpoints#p2_1#lesson() abort
  " The d operator alone waits for a motion (Tier 4 territory). The
  " linewise shortcut is to double the operator. The lesson teaches
  " that doubling rule and exercises it on a few cursor positions
  " including the last-line edge case where the cursor jumps up.
  let buf3 = ['alpha', 'beta', 'gamma']
  let after2 = ['alpha', 'gamma']
  let buf4 = ['alpha', 'beta', 'gamma', 'delta']
  let after_last = ['alpha', 'beta', 'gamma']
  let buf5 = ['alpha', 'beta', 'gamma', 'delta', 'epsilon']
  let after_mid = ['alpha', 'beta', 'delta', 'epsilon']
  return [
    \ {'kind': 'show', 'lines': buf3, 'cursor': [2, 1],
    \  'prompt': 'd is the delete operator. Doubling it — dd — deletes the entire line under the cursor.'},
    \ {'kind': 'try', 'lines': buf3, 'start': [2, 1], 'target': [2, 1],
    \  'target_lines': after2,
    \  'deletion_range': [[2, 1, len(buf3[1])]],
    \  'prompt': 'Press dd to delete the highlighted line.'},
    \ {'kind': 'try', 'lines': buf5, 'start': [3, 1], 'target': [3, 1],
    \  'target_lines': after_mid,
    \  'deletion_range': [[3, 1, len(buf5[2])]],
    \  'prompt': 'Press dd. After deletion, the cursor lands at the start of what is now the next line.'},
    \ {'kind': 'try', 'lines': buf4, 'start': [4, 1], 'target': [3, 1],
    \  'target_lines': after_last,
    \  'deletion_range': [[4, 1, len(buf4[3])]],
    \  'prompt': 'When you delete the last line, the cursor lands on the new last line. Press dd.'},
    \ ]
endfunction
