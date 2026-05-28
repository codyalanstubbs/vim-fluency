" Tests for the :VfList navigator. Exercises status classification,
" prereq resolution (specific-slug only — no more group/tier prefix
" matching), and a render smoke test.

" -- s:status_from_sessions --

function! s:sess(date, rate) abort
  return {'timestamp': a:date . 'T12:00:00', 'frequency_per_min': a:rate}
endfunction

let s:meta_aim50 = {'aim': 50}

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50, []),
  \ 'not_started', 'status: empty sessions → not_started')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50,
  \   [s:sess('2026-01-01', 0.0)]),
  \ 'not_started', 'status: only zero-rate sessions → not_started')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50,
  \   [s:sess('2026-01-01', 60.0)]),
  \ 'climbing', 'status: 1 session at aim → still climbing (need 3)')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50,
  \   [s:sess('2026-01-01', 60.0), s:sess('2026-01-02', 60.0)]),
  \ 'climbing', 'status: 2 at-aim sessions → still climbing (need 3)')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50, [
  \   s:sess('2026-01-01', 60.0),
  \   s:sess('2026-01-02', 55.0),
  \   s:sess('2026-01-03', 70.0)]),
  \ 'at_aim', 'status: 3 consecutive at-aim → at_aim')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50, [
  \   s:sess('2026-01-01', 60.0),
  \   s:sess('2026-01-02', 40.0),
  \   s:sess('2026-01-03', 70.0)]),
  \ 'climbing', 'status: regression in last 3 → climbing')

" Zero-rate quit in the middle is filtered out before counting last 3.
call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50, [
  \   s:sess('2026-01-01', 60.0),
  \   s:sess('2026-01-02', 0.0),
  \   s:sess('2026-01-03', 55.0),
  \   s:sess('2026-01-04', 70.0)]),
  \ 'at_aim', 'status: zero-rate quits filtered before the 3-streak check')

" -- s:unmet_prereqs --
"
" Under the slug-based ID scheme each prereq references a specific
" pinpoint by slug. If the prereq isn't in the registry, it counts
" as satisfied (you can't be blocked by an unbuilt pinpoint).

let s:registry = {
  \ 'hjkl':           {'id': 'hjkl',           'name': 'hjkl',         'aim': 60, 'prereqs': []},
  \ 'line_edges':     {'id': 'line_edges',     'name': 'line edges',   'aim': 50, 'prereqs': []},
  \ 'word_motions':   {'id': 'word_motions',   'name': 'w b',          'aim': 45, 'prereqs': ['hjkl']},
  \ 'find_char':      {'id': 'find_char',      'name': 'f F',          'aim': 50, 'prereqs': ['hjkl']},
  \ 'till_char':      {'id': 'till_char',      'name': 't T',          'aim': 45, 'prereqs': ['find_char']},
  \ }

" Case A: hjkl not at aim → word_motions is blocked.
let s:status = {'hjkl': 'climbing', 'line_edges': 'climbing',
  \ 'word_motions': 'climbing', 'find_char': 'climbing', 'till_char': 'climbing'}
let s:u = vimfluency#_test_unmet_prereqs(s:registry['word_motions'], s:registry, s:status)
call AssertEq(s:u, ['hjkl'], 'unmet_prereqs: word_motions blocked when hjkl not at aim')

" Case B: hjkl at aim → word_motions is eligible.
let s:status_b = {'hjkl': 'at_aim', 'line_edges': 'at_aim',
  \ 'word_motions': 'climbing', 'find_char': 'climbing', 'till_char': 'climbing'}
let s:u_b = vimfluency#_test_unmet_prereqs(s:registry['word_motions'], s:registry, s:status_b)
call AssertEq(s:u_b, [], 'unmet_prereqs: word_motions eligible when hjkl at aim')

" Case C: till_char needs find_char (specific slug prereq).
let s:u_c = vimfluency#_test_unmet_prereqs(s:registry['till_char'], s:registry, s:status_b)
call AssertEq(s:u_c, ['find_char'],
  \ 'unmet_prereqs: till_char blocked when find_char not at aim')

" Case D: prereq names a pinpoint not yet in the registry — satisfied vacuously.
let s:vacuous = {'id': 'novel', 'name': 'novel', 'aim': 30, 'prereqs': ['not_yet_built']}
let s:u_d = vimfluency#_test_unmet_prereqs(s:vacuous, s:registry, s:status)
call AssertEq(s:u_d, [],
  \ 'unmet_prereqs: prereq satisfied vacuously when pinpoint not in registry')

" -- s:per_motion_from_sessions --

let s:pm_empty = vimfluency#_test_per_motion_from_sessions([])
call AssertEq(s:pm_empty, {}, 'per_motion: empty sessions → {}')

let s:sess_with_pm = [{
  \ 'timestamp': '2026-01-01T12:00:00',
  \ 'frequency_per_min': 30.0,
  \ 'per_motion': {'w': {'rate_per_min': 40.0}, 'b': {'rate_per_min': 20.0}}
  \ }]
