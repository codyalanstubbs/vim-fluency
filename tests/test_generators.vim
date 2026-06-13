" Property tests over each drill's generator. Generates many items and
" asserts structural invariants + the drill-specific optimal_motions
" formula and expected_motion vocabulary.

let s:N = 50

" Common structural invariants applied to every generator.
function! s:assert_common(id, item) abort
  let prefix = 'gen[' . a:id . ']: '
  let item = a:item
  call Assert(has_key(item, 'lines') && type(item.lines) == v:t_list,
    \ prefix . 'lines is a list')
  call Assert(has_key(item, 'start'), prefix . 'has start')
  call Assert(has_key(item, 'target'), prefix . 'has target')
  call Assert(has_key(item, 'expected_motion'), prefix . 'has expected_motion')
  call Assert(has_key(item, 'optimal_motions'), prefix . 'has optimal_motions')

  call Assert(!empty(item.expected_motion), prefix . 'expected_motion non-empty')
  call Assert(item.optimal_motions > 0, prefix . 'optimal_motions positive')
  " The training must require *something* — either cursor or buffer must change.
  let target_lines = get(item, 'target_lines', item.lines)
  call Assert(item.start != item.target || target_lines !=# item.lines,
    \ prefix . 'item requires cursor move or buffer change')

  let srow = item.start[0]
  let scol = item.start[1]
  call Assert(srow >= 1 && srow <= len(item.lines),
    \ prefix . 'start row in bounds (' . srow . '/' . len(item.lines) . ')')
  let sline = item.lines[srow - 1]
  call Assert(scol >= 1 && scol <= max([1, len(sline)]),
    \ prefix . 'start col in bounds (' . scol . '/' . len(sline) . ')')

  let trow = item.target[0]
  let tcol = item.target[1]
  " For editing-kind drills the cursor lands inside target_lines
  " (the post-edit buffer), not item.lines. For motion-only items
  " the two are the same. Always check against target_lines so
  " operations that lengthen the line (like indent_vs_dedent's >>) don't fail
  " the bound check against a shorter pre-edit line.
  let after_lines = get(item, 'target_lines', item.lines)
  call Assert(trow >= 1 && trow <= len(after_lines),
    \ prefix . 'target row in bounds (' . trow . '/' . len(after_lines) . ')')
  let tline = after_lines[trow - 1]
  call Assert(tcol >= 1 && tcol <= max([1, len(tline)]),
    \ prefix . 'target col in bounds (' . tcol . '/' . len(tline) . ')')
endfunction

" move_single_char_up_down_left_right: optimal_motions == manhattan(start, target);
" expected_motion ∈ {h, j, k, l, diag}
function! s:test_move_single_char_up_down_left_right() abort
  let GenFn = function('vimfluency#drills#move_single_char_up_down_left_right#generate')
  let valid = ['h', 'j', 'k', 'l', 'diag']
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_single_char_up_down_left_right', item)
    let manhattan = abs(item.target[0] - item.start[0])
      \ + abs(item.target[1] - item.start[1])
    call AssertEq(item.optimal_motions, manhattan,
      \ 'move_single_char_up_down_left_right: optimal_motions == manhattan(start, target)')
    call AssertIn(item.expected_motion, valid,
      \ 'move_single_char_up_down_left_right: expected_motion in {h,j,k,l,diag}')
  endfor
endfunction

" move_to_line_edges_all: optimal_motions == 1; expected_motion ∈ {0, ^, $, g_};
" target_col == 1 → motion is '0'; trailing whitespace items can be 'g_'.
function! s:test_move_to_line_edges_all() abort
  let GenFn = function('vimfluency#drills#move_to_line_edges_all#generate')
  let valid = ['0', '^', '$', 'g_']
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_to_line_edges_all', item)
    call AssertEq(item.optimal_motions, 1, 'move_to_line_edges_all: optimal_motions == 1')
    call AssertIn(item.expected_motion, valid,
      \ 'move_to_line_edges_all: expected_motion in {0, ^, $, g_}')

    " Cross-check label vs target position
    let line = item.lines[0]
    let llen = len(line)
    let tcol = item.target[1]
    if tcol == 1
      call AssertEq(item.expected_motion, '0',
        \ 'move_to_line_edges_all: target_col == 1 implies motion == 0')
    elseif tcol == llen
      let stripped = substitute(line, '\s\+$', '', '')
      let last_nonblank = empty(stripped) ? llen : len(stripped)
      if last_nonblank == llen
        call AssertEq(item.expected_motion, '$',
          \ 'move_to_line_edges_all: target_col == llen with no trailing ws implies $')
      endif
    endif
  endfor
endfunction

" move_to_word_start_forward_backward: expected_motion ∈ {w, b}; optimal_motions == dist (which is
" the same as the manhattan word-distance, in [2, 4]).
function! s:test_move_to_word_start_forward_backward() abort
  let GenFn = function('vimfluency#drills#move_to_word_start_forward_backward#generate')
  let valid = ['w', 'b']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_to_word_start_forward_backward', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_to_word_start_forward_backward: expected_motion in {w, b}')
    call Assert(item.optimal_motions >= 2 && item.optimal_motions <= 4,
      \ 'move_to_word_start_forward_backward: optimal_motions in [2, 4], got ' . item.optimal_motions)
    let seen[item.expected_motion] = 1
  endfor
  call Assert(get(seen, 'w', 0) == 1, 'move_to_word_start_forward_backward: w appeared in samples')
  call Assert(get(seen, 'b', 0) == 1, 'move_to_word_start_forward_backward: b appeared in samples')
endfunction

" move_to_word_end_forward_backward: expected_motion ∈ {e, ge}; optimal_motions == dist+1 for
" forward (e), dist for backward (ge). Range [2, 5].
function! s:test_move_to_word_end_forward_backward() abort
  let GenFn = function('vimfluency#drills#move_to_word_end_forward_backward#generate')
  let valid = ['e', 'ge']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_to_word_end_forward_backward', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_to_word_end_forward_backward: expected_motion in {e, ge}')
    call Assert(item.optimal_motions >= 2 && item.optimal_motions <= 5,
      \ 'move_to_word_end_forward_backward: optimal_motions in [2, 5], got ' . item.optimal_motions)

    " Forward (e): one extra motion beyond word distance because the
    " first e lands at end of current word.
    " Backward (ge): one motion per word stepped.
    if item.expected_motion ==# 'e'
      call Assert(item.target[1] > item.start[1],
        \ 'move_to_word_end_forward_backward/e: target col > start col (forward)')
    else
      call Assert(item.target[1] < item.start[1],
        \ 'move_to_word_end_forward_backward/ge: target col < start col (backward)')
    endif
    let seen[item.expected_motion] = 1
  endfor
  call Assert(get(seen, 'e', 0) == 1, 'move_to_word_end_forward_backward: e appeared in samples')
  call Assert(get(seen, 'ge', 0) == 1, 'move_to_word_end_forward_backward: ge appeared in samples')
endfunction

" delete_char_vs_line: editing-kind discrimination training. expected_motion ∈ {x, dd}.
" 2-line buffer where the cursor starts at col 1 of one line and
" the highlight lives on the OTHER line — single char (col 1) for
" x items, full line for dd items. Each item is a 2-event sequence:
" j or k to navigate, then the operator. Both motions appear over
" many samples and both navigation directions are exercised.
function! s:test_delete_char_vs_line() abort
  let GenFn = function('vimfluency#drills#delete_char_vs_line#generate')
  let valid = ['x', 'dd']
  let seen = {}
  let nav_dirs = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('delete_char_vs_line', item)
    call AssertIn(item.expected_motion, valid,
      \ 'delete_char_vs_line: expected_motion in {x, dd}')
    call AssertEq(item.optimal_motions, 2,
      \ 'delete_char_vs_line: optimal_motions == 2 (1 nav + 1 operator)')

    call AssertEq(len(item.lines), 2, 'delete_char_vs_line: two-line buffer')
    call Assert(has_key(item, 'target_lines'), 'delete_char_vs_line: has target_lines')
    call Assert(has_key(item, 'deletion_range'), 'delete_char_vs_line: has deletion_range')

    " Cursor always starts at col 1.
    call AssertEq(item.start[1], 1, 'delete_char_vs_line: cursor starts at col 1')

    let cursor_line = item.start[0]
    let target_line_idx = cursor_line == 1 ? 2 : 1
    let dr = item.deletion_range[0]

    " Highlight is on the line opposite the cursor.
    call AssertEq(dr[0], target_line_idx,
      \ 'delete_char_vs_line: highlight is on the line opposite the cursor')

    let target_text = item.lines[target_line_idx - 1]
    let target_len = len(target_text)

    if item.expected_motion ==# 'dd'
      " dd: highlight covers the entire target line; after j/k + dd
      " the target line is gone, the cursor's original line is the
      " only buffer row, cursor lands at line 1 col 1.
      call AssertEq(len(item.target_lines), 1,
        \ 'delete_char_vs_line/dd: target buffer is the surviving line only')
      let surviving = item.lines[cursor_line - 1]
      call AssertEq(item.target_lines[0], surviving,
        \ 'delete_char_vs_line/dd: surviving line is the cursor''s original line')
      call AssertEq(item.target, [1, 1],
        \ 'delete_char_vs_line/dd: cursor lands at line 1 col 1')
      call AssertEq(dr, [target_line_idx, 1, target_len],
        \ 'delete_char_vs_line/dd: deletion_range covers the entire target line')
    else
      " x: highlight is single char at col 1 of target line. j/k
      " preserves column, lands cursor on the highlighted char,
      " then x deletes one char.
      call AssertEq(len(item.target_lines), 2,
        \ 'delete_char_vs_line/x: target preserves both lines')
      call AssertEq(len(item.target_lines[target_line_idx - 1]),
        \ target_len - 1,
        \ 'delete_char_vs_line/x: target line is one char shorter')
      let other = item.lines[cursor_line - 1]
      call AssertEq(item.target_lines[cursor_line - 1], other,
        \ 'delete_char_vs_line/x: cursor''s original line is unchanged')
      call AssertEq(dr, [target_line_idx, 1, 1],
        \ 'delete_char_vs_line/x: deletion_range is one char at col 1 of target line')
      call AssertEq(item.target, [target_line_idx, 1],
        \ 'delete_char_vs_line/x: cursor ends at col 1 of target line')
    endif
    let seen[item.expected_motion] = 1
    let nav_dirs[cursor_line == 1 ? 'down' : 'up'] = 1
  endfor
  call Assert(get(seen, 'x', 0) == 1, 'delete_char_vs_line: x appeared in samples')
  call Assert(get(seen, 'dd', 0) == 1, 'delete_char_vs_line: dd appeared in samples')
  call Assert(get(nav_dirs, 'down', 0) == 1,
    \ 'delete_char_vs_line: items where the user navigates down (j) appeared')
  call Assert(get(nav_dirs, 'up', 0) == 1,
    \ 'delete_char_vs_line: items where the user navigates up (k) appeared')
