" Property tests over each pinpoint's generator. Generates many items and
" asserts structural invariants + the pinpoint-specific optimal_motions
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
  " The probe must require *something* — either cursor or buffer must change.
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
  " For editing-kind pinpoints the cursor lands inside target_lines
  " (the post-edit buffer), not item.lines. For motion-only items
  " the two are the same. Always check against target_lines so
  " operations that lengthen the line (like 2.2's >>) don't fail
  " the bound check against a shorter pre-edit line.
  let after_lines = get(item, 'target_lines', item.lines)
  call Assert(trow >= 1 && trow <= len(after_lines),
    \ prefix . 'target row in bounds (' . trow . '/' . len(after_lines) . ')')
  let tline = after_lines[trow - 1]
  call Assert(tcol >= 1 && tcol <= max([1, len(tline)]),
    \ prefix . 'target col in bounds (' . tcol . '/' . len(tline) . ')')
endfunction

" 1A.1: optimal_motions == manhattan(start, target);
" expected_motion ∈ {h, j, k, l, diag}
function! s:test_1A_1() abort
  let GenFn = function('vimfluency#pinpoints#p1A_1#generate')
  let valid = ['h', 'j', 'k', 'l', 'diag']
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1A.1', item)
    let manhattan = abs(item.target[0] - item.start[0])
      \ + abs(item.target[1] - item.start[1])
    call AssertEq(item.optimal_motions, manhattan,
      \ '1A.1: optimal_motions == manhattan(start, target)')
    call AssertIn(item.expected_motion, valid,
      \ '1A.1: expected_motion in {h,j,k,l,diag}')
  endfor
endfunction

" 1A.2: optimal_motions == 1; expected_motion ∈ {0, ^, $, g_};
" target_col == 1 → motion is '0'; trailing whitespace items can be 'g_'.
function! s:test_1A_2() abort
  let GenFn = function('vimfluency#pinpoints#p1A_2#generate')
  let valid = ['0', '^', '$', 'g_']
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1A.2', item)
    call AssertEq(item.optimal_motions, 1, '1A.2: optimal_motions == 1')
    call AssertIn(item.expected_motion, valid,
      \ '1A.2: expected_motion in {0, ^, $, g_}')

    " Cross-check label vs target position
    let line = item.lines[0]
    let llen = len(line)
    let tcol = item.target[1]
    if tcol == 1
      call AssertEq(item.expected_motion, '0',
        \ '1A.2: target_col == 1 implies motion == 0')
    elseif tcol == llen
      let stripped = substitute(line, '\s\+$', '', '')
      let last_nonblank = empty(stripped) ? llen : len(stripped)
      if last_nonblank == llen
        call AssertEq(item.expected_motion, '$',
          \ '1A.2: target_col == llen with no trailing ws implies $')
      endif
    endif
  endfor
endfunction

" 1B.1: expected_motion ∈ {w, b}; optimal_motions == dist (which is
" the same as the manhattan word-distance, in [2, 4]).
function! s:test_1B_1() abort
  let GenFn = function('vimfluency#pinpoints#p1B_1#generate')
  let valid = ['w', 'b']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1B.1', item)
    call AssertIn(item.expected_motion, valid,
      \ '1B.1: expected_motion in {w, b}')
    call Assert(item.optimal_motions >= 2 && item.optimal_motions <= 4,
      \ '1B.1: optimal_motions in [2, 4], got ' . item.optimal_motions)
    let seen[item.expected_motion] = 1
  endfor
  call Assert(get(seen, 'w', 0) == 1, '1B.1: w appeared in samples')
  call Assert(get(seen, 'b', 0) == 1, '1B.1: b appeared in samples')
endfunction

