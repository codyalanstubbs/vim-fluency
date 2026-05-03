" 4.d — delete with word motion (dw, db). The first real Tier-4
" composite probe: the user must recognize, from the highlighted
" deletion range AND their cursor position, which motion describes
" the range. Same cursor position can map to either motion depending
" on what's being deleted, so the recognition isn't bypassable.
"
" Design constraints:
"   - single line of plain words separated by single spaces
"   - cursor at start of a word V; the deletion is *highlighted* in red
"   - if deletion = word V + trailing space, answer is dw
"   - if deletion = word V-1 + trailing space (preceding word), answer is db
"   - generator picks dw or db randomly; same buffer/cursor layout can
"     yield either, so the user can't shortcut by cursor inspection alone
"
" v1 ships dw and db only. de and dge added later — they introduce
" awkward whitespace cases (de from start-of-word leaves a double space)
" that need their own design pass.

let s:words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon',
  \ 'zeta', 'eta', 'theta', 'iota', 'kappa']

function! vimfluency#pinpoints#p4_d#meta() abort
  return {'id': '4.d', 'name': 'delete with word motion (dw, db)',
    \ 'aim': 60, 'allowed_keys': 'dwb', 'kind': 'editing'}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#p4_d#generate() abort
  let n_words = 5
  let words = []
  let used = {}
  while len(words) < n_words
    let w = s:words[s:rand(len(s:words))]
    if !has_key(used, w)
      let used[w] = 1
      call add(words, w)
    endif
  endwhile

  let line = join(words, ' ')

  " 1-indexed start col of each word
  let starts = []
  let col = 1
  for w in words
    call add(starts, col)
    let col += len(w) + 1
  endfor

  " Pick motion. dw needs a word after V; db needs a word before V.
  let motion = s:rand(2) == 0 ? 'dw' : 'db'

  if motion ==# 'dw'
    " V in [1, n-1]; cursor at start of V; delete word V + trailing space
    let V = 1 + s:rand(n_words - 1)
    let cursor_col = starts[V - 1]
    let del_start = starts[V - 1]
    let del_len = starts[V] - starts[V - 1]   " word V length + 1 (space)
    let removed_idx = V - 1
  else
    " V in [2, n]; cursor at start of V; delete word V-1 + trailing space
    let V = 2 + s:rand(n_words - 1)
    let cursor_col = starts[V - 1]
    let del_start = starts[V - 2]
    let del_len = starts[V - 1] - starts[V - 2]   " word V-1 + 1
    let removed_idx = V - 2
  endif

  " target_lines: words minus the removed one
  let kept = []
  for i in range(n_words)
    if i != removed_idx
      call add(kept, words[i])
    endif
  endfor
  let target_line = join(kept, ' ')

  " target cursor col: same as deletion start — cursor lands at where
  " the deletion began (forward dw → stays put; backward db → jumps back)
  let target_col = del_start

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, target_col],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted range using d + a word motion.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#pinpoints#p4_d#lesson() abort
  " Teaches the d-operator + word-motion composition rule, focusing on
  " the dw/db discrimination. The opening show frame names the meta-rule
  " (no specific motion to demo); the dw/db demos are try frames so the
  " learner performs the deletion and watches the buffer change. The
  " "u undoes" tip is a show frame because there's no motion involved
  " in the rule itself.
  let buf = ['alpha beta gamma delta']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 12],
    \  'prompt': 'd takes a motion. The motion names a range from cursor; d deletes that range.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 12], 'target': [1, 12],
    \  'prompt': 'Press dw — deletes gamma + trailing space (current word). Cursor stays put.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 12], 'target': [1, 7],
    \  'prompt': 'Press db — deletes beta + trailing space (previous word). Cursor jumps back.'},
    \ {'kind': 'show', 'lines': ['edit me; mistakes happen.'], 'cursor': [1, 1],
    \  'prompt': 'Pressed the wrong motion? u undoes. The probe is free-operant — keep editing until the buffer matches.'},
    \ {'kind': 'try', 'lines': ['one two three four five'], 'start': [1, 9], 'target': [1, 9],
    \  'prompt': 'Use dw to delete three.'},
    \ {'kind': 'try', 'lines': ['one two three four five'], 'start': [1, 9], 'target': [1, 5],
    \  'prompt': 'Use db to delete two.'},
    \ ]
endfunction