endfunction

" indent_vs_dedent: indent/dedent discrimination. 2-line buffer; line 1 is the
" active line, line 2 is the reference. They differ by 1 or 2
" shiftwidths in the picked direction. Both motions and both step
" counts appear over many samples.
function! s:test_indent_vs_dedent() abort
  let GenFn = function('vimfluency#drills#indent_vs_dedent#generate')
  let SW = 4
  let valid = ['>>', '<<']
  let seen = {}
  let step_counts = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('indent_vs_dedent', item)
    call AssertIn(item.expected_motion, valid,
      \ 'indent_vs_dedent: expected_motion in {>>, <<}')
    call AssertIn(item.optimal_motions, [1, 2],
      \ 'indent_vs_dedent: optimal_motions in {1, 2}')

    call AssertEq(len(item.lines), 2, 'indent_vs_dedent: 2-line buffer')
    call AssertEq(len(item.target_lines), 2, 'indent_vs_dedent: target also 2-line')

    " Line 2 (reference) is unchanged in target.
    call AssertEq(item.target_lines[1], item.lines[1],
      \ 'indent_vs_dedent: line 2 reference is not modified')

    " Cursor starts on line 1 at first non-blank, lands on line 1 at
    " first non-blank of the new indent.
    call AssertEq(item.start[0], 1, 'indent_vs_dedent: cursor starts on line 1')
    call AssertEq(item.target[0], 1, 'indent_vs_dedent: cursor lands on line 1')

    " Indent difference between line 1 and line 2 is steps × SW.
    let l1_indent = match(item.lines[0], '\S')
    let l2_indent = match(item.lines[1], '\S')
    let diff = l2_indent - l1_indent
    let signed = item.expected_motion ==# '>>'
      \ ? item.optimal_motions * SW
      \ : -1 * item.optimal_motions * SW
    call AssertEq(diff, signed,
      \ 'indent_vs_dedent: line 2 indent matches signed steps × shiftwidth')

    " After the operation, line 1's indent equals line 2's.
    let new_l1_indent = match(item.target_lines[0], '\S')
    call AssertEq(new_l1_indent, l2_indent,
      \ 'indent_vs_dedent: line 1 target indent matches line 2')

    " Indents stay non-negative and within the bounded range.
    call Assert(l1_indent >= 0, 'indent_vs_dedent: line 1 indent non-negative')
    call Assert(l2_indent >= 0, 'indent_vs_dedent: line 2 indent non-negative')
    call Assert(l1_indent <= 12 && l2_indent <= 12,
      \ 'indent_vs_dedent: indents capped at 12 spaces')
    let seen[item.expected_motion] = 1
    let step_counts[item.optimal_motions] = 1
  endfor
  call Assert(get(seen, '>>', 0) == 1, 'indent_vs_dedent: >> appeared in samples')
  call Assert(get(seen, '<<', 0) == 1, 'indent_vs_dedent: << appeared in samples')
  call Assert(get(step_counts, 1, 0) == 1, 'indent_vs_dedent: 1-step items appeared')
  call Assert(get(step_counts, 2, 0) == 1, 'indent_vs_dedent: 2-step items appeared')
endfunction

" delete_to_word_start_forward_backward: editing kind; expected_motion ∈ {dw, db}; deletion_range matches
" the actual delta between start_lines and target_lines.
function! s:test_delete_to_word_start_forward_backward() abort
  let GenFn = function('vimfluency#drills#delete_to_word_start_forward_backward#generate')
  let valid = ['dw', 'db']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('delete_to_word_start_forward_backward', item)
    call AssertIn(item.expected_motion, valid,
      \ 'delete_to_word_start_forward_backward: expected_motion in {dw, db}')
    call AssertEq(item.optimal_motions, 1, 'delete_to_word_start_forward_backward: optimal_motions == 1')
    let seen[item.expected_motion] = 1

    " editing-kind invariants
    call Assert(has_key(item, 'target_lines'), 'delete_to_word_start_forward_backward: has target_lines')
    call Assert(has_key(item, 'deletion_range'), 'delete_to_word_start_forward_backward: has deletion_range')
    call Assert(!empty(item.deletion_range), 'delete_to_word_start_forward_backward: deletion_range non-empty')

    " Some chars must have been removed (target line is shorter than start).
    " Word count is no longer asserted: db from mid-word leaves a
    " prefix-fragment of the current word, so word count can stay equal.
    call Assert(len(item.target_lines[0]) < len(item.lines[0]),
      \ 'delete_to_word_start_forward_backward: target_lines is shorter than lines')

    " deletion_range length should match the actual length removed
    let removed_chars = len(item.lines[0]) - len(item.target_lines[0])
    let total_len = 0
    for pos in item.deletion_range
      let total_len += pos[2]
    endfor
    call AssertEq(total_len, removed_chars,
      \ 'delete_to_word_start_forward_backward: deletion_range length matches chars actually removed')

    " for dw: target_cursor col == start_cursor col (cursor stays put)
    " for db: target_cursor col < start_cursor col (cursor jumps back)
    if item.expected_motion ==# 'dw'
      call AssertEq(item.target[1], item.start[1],
        \ 'delete_to_word_start_forward_backward/dw: target col == start col')
    else
      call Assert(item.target[1] < item.start[1],
        \ 'delete_to_word_start_forward_backward/db: target col < start col')
    endif
  endfor

  " Both motions should appear in 50 generates with high probability
  call Assert(get(seen, 'dw', 0) == 1, 'delete_to_word_start_forward_backward: dw appeared in samples')
  call Assert(get(seen, 'db', 0) == 1, 'delete_to_word_start_forward_backward: db appeared in samples')

  let meta = vimfluency#drills#delete_to_word_start_forward_backward#meta()
  call AssertEq(get(meta, 'kind', 'motion'), 'editing',
    \ 'delete_to_word_start_forward_backward: meta.kind == editing')
endfunction

" move_to_char_forward_backward: expected_motion ∈ {f, F}; optimal_motions == 1; target unique in
" line; target interior to its word (margin ≥2); cursor not on whitespace
" or target_char; distance ≥4 from cursor.
function! s:test_move_to_char_forward_backward() abort
  let GenFn = function('vimfluency#drills#move_to_char_forward_backward#generate')
  let valid = ['f', 'F']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_to_char_forward_backward', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_to_char_forward_backward: expected_motion in {f, F}')
    call AssertEq(item.optimal_motions, 1,
      \ 'move_to_char_forward_backward: optimal_motions == 1')
    call s:assert_till_shape_auto('move_to_char_forward_backward', item)

    let line = item.lines[0]
    let llen = len(line)
    let start_col = item.start[1]
    let target_col = item.target[1]
    let target_char = line[target_col - 1]
    let seen[item.expected_motion] = 1

    if item.expected_motion ==# 'f'
      call Assert(start_col < target_col,
        \ 'move_to_char_forward_backward/f: start_col < target_col')
    else
      call Assert(start_col > target_col,
        \ 'move_to_char_forward_backward/F: start_col > target_col')
    endif

    call Assert(abs(target_col - start_col) >= 4,
      \ 'move_to_char_forward_backward: distance ≥ 4 (cheat-defense vs hjkl chains)')

    call Assert(line[start_col - 1] !=# ' ',
      \ 'move_to_char_forward_backward: start not on whitespace')
    call Assert(line[start_col - 1] !=# target_char,
      \ 'move_to_char_forward_backward: start not on target_char')

    let count_target = 0
    for ci in range(llen)
      if line[ci] ==# target_char | let count_target += 1 | endif
    endfor
    call AssertEq(count_target, 1,
      \ 'move_to_char_forward_backward: target_char appears exactly once in line')

    let words_in_line = split(line, ' ')
    let cumcol = 1
    for w in words_in_line
      let ws = cumcol
      let we = cumcol + len(w) - 1
      if target_col >= ws && target_col <= we
        call Assert(target_col - ws >= 2,
          \ 'move_to_char_forward_backward: target ≥2 cols from word start')
        call Assert(we - target_col >= 2,
          \ 'move_to_char_forward_backward: target ≥2 cols from word end')
        break
      endif
      let cumcol += len(w) + 1
    endfor
  endfor

  call Assert(get(seen, 'f', 0) == 1, 'move_to_char_forward_backward: f appeared in samples')
  call Assert(get(seen, 'F', 0) == 1, 'move_to_char_forward_backward: F appeared in samples')