" 1B.2: expected_motion ∈ {e, ge}; optimal_motions == dist+1 for
" forward (e), dist for backward (ge). Range [2, 5].
function! s:test_1B_2() abort
  let GenFn = function('vimfluency#pinpoints#p1B_2#generate')
  let valid = ['e', 'ge']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1B.2', item)
    call AssertIn(item.expected_motion, valid,
      \ '1B.2: expected_motion in {e, ge}')
    call Assert(item.optimal_motions >= 2 && item.optimal_motions <= 5,
      \ '1B.2: optimal_motions in [2, 5], got ' . item.optimal_motions)

    " Forward (e): one extra motion beyond word distance because the
    " first e lands at end of current word.
    " Backward (ge): one motion per word stepped.
    if item.expected_motion ==# 'e'
      call Assert(item.target[1] > item.start[1],
        \ '1B.2/e: target col > start col (forward)')
    else
      call Assert(item.target[1] < item.start[1],
        \ '1B.2/ge: target col < start col (backward)')
    endif
    let seen[item.expected_motion] = 1
  endfor
  call Assert(get(seen, 'e', 0) == 1, '1B.2: e appeared in samples')
  call Assert(get(seen, 'ge', 0) == 1, '1B.2: ge appeared in samples')
endfunction

" 2.1: editing-kind discrimination probe. expected_motion ∈ {x, dd}.
" 2-line buffer where the cursor starts at col 1 of one line and
" the highlight lives on the OTHER line — single char (col 1) for
" x items, full line for dd items. Each item is a 2-event sequence:
" j or k to navigate, then the operator. Both motions appear over
" many samples and both navigation directions are exercised.
function! s:test_2_1() abort
  let GenFn = function('vimfluency#pinpoints#p2_1#generate')
  let valid = ['x', 'dd']
  let seen = {}
  let nav_dirs = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('2.1', item)
    call AssertIn(item.expected_motion, valid,
      \ '2.1: expected_motion in {x, dd}')
    call AssertEq(item.optimal_motions, 2,
      \ '2.1: optimal_motions == 2 (1 nav + 1 operator)')

    call AssertEq(len(item.lines), 2, '2.1: two-line buffer')
    call Assert(has_key(item, 'target_lines'), '2.1: has target_lines')
    call Assert(has_key(item, 'deletion_range'), '2.1: has deletion_range')

    " Cursor always starts at col 1.
    call AssertEq(item.start[1], 1, '2.1: cursor starts at col 1')

    let cursor_line = item.start[0]
    let target_line_idx = cursor_line == 1 ? 2 : 1
    let dr = item.deletion_range[0]

    " Highlight is on the line opposite the cursor.
    call AssertEq(dr[0], target_line_idx,
      \ '2.1: highlight is on the line opposite the cursor')

    let target_text = item.lines[target_line_idx - 1]
    let target_len = len(target_text)

    if item.expected_motion ==# 'dd'
      " dd: highlight covers the entire target line; after j/k + dd
      " the target line is gone, the cursor's original line is the
      " only buffer row, cursor lands at line 1 col 1.
      call AssertEq(len(item.target_lines), 1,
        \ '2.1/dd: target buffer is the surviving line only')
      let surviving = item.lines[cursor_line - 1]
      call AssertEq(item.target_lines[0], surviving,
        \ '2.1/dd: surviving line is the cursor''s original line')
      call AssertEq(item.target, [1, 1],
        \ '2.1/dd: cursor lands at line 1 col 1')
      call AssertEq(dr, [target_line_idx, 1, target_len],
        \ '2.1/dd: deletion_range covers the entire target line')
    else
      " x: highlight is single char at col 1 of target line. j/k
      " preserves column, lands cursor on the highlighted char,
      " then x deletes one char.
      call AssertEq(len(item.target_lines), 2,
        \ '2.1/x: target preserves both lines')
      call AssertEq(len(item.target_lines[target_line_idx - 1]),
        \ target_len - 1,
        \ '2.1/x: target line is one char shorter')
      let other = item.lines[cursor_line - 1]
      call AssertEq(item.target_lines[cursor_line - 1], other,
        \ '2.1/x: cursor''s original line is unchanged')
      call AssertEq(dr, [target_line_idx, 1, 1],
        \ '2.1/x: deletion_range is one char at col 1 of target line')
      call AssertEq(item.target, [target_line_idx, 1],
        \ '2.1/x: cursor ends at col 1 of target line')
    endif
    let seen[item.expected_motion] = 1
    let nav_dirs[cursor_line == 1 ? 'down' : 'up'] = 1
  endfor
  call Assert(get(seen, 'x', 0) == 1, '2.1: x appeared in samples')
  call Assert(get(seen, 'dd', 0) == 1, '2.1: dd appeared in samples')
  call Assert(get(nav_dirs, 'down', 0) == 1,
    \ '2.1: items where the user navigates down (j) appeared')
  call Assert(get(nav_dirs, 'up', 0) == 1,
    \ '2.1: items where the user navigates up (k) appeared')
