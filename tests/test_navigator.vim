" Tests for the :VfList navigator. Exercises status classification,
" prereq resolution (specific-slug only — no more group/tier prefix
" matching), and a render smoke test.

" -- s:status_from_sessions --

function! s:sess(date, rate) abort
  return {'timestamp': a:date . 'T12:00:00', 'frequency_per_min': a:rate}
endfunction

let s:meta_aim50 = {'aim': 50}

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50.aim, []),
  \ 'not_started', 'status: empty sessions → not_started')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50.aim,
  \   [s:sess('2026-01-01', 0.0)]),
  \ 'not_started', 'status: only zero-rate sessions → not_started')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50.aim,
  \   [s:sess('2026-01-01', 60.0)]),
  \ 'climbing', 'status: 1 session at aim → still climbing (need 3)')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50.aim,
  \   [s:sess('2026-01-01', 60.0), s:sess('2026-01-02', 60.0)]),
  \ 'climbing', 'status: 2 at-aim sessions → still climbing (need 3)')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50.aim, [
  \   s:sess('2026-01-01', 60.0),
  \   s:sess('2026-01-02', 55.0),
  \   s:sess('2026-01-03', 70.0)]),
  \ 'at_aim', 'status: 3 consecutive at-aim → at_aim')

call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50.aim, [
  \   s:sess('2026-01-01', 60.0),
  \   s:sess('2026-01-02', 40.0),
  \   s:sess('2026-01-03', 70.0)]),
  \ 'climbing', 'status: regression in last 3 → climbing')

