" Tests for the :VfList navigator. Exercises ID parsing, status
" classification, prereq resolution (specific ID and group prefix
" forms), and a render smoke test.

" -- s:parse_id --

let s:p1A = vimfluency#_test_parse_id('1A.1')
call AssertEq(s:p1A.tier, 1, 'parse_id 1A.1: tier')
call AssertEq(s:p1A.group, '1A', 'parse_id 1A.1: group')
call AssertEq(s:p1A.seq, '1', 'parse_id 1A.1: seq')

let s:p4d = vimfluency#_test_parse_id('4.d')
call AssertEq(s:p4d.tier, 4, 'parse_id 4.d: tier')
call AssertEq(s:p4d.group, '4', 'parse_id 4.d: group (no sub-letter)')
call AssertEq(s:p4d.seq, 'd', 'parse_id 4.d: seq')

let s:pT0 = vimfluency#_test_parse_id('T0.1')
call AssertEq(s:pT0.tier, 0, 'parse_id T0.1: tier=0')
call AssertEq(s:pT0.group, 'T0', 'parse_id T0.1: group=T0')

let s:pC = vimfluency#_test_parse_id('C.1')
call AssertEq(s:pC.tier, 13, 'parse_id C.1: tier=13 (composites)')
call AssertEq(s:pC.group, 'C', 'parse_id C.1: group=C')

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

" Mock registry with two pinpoints: a foundation that's at aim and a
" follow-up that's still climbing. A third pinpoint depends on the
" group prefix containing both.
let s:registry = {
  \ '1A.1': {'id': '1A.1', 'name': 'hjkl',           'aim': 60, 'prereqs': ['T0']},
  \ '1A.2': {'id': '1A.2', 'name': 'line start/end', 'aim': 50, 'prereqs': ['T0']},
  \ '1B.1': {'id': '1B.1', 'name': 'word motions',   'aim': 45, 'prereqs': ['1A']},
  \ '1C.1': {'id': '1C.1', 'name': 'find char',      'aim': 50, 'prereqs': ['1A']},
  \ '1C.2': {'id': '1C.2', 'name': 'till char',      'aim': 45, 'prereqs': ['1C.1']},
  \ }

" Case A: 1A.1 at aim, 1A.2 climbing → '1A' group prereq is unmet.
let s:status = {'1A.1': 'at_aim', '1A.2': 'climbing',
  \ '1B.1': 'climbing', '1C.1': 'climbing', '1C.2': 'climbing'}
let s:u = vimfluency#_test_unmet_prereqs(s:registry['1B.1'], s:registry, s:status)
call AssertEq(s:u, ['1A'], 'unmet_prereqs: 1B.1 blocked because 1A.2 not at aim')

" Case B: both 1A pinpoints at aim → 1B.1 is now eligible.
let s:status_b = {'1A.1': 'at_aim', '1A.2': 'at_aim',
  \ '1B.1': 'climbing', '1C.1': 'climbing', '1C.2': 'climbing'}
let s:u_b = vimfluency#_test_unmet_prereqs(s:registry['1B.1'], s:registry, s:status_b)
call AssertEq(s:u_b, [], 'unmet_prereqs: 1B.1 eligible when whole 1A group is at aim')

" Case C: specific-ID prereq (1C.2 needs 1C.1).
let s:u_c = vimfluency#_test_unmet_prereqs(s:registry['1C.2'], s:registry, s:status_b)
call AssertEq(s:u_c, ['1C.1'],
  \ 'unmet_prereqs: 1C.2 blocked when 1C.1 not at aim (specific-id prereq)')

" Case D: T0 prereq on 1A.1 — nothing built in T0, so it's satisfied.
let s:u_d = vimfluency#_test_unmet_prereqs(s:registry['1A.1'], s:registry, s:status)
call AssertEq(s:u_d, [],
  \ 'unmet_prereqs: T0 prereq satisfied vacuously when nothing in T0 is built')

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

