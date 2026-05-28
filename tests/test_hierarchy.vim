" Tests for :VfHierarchy. It reuses the :VfList rendering engine but
" partitions rows by prereq signature (topologically ordered) instead
" of by family. Build a tiny fixture registry + sessions and check the
" section headers, their order, the shared VfList row format, and that
" the B-toggle breakdown still works.

let s:reg = {
  \ 'insert_basic': {'id': 'insert_basic', 'name': 'enter / leave insert',
  \                  'aim': 50, 'allowed_keys': 'iaEsc', 'keys': 'i/a/Esc',
  \                  'family': 'survival', 'prereqs': []},
  \ 'open_line_above_below': {'id': 'open_line_above_below', 'name': 'open new line',
  \                          'aim': 40, 'keys': 'o/O',
  \                          'family': 'survival', 'prereqs': ['insert_basic']},
  \ 'recognize_current_mode': {'id': 'recognize_current_mode', 'name': 'mode awareness',
  \                            'aim': 120, 'family': 'survival', 'prereqs': []},
  \ 'hjkl_broad': {'id': 'hjkl_broad', 'name': 'hjkl', 'aim': 60, 'keys': 'h/j/k/l',
  \                'family': 'motion',
  \                'prereqs': ['recognize_current_mode', 'insert_basic']},
  \ 'hl': {'id': 'hl', 'name': 'h l', 'aim': 60, 'keys': 'h/l', 'family': 'motion',
  \        'prereqs': ['recognize_current_mode', 'insert_basic']},
  \ 'jk': {'id': 'jk', 'name': 'j k', 'aim': 60, 'keys': 'j/k', 'family': 'motion',
  \        'prereqs': ['recognize_current_mode', 'insert_basic']},
  \ 'wb': {'id': 'wb', 'name': 'w b', 'aim': 45, 'keys': 'w/b', 'family': 'motion',
  \        'prereqs': ['hjkl_broad']},
  \ 'ege': {'id': 'ege', 'name': 'e ge', 'aim': 40, 'keys': 'e/ge', 'family': 'motion',
  \         'prereqs': ['hjkl_broad']},
  \ }

" One session for hl, with a per-motion breakdown for the B toggle.
let s:sessions = {
  \ 'hl': [{'timestamp': '2026-05-01T10:00:00', 'frequency_per_min': 55,
  \         'per_motion': {'h': {'rate_per_min': 60}, 'l': {'rate_per_min': 50}}}],
  \ }

let s:view = vimfluency#_test_build_hierarchy_view(s:reg, s:sessions)
let s:lines = s:view.lines
let s:text = join(s:lines, "\n")

" View dict shape matches what the navigator expects.
call Assert(has_key(s:view, 'lines') && has_key(s:view, 'mapping')
  \ && has_key(s:view, 'pinpoint_rows'),
  \ 'hierarchy view: returns lines/mapping/pinpoint_rows')

call Assert(s:text =~# 'vim-fluency hierarchy',
  \ 'hierarchy: banner present')

" Section headers: roots, then each prereq signature.
call Assert(s:text =~# '── no prereqs (roots) ──',
  \ 'hierarchy: roots section header')
call Assert(s:text =~# '── needs insert_basic ──',
  \ 'hierarchy: insert_basic-only section header')
call Assert(s:text =~# '── needs insert_basic, recognize_current_mode ──',
  \ 'hierarchy: combined-prereq section header')
call Assert(s:text =~# '── needs hjkl_broad ──',
  \ 'hierarchy: hjkl_broad section header')

" Topological order: roots first, hjkl_broad section last (its prereq
" is satisfied by an earlier section).
function! s:index_of(lines, pattern) abort
  for i in range(len(a:lines))
    if a:lines[i] =~# a:pattern | return i | endif
  endfor
  return -1
endfunction

call Assert(s:index_of(s:lines, '── no prereqs (roots) ──')
  \ < s:index_of(s:lines, '── needs insert_basic ──'),
  \ 'hierarchy: roots precede needs-insert_basic')
call Assert(s:index_of(s:lines, '── needs insert_basic, recognize_current_mode ──')
  \ < s:index_of(s:lines, '── needs hjkl_broad ──'),
  \ 'hierarchy: combined-prereq section precedes its dependents')

" Shared VfList row format: keys in parens, aligned aim/recent_rate.
call Assert(s:text =~# 'insert_basic (i/a/Esc)\s\+aim:\s\+50/min  recent_rate:',
  \ 'hierarchy: rows use the VfList format (keys, aim, recent_rate)')

" recent_rate reflects the logged session for hl.
call Assert(match(s:lines, 'hl (h/l)\s\+aim:\s\+60/min  recent_rate:\s\+55/min') >= 0,
  \ 'hierarchy: hl recent_rate shows the session rate')

" Every pinpoint is a main row exactly once.
call AssertEq(len(s:view.pinpoint_rows), len(keys(s:reg)),
  \ 'hierarchy: one main row per pinpoint')
for s:row in s:view.pinpoint_rows
  call Assert(has_key(s:view.mapping, s:row),
    \ 'hierarchy: pinpoint row ' . s:row . ' is in the id map')
endfor

" B-toggle breakdown: expanding hl adds its per-motion sub-rows.
let s:eview = vimfluency#_test_build_hierarchy_view(s:reg, s:sessions, {'hl': 1})
let s:etext = join(s:eview.lines, "\n")
call Assert(len(s:eview.lines) > len(s:view.lines),
  \ 'hierarchy: expanding hl adds breakdown rows')
call Assert(s:etext =~# 'h:\s\+60/min' && s:etext =~# 'l:\s\+50/min',
  \ 'hierarchy: hl breakdown shows per-motion rates')