" Zero-rate quit in the middle is filtered out before counting last 3.
call AssertEq(
  \ vimfluency#_test_status_from_sessions(s:meta_aim50.aim, [
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

" Family is now a column value, not a '── Motions ──' section divider.
call Assert(s:rendered !~# '── Motions ──',
  \ 'render_list: families render as a column, not as section dividers')

" Banner carries a status-icon legend (the column itself is gone).
call Assert(s:rendered =~# 'Status:.*✓ at aim.*▶ climbing.*○ not started',
  \ 'render_list: status legend present in banner')

" Header row lists every column in order. No 'status' word column —
" the ▶/✓/○ bullet at the start of each row carries that meaning.
" Family is the LAST column.
call Assert(s:rendered =~# 'drill\s\+commands\s\+prereqs_n\s\+aim'
  \ . '\s\+last_rate\s\+last_session\s\+runs\s\+family',
  \ 'render_list: header row lists columns in order, family last')
call Assert(s:rendered !~# '\<status\s\+aim\>',
  \ 'render_list: no status word column between behavior and aim')

" Row format: bullet, then left-aligned behavior + commands, then the
" right-aligned numeric columns (prereq_depth, aim, previous_rate,
" previous_session, sessions_count), then left-aligned family last.
" hjkl is at aim (3 sessions at 70 ≥ aim 60, so 3 sessions logged) → ✓.
call Assert(s:rendered =~# ' ✓ hjkl\s\+h l\s\+0\s\+60/min\s\+70/min'
  \ . '\s\+2026-01-03\s\+3\s\+motion',
  \ 'render_list: row = bullet behavior commands prereq_depth aim'
  \ . ' previous_rate previous_session sessions_count family')

" The status word never appears on any data row (only in the legend).
" line_edges is climbing, but its row carries only the ▶ icon, not the
" word.
let s:le_row = ''
for s:l in s:view.lines
  if s:l =~# '^ [▶✓○] line_edges\>' | let s:le_row = s:l | break | endif
endfor
call Assert(s:le_row =~# '^ ▶ line_edges',
  \ 'render_list: climbing pinpoint leads with the ▶ bullet')
call Assert(s:le_row !~# '\<climbing\>',
  \ 'render_list: status word does not appear inline on data rows')

" Per-motion breakdown is NOT auto-shown (toggled by B).
call Assert(s:rendered !~# '\<h\>\s\+80/min',
  \ 'render_list: per-motion breakdown NOT shown by default')

" word_motions's prereq (line_edges) is NOT inline on its row — it
" only surfaces under the B breakdown for word_motions (asserted below).
let s:wm_row = ''
for s:l in s:view.lines
  if s:l =~# '^ [▶✓○] word_motions\>' | let s:wm_row = s:l | break | endif
endfor
call Assert(s:wm_row !~# 'line_edges',
  \ 'render_list: word_motions main row does not list its prereq')
call Assert(s:rendered =~# "Today's set",
  \ 'render_list: today-summary footer present')

" Column alignment: every data row puts the aim_rate "/min" at the same
" byte offset. Rows begin with ' ▶/✓/○ behavior'; the bullet is the
" only multibyte character before the rate columns, and it's always 3
" bytes, so byte offset tracks display column here. Guards the user's
" "columns must line up for quick scanning" requirement.
let s:aim_cols = {}
for s:l in s:view.lines
  if s:l =~# '^ [▶✓○] ' && s:l =~# '/min'
    let s:aim_cols[stridx(s:l, '/min')] = 1
  endif
endfor
call AssertEq(len(s:aim_cols), 1,
  \ 'render_list: aim_rate column aligned across all pinpoint rows')

" Foundational-first ordering within a family: word_motions (depth 1,
" prereq line_edges) renders after the depth-0 motions it builds on.
function! s:nav_line_idx(lines, pat) abort
  for i in range(len(a:lines))
    if a:lines[i] =~# a:pat | return i | endif
  endfor
  return -1
endfunction
call Assert(s:nav_line_idx(s:view.lines, '^ [▶✓○] line_edges\>')
  \ < s:nav_line_idx(s:view.lines, '^ [▶✓○] word_motions\>'),
  \ 'render_list: deeper-prereq pinpoint sorts after its prereq within family')

" -- expanded breakdown (B toggle) --
"
" hjkl has no prereqs but has per-motion data — expansion shows ONLY
" the commands sub-table (no prereqs sub-block) and closes with └.
let s:eview = vimfluency#_test_build_list_view(s:render_reg, s:sessions_by_id, {'hjkl': 1})
let s:erendered = join(s:eview.lines, "\n")
call Assert(s:erendered =~# '└ commands:',
  \ 'render_list expanded: commands sub-block (└ since it is the last/only one)')
call Assert(s:erendered =~# 'command\s\+last_rate\s\+stroke_count\s\+stroke_rate',
  \ 'render_list expanded: per-command sub-table header')
" Per-command rows: name, last_rate, stroke_count (1 for h/l), stroke_rate
" (== last_rate since single-stroke commands). Both commands are at aim
" (80 ≥ 60, 60 ≥ 60) so both get the ✓ at-aim mark.
call Assert(s:erendered =~# '✓ h\s\+80/min\s\+1\s\+80/min',
  \ 'render_list expanded: h command row with stroke_count + stroke_rate')
call Assert(s:erendered =~# '✓ l\s\+60/min\s\+1\s\+60/min',
  \ 'render_list expanded: l command row with stroke_count + stroke_rate')
call Assert(s:erendered !~# '├ prereqs:\|└ prereqs:',
  \ 'render_list expanded: no prereqs sub-block when pinpoint has no prereqs')

" word_motions has line_edges as a prereq AND no session data. Expansion
" shows ONLY the prereqs sub-block (no commands), closed with └. Prereq
" entries are minimal: bullet + name, no status word.
let s:wview = vimfluency#_test_build_list_view(s:render_reg, s:sessions_by_id, {'word_motions': 1})
let s:wrendered = join(s:wview.lines, "\n")
call Assert(s:wrendered =~# '└ prereqs:',
  \ 'render_list expanded: prereqs is the last sub-block (└)')
call Assert(s:wrendered =~# '▶ line_edges',
  \ 'render_list expanded: prereq listed with status icon + name only')
call Assert(s:wrendered !~# '\<climbing\>\s\+line_edges',
  \ 'render_list expanded: prereq has no status word, only the icon')
call Assert(s:wrendered !~# '└ commands:\|├ commands:',
  \ 'render_list expanded: no commands sub-block when there is no session data')

" -- column sort --
"
" Fixture for sort tests: 4 pinpoints with different aims so order is
" observable. Two share the same aim to verify tiebreaker stability.
let s:sort_reg = {
  \ 'foundation_a': {'id': 'foundation_a', 'name': 'a', 'aim': 60,
  \                  'prereqs': [], 'family': 'survival'},
  \ 'foundation_b': {'id': 'foundation_b', 'name': 'b', 'aim': 60,
  \                  'prereqs': [], 'family': 'motion'},
  \ 'mid':          {'id': 'mid', 'name': 'mid', 'aim': 80,
  \                  'prereqs': ['foundation_a'], 'family': 'motion'},
  \ 'top':          {'id': 'top', 'name': 'top', 'aim': 40,
  \                  'prereqs': ['mid'], 'family': 'delete'},
  \ }
let s:sort_sess = {}

" Helper: list of pinpoint slugs in the rendered order.
function! s:nav_pinpoint_order(view) abort
  let out = []
  for row in a:view.pinpoint_rows
    call add(out, a:view.mapping[row])
  endfor
  return out
endfunction

" Default sort: family curated order (survival, motion, delete) then
" depth then alpha. No ▲/▼ marker.
let s:dview = vimfluency#_test_build_list_view(s:sort_reg, s:sort_sess)
call AssertEq(s:nav_pinpoint_order(s:dview),
  \ ['foundation_a', 'foundation_b', 'mid', 'top'],
  \ 'sort default: family → depth → slug')
call Assert(join(s:dview.lines, "\n") !~# '[▲▼]',
  \ 'sort default: no ▲/▼ marker in header')

" Sort by aim ascending: 40, 60, 60, 80 — ties broken by family/depth/slug.
let s:av = vimfluency#_test_build_list_view(s:sort_reg, s:sort_sess, {}, 'aim', 0)
call AssertEq(s:nav_pinpoint_order(s:av),
  \ ['top', 'foundation_a', 'foundation_b', 'mid'],
  \ 'sort aim asc: 40 → 60 (tie: family then slug) → 80')
call Assert(join(s:av.lines, "\n") =~# 'aim \+▲',
  \ 'sort aim asc: ▲ marker in the gutter after aim header')

" Sort by aim descending: 80, 60, 60, 40 — tiebreaker stays asc so
" two-60s order doesn't flip from the asc case.
let s:dv = vimfluency#_test_build_list_view(s:sort_reg, s:sort_sess, {}, 'aim', 1)
call AssertEq(s:nav_pinpoint_order(s:dv),
  \ ['mid', 'foundation_a', 'foundation_b', 'top'],
  \ 'sort aim desc: 80 → 60s (tiebreaker stays asc) → 40')
call Assert(join(s:dv.lines, "\n") =~# 'aim \+▼',
  \ 'sort aim desc: ▼ marker in the gutter after aim header')

" Cursor preservation contract (under-test via row-index math):
" two views with the same fixture but different sort orders share the
" same pinpoint_rows LENGTH (one main row per pinpoint, no breakdowns
" here). So the cursor's Nth-row index translates cleanly between
" sorts, and the slug at row N is expected to change.
call AssertEq(len(s:av.pinpoint_rows), len(s:dv.pinpoint_rows),
  \ 'sort: pinpoint_rows length is invariant across sorts')
call Assert(s:av.mapping[s:av.pinpoint_rows[0]]
  \ !=# s:dv.mapping[s:dv.pinpoint_rows[0]],
  \ 'sort: row 0 carries a different pinpoint across asc/desc')

" Sort by prereqs_n asc: 0, 0, 1, 2.
let s:depth_v = vimfluency#_test_build_list_view(s:sort_reg, s:sort_sess, {}, 'prereqs_n', 0)
call AssertEq(s:nav_pinpoint_order(s:depth_v),
  \ ['foundation_a', 'foundation_b', 'mid', 'top'],
  \ 'sort prereqs_n asc: 0s first, then 1, then 2')

" Reset (col=''): same order as default, no marker.
let s:rv = vimfluency#_test_build_list_view(s:sort_reg, s:sort_sess, {}, '', 0)
call AssertEq(s:nav_pinpoint_order(s:rv), s:nav_pinpoint_order(s:dview),
  \ 'sort reset: empty col reproduces the default order')
call Assert(join(s:rv.lines, "\n") !~# '[▲▼]',
  \ 'sort reset: no marker in header')

" -- sessions_count excludes zero-rate quits --
"
" A pinpoint with 2 usable sessions plus a 0-rate quit shows
" sessions_count = 2, not 3. Keeps the column consistent with
" previous_rate / previous_session, which both read from the most
" recent NON-ZERO session.
let s:zq_reg = {
  \ 'zq': {'id': 'zq', 'name': 'zq', 'aim': 50,
  \        'prereqs': [], 'family': 'motion'},
  \ }
let s:zq_sess = {
  \ 'zq': [
  \   s:sess('2026-01-01', 40.0),
  \   s:sess('2026-01-02', 45.0),
  \   s:sess('2026-01-03', 0.0),
  \ ],
  \ }
let s:zqview = vimfluency#_test_build_list_view(s:zq_reg, s:zq_sess)
let s:zq_row = ''
for s:l in s:zqview.lines
  if s:l =~# '^ [▶✓○] zq\>' | let s:zq_row = s:l | break | endif
endfor
" Row carries previous_rate 45/min (most recent non-zero), date
" 2026-01-02 (same session), and sessions_count 2 — NOT 3.
call Assert(s:zq_row =~# '\s\+45/min\s\+2026-01-02\s\+2\s\+motion',
  \ 'sessions_count: zero-rate quits not counted')

" -- stroke_counts override --
"
" A pinpoint can declare per-command stroke counts in meta() to
" override the derived count. The breakdown uses the declared value
" verbatim, and stroke_rate = last_rate / declared_count.
let s:override_reg = {
  \ 'leader_cmd': {'id': 'leader_cmd', 'name': 'leader', 'aim': 30,
  \                'prereqs': [], 'family': 'motion',
  \                'stroke_counts': {'leader_w': 7}},
  \ }
let s:override_sess = {
  \ 'leader_cmd': [s:sess_pm('2026-01-01', 14.0, {'leader_w': {'rate_per_min': 14.0}})],
  \ }
let s:oview = vimfluency#_test_build_list_view(s:override_reg, s:override_sess, {'leader_cmd': 1})
let s:orendered = join(s:oview.lines, "\n")
call Assert(s:orendered =~# 'leader_w\s\+14/min\s\+7\s\+2/min',
  \ 'stroke_counts override: declared count drives stroke_rate (14/7 = 2)')

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
  if s:lines_for_map[s:i] =~# '^ [▶✓○] hjkl\>'
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
  if s:eview.lines[s:i] =~# '^ [▶✓○] hjkl\>'
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
