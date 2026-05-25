" Tests for :VfHierarchy's rendering. Build a tiny fixture registry
" and check that pinpoints are grouped by prereq signature, that
" sections render in topological order, and that parallel_to /
" narrower_of annotations appear inline.

let s:reg = {
  \ 'T0.1': {'id': 'T0.1', 'name': 'enter / leave insert', 'aim': 50,
  \          'allowed_keys': 'iaEsc', 'prereqs': []},
  \ 'T0.2': {'id': 'T0.2', 'name': 'open new line',        'aim': 40,
  \          'allowed_keys': 'oO',    'prereqs': ['T0.1']},
  \ '1A.1': {'id': '1A.1', 'name': 'hjkl',                 'aim': 60,
  \          'allowed_keys': 'hjkl',  'prereqs': ['T0']},
  \ '1A.3': {'id': '1A.3', 'name': 'h l',                  'aim': 60,
  \          'allowed_keys': 'hl',    'prereqs': ['T0'],
  \          'narrower_of': '1A.1', 'parallel_to': ['1A.4']},
  \ '1A.4': {'id': '1A.4', 'name': 'j k',                  'aim': 60,
  \          'allowed_keys': 'jk',    'prereqs': ['T0'],
  \          'narrower_of': '1A.1', 'parallel_to': ['1A.3']},
  \ '1B.1': {'id': '1B.1', 'name': 'w b',                  'aim': 45,
  \          'allowed_keys': 'wb',    'prereqs': ['1A'],
  \          'parallel_to': ['1B.2']},
  \ '1B.2': {'id': '1B.2', 'name': 'e ge',                 'aim': 40,
  \          'allowed_keys': 'eg',    'prereqs': ['1A'],
  \          'parallel_to': ['1B.1']},
  \ }

let s:lines = vimfluency#_test_render_hierarchy(s:reg)
let s:text = join(s:lines, "\n")

call Assert(s:text =~# 'vim-fluency hierarchy',
  \ 'render_hierarchy: header present')

" Every pinpoint appears exactly once across the body (the legend may
" mention IDs in narrower-of/parallel-to annotations).
for s:id in keys(s:reg)
  let s:n_rows = 0
  for s:l in s:lines
    " Match the id as a left-aligned column entry (after the leading indent).
    if s:l =~# '^\s\+' . substitute(s:id, '\.', '\\.', 'g') . '\>'
      let s:n_rows += 1
    endif
  endfor
  call AssertEq(s:n_rows, 1,
    \ 'render_hierarchy: ' . s:id . ' appears in exactly one section')
endfor

" Section headers for the prereq signatures present in the fixture.
call Assert(s:text =~# 'no prereqs',
  \ 'render_hierarchy: roots section header present')
call Assert(s:text =~# 'depends on T0\.1',
  \ 'render_hierarchy: T0.1 section header present')
call Assert(s:text =~# 'depends on T0\>',
  \ 'render_hierarchy: T0-group section header present')
call Assert(s:text =~# 'depends on 1A\>',
  \ 'render_hierarchy: 1A-group section header present')

" Topological order: roots come before things that depend on T0.1,
" and the T0 group section comes after T0.1 specifically.
function! s:index_of(lines, pattern) abort
  for i in range(len(a:lines))
    if a:lines[i] =~# a:pattern | return i | endif
  endfor
  return -1
endfunction

let s:idx_roots   = s:index_of(s:lines, 'no prereqs')
let s:idx_t0_1    = s:index_of(s:lines, 'depends on T0\.1')
let s:idx_t0_grp  = s:index_of(s:lines, 'depends on T0\>')
let s:idx_1a_grp  = s:index_of(s:lines, 'depends on 1A\>')

call Assert(s:idx_roots >= 0 && s:idx_roots < s:idx_t0_1,
  \ 'render_hierarchy: roots section precedes "depends on T0.1"')
call Assert(s:idx_t0_grp < s:idx_1a_grp,
  \ 'render_hierarchy: "depends on T0" precedes "depends on 1A"')

" parallel_to inline.
call Assert(s:text =~# '1B\.1\s\+w b.*⟷.*1B\.2',
  \ 'render_hierarchy: 1B.1 shows ⟷ 1B.2 inline')

" narrower_of inline.
call Assert(s:text =~# '1A\.3\s\+h l.*narrower of 1A\.1',
  \ 'render_hierarchy: 1A.3 shows narrower of 1A.1 inline')