endfunction

" 2.2: indent/dedent discrimination. 2-line buffer; line 1 is the
" active line, line 2 is the reference. They differ by 1 or 2
" shiftwidths in the picked direction. Both motions and both step
" counts appear over many samples.
function! s:test_2_2() abort
  let GenFn = function('vimfluency#pinpoints#p2_2#generate')
  let SW = 4
  let valid = ['>>', '<<']
  let seen = {}
  let step_counts = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('2.2', item)
    call AssertIn(item.expected_motion, valid,
      \ '2.2: expected_motion in {>>, <<}')
    call AssertIn(item.optimal_motions, [1, 2],
      \ '2.2: optimal_motions in {1, 2}')

    call AssertEq(len(item.lines), 2, '2.2: 2-line buffer')
    call AssertEq(len(item.target_lines), 2, '2.2: target also 2-line')

    " Line 2 (reference) is unchanged in target.
    call AssertEq(item.target_lines[1], item.lines[1],
      \ '2.2: line 2 reference is not modified')

    " Cursor starts on line 1 at first non-blank, lands on line 1 at
    " first non-blank of the new indent.
    call AssertEq(item.start[0], 1, '2.2: cursor starts on line 1')
    call AssertEq(item.target[0], 1, '2.2: cursor lands on line 1')

    " Indent difference between line 1 and line 2 is steps × SW.
    let l1_indent = match(item.lines[0], '\S')
    let l2_indent = match(item.lines[1], '\S')
    let diff = l2_indent - l1_indent
    let signed = item.expected_motion ==# '>>'
      \ ? item.optimal_motions * SW
      \ : -1 * item.optimal_motions * SW
    call AssertEq(diff, signed,
      \ '2.2: line 2 indent matches signed steps × shiftwidth')

    " After the operation, line 1's indent equals line 2's.
    let new_l1_indent = match(item.target_lines[0], '\S')
    call AssertEq(new_l1_indent, l2_indent,
      \ '2.2: line 1 target indent matches line 2')

    " Indents stay non-negative and within the bounded range.
    call Assert(l1_indent >= 0, '2.2: line 1 indent non-negative')
    call Assert(l2_indent >= 0, '2.2: line 2 indent non-negative')
    call Assert(l1_indent <= 12 && l2_indent <= 12,
      \ '2.2: indents capped at 12 spaces')
    let seen[item.expected_motion] = 1
    let step_counts[item.optimal_motions] = 1
  endfor
  call Assert(get(seen, '>>', 0) == 1, '2.2: >> appeared in samples')
  call Assert(get(seen, '<<', 0) == 1, '2.2: << appeared in samples')
  call Assert(get(step_counts, 1, 0) == 1, '2.2: 1-step items appeared')
  call Assert(get(step_counts, 2, 0) == 1, '2.2: 2-step items appeared')
endfunction

