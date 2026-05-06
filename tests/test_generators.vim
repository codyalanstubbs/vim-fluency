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
  call Assert(trow >= 1 && trow <= len(item.lines),
    \ prefix . 'target row in bounds (' . trow . '/' . len(item.lines) . ')')
  let tline = item.lines[trow - 1]
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

call s:test_1A_1()
call s:test_1A_2()
call s:test_1B_1()
call s:test_1B_2()
call s:test_1C_1()
call s:test_1C_2()
call s:test_1C_3()
call s:test_1C_4()
call s:test_4_1()