let s:pm = vimfluency#_test_per_motion_from_sessions(s:sess_with_pm)
call AssertEq(s:pm, {'w': 40.0, 'b': 20.0},
  \ 'per_motion: flattens to {motion → rate_per_min}')

" Picks the most recent non-zero session, not just the last in the list.
let s:sess_multi = [
  \ {'timestamp': '2026-01-03T12:00:00', 'frequency_per_min': 50.0,
  \  'per_motion': {'w': {'rate_per_min': 50.0}}},
  \ {'timestamp': '2026-01-02T12:00:00', 'frequency_per_min': 30.0,
  \  'per_motion': {'w': {'rate_per_min': 30.0}}},
  \ {'timestamp': '2026-01-04T12:00:00', 'frequency_per_min': 0.0,
  \  'per_motion': {}},
  \ ]
let s:pm_recent = vimfluency#_test_per_motion_from_sessions(s:sess_multi)
call AssertEq(s:pm_recent, {'w': 50.0},
  \ 'per_motion: most recent non-zero session wins, zero-rate skipped')

" -- render_list smoke test --
"
" Family grouping: each pinpoint's `family` field determines the
" section it appears in; family-less pinpoints fall into the 'other'
" bucket.

function! s:sess_pm(date, rate, pm) abort
  return {'timestamp': a:date . 'T12:00:00',
    \ 'frequency_per_min': a:rate, 'per_motion': a:pm}
endfunction

let s:render_reg = {
  \ 'hjkl':         {'id': 'hjkl',         'name': 'hjkl',       'aim': 60, 'prereqs': [],
  \                  'family': 'motion'},
  \ 'line_edges':   {'id': 'line_edges',   'name': 'line edges', 'aim': 50, 'prereqs': [],
  \                  'family': 'motion'},
  \ 'word_motions': {'id': 'word_motions', 'name': 'w b',        'aim': 45, 'prereqs': ['line_edges'],
  \                  'family': 'motion'},
  \ }
let s:sessions_by_id = {
  \ 'hjkl': [
  \   s:sess_pm('2026-01-01', 70.0, {'h': {'rate_per_min': 80.0}, 'l': {'rate_per_min': 60.0}}),
  \   s:sess_pm('2026-01-02', 70.0, {'h': {'rate_per_min': 80.0}, 'l': {'rate_per_min': 60.0}}),
  \   s:sess_pm('2026-01-03', 70.0, {'h': {'rate_per_min': 80.0}, 'l': {'rate_per_min': 60.0}}),
  \   ],
  \ 'line_edges': [s:sess('2026-01-03', 30.0)],
  \ }
let s:render_reg.hjkl.keys = 'h/l'
let s:view = vimfluency#_test_build_list_view(s:render_reg, s:sessions_by_id)
let s:rendered = join(s:view.lines, "\n")
" Header is a clean section marker (no doubled "family", no redundant
" slug tail). Regression guard for review bug #1.
call Assert(s:rendered =~# '── Motions ──',
  \ 'render_list: family header rendered as clean section marker')
call Assert(s:rendered !~# 'family family',
  \ 'render_list: no doubled "family" in section headers')
call Assert(s:rendered !~# 'family — motion',
  \ 'render_list: no redundant "— <slug>" tail in section headers')
" New row format: keystrokes in parens, labelled aim_rate:/last_rate:.
" Numbers are right-aligned on 3 cols (%3d), so allow >=1 space.
call Assert(s:rendered =~# 'hjkl (h/l)',
  \ 'render_list: keystrokes shown in parens after slug')
call Assert(s:rendered =~# 'aim_rate: \+60/min',
  \ 'render_list: aim shown with aim_rate: N/min label, right-aligned')
call Assert(s:rendered =~# 'last_rate: \+70/min',
  \ 'render_list: current rate shown with last_rate: N/min label')
" Per-motion breakdown is NOT auto-shown (toggled by B).
call Assert(s:rendered !~# 'h:.*80/min',
  \ 'render_list: per-motion breakdown NOT shown by default')
call Assert(s:rendered =~# '✓ at aim',
  \ 'render_list: at-aim status icon present for hjkl')
call Assert(s:rendered =~# '○ not started',
  \ 'render_list: not-started icon present for pinpoints with no sessions')
call Assert(s:rendered =~# 'prereq(s): \w',
  \ 'render_list: unmet-prereqs annotation present')
call Assert(s:rendered =~# "Today's set",
  \ 'render_list: today-summary footer present')

" Column alignment: every main pinpoint row puts "last_rate:" at the
" same byte offset (the label column is ASCII and padded to a fixed
" width, so byte offset == display column here). Guards the user's
" "columns must line up for quick scanning" requirement.
let s:rr_cols = {}
for s:l in s:view.lines
  if s:l =~# '^    \S' && s:l =~# 'last_rate:'
    let s:rr_cols[stridx(s:l, 'last_rate:')] = 1
  endif
endfor
call AssertEq(len(s:rr_cols), 1,
  \ 'render_list: last_rate: column aligned across all pinpoint rows')

