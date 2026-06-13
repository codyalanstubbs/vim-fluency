" general — the default 'everything' path. include_all=1 means the
" path encompasses every drill in the registry; no per-drill
" curation is needed and the catalog grows / shrinks here
" automatically as drills land or get removed.
"
" Used as the fallback when settings.current_path is unset or
" points to a path file that no longer exists.

function! vimfluency#paths#general#meta() abort
  return {'id': 'general',
    \ 'name': 'General',
    \ 'description': 'All shipped drills — no curation. The default path.',
    \ 'include_all': 1,
    \ 'drill_ids': []}
endfunction
