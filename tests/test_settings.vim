" Tests for user settings — per-pinpoint aim overrides + global default
" duration. Both live in $XDG_DATA_HOME/vimfluency/settings.json and
" thread through s:effective_aim / s:effective_duration. Tests point
" $XDG_DATA_HOME at a tempdir so the user's real settings file is
" untouched.

let s:tmp = tempname()
call mkdir(s:tmp . '/vimfluency', 'p')
let $XDG_DATA_HOME = s:tmp

" -- effective_aim / effective_duration with no settings file --
"
" A fresh install (no settings.json) returns the pinpoint's meta.aim
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
  \ 'effective_aim: pinpoint NOT in overrides → falls back to meta.aim')
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
" When a pinpoint has an aim override, its row's aim field carries a
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
for s:row in s:av.pinpoint_rows
  call add(s:order, s:av.mapping[s:row])
endfor
call AssertEq(s:order, ['bar', 'foo'],
  \ 'sort aim asc: effective aim (override) drives sort order, not meta.aim')

" Cleanup: delete the temp file so subsequent test files start clean.
call delete(s:tmp . '/vimfluency/settings.json')