" 4.1: editing kind; expected_motion ∈ {dw, db}; deletion_range matches
" the actual delta between start_lines and target_lines.
function! s:test_4_1() abort
  let GenFn = function('vimfluency#pinpoints#p4_1#generate')
  let valid = ['dw', 'db']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('4.1', item)
    call AssertIn(item.expected_motion, valid,
      \ '4.1: expected_motion in {dw, db}')
    call AssertEq(item.optimal_motions, 1, '4.1: optimal_motions == 1')
    let seen[item.expected_motion] = 1

    " editing-kind invariants
    call Assert(has_key(item, 'target_lines'), '4.1: has target_lines')
    call Assert(has_key(item, 'deletion_range'), '4.1: has deletion_range')
    call Assert(!empty(item.deletion_range), '4.1: deletion_range non-empty')

    " Some chars must have been removed (target line is shorter than start).
    " Word count is no longer asserted: db from mid-word leaves a
    " prefix-fragment of the current word, so word count can stay equal.
    call Assert(len(item.target_lines[0]) < len(item.lines[0]),
      \ '4.1: target_lines is shorter than lines')

    " deletion_range length should match the actual length removed
    let removed_chars = len(item.lines[0]) - len(item.target_lines[0])
    let total_len = 0
    for pos in item.deletion_range
      let total_len += pos[2]
    endfor
    call AssertEq(total_len, removed_chars,
      \ '4.1: deletion_range length matches chars actually removed')

    " for dw: target_cursor col == start_cursor col (cursor stays put)
    " for db: target_cursor col < start_cursor col (cursor jumps back)
    if item.expected_motion ==# 'dw'
      call AssertEq(item.target[1], item.start[1],
        \ '4.1/dw: target col == start col')
    else
      call Assert(item.target[1] < item.start[1],
        \ '4.1/db: target col < start col')
    endif
  endfor

  " Both motions should appear in 50 generates with high probability
  call Assert(get(seen, 'dw', 0) == 1, '4.1: dw appeared in samples')
  call Assert(get(seen, 'db', 0) == 1, '4.1: db appeared in samples')

  let meta = vimfluency#pinpoints#p4_1#meta()
  call AssertEq(get(meta, 'kind', 'motion'), 'editing',
    \ '4.1: meta.kind == editing')
endfunction

" 1C.1: expected_motion ∈ {f, F}; optimal_motions == 1; target unique in
" line; target interior to its word (margin ≥2); cursor not on whitespace
" or target_char; distance ≥4 from cursor.
function! s:test_1C_1() abort
  let GenFn = function('vimfluency#pinpoints#p1C_1#generate')
  let valid = ['f', 'F']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1C.1', item)
    call AssertIn(item.expected_motion, valid,
      \ '1C.1: expected_motion in {f, F}')
    call AssertEq(item.optimal_motions, 1,
      \ '1C.1: optimal_motions == 1')

    let line = item.lines[0]
    let llen = len(line)
    let start_col = item.start[1]
    let target_col = item.target[1]
    let target_char = line[target_col - 1]
    let seen[item.expected_motion] = 1

    if item.expected_motion ==# 'f'
      call Assert(start_col < target_col,
        \ '1C.1/f: start_col < target_col')
    else
      call Assert(start_col > target_col,
        \ '1C.1/F: start_col > target_col')
    endif

    call Assert(abs(target_col - start_col) >= 4,
      \ '1C.1: distance ≥ 4 (cheat-defense vs hjkl chains)')

    call Assert(line[start_col - 1] !=# ' ',
      \ '1C.1: start not on whitespace')
    call Assert(line[start_col - 1] !=# target_char,
      \ '1C.1: start not on target_char')

    let count_target = 0
    for ci in range(llen)
      if line[ci] ==# target_char | let count_target += 1 | endif
    endfor
    call AssertEq(count_target, 1,
      \ '1C.1: target_char appears exactly once in line')

    let words_in_line = split(line, ' ')
    let cumcol = 1
    for w in words_in_line
      let ws = cumcol
      let we = cumcol + len(w) - 1
      if target_col >= ws && target_col <= we
        call Assert(target_col - ws >= 2,
          \ '1C.1: target ≥2 cols from word start')
        call Assert(we - target_col >= 2,
          \ '1C.1: target ≥2 cols from word end')
        break
      endif
      let cumcol += len(w) + 1
    endfor
  endfor

  call Assert(get(seen, 'f', 0) == 1, '1C.1: f appeared in samples')
  call Assert(get(seen, 'F', 0) == 1, '1C.1: F appeared in samples')
