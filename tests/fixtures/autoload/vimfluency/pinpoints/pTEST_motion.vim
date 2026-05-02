" Fixture motion pinpoint. Generated items come from g:vf_fixture_items
" in order; index lives in g:vf_fixture_idx (so tests can reset by
" reassigning these globals). When the queue is exhausted it wraps —
" matches the behavior of real generators that produce indefinitely.
"
" Only loaded when tests/fixtures is on the runtimepath, so this never
" pollutes a real :VfList.

function! vimfluency#pinpoints#pTEST_motion#meta() abort
  return {'id': 'TEST.motion', 'name': 'fixture motion',
    \ 'aim': 60, 'allowed_keys': 'hjklwbe'}
endfunction

function! vimfluency#pinpoints#pTEST_motion#generate() abort
  let items = get(g:, 'vf_fixture_items', [])
  if empty(items)
    return {'lines': ['abcdefghij'], 'start': [1,1], 'target': [1,3],
      \ 'expected_motion': 'l', 'optimal_motions': 2}
  endif
  let idx = get(g:, 'vf_fixture_idx', 0)
  let item = items[idx % len(items)]
  let g:vf_fixture_idx = idx + 1
  return deepcopy(item)
endfunction
