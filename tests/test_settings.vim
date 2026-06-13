" Tests for user settings — per-drill aim overrides + global default
" duration. Both live in $XDG_DATA_HOME/vimfluency/settings.json and
" thread through s:effective_aim / s:effective_duration. Tests point
" $XDG_DATA_HOME at a tempdir so the user's real settings file is
" untouched.

let s:tmp = tempname()
call mkdir(s:tmp . '/vimfluency', 'p')
let $XDG_DATA_HOME = s:tmp

" -- effective_aim / effective_duration with no settings file --
"
" A fresh install (no settings.json) returns the drill's meta.aim
" and the 60s default duration. Nothing on disk yet at this point.
let s:meta = {'aim': 50}
call AssertEq(vimfluency#_test_effective_aim('foo', s:meta), 50,
  \ 'effective_aim: no settings file → falls back to meta.aim')
call AssertEq(vimfluency#_test_effective_duration(), 60,
  \ 'effective_duration: no settings file → 60s default')

" -- write an override file and re-read --
"
" The runner re-reads the file on each call; tests can poke at it
" directly to set up state without going through set_aim/set_duration.
let s:settings = {'aims': {'foo': 75}, 'default_duration': 90}
call writefile([json_encode(s:settings)], s:tmp . '/vimfluency/settings.json')

call AssertEq(vimfluency#_test_effective_aim('foo', s:meta), 75,
  \ 'effective_aim: override wins over meta.aim')
call AssertEq(vimfluency#_test_effective_aim('bar', s:meta), 50,
  \ 'effective_aim: drill NOT in overrides → falls back to meta.aim')
call AssertEq(vimfluency#_test_effective_duration(), 90,
  \ 'effective_duration: default_duration override applied')

" -- malformed file → empty defaults, no error --
"
" Real users do edit JSON files by hand; a broken file should fall
" back gracefully rather than break :VfList / :Vf entirely.
call writefile(['{not valid json'], s:tmp . '/vimfluency/settings.json')
call AssertEq(vimfluency#_test_effective_aim('foo', s:meta), 50,
  \ 'effective_aim: malformed settings file → meta.aim default')
call AssertEq(vimfluency#_test_effective_duration(), 60,
  \ 'effective_duration: malformed settings file → 60s default')

" -- the asterisk shows up in the rendered VfList row --
"
" When a drill has an aim override, its row's aim field carries a
" trailing '*'; rows without an override end with a space so all values
" right-align to the same col.
call delete(s:tmp . '/vimfluency/settings.json')
call writefile([json_encode({'aims': {'foo': 75}})],
  \ s:tmp . '/vimfluency/settings.json')
let s:reg = {
  \ 'foo': {'id': 'foo', 'name': 'foo', 'aim': 50, 'prereqs': [], 'family': 'motion'},
  \ 'bar': {'id': 'bar', 'name': 'bar', 'aim': 50, 'prereqs': [], 'family': 'motion'},
  \ }
let s:view = vimfluency#_test_build_list_view(s:reg, {}, {})
let s:foo_row = ''
let s:bar_row = ''
for s:l in s:view.lines
  if s:l =~# '^ [▶✓○] foo\>' | let s:foo_row = s:l | endif
  if s:l =~# '^ [▶✓○] bar\>' | let s:bar_row = s:l | endif
endfor
call Assert(s:foo_row =~# '75/min\*',
  \ 'render_list: overridden aim row shows trailing asterisk')
call Assert(s:bar_row =~# '50/min ',
  \ 'render_list: non-overridden aim row ends with a space (no asterisk)')

" -- sort by aim picks up the effective (overridden) value --
"
" foo has override 75; bar has default 50. Sort ASC by aim should
" put bar (50) BEFORE foo (75) even though bar's meta.aim and foo's
" meta.aim are equal.
let s:av = vimfluency#_test_build_list_view(s:reg, {}, {}, 'aim', 0)
let s:order = []
for s:row in s:av.drill_rows
  call add(s:order, s:av.mapping[s:row])