endfunction

" 1C.2: expected_motion ∈ {t, T}; optimal_motions == 1; the LANDING is
" target_col, the actual char is at target_col + 1 (forward) or
" target_col - 1 (backward). Char must be unique in line, interior to
" its word with direction-specific margins, and distance >= 3 from cursor.
function! s:test_1C_2() abort
  let GenFn = function('vimfluency#pinpoints#p1C_2#generate')
  let valid = ['t', 'T']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1C.2', item)
    call AssertIn(item.expected_motion, valid,
      \ '1C.2: expected_motion in {t, T}')
    call AssertEq(item.optimal_motions, 1,
      \ '1C.2: optimal_motions == 1')

    let line = item.lines[0]
    let llen = len(line)
    let start_col = item.start[1]
    let target_col = item.target[1]
    let seen[item.expected_motion] = 1

    if item.expected_motion ==# 't'
      call Assert(start_col < target_col,
        \ '1C.2/t: start_col < target_col')
      let target_char_col = target_col + 1
    else
      call Assert(start_col > target_col,
        \ '1C.2/T: start_col > target_col')
      let target_char_col = target_col - 1
    endif

    call Assert(target_char_col >= 1 && target_char_col <= llen,
      \ '1C.2: target_char_col in line bounds')
    let target_char = line[target_char_col - 1]
    call Assert(target_char !=# ' ',
      \ '1C.2: target_char is not whitespace')

    call Assert(abs(target_col - start_col) >= 3,
      \ '1C.2: distance >= 3 from cursor to landing')

    call Assert(line[start_col - 1] !=# ' ',
      \ '1C.2: start not on whitespace')
    call Assert(line[start_col - 1] !=# target_char,
      \ '1C.2: start not on target_char')

    let count_target = 0
    for ci in range(llen)
      if line[ci] ==# target_char | let count_target += 1 | endif
    endfor
    call AssertEq(count_target, 1,
      \ '1C.2: target_char appears exactly once in line')

    let words_in_line = split(line, ' ')
    let cumcol = 1
    for w in words_in_line
      let ws = cumcol
      let we = cumcol + len(w) - 1
      if target_char_col >= ws && target_char_col <= we
        if item.expected_motion ==# 't'
          call Assert(target_char_col - ws >= 3,
            \ '1C.2/t: target_char >= 3 cols from word start')
          call Assert(we - target_char_col >= 1,
            \ '1C.2/t: target_char >= 1 col from word end')
        else
          call Assert(target_char_col - ws >= 1,
            \ '1C.2/T: target_char >= 1 col from word start')
          call Assert(we - target_char_col >= 3,
            \ '1C.2/T: target_char >= 3 cols from word end')
        endif
        break
      endif
      let cumcol += len(w) + 1
    endfor
  endfor

  call Assert(get(seen, 't', 0) == 1, '1C.2: t appeared in samples')
  call Assert(get(seen, 'T', 0) == 1, '1C.2: T appeared in samples')
endfunction