endfunction

" move_till_char_forward_backward: expected_motion ∈ {t, T}; optimal_motions == 1; the LANDING is
" target_col, the actual char is at target_col + 1 (forward) or
" target_col - 1 (backward). Char must be unique in line, interior to
" its word with direction-specific margins, and distance >= 3 from cursor.
function! s:test_move_till_char_forward_backward() abort
  let GenFn = function('vimfluency#drills#move_till_char_forward_backward#generate')
  let valid = ['t', 'T']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_till_char_forward_backward', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_till_char_forward_backward: expected_motion in {t, T}')
    call AssertEq(item.optimal_motions, 1,
      \ 'move_till_char_forward_backward: optimal_motions == 1')
    call s:assert_till_shape_auto('move_till_char_forward_backward', item)

    let line = item.lines[0]
    let llen = len(line)
    let start_col = item.start[1]
    let target_col = item.target[1]
    let seen[item.expected_motion] = 1

    if item.expected_motion ==# 't'
      call Assert(start_col < target_col,
        \ 'move_till_char_forward_backward/t: start_col < target_col')
      let target_char_col = target_col + 1
    else
      call Assert(start_col > target_col,
        \ 'move_till_char_forward_backward/T: start_col > target_col')
      let target_char_col = target_col - 1
    endif

    call Assert(target_char_col >= 1 && target_char_col <= llen,
      \ 'move_till_char_forward_backward: target_char_col in line bounds')
    let target_char = line[target_char_col - 1]
    call Assert(target_char !=# ' ',
      \ 'move_till_char_forward_backward: target_char is not whitespace')

    call Assert(abs(target_col - start_col) >= 3,
      \ 'move_till_char_forward_backward: distance >= 3 from cursor to landing')

    call Assert(line[start_col - 1] !=# ' ',
      \ 'move_till_char_forward_backward: start not on whitespace')
    call Assert(line[start_col - 1] !=# target_char,
      \ 'move_till_char_forward_backward: start not on target_char')

    let count_target = 0
    for ci in range(llen)
      if line[ci] ==# target_char | let count_target += 1 | endif
    endfor
    call AssertEq(count_target, 1,
      \ 'move_till_char_forward_backward: target_char appears exactly once in line')

    let words_in_line = split(line, ' ')
    let cumcol = 1
    for w in words_in_line
      let ws = cumcol
      let we = cumcol + len(w) - 1
      if target_char_col >= ws && target_char_col <= we
        if item.expected_motion ==# 't'
          call Assert(target_char_col - ws >= 3,
            \ 'move_till_char_forward_backward/t: target_char >= 3 cols from word start')
          call Assert(we - target_char_col >= 1,
            \ 'move_till_char_forward_backward/t: target_char >= 1 col from word end')
        else
          call Assert(target_char_col - ws >= 1,
            \ 'move_till_char_forward_backward/T: target_char >= 1 col from word start')
          call Assert(we - target_char_col >= 3,
            \ 'move_till_char_forward_backward/T: target_char >= 3 cols from word end')
        endif
        break
      endif
      let cumcol += len(w) + 1
    endfor
  endfor

  call Assert(get(seen, 't', 0) == 1, 'move_till_char_forward_backward: t appeared in samples')
  call Assert(get(seen, 'T', 0) == 1, 'move_till_char_forward_backward: T appeared in samples')
endfunction

" move_repeat_last_find_forward_backward: expected_motion in {; ,}; optimal_motions == 2; target interior
" to its word with margin >= 2; cursor positioned per-scenario; distance
" >= 3; exactly one waypoint at the canonical-sequence's first-stop.
function! s:test_move_repeat_last_find_forward_backward() abort
  let GenFn = function('vimfluency#drills#move_repeat_last_find_forward_backward#generate')
  let valid_motions = [';', ',']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_repeat_last_find_forward_backward', item)
    call AssertIn(item.expected_motion, valid_motions,
      \ 'move_repeat_last_find_forward_backward: expected_motion in {; ,}')
    call AssertEq(item.optimal_motions, 2,
      \ 'move_repeat_last_find_forward_backward: optimal_motions == 2')

    let line = item.lines[0]
    let llen = len(line)
    let start_col = item.start[1]
    let target_col = item.target[1]
    let target_char = line[target_col - 1]
    let seen[item.expected_motion] = 1

    call Assert(abs(target_col - start_col) >= 3,
      \ 'move_repeat_last_find_forward_backward: distance >= 3')
    call Assert(target_char !=# ' ',
      \ 'move_repeat_last_find_forward_backward: target_char is not whitespace')

    let cols_for_char = []
    for ci in range(llen)
      if line[ci] ==# target_char | call add(cols_for_char, ci + 1) | endif
    endfor
    call Assert(len(cols_for_char) >= 2,
      \ 'move_repeat_last_find_forward_backward: target_char appears >= 2 times in line')

    call Assert(has_key(item, 'waypoints'), 'move_repeat_last_find_forward_backward: item has waypoints')
    call AssertEq(len(item.waypoints), 1, 'move_repeat_last_find_forward_backward: exactly one waypoint')
    let wp_col = item.waypoints[0][1]
    call Assert(abs(target_col - wp_col) >= 2,
      \ 'move_repeat_last_find_forward_backward: target and waypoint at least 2 cols apart')

    if item.expected_motion ==# ';'
      if start_col < target_col
        " forward ; (fc;): cursor < cols[0]; target == cols[1];
        " waypoint == cols[0].
        call Assert(start_col < cols_for_char[0],
          \ 'move_repeat_last_find_forward_backward/forward;: start before first occurrence')
        call AssertEq(target_col, cols_for_char[1],
          \ 'move_repeat_last_find_forward_backward/forward;: target == second occurrence')
        call AssertEq(wp_col, cols_for_char[0],
          \ 'move_repeat_last_find_forward_backward/forward;: waypoint == first occurrence')
      else
        " backward ; (Fc;): cursor > cols[-1]; target == cols[-2];
        " waypoint == cols[-1].
        call Assert(start_col > cols_for_char[-1],
          \ 'move_repeat_last_find_forward_backward/backward;: start after last occurrence')
        call AssertEq(target_col, cols_for_char[-2],
          \ 'move_repeat_last_find_forward_backward/backward;: target == second-to-last occurrence')
        call AssertEq(wp_col, cols_for_char[-1],
          \ 'move_repeat_last_find_forward_backward/backward;: waypoint == last occurrence')
      endif
    else
      " , scenarios: cursor strictly between cols[0] and cols[1].
      call Assert(start_col > cols_for_char[0]
        \ && start_col < cols_for_char[1],
        \ 'move_repeat_last_find_forward_backward/,: cursor between cols[0] and cols[1]')
      if target_col == cols_for_char[0]
        " fc, : target == cols[0]; waypoint == cols[1].
        call AssertEq(wp_col, cols_for_char[1],
          \ 'move_repeat_last_find_forward_backward/fc,: waypoint == second occurrence')
      else
        " Fc, : target == cols[1]; waypoint == cols[0].
        call AssertEq(target_col, cols_for_char[1],
          \ 'move_repeat_last_find_forward_backward/Fc,: target == second occurrence')
        call AssertEq(wp_col, cols_for_char[0],
          \ 'move_repeat_last_find_forward_backward/Fc,: waypoint == first occurrence')
      endif
    endif

    call Assert(line[start_col - 1] !=# ' ',
      \ 'move_repeat_last_find_forward_backward: start not on whitespace')
    call Assert(line[start_col - 1] !=# target_char,
      \ 'move_repeat_last_find_forward_backward: start not on target_char')

    let words_in_line = split(line, ' ')
    let cumcol = 1
    for w in words_in_line
      let ws = cumcol
      let we = cumcol + len(w) - 1
      if target_col >= ws && target_col <= we
        call Assert(target_col - ws >= 2,
          \ 'move_repeat_last_find_forward_backward: target >= 2 cols from word start')
        call Assert(we - target_col >= 2,
          \ 'move_repeat_last_find_forward_backward: target >= 2 cols from word end')
        break
      endif
      let cumcol += len(w) + 1
    endfor
  endfor

  call Assert(get(seen, ';', 0) == 1, 'move_repeat_last_find_forward_backward: ; appeared in samples')
  call Assert(get(seen, ',', 0) == 1, 'move_repeat_last_find_forward_backward: , appeared in samples')
endfunction

" move_to_vs_till_forward_backward: delegates to move_to_char_forward_backward / move_till_char_forward_backward generators. Just verify all four
" motions appear over N samples and every item passes a baseline
" structural check.
function! s:test_move_to_vs_till_forward_backward() abort
  let GenFn = function('vimfluency#drills#move_to_vs_till_forward_backward#generate')
  let valid = ['f', 'F', 't', 'T']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_to_vs_till_forward_backward', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_to_vs_till_forward_backward: expected_motion in {f, F, t, T}')
    call AssertEq(item.optimal_motions, 1,
      \ 'move_to_vs_till_forward_backward: optimal_motions == 1')
    call s:assert_till_shape_auto('move_to_vs_till_forward_backward', item)
    let seen[item.expected_motion] = 1
  endfor
  for m in valid
    call Assert(get(seen, m, 0) == 1,
      \ 'move_to_vs_till_forward_backward: ' . m . ' appeared in samples')
  endfor
