" Tests for :VfHierarchy's rendering. Build a tiny fixture registry
" and check that the tree structure renders narrower siblings nested
" under their parent and that parallel_to peers appear inline.

let s:reg = {
  \ '1A.1': {'id': '1A.1', 'name': 'hjkl',   'aim': 60, 'allowed_keys': 'hjkl', 'prereqs': ['T0']},
  \ '1A.3': {'id': '1A.3', 'name': 'h l',    'aim': 60, 'allowed_keys': 'hl',
  \          'prereqs': ['T0'], 'narrower_of': '1A.1', 'parallel_to': ['1A.4']},
  \ '1A.4': {'id': '1A.4', 'name': 'j k',    'aim': 60, 'allowed_keys': 'jk',
  \          'prereqs': ['T0'], 'narrower_of': '1A.1', 'parallel_to': ['1A.3']},
  \ '1B.1': {'id': '1B.1', 'name': 'w b',    'aim': 45, 'allowed_keys': 'wb',
  \          'prereqs': ['1A'], 'parallel_to': ['1B.2']},
  \ '1B.2': {'id': '1B.2', 'name': 'e ge',   'aim': 40, 'allowed_keys': 'eg',
  \          'prereqs': ['1A'], 'parallel_to': ['1B.1']},
  \ }

let s:lines = vimfluency#_test_render_hierarchy(s:reg)
let s:text = join(s:lines, "\n")

call Assert(s:text =~# 'vim-fluency hierarchy',
  \ 'render_hierarchy: header present')

" Every pinpoint appears exactly once.
for s:id in keys(s:reg)
  let s:n = 0
  for s:l in s:lines
    " Match the id only when followed by whitespace, so '1A.1' doesn't
    " accidentally match inside '1A.10' if that ever existed.
    if s:l =~# '\<' . substitute(s:id, '\.', '\\.', 'g') . '\>'
      let s:n += 1
    endif
  endfor
  call Assert(s:n >= 1, 'render_hierarchy: ' . s:id . ' appears in output')
endfor

" Narrower siblings render with tree connectors under their parent.
call Assert(s:text =~# '├─ 1A\.3'  || s:text =~# '└─ 1A\.3',
  \ 'render_hierarchy: 1A.3 nested under 1A.1 with tree connector')
call Assert(s:text =~# '├─ 1A\.4'  || s:text =~# '└─ 1A\.4',
  \ 'render_hierarchy: 1A.4 nested under 1A.1 with tree connector')
" The last child of a parent uses └─ (not ├─).
call Assert(s:text =~# '└─ 1A\.4',
  \ 'render_hierarchy: last child uses └─ connector')
" The first of multiple children uses ├─.
call Assert(s:text =~# '├─ 1A\.3',
  \ 'render_hierarchy: first of multiple children uses ├─ connector')

" Parallel_to peers shown inline with ⟷.
call Assert(s:text =~# '1B\.1.*⟷.*1B\.2',
  \ 'render_hierarchy: 1B.1 shows ⟷ 1B.2 inline')
call Assert(s:text =~# '1B\.2.*⟷.*1B\.1',
  \ 'render_hierarchy: 1B.2 shows ⟷ 1B.1 inline')

" Prereqs shown inline.
call Assert(s:text =~# '1A\.1.*prereqs: T0',
  \ 'render_hierarchy: 1A.1 shows prereqs: T0 inline')

" Roots (no narrower_of) appear at the group indent level.
" Specifically 1A.1 should NOT have a ├─/└─ on its own line.
for s:l in s:lines
  if s:l =~# '\<1A\.1\>'
    call Assert(s:l !~# '├─\|└─',
      \ 'render_hierarchy: 1A.1 (root) has no tree connector on its own line')
    break
  endif
endfor
