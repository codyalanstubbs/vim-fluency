" delete_to_word_start_forward_backward — delete with word motion (dw, db). The first real Tier-4
" composite training: the user must recognize, from the highlighted
" deletion range and their cursor position, which motion describes
" the range. The runner intentionally hides the green target cell for
" editing-kind training sessions — the deletion range alone is the cue, and the
" discrimination is "where is red relative to my cursor?" rather than
" "is a green cell visible?".
"
" Design constraints:
"   - single line of plain words separated by single spaces
"   - cursor anywhere in a word V (start, middle, end). Mid-word use
"     is real-world: dw from mid-word deletes the rest of V plus the
"     trailing space; db from mid-word deletes the prefix of V from
"     start-of-word to cursor exclusive.
"   - dw cases: deletion starts AT cursor, extends forward to start of
"     next word.
"   - db cases at start-of-V: deletion is word V-1 + trailing space,
"     ending one column before cursor.
"   - db cases mid-V: deletion is the prefix of V from start-of-word
"     to cursor exclusive (a prefix-fragment delete).
"   - in all cases the same cursor position can map to either dw or db
"     depending on which side of the cursor red is highlighted, so the
"     learner can't shortcut by cursor inspection alone.
"
" v1 ships dw and db only. de and dge added later — they introduce
" awkward whitespace cases (de from start-of-word leaves a double space)
" that need their own design pass.

let s:words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon',
  \ 'zeta', 'eta', 'theta', 'iota', 'kappa']

function! vimfluency#pinpoints#delete_to_word_start_forward_backward#meta() abort
  return {'id': 'delete_to_word_start_forward_backward', 'name': 'delete with word motion (dw, db)',
    \ 'aim': 60, 'allowed_keys': 'dwb', 'kind': 'editing',
    \ 'prereqs': ['discriminate_delete_char_vs_line', 'move_to_word_start_forward_backward'],
    \ 'parallel_to': ['delete_to_line_edges_beginning_end', 'delete_single_char_left_right'], 'keys': 'dw/db', 'family': 'delete'}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#delete_to_word_start_forward_backward#generate() abort
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

  " 1-indexed start/end col of each word
  let starts = []
  let ends = []
  let col = 1
  for w in words
    call add(starts, col)
    call add(ends, col + len(w) - 1)
    let col += len(w) + 1
  endfor

  " Pick motion. dw needs a word after V; db needs a word before V.
  let motion = s:rand(2) == 0 ? 'dw' : 'db'

  if motion ==# 'dw'
    " V in [1, n-1]; cursor anywhere in V; deletion = [cursor, starts[V]).
    let V = 1 + s:rand(n_words - 1)
    let s_v = starts[V - 1]
    let e_v = ends[V - 1]
    let cursor_col = s_v + s:rand(e_v - s_v + 1)
    let del_start = cursor_col
    let del_len = starts[V] - cursor_col
    let target_col = cursor_col   " dw leaves cursor put
  else
    " db: V in [2, n]; cursor anywhere in V.
    "   cursor at start-of-V → deletion = word V-1 + trailing space
    "   cursor mid-V         → deletion = prefix of V (start-of-V to
    "                          cursor exclusive)
    let V = 2 + s:rand(n_words - 1)
    let s_v = starts[V - 1]
    let e_v = ends[V - 1]
    let cursor_col = s_v + s:rand(e_v - s_v + 1)
    if cursor_col == s_v
      let del_start = starts[V - 2]
      let del_len = starts[V - 1] - starts[V - 2]
    else
      let del_start = s_v
      let del_len = cursor_col - s_v
    endif
    let target_col = del_start   " db lands cursor where deletion began
  endif

  " Compute target line by splicing out [del_start, del_start+del_len-1].
  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

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

function! vimfluency#pinpoints#delete_to_word_start_forward_backward#lesson() abort
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
    \  'target_lines': ['alpha beta delta'],
    \  'deletion_range': [[1, 12, 6]],
    \  'prompt': 'Press dw — deletes gamma + trailing space (current word). Cursor stays put.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 12], 'target': [1, 7],
    \  'target_lines': ['alpha gamma delta'],
    \  'deletion_range': [[1, 7, 5]],
    \  'prompt': 'Press db — deletes beta + trailing space (previous word). Cursor jumps back.'},
    \ {'kind': 'show', 'lines': ['edit me; mistakes happen.'], 'cursor': [1, 1],
    \  'prompt': 'Pressed the wrong motion? u undoes. The training is free-operant — keep editing until the buffer matches.'},
    \ {'kind': 'try', 'lines': ['one two three four five'], 'start': [1, 9], 'target': [1, 9],
    \  'target_lines': ['one two four five'],
    \  'deletion_range': [[1, 9, 6]],
    \  'prompt': 'Use dw to delete three.'},
    \ {'kind': 'try', 'lines': ['one two three four five'], 'start': [1, 9], 'target': [1, 5],
    \  'target_lines': ['one three four five'],
    \  'deletion_range': [[1, 5, 4]],
    \  'prompt': 'Use db to delete two.'},
    \ ]
endfunction