endfunction

" move_to_vs_till_forward — 2-cell atomic over {f, t}. The generator
" re-rolls the by-find/till underlying generators until a forward
" item lands, so every item should have expected_motion in {f, t}.
" Simulate F{ch} / T{ch} landings from col `from` (backward search):
" returns [F_landing, T_landing] (0 = char absent). Mirrors vim.
function! s:sim_backward(line, x_ch, y_ch, from) abort
  let f_land = 0
  let t_land = 0
  let c = a:from - 1
  while c >= 1
    if f_land == 0 && a:line[c - 1] ==# a:x_ch | let f_land = c | endif
    if t_land == 0 && a:line[c - 1] ==# a:y_ch | let t_land = c + 1 | endif
    if f_land && t_land | break | endif
    let c -= 1
  endwhile
  return [f_land, t_land]
endfunction

" Simulate f{ch} / t{ch} landings from col `from` (forward search).
function! s:sim_forward(line, x_ch, z_ch, from) abort
  let f_land = 0
  let t_land = 0
  let llen = len(a:line)
  let c = a:from + 1
  while c <= llen
    if f_land == 0 && a:line[c - 1] ==# a:x_ch | let f_land = c | endif
    if t_land == 0 && a:line[c - 1] ==# a:z_ch | let t_land = c - 1 | endif
    if f_land && t_land | break | endif
    let c += 1
  endwhile
  return [f_land, t_land]
endfunction

