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

" 1B.1: expected_motion ∈ {w, b, e, ge}; optimal_motions in [2, 5].
function! s:test_1B_1() abort
  let GenFn = function('vimfluency#pinpoints#p1B_1#generate')
  let valid = ['w', 'b', 'e', 'ge']
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('1B.1', item)
    call AssertIn(item.expected_motion, valid,
      \ '1B.1: expected_motion in {w, b, e, ge}')
    call Assert(item.optimal_motions >= 2 && item.optimal_motions <= 5,
      \ '1B.1: optimal_motions in [2, 5], got ' . item.optimal_motions)
  endfor
endfunction

" 4.d: editing kind; expected_motion ∈ {dw, db}; deletion_range matches
" the actual delta between start_lines and target_lines.
function! s:test_4_d() abort
  let GenFn = function('vimfluency#pinpoints#p4_d#generate')
  let valid = ['dw', 'db']
  let seen = {}
  for i in range(s:N)
    let item = GenFn()
    call s:assert_common('4.d', item)
    call AssertIn(item.expected_motion, valid,
      \ '4.d: expected_motion in {dw, db}')
    call AssertEq(item.optimal_motions, 1, '4.d: optimal_motions == 1')
    let seen[item.expected_motion] = 1

    " editing-kind invariants
    call Assert(has_key(item, 'target_lines'), '4.d: has target_lines')
    call Assert(has_key(item, 'deletion_range'), '4.d: has deletion_range')
    call Assert(!empty(item.deletion_range), '4.d: deletion_range non-empty')

    let start_words = split(item.lines[0])
    let target_words = split(item.target_lines[0])
    call AssertEq(len(target_words), len(start_words) - 1,
      \ '4.d: target has one fewer word')

    " deletion_range cols + length should match the actual length removed
    let removed_chars = len(item.lines[0]) - len(item.target_lines[0])
    let total_len = 0
    for pos in item.deletion_range
      let total_len += pos[2]
    endfor
    call AssertEq(total_len, removed_chars,
      \ '4.d: deletion_range length matches chars actually removed')

    " for dw: target_cursor col == start_cursor col (cursor stays put)
    " for db: target_cursor col < start_cursor col (cursor jumps back)
    if item.expected_motion ==# 'dw'
      call AssertEq(item.target[1], item.start[1],
        \ '4.d/dw: target col == start col')
    else
      call Assert(item.target[1] < item.start[1],
        \ '4.d/db: target col < start col')
    endif
  endfor

  " Both motions should appear in 50 generates with high probability
  call Assert(get(seen, 'dw', 0) == 1, '4.d: dw appeared in samples')
  call Assert(get(seen, 'db', 0) == 1, '4.d: db appeared in samples')

  let meta = vimfluency#pinpoints#p4_d#meta()
  call AssertEq(get(meta, 'kind', 'motion'), 'editing',
    \ '4.d: meta.kind == editing')
endfunction

call s:test_1A_1()
call s:test_1A_2()
call s:test_1B_1()
call s:test_4_d()
