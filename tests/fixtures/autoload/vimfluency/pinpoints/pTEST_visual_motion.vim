" Fixture visual_motion pinpoint. Generated items come from
" g:vf_fixture_visual_items in order; index lives in
" g:vf_fixture_visual_idx. Wraps when the queue is exhausted, same
" pattern as pTEST_motion. Lives only in tests/fixtures/ so it never
" appears in a real :VfList.

function! vimfluency#pinpoints#pTEST_visual_motion#meta() abort
  return {'id': 'TEST.visual_motion', 'name': 'fixture visual_motion',
    \ 'aim': 60, 'allowed_keys': 'vhjkl', 'kind': 'visual_motion'}
endfunction

function! vimfluency#pinpoints#pTEST_visual_motion#generate() abort
  let items = get(g:, 'vf_fixture_visual_items', [])
  if empty(items)
    return {'lines': ['abcdefghij'], 'start': [1, 4], 'target': [1, 5],
      \ 'expected_selection_start': [1, 4],
      \ 'expected_selection_end': [1, 5],
      \ 'expected_sub_mode': 'v',
      \ 'expected_motion': 'vl', 'optimal_motions': 2}
  endif
  let idx = get(g:, 'vf_fixture_visual_idx', 0)
  let item = items[idx % len(items)]
  let g:vf_fixture_visual_idx = idx + 1
  return deepcopy(item)
endfunction
