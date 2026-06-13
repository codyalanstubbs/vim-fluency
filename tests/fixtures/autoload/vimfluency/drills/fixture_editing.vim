" Fixture editing drill (kind=editing). Items pulled from
" g:vf_fixture_editing_items; index in g:vf_fixture_editing_idx.

function! vimfluency#drills#fixture_editing#meta() abort
  return {'id': 'fixture_editing', 'name': 'fixture editing',
    \ 'aim': 30, 'allowed_keys': 'dwbe', 'kind': 'editing'}
endfunction

function! vimfluency#drills#fixture_editing#generate() abort
  let items = get(g:, 'vf_fixture_editing_items', [])
  if empty(items)
    return {'lines': ['hello world'], 'target_lines': ['world'],
      \ 'start': [1,1], 'target': [1,1],
      \ 'expected_motion': 'dw', 'optimal_motions': 1,
      \ 'deletion_range': [[1,1,6]],
      \ 'prompt': 'delete the first word'}
  endif
  let idx = get(g:, 'vf_fixture_editing_idx', 0)
  let item = items[idx % len(items)]
  let g:vf_fixture_editing_idx = idx + 1
  return deepcopy(item)
endfunction