" 1C.3: expected_motion in {; ,}; optimal_motions == 2; target interior
" to its word with margin >= 2; cursor positioned per-scenario; distance
" >= 3; exactly one waypoint at the canonical-sequence's first-stop.
function! s:test_1C_3() abort
  let GenFn = function('vimfluency#pinpoints#p1C_3#generate')
  let valid_motions = [';', ',']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1C.3', item)
    call AssertIn(item.expected_motion, valid_motions,
      \ '1C.3: expected_motion in {; ,}')
    call AssertEq(item.optimal_motions, 2,
      \ '1C.3: optimal_motions == 2')

    let line = item.lines[0]
    let llen = len(line)
    let start_col = item.start[1]
    let target_col = item.target[1]
    let target_char = line[target_col - 1]
    let seen[item.expected_motion] = 1

    call Assert(abs(target_col - start_col) >= 3,
      \ '1C.3: distance >= 3')
    call Assert(target_char !=# ' ',
      \ '1C.3: target_char is not whitespace')

    let cols_for_char = []
    for ci in range(llen)
      if line[ci] ==# target_char | call add(cols_for_char, ci + 1) | endif
    endfor
    call Assert(len(cols_for_char) >= 2,
      \ '1C.3: target_char appears >= 2 times in line')

    call Assert(has_key(item, 'waypoints'), '1C.3: item has waypoints')
    call AssertEq(len(item.waypoints), 1, '1C.3: exactly one waypoint')
    let wp_col = item.waypoints[0][1]
    call Assert(abs(target_col - wp_col) >= 2,
      \ '1C.3: target and waypoint at least 2 cols apart')

    if item.expected_motion ==# ';'
      if start_col < target_col
        " forward ; (fc;): cursor < cols[0]; target == cols[1];
        " waypoint == cols[0].
        call Assert(start_col < cols_for_char[0],
          \ '1C.3/forward;: start before first occurrence')
        call AssertEq(target_col, cols_for_char[1],
          \ '1C.3/forward;: target == second occurrence')
        call AssertEq(wp_col, cols_for_char[0],
          \ '1C.3/forward;: waypoint == first occurrence')
      else
        " backward ; (Fc;): cursor > cols[-1]; target == cols[-2];
        " waypoint == cols[-1].
        call Assert(start_col > cols_for_char[-1],
          \ '1C.3/backward;: start after last occurrence')
        call AssertEq(target_col, cols_for_char[-2],
          \ '1C.3/backward;: target == second-to-last occurrence')
        call AssertEq(wp_col, cols_for_char[-1],
          \ '1C.3/backward;: waypoint == last occurrence')
      endif
    else
      " , scenarios: cursor strictly between cols[0] and cols[1].
      call Assert(start_col > cols_for_char[0]
        \ && start_col < cols_for_char[1],
        \ '1C.3/,: cursor between cols[0] and cols[1]')
      if target_col == cols_for_char[0]
        " fc, : target == cols[0]; waypoint == cols[1].
        call AssertEq(wp_col, cols_for_char[1],
          \ '1C.3/fc,: waypoint == second occurrence')
      else
        " Fc, : target == cols[1]; waypoint == cols[0].
        call AssertEq(target_col, cols_for_char[1],
          \ '1C.3/Fc,: target == second occurrence')
        call AssertEq(wp_col, cols_for_char[0],
          \ '1C.3/Fc,: waypoint == first occurrence')
      endif
    endif

    call Assert(line[start_col - 1] !=# ' ',
      \ '1C.3: start not on whitespace')
    call Assert(line[start_col - 1] !=# target_char,
      \ '1C.3: start not on target_char')

    let words_in_line = split(line, ' ')
    let cumcol = 1
    for w in words_in_line
      let ws = cumcol
      let we = cumcol + len(w) - 1
      if target_col >= ws && target_col <= we
        call Assert(target_col - ws >= 2,
          \ '1C.3: target >= 2 cols from word start')
        call Assert(we - target_col >= 2,
          \ '1C.3: target >= 2 cols from word end')
        break
      endif
      let cumcol += len(w) + 1
    endfor
  endfor

  call Assert(get(seen, ';', 0) == 1, '1C.3: ; appeared in samples')
  call Assert(get(seen, ',', 0) == 1, '1C.3: , appeared in samples')
endfunction

" 1C.4: delegates to p1C_1 / p1C_2 generators. Just verify all four
" motions appear over N samples and every item passes a baseline
" structural check.
function! s:test_1C_4() abort
  let GenFn = function('vimfluency#pinpoints#p1C_4#generate')
  let valid = ['f', 'F', 't', 'T']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1C.4', item)
    call AssertIn(item.expected_motion, valid,
      \ '1C.4: expected_motion in {f, F, t, T}')
    call AssertEq(item.optimal_motions, 1,
      \ '1C.4: optimal_motions == 1')
    let seen[item.expected_motion] = 1
  endfor
  for m in valid
    call Assert(get(seen, m, 0) == 1,
      \ '1C.4: ' . m . ' appeared in samples')
  endfor