" Behavioral property shared by all four till drills (2026-06-11
" diary): the expected motion must land EXACTLY on the target, and
" the OTHER member of the pair must NOT — otherwise the item doesn't
" force the F-vs-T (f-vs-t) discrimination and the learner can answer
" everything with one motion.
function! s:assert_till_shape(id, item, backward) abort
  let prefix = a:id . ': '
  let line = a:item.lines[0]
  let L = a:item.target[1]
  let C = a:item.start[1]
  let X = line[L - 1]
  if a:backward
    let Y = line[L - 2]
    let [f_land, t_land] = s:sim_backward(line, X, Y, C)
  else
    let Z = line[L]
    let [f_land, t_land] = s:sim_forward(line, X, Z, C)
  endif
  let motion_lower = tolower(a:item.expected_motion)
  if motion_lower ==# 'f'
    call AssertEq(f_land, L,
      \ prefix . 'find-motion lands on target (line="' . line . '" L=' . L . ' C=' . C . ')')
    call Assert(t_land != L,
      \ prefix . 'till-motion must NOT land on target (line="' . line . '" L=' . L . ' C=' . C . ')')
  else
    call AssertEq(t_land, L,
      \ prefix . 'till-motion lands on target (line="' . line . '" L=' . L . ' C=' . C . ')')
    call Assert(f_land != L,
      \ prefix . 'find-motion must NOT land on target (line="' . line . '" L=' . L . ' C=' . C . ')')
  endif
  " Cursor never starts on either search char (would make the skim
  " read ambiguous).
  let cch = line[C - 1]
  call Assert(cch !=# X, prefix . 'cursor cell != target char')
  if a:backward
    call Assert(cch !=# line[L - 2], prefix . 'cursor cell != left-neighbor char')
  else
    call Assert(cch !=# line[L], prefix . 'cursor cell != right-neighbor char')
  endif
endfunction

" Variant for drills whose items mix directions: derive the
" backward flag from the motion's case (F/T backward, f/t forward).
function! s:assert_till_shape_auto(id, item) abort
  call s:assert_till_shape(a:id, a:item,
    \ a:item.expected_motion =~# '^[FT]$')
endfunction

function! s:test_till_pair(id, valid, backward, constant_geom) abort
  let GenFn = function('vimfluency#drills#' . a:id . '#generate')
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common(a:id, item)
    call AssertIn(item.expected_motion, a:valid,
      \ a:id . ': expected_motion in ' . string(a:valid))
    call AssertEq(item.optimal_motions, 1,
      \ a:id . ': optimal_motions == 1')
    call s:assert_till_shape(a:id, item, a:backward)
    if !empty(a:constant_geom)
      call AssertEq(item.start, a:constant_geom[0],
        \ a:id . ': constant cursor position')
      call AssertEq(item.target, a:constant_geom[1],
        \ a:id . ': constant target position')
      call AssertEq(len(item.lines[0]), a:constant_geom[2],
        \ a:id . ': constant line length')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for m in a:valid
    call Assert(get(seen, m, 0) == 1,
      \ a:id . ': ' . m . ' appeared in samples')
  endfor
endfunction

function! s:test_move_to_vs_till_forward() abort
  call s:test_till_pair('move_to_vs_till_forward', ['f', 't'], 0,
    \ [[1, 1], [1, 10], 15])
endfunction

function! s:test_move_to_vs_till_backward() abort
  call s:test_till_pair('move_to_vs_till_backward', ['F', 'T'], 1,
    \ [[1, 15], [1, 6], 15])
endfunction

function! s:test_move_to_vs_till_forward_in_words() abort
  call s:test_till_pair('move_to_vs_till_forward_in_words', ['f', 't'], 0, [])
endfunction

function! s:test_move_to_vs_till_backward_in_words() abort
  call s:test_till_pair('move_to_vs_till_backward_in_words', ['F', 'T'], 1, [])
endfunction

" --- recall and mode kinds -----------------------------------------
"
" Recall and mode kinds don't carry a live editing area (recall) or
" require a cursor move within an item (mode often doesn't, when the
" cursor returns to its start col after Esc). So they bypass
" s:assert_common — they have their own shape invariants.

" Common shape check for recall items. The 'command' kind (save/quit
" family) keeps the same answer/motion/optimal fields but renders via
" snippet+status_text+goal instead of a prompt — accept either.
function! s:assert_recall_common(id, item) abort
  let prefix = 'gen[' . a:id . ']: '
  let item = a:item
  call Assert(has_key(item, 'expected_answer')
    \ && type(item.expected_answer) == v:t_string
    \ && !empty(item.expected_answer),
    \ prefix . 'expected_answer is a non-empty string')
  call Assert(has_key(item, 'expected_motion')
    \ && !empty(item.expected_motion),
    \ prefix . 'expected_motion non-empty')
  call Assert(has_key(item, 'optimal_motions')
    \ && item.optimal_motions > 0,
    \ prefix . 'optimal_motions positive')
  let has_prompt = has_key(item, 'prompt')
  let has_command_shape = has_key(item, 'snippet') && has_key(item, 'goal')
  call Assert(has_prompt || has_command_shape,
    \ prefix . 'has prompt OR has snippet+goal')
endfunction

" save/quit family (save_vs_quit, save_quit_vs_force_quit,
" save_quit_vs_zz, force_quit_vs_zq) — binary
" discrimination drills. Each one picks between exactly two
" answers. expected_motion mirrors the answer; optimal_motions equals
" the answer's character count.
function! s:test_save_quit_pair(id, module, valid) abort
  let GenFn = function('vimfluency#drills#' . a:module . '#generate')
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_recall_common(a:id, item)
    call AssertIn(item.expected_answer, a:valid,
      \ a:id . ': expected_answer in declared pair')
    call AssertEq(item.expected_motion, item.expected_answer,
      \ a:id . ': expected_motion mirrors expected_answer')
    call AssertEq(item.optimal_motions, len(item.expected_answer),
      \ a:id . ': optimal_motions == len(expected_answer)')
    let seen[item.expected_answer] = 1
  endfor
  for a in a:valid
    call Assert(get(seen, a, 0) == 1,
      \ a:id . ': ' . a . ' appeared in samples')
  endfor
endfunction

" undo_redo — undo / redo. Editing kind with pre-staged undo history.
" Each item declares `history` (list of buffer states) and
" `start_index`; the runner stages the states into the buffer's
" undo log so 'u' / Ctrl-r have real targets.
function! s:test_undo_redo() abort
  let GenFn = function('vimfluency#drills#undo_redo#generate')
  let valid = ['u', '<C-r>']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call AssertIn(item.expected_motion, valid,
      \ 'undo_redo: expected_motion in {u, <C-r>}')
    call AssertEq(item.optimal_motions, 1,
      \ 'undo_redo: optimal_motions == 1 (single keystroke)')
    call Assert(has_key(item, 'history') && type(item.history) == v:t_list
      \ && len(item.history) >= 2,
      \ 'undo_redo: history is a list with at least 2 states')
    call Assert(has_key(item, 'start_index'),
      \ 'undo_redo: has start_index')
    " For u items: start_index = last; target = state before last.
    " For Ctrl-r items: start_index = 0; target = state after.
    let history = item.history
    let target_lines = get(item, 'target_lines', item.lines)
    if item.expected_motion ==# 'u'
      call AssertEq(item.start_index, len(history) - 1,
        \ 'undo_redo[u]: start_index points at last history state')
      call AssertEq(target_lines, history[item.start_index - 1],
        \ 'undo_redo[u]: target_lines = history one step earlier')
    else
      call AssertEq(item.start_index, 0,
        \ 'undo_redo[<C-r>]: start_index points at first history state')
      call AssertEq(target_lines, history[item.start_index + 1],
        \ 'undo_redo[<C-r>]: target_lines = history one step later')
    endif
    " item.lines must equal the state at start_index (what the user sees).
    call AssertEq(item.lines, history[item.start_index],
      \ 'undo_redo: item.lines == history[start_index]')
    " All history states have the same line count (staging assumption).
    let n_lines = len(history[0])
    for state in history
      call AssertEq(len(state), n_lines,
        \ 'undo_redo: all history states have equal line count')
    endfor
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'undo_redo: ' . k . ' appeared in samples')
  endfor
endfunction

" recall_inner_quote_pair / _triple — inner quote text objects. The
" discriminative cue is the
" delim char in the visible cue line; the answer is i + that delim.
" Cheat-defense rules tested here:
"   - answer is always i + the cue's delim
"   - the arrow (^) lands strictly between the two delim positions
"     (never on a delim) so the cursor is unambiguously inside the
"     inner content
"   - the cue line contains exactly two instances of the delim char
function! s:test_recall_inner_quote(id, module, valid_delims) abort
  let GenFn = function('vimfluency#drills#' . a:module . '#generate')
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_recall_common(a:id, item)
    let answer = item.expected_answer
    let delim = answer[1]
    call AssertEq(answer[0], 'i',
      \ a:id . ': expected_answer starts with i')
    call AssertIn(delim, a:valid_delims,
      \ a:id . ': delim char in declared set')
    call AssertEq(item.expected_motion, answer,
      \ a:id . ': expected_motion mirrors expected_answer')
    call AssertEq(item.optimal_motions, len(answer),
      \ a:id . ': optimal_motions == len(expected_answer)')
    call Assert(type(item.prompt) == v:t_list && len(item.prompt) >= 4,
      \ a:id . ': prompt is a list with at least 4 lines')

    let cue = item.prompt[2]
    let arrow = item.prompt[3]
    let n_delim = len(cue) - len(substitute(cue, delim, '', 'g'))
    call AssertEq(n_delim, 2,
      \ a:id . ': cue line contains exactly two delim chars')

    let caret = stridx(arrow, '^')
    call Assert(caret >= 0,
      \ a:id . ': arrow line has a ^ marker')
    if caret >= 0
      call Assert(cue[caret] !=# delim,
        \ a:id . ': ^ does not land on a delim char (cursor is inside)')
      let open_idx = stridx(cue, delim)
      let close_idx = strridx(cue, delim)
      call Assert(caret > open_idx && caret < close_idx,
        \ a:id . ': ^ sits strictly between the two delims')
    endif
    let seen[delim] = 1
  endfor
  for d in a:valid_delims
    call Assert(get(seen, d, 0) == 1,
      \ a:id . ': delim ' . d . ' appeared in samples')
  endfor
endfunction

function! s:test_recall_inner_quote_pair() abort
  call s:test_recall_inner_quote('recall_inner_quote_pair', 'recall_inner_quote_pair', ['"', "'"])
endfunction
function! s:test_recall_inner_quote_triple() abort
  call s:test_recall_inner_quote('recall_inner_quote_triple', 'recall_inner_quote_triple', ['"', "'", '`'])
endfunction

function! s:test_save_vs_quit() abort
  call s:test_save_quit_pair('save_vs_quit', 'save_vs_quit', [':w', ':q'])
endfunction
function! s:test_save_quit_vs_force_quit() abort
  call s:test_save_quit_pair('save_quit_vs_force_quit', 'save_quit_vs_force_quit', [':wq', ':q!'])
endfunction
function! s:test_save_quit_vs_zz() abort
  call s:test_save_quit_pair('save_quit_vs_zz', 'save_quit_vs_zz', [':wq', 'ZZ'])
endfunction
function! s:test_force_quit_vs_zq() abort
  call s:test_save_quit_pair('force_quit_vs_zq', 'force_quit_vs_zq', [':q!', 'ZQ'])
endfunction

" switch_mode_to_X atomics — each is a 2-cell {Normal, target} drill.
" Over s:N samples we expect both cells to appear. expected_motion is
" the actual keystroke ('C-[' for the Normal target, target's entry
" key otherwise) so the summary displays honest labels.
function! s:test_mode_atomic(id, target, target_key) abort
  let GenFn = function('vimfluency#drills#' . a:id . '#generate')
  let valid = ['n', a:target]
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call AssertIn(item.target_mode_canon, valid,
      \ a:id . ': target in {n,' . a:target . '}')
    let want = item.target_mode_canon ==# 'n' ? 'C-[' : a:target_key
    call AssertEq(item.expected_motion, want,
      \ a:id . ': expected_motion = ' . want)
    call AssertEq(item.optimal_motions, 1,
      \ a:id . ': optimal_motions = 1 (atomic)')
    let seen[item.target_mode_canon] = 1
  endfor
  for m in valid
    call Assert(get(seen, m, 0) == 1,
      \ a:id . ': target ' . m . ' appeared in samples')
  endfor
endfunction

function! s:test_switch_mode_to_insert() abort
  call s:test_mode_atomic('switch_mode_to_insert', 'i', 'i')
endfunction
function! s:test_switch_mode_to_visual() abort
  call s:test_mode_atomic('switch_mode_to_visual', 'v', 'v')
endfunction
function! s:test_switch_mode_to_replace() abort
  call s:test_mode_atomic('switch_mode_to_replace', 'r', 'R')
endfunction
function! s:test_switch_mode_to_command_line() abort
  call s:test_mode_atomic('switch_mode_to_command_line', 'c', ':')
endfunction

" switch_between_many_modes composite — strict alternation between
" Normal and non-Normal. From Normal the generator picks any of
" {i,v,r,c}; from any non-Normal it picks 'n'. Every item is 1
" stroke. The drill exposes the optional current-mode arg so we
" can test both branches without contorting the test harness.
function! s:test_switch_between_many_modes() abort
  let GenFn = function('vimfluency#drills#switch_between_many_modes#generate')
  let non_normal = ['i', 'v', 'r', 'c']
  let expected = {'n': 'C-[', 'i': 'i', 'v': 'v', 'r': 'R', 'c': ':'}

  " From Normal: should always pick a non-Normal target, and over s:N
  " samples all four non-Normal targets should appear.
  let seen = {}
  for i in range(s:N)
    let item = GenFn('n')
    call AssertIn(item.target_mode_canon, non_normal,
      \ 'switch_between_many_modes[from n]: target in {i,v,r,c}')
    call AssertEq(item.expected_motion, expected[item.target_mode_canon],
      \ 'switch_between_many_modes[from n]: expected_motion = entry key')
    call AssertEq(item.optimal_motions, 1,
      \ 'switch_between_many_modes[from n]: optimal_motions = 1')
    let seen[item.target_mode_canon] = 1
  endfor
  for m in non_normal
    call Assert(get(seen, m, 0) == 1,
      \ 'switch_between_many_modes[from n]: target ' . m . ' appeared')
  endfor

  " From any non-Normal: target must be 'n', expected_motion 'C-['.
  for cur in non_normal
    let item = GenFn(cur)
    call AssertEq(item.target_mode_canon, 'n',
      \ 'switch_between_many_modes[from ' . cur . ']: target = n')
    call AssertEq(item.expected_motion, 'C-[',
      \ 'switch_between_many_modes[from ' . cur . ']: expected_motion = C-[')
    call AssertEq(item.optimal_motions, 1,
      \ 'switch_between_many_modes[from ' . cur . ']: optimal_motions = 1')
  endfor
endfunction

" Common shape for mode items: enter_at_{row,col}, target, target_lines,
" expected_motion non-empty, optimal_motions positive.
function! s:assert_mode_common(id, item) abort
  let prefix = 'gen[' . a:id . ']: '
  let item = a:item
  call Assert(has_key(item, 'enter_at_row') && has_key(item, 'enter_at_col'),
    \ prefix . 'has enter_at_row/col')
  call Assert(has_key(item, 'target_lines') && type(item.target_lines) == v:t_list,
    \ prefix . 'has target_lines (list)')
  call Assert(has_key(item, 'target')
    \ && type(item.target) == v:t_list && len(item.target) == 2,
    \ prefix . 'target is [row, col]')
  call Assert(has_key(item, 'expected_motion') && !empty(item.expected_motion),
    \ prefix . 'expected_motion non-empty')
  call Assert(has_key(item, 'optimal_motions') && item.optimal_motions > 0,
    \ prefix . 'optimal_motions positive')
  " enter_at must point inside target_lines.
  let er = item.enter_at_row
  let ec = item.enter_at_col
  call Assert(er >= 1 && er <= len(item.target_lines),
    \ prefix . 'enter_at_row in target_lines bounds')
  let eline = item.target_lines[er - 1]
  call Assert(ec >= 1 && ec <= max([1, len(eline) + 1]),
    \ prefix . 'enter_at_col in [1, len+1] of its target_line')
endfunction

" insert_before_after_char — 2-cell atomic over {i, a}. Each item
" is 4 strokes (entry key + 'foo'); enter_at_col tracks i/a's
" cursor-vs-insertion-point offset (i = cursor col, a = cursor+1).
function! s:test_insert_before_after_char() abort
  let GenFn = function('vimfluency#drills#insert_before_after_char#generate')
  let valid = ['i', 'a']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_mode_common('insert_before_after_char', item)
    call AssertIn(item.expected_motion, valid,
      \ 'insert_before_after_char: expected_motion in {i, a}')
    call AssertEq(item.optimal_motions, 4,
      \ 'insert_before_after_char: optimal_motions == 4')
    call AssertEq(item.target_lines, item.lines,
      \ 'insert_before_after_char: target_lines == lines (pre-typing)')
    call Assert(has_key(item, 'target_lines_after_type'),
      \ 'insert_before_after_char: target_lines_after_type present')
    let line = item.lines[0]
    let sc = item.start[1]
    if item.expected_motion ==# 'i'
      call AssertEq(item.enter_at_col, sc,
        \ 'insert_before_after_char[i]: enter_at_col == start_col')
      call Assert(sc > 1,
        \ 'insert_before_after_char[i]: start_col > 1')
    else
      call AssertEq(item.enter_at_col, sc + 1,
        \ 'insert_before_after_char[a]: enter_at_col == start_col + 1')
      call Assert(sc < len(line),
        \ 'insert_before_after_char[a]: start_col < line_end')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'insert_before_after_char: ' . k . ' appeared in samples')
  endfor
endfunction

" insert_start_end_line — 2-cell atomic over {I, A}. Both keys
" IGNORE the cursor column and jump to a line edge (first-non-blank
" for I, end-of-line+1 for A) before opening insert.
function! s:test_insert_start_end_line() abort
  let GenFn = function('vimfluency#drills#insert_start_end_line#generate')
  let valid = ['I', 'A']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_mode_common('insert_start_end_line', item)
    call AssertIn(item.expected_motion, valid,
      \ 'insert_start_end_line: expected_motion in {I, A}')
    call AssertEq(item.optimal_motions, 4,
      \ 'insert_start_end_line: optimal_motions == 4')
    call AssertEq(item.target_lines, item.lines,
      \ 'insert_start_end_line: target_lines == lines (pre-typing)')
    call Assert(has_key(item, 'target_lines_after_type'),
      \ 'insert_start_end_line: target_lines_after_type present')
    let line = item.lines[0]
    if item.expected_motion ==# 'I'
      let fnb = match(line, '\S') + 1
      call AssertEq(item.enter_at_col, fnb,
        \ 'insert_start_end_line[I]: enter_at_col == first_nonblank')
      call Assert(fnb > 1,
        \ 'insert_start_end_line[I]: line has leading whitespace')
    else
      call AssertEq(item.enter_at_col, len(line) + 1,
        \ 'insert_start_end_line[A]: enter_at_col == line_len + 1')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'insert_start_end_line: ' . k . ' appeared in samples')
  endfor
endfunction

" insert_before_after_char_start_end_line — enter / leave insert mode. Four keys, all optimal 2.
" target_lines must equal lines (no buffer change for i/a/I/A).
function! s:test_insert_before_after_char_start_end_line() abort
  let GenFn = function('vimfluency#drills#insert_before_after_char_start_end_line#generate')
  let valid = ['i', 'a', 'I', 'A']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_mode_common('insert_before_after_char_start_end_line', item)
    call AssertIn(item.expected_motion, valid,
      \ 'insert_before_after_char_start_end_line: expected_motion in {i, a, I, A}')
    call AssertEq(item.optimal_motions, 4,
      \ 'insert_before_after_char_start_end_line: optimal_motions == 4 (entry key + 3 chars of "foo")')
    call AssertEq(item.target_lines, item.lines,
      \ 'insert_before_after_char_start_end_line: target_lines == lines (the post-Esc fallback target; '
      \ . 'pre-typing buffer state)')
    " The lesson's TextChangedI path matches against
    " target_lines_after_type — the buffer state after the learner
    " has typed the test string ('foo') at the insertion column.
    call Assert(has_key(item, 'target_lines_after_type'),
      \ 'insert_before_after_char_start_end_line: target_lines_after_type present (lesson credit target)')
    let _line = item.lines[0]
    let _ec = item.enter_at_col
    let _expected = strpart(_line, 0, _ec - 1) . 'foo' . strpart(_line, _ec - 1)
    call AssertEq(item.target_lines_after_type, [_expected],
      \ 'insert_before_after_char_start_end_line: target_lines_after_type == lines with "foo" inserted at enter_at_col')
    " Disambiguation requirements per key:
    let line = item.lines[0]
    let sc = item.start[1]
    if item.expected_motion ==# 'i'
      call AssertEq(item.enter_at_col, sc,
        \ 'insert_before_after_char_start_end_line[i]: enter_at_col == start_col')
      call Assert(sc > 1,
        \ 'insert_before_after_char_start_end_line[i]: start_col > 1 (S=1 makes post-Esc target degenerate at 1)')
      call AssertEq(item.target[1], sc - 1,
        \ 'insert_before_after_char_start_end_line[i]: target_col == start_col - 1')
    elseif item.expected_motion ==# 'a'
      call AssertEq(item.enter_at_col, sc + 1,
        \ 'insert_before_after_char_start_end_line[a]: enter_at_col == start_col + 1')
      call Assert(sc < len(line),
        \ 'insert_before_after_char_start_end_line[a]: start_col < line_end (S=line_end makes a ≡ A at runner level)')
      call AssertEq(item.target[1], sc,
        \ 'insert_before_after_char_start_end_line[a]: target_col == start_col')
    elseif item.expected_motion ==# 'I'
      let fnb = match(line, '\S') + 1
      call AssertEq(item.enter_at_col, fnb,
        \ 'insert_before_after_char_start_end_line[I]: enter_at_col == first_nonblank')
      call Assert(fnb > 1,
        \ 'insert_before_after_char_start_end_line[I]: line has leading whitespace (fnb > 1)')
      call Assert(sc != fnb && sc != fnb - 1,
        \ 'insert_before_after_char_start_end_line[I]: start_col differs from fnb and fnb-1 '
        \ . '(else i/a from same S match I at runner level)')
      call AssertEq(item.target[1], fnb - 1,
        \ 'insert_before_after_char_start_end_line[I]: target_col == first_nonblank - 1')
    elseif item.expected_motion ==# 'A'
      call AssertEq(item.enter_at_col, len(line) + 1,
        \ 'insert_before_after_char_start_end_line[A]: enter_at_col == line_len + 1')
      call Assert(sc < len(line),
        \ 'insert_before_after_char_start_end_line[A]: start_col < line_end (else a ≡ A at runner level)')
      call AssertEq(item.target[1], len(line),
        \ 'insert_before_after_char_start_end_line[A]: target_col == line_end')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'insert_before_after_char_start_end_line: ' . k . ' appeared in samples')
  endfor
