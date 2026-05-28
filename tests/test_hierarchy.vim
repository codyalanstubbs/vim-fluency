" Tests for :VfHierarchy's prereq-tree rendering. Build a tiny fixture
" registry and check that each pinpoint nests under its primary prereq,
" that roots carry the ● marker, that secondary prereqs surface as
" ·needs tags, and that parallel_to / narrower_of annotations appear
" inline. Children are deeper-indented than their parent.

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

" A node line places the id right after a tree connector ('─ <id>').
" Annotation mentions ('·needs <id>', '⟷ <id>', 'narrower of <id>') are
" preceded by a space, not the connector, so they don't count as nodes.
function! s:node_line(lines, id) abort
  for l in a:lines
    if l =~# '─ ' . a:id . '\>'
      return l
    endif
  endfor
  return ''
endfunction

" Display-column where the id starts on its node line = width of the
" tree art before it. Deeper nodes have wider art.
function! s:indent_of(lines, id) abort
  let l = s:node_line(a:lines, a:id)
  return strdisplaywidth(strpart(l, 0, match(l, a:id . '\>')))
endfunction

" Every pinpoint appears as a node exactly once.
for s:id in keys(s:reg)
  let s:n = 0
  for s:l in s:lines
    if s:l =~# '─ ' . s:id . '\>' | let s:n += 1 | endif
  endfor
  call AssertEq(s:n, 1, 'render_hierarchy: ' . s:id . ' is a node exactly once')
endfor

" Roots carry the ● marker; non-roots do not.
call Assert(s:text =~# '●─ insert_basic\>',
  \ 'render_hierarchy: insert_basic is a ● root')
call Assert(s:text =~# '●─ recognize_current_mode\>',
  \ 'render_hierarchy: recognize_current_mode is a ● root')
call Assert(s:node_line(s:lines, 'hjkl_broad') !~# '●',
  \ 'render_hierarchy: hjkl_broad is not a root')

" Primary parent: hjkl_broad's prereqs tie at depth 0, so insert_basic
" (alphabetically first) is the parent and recognize_current_mode shows
" as a ·needs tag.
call Assert(s:node_line(s:lines, 'hjkl_broad') =~# '·needs recognize_current_mode',
  \ 'render_hierarchy: hjkl_broad shows ·needs recognize_current_mode')

" Inline structural annotations.
call Assert(s:node_line(s:lines, 'hl') =~# 'narrower of hjkl_broad',
  \ 'render_hierarchy: hl shows narrower of hjkl_broad')
call Assert(s:node_line(s:lines, 'wb') =~# '⟷ ege',
  \ 'render_hierarchy: wb shows ⟷ ege')

" Nesting: a child is indented deeper than its parent.
call Assert(s:indent_of(s:lines, 'hjkl_broad') > s:indent_of(s:lines, 'insert_basic'),
  \ 'render_hierarchy: hjkl_broad indented under insert_basic')
call Assert(s:indent_of(s:lines, 'wb') > s:indent_of(s:lines, 'hjkl_broad'),
  \ 'render_hierarchy: wb indented under hjkl_broad')

" Parent appears before child in the rendered order.
function! s:index_of(lines, pattern) abort
  for i in range(len(a:lines))
    if a:lines[i] =~# a:pattern | return i | endif
  endfor
  return -1
endfunction

call Assert(s:index_of(s:lines, '●─ insert_basic\>')
  \ < s:index_of(s:lines, '─ hjkl_broad\>'),
  \ 'render_hierarchy: insert_basic root precedes hjkl_broad')
call Assert(s:index_of(s:lines, '─ hjkl_broad\>')
  \ < s:index_of(s:lines, '─ wb\>'),
  \ 'render_hierarchy: hjkl_broad precedes its child wb')