endfunction

" --- T0 — recall and mode kinds -----------------------------------
"
" Recall and mode kinds don't carry a live editing area (recall) or
" require a cursor move within an item (mode often doesn't, when the
" cursor returns to its start col after Esc). So they bypass
" s:assert_common — they have their own shape invariants.

" Common shape check for recall items.
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
  call Assert(has_key(item, 'prompt'),
    \ prefix . 'has prompt')
endfunction

" T0.3a–d — save/quit binary discrimination pinpoints. Each one
" picks between exactly two answers. expected_motion mirrors the
" answer; optimal_motions equals the answer's character count.
function! s:test_T0_3_pair(id, module, valid) abort
  let GenFn = function('vimfluency#pinpoints#' . a:module . '#generate')
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

function! s:test_T0_3a() abort
  call s:test_T0_3_pair('T0.3a', 'pT0_3a', [':w', ':q'])
endfunction
function! s:test_T0_3b() abort
  call s:test_T0_3_pair('T0.3b', 'pT0_3b', [':wq', ':q!'])
endfunction
function! s:test_T0_3c() abort
  call s:test_T0_3_pair('T0.3c', 'pT0_3c', [':wq', 'ZZ'])
endfunction
function! s:test_T0_3d() abort
  call s:test_T0_3_pair('T0.3d', 'pT0_3d', [':q!', 'ZQ'])
endfunction

" T0.5 — mode awareness (recall). Each item's answer is one of the
" five named modes; the prompt is a list (multi-line mock cue);
" expected_motion mirrors answer.
function! s:test_T0_5() abort
  let GenFn = function('vimfluency#pinpoints#pT0_5#generate')
  let valid = ['normal', 'insert', 'visual', 'replace', 'command']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_recall_common('T0.5', item)
    call AssertIn(item.expected_answer, valid,
      \ 'T0.5: expected_answer in mode-name set')
    call Assert(type(item.prompt) == v:t_list,
      \ 'T0.5: prompt is a list (mock-screen cue)')
    call AssertEq(item.expected_motion, item.expected_answer,
      \ 'T0.5: expected_motion mirrors expected_answer')
    let seen[item.expected_answer] = 1
  endfor
  for m in valid
    call Assert(get(seen, m, 0) == 1,
      \ 'T0.5: ' . m . ' appeared in samples')
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

" T0.1 — enter / leave insert mode. Four keys, all optimal 2.
" target_lines must equal lines (no buffer change for i/a/I/A).
function! s:test_T0_1() abort
  let GenFn = function('vimfluency#pinpoints#pT0_1#generate')
  let valid = ['i', 'a', 'I', 'A']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_mode_common('T0.1', item)
    call AssertIn(item.expected_motion, valid,
      \ 'T0.1: expected_motion in {i, a, I, A}')
    call AssertEq(item.optimal_motions, 2,
      \ 'T0.1: optimal_motions == 2 (key + Esc)')
    call AssertEq(item.target_lines, item.lines,
      \ 'T0.1: target_lines == lines (no buffer change)')
    " Disambiguation requirements per key:
    let line = item.lines[0]
    let sc = item.start[1]
    if item.expected_motion ==# 'i'
      call AssertEq(item.enter_at_col, sc,
        \ 'T0.1[i]: enter_at_col == start_col')
      call Assert(sc > 1,
        \ 'T0.1[i]: start_col > 1 (S=1 makes post-Esc target degenerate at 1)')
      call AssertEq(item.target[1], sc - 1,
        \ 'T0.1[i]: target_col == start_col - 1')
    elseif item.expected_motion ==# 'a'
      call AssertEq(item.enter_at_col, sc + 1,
        \ 'T0.1[a]: enter_at_col == start_col + 1')
      call Assert(sc < len(line),
        \ 'T0.1[a]: start_col < line_end (S=line_end makes a ≡ A at runner level)')
      call AssertEq(item.target[1], sc,
        \ 'T0.1[a]: target_col == start_col')
    elseif item.expected_motion ==# 'I'
      let fnb = match(line, '\S') + 1
      call AssertEq(item.enter_at_col, fnb,
        \ 'T0.1[I]: enter_at_col == first_nonblank')
      call Assert(fnb > 1,
        \ 'T0.1[I]: line has leading whitespace (fnb > 1)')
      call Assert(sc != fnb && sc != fnb - 1,
        \ 'T0.1[I]: start_col differs from fnb and fnb-1 '
        \ . '(else i/a from same S match I at runner level)')
      call AssertEq(item.target[1], fnb - 1,
        \ 'T0.1[I]: target_col == first_nonblank - 1')
    elseif item.expected_motion ==# 'A'
      call AssertEq(item.enter_at_col, len(line) + 1,
        \ 'T0.1[A]: enter_at_col == line_len + 1')
      call Assert(sc < len(line),
        \ 'T0.1[A]: start_col < line_end (else a ≡ A at runner level)')
      call AssertEq(item.target[1], len(line),
        \ 'T0.1[A]: target_col == line_end')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'T0.1: ' . k . ' appeared in samples')
  endfor