endfunction

" insert_line_above_below — open new line. Two keys, optimal 4 (the o/O opener plus the
" 3 chars of 'foo' typed onto the new line under the new credit-on-
" text-typed flow). The pre-press buffer has two adjacent rows
" marked with '⏵' (the bracket rows around the gap) and the rest of
" the rows prefixed with a space for column alignment. The cursor
" sits on one bracket row; target_lines is the post-press buffer
" with a new BLANK line between the brackets (pre-typing target);
" target_lines_after_type is the same buffer with 'foo' on that line.
function! s:test_insert_line_above_below() abort
  let GenFn = function('vimfluency#drills#insert_line_above_below#generate')
  let valid = ['o', 'O']
  let mark = '⏵'
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_mode_common('insert_line_above_below', item)
    call AssertIn(item.expected_motion, valid,
      \ 'insert_line_above_below: expected_motion in {o, O}')
    call AssertEq(item.optimal_motions, 4,
      \ 'insert_line_above_below: optimal_motions == 4 (o/O + 3 chars of "foo")')
    call AssertEq(len(item.target_lines), len(item.lines) + 1,
      \ 'insert_line_above_below: target_lines has one more line than lines (the new blank)')
    " target_lines_after_type matches target_lines with 'foo' on the
    " new line instead of blank — the credit_on_text_typed handler
    " matches against this.
    call Assert(has_key(item, 'target_lines_after_type'),
      \ 'insert_line_above_below: target_lines_after_type present')
    let blank_row_idx = index(item.target_lines, '')
    let _expected_typed = copy(item.target_lines)
    let _expected_typed[blank_row_idx] = 'foo'
    call AssertEq(item.target_lines_after_type, _expected_typed,
      \ 'insert_line_above_below: target_lines_after_type == target_lines with "foo" on the new line')

    " Find the two bracket rows (those prefixed with the ⏵ mark).
    let bracket_rows = []
    for row in range(1, len(item.lines))
      if strpart(item.lines[row - 1], 0, len(mark)) ==# mark
        call add(bracket_rows, row)
      endif
    endfor
    call AssertEq(len(bracket_rows), 2,
      \ 'insert_line_above_below: lines contains exactly two ⏵-prefixed bracket rows')
    if len(bracket_rows) == 2
      call AssertEq(bracket_rows[1] - bracket_rows[0], 1,
        \ 'insert_line_above_below: bracket rows are adjacent (single-row gap between them)')
    endif

    " The new blank in target_lines sits between the two bracket rows.
    let blank_row = index(item.target_lines, '') + 1
    call AssertEq(blank_row, bracket_rows[0] + 1,
      \ 'insert_line_above_below: new blank appears between the two bracket rows')

    if item.expected_motion ==# 'o'
      call AssertEq(item.start[0], bracket_rows[0],
        \ 'insert_line_above_below[o]: cursor on the UPPER bracket row (other ⏵ below)')
    else
      call AssertEq(item.start[0], bracket_rows[1],
        \ 'insert_line_above_below[O]: cursor on the LOWER bracket row (other ⏵ above)')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'insert_line_above_below: ' . k . ' appeared in samples')
  endfor
