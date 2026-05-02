" Runner integration tests. Drive the probe state machine via cursor()
" + doautocmd against fixture pinpoints, asserting on counters and state
" transitions that generator-level tests can't observe.
"
" These tests exist because the 2026-04-30 motion-count regression
" (vim's deferred CursorMoved firing after in-handler cursor() inflated
" total_motions on every item transition) was a *runner* bug —
" generator-level property tests couldn't have caught it.
"
" Driving model: vim's batch mode (-Es) doesn't run an event loop, so
" CursorMoved doesn't fire automatically on cursor() / feedkeys / :normal.
" We move the cursor explicitly and fire `doautocmd CursorMoved`. This
" still exercises s:on_change end-to-end (its early-return guard, target
" matching, item bookkeeping) — what it does NOT exercise is vim's own
" deferred-autocmd timing. We compensate by manually firing CursorMoved
" at item-start position to simulate the deferred fire (test #1).

let s:dur = 600

function! s:set_motion_fixture(items) abort
  let g:vf_fixture_items = a:items
  let g:vf_fixture_idx = 0
endfunction

function! s:set_editing_fixture(items) abort
  let g:vf_fixture_editing_items = a:items
  let g:vf_fixture_editing_idx = 0
endfunction

function! s:cleanup() abort
  if !empty(vimfluency#_test_state())
    silent! call vimfluency#stop('test_cleanup')
  endif
  silent! call vimfluency#close_summary()
  while tabpagenr('$') > 1
    silent! tabclose!
  endwhile
endfunction

" Move cursor + fire CursorMoved. Coordinates are buffer-absolute.
function! s:move(row, col) abort
  call cursor(a:row, a:col)
  doautocmd CursorMoved
endfunction

" Buffer-coords helpers that account for editing-kind header_offset.
function! s:item_row(item_row) abort
  let st = vimfluency#_test_state()
  return get(st, 'header_offset', 0) + a:item_row
endfunction

function! s:move_item(item_row, col) abort
  call s:move(s:item_row(a:item_row), a:col)
endfunction

" Replace a single line in the editing area, then move + fire.
function! s:edit_line(item_row, col, new_text) abort
  let buf_row = s:item_row(a:item_row)
  call setline(buf_row, a:new_text)
  call s:move(buf_row, a:col)
endfunction

" --- 1) deferred-fire guard at item transition -------------------------
" Drive item 1 to credit, then manually fire CursorMoved at item-2's
" start position (simulating vim's deferred fire after s:next_item's
" cursor() call). Without the early-return guard in s:on_change this
" would inflate item 2's count by 1; with the guard it's a no-op.
function! s:test_no_motion_count_inflation() abort
  call s:set_motion_fixture([
    \ {'lines': ['abcdefghij'], 'start': [1,1], 'target': [1,4],
    \  'expected_motion': 'l', 'optimal_motions': 3},
    \ {'lines': ['abcdefghij'], 'start': [1,1], 'target': [1,3],
    \  'expected_motion': 'l', 'optimal_motions': 2},
    \ ])
  call vimfluency#start('TEST.motion', s:dur)
  call s:move_item(1, 2)
  call s:move_item(1, 3)
  call s:move_item(1, 4)
  " Credit fired; runner advanced to item 2 and placed cursor at (1,1).
  " Simulate vim's deferred CursorMoved for that cursor() call:
  doautocmd CursorMoved
  let st = vimfluency#_test_state()
  call AssertEq(st.current_item_motions, 0,
    \ 'runner: deferred fire at item start does not increment motions')
  call s:move_item(1, 2)
  call s:move_item(1, 3)
  call AssertEq(st.items_correct, 2, 'runner: 2 items credited')
  call AssertEq(st.total_motions, 5,
    \ 'runner: total_motions == 5 across two items (no transition inflation)')
  call AssertEq(st.total_optimal_motions, 5,
    \ 'runner: total_optimal_motions == 5')
  call s:cleanup()
endfunction

" --- 2) wrong motion records but doesn't auto-advance (free-operant) ---
function! s:test_wrong_motion_free_operant() abort
  call s:set_motion_fixture([
    \ {'lines': ['abcdefghij','abcdefghij','abcdefghij'],
    \  'start': [2,5], 'target': [2,7],
    \  'expected_motion': 'l', 'optimal_motions': 2},
    \ ])
  call vimfluency#start('TEST.motion', s:dur)
  let st = vimfluency#_test_state()
  call s:move_item(3, 5)
  call AssertEq(st.items_correct, 0,
    \ 'runner: wrong motion does not credit the item')
  call AssertEq(st.current_item_motions, 1,
    \ 'runner: wrong motion increments current_item_motions')
  call s:move_item(2, 5)
  call s:move_item(2, 6)
  call s:move_item(2, 7)
  call AssertEq(st.items_correct, 1, 'runner: recovery to target credits item')
  call AssertEq(st.total_motions, 4,
    \ 'runner: total_motions counts all 4 cursor moves (1 wrong + 3 recovery)')
  call s:cleanup()
endfunction

" --- 3) Tab skip --------------------------------------------------------
" The Tab key is bound via :nnoremap <buffer> <Tab> :call <SID>skip()<CR>.
" :normal \<Tab> is unreliable in -Es batch mode, so we exercise the skip
" path through vimfluency#_test_skip() and separately verify the buffer
" mapping is installed (so a regression in registration is still caught).
function! s:test_tab_skip() abort
  call s:set_motion_fixture([
    \ {'lines': ['abcdefghij'], 'start': [1,1], 'target': [1,5],
    \  'expected_motion': 'l', 'optimal_motions': 4},
    \ {'lines': ['abcdefghij'], 'start': [1,1], 'target': [1,3],
    \  'expected_motion': 'l', 'optimal_motions': 2},
    \ ])
  call vimfluency#start('TEST.motion', s:dur)
  call Assert(!empty(maparg('<Tab>', 'n')),
    \ 'runner: <Tab> mapping installed on probe buffer')
  call vimfluency#_test_skip()
  let st = vimfluency#_test_state()
  call AssertEq(st.items_skipped, 1, 'runner: skip path marks item skipped')
  call AssertEq(st.items_correct, 0, 'runner: skip does not credit a correct')
  call s:cleanup()
endfunction

" --- 4) per-motion accounting (mixed motions in one session) -----------
function! s:test_per_motion_accounting() abort
  call s:set_motion_fixture([
    \ {'lines': ['abcdefghij'], 'start': [1,1], 'target': [1,3],
    \  'expected_motion': 'l', 'optimal_motions': 2},
    \ {'lines': ['abcdefghij','abcdefghij','abcdefghij'],
    \  'start': [3,1], 'target': [2,1],
    \  'expected_motion': 'k', 'optimal_motions': 1},
    \ ])
  call vimfluency#start('TEST.motion', s:dur)
  call s:move_item(1, 2)
  call s:move_item(1, 3)
  call s:move_item(2, 1)
  let st = vimfluency#_test_state()
  call AssertEq(st.items_correct, 2, 'runner: both items credited')
  call Assert(has_key(st.per_motion, 'l'), 'runner: per_motion has l bucket')
  call Assert(has_key(st.per_motion, 'k'), 'runner: per_motion has k bucket')
  call AssertEq(st.per_motion.l.correct, 1, 'runner: l correct == 1')
  call AssertEq(st.per_motion.k.correct, 1, 'runner: k correct == 1')
  call AssertEq(st.per_motion.l.motions_total, 2,
    \ 'runner: l motions_total == 2')
  call AssertEq(st.per_motion.k.motions_total, 1,
    \ 'runner: k motions_total == 1')
  call AssertEq(st.per_motion.l.optimal_total, 2,
    \ 'runner: l optimal_total == 2')
  call AssertEq(st.per_motion.k.optimal_total, 1,
    \ 'runner: k optimal_total == 1')
  call s:cleanup()
endfunction

" --- 5) editing-kind flow (buffer changes, not just cursor moves) -----
" Replace 'hello world' with 'world' (simulating dw at col 1) and verify
" the runner credits when target_lines + cursor both match.
function! s:test_editing_kind() abort
  call s:set_editing_fixture([
    \ {'lines': ['hello world'], 'target_lines': ['world'],
    \  'start': [1,1], 'target': [1,1],
    \  'expected_motion': 'dw', 'optimal_motions': 1,
    \  'deletion_range': [[1,1,6]],
    \  'prompt': 'delete first word'},
    \ ])
  call vimfluency#start('TEST.editing', s:dur)
  call s:edit_line(1, 1, 'world')
  let st = vimfluency#_test_state()
  call AssertEq(st.items_correct, 1, 'runner: editing dw credits item')
  call AssertEq(st.total_optimal_motions, 1,
    \ 'runner: editing optimal accumulates')
  call Assert(has_key(st.per_motion, 'dw'),
    \ 'runner: editing per_motion has dw bucket')
  call s:cleanup()
endfunction

" --- 6) stop() writes a well-formed JSONL record -----------------------
function! s:test_stop_persists_jsonl() abort
  call s:set_motion_fixture([
    \ {'lines': ['abcdefghij'], 'start': [1,1], 'target': [1,3],
    \  'expected_motion': 'l', 'optimal_motions': 2},
    \ ])
  call vimfluency#start('TEST.motion', s:dur)
  call s:move_item(1, 2)
  call s:move_item(1, 3)
  call vimfluency#stop('test_persist')

  let log = vimfluency#log_dir() . '/sessions.jsonl'
  call Assert(filereadable(log), 'runner: sessions.jsonl created')
  let raw = readfile(log)
  call Assert(!empty(raw), 'runner: sessions.jsonl has lines')
  let rec = json_decode(raw[-1])
  call AssertEq(rec.pinpoint_id, 'TEST.motion',
    \ 'runner: record pinpoint_id')
  call AssertEq(rec.items_correct, 1,
    \ 'runner: record items_correct')
  call AssertEq(rec.total_motions, 2,
    \ 'runner: record total_motions')
  call AssertEq(rec.total_optimal_motions, 2,
    \ 'runner: record total_optimal_motions')
  call AssertEq(rec.end_reason, 'test_persist',
    \ 'runner: record end_reason')
  call Assert(has_key(rec, 'per_motion'),
    \ 'runner: record has per_motion')
  call Assert(has_key(rec.per_motion, 'l'),
    \ 'runner: record per_motion has l')
  call Assert(has_key(rec, 'items') && len(rec.items) >= 1,
    \ 'runner: record has items log')
  call s:cleanup()
endfunction

call s:test_no_motion_count_inflation()
call s:test_wrong_motion_free_operant()
call s:test_tab_skip()
call s:test_per_motion_accounting()
call s:test_editing_kind()
call s:test_stop_persists_jsonl()