endfunction

" T0.2 — open new line. Two keys, optimal 2. The pre-press buffer has
" two adjacent rows marked with '⏵' (the bracket rows around the gap)
" and the rest of the rows prefixed with a space for column alignment.
" The cursor sits on one bracket row; the post-press buffer has a new
" blank line inserted between the two brackets.
function! s:test_T0_2() abort
  let GenFn = function('vimfluency#pinpoints#pT0_2#generate')
  let valid = ['o', 'O']
  let mark = '⏵'
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_mode_common('T0.2', item)
    call AssertIn(item.expected_motion, valid,
      \ 'T0.2: expected_motion in {o, O}')
    call AssertEq(item.optimal_motions, 2,
      \ 'T0.2: optimal_motions == 2')
    call AssertEq(len(item.target_lines), len(item.lines) + 1,
      \ 'T0.2: target_lines has one more line than lines (the new blank)')

    " Find the two bracket rows (those prefixed with the ⏵ mark).
    let bracket_rows = []
    for row in range(1, len(item.lines))
      if strpart(item.lines[row - 1], 0, len(mark)) ==# mark
        call add(bracket_rows, row)
      endif
    endfor
    call AssertEq(len(bracket_rows), 2,
      \ 'T0.2: lines contains exactly two ⏵-prefixed bracket rows')
    if len(bracket_rows) == 2
      call AssertEq(bracket_rows[1] - bracket_rows[0], 1,
        \ 'T0.2: bracket rows are adjacent (single-row gap between them)')
    endif

    " The new blank in target_lines sits between the two bracket rows.
    let blank_row = index(item.target_lines, '') + 1
    call AssertEq(blank_row, bracket_rows[0] + 1,
      \ 'T0.2: new blank appears between the two bracket rows')

    if item.expected_motion ==# 'o'
      call AssertEq(item.start[0], bracket_rows[0],
        \ 'T0.2[o]: cursor on the UPPER bracket row (other ⏵ below)')
    else
      call AssertEq(item.start[0], bracket_rows[1],
        \ 'T0.2[O]: cursor on the LOWER bracket row (other ⏵ above)')
    endif
    let seen[item.expected_motion] = 1
  endfor
  for k in valid
    call Assert(get(seen, k, 0) == 1,
      \ 'T0.2: ' . k . ' appeared in samples')
  endfor
endfunction

call s:test_1A_1()
call s:test_1A_2()
call s:test_1B_1()
call s:test_1B_2()
call s:test_1C_1()
call s:test_1C_2()
call s:test_1C_3()
call s:test_1C_4()
call s:test_2_1()
call s:test_2_2()
call s:test_4_1()
call s:test_T0_1()
call s:test_T0_2()
call s:test_T0_3a()
call s:test_T0_3b()
call s:test_T0_3c()
call s:test_T0_3d()
call s:test_T0_5()