endfunction

" move_single_char_left_right: h vs l. Target on same row as start; dcol ∈ {-2,-1,1,2};
" optimal_motions == abs(dcol); motion 'l' for positive dcol, 'h' otherwise.
function! s:test_move_single_char_left_right() abort
  let GenFn = function('vimfluency#drills#move_single_char_left_right#generate')
  let valid = ['h', 'l']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_single_char_left_right', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_single_char_left_right: expected_motion in {h, l}')
    call AssertEq(item.target[0], item.start[0],
      \ 'move_single_char_left_right: target row == start row (no vertical component)')
    let dcol = item.target[1] - item.start[1]
    call Assert(dcol != 0 && abs(dcol) <= 2,
      \ 'move_single_char_left_right: dcol in {-2,-1,1,2}, got ' . dcol)
    call AssertEq(item.optimal_motions, abs(dcol),
      \ 'move_single_char_left_right: optimal_motions == abs(dcol)')
    if dcol > 0
      call AssertEq(item.expected_motion, 'l', 'move_single_char_left_right: dcol>0 → l')
    else
      call AssertEq(item.expected_motion, 'h', 'move_single_char_left_right: dcol<0 → h')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'move_single_char_left_right: ' . k . ' appeared in samples')
  endfor
endfunction

" move_single_char_up_down: j vs k. Target on same column as start; drow ∈ {-2,-1,1,2};
" optimal_motions == abs(drow); motion 'j' for positive drow, 'k' otherwise.
function! s:test_move_single_char_up_down() abort
  let GenFn = function('vimfluency#drills#move_single_char_up_down#generate')
  let valid = ['j', 'k']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_single_char_up_down', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_single_char_up_down: expected_motion in {j, k}')
    call AssertEq(item.target[1], item.start[1],
      \ 'move_single_char_up_down: target col == start col (no horizontal component)')
    let drow = item.target[0] - item.start[0]
    call Assert(drow != 0 && abs(drow) <= 2,
      \ 'move_single_char_up_down: drow in {-2,-1,1,2}, got ' . drow)
    call AssertEq(item.optimal_motions, abs(drow),
      \ 'move_single_char_up_down: optimal_motions == abs(drow)')
    if drow > 0
      call AssertEq(item.expected_motion, 'j', 'move_single_char_up_down: drow>0 → j')
    else
      call AssertEq(item.expected_motion, 'k', 'move_single_char_up_down: drow<0 → k')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'move_single_char_up_down: ' . k . ' appeared in samples')
  endfor
endfunction

" move_to_line_edges_start_end: 0 vs $. Single line, no trailing whitespace, cursor in interior.
" target column ∈ {1, llen}; motion '0' for col 1 else '$'.
function! s:test_move_to_line_edges_start_end() abort
  let GenFn = function('vimfluency#drills#move_to_line_edges_start_end#generate')
  let valid = ['0', '$']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_to_line_edges_start_end', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_to_line_edges_start_end: expected_motion in {0, $}')
    call AssertEq(item.optimal_motions, 1, 'move_to_line_edges_start_end: optimal_motions == 1')
    let line = item.lines[0]
    let llen = len(line)
    call Assert(line ==# substitute(line, '\s\+$', '', ''),
      \ 'move_to_line_edges_start_end: line has no trailing whitespace')
    call Assert(line ==# substitute(line, '^\s\+', '', ''),
      \ 'move_to_line_edges_start_end: line has no leading whitespace')
    if item.expected_motion ==# '0'
      call AssertEq(item.target[1], 1, 'move_to_line_edges_start_end/0: target col == 1')
    else
      call AssertEq(item.target[1], llen, 'move_to_line_edges_start_end/$: target col == line length')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'move_to_line_edges_start_end: ' . k . ' appeared in samples')
  endfor
endfunction

" move_to_line_edges_non_white_space — ^ vs g_. Line has BOTH
" leading and trailing whitespace so neither motion collapses to its
" 0/$ sibling. Cursor sits strictly between first_nonblank and
" last_nonblank so neither motion is a no-op.
function! s:test_move_to_line_edges_non_white_space() abort
  let GenFn = function('vimfluency#drills#move_to_line_edges_non_white_space#generate')
  let valid = ['^', 'g_']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('move_to_line_edges_non_white_space', item)
    call AssertIn(item.expected_motion, valid,
      \ 'move_to_line_edges_non_white_space: expected_motion in {^, g_}')
    call AssertEq(item.optimal_motions, 1,
      \ 'move_to_line_edges_non_white_space: optimal_motions == 1')
    let line = item.lines[0]
    let llen = len(line)
    let stripped_left = substitute(line, '^\s\+', '', '')
    let stripped_right = substitute(line, '\s\+$', '', '')
    let fnb = llen - len(stripped_left) + 1
    let lnb = len(stripped_right)
    call Assert(fnb > 1,
      \ 'move_to_line_edges_non_white_space: line has leading whitespace (fnb > 1)')
    call Assert(lnb < llen,
      \ 'move_to_line_edges_non_white_space: line has trailing whitespace (lnb < llen)')
    if item.expected_motion ==# '^'
      call AssertEq(item.target[1], fnb,
        \ 'move_to_line_edges_non_white_space[^]: target == first_nonblank')
    else
      call AssertEq(item.target[1], lnb,
        \ 'move_to_line_edges_non_white_space[g_]: target == last_nonblank')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'move_to_line_edges_non_white_space: ' . k . ' appeared in samples')
  endfor
endfunction

" delete_to_line_edges_start_end: d0 vs d$. Editing-kind; single-line buffer; cursor in interior.
" Deletion range covers [1, cursor-1] for d0 or [cursor, llen] for d$.
" target_lines is the surviving slice; cursor ends at col 1 (d0) or
" cursor-1 (d$).
function! s:test_delete_to_line_edges_start_end() abort
  let GenFn = function('vimfluency#drills#delete_to_line_edges_start_end#generate')
  let valid = ['d0', 'd$']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('delete_to_line_edges_start_end', item)
    call AssertIn(item.expected_motion, valid,
      \ 'delete_to_line_edges_start_end: expected_motion in {d0, d$}')
    call AssertEq(item.optimal_motions, 1, 'delete_to_line_edges_start_end: optimal_motions == 1')
    call Assert(has_key(item, 'target_lines'),
      \ 'delete_to_line_edges_start_end: has target_lines')
    call Assert(has_key(item, 'deletion_range'),
      \ 'delete_to_line_edges_start_end: has deletion_range')
    let cursor_col = item.start[1]
    let line = item.lines[0]
    let llen = len(line)
    let del = item.deletion_range[0]
    if item.expected_motion ==# 'd0'
      call AssertEq(del[1], 1, 'delete_to_line_edges_start_end/d0: deletion starts at col 1')
      call AssertEq(del[2], cursor_col - 1, 'delete_to_line_edges_start_end/d0: deletion length == cursor-1')
      call AssertEq(item.target[1], 1, 'delete_to_line_edges_start_end/d0: target col == 1')
    else
      call AssertEq(del[1], cursor_col, 'delete_to_line_edges_start_end/d$: deletion starts at cursor')
      call AssertEq(del[2], llen - cursor_col + 1, 'delete_to_line_edges_start_end/d$: deletion length == llen-cursor+1')
      call AssertEq(item.target[1], cursor_col - 1, 'delete_to_line_edges_start_end/d$: target col == cursor-1')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'delete_to_line_edges_start_end: ' . k . ' appeared in samples')
  endfor
endfunction

" delete_single_char_left_right: dl vs dh. Editing-kind; single-line; deletion is exactly 1 char.
" dl deletes char AT cursor (cursor stays); dh deletes char BEFORE cursor
" (cursor moves left one column).
function! s:test_delete_single_char_left_right() abort
  let GenFn = function('vimfluency#drills#delete_single_char_left_right#generate')
  let valid = ['dl', 'dh']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('delete_single_char_left_right', item)
    call AssertIn(item.expected_motion, valid,
      \ 'delete_single_char_left_right: expected_motion in {dl, dh}')
    call AssertEq(item.optimal_motions, 1, 'delete_single_char_left_right: optimal_motions == 1')
    let cursor_col = item.start[1]
    let del = item.deletion_range[0]
    call AssertEq(del[2], 1, 'delete_single_char_left_right: deletion length == 1')
    if item.expected_motion ==# 'dl'
      call AssertEq(del[1], cursor_col, 'delete_single_char_left_right/dl: deletion at cursor col')
      call AssertEq(item.target[1], cursor_col, 'delete_single_char_left_right/dl: cursor stays')
    else
      call AssertEq(del[1], cursor_col - 1, 'delete_single_char_left_right/dh: deletion before cursor')
      call AssertEq(item.target[1], cursor_col - 1, 'delete_single_char_left_right/dh: cursor moves left one')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'delete_single_char_left_right: ' . k . ' appeared in samples')
  endfor
endfunction