" Foundational-first ordering within a family: word_motions (depth 1,
" prereq line_edges) renders after the depth-0 motions it builds on.
function! s:nav_line_idx(lines, pat) abort
  for i in range(len(a:lines))
    if a:lines[i] =~# a:pat | return i | endif
  endfor
  return -1
endfunction
call Assert(s:nav_line_idx(s:view.lines, '^    line_edges\>')
  \ < s:nav_line_idx(s:view.lines, '^    word_motions\>'),
  \ 'render_list: deeper-prereq pinpoint sorts after its prereq within family')

" -- expanded breakdown (B toggle) --
"
" With hjkl expanded, its per-motion breakdown rows appear: one
" indented row per motion, with the rate and a ✓ when at-or-above aim.
let s:eview = vimfluency#_test_build_list_view(s:render_reg, s:sessions_by_id, {'hjkl': 1})
let s:erendered = join(s:eview.lines, "\n")
call Assert(s:erendered =~# 'h:.*80/min',
  \ 'render_list expanded: h motion rate shown in breakdown')
call Assert(s:erendered =~# 'l:.*60/min',
  \ 'render_list expanded: l motion rate shown in breakdown')
call Assert(s:erendered =~# '├─\|└─',
  \ 'render_list expanded: breakdown uses tree connectors')

" -- coordinate map (interactive :VfList) --
"
" The view emits its own line→id map (no re-parsing of formatted
" text). Each pinpoint row maps to its id; family headers, blank
" lines, and the footer have no mapping entries. The separate
" `pinpoint_rows` list — used by j/k navigation — contains only MAIN
" rows, sorted ascending.

let s:lines_for_map = s:view.lines
let s:line_map = s:view.mapping
let s:pp_rows = s:view.pinpoint_rows

" Every registry id appears in the map at least once.
let s:ids_in_map = {}
for s:lnum in keys(s:line_map)
  let s:ids_in_map[s:line_map[s:lnum]] = 1
endfor
for s:id in keys(s:render_reg)
  call Assert(get(s:ids_in_map, s:id, 0) == 1,
    \ 'line_map: registry id ' . s:id . ' appears in the map')
endfor

" Find hjkl's line and confirm it maps to 'hjkl'.
let s:row_hjkl = -1
for s:i in range(len(s:lines_for_map))
  if s:lines_for_map[s:i] =~# '^    hjkl\>'
    let s:row_hjkl = s:i + 1
    break
  endif
endfor
call Assert(s:row_hjkl > 0, 'line_map: hjkl pinpoint row found')
call AssertEq(get(s:line_map, s:row_hjkl, ''), 'hjkl',
  \ 'line_map: hjkl row maps to "hjkl"')

" pinpoint_rows: one entry per registry pinpoint, sorted ascending.
" Default (collapsed) view has no breakdown rows.
call AssertEq(len(s:pp_rows), len(s:render_reg),
  \ 'pinpoint_rows: one entry per registry pinpoint')
let s:sorted = sort(copy(s:pp_rows), 'N')
call AssertEq(s:pp_rows, s:sorted,
  \ 'pinpoint_rows: sorted ascending')

" In the EXPANDED view, breakdown rows map to the parent id but are
" NOT in pinpoint_rows (j/k skips them).
let s:erow_hjkl = -1
for s:i in range(len(s:eview.lines))
  if s:eview.lines[s:i] =~# '^    hjkl\>'
    let s:erow_hjkl = s:i + 1
    break
  endif
endfor
call AssertEq(get(s:eview.mapping, s:erow_hjkl + 1, ''), 'hjkl',
  \ 'expanded: breakdown row inherits parent pinpoint id')
call Assert(index(s:eview.pinpoint_rows, s:erow_hjkl + 1) == -1,
  \ 'expanded: breakdown row excluded from pinpoint_rows')
call Assert(index(s:eview.pinpoint_rows, s:erow_hjkl) >= 0,
  \ 'expanded: hjkl main row still in pinpoint_rows')

" Banner rows present, and don't carry mapping entries.
let s:has_banner = 0
for s:l in s:lines_for_map
  if s:l =~# '(L)earn.*(T)rain.*(C)hart.*(B)reakdown'
    let s:has_banner = 1
    break
  endif
endfor
call Assert(s:has_banner, 'render_list: help banner present with B')

" -- list_action pre-flight guards (bug #2) --
"
" list_action closes the list tab before dispatching, so Chart on a
" pinpoint with no sessions and Learn on a pinpoint with no lesson
" must be caught BEFORE the close. These helpers back those guards.
" (Real pinpoints are on the runtimepath; the session log points at a
" per-invocation temp dir that starts empty.)

call AssertEq(vimfluency#_test_pinpoint_has_lesson('save_vs_quit'), 1,
  \ 'has_lesson: a shipped pinpoint with a lesson() reports true')
call AssertEq(vimfluency#_test_pinpoint_has_lesson('no_such_pinpoint'), 0,
  \ 'has_lesson: an unknown id reports false')

call AssertEq(vimfluency#_test_pinpoint_has_sessions('no_such_pinpoint'), 0,
  \ 'has_sessions: a pinpoint with no logged sessions reports false')
