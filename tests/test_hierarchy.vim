" Tests for :VfHierarchy's rendering. Build a tiny fixture registry
" and check that pinpoints are grouped by prereq signature, that
" sections render in topological order, and that parallel_to /
" narrower_of annotations appear inline.

let s:reg = {
  \ 'insert_basic': {'id': 'insert_basic', 'name': 'enter / leave insert',
  \                  'aim': 50, 'allowed_keys': 'iaEsc', 'prereqs': []},
  \ 'open_line_above_below': {'id': 'open_line_above_below', 'name': 'open new line',
  \                          'aim': 40, 'allowed_keys': 'oO', 'prereqs': ['insert_basic']},
  \ 'recognize_current_mode': {'id': 'recognize_current_mode', 'name': 'mode awareness',
  \                            'aim': 120, 'allowed_keys': 'nivr:', 'prereqs': []},
  \ 'hjkl_broad': {'id': 'hjkl_broad', 'name': 'hjkl', 'aim': 60,
  \                'allowed_keys': 'hjkl',
  \                'prereqs': ['recognize_current_mode', 'insert_basic']},
  \ 'hl': {'id': 'hl', 'name': 'h l', 'aim': 60, 'allowed_keys': 'hl',
  \        'prereqs': ['recognize_current_mode', 'insert_basic'],
  \        'narrower_of': 'hjkl_broad', 'parallel_to': ['jk']},
  \ 'jk': {'id': 'jk', 'name': 'j k', 'aim': 60, 'allowed_keys': 'jk',
  \        'prereqs': ['recognize_current_mode', 'insert_basic'],
  \        'narrower_of': 'hjkl_broad', 'parallel_to': ['hl']},
  \ 'wb': {'id': 'wb', 'name': 'w b', 'aim': 45, 'allowed_keys': 'wb',
  \        'prereqs': ['hjkl_broad'], 'parallel_to': ['ege']},
  \ 'ege': {'id': 'ege', 'name': 'e ge', 'aim': 40, 'allowed_keys': 'eg',
  \        'prereqs': ['hjkl_broad'], 'parallel_to': ['wb']},
  \ }

let s:lines = vimfluency#_test_render_hierarchy(s:reg)
let s:text = join(s:lines, "\n")

call Assert(s:text =~# 'vim-fluency hierarchy',
  \ 'render_hierarchy: header present')

" Every pinpoint appears exactly once across the body.
for s:id in keys(s:reg)
  let s:n_rows = 0
  for s:l in s:lines
    if s:l =~# '^\s\+' . s:id . '\>'
      let s:n_rows += 1
    endif
  endfor
  call AssertEq(s:n_rows, 1,
    \ 'render_hierarchy: ' . s:id . ' appears in exactly one section')
endfor

" Section headers for the prereq signatures present in the fixture.
call Assert(s:text =~# 'no prereqs',
  \ 'render_hierarchy: roots section header present')
call Assert(s:text =~# 'depends on insert_basic\>',
  \ 'render_hierarchy: insert_basic-only section header present')
call Assert(s:text =~# 'depends on insert_basic, recognize_current_mode',
  \ 'render_hierarchy: T0-equivalent section header present')
call Assert(s:text =~# 'depends on hjkl_broad',
  \ 'render_hierarchy: hjkl-prereq section header present')

" Topological order: roots before "depends on insert_basic" (which depends
" on a root), which is before "depends on hjkl_broad" (depends on something
" at depth 1).
function! s:index_of(lines, pattern) abort
  for i in range(len(a:lines))
    if a:lines[i] =~# a:pattern | return i | endif
  endfor
  return -1
endfunction

let s:idx_roots   = s:index_of(s:lines, 'no prereqs')
let s:idx_ib_only = s:index_of(s:lines, 'depends on insert_basic\>')
let s:idx_t0_grp  = s:index_of(s:lines, 'depends on insert_basic, recognize_current_mode')
let s:idx_hjkl    = s:index_of(s:lines, 'depends on hjkl_broad')

call Assert(s:idx_roots >= 0 && s:idx_roots < s:idx_ib_only,
  \ 'render_hierarchy: roots section precedes "depends on insert_basic"')
call Assert(s:idx_t0_grp < s:idx_hjkl,
  \ 'render_hierarchy: T0-equivalent section precedes hjkl-prereq section')

" parallel_to inline.
call Assert(s:text =~# 'wb\s\+w b.*⟷.*ege',
  \ 'render_hierarchy: wb shows ⟷ ege inline')

" narrower_of inline.
call Assert(s:text =~# 'hl\s\+h l.*narrower of hjkl_broad',
  \ 'render_hierarchy: hl shows narrower of hjkl_broad inline')