" delete_two_lines_down_up: dj vs dk. Linewise editing-kind; 5-line buffer; cursor on row 2-3.
" dj deletes rows [cursor, cursor+1]; dk deletes rows [cursor-1, cursor].
" Survivors: 3 rows. Cursor lands at col 1 of the appropriate surviving row.
function! s:test_delete_two_lines_down_up() abort
  let GenFn = function('vimfluency#drills#delete_two_lines_down_up#generate')
  let valid = ['dj', 'dk']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('delete_two_lines_down_up', item)
    call AssertIn(item.expected_motion, valid,
      \ 'delete_two_lines_down_up: expected_motion in {dj, dk}')
    call AssertEq(item.optimal_motions, 1, 'delete_two_lines_down_up: optimal_motions == 1')
    call AssertEq(len(item.lines), 5, 'delete_two_lines_down_up: 5-line buffer')
    call AssertEq(len(item.target_lines), 3, 'delete_two_lines_down_up: 3 surviving lines')
    let cursor_row = item.start[0]
    call Assert(cursor_row == 2 || cursor_row == 3,
      \ 'delete_two_lines_down_up: cursor on row 2 or 3')
    call AssertEq(item.start[1], 1, 'delete_two_lines_down_up: cursor starts at col 1')
    call AssertEq(item.target[1], 1, 'delete_two_lines_down_up: cursor target at col 1')
    call AssertEq(len(item.deletion_range), 2,
      \ 'delete_two_lines_down_up: deletion_range covers 2 rows')
    if item.expected_motion ==# 'dj'
      call AssertEq(item.deletion_range[0][0], cursor_row,
        \ 'delete_two_lines_down_up/dj: first deletion row == cursor row')
      call AssertEq(item.deletion_range[1][0], cursor_row + 1,
        \ 'delete_two_lines_down_up/dj: second deletion row == cursor row + 1')
      call AssertEq(item.target[0], cursor_row,
        \ 'delete_two_lines_down_up/dj: cursor lands at cursor_row (now the next survivor)')
    else
      call AssertEq(item.deletion_range[0][0], cursor_row - 1,
        \ 'delete_two_lines_down_up/dk: first deletion row == cursor row - 1')
      call AssertEq(item.deletion_range[1][0], cursor_row,
        \ 'delete_two_lines_down_up/dk: second deletion row == cursor row')
      call AssertEq(item.target[0], cursor_row - 1,
        \ 'delete_two_lines_down_up/dk: cursor lands at cursor_row-1 (now the next survivor)')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'delete_two_lines_down_up: ' . k . ' appeared in samples')
  endfor
endfunction

" visual_select_single_char_up_down_left_right: vh / vj / vk / vl.
" Broader v-family charwise drill mixing all four single-cell
" extensions. Target Chebyshev distance == 1 (one cardinal cell),
" no diagonals, expected_sub_mode == 'v', and the motion label
" matches the chosen cardinal direction.
function! s:test_visual_select_single_char_up_down_left_right() abort
  let GenFn = function('vimfluency#drills#visual_select_single_char_up_down_left_right#generate')
  let valid = ['vh', 'vj', 'vk', 'vl']
  let seen = {}
  let prefix = 'visual_select_single_char_up_down_left_right: '
  for i in range(s:N)
    let item = GenFn()
    call AssertIn(item.expected_motion, valid,
      \ prefix . 'expected_motion in {vh, vj, vk, vl}')
    let drow = item.target[0] - item.start[0]
    let dcol = item.target[1] - item.start[1]
    call Assert((abs(drow) + abs(dcol)) == 1,
      \ prefix . 'manhattan distance == 1 (single cardinal step), got drow='
      \ . drow . ' dcol=' . dcol)
    call AssertEq(item.optimal_motions, 2,
      \ prefix . 'optimal_motions == 2 (v + direction)')
    call AssertEq(item.expected_sub_mode, 'v',
      \ prefix . 'expected_sub_mode == "v" (charwise)')
    call AssertEq(item.expected_selection_start, item.start,
      \ prefix . 'expected_selection_start == start (anchor at cursor)')
    call AssertEq(item.expected_selection_end, item.target,
      \ prefix . 'expected_selection_end == target')
    " Motion label matches the direction vector
    if     dcol == -1 | call AssertEq(item.expected_motion, 'vh', prefix . 'dcol=-1 → vh')
    elseif dcol ==  1 | call AssertEq(item.expected_motion, 'vl', prefix . 'dcol=+1 → vl')
    elseif drow == -1 | call AssertEq(item.expected_motion, 'vk', prefix . 'drow=-1 → vk')
    elseif drow ==  1 | call AssertEq(item.expected_motion, 'vj', prefix . 'drow=+1 → vj')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ prefix . k . ' appeared in samples')
  endfor
endfunction

" visual_select_single_char_up_down: vj vs vk. Foundational v-family
" charwise pair on the vertical axis. Target on the same column as
" start, target row = start ± 1, expected_sub_mode = 'v'.
function! s:test_visual_select_single_char_up_down() abort
  let GenFn = function('vimfluency#drills#visual_select_single_char_up_down#generate')
  let valid = ['vj', 'vk']
  let seen = {}
  let prefix = 'visual_select_single_char_up_down: '
  for i in range(s:N)
    let item = GenFn()
    call AssertIn(item.expected_motion, valid,
      \ prefix . 'expected_motion in {vj, vk}')
    call AssertEq(item.target[1], item.start[1],
      \ prefix . 'target col == start col (no horizontal component)')
    let drow = item.target[0] - item.start[0]
    call Assert(abs(drow) == 1,
      \ prefix . 'drow in {-1,+1}, got ' . drow)
    call AssertEq(item.optimal_motions, 2,
      \ prefix . 'optimal_motions == 2 (v + direction)')
    call AssertEq(item.expected_sub_mode, 'v',
      \ prefix . 'expected_sub_mode == "v" (charwise)')
    call AssertEq(item.expected_selection_start, item.start,
      \ prefix . 'expected_selection_start == start (anchor at cursor)')
    call AssertEq(item.expected_selection_end, item.target,
      \ prefix . 'expected_selection_end == target')
    if drow > 0
      call AssertEq(item.expected_motion, 'vj', prefix . 'drow>0 → vj')
    else
      call AssertEq(item.expected_motion, 'vk', prefix . 'drow<0 → vk')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ prefix . k . ' appeared in samples')
  endfor
endfunction

" visual_select_single_char_left_right: vh vs vl. Foundational v-family
" charwise pair. Target on the same row as start, target column = start ± 1,
" expected_sub_mode = 'v', selection start = start, selection end = target.
function! s:test_visual_select_single_char_left_right() abort
  let GenFn = function('vimfluency#drills#visual_select_single_char_left_right#generate')
  let valid = ['vh', 'vl']
  let seen = {}
  let prefix = 'visual_select_single_char_left_right: '
  for i in range(s:N)
    let item = GenFn()
    call AssertIn(item.expected_motion, valid,
      \ prefix . 'expected_motion in {vh, vl}')
    call AssertEq(item.target[0], item.start[0],
      \ prefix . 'target row == start row (charwise, single line)')
    let dcol = item.target[1] - item.start[1]
    call Assert(abs(dcol) == 1,
      \ prefix . 'dcol in {-1,+1}, got ' . dcol)
    call AssertEq(item.optimal_motions, 2,
      \ prefix . 'optimal_motions == 2 (v + direction)')
    call AssertEq(item.expected_sub_mode, 'v',
      \ prefix . 'expected_sub_mode == "v" (charwise)')
    call AssertEq(item.expected_selection_start, item.start,
      \ prefix . 'expected_selection_start == start (anchor at cursor)')
    call AssertEq(item.expected_selection_end, item.target,
      \ prefix . 'expected_selection_end == target')
    if dcol > 0
      call AssertEq(item.expected_motion, 'vl', prefix . 'dcol>0 → vl')
    else
      call AssertEq(item.expected_motion, 'vh', prefix . 'dcol<0 → vh')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ prefix . k . ' appeared in samples')
  endfor
endfunction

call s:test_move_single_char_up_down_left_right()
call s:test_move_to_line_edges_all()
call s:test_move_to_word_start_forward_backward()
call s:test_move_to_word_end_forward_backward()
call s:test_move_to_char_forward_backward()
call s:test_move_till_char_forward_backward()
call s:test_move_repeat_last_find_forward_backward()
call s:test_move_to_vs_till_forward_backward()
call s:test_move_to_vs_till_forward()
call s:test_move_to_vs_till_backward()
call s:test_move_to_vs_till_forward_in_words()
call s:test_move_to_vs_till_backward_in_words()
call s:test_delete_char_vs_line()
call s:test_indent_vs_dedent()
call s:test_delete_to_word_start_forward_backward()
call s:test_insert_before_after_char()
call s:test_insert_start_end_line()
call s:test_insert_before_after_char_start_end_line()
call s:test_insert_line_above_below()
call s:test_save_vs_quit()
call s:test_save_quit_vs_force_quit()
call s:test_save_quit_vs_zz()
call s:test_force_quit_vs_zq()
call s:test_undo_redo()
call s:test_switch_mode_to_insert()
call s:test_switch_mode_to_visual()
call s:test_switch_mode_to_replace()
call s:test_switch_mode_to_command_line()
call s:test_switch_between_many_modes()
call s:test_recall_inner_quote_pair()
call s:test_recall_inner_quote_triple()
call s:test_move_single_char_left_right()
call s:test_move_to_line_edges_non_white_space()
call s:test_move_single_char_up_down()
call s:test_move_to_line_edges_start_end()
call s:test_delete_to_line_edges_start_end()
call s:test_delete_single_char_left_right()
call s:test_delete_two_lines_down_up()
call s:test_visual_select_single_char_left_right()
call s:test_visual_select_single_char_up_down()
call s:test_visual_select_single_char_up_down_left_right()
