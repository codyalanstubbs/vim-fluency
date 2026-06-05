" general — the default 'everything' path. include_all=1 means the
" path encompasses every pinpoint in the registry; no per-pinpoint
" curation is needed and the catalog grows / shrinks here
" automatically as pinpoints land or get removed.
"
" Used as the fallback when settings.current_path is unset or
" points to a path file that no longer exists.

function! vimfluency#paths#general#meta() abort
  return {'id': 'general',
    \ 'name': 'General',
    \ 'description': 'All shipped pinpoints — no curation. The default path.',
    \ 'include_all': 1,
    \ 'pinpoint_ids': []}
endfunction