endfor
call AssertEq(s:order, ['bar', 'foo'],
  \ 'sort aim asc: effective aim (override) drives sort order, not meta.aim')

" Cleanup: delete the temp file so subsequent test files start clean.
call delete(s:tmp . '/vimfluency/settings.json')

" -- legacy id aliasing --
"
" Renamed drill slugs keep working: vimfluency#canonical_id maps old →
" new, aim overrides stored under an old id migrate on load, and
" session records logged under an old id group under the new id at
" read time. The JSONL log is never rewritten.
call AssertEq(vimfluency#canonical_id('switch_btwn_many_modes'),
  \ 'switch_between_many_modes',
  \ 'canonical_id: renamed slug maps to current slug')
call AssertEq(vimfluency#canonical_id('move_to_till_forward_in_words'),
  \ 'move_to_vs_till_forward_in_words',
  \ 'canonical_id: every legacy map entry resolves (spot check)')
call AssertEq(vimfluency#canonical_id('save_vs_quit'), 'save_vs_quit',
  \ 'canonical_id: current slug passes through unchanged')
call AssertEq(vimfluency#canonical_id('no_such_drill'), 'no_such_drill',
  \ 'canonical_id: unknown id passes through unchanged')

" Aim override stored under the OLD id applies to the NEW id.
call writefile([json_encode({'aims': {'move_to_line_edges_beginning_end': 75}})],
  \ s:tmp . '/vimfluency/settings.json')
call AssertEq(vimfluency#_test_effective_aim('move_to_line_edges_start_end', s:meta), 75,
  \ 'aims migration: override under old id applies to new id')
call AssertEq(vimfluency#_test_effective_aim('move_to_line_edges_beginning_end', s:meta), 50,
  \ 'aims migration: old key is dropped, not duplicated')

" When overrides exist under BOTH ids, the new id wins.
call writefile([json_encode({'aims': {
  \ 'move_to_line_edges_beginning_end': 75,
  \ 'move_to_line_edges_start_end': 80}})],
  \ s:tmp . '/vimfluency/settings.json')
call AssertEq(vimfluency#_test_effective_aim('move_to_line_edges_start_end', s:meta), 80,
  \ 'aims migration: override under new id wins over old-id override')
call delete(s:tmp . '/vimfluency/settings.json')

" A record written by an OLD version — the pre-rename pinpoint_id /
" pinpoint_name field names AND an old slug — must still group under
" the current id. Exercises both back-compat dimensions at once
" (s:rec_id resolves field rename then slug rename).
let s:old_rec = {'pinpoint_id': 'move_to_line_edges_beginning_end',
  \ 'pinpoint_name': 'line edges (0 / $)', 'timestamp': '2026-06-01T12:00:00',
  \ 'frequency_per_min': 42}
call writefile([json_encode(s:old_rec)], s:tmp . '/vimfluency/sessions.jsonl')
call Assert(vimfluency#_test_drill_has_sessions('move_to_line_edges_start_end'),
  \ 'sessions remap: legacy pinpoint_id record groups under the new id')
call Assert(!vimfluency#_test_drill_has_sessions('move_to_line_edges_beginning_end'),
  \ 'sessions remap: nothing left grouped under the old id')

" A record using the new drill_id field but a current slug also works
" (the common go-forward case).
let s:new_rec = {'drill_id': 'save_vs_quit', 'drill_name': 'save vs quit',
  \ 'timestamp': '2026-06-02T12:00:00', 'frequency_per_min': 50}
call writefile([json_encode(s:new_rec)], s:tmp . '/vimfluency/sessions.jsonl')
call Assert(vimfluency#_test_drill_has_sessions('save_vs_quit'),
  \ 'sessions: current drill_id field record groups correctly')
call delete(s:tmp . '/vimfluency/sessions.jsonl')