" 1A.1 has per_motion data so the breakdown line should render below
" its main row. 1A.2 has only frequency_per_min, no per_motion, so it
" should not get a breakdown line.
function! s:sess_pm(date, rate, pm) abort
  return {'timestamp': a:date . 'T12:00:00',
    \ 'frequency_per_min': a:rate, 'per_motion': a:pm}
endfunction

let s:sessions_by_id = {
  \ '1A.1': [
  \   s:sess_pm('2026-01-01', 70.0, {'h': {'rate_per_min': 80.0}, 'l': {'rate_per_min': 60.0}}),
  \   s:sess_pm('2026-01-02', 70.0, {'h': {'rate_per_min': 80.0}, 'l': {'rate_per_min': 60.0}}),
  \   s:sess_pm('2026-01-03', 70.0, {'h': {'rate_per_min': 80.0}, 'l': {'rate_per_min': 60.0}}),
  \   ],
  \ '1A.2': [s:sess('2026-01-03', 30.0)],
  \ }
let s:rendered = join(vimfluency#_test_render_list(s:registry, s:sessions_by_id), "\n")
call Assert(s:rendered =~# 'Tier 1 — Motions',
  \ 'render_list: tier header rendered')
call Assert(s:rendered =~# 'h 80/min',
  \ 'render_list: per-motion breakdown line shows individual motion rates')
call Assert(s:rendered =~# 'l 60/min',
  \ 'render_list: per-motion breakdown lists all motions in the dict')
call Assert(s:rendered =~# '1A — Char & line',
  \ 'render_list: sub-group header rendered for tier 1')
call Assert(s:rendered =~# '✓ at aim',
  \ 'render_list: at-aim status icon present for 1A.1')
call Assert(s:rendered =~# '○ not started',
  \ 'render_list: not-started icon present for pinpoints with no sessions')
call Assert(s:rendered =~# 'needs.*at aim',
  \ 'render_list: blocked-by-prereqs annotation present')
call Assert(s:rendered =~# "Today's set",
  \ 'render_list: today-summary footer present')

" -- list_line_to_id_map (interactive :VfList) --
"
" Each pinpoint row in the rendered list should map to its id; tier
" headers, group headers, blank lines, and the footer should NOT have
" entries; per-motion sub-rows (14 leading spaces) should inherit the
" parent pinpoint's id so the cursor doesn't dead-zone on them.

let s:lines_for_map = vimfluency#_test_render_list(s:registry, s:sessions_by_id)
let s:line_map = vimfluency#_test_list_line_map(s:lines_for_map, s:registry)

" Every registry id appears in the map at least once.
let s:ids_in_map = {}
for s:lnum in keys(s:line_map)
  let s:ids_in_map[s:line_map[s:lnum]] = 1
endfor
for s:id in keys(s:registry)
  call Assert(get(s:ids_in_map, s:id, 0) == 1,
    \ 'line_map: registry id ' . s:id . ' appears in the map')
endfor

" Find 1A.1's line and confirm it maps to '1A.1'.
let s:row_1A1 = -1
for s:i in range(len(s:lines_for_map))
  if s:lines_for_map[s:i] =~# '^    1A\.1\>'
    let s:row_1A1 = s:i + 1
    break
  endif
endfor
call Assert(s:row_1A1 > 0, 'line_map: 1A.1 pinpoint row found')
call AssertEq(get(s:line_map, s:row_1A1, ''), '1A.1',
  \ 'line_map: 1A.1 row maps to "1A.1"')

" 1A.1 has per_motion data → the next line should be the breakdown
" row and should also map to '1A.1' (sub-row inherits parent id).
call AssertEq(get(s:line_map, s:row_1A1 + 1, ''), '1A.1',
  \ 'line_map: per-motion sub-row inherits parent pinpoint id')

" Tier and group header lines should NOT appear in the map.
for s:i in range(len(s:lines_for_map))
  let s:lt = s:lines_for_map[s:i]
  if s:lt =~# '^Tier ' || s:lt =~# '^  \S\+ —' || empty(s:lt)
    call Assert(!has_key(s:line_map, s:i + 1),
      \ 'line_map: non-pinpoint row at line ' . (s:i + 1) . ' has no entry')
  endif
endfor
