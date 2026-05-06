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

" -- render_list smoke test --

let s:sessions_by_id = {
  \ '1A.1': [s:sess('2026-01-01', 70.0), s:sess('2026-01-02', 70.0), s:sess('2026-01-03', 70.0)],
  \ '1A.2': [s:sess('2026-01-03', 30.0)],
  \ }
let s:rendered = join(vimfluency#_test_render_list(s:registry, s:sessions_by_id), "\n")
call Assert(s:rendered =~# 'Tier 1 — Motions',
  \ 'render_list: tier header rendered')
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
