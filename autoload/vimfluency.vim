" Session state. Empty dict when no session is active.
let s:session = {}

" Test-only accessor for the runner's session dict. Returns a reference,
" so in-place mutations from the runner are visible to the caller.
function! vimfluency#_test_state() abort
  return s:session
endfunction

" Test-only entrypoint for the skip path. The user-facing trigger is the
" buffer-local <Tab> mapping, but :normal \<Tab> is unreliable in batch
" (-Es) mode, so tests call this directly.
function! vimfluency#_test_skip() abort
  call s:skip()
endfunction

" Test-only render accessor. Returns the chart lines as a list — same
" content :VfChart shows in its tab buffer, but addressable from
" headless mode (where tabnew + getline misbehaves under -Es).
function! vimfluency#_test_render_chart(id, sessions, ...) abort
  let bounds = a:0 ? a:1 : s:CHART_BOUNDS_FULL
  return s:render_chart(a:id, a:sessions, bounds)
endfunction

function! vimfluency#_test_chart_bounds_zoom() abort
  return s:CHART_BOUNDS_ZOOM
endfunction

function! vimfluency#_test_build_list_view(registry, sessions_by_id, ...) abort
  let expanded = a:0 >= 1 ? a:1 : {}
  let sort_col = a:0 >= 2 ? a:2 : ''
  let sort_desc = a:0 >= 3 ? a:3 : 0
  return s:build_list_view(a:registry, a:sessions_by_id, expanded,
    \ sort_col, sort_desc)
endfunction

function! vimfluency#_test_pinpoint_has_lesson(id) abort
  return s:pinpoint_has_lesson(a:id)
endfunction

function! vimfluency#_test_pinpoint_has_sessions(id) abort
  return s:pinpoint_has_sessions(a:id)
endfunction

function! vimfluency#_test_status_from_sessions(aim, sessions) abort
  return s:status_from_sessions(a:aim, a:sessions)
endfunction

function! vimfluency#_test_unmet_prereqs(meta, registry, status_map) abort
  return s:unmet_prereqs(a:meta, a:registry, a:status_map)
endfunction

function! vimfluency#_test_per_motion_from_sessions(sessions) abort
  return s:per_motion_from_sessions(a:sessions)
endfunction

function! s:round3(x) abort
  return str2float(printf('%.3f', a:x))
endfunction

" Build a numbered annotation row aligned with item.lines[0]. Each
" waypoint gets a number 1..N (in declared order); the final target
" gets N+1. Returns [annotation_string] (a single-line list) when the
" item declares non-empty waypoints, otherwise [] so callers can
" splice it into the header unconditionally. Multi-row annotation
" isn't supported yet — every numbered position must sit on row 1.
function! s:waypoint_annotation(item) abort
  if !has_key(a:item, 'waypoints') || empty(a:item.waypoints)
    return []
  endif
  if empty(a:item.lines) | return [] | endif
  let llen = len(a:item.lines[0])
  let annotation = repeat(' ', llen)
  let n = 1
  for wp in a:item.waypoints
    if wp[0] == 1 && wp[1] >= 1 && wp[1] <= llen
      let annotation = strpart(annotation, 0, wp[1] - 1)
        \ . string(n) . strpart(annotation, wp[1])
    endif
    let n += 1
  endfor
  let trow = a:item.target[0]
  let tcol = a:item.target[1]
  if trow == 1 && tcol >= 1 && tcol <= llen
    let annotation = strpart(annotation, 0, tcol - 1)
      \ . string(n) . strpart(annotation, tcol)
  endif
  return [annotation]
endfunction

" Add VfTarget highlights for each declared waypoint at its buffer row
" (header_offset + item-coord row). Stores match IDs on the session so
" they can be cleared on render_complete or the next frame.
function! s:add_waypoint_matches(item) abort
  let s:session.waypoint_match_ids = []
  if !has_key(a:item, 'waypoints') || empty(a:item.waypoints)
    return
  endif
  for wp in a:item.waypoints
    let buf_row = s:session.header_offset + wp[0]
    let id = matchaddpos('VfTarget', [[buf_row, wp[1], 1]], 20)
    call add(s:session.waypoint_match_ids, id)
  endfor
endfunction

function! s:clear_waypoint_matches() abort
  if !has_key(s:session, 'waypoint_match_ids') | return | endif
  for id in s:session.waypoint_match_ids
    silent! call matchdelete(id)
  endfor
  let s:session.waypoint_match_ids = []
endfunction

function! vimfluency#log_dir() abort
  let dir = exists('$XDG_DATA_HOME') && !empty($XDG_DATA_HOME)
    \ ? $XDG_DATA_HOME . '/vimfluency'
    \ : expand('~/.local/share/vimfluency')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  return dir
endfunction

" -----------------------------------------------------------------
" User settings — per-pinpoint aim overrides + global default duration.
" -----------------------------------------------------------------
"
" Settings live in $XDG_DATA_HOME/vimfluency/settings.json next to the
" session log. Two fields are recognized:
"   "aims":             {pinpoint_id → integer rate per minute}
"   "default_duration": integer seconds (applies when :Vf has no arg)
"
" Defaults stay in each pinpoint's meta(); the user's overrides sit on
" top via s:effective_aim() / s:effective_duration(). Status, charts,
" the VfList view, the breakdown ✓ mark, and the runner ALL read
" through the effective helpers, so a single override propagates
" everywhere.

function! s:settings_path() abort
  return vimfluency#log_dir() . '/settings.json'
endfunction

" Load the settings dict. Missing file or malformed JSON both yield
" the empty defaults so the runner never errors on a fresh install.
function! s:load_settings() abort
  let path = s:settings_path()
  if !filereadable(path) | return {'aims': {}} | endif
  try
    let raw = join(readfile(path), "\n")
    let parsed = json_decode(raw)
    if type(parsed) != type({}) | return {'aims': {}} | endif
    if !has_key(parsed, 'aims') | let parsed.aims = {} | endif
    return parsed
  catch
    return {'aims': {}}
  endtry
endfunction

function! s:save_settings(settings) abort
  call writefile([json_encode(a:settings)], s:settings_path())
endfunction

" Effective aim for a pinpoint = user override (if set) else meta.aim.
function! s:effective_aim(id, meta) abort
  let aims = get(s:load_settings(), 'aims', {})
  return get(aims, a:id, get(a:meta, 'aim', 0))
endfunction

" Effective default duration in seconds for :Vf with no explicit arg.
" Explicit duration on :Vf <id> N is unaffected — this is JUST the
" default when the user doesn't specify.
function! s:effective_duration() abort
  return get(s:load_settings(), 'default_duration', 60)
endfunction

" :VfSetAim <id> <rate>  — store an aim override for one pinpoint.
function! vimfluency#set_aim(id, rate) abort
  let registry = vimfluency#discover_pinpoints()
  if !has_key(registry, a:id)
    echo 'unknown pinpoint: ' . a:id . '  (try :VfList)'
    return
  endif
  let rate = str2nr(a:rate)
  if rate <= 0
    echo 'aim must be a positive integer (rate per minute)'
    return
  endif
  let settings = s:load_settings()
  if !has_key(settings, 'aims') | let settings.aims = {} | endif
  let settings.aims[a:id] = rate
  call s:save_settings(settings)
  echo 'aim for ' . a:id . ' set to ' . rate . '/min'
    \ . ' (default ' . registry[a:id].aim . '/min)'
endfunction

" :VfResetAim <id>  — clear the aim override for one pinpoint.
function! vimfluency#reset_aim(id) abort
  let registry = vimfluency#discover_pinpoints()
  if !has_key(registry, a:id)
    echo 'unknown pinpoint: ' . a:id . '  (try :VfList)'
    return
  endif
  let settings = s:load_settings()
  let aims = get(settings, 'aims', {})
  if !has_key(aims, a:id)
    echo 'no aim override set for ' . a:id
    return
  endif
  call remove(aims, a:id)
  let settings.aims = aims
  call s:save_settings(settings)
  echo 'aim override cleared for ' . a:id
    \ . ' (reverted to ' . registry[a:id].aim . '/min)'
endfunction

" :VfSetDuration <seconds>  — store the global default duration.
function! vimfluency#set_duration(seconds) abort
  let secs = str2nr(a:seconds)
  if secs <= 0
    echo 'duration must be a positive integer (seconds)'
    return
  endif
  let settings = s:load_settings()
  let settings.default_duration = secs
  call s:save_settings(settings)
  echo 'default duration set to ' . secs . 's'
endfunction

" :VfResetDuration  — clear the global default duration override.
function! vimfluency#reset_duration() abort
  let settings = s:load_settings()
  if !has_key(settings, 'default_duration')
    echo 'no default duration override set'
    return
  endif
  call remove(settings, 'default_duration')
  call s:save_settings(settings)
  echo 'default duration cleared (reverted to 60s)'
endfunction

" Test accessors.
function! vimfluency#_test_effective_aim(id, meta) abort
  return s:effective_aim(a:id, a:meta)
endfunction

function! vimfluency#_test_effective_duration() abort
  return s:effective_duration()
endfunction

function! vimfluency#discover_pinpoints() abort
  let registry = {}
  let files = globpath(&runtimepath, 'autoload/vimfluency/pinpoints/*.vim', 0, 1)
  for f in files
    let mod = fnamemodify(f, ':t:r')
    let MetaFn = function('vimfluency#pinpoints#' . mod . '#meta')
    let info = MetaFn()
    let info.module = mod
    let registry[info.id] = info
  endfor
  return registry
endfunction

function! vimfluency#complete(arglead, cmdline, cursorpos) abort
  let registry = vimfluency#discover_pinpoints()
  return filter(sort(keys(registry)), 'v:val =~# "^" . a:arglead')
endfunction

" Human-readable family labels for navigator display. Mirrors the
" `family` value in each pinpoint's meta(). Unknown families fall
" back to the family slug itself. Order in this list defines the
" display order in :VfList; add new families in the order you want
" them to appear. Labels are plain section names — the header
" template adds the section framing, so don't bake "family" into
" the label (that produced "Delete family family — delete").
" :VfList column layout — fixed 0-indexed DISPLAY columns so the one
" header row and every data row line up. Column titles live in the
" header row, not inline. The status word column is gone; the leading
" ▶/✓/○ bullet encodes status and a banner legend names each icon.
"
" S_* are LEFT-edge start columns (left-aligned text). E_* are RIGHT-
" edge END columns (one past the last char; both header and value
" right-align to the same edge so numbers stack under their headers).
" Keep behavior slugs under ~40 chars and family values under ~18 or
" the row drifts.
" Each column's marker sits 1 col after the HEADER TEXT (not the
" column's right edge), so for left-aligned columns the marker stays
" visually close to its header name instead of drifting all the way
" to the next column's gutter. Right-aligned numeric columns are
" headers-flush-right, so their marker DOES land in the gutter — for
" those the E_* values reserve ≥2 cols between the marker and the
" next column's header so the marker is unambiguously associated
" with the column to its left.
let s:S_BULLET       = 1     " ▶ / ✓ / ○
let s:S_DRILL        = 3     " 'drill' column (values: pinpoint slug, max ~38 chars)
let s:S_COMMANDS     = 45    " 'commands' column (values: space-separated keys)
let s:E_PREREQS_N    = 66    " 'prereqs_n' (9 cols)
let s:E_AIM          = 76    " 'aim' (3) but value '%3d/min%s' (8) sets the width — the trailing %s is ' ' or '*' for user-override
let s:E_LAST_RATE    = 89    " 'last_rate' (9)
let s:E_LAST_SESSION = 105   " 'last_session' (12)
let s:E_RUNS         = 113   " 'runs' (4); value up to 3 digits → col width 4
let s:S_FAMILY       = 117   " family is the last column

" Marker cols for left-aligned columns — 1 col past the END of the
" HEADER TEXT (not the column's max value extent), so the marker
" reads as attached to its header name.
let s:M_DRILL        = 9     " 'drill'    (5 chars) at S=3   → ends col 7;   marker col 9
let s:M_COMMANDS     = 54    " 'commands' (8 chars) at S=45  → ends col 52;  marker col 54
let s:M_FAMILY       = 124   " 'family'   (6 chars) at S=117 → ends col 122; marker col 124

" Number of leading lines in s:build_list_view's output that form the
" sticky header — banner intro, action hints, status legend, sort
" hints, blank, the column-header row. :VfList puts these in a small
" fixed-height window above the scrollable data window so the column
" titles stay visible when the user scrolls through the table.
let s:HEADER_COUNT = 7

" Breakdown sub-section layout: ├/└/│ in BD_TREE column; prereq entries
" indent at BD_BODY; the commands sub-table places the ✓-at-aim mark,
" the command name, and the three numeric columns at fixed cols.
let s:BD_TREE         = 3
let s:BD_BODY         = 5
let s:BD_CMD_MARK     = 5     " ✓ if command's last_rate ≥ pinpoint aim
let s:BD_CMD_NAME     = 7
let s:BD_CMD_PREV     = 19    " 'last_rate' header (9 cols)
let s:BD_CMD_STROKES  = 34    " 'stroke_count' (12 cols)
let s:BD_CMD_PER_STR  = 48    " 'stroke_rate' (11 cols)

let s:FAMILY_NAMES = [
  \ ['survival',          'Survival'],
  \ ['motion',            'Motions'],
  \ ['v',                 'Visual mode'],
  \ ['delete',            'Delete'],
  \ ['change',            'Change'],
  \ ['yank',              'Yank'],
  \ ['paste',             'Paste'],
  \ ['indent',            'Indent'],
  \ ['text-object-recall', 'Text objects (recall, legacy)'],
  \ ]

" Read sessions.jsonl once, return {pinpoint_id → list of records}.
function! s:load_sessions_grouped() abort
  let log_path = vimfluency#log_dir() . '/sessions.jsonl'
  let by_id = {}
  if !filereadable(log_path) | return by_id | endif
  for line in readfile(log_path)
    if empty(line) | continue | endif
    try
      let r = json_decode(line)
      let id = get(r, 'pinpoint_id', '')
      if empty(id) | continue | endif
      if !has_key(by_id, id) | let by_id[id] = [] | endif
      call add(by_id[id], r)
    catch
    endtry
  endfor
  return by_id
endfunction

" Status from session history. PT convention: 'at_aim' requires three
" consecutive recent non-zero-rate sessions at-or-above aim. Anything
" run-but-not-yet-stable is 'climbing'. No sessions (or only zero-rate
" quits) is 'not_started'.
" Status from session history. Takes the EFFECTIVE aim directly so the
" caller can supply meta.aim or a user override; status is computed
" against today's target.
function! s:status_from_sessions(aim, sessions) abort
  if empty(a:sessions) | return 'not_started' | endif
  let usable = filter(copy(a:sessions),
    \ 'get(v:val, "frequency_per_min", 0) > 0')
  if empty(usable) | return 'not_started' | endif
  call sort(usable, {a, b -> a.timestamp ==# b.timestamp ? 0
    \ : (a.timestamp <# b.timestamp ? -1 : 1)})
  if len(usable) < 3 | return 'climbing' | endif
  for s in usable[-3:]
    if s.frequency_per_min < a:aim | return 'climbing' | endif
  endfor
  return 'at_aim'
endfunction

" Most recent non-zero-rate session, or {} if none. Sole source-of-truth
" for what "the last training session" means in :VfList — last_rate and
" last_date derive from the same record so they can't drift, and a
" zero-rate quit doesn't count as "trained."
function! s:last_session(sessions) abort
  if empty(a:sessions) | return {} | endif
  let usable = filter(copy(a:sessions),
    \ 'get(v:val, "frequency_per_min", 0) > 0')
  if empty(usable) | return {} | endif
  call sort(usable, {a, b -> a.timestamp ==# b.timestamp ? 0
    \ : (a.timestamp <# b.timestamp ? 1 : -1)})
  return usable[0]
endfunction

function! s:last_rate_from_sessions(sessions) abort
  let s = s:last_session(a:sessions)
  return empty(s) ? 0.0 : s.frequency_per_min
endfunction

" Simple YYYY-MM-DD date of the last training session (the same record
" last_rate comes from). Empty string when there are no usable sessions.
function! s:last_date_from_sessions(sessions) abort
  let s = s:last_session(a:sessions)
  return empty(s) ? '' : strpart(get(s, 'timestamp', ''), 0, 10)
endfunction

function! s:status_label(status) abort
  if a:status ==# 'at_aim'       | return '✓ at aim'
  elseif a:status ==# 'climbing' | return '▶ climbing'
  else                           | return '○ not started'
  endif
endfunction

" Just the bullet glyph, for the leading-column variant in :VfList.
function! s:status_icon(status) abort
  if a:status ==# 'at_aim'       | return '✓'
  elseif a:status ==# 'climbing' | return '▶'
  else                           | return '○'
  endif
endfunction

" Per-motion breakdown from the SAME session last_rate / last_date come
" from, or {} if none. Returns a flat {motion → rate_per_min (float)}
" for display (the runner stores per_motion as {motion → {rate_per_min,
" correct, ...}}).
function! s:per_motion_from_sessions(sessions) abort
  let s = s:last_session(a:sessions)
  if empty(s) | return {} | endif
  let pm = get(s, 'per_motion', {})
  let out = {}
  for [motion, stats] in items(pm)
    let out[motion] = get(stats, 'rate_per_min', 0)
  endfor
  return out
endfunction

" Resolve prereqs against the registry. A prereq is either a specific
" Under the slug-based ID scheme each prereq is a specific pinpoint
" slug (no group/tier prefix matching). If the prereq isn't yet built,
" it counts as satisfied — you can't be blocked by what doesn't exist.
function! s:unmet_prereqs(meta, registry, status_map) abort
  let unmet = []
  for prereq in get(a:meta, 'prereqs', [])
    if !has_key(a:registry, prereq) | continue | endif
    if a:status_map[prereq] !=# 'at_aim'
      call add(unmet, prereq)
    endif
  endfor
  return unmet
endfunction

" Transitive prereq depth: max depth of in-registry prereqs + 1; a
" pinpoint with no (in-registry) prereqs is 0. :VfList orders each
" family foundational-first by this depth, so a pinpoint always sorts
" after the ones it builds on (raw prereq count would misorder — a
" word motion has one prereq but is deeper than a single-char motion
" with two). The cache doubles as a cycle guard (in-progress = 0).
function! s:pinpoint_depth(id, registry, cache) abort
  if has_key(a:cache, a:id) | return a:cache[a:id] | endif
  let a:cache[a:id] = 0
  let max_d = 0
  for prereq in get(a:registry[a:id], 'prereqs', [])
    if has_key(a:registry, prereq)
      let max_d = max([max_d, s:pinpoint_depth(prereq, a:registry, a:cache) + 1])
    endif
  endfor
  let a:cache[a:id] = max_d
  return max_d
endfunction

" Append a:text so it starts at DISPLAY column a:col, padding the line
" with spaces to reach it. If the line already reached/passed the
" column (a long previous field), fall back to a single separating
" space so the row stays readable rather than silently concatenating.
function! s:place(line, col, text) abort
  let w = strdisplaywidth(a:line)
  let pad = a:col > w ? a:col - w : 1
  return a:line . repeat(' ', pad) . a:text
endfunction

" Right-aligned variant: append a:text so it ENDS just before display
" column a:end_col (last char at a:end_col - 1). Used for numeric
" columns where the header and value share the same right edge — the
" digits stack under their header without floating to the left.
function! s:place_right(line, end_col, text) abort
  let w = strdisplaywidth(a:line)
  let start = a:end_col - strdisplaywidth(a:text)
  let pad = start > w ? start - w : 1
  return a:line . repeat(' ', pad) . a:text
endfunction

" Characters that require Shift on US QWERTY. Each costs 2 keystrokes
" (the shift modifier counts as its own physical press) — used by
" s:command_strokes to count a command's keystroke length.
let s:SHIFTED_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ~!@#$%^&*()_+{}|:"<>?'

function! s:char_strokes(ch) abort
  return stridx(s:SHIFTED_CHARS, a:ch) >= 0 ? 2 : 1
endfunction

" Strokes inside a <…> chord: 1 per modifier (C / S / M / A / D) plus
" the trailing base key (single char goes through char_strokes; a named
" key like 'Esc' / 'CR' / 'Tab' / 'F1' counts as 1).
function! s:chord_strokes(inner) abort
  let parts = split(a:inner, '-')
  if empty(parts) | return 1 | endif
  let n = len(parts) - 1
  let base = parts[-1]
  return n + (strlen(base) == 1 ? s:char_strokes(base) : 1)
endfunction

" Total physical keystrokes for a vim command string. Walks left-to-
" right: <…> sequences are one chord, everything else is a sequence of
" base characters. Auto-derived on every breakdown row; a pinpoint can
" override per-command via meta()'s `stroke_counts: {motion → N}`.
function! s:command_strokes(cmd) abort
  let n = 0
  let i = 0
  let L = strlen(a:cmd)
  while i < L
    if a:cmd[i] ==# '<'
      let close = stridx(a:cmd, '>', i + 1)
      if close > i
        let n += s:chord_strokes(strpart(a:cmd, i + 1, close - i - 1))
        let i = close + 1
        continue
      endif
    endif
    let n += s:char_strokes(a:cmd[i])
    let i += 1
  endwhile
  return n
endfunction

" Test-only accessor for stroke counting.
function! vimfluency#_test_command_strokes(cmd) abort
  return s:command_strokes(a:cmd)
endfunction

" Render last_rate / stroke_count as a rate per minute, dropping the
" decimal when the result is integer-ish (within 0.05 of a whole
" number). 25/3 → "8.3/min"; 52/4 → "13/min".
function! s:stroke_rate_field(rate, strokes) abort
  if a:strokes <= 0 | return '—' | endif
  let raw = a:rate * 1.0 / a:strokes
  let nearest = float2nr(raw + 0.5)
  if abs(raw - nearest) < 0.05
    return printf('%d/min', nearest)
  endif
  return printf('%.1f/min', raw)
endfunction

" Sort-primary string for one pinpoint, keyed by the user-chosen
" column. Returns a string so vim's lex sort matches the natural
" order: numeric values are zero-padded, dates are ISO so lex == time.
" Empty column (or 'family') falls through to the curated family
" order. Empty 'previous_session' values sort first (lowest).
function! s:sort_primary(id, sort_col, ctx) abort
  let m = a:ctx.registry[a:id]
  if a:sort_col ==# 'drill'
    return a:id
  elseif a:sort_col ==# 'commands'
    return get(m, 'keys', '')
  elseif a:sort_col ==# 'prereqs_n'
    return printf('%04d', a:ctx.depth[a:id])
  elseif a:sort_col ==# 'aim'
    return printf('%05d', a:ctx.effective_aims[a:id])
  elseif a:sort_col ==# 'last_rate'
    return printf('%010.3f', a:ctx.prev_rate[a:id])
  elseif a:sort_col ==# 'last_session'
    return empty(a:ctx.prev_date[a:id]) ? '0000-00-00' : a:ctx.prev_date[a:id]
  elseif a:sort_col ==# 'runs'
    return printf('%05d', a:ctx.sessions_count[a:id])
  endif
  " '' (default) or 'family' → curated family order
  return printf('%04d', get(a:ctx.family_order,
    \ get(m, 'family', 'zzz'), 999))
endfunction

" Header placement with optional ▲/▼ marker in the gutter to the
" RIGHT of the column. The header text is placed first (left- or
" right-aligned per its column kind); the marker, when the column is
" the active sort, then lands at a fixed gutter column with a space
" between header text and marker.
"   right-aligned columns — marker at end_col + 1 (one col past header
"                            right edge, in the inter-column gutter)
"   left-aligned columns  — marker at a per-column marker_col chosen
"                            to sit past the column's max value extent
function! s:place_right_hdr(line, end_col, name, sort_col, sort_desc) abort
  let line = s:place_right(a:line, a:end_col, a:name)
  if a:name ==# a:sort_col
    let line = s:place(line, a:end_col + 1, a:sort_desc ? '▼' : '▲')
  endif
  return line
endfunction

function! s:place_left_hdr(line, col, name, sort_col, sort_desc, marker_col) abort
  let line = s:place(a:line, a:col, a:name)
  if a:name ==# a:sort_col
    let line = s:place(line, a:marker_col, a:sort_desc ? '▼' : '▲')
  endif
  return line
endfunction

" Build the :VfList view in one pass: rendered lines PLUS the
" line-coordinate map the interactive navigator needs. The renderer
" is the single source of truth for which line is which pinpoint —
" the coordinate map is recorded as each row is emitted, never
" re-parsed from formatted text. Returns:
"   lines         — buffer lines
"   mapping       — 1-indexed line → pinpoint id (main rows AND
"                   per-motion sub-rows, so action keys resolve from
"                   either)
"   pinpoint_rows — sorted line numbers of MAIN rows only; j/k
"                   navigation snaps to these
" `expanded` is a dict {id: 1} of pinpoints whose per-motion
" breakdown should be shown (toggled by B). Breakdown rows are NOT
" auto-shown — the default view is just the pinpoint rows.
" Optional positional args:
"   sort_col   — column name to sort by ('' = default family order)
"   sort_desc  — 0 = ascending, 1 = descending. Tiebreaker is always
"                (family, depth, slug) ascending regardless of dir.
" Pure function over registry + sessions so tests can drive it
" without touching the user's real log.
function! s:build_list_view(registry, sessions_by_id, expanded, ...) abort
  let sort_col = a:0 >= 1 ? a:1 : ''
  let sort_desc = a:0 >= 2 ? a:2 : 0
  let aim_overrides = get(s:load_settings(), 'aims', {})
  let status_map = {}
  let prev_rate = {}
  let prev_date = {}
  let sessions_count = {}
  let effective_aims = {}    " effective aim per pinpoint (override or meta.aim)
  for [id, m] in items(a:registry)
    let s = get(a:sessions_by_id, id, [])
    let effective_aims[id] = get(aim_overrides, id, get(m, 'aim', 0))
    let status_map[id]     = s:status_from_sessions(effective_aims[id], s)
    let prev_rate[id]      = s:last_rate_from_sessions(s)
    let prev_date[id]      = s:last_date_from_sessions(s)
    " Non-zero-rate sessions only — a zero-rate quit isn't a usable
    " training sample, so sessions_count is consistent with what
    " previous_rate and previous_session both read from.
    let sessions_count[id] = len(filter(copy(s),
      \ 'get(v:val, "frequency_per_min", 0) > 0'))
  endfor

  " Prereq depth: both a column and the within-family sort key.
  let depth = {}
  for id in keys(a:registry)
    call s:pinpoint_depth(id, a:registry, depth)
  endfor

  " Curated family ordering from FAMILY_NAMES; unknown families fall
  " through to the end. The default sort is (family, depth, slug);
  " when sort_col is set, that column becomes the primary key and
  " (family, depth, slug) drops to the tiebreaker. Direction (asc/desc)
  " flips only the primary — tiebreakers stay ascending so two rows
  " with the same primary value keep the same relative order whether
  " you've toggled direction or not.
  let family_order = {}
  let fi = 0
  for [fam, _label] in s:FAMILY_NAMES
    let family_order[fam] = fi
    let fi += 1
  endfor
  let ctx = {'registry': a:registry, 'depth': depth, 'prev_rate': prev_rate,
    \ 'prev_date': prev_date, 'sessions_count': sessions_count,
    \ 'effective_aims': effective_aims, 'family_order': family_order}
  let primary = {}
  let tiebreak = {}
  for id in keys(a:registry)
    let primary[id] = s:sort_primary(id, sort_col, ctx)
    let fkey = get(family_order, get(a:registry[id], 'family', 'zzz'), 999)
    let tiebreak[id] = printf('%04d:%03d:%s', fkey, depth[id], id)
  endfor
  let sorted_ids = sort(keys(a:registry), {x, y ->
    \ primary[x] !=# primary[y]
    \   ? (sort_desc
    \      ? (primary[x] <# primary[y] ? 1 : -1)
    \      : (primary[x] <# primary[y] ? -1 : 1))
    \   : (tiebreak[x] ==# tiebreak[y] ? 0
    \      : (tiebreak[x] <# tiebreak[y] ? -1 : 1))})

  let lines = []
  let mapping = {}
  let pinpoint_rows = []

  call add(lines, printf('vim-fluency: %d pinpoint(s) built',
    \ len(a:registry)))
  call add(lines, '')
  call add(lines, 'Move with j/k, then:  (L)earn  (T)rain  (C)hart  (B)reakdown  set (A)im  (D)uration   ·   q closes')
  call add(lines, 'Status:  ✓ at aim    ▶ climbing    ○ not started')
  call add(lines, 'Sort with s + column letter:  d c p a r s n f   (repeat letter to reverse; s<Space> resets)')
  call add(lines, '')

  " Column header row. The bullet column at S_BULLET has no header —
  " the legend above names each icon. The sorted column gets a ▲/▼
  " marker 1 col after the header text (in the gutter for the tight
  " right-aligned columns).
  let head = s:place_left_hdr('',    s:S_DRILL,         'drill',        sort_col, sort_desc, s:M_DRILL)
  let head = s:place_left_hdr(head,  s:S_COMMANDS,      'commands',     sort_col, sort_desc, s:M_COMMANDS)
  let head = s:place_right_hdr(head, s:E_PREREQS_N,     'prereqs_n',    sort_col, sort_desc)
  let head = s:place_right_hdr(head, s:E_AIM,           'aim',          sort_col, sort_desc)
  let head = s:place_right_hdr(head, s:E_LAST_RATE,     'last_rate',    sort_col, sort_desc)
  let head = s:place_right_hdr(head, s:E_LAST_SESSION,  'last_session', sort_col, sort_desc)
  let head = s:place_right_hdr(head, s:E_RUNS,          'runs',         sort_col, sort_desc)
  let head = s:place_left_hdr(head,  s:S_FAMILY,        'family',       sort_col, sort_desc, s:M_FAMILY)
  call add(lines, head)

  for id in sorted_ids
    let m = a:registry[id]
    let rate = prev_rate[id]
    let rate_field = rate > 0 ? printf('%3d/min', float2nr(rate + 0.5))
      \ : '—'
    let date_field = empty(prev_date[id]) ? '—' : prev_date[id]
    " 'commands' renders meta()'s `keys` field with slashes turned into
    " spaces (i/a/I/A → i a I A). The field stays slash-separated for
    " backwards compatibility; the column is a render concern only.
    let commands = substitute(get(m, 'keys', ''), '/', ' ', 'g')
    " aim is 8 cols: %3d/min + trailing space or '*' when the user has
    " set a personal override via :VfSetAim. The asterisk sits at the
    " column's right edge; non-overridden rows pad with a trailing
    " space so all values right-align to the same col.
    let aim_suffix = has_key(aim_overrides, id) ? '*' : ' '
    let aim_field = printf('%3d/min%s', effective_aims[id], aim_suffix)

    let row = s:place('',   s:S_BULLET,           s:status_icon(status_map[id]))
    let row = s:place(row,  s:S_DRILL,            id)
    let row = s:place(row,  s:S_COMMANDS,         commands)
    let row = s:place_right(row, s:E_PREREQS_N,     printf('%d', depth[id]))
    let row = s:place_right(row, s:E_AIM,           aim_field)
    let row = s:place_right(row, s:E_LAST_RATE,     rate_field)
    let row = s:place_right(row, s:E_LAST_SESSION,  date_field)
    let row = s:place_right(row, s:E_RUNS,          printf('%d', sessions_count[id]))
    let row = s:place(row,  s:S_FAMILY,           get(m, 'family', ''))
    call add(lines, substitute(row, '\s\+$', '', ''))
    let mapping[len(lines)] = id
    call add(pinpoint_rows, len(lines))

    if get(a:expanded, id, 0)
      call s:append_breakdown(lines, mapping, id, m, status_map,
        \ s:per_motion_from_sessions(get(a:sessions_by_id, id, [])),
        \ effective_aims[id])
    endif
  endfor


  return {'lines': lines, 'mapping': mapping, 'pinpoint_rows': pinpoint_rows}
endfunction

" Append the B-toggle breakdown for one expanded pinpoint. Two
" sub-sections, in order:
"   prereqs:   every in-registry prereq, ▶/✓/○ icon + name only
"   commands:  per-command sub-table — last_rate, stroke_count, and
"              stroke_rate (last_rate / strokes); ✓ if the command's
"              last_rate ≥ pinpoint aim
" Whichever sub-section is LAST gets the └ glyph so the tree closes;
" the earlier one gets ├ and its body lines carry │ continuation.
" Vacuous prereqs (slug not in registry) are skipped. All breakdown
" rows inherit the parent id in mapping so action keys still resolve
" from anywhere in the block.
function! s:append_breakdown(lines, mapping, id, meta, status_map, per_motion, aim) abort
  let prereqs = filter(copy(get(a:meta, 'prereqs', [])),
    \ 'has_key(a:status_map, v:val)')
  let has_prereqs  = !empty(prereqs)
  let has_commands = !empty(a:per_motion)
  if !has_prereqs && !has_commands | return | endif

  if has_prereqs
    let glyph = has_commands ? '├' : '└'
    call add(a:lines, s:place('', s:BD_TREE, glyph . ' prereqs:'))
    let a:mapping[len(a:lines)] = a:id
    for prereq in prereqs
      let line = has_commands ? s:place('', s:BD_TREE, '│') : ''
      let line = s:place(line, s:BD_BODY,
        \ s:status_icon(a:status_map[prereq]) . ' ' . prereq)
      call add(a:lines, line)
      let a:mapping[len(a:lines)] = a:id
    endfor
    if has_commands
      call add(a:lines, s:place('', s:BD_TREE, '│'))
      let a:mapping[len(a:lines)] = a:id
    endif
  endif

  if has_commands
    call add(a:lines, s:place('', s:BD_TREE, '└ commands:'))
    let a:mapping[len(a:lines)] = a:id
    let head = s:place('', s:BD_CMD_NAME, 'command')
    let head = s:place(head, s:BD_CMD_PREV,    'last_rate')
    let head = s:place(head, s:BD_CMD_STROKES, 'stroke_count')
    let head = s:place(head, s:BD_CMD_PER_STR, 'stroke_rate')
    call add(a:lines, substitute(head, '\s\+$', '', ''))
    let a:mapping[len(a:lines)] = a:id
    let overrides = get(a:meta, 'stroke_counts', {})
    let aim = a:aim
    for motion in sort(keys(a:per_motion))
      let mrate_f = a:per_motion[motion]
      let mrate_i = float2nr(mrate_f + 0.5)
      let strokes = get(overrides, motion, s:command_strokes(motion))
      let row = s:place('', s:BD_CMD_MARK, mrate_i >= aim ? '✓' : '')
      let row = s:place(row, s:BD_CMD_NAME,    motion)
      let row = s:place(row, s:BD_CMD_PREV,    printf('%3d/min', mrate_i))
      let row = s:place(row, s:BD_CMD_STROKES, printf('%d', strokes))
      let row = s:place(row, s:BD_CMD_PER_STR,
        \ s:stroke_rate_field(mrate_f, strokes))
      call add(a:lines, substitute(row, '\s\+$', '', ''))
      let a:mapping[len(a:lines)] = a:id
    endfor
  endif
endfunction

function! vimfluency#list() abort
  let registry = vimfluency#discover_pinpoints()
  if empty(registry)
    echo 'no pinpoints built — see CATALOG.md'
    return
  endif
  let view = s:build_list_view(registry, s:load_sessions_grouped(), {})
  call s:show_list_buffer(view)
endfunction

" Wipe the companion 'vf-list-header' buffer so its window doesn't
" linger after the data window closes. Called from a BufWipeout
" autocmd on the data buffer; bwipe is wrapped in silent! so a
" double-close (e.g. user already wiped the header) doesn't error.
function! s:cleanup_list_header_window() abort
  let hbufnr = bufnr('vf-list-header')
  if hbufnr > 0
    silent! execute 'bwipeout! ' . hbufnr
  endif
endfunction

" Split view.lines into the sticky-header slice and the scrollable
" data slice, and translate view.mapping / view.pinpoint_rows (keyed
" by line numbers in the COMBINED output) to line numbers within the
" data slice (so the navigator's b: vars line up with the data buffer).
function! s:split_view(view) abort
  let header_lines = a:view.lines[: s:HEADER_COUNT - 1]
  let data_lines   = a:view.lines[s:HEADER_COUNT :]
  let mapping = {}
  for [k, id] in items(a:view.mapping)
    let ln = str2nr(k) - s:HEADER_COUNT
    if ln >= 1 | let mapping[ln] = id | endif
  endfor
  let pinpoint_rows = []
  for r in a:view.pinpoint_rows
    let dr = r - s:HEADER_COUNT
    if dr >= 1 | call add(pinpoint_rows, dr) | endif
  endfor
  return {'header_lines': header_lines, 'data_lines': data_lines,
    \ 'mapping': mapping, 'pinpoint_rows': pinpoint_rows}
endfunction

" Replace the contents of the data window (assumed current) AND the
" header window for the active :VfList. Used by every rebuild path
" (sort, toggle breakdown, set aim) so the sticky header stays in
" sync with the data when the sort marker or column widths change.
function! s:apply_view(view) abort
  let split = s:split_view(a:view)
  " --- Data window (current) ---
  setlocal modifiable
  silent! %delete _
  call setline(1, split.data_lines)
  setlocal nomodifiable nomodified
  let b:vf_list_line_to_id    = split.mapping
  let b:vf_list_pinpoint_rows = split.pinpoint_rows
  " --- Header window (find the buffer named 'vf-list-header' and
  " replace its lines without disturbing the cursor's window). ---
  let hdr_bufnr = bufnr('vf-list-header')
  if hdr_bufnr <= 0 | return | endif
  let cur_winnr = winnr()
  let hdr_winnr = 0
  for win in range(1, winnr('$'))
    if winbufnr(win) == hdr_bufnr
      let hdr_winnr = win | break
    endif
  endfor
  if hdr_winnr == 0 | return | endif
  execute hdr_winnr . 'wincmd w'
  setlocal modifiable
  silent! %delete _
  call setline(1, split.header_lines)
  setlocal nomodifiable nomodified
  execute cur_winnr . 'wincmd w'
endfunction

function! s:show_list_buffer(view) abort
  let split = s:split_view(a:view)
  tabnew
  let tabnr = tabpagenr()

  " --- Data window (current after tabnew). Holds the scrollable
  " body. The cursor lives here; all navigation and action keys are
  " mapped on this buffer. ---
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal cursorline
  silent! execute 'keepalt file vf-list'
  call setline(1, split.data_lines)
  setlocal nomodifiable nomodified
  let &l:statusline = ' pinpoint list   [L=Learn  T=Train  C=Chart  B=Breakdown  A=Aim  D=Duration  s+col=Sort  q=close]'
  let b:vf_summary_tabnr = tabnr
  let b:vf_summary_prev_laststatus = &laststatus
  let b:vf_list_line_to_id    = split.mapping
  let b:vf_list_pinpoint_rows = split.pinpoint_rows
  let b:vf_list_expanded = {}
  " Sort state: empty col = default (family, depth, slug). When a sort
  " key is pressed, list_sort() updates these and rebuilds the buffer.
  let b:vf_list_sort_col = ''
  let b:vf_list_sort_desc = 0
  set laststatus=2

  " When the data window goes away (via `q`, `:q`, `:close`, etc.),
  " wipe the companion header buffer so its window doesn't linger and
  " require a second :q. BufWipeout fires after vim has already wiped
  " the data buffer; bwipe on the header buffer closes its window and
  " — because that's the last window in the tab — closes the tab too.
  autocmd BufWipeout <buffer> silent! call s:cleanup_list_header_window()

  " Action keys: L=lesson, T=train, C=chart, B=toggle breakdown.
  nnoremap <buffer> <silent> L :call vimfluency#list_action('learn')<CR>
  nnoremap <buffer> <silent> T :call vimfluency#list_action('train')<CR>
  nnoremap <buffer> <silent> C :call vimfluency#list_action('chart')<CR>
  nnoremap <buffer> <silent> B :call vimfluency#list_toggle_breakdown()<CR>
  nnoremap <buffer> <silent> A :call vimfluency#list_set_aim()<CR>
  nnoremap <buffer> <silent> D :call vimfluency#list_set_duration()<CR>
  nnoremap <buffer> <silent> q :call vimfluency#close_summary()<CR>

  " Sort keys: s + column letter. Same letter twice flips direction;
  " s<Space> resets to the default (family, depth, slug) sort. A bare
  " s with nothing after echoes the legend so the keys stay discoverable.
  nnoremap <buffer> <silent> sd :call vimfluency#list_sort('drill')<CR>
  nnoremap <buffer> <silent> sc :call vimfluency#list_sort('commands')<CR>
  nnoremap <buffer> <silent> sp :call vimfluency#list_sort('prereqs_n')<CR>
  nnoremap <buffer> <silent> sa :call vimfluency#list_sort('aim')<CR>
  nnoremap <buffer> <silent> sr :call vimfluency#list_sort('last_rate')<CR>
  nnoremap <buffer> <silent> ss :call vimfluency#list_sort('last_session')<CR>
  nnoremap <buffer> <silent> sn :call vimfluency#list_sort('runs')<CR>
  nnoremap <buffer> <silent> sf :call vimfluency#list_sort('family')<CR>
  nnoremap <buffer> <silent> s<Space> :call vimfluency#list_sort('')<CR>
  nnoremap <buffer> <silent> s :call vimfluency#list_sort_help()<CR>

  " Pinpoint-only navigation. j/k snap between MAIN rows (no
  " landing on sub-rows or headers); gg/G jump to first/last.
  nnoremap <buffer> <silent> j :call vimfluency#list_move('next')<CR>
  nnoremap <buffer> <silent> k :call vimfluency#list_move('prev')<CR>
  nnoremap <buffer> <silent> gg :call vimfluency#list_move('first')<CR>
  nnoremap <buffer> <silent> G :call vimfluency#list_move('last')<CR>

  " --- Header window: a small split ABOVE the data window with the
  " banner + column-header row. Fixed height (winfixheight), no
  " cursorline, read-only. The user can't move the cursor into it
  " via j/k (those are mapped on the data buffer); :wincmd k would
  " technically land there but the buffer is harmless. tabclose
  " from `q` tears the whole tab down so both windows close together.
  topleft new
  execute 'resize ' . s:HEADER_COUNT
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal winfixheight nocursorline
  silent! execute 'keepalt file vf-list-header'
  call setline(1, split.header_lines)
  setlocal nomodifiable nomodified
  " Empty statusline so the inter-window separator is a clean horizontal
  " bar with no label — keeps the visual transition between header and
  " data minimal.
  let &l:statusline = ' '
  " Return to the data window where the cursor lives.
  wincmd j

  " Land cursor on the first pinpoint row.
  let first_line = empty(split.pinpoint_rows) ? 1 : split.pinpoint_rows[0]
  call cursor(first_line, 1)
endfunction

" Pinpoint-only cursor movement inside the :VfList buffer. Snaps to
" the next/prev row in b:vf_list_pinpoint_rows; at the ends, stays
" put (no wrap, matches standard vim's no-wrap-by-default posture).
function! vimfluency#list_move(action) abort
  if !exists('b:vf_list_pinpoint_rows') | return | endif
  let rows = b:vf_list_pinpoint_rows
  if empty(rows) | return | endif
  let current = line('.')
  let target = current
  if a:action ==# 'next'
    for r in rows
      if r > current | let target = r | break | endif
    endfor
  elseif a:action ==# 'prev'
    for i in range(len(rows) - 1, 0, -1)
      if rows[i] < current | let target = rows[i] | break | endif
    endfor
  elseif a:action ==# 'first'
    let target = rows[0]
  elseif a:action ==# 'last'
    let target = rows[-1]
  endif
  call cursor(target, 1)
endfunction

" Invoked by the buffer-local L/T/C mappings. Reads the pinpoint id
" off the cursor line, confirms the action can actually proceed, then
" closes the list tab and launches it.
"
" The pre-flight check matters: close_summary() destroys the list tab,
" so if we closed first and the action then no-op'd (Chart on a
" pinpoint with no logged sessions, Learn on a pinpoint with no
" lesson), the list would vanish with only a fleeting message. Check
" before closing so a no-op leaves the list intact with a hint.
function! vimfluency#list_action(action) abort
  if !exists('b:vf_list_line_to_id') | return | endif
  let id = get(b:vf_list_line_to_id, line('.'), '')
  if empty(id)
    echo 'cursor must be on a pinpoint row'
    return
  endif

  if a:action ==# 'chart' && !s:pinpoint_has_sessions(id)
    echo 'no sessions logged yet for ' . id . ' — train it first (T)'
    return
  endif
  if a:action ==# 'learn' && !s:pinpoint_has_lesson(id)
    echo 'no lesson written for ' . id . ' yet'
    return
  endif

  call vimfluency#close_summary()
  if a:action ==# 'train'
    call vimfluency#start(id)
  elseif a:action ==# 'learn'
    call vimfluency#learn(id)
  elseif a:action ==# 'chart'
    call vimfluency#chart(id)
  endif
endfunction

" True if sessions.jsonl has at least one record for this pinpoint.
" Mirrors the filter vimfluency#chart uses to decide it has data.
function! s:pinpoint_has_sessions(id) abort
  let grouped = s:load_sessions_grouped()
  return has_key(grouped, a:id) && !empty(grouped[a:id])
endfunction

" True if the pinpoint module exports a #lesson() function.
function! s:pinpoint_has_lesson(id) abort
  let registry = vimfluency#discover_pinpoints()
  if !has_key(registry, a:id) | return 0 | endif
  return exists('*vimfluency#pinpoints#' . registry[a:id].module . '#lesson')
endfunction

" True when B would show something useful: either the last session has
" 2+ motions to break down, or the pinpoint declares at least one
" in-registry prereq whose status the user can drill into. A
" single-motion session with no prereqs just restates the row's
" last_rate, so B stays a no-op there.
function! s:pinpoint_has_breakdown(id) abort
  let registry = vimfluency#discover_pinpoints()
  let meta = get(registry, a:id, {})
  let prereqs = filter(copy(get(meta, 'prereqs', [])),
    \ 'has_key(registry, v:val)')
  let grouped = s:load_sessions_grouped()
  let pm = s:per_motion_from_sessions(get(grouped, a:id, []))
  return !empty(prereqs) || len(pm) >= 2
endfunction

" B toggles the breakdown for the pinpoint under the cursor — per-motion
" rates from the last session AND a prereq status sub-list. Rebuilds
" the whole buffer (cheap — a few dozen lines) with the expanded set
" updated, then restores the cursor to the same pinpoint.
function! vimfluency#list_toggle_breakdown() abort
  if !exists('b:vf_list_line_to_id') | return | endif
  let id = get(b:vf_list_line_to_id, line('.'), '')
  if empty(id)
    echo 'cursor must be on a pinpoint row'
    return
  endif
  if !has_key(b:vf_list_expanded, id) && !s:pinpoint_has_breakdown(id)
    echo 'nothing to break down for ' . id
      \ . ' (no prereqs, and no multi-motion session yet)'
    return
  endif
  if has_key(b:vf_list_expanded, id)
    call remove(b:vf_list_expanded, id)
  else
    let b:vf_list_expanded[id] = 1
  endif

  let registry = vimfluency#discover_pinpoints()
  let view = s:build_list_view(registry, s:load_sessions_grouped(),
    \ b:vf_list_expanded,
    \ get(b:, 'vf_list_sort_col', ''),
    \ get(b:, 'vf_list_sort_desc', 0))
  call s:apply_view(view)
  " Restore the cursor to the toggled pinpoint's main row.
  for row in b:vf_list_pinpoint_rows
    if get(b:vf_list_line_to_id, row, '') ==# id
      call cursor(row, 1)
      break
    endif
  endfor
endfunction

" Echo the sort keys when the user presses a bare `s`. Keeps the
" mapping legend discoverable without polluting the banner.
function! vimfluency#list_sort_help() abort
  echo 'Sort: sd=drill sc=commands sp=prereqs_n sa=aim sr=last_rate'
    \ . ' ss=last_session sn=runs sf=family   (repeat reverses; s<Space> resets)'
endfunction

" Apply a sort and rebuild the buffer. Empty col → reset to default
" family/depth/slug order. Same col as the current sort flips
" direction; a new col starts in ascending.
"
" Cursor stays on the SAME Nth pinpoint row across the resort — it
" does NOT follow the pinpoint id. So if you sort and your row's
" pinpoint moves to the bottom, the cursor stays put and the row
" underneath you changes.
function! vimfluency#list_sort(col) abort
  if !exists('b:vf_list_line_to_id') | return | endif

  " Find which Nth pinpoint row the cursor is on (or just past, when
  " sitting on a breakdown sub-row under that pinpoint).
  let cur_line = line('.')
  let cur_idx = -1
  for i in range(len(b:vf_list_pinpoint_rows))
    if b:vf_list_pinpoint_rows[i] <= cur_line
      let cur_idx = i
    else
      break
    endif
  endfor

  if empty(a:col)
    let b:vf_list_sort_col = ''
    let b:vf_list_sort_desc = 0
  elseif get(b:, 'vf_list_sort_col', '') ==# a:col
    let b:vf_list_sort_desc = !get(b:, 'vf_list_sort_desc', 0)
  else
    let b:vf_list_sort_col = a:col
    let b:vf_list_sort_desc = 0
  endif

  let registry = vimfluency#discover_pinpoints()
  let view = s:build_list_view(registry, s:load_sessions_grouped(),
    \ b:vf_list_expanded, b:vf_list_sort_col, b:vf_list_sort_desc)
  call s:apply_view(view)
  if cur_idx >= 0 && cur_idx < len(b:vf_list_pinpoint_rows)
    call cursor(b:vf_list_pinpoint_rows[cur_idx], 1)
  elseif !empty(b:vf_list_pinpoint_rows)
    call cursor(b:vf_list_pinpoint_rows[0], 1)
  endif
endfunction

" Rebuild the VfList buffer in place and keep the cursor on the same
" pinpoint id. Used after :A / :D updates so the user's eye stays on
" the row they just modified, even if the row moves under the current
" sort.
function! s:rebuild_list_buffer_keeping_pinpoint(id) abort
  let registry = vimfluency#discover_pinpoints()
  let view = s:build_list_view(registry, s:load_sessions_grouped(),
    \ b:vf_list_expanded,
    \ get(b:, 'vf_list_sort_col', ''),
    \ get(b:, 'vf_list_sort_desc', 0))
  call s:apply_view(view)
  for row in b:vf_list_pinpoint_rows
    if get(b:vf_list_line_to_id, row, '') ==# a:id
      call cursor(row, 1)
      return
    endif
  endfor
  if !empty(b:vf_list_pinpoint_rows)
    call cursor(b:vf_list_pinpoint_rows[0], 1)
  endif
endfunction

" A on a pinpoint row → prompt for an aim. Positive int sets the
" override; 0 (or empty Esc) cancels; if the user types 0 AND there's
" an existing override, it's cleared (so the same key handles set and
" reset without separate bindings).
function! vimfluency#list_set_aim() abort
  if !exists('b:vf_list_line_to_id') | return | endif
  let id = get(b:vf_list_line_to_id, line('.'), '')
  if empty(id)
    echo 'cursor must be on a pinpoint row'
    return
  endif
  let registry = vimfluency#discover_pinpoints()
  let meta = get(registry, id, {})
  let cur_aim = s:effective_aim(id, meta)
  let aims = get(s:load_settings(), 'aims', {})
  let is_overridden = has_key(aims, id)
  let tag = is_overridden ? 'overridden' : 'default'
  let prompt = printf('aim for %s [current %d/min, %s] (0 = reset, Esc = cancel): ',
    \ id, cur_aim, tag)
  let response = input(prompt)
  redraw
  if empty(response)
    echo 'cancelled'
    return
  endif
  if response !~# '^\d\+$'
    echo 'aim must be a non-negative integer (rate per minute)'
    return
  endif
  let rate = str2nr(response)
  if rate == 0
    if is_overridden
      call vimfluency#reset_aim(id)
    else
      echo 'no aim override set for ' . id
      return
    endif
  else
    call vimfluency#set_aim(id, response)
  endif
  call s:rebuild_list_buffer_keeping_pinpoint(id)
endfunction

" D → prompt for the global default duration. Same set/reset
" semantics as A: positive int sets, 0 resets when there's an
" override, Esc cancels. Display doesn't depend on duration so no
" rebuild needed.
function! vimfluency#list_set_duration() abort
  let cur_dur = s:effective_duration()
  let settings = s:load_settings()
  let is_overridden = has_key(settings, 'default_duration')
  let tag = is_overridden ? 'overridden' : 'built-in'
  let prompt = printf('default duration [current %ds, %s] (0 = reset, Esc = cancel): ',
    \ cur_dur, tag)
  let response = input(prompt)
  redraw
  if empty(response)
    echo 'cancelled'
    return
  endif
  if response !~# '^\d\+$'
    echo 'duration must be a non-negative integer (seconds)'
    return
  endif
  let secs = str2nr(response)
  if secs == 0
    if is_overridden
      call vimfluency#reset_duration()
    else
      echo 'no default duration override set'
    endif
  else
    call vimfluency#set_duration(response)
  endif
endfunction

function! vimfluency#start(...) abort
  if !empty(s:session)
    echo 'a session is already active; :VfQuit first'
    return
  endif

  " Parse positional args + kwargs (e.g. only=g_,^)
  let positional = []
  let kwargs = {}
  for arg in a:000
    let parts = split(arg, '=', 1)
    if len(parts) == 2
      let kwargs[parts[0]] = parts[1]
    else
      call add(positional, arg)
    endif
  endfor

  if empty(positional)
    echo 'usage: :Vf <id> [duration] [only=motion[,motion...]]'
    return
  endif
  let id = positional[0]
  " Duration precedence: explicit arg > user's global default > 60s.
  let duration = len(positional) >= 2
    \ ? str2nr(positional[1])
    \ : s:effective_duration()
  let only_filter = has_key(kwargs, 'only')
    \ ? filter(split(kwargs.only, ','), '!empty(v:val)') : []

  let registry = vimfluency#discover_pinpoints()
  if !has_key(registry, id)
    echo 'unknown pinpoint: ' . id . '  (try :VfList)'
    return
  endif
  let info = registry[id]

  let s:session = {
    \ 'mode': 'train',
    \ 'id': info.id,
    \ 'name': info.name,
    \ 'aim': s:effective_aim(info.id, info),
    \ 'module': info.module,
    \ 'kind': get(info, 'kind', 'motion'),
    \ 'credit_on_text_typed': get(info, 'credit_on_text_typed', 0),
    \ 'duration': duration,
    \ 'only_filter': only_filter,
    \ 'started_at': reltime(),
    \ 'items_correct': 0,
    \ 'items_skipped': 0,
    \ 'items_log': [],
    \ 'per_motion': {},
    \ 'total_motions': 0,
    \ 'total_optimal_motions': 0,
    \ 'current_item_motions': 0,
    \ 'current_item': {},
    \ 'item_started_at': reltime(),
    \ 'advancing': 0,
    \ 'target_match_id': -1,
    \ 'header_offset': 0,
    \ 'deletion_match_id': -1,
    \ 'waypoint_match_ids': [],
    \ 'prev_laststatus': &laststatus,
    \ 'prev_ttimeoutlen': &ttimeoutlen,
    \ }
  " ttimeoutlen is what gates how long vim waits after Esc / Ctrl+[
  " to see if a function-key sequence is starting. Default is 100ms
  " (newer vim) or -1=timeoutlen=1000ms (older). That delay is what
  " makes the to-Normal transition feel laggy in mode_switch — the
  " ModeChanged event can't fire until vim commits to interpreting
  " the byte as Esc. Drop it to 10ms during the session and restore
  " in vimfluency#stop.
  set ttimeoutlen=10

  call s:setup_window()
  call s:next_item()
  call s:install_autocmds()
  let s:session.timer = timer_start(200, function('s:on_tick'), {'repeat': -1})
endfunction

function! s:setup_window() abort
  tabnew
  let s:session.tabnr = tabpagenr()
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal list listchars=trail:·,nbsp:·
  " Predictable indent semantics for operators like >> and <<.
  " Override whatever the user has globally so training behavior is
  " consistent across vimrcs.
  setlocal shiftwidth=4 softtabstop=4 expandtab
  silent! execute 'keepalt file vf-' . s:session.id
  let &l:statusline = '%{vimfluency#statusline()}'
  set laststatus=2
  let s:session.you_win = win_getid()
endfunction

function! vimfluency#statusline() abort
  if empty(s:session) | return '' | endif
  let elapsed = reltimefloat(reltime(s:session.started_at))
  let remaining = max([0, s:session.duration - elapsed])
  let rate = elapsed > 0 ? s:session.items_correct * 60.0 / elapsed : 0.0
  let filter_tag = empty(get(s:session, 'only_filter', []))
    \ ? '' : ' [only=' . join(s:session.only_filter, ',') . ']'
  return printf(' %s — %s%s   time %ds   correct %d   rate %.1f/min   aim %d/min   [Tab=skip :VfQuit=quit]',
    \ s:session.id, s:session.name, filter_tag,
    \ float2nr(remaining), s:session.items_correct, rate, s:session.aim)
endfunction

function! s:next_item() abort
  let s:session.advancing = 1
  let GenFn = function('vimfluency#pinpoints#' . s:session.module . '#generate')
  let item = {}
  let attempts = 0
  let cur_canon = s:session.kind ==# 'mode_switch' ? s:mode_canonical(mode(1)) : ''
  while attempts < 100
    let item = GenFn()
    let filter_ok = empty(s:session.only_filter)
      \ || index(s:session.only_filter, get(item, 'expected_motion', '')) >= 0
    " mode_switch needs target != current (otherwise the user has
    " nothing to do, and we don't want the same target twice in a row).
    let mode_ok = s:session.kind !=# 'mode_switch'
      \ || get(item, 'target_mode_canon', '') !=# cur_canon
    if filter_ok && mode_ok
      break
    endif
    let attempts += 1
  endwhile
  if attempts >= 100
    let s:session.advancing = 0
    echo 'could not generate item matching only=' . join(s:session.only_filter, ',')
    call vimfluency#stop('filter_error')
    return
  endif
  let s:session.current_item = item
  let s:session.item_started_at = reltime()
  let s:session.current_item_motions = 0
  " Initial state for the dedupe guard in s:on_change. The deferred
  " CursorMoved that fires after our cursor() call below sees this
  " same state and is skipped as a duplicate. Subsequent presses
  " produce distinct states and increment the count.
  let s:session.last_event_state = [item.start, copy(item.lines)]

  " Recall and mode kinds have their own item-rendering paths; they share
  " bookkeeping with motion/editing but the buffer layout and credit
  " trigger differ enough that branching here is cleaner than a unified
  " render.
  if s:session.kind ==# 'recall'
    call s:render_recall_item(item)
    let s:session.advancing = 0
    return
  endif
  if s:session.kind ==# 'mode'
    call s:render_mode_item(item)
    let s:session.advancing = 0
    return
  endif
  if s:session.kind ==# 'mode_switch'
    call s:render_mode_switch_item(item)
    call s:start_mode_polling()
    let s:session.advancing = 0
    " Defensive synchronous re-check: covers the case where the
    " user is already in this item's target mode at render time and
    " no ModeChanged will fire. Routine path is a no-op (mode at
    " next_item time != next target by the no-repeat constraint).
    call s:check_mode_for_credit()
    return
  endif

  " Editing-kind training sessions get a 2-line header (prompt + divider) above the
  " live editing area. Match checks subtract the header offset.
  let header = []
  if s:session.kind ==# 'editing'
    let prompt = get(item, 'prompt', 'edit to match the target')
    let header = [prompt, repeat('─', 60)]
  endif
  " Waypoint annotation row sits at the END of the header (just above the
  " content) so the deferred-fire guard's cur_lines comparison still
  " excludes it via header_offset. Same scaffolding as in lessons —
  " training sessions need it too so the learner can disambiguate ; vs , scenarios
  " for items where cursor sits between two char occurrences.
  let header += s:waypoint_annotation(item)
  let s:session.header_offset = len(header)

  setlocal modifiable
  silent! %delete _
  if has_key(item, 'history') && !empty(item.history)
    " T0.4-style: pre-stage undo history so 'u' / Ctrl-r have somewhere
    " to go. The user's first keypress reverts (or re-applies) the
    " edit we just staged behind the scenes.
    call s:stage_undo_history(item, header)
  else
    call setline(1, header + item.lines)
  endif
  call cursor(s:session.header_offset + item.start[0], item.start[1])

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  " For editing-kind training sessions the deletion range alone tells the learner
  " what to do; rendering a green target makes the discrimination "is
  " green visible or not?" instead of "where is red relative to the
  " cursor?". Motion-kind training sessions still get the green cell since that's
  " the entire cue.
  if s:session.kind !=# 'editing'
    let s:session.target_match_id = matchaddpos('VfTarget',
      \ [[s:session.header_offset + item.target[0], item.target[1], 1]], 20)
  endif

  " Deletion-range highlight (editing training sessions that mark which characters
  " will be removed). Items declare deletion_range as a list of
  " [row, col, length] tuples (matchaddpos format, item-coords).
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
  if has_key(item, 'deletion_range') && !empty(item.deletion_range)
    let positions = []
    for pos in item.deletion_range
      call add(positions,
        \ [s:session.header_offset + pos[0], pos[1], pos[2]])
    endfor
    let s:session.deletion_match_id = matchaddpos('VfDeletion', positions, 10)
  endif

  call s:clear_waypoint_matches()
  call s:add_waypoint_matches(item)

  redrawstatus
  let s:session.advancing = 0
endfunction

function! s:install_autocmds() abort
  if s:session.kind ==# 'recall'
    " Recall kind drives input through buffer-local key maps, not
    " autocmds — there's no live "editing area" to watch. Tab still
    " skips, so the existing skip path stays consistent.
    call s:install_recall_maps()
    return
  endif
  if s:session.kind ==# 'mode_switch'
    " mode_switch credits the instant vim's mode changes. When
    " ModeChanged is available (8.2+) we hook it for sub-frame
    " latency; on 8.1 we fall back to s:start_mode_polling's 50ms
    " timer (kicked off from s:next_item). Tab still skips.
    "
    " CmdlineEnter is the only hook that fires while a target='c'
    " item is satisfiable — once the user is in cmdline mode,
    " timer/ModeChanged callbacks don't run until cmdline closes.
    " The handler credits synchronously and leaves the user in
    " cmdline so their Ctrl+[ keystroke fires the next item's
    " c:n credit honestly.
    "
    " The buffer-local cnoremap maps <CR> to <C-c> for the whole
    " session, so any text the user types in cmdline can't execute
    " as an ex command against the training buffer. Cleaned up
    " when the training buffer is wiped.
    augroup VfTrain
      autocmd!
      if exists('##ModeChanged')
        autocmd ModeChanged * call s:check_mode_for_credit()
      endif
      autocmd CmdlineEnter : call s:on_cmdline_enter_train()
    augroup END
    cnoremap <buffer> <CR> <C-c>
    nnoremap <buffer> <silent> <Tab> :call <SID>skip()<CR>
    return
  endif
  augroup VfTrain
    autocmd!
    if s:session.kind ==# 'mode'
      " Mode kind tracks the round trip through insert mode.
      " InsertEnter records WHERE insert was entered so we can
      " disambiguate i/a/I/A/o/O by column. We deliberately do NOT
      " hook TextChangedI by default: vim fires it as part of o/O's
      " line-insert sequence, which would inflate the motion count
      " by 1 for those keys (3 instead of optimal 2). The matcher
      " rejects any wrong buffer state on InsertLeave, so typing-
      " then-undo paths still penalize via failed credits.
      autocmd InsertEnter <buffer> call s:on_insert_enter()
      autocmd InsertLeave <buffer> call s:on_insert_leave()
      " Opt-in: when the pinpoint declares credit_on_text_typed,
      " the training credits the moment the buffer matches
      " target_lines_after_type (the post-typing target). The
      " learner doesn't have to press Esc — the leave-mode
      " keystroke is drilled separately in switch_mode_to_insert.
      " Each typed char fires TextChangedI so motion counting stays
      " honest. The o/O caveat above doesn't apply here because no
      " current credit_on_text_typed pinpoint uses o/O.
      if get(s:session, 'credit_on_text_typed', 0)
        autocmd TextChangedI <buffer> call s:on_text_changed_i()
      endif
    else
      autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI <buffer>
        \ call s:on_change()
    endif
  augroup END
  nnoremap <buffer> <silent> <Tab> :call <SID>skip()<CR>
  " Ctrl-C in vim is the interrupt key — it exits insert mode but
  " explicitly does NOT fire InsertLeave, by design. Real-world
  " users still reach for it as a faster Esc, so within training
  " buffers we route it through Esc so the matcher sees the round
  " trip. Applies to any kind that might enter insert mode (mode
  " kind, plus motion/editing kinds where the learner hit i/a/o by
  " mistake and needs out).
  inoremap <buffer> <silent> <C-c> <Esc>
endfunction

function! s:on_change() abort
  if empty(s:session) || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif

  let item = s:session.current_item
  let header_offset = s:session.header_offset
  let cur_pos = [line('.') - header_offset, col('.')]
  let cur_lines = getline(header_offset + 1, '$')
  let start_lines = item.lines
  let target_lines = get(item, 'target_lines', item.lines)

  " Dedupe by (cursor, buffer) state. Two cases collapse:
  "   1. The deferred CursorMoved that vim fires after our cursor()
  "      call in s:next_item — sees the same state we initialized
  "      last_event_state to, gets skipped.
  "   2. Operations that fire BOTH TextChanged and CursorMoved for
  "      the same press (e.g. >>, <<, dd — the buffer changes AND
  "      the cursor's column changes). Both events report the same
  "      final state, so only the first one increments the count.
  " Pure motions (j/w/...) and pure-text-no-cursor-move (x/dw at
  " start of line) fire only one event per press, so dedupe is a
  " no-op for them.
  let new_state = [cur_pos, cur_lines]
  if get(s:session, 'last_event_state', []) ==# new_state
    return
  endif
  let s:session.last_event_state = new_state

  let s:session.current_item_motions += 1

  if cur_lines ==# target_lines && cur_pos == item.target
    call s:credit_item()
  endif
endfunction

" Shared credit path. Recall and mode kinds call this directly when their
" own match logic decides the item is done; motion/editing call it from
" s:on_change. All counter bookkeeping lives here so the kinds stay
" symmetric in their stats.
function! s:credit_item() abort
  let item = s:session.current_item
  let s:session.items_correct += 1
  let elapsed = reltimefloat(reltime(s:session.item_started_at))
  let actual = s:session.current_item_motions
  let optimal = get(item, 'optimal_motions', 0)
  let motion = get(item, 'expected_motion', '')
  if !empty(motion)
    if !has_key(s:session.per_motion, motion)
      let s:session.per_motion[motion] = {
        \ 'correct': 0, 'time_total': 0.0,
        \ 'motions_total': 0, 'optimal_total': 0}
    endif
    let s:session.per_motion[motion].correct += 1
    let s:session.per_motion[motion].time_total += elapsed
    let s:session.per_motion[motion].motions_total += actual
    let s:session.per_motion[motion].optimal_total += optimal
  endif
  if optimal > 0
    let s:session.total_motions += actual
    let s:session.total_optimal_motions += optimal
  endif
  call add(s:session.items_log, {
    \ 'lines': item.lines,
    \ 'target_lines': get(item, 'target_lines', item.lines),
    \ 'start': item.start,
    \ 'target': item.target,
    \ 'expected_motion': motion,
    \ 'optimal_motions': optimal,
    \ 'actual_motions': actual,
    \ 'time_seconds': s:round3(elapsed),
    \ 'outcome': 'correct',
    \ })
  call s:next_item()
endfunction

" Stage a sequence of buffer states in the editing area, leaving
" the buffer's undo history primed so 'u' / Ctrl-r have somewhere
" to go. Used by T0.4 (undo / redo).
"
" Mechanics:
"   1. Write the FIRST state with undolevels=-1 so it isn't
"      recorded — that makes it the undo floor (no further u
"      below this point).
"   2. Write subsequent states one at a time, breaking the undo
"      node between each via `let &undolevels = &undolevels` so
"      each becomes its own undo entry.
"   3. Apply (len(history) - 1 - start_index) undos so the buffer
"      ends up at item.history[start_index] with undo+redo info
"      available in both directions.
function! s:stage_undo_history(item, header_lines) abort
  let history = a:item.history
  let save_ul = &undolevels
  setlocal undolevels=-1
  call setline(1, a:header_lines + history[0])
  let &undolevels = save_ul
  for state in history[1:]
    " Position cursor in the editing area BEFORE the setline so vim
    " records this position with the undo entry. Otherwise undo
    " would later restore the cursor to wherever the script happened
    " to leave it (typically buffer row 1, on the header), which
    " breaks the matcher's cur_pos == item.target check.
    call cursor(s:session.header_offset + 1, 1)
    call setline(s:session.header_offset + 1, state)
    let &undolevels = &undolevels
  endfor
  let undos_needed = (len(history) - 1)
    \ - get(a:item, 'start_index', len(history) - 1)
  for _ in range(undos_needed)
    silent! undo
  endfor
endfunction

" -----------------------------------------------------------------
" Recall kind — type the keystroke string that does X
" -----------------------------------------------------------------

" Build the line list and input_row for a recall item, given an
" optional pre-header (used by lessons to add their own status line
" above the recall area). Returns the [lines, input_row] tuple.
"
" Item fields:
"   prompt        — string or list, shown ABOVE the input
"   prompt_after  — string or list, shown DIRECTLY BELOW the input
"                   (used by T0.5 to render a mock vim screen with
"                   the input as the buffer's first line and the
"                   mode indicator at the buffer bottom).
"
" Layout:
"   <pre_header>
"   <prompt + blank>
"   <input row>
"   <prompt_after>           ← visually adjacent to input
"   <blank>
"   [BS=fix  Tab=skip  Esc=quit]
function! s:recall_compose(item, pre_header) abort
  let raw = get(a:item, 'prompt', '')
  let prompt_lines = type(raw) == type([])
    \ ? raw
    \ : (empty(raw) ? [] : [raw])
  let after_raw = get(a:item, 'prompt_after', '')
  let after_lines = type(after_raw) == type([])
    \ ? after_raw
    \ : (empty(after_raw) ? [] : [after_raw])

  let lines = copy(a:pre_header)
  if !empty(prompt_lines)
    call extend(lines, prompt_lines + [''])
  endif
  let input_row = len(lines) + 1
  call add(lines, '  > ')
  if !empty(after_lines)
    call extend(lines, after_lines)
  endif
  call extend(lines, ['', '  [BS=fix  Tab=skip  Esc=quit]'])
  return [lines, input_row]
endfunction

" Render a recall item. The buffer is pure UI: prompt at top, an input
" line marked '> ' that the keymap layer paints into. There's no live
" editing area — TextChanged/CursorMoved aren't wired for this kind.
function! s:render_recall_item(item) abort
  let s:session.recall_input = ''
  let [lines, input_row] = s:recall_compose(a:item, [])
  let s:session.input_row = input_row
  let s:session.input_prefix = '  > '
  setlocal modifiable
  silent! %delete _
  call setline(1, lines)
  call cursor(s:session.input_row, len(s:session.input_prefix) + 1)
  redrawstatus
endfunction

" Build the buffer-local key maps used during recall input. Every
" printable ASCII char (33-126) plus space is mapped to recall_append;
" BS corrects, Tab skips, Esc/Ctrl-C quit.
"
" Quit-key rationale: the recall layer captures ':' as typed input
" (since answers like ':wq' contain it), which means :VfQuit can't
" be typed inside the recall buffer. So we install Esc and Ctrl-C
" as buffer-local quit shortcuts.
function! s:install_recall_maps() abort
  " LHS escapes for keys vim's mapping parser treats specially in the
  " left-hand side. '<' must be <lt> (otherwise vim reads <Whatever>
  " as a key notation); '|' must be <bar> (otherwise it ends the
  " :nnoremap command).
  " RHS gotcha: a literal '<' inside the mapping body makes vim try to
  " parse a key notation (<CR>, <Esc>, ...). We dodge that entirely by
  " passing the char to recall_append() as nr2char(N) rather than the
  " literal character, so the RHS never contains '<' for char-mappings.
  let lhs_escape = {'<': '<lt>', '|': '<bar>'}
  for n in range(33, 126)
    let c = nr2char(n)
    let lhs = get(lhs_escape, c, c)
    let rhs = ':call <SID>recall_append(nr2char(' . n . '))<CR>'
    execute 'nnoremap <buffer> <silent> ' . lhs . ' ' . rhs
  endfor
  nnoremap <buffer> <silent> <Space> :call <SID>recall_append(' ')<CR>
  nnoremap <buffer> <silent> <BS> :call <SID>recall_backspace()<CR>
  nnoremap <buffer> <silent> <Tab> :call <SID>skip()<CR>
  nnoremap <buffer> <silent> <Esc> :call vimfluency#stop('user')<CR>
  nnoremap <buffer> <silent> <C-c> :call vimfluency#stop('user')<CR>
  " Block <CR>'s default (would jump the cursor to the next line).
  nnoremap <buffer> <silent> <CR> <Nop>
endfunction

" Recall input handlers work for both training and lesson sessions:
"   - training → motions accumulate to current_item_motions, credit via s:credit_item
"   - learn (setup) → frame_complete + s:learn_render_complete
"   - learn (test)  → motions accumulate to test_motion_count, streak update +
"                     s:learn_render_complete
" Show frames in lessons don't set input_row, so the input handlers
" silently no-op if a key fires before a try frame is active.

function! s:recall_append(c) abort
  if empty(s:session) || s:session.advancing | return | endif
  if !has_key(s:session, 'input_row') | return | endif
  let s:session.recall_input .= a:c
  call s:recall_increment_motions()
  call s:recall_repaint()
  call s:recall_check_match()
endfunction

function! s:recall_backspace() abort
  if empty(s:session) || s:session.advancing | return | endif
  if !has_key(s:session, 'input_row') | return | endif
  call s:recall_increment_motions()
  if !empty(s:session.recall_input)
    let s:session.recall_input = strpart(s:session.recall_input,
      \ 0, len(s:session.recall_input) - 1)
  endif
  call s:recall_repaint()
endfunction

function! s:recall_increment_motions() abort
  if get(s:session, 'mode', 'train') ==# 'train'
    let s:session.current_item_motions += 1
  elseif get(s:session, 'phase', '') ==# 'test'
    let s:session.test_motion_count += 1
  endif
endfunction

function! s:recall_repaint() abort
  setlocal modifiable
  call setline(s:session.input_row,
    \ s:session.input_prefix . s:session.recall_input)
  call cursor(s:session.input_row,
    \ len(s:session.input_prefix) + len(s:session.recall_input) + 1)
  " <silent> mappings can suppress the implicit redraw between
  " keystrokes; force one so the typed input shows immediately.
  redraw
endfunction

" Auto-credit on exact match. Saves a stand-alone <CR> "submit" — keeps
" the free-operant rhythm: no extra key between getting it right and
" the next item appearing. Within an item there's exactly one
" expected_answer, so prefix collisions across items don't apply.
function! s:recall_check_match() abort
  if get(s:session, 'frame_complete', 0) | return | endif

  let mode = get(s:session, 'mode', 'train')
  if mode ==# 'train'
    let item = s:session.current_item
  elseif s:session.phase ==# 'test'
    let item = s:session.current_test_item
  else
    let frame = s:session.frames[s:session.frame_idx]
    if frame.kind !=# 'try' | return | endif
    let item = frame
  endif

  let expected = get(item, 'expected_answer', '')
  if empty(expected) | return | endif
  if s:session.recall_input !=# expected | return | endif

  if mode ==# 'train'
    call s:credit_item()
    return
  endif

  " Learn: mark frame complete, update test-phase streak, repaint header.
  let s:session.frame_complete = 1
  if s:session.phase ==# 'test'
    let s:session.last_item_motions = s:session.test_motion_count
    let s:session.last_item_optimal = get(item, 'optimal_motions', 1)
    if s:session.last_item_motions <= s:session.last_item_optimal
      let s:session.streak += 1
      let s:session.wrongs = 0
    else
      let s:session.streak = 0
      let s:session.wrongs += 1
    endif
  endif
  call s:learn_render_complete()
endfunction

" -----------------------------------------------------------------
" Mode kind — round trip through insert mode
" -----------------------------------------------------------------

" Render a mode item. Layout mirrors editing kind (prompt + divider
" header above a small content area), but the content is the buffer
" the learner enters/leaves insert mode in. Item declares:
"   - lines, start, target, target_lines (post-Esc state)
"   - enter_at_row, enter_at_col (where InsertEnter must fire)
"   - expected_motion (i/a/I/A/o/O/...)
" Build the '▶◀' indicator row for a mode-kind item. Returns '' when
" the item shouldn't get the indicator (no enter_at_col, or
" hide_target opt-out — T0.2 sets this because its gap is between
" ROWS, not columns, so the column-based affordance is the wrong shape).
"
" Cue semantics (column-based insert-entries):
"   - cursor under ◀ → cursor is RIGHT of the seam → `i` (insert before)
"   - cursor under ▶ → cursor is LEFT of the seam  → `a` (append after)
"   - cursor far away, arrows near indent boundary → `I`
"   - cursor far away, arrows at end-of-line       → `A`
"
" No coloring on the content row — leaves the buffer visually clean.
" No trailing pad after ◀ — listchars=trail:· would otherwise render
" those spaces as dots and clutter the cue.
function! s:mode_gap_indicator(item) abort
  if !has_key(a:item, 'enter_at_col') || get(a:item, 'hide_target', 0)
    return ''
  endif
  let gap_right = a:item.enter_at_col
  let gap_left = max([gap_right - 1, 1])
  " gap_right - gap_left is 1 in every well-formed item (since
  " gap_left = enter_at_col - 1 unless that would underflow at 1).
  let between = repeat(' ', max([gap_right - gap_left - 1, 0]))
  return repeat(' ', gap_left - 1) . '▶' . between . '◀'
endfunction

" -----------------------------------------------------------------
" mode_switch kind — production training for mode changes
" -----------------------------------------------------------------
"
" Items declare a `target_mode_canon` ∈ {n, i, v, r, c}. The runner
" polls vim's mode() every 50ms; when the canonical mode matches the
" target, the item credits and the next item's target is generated
" with the no-repeat constraint (target != current mode).
"
" Why polling and not events: vim 8.1 (the project floor) doesn't
" have ModeChanged (8.2+). InsertEnter/InsertLeave only cover insert.
" There's no clean event for visual entry. Polling mode(1) is cheap
" — a string compare every 50ms — and covers all five modes
" uniformly.

" Map vim's mode(1) string to one of the five canonical labels.
" Visual character / line / block all collapse into 'v'; Replace and
" virtual-replace into 'r'; command-line variants into 'c'.
function! s:mode_canonical(raw) abort
  if empty(a:raw) | return 'n' | endif
  let c = a:raw[0]
  if c ==# 'i' | return 'i' | endif
  if c ==# 'R' | return 'r' | endif
  if c ==# 'c' | return 'c' | endif
  if c ==# 'v' || c ==# 'V' || c ==# "\<C-v>" | return 'v' | endif
  return 'n'
endfunction

function! s:mode_pretty(canon) abort
  return get({'n': 'NORMAL', 'i': 'INSERT', 'v': 'VISUAL',
    \ 'r': 'REPLACE', 'c': 'COMMAND'}, a:canon, 'NORMAL')
endfunction

function! s:render_mode_switch_item(item) abort
  let target = s:mode_pretty(get(a:item, 'target_mode_canon', 'n'))
  let lines = [
    \ '',
    \ '',
    \ '    Switch to ' . target . ' mode',
    \ '',
    \ '    (from a non-Normal mode, press <Esc> first)',
    \ '',
    \ ]
  let s:session.header_offset = 0
  setlocal modifiable
  " Overwrite in place rather than %delete + setline. The handler is
  " called from ModeChanged while the user is in the just-entered
  " mode (v / i / R / c). %delete invalidates Visual mode's selection
  " range and kicks vim back to Normal — which fires *another*
  " ModeChanged that credits the next (n-target) item too, advancing
  " to item 3 (another v-target) on a single 'v' keystroke. The user
  " sees an identical-looking screen and concludes 'nothing happened'.
  " setline keeps mode state intact across all four non-Normal modes.
  call setline(1, lines)
  if line('$') > len(lines)
    silent! execute (len(lines) + 1) . ',$delete _'
  endif
  call cursor(2, 1)
  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
  call s:clear_waypoint_matches()
  " Full :redraw, not :redrawstatus. The mode_switch path can call
  " into here from a CmdlineEnter autocmd (':' pressed → credit → next
  " item → this renderer), and vim won't repaint the buffer area
  " while cmdline is open without an explicit redraw. Without it,
  " the user sees the prior item's prompt frozen behind the cmdline,
  " has no signal that pressing : worked, and feels stuck.
  redraw
endfunction

" Start (or restart) the polling timer for the current mode_switch
" item. Stops any existing timer first so multiple items in a row
" don't accumulate timers. When ModeChanged is available (vim 8.2+),
" credit fires synchronously via that autocmd — no polling needed,
" and credit latency drops from ~25-50ms (timer phase) to ~0ms.
function! s:start_mode_polling() abort
  call s:stop_mode_polling()
  if exists('##ModeChanged') | return | endif
  let s:session.mode_poll_timer = timer_start(50,
    \ function('s:check_mode_for_credit'), {'repeat': -1})
endfunction

function! s:stop_mode_polling() abort
  if has_key(s:session, 'mode_poll_timer')
    call timer_stop(s:session.mode_poll_timer)
    unlet s:session.mode_poll_timer
  endif
endfunction

" Variadic so this works as both a timer callback (gets a timer id)
" and a ModeChanged autocmd handler (gets nothing). The args aren't
" used either way — we only ever read vim's current mode().
" CmdlineEnter handler — see s:install_autocmds. The instant the user
" presses ':' we credit the c-target item and LEAVE THE USER IN
" CMDLINE. They press Ctrl+[/<Esc>/<C-c> themselves to leave; that
" keystroke fires a c:n ModeChanged which credits the next item
" (always target='n' under the no-repeat constraint, since current
" mode is 'c' at next-item time). Net: user presses ':' then
" Ctrl+[, gets two honest credits, drills both keystrokes —
" exactly the pedagogy the pinpoint demands. The cnoremap that
" defangs <CR> in cmdline is session-wide (installed once in
" s:install_autocmds), not per-press.
function! s:on_cmdline_enter_train() abort
  if empty(s:session) | return | endif
  if get(s:session, 'advancing', 0) | return | endif
  let target = get(s:session.current_item, 'target_mode_canon', '')
  if target !=# 'c' | return | endif
  let s:session.current_item_motions = s:mode_switch_strokes('c')
  call s:credit_item()
endfunction

function! s:check_mode_for_credit(...) abort
  if empty(s:session) | return | endif
  if get(s:session, 'advancing', 0) | return | endif
  let canon = s:mode_canonical(mode(1))
  let target = get(s:session.current_item, 'target_mode_canon', '')
  if canon ==# target
    " current_item_motions for mode_switch is best-effort: we don't
    " hook each keystroke (would have to install per-key maps in
    " every mode). Charge 1 stroke if target == 'n' (just <Esc>) or
    " if previous mode was 'n' (one entry key); otherwise 2 strokes
    " (<Esc> + entry key). Mirrors the optimal_motions logic so the
    " per-motion breakdown stays honest.
    let s:session.current_item_motions = s:mode_switch_strokes(target)
    call s:credit_item()
  endif
endfunction

" Lesson CmdlineEnter handler — mirror of s:on_cmdline_enter_train,
" but routes into the lesson's frame_complete machinery. The session-
" wide cmap installed in s:learn_install_autocmds defangs <CR> so the
" user can stay in cmdline safely. They press Ctrl+[ themselves to
" leave; the c:n ModeChanged fires while frame_complete=1 (returns
" early), and the auto-advance timer that this credit schedules
" eventually renders the next (n-target) frame — where the auto-
" credit-on-render check in s:learn_show_frame fires because the
" user is already in Normal.
function! s:on_cmdline_enter_learn() abort
  if empty(s:session) | return | endif
  if get(s:session, 'advancing', 0) | return | endif
  if get(s:session, 'frame_complete', 0) | return | endif

  let target = ''
  if s:session.phase ==# 'test'
    let target = get(get(s:session, 'current_test_item', {}),
      \ 'target_mode_canon', '')
  elseif s:session.phase ==# 'setup'
    if s:session.frame_idx >= len(s:session.frames) | return | endif
    let frame = s:session.frames[s:session.frame_idx]
    if frame.kind !=# 'try' | return | endif
    let target = get(frame, 'target_mode_canon', '')
  endif
  if target !=# 'c' | return | endif

  call s:check_mode_for_learn_credit()
endfunction

" Lesson polling: parallel to s:check_mode_for_credit but routes credit
" into the lesson's frame_complete + streak machinery instead of
" s:credit_item. Also schedules a brief auto-advance so the user
" doesn't have to <Esc>+Space their way out of every credited frame.
function! s:check_mode_for_learn_credit(...) abort
  if empty(s:session) | return | endif
  if get(s:session, 'advancing', 0) | return | endif
  if get(s:session, 'frame_complete', 0) | return | endif

  let target = ''
  if s:session.phase ==# 'test'
    let target = get(get(s:session, 'current_test_item', {}),
      \ 'target_mode_canon', '')
  elseif s:session.phase ==# 'setup'
    if s:session.frame_idx >= len(s:session.frames) | return | endif
    let frame = s:session.frames[s:session.frame_idx]
    if frame.kind !=# 'try' | return | endif
    let target = get(frame, 'target_mode_canon', '')
  endif
  if empty(target) | return | endif

  let canon = s:mode_canonical(mode(1))
  if canon !=# target | return | endif

  let strokes = s:mode_switch_strokes(target)
  if s:session.phase ==# 'test'
    let s:session.test_motion_count += strokes
    let s:session.last_item_motions = strokes
    let s:session.last_item_optimal = get(s:session.current_test_item,
      \ 'optimal_motions', 1)
    if s:session.last_item_motions <= s:session.last_item_optimal
      let s:session.streak += 1
    else
      let s:session.streak = 0
      let s:session.wrongs += 1
    endif
  endif
  let s:session.frame_complete = 1
  call s:learn_render_complete()
  " Auto-advance after a brief pause. Without this, the user would
  " have to <Esc> back to Normal and press Space — but they may
  " already be in a non-Normal mode where Space types into the
  " buffer instead of advancing. The Space mapping still works in
  " Normal mode for the impatient.
  call s:stop_learn_auto_advance()
  let s:session.learn_auto_advance_timer = timer_start(600,
    \ function('s:learn_mode_switch_auto_advance'))
endfunction

function! s:learn_mode_switch_auto_advance(timer) abort
  if empty(s:session) | return | endif
  if get(s:session, 'phase', '') ==# 'complete' | return | endif
  if !get(s:session, 'frame_complete', 0) | return | endif
  call s:learn_next()
endfunction

function! s:stop_learn_auto_advance() abort
  if has_key(s:session, 'learn_auto_advance_timer')
    call timer_stop(s:session.learn_auto_advance_timer)
    unlet s:session.learn_auto_advance_timer
  endif
endfunction

" Optimal strokes for a mode_switch item based on the CURRENT mode at
" the time of credit. Always at least 1. Caveat: this is "optimal given
" the actual transition," not what the user pressed — they can't
" register inflated strokes because we don't track each keypress.
"
" prev (s:session.mode_switch_prev) MUST be updated unconditionally so
" the NEXT item reads the right starting mode. Earlier bug: returning
" 1 for target=='n' WITHOUT updating prev left prev stuck at the
" prior non-Normal target, so the next non-Normal item saw prev !=
" 'n' and returned 2 — even though the user was actually in Normal.
function! s:mode_switch_strokes(target) abort
  let prev = get(s:session, 'mode_switch_prev', 'n')
  let s:session.mode_switch_prev = a:target
  if a:target ==# 'n' | return 1 | endif
  return prev ==# 'n' ? 1 : 2
endfunction

function! s:render_mode_item(item) abort
  let s:session.insert_entered = 0
  let s:session.insert_enter_pos = []
  let prompt = get(a:item, 'prompt', 'enter insert mode and leave again')
  let header = [prompt, repeat('─', 60)]

  let indicator = s:mode_gap_indicator(a:item)
  if !empty(indicator)
    call add(header, indicator)
  endif

  let header += s:waypoint_annotation(a:item)
  let s:session.header_offset = len(header)

  setlocal modifiable
  silent! %delete _
  call setline(1, header + a:item.lines)
  call cursor(s:session.header_offset + a:item.start[0], a:item.start[1])

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
  call s:clear_waypoint_matches()
  call s:add_waypoint_matches(a:item)
  redrawstatus
endfunction

" InsertEnter records the row+col where insert was actually entered.
" That's what disambiguates i (start col) from a (start col + 1) from
" I (first non-blank) from A (line end + 1) from o/O (col 1 of new line).
function! s:on_insert_enter() abort
  if empty(s:session) || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif
  let header_offset = s:session.header_offset
  let s:session.insert_entered = 1
  let s:session.insert_enter_pos = [line('.') - header_offset, col('.')]
  let s:session.current_item_motions += 1
  " Arm a one-shot guard for the credit_on_text_typed TextChangedI
  " handler. o/O fire both InsertEnter AND a TextChangedI for the
  " line they auto-insert; without the guard that TextChangedI
  " would be counted as a stroke and credited against optimal.
  let s:session.first_text_change_pending = 1
endfunction

" InsertLeave fires the match check. Success = entered insert at the
" right place AND buffer matches target_lines AND cursor lands at item.target
" once we're back in normal mode. Wrong attempts don't auto-fail (free
" operant); the learner can keep trying — the runner just resets the
" insert_entered flag so a fresh round trip can be evaluated.
function! s:on_insert_leave() abort
  if empty(s:session) || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif
  if !get(s:session, 'insert_entered', 0) | return | endif
  let s:session.current_item_motions += 1
  " For credit_on_text_typed pinpoints, credit is exclusively the
  " TextChangedI handler's job — pressing Esc without typing the
  " expected payload is a wrong attempt. Reset for retry; the
  " motion increment above already billed the leave.
  if get(s:session, 'credit_on_text_typed', 0)
    let s:session.insert_entered = 0
    let s:session.insert_enter_pos = []
    return
  endif
  let item = s:session.current_item
  let header_offset = s:session.header_offset
  let cur_pos = [line('.') - header_offset, col('.')]
  let cur_lines = getline(header_offset + 1, '$')
  let target_lines = get(item, 'target_lines', item.lines)

  let entered_correct = s:session.insert_enter_pos
    \ == [item.enter_at_row, item.enter_at_col]
  let buffer_correct = cur_lines ==# target_lines
  let cursor_correct = cur_pos == item.target

  if entered_correct && buffer_correct && cursor_correct
    call s:credit_item()
  else
    " Reset for retry. Free-operant: the learner stays in control of
    " when the next item appears.
    let s:session.insert_entered = 0
    let s:session.insert_enter_pos = []
  endif
endfunction

" Training TextChangedI handler — fires after every keystroke while
" in insert mode for pinpoints with credit_on_text_typed set. Mirrors
" s:learn_on_text_changed_i, but routes credit through s:credit_item.
" Per-char motion counting keeps the rate honest: a clean i+foo run
" = 1 (InsertEnter) + 3 (TextChangedI per char) = 4 strokes.
function! s:on_text_changed_i() abort
  if empty(s:session) || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif
  if !get(s:session, 'insert_entered', 0) | return | endif
  let item = s:session.current_item
  let target = get(item, 'target_lines_after_type',
    \ get(item, 'target_lines', []))
  if empty(target) | return | endif

  let header_offset = s:session.header_offset
  let cur_lines = getline(header_offset + 1, '$')
  " Guard: the FIRST TextChangedI after InsertEnter may be vim's
  " line-insert from a line-opening entry key (o/O), not a user-
  " typed char. Detect via cur_lines matching the pre-typing target
  " (item.target_lines, which o/O generators set to lines+blank).
  " For i/a/I/A items target_lines == lines and the buffer post-
  " first-typed-char never matches, so the guard is a no-op.
  let pending = get(s:session, 'first_text_change_pending', 0)
  let s:session.first_text_change_pending = 0
  if pending && cur_lines ==# get(item, 'target_lines', [])
    return
  endif
  let s:session.current_item_motions += 1
  if cur_lines !=# target | return | endif
  " Cheat-defense: the InsertEnter column must match what the
  " expected entry key produces.
  if has_key(item, 'enter_at_row') && has_key(item, 'enter_at_col')
    if s:session.insert_enter_pos != [item.enter_at_row, item.enter_at_col]
      return
    endif
  endif

  call s:credit_item()
  " Drop the learner back to Normal so the next item renders cleanly.
  " 'i' flag inserts Esc at the *start* of the typeahead buffer, so it
  " preempts any chars the learner over-typed in their reaction window.
  call feedkeys("\<Esc>", 'ni')
  " credit_item already rendered the new item and placed the cursor
  " at item.start, but that cursor() call ran while we were still in
  " insert mode. Vim's post-Esc shift then moves the cursor 1 left
  " (because in Normal the cursor sits ON a char rather than between
  " them), so the learner sees the next item with the cursor in the
  " wrong column. Re-position via a 0-timer that fires AFTER the
  " queued Esc has been processed.
  call timer_start(0, function('s:repos_cursor_post_esc'))
endfunction

function! s:repos_cursor_post_esc(...) abort
  if empty(s:session) | return | endif
  let item = get(s:session, 'current_item', {})
  if !has_key(item, 'start') | return | endif
  call cursor(s:session.header_offset + item.start[0], item.start[1])
endfunction

function! s:skip() abort
  if empty(s:session) || s:session.advancing | return | endif
  let item = s:session.current_item
  let s:session.items_skipped += 1
  let actual = s:session.current_item_motions
  let optimal = get(item, 'optimal_motions', 0)
  if optimal > 0
    let s:session.total_motions += actual
    let s:session.total_optimal_motions += optimal
  endif
  call add(s:session.items_log, {
    \ 'lines': item.lines,
    \ 'target_lines': get(item, 'target_lines', item.lines),
    \ 'start': item.start,
    \ 'target': item.target,
    \ 'expected_motion': get(item, 'expected_motion', ''),
    \ 'optimal_motions': optimal,
    \ 'actual_motions': actual,
    \ 'time_seconds': s:round3(reltimefloat(reltime(s:session.item_started_at))),
    \ 'outcome': 'skipped',
    \ })
  call s:next_item()
endfunction

function! s:on_tick(timer) abort
  if empty(s:session) | return | endif
  let elapsed = reltimefloat(reltime(s:session.started_at))
  if elapsed >= s:session.duration
    call vimfluency#stop('time')
    return
  endif
  if win_getid() == s:session.you_win
    redrawstatus
  endif
endfunction

function! vimfluency#stop(reason) abort
  if empty(s:session) | return | endif
  if get(s:session, 'mode', 'train') ==# 'learn'
    call vimfluency#learn_stop()
    return
  endif
  if has_key(s:session, 'timer')
    call timer_stop(s:session.timer)
  endif
  call s:stop_mode_polling()
  silent! augroup VfTrain | autocmd! | augroup END

  let elapsed = min([reltimefloat(reltime(s:session.started_at)), s:session.duration * 1.0])
  let rate = elapsed > 0 ? s:session.items_correct * 60.0 / elapsed : 0.0

  " Per-motion summary: items_correct(motion) × 60 / sum_of_time(motion)
  " gives the intrinsic rate of each motion. avg_motions tracks how many
  " CursorMoved events the item took on average — > optimal × 1.5 = noisy.
  let per_motion_out = {}
  let max_motion_rate = 0.0
  for [motion, stats] in items(s:session.per_motion)
    let mrate = stats.time_total > 0 ? stats.correct * 60.0 / stats.time_total : 0.0
    let avg_m = stats.correct > 0 ? stats.motions_total * 1.0 / stats.correct : 0.0
    let avg_o = stats.correct > 0 ? stats.optimal_total * 1.0 / stats.correct : 0.0
    let per_motion_out[motion] = {
      \ 'correct': stats.correct,
      \ 'time_seconds': s:round3(stats.time_total),
      \ 'rate_per_min': s:round3(mrate),
      \ 'avg_motions': s:round3(avg_m),
      \ 'avg_optimal': s:round3(avg_o),
      \ }
    if mrate > max_motion_rate | let max_motion_rate = mrate | endif
  endfor

  " Wasted motions = total - optimal (clamped). This is the SCC errors line.
  let wasted = max([0, s:session.total_motions - s:session.total_optimal_motions])
  let errors_per_min = elapsed > 0 ? wasted * 60.0 / elapsed : 0.0
  let efficiency_pct = s:session.total_motions > 0
    \ ? s:session.total_optimal_motions * 100.0 / s:session.total_motions : 0.0

  let record = {
    \ 'timestamp': strftime('%Y-%m-%dT%H:%M:%S'),
    \ 'pinpoint_id': s:session.id,
    \ 'pinpoint_name': s:session.name,
    \ 'aim': s:session.aim,
    \ 'duration_seconds': s:session.duration,
    \ 'elapsed_seconds': s:round3(elapsed),
    \ 'items_correct': s:session.items_correct,
    \ 'items_skipped': s:session.items_skipped,
    \ 'frequency_per_min': s:round3(rate),
    \ 'errors_per_min': s:round3(errors_per_min),
    \ 'total_motions': s:session.total_motions,
    \ 'total_optimal_motions': s:session.total_optimal_motions,
    \ 'efficiency_pct': s:round3(efficiency_pct),
    \ 'end_reason': a:reason,
    \ 'only_filter': s:session.only_filter,
    \ 'per_motion': per_motion_out,
    \ 'items': s:session.items_log,
    \ }
  call writefile([json_encode(record)], vimfluency#log_dir() . '/sessions.jsonl', 'a')

  " Build summary as buffer lines (avoids vim's "press ENTER" gate
  " that hits when too many :echo lines fire at once).
  let aim = s:session.aim
  let only_tag = empty(s:session.only_filter)
    \ ? '' : ' [only=' . join(s:session.only_filter, ',') . ']'
  let lines = []
  call add(lines, printf('── %s — %s%s ──',
    \ record.pinpoint_id, record.pinpoint_name, only_tag))
  call add(lines, '')
  call add(lines, printf('  duration:  %ss', string(record.elapsed_seconds)))
  call add(lines, printf('  correct:   %d', record.items_correct))
  call add(lines, printf('  skipped:   %d', record.items_skipped))
  call add(lines, printf('  rate:      %s/min   aim %d/min',
    \ string(record.frequency_per_min), aim))
  if rate >= aim
    call add(lines, '  AT AIM')
  elseif rate > 0
    call add(lines, printf('  gap:       %.1f/min  (%.1fx current rate)',
      \ aim - rate, aim / rate))
  endif
  call add(lines, printf('  errors:    %s/min   (wasted motions; SCC errors line)',
    \ string(s:round3(errors_per_min))))
  if s:session.total_optimal_motions > 0
    call add(lines, printf('  efficiency: %d%%        (%d motions for %d optimal)',
      \ float2nr(efficiency_pct),
      \ s:session.total_motions, s:session.total_optimal_motions))
  endif
  if !empty(per_motion_out)
    call add(lines, '')
    call add(lines, '  per motion:')
    for motion in sort(keys(per_motion_out))
      let m = per_motion_out[motion]
      let slow = (max_motion_rate > 0 && m.rate_per_min < max_motion_rate * 0.5)
      let noisy = (m.avg_optimal > 0 && m.avg_motions > m.avg_optimal * 1.5)
      let marks = []
      if slow | call add(marks, 'slow') | endif
      if noisy | call add(marks, 'noisy') | endif
      let marker = empty(marks) ? '' : '   ← ' . join(marks, ' + ')
      call add(lines, printf('    %-4s  %3d items   %5.1f/min   %.1f avg motions%s',
        \ motion, m.correct, m.rate_per_min, m.avg_motions, marker))
    endfor
  endif
  call add(lines, '')
  call add(lines, '  logged: ' . vimfluency#log_dir() . '/sessions.jsonl')
  call add(lines, '')
  call add(lines, '  Next:  C = open :VfChart  ·  L = back to :VfList  ·  q/<Enter> = close')

  " Render into the (still-open) training buffer; user dismisses explicitly.
  let prev_laststatus = s:session.prev_laststatus
  let prev_ttimeoutlen = get(s:session, 'prev_ttimeoutlen', &ttimeoutlen)
  let tabnr = s:session.tabnr
  let target_id = s:session.target_match_id
  let deletion_id = s:session.deletion_match_id
  let waypoint_ids = get(s:session, 'waypoint_match_ids', [])
  let you_win = get(s:session, 'you_win', 0)
  let s:session = {}

  if you_win > 0 && win_id2win(you_win) > 0
    call win_gotoid(you_win)
    if target_id != -1
      silent! call matchdelete(target_id)
    endif
    for wid in waypoint_ids
      silent! call matchdelete(wid)
    endfor
    if deletion_id != -1
      silent! call matchdelete(deletion_id)
    endif
    setlocal modifiable
    silent! %delete _
    call setline(1, lines)
    setlocal nomodifiable nomodified
    silent! execute 'keepalt file vf-summary-' . record.pinpoint_id
    " Force back to Normal so q/L/C bindings fire regardless of which
    " mode the user was in when the timer expired. <C-\><C-n> is vim's
    " universal "to Normal from anywhere" sequence.
    silent! call feedkeys("\<C-\>\<C-n>", 'n')
    let &l:statusline = ' session ended  [C=Chart  L=List  q=close]'
    let b:vf_summary_tabnr = tabnr
    let b:vf_summary_prev_laststatus = prev_laststatus
    let b:vf_summary_prev_ttimeoutlen = prev_ttimeoutlen
    " Remember which pinpoint this summary is for so C can open the
    " right chart. L just opens :VfList — no pinpoint context needed.
    let b:vf_summary_pinpoint_id = record.pinpoint_id
    nnoremap <buffer> <silent> q :call vimfluency#close_summary()<CR>
    nnoremap <buffer> <silent> <CR> :call vimfluency#close_summary()<CR>
    nnoremap <buffer> <silent> C :call vimfluency#summary_action('chart')<CR>
    nnoremap <buffer> <silent> L :call vimfluency#summary_action('list')<CR>
    call cursor(1, 1)
  else
    " training window/tab is gone — fall back to echoing
    silent! execute 'tabclose ' . tabnr
    let &laststatus = prev_laststatus
    let &ttimeoutlen = prev_ttimeoutlen
    for line in lines
      echo line
    endfor
  endif
endfunction

function! vimfluency#close_summary() abort
  if exists('b:vf_summary_tabnr')
    let tabnr = b:vf_summary_tabnr
    let prev_ls = b:vf_summary_prev_laststatus
    let prev_ttl = get(b:, 'vf_summary_prev_ttimeoutlen', &ttimeoutlen)
    silent! execute 'tabclose ' . tabnr
    let &laststatus = prev_ls
    let &ttimeoutlen = prev_ttl
  endif
endfunction

" Post-session shortcuts: from the summary, jump straight to the
" celeration chart for the pinpoint you just trained, or back to
" :VfList. Closes the summary tab first so we don't leave it behind.
function! vimfluency#summary_action(action) abort
  let id = get(b:, 'vf_summary_pinpoint_id', '')
  call vimfluency#close_summary()
  if a:action ==# 'chart' && !empty(id)
    call vimfluency#chart(id)
  elseif a:action ==# 'list'
    call vimfluency#list()
  endif
endfunction

function! s:rate_bar(rate, aim) abort
  let width = 20
  if a:aim <= 0 | return '[' . repeat(' ', width) . ']' | endif
  let frac = a:rate * 1.0 / a:aim
  if frac >= 1.0
    return '[' . repeat('*', width) . ']'
  endif
  let filled = float2nr(frac * width)
  return '[' . repeat('=', filled) . repeat(' ', width - filled) . ']'
endfunction

function! vimfluency#history(...) abort
  let filter_id = a:0 >= 1 ? a:1 : ''
  let log_path = vimfluency#log_dir() . '/sessions.jsonl'
  if !filereadable(log_path)
    echo 'no sessions logged yet (' . log_path . ')'
    return
  endif

  let records = []
  for line in readfile(log_path)
    if empty(line) | continue | endif
    try
      call add(records, json_decode(line))
    catch
      " skip malformed line
    endtry
  endfor

  if !empty(filter_id)
    call filter(records, 'v:val.pinpoint_id ==# filter_id')
    if empty(records)
      echo 'no sessions for pinpoint ' . filter_id
      return
    endif
  endif

  if empty(records)
    echo 'no sessions logged yet'
    return
  endif

  " group by pinpoint_id, chronological order preserved (file is append-only)
  let groups = {}
  let order = []
  for r in records
    if !has_key(groups, r.pinpoint_id)
      let groups[r.pinpoint_id] = []
      call add(order, r.pinpoint_id)
    endif
    call add(groups[r.pinpoint_id], r)
  endfor

  echo printf('vimfluency history — %d session(s) across %d pinpoint(s)',
    \ len(records), len(groups))
  for pid in sort(order)
    let g = groups[pid]
    let aim = g[0].aim
    let name = g[0].pinpoint_name
    let n = len(g)
    let first_rate = g[0].frequency_per_min
    let last_rate = g[-1].frequency_per_min

    let header = printf(' %s — %s   aim %d/min   n=%d', pid, name, aim, n)
    if n >= 2 && first_rate > 0
      let mult = last_rate / first_rate
      let header .= printf('   first→last ×%.2f', mult)
    endif
    echo ''
    echo header
    for r in g
      let ts = substitute(r.timestamp, 'T', ' ', '')
      echo printf('   %s  %5.1f/min  %s  correct %2d  skipped %d',
        \ ts, r.frequency_per_min,
        \ s:rate_bar(r.frequency_per_min, aim),
        \ r.items_correct, r.items_skipped)
    endfor
  endfor
endfunction

" -----------------------------------------------------------------
" Lesson mode (DI-style example/non-example sequencing before a training)
" -----------------------------------------------------------------

function! vimfluency#learn(...) abort
  if !empty(s:session)
    echo 'a session is already active; :VfQuit first'
    return
  endif
  if a:0 < 1
    echo 'usage: :VfLearn <pinpoint_id>'
    return
  endif
  let id = a:1
  let registry = vimfluency#discover_pinpoints()
  if !has_key(registry, id)
    echo 'unknown pinpoint: ' . id
    return
  endif
  let info = registry[id]
  let lesson_fn = 'vimfluency#pinpoints#' . info.module . '#lesson'
  if !exists('*' . lesson_fn)
    echo 'no lesson written for ' . id . ' yet'
    return
  endif
  let LessonFn = function(lesson_fn)
  let frames = LessonFn()
  if empty(frames)
    echo 'lesson is empty'
    return
  endif

  let s:session = {
    \ 'mode': 'learn',
    \ 'id': info.id,
    \ 'name': info.name,
    \ 'module': info.module,
    \ 'kind': get(info, 'kind', 'motion'),
    \ 'credit_on_text_typed': get(info, 'credit_on_text_typed', 0),
    \ 'frames': frames,
    \ 'frame_idx': 0,
    \ 'frame_complete': 0,
    \ 'phase': 'setup',
    \ 'streak': 0,
    \ 'test_sequence': get(info, 'test_sequence', []),
    \ 'test_seq_idx': 0,
    \ 'required_streak':
    \   empty(get(info, 'test_sequence', []))
    \     ? 3 : 3 * len(get(info, 'test_sequence', [])),
    \ 'max_test_items':
    \   empty(get(info, 'test_sequence', []))
    \     ? 20 : max([20, 5 * len(get(info, 'test_sequence', []))]),
    \ 'max_wrongs': 3,
    \ 'test_items_seen': 0,
    \ 'wrongs': 0,
    \ 'test_motion_count': 0,
    \ 'last_item_motions': 0,
    \ 'last_item_optimal': 0,
    \ 'current_test_item': {},
    \ 'prev_laststatus': &laststatus,
    \ 'prev_ttimeoutlen': &ttimeoutlen,
    \ 'target_match_id': -1,
    \ 'deletion_match_id': -1,
    \ 'waypoint_match_ids': [],
    \ 'advancing': 0,
    \ }
  " See vimfluency#start: drop ttimeoutlen so Esc / Ctrl+[ commit
  " quickly. Restored in vimfluency#learn_stop. Without this the
  " mode_switch lesson's to-Normal try frames feel laggy compared
  " to to-Insert / to-Visual / to-Cmd transitions.
  set ttimeoutlen=10

  call s:learn_setup_window()
  call s:learn_show_frame()
  call s:learn_install_autocmds()
endfunction

function! s:learn_setup_window() abort
  tabnew
  let s:session.tabnr = tabpagenr()
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal list listchars=trail:·,nbsp:·
  setlocal shiftwidth=4 softtabstop=4 expandtab
  silent! execute 'keepalt file vf-lesson-' . s:session.id
  let s:session.you_win = win_getid()
endfunction

" Build the lesson header line dynamically. Reads s:session.frame_complete
" so the same function works both for initial render and the post-success
" "✓ Press <Space>" update. Test phase has its own format (streak counter
" + ✓/✗ feedback).
function! s:learn_header_line() abort
  if s:session.phase ==# 'test'
    let cur = s:session.streak
    let req = s:session.required_streak
    let kind = get(s:session, 'kind', 'motion')
    if s:session.frame_complete
      if s:session.last_item_motions <= s:session.last_item_optimal
        if s:session.streak >= s:session.required_streak
          let hint = printf('✓ %d/%d streak!  [Space=start training]',
            \ cur, req)
        else
          let hint = printf('✓ %d motion(s)  streak %d/%d  [Space=next]',
            \ s:session.last_item_motions, cur, req)
        endif
      else
        let hint = printf('✗ %d motions, expected %d  streak reset to 0  [Space=next]',
          \ s:session.last_item_motions, s:session.last_item_optimal)
      endif
    else
      if kind ==# 'mode'
        let goal = 'enter insert at the gap, then Esc'
      elseif kind ==# 'mode_switch'
        let goal = 'change into the prompted mode'
      elseif kind ==# 'recall'
        let goal = 'type the keystrokes for the prompt'
      else
        let goal = 'reach the green cell, fewest keystrokes'
      endif
      let hint = printf('streak %d/%d  [%s]', cur, req, goal)
      if kind ==# 'editing'
        let hint .= '  [u=undo if wrong]'
      endif
    endif
    let quit_hint = kind ==# 'recall' ? '[Esc=quit]' : '[q=quit]'
    return printf('LESSON %s  TEST  %s  %s', s:session.id, hint, quit_hint)
  endif

  let frame = s:session.frames[s:session.frame_idx]
  let total = len(s:session.frames)
  let idx = s:session.frame_idx + 1
  let kind = get(s:session, 'kind', 'motion')
  if s:session.frame_complete
    let hint = '✓ correct  [Space=next]'
  elseif frame.kind ==# 'show'
    let hint = '[Space=next]'
  else
    if kind ==# 'mode'
      let hint = '[enter insert at the gap, then Esc]'
    elseif kind ==# 'mode_switch'
      let hint = '[change into the prompted mode]'
    elseif kind ==# 'recall'
      let hint = '[type the keystrokes for the prompt]'
    else
      let hint = '[reach the green cell]'
    endif
    if kind ==# 'editing'
      let hint .= '  [u=undo if wrong]'
    endif
  endif
  let quit_hint = kind ==# 'recall' ? '[Esc=quit]' : '[q=quit]'
  return printf('LESSON %s  SETUP %d/%d  %s  %s',
    \ s:session.id, idx, total, hint, quit_hint)
endfunction

function! s:learn_show_frame() abort
  let s:session.advancing = 1
  let s:session.frame_complete = 0
  " Mode-kind insert-tracking state, reset at every new frame. Training
  " path resets these in s:render_mode_item; lesson path mirrors here.
  let s:session.insert_entered = 0
  let s:session.insert_enter_pos = []
  " Recall input-row state. unlet first so show frames don't accept
  " stray keystrokes from a prior try frame; try frames re-set it.
  if has_key(s:session, "input_row") | unlet s:session.input_row | endif
  let frame = s:session.frames[s:session.frame_idx]
  let kind = get(s:session, 'kind', 'motion')
  let is_mode = kind ==# 'mode'
  let is_mode_switch = kind ==# 'mode_switch'
  let is_recall = kind ==# 'recall'

  " prompt may be a string or a list of lines — multi-line lets a
  " pinpoint wrap long instructions at a readable width instead of
  " forcing a horizontal scroll.
  let prompt_lines = type(frame.prompt) == v:t_list
    \ ? copy(frame.prompt) : [frame.prompt]
  let base_header = [s:learn_header_line(), ''] + prompt_lines + ['']

  if is_mode_switch
    " mode_switch lessons: header + prompt + (for try frames) a
    " "switch to MODE" line that the polling timer will match
    " against. show frames are just static rule statements with no
    " target_mode_canon.
    let body = []
    if frame.kind ==# 'try'
      let body = ['    Switch to '
        \ . s:mode_pretty(get(frame, 'target_mode_canon', 'n')) . ' mode',
        \ '',
        \ '    (from a non-Normal mode, press <Esc> first)']
    endif
    let s:session.header_offset = len(base_header)
    setlocal modifiable
    " Overwrite in place. %delete would invalidate Visual mode's
    " selection range if the user is still in visual when we re-render
    " (auto-advance timer fires while they're sitting in 'v' after a
    " just-credited v-frame). That invalidation kicks vim to Normal,
    " which then makes the auto-credit-on-render below fire for the
    " *next* (n-target) frame too — the user sees the v-frame credit
    " then immediately a "skip" through Normal. Same root cause as
    " s:render_mode_switch_item in the training path.
    let new_lines = base_header + body
    call setline(1, new_lines)
    if line('$') > len(new_lines)
      silent! execute (len(new_lines) + 1) . ',$delete _'
    endif
    " Park the cursor near the top of the prompt; insert/visual entry
    " keys typed by the user start from here.
    call cursor(min([len(base_header) + 1, line('$')]), 1)
    if s:session.target_match_id != -1
      silent! call matchdelete(s:session.target_match_id)
      let s:session.target_match_id = -1
    endif
    if s:session.deletion_match_id != -1
      silent! call matchdelete(s:session.deletion_match_id)
      let s:session.deletion_match_id = -1
    endif
    call s:clear_waypoint_matches()
    let s:session.advancing = 0
    " Re-check mode in case the user is already in the target mode
    " without further input. The motivating case: the previous frame
    " was target='c', the user pressed Ctrl+[ inside cmdline to leave,
    " landing in Normal. The c:n ModeChanged fired then, but the
    " current frame was still the c-frame (frame_complete blocked
    " re-credit). After advancing to this n-frame, mode is already 'n'
    " — no further ModeChanged will fire, so we'd be stuck without
    " this synchronous check.
    if frame.kind ==# 'try'
      call s:check_mode_for_learn_credit()
    endif
    return
  endif
  if is_recall
    " Recall lessons render the lesson header line + try-frame's
    " prompt + input area + optional prompt_after (e.g. T0.5's mock
    " vim screen at the buffer bottom). Show frames stay static;
    " no input area.
    if frame.kind ==# 'try'
      let pre = [s:learn_header_line(), '']
      let [lines, input_row] = s:recall_compose(frame, pre)
      let s:session.recall_input = ''
      let s:session.input_prefix = '  > '
      let s:session.input_row = input_row
      setlocal modifiable
      silent! %delete _
      call setline(1, lines)
      call cursor(s:session.input_row, len(s:session.input_prefix) + 1)
    else
      setlocal modifiable
      silent! %delete _
      call setline(1, base_header)
      " Park cursor at the bottom blank header line so the block sits
      " on empty space rather than over a prompt char.
      call cursor(len(base_header), 1)
    endif
    let s:session.advancing = 0
    return
  endif
  " Mode-kind frames may get a '▶◀' gap indicator row — try frames
  " always do (it's the cue); show frames optionally, when they
  " declare enter_at_col to demonstrate the cue itself.
  let mode_extra = []
  if is_mode
    let ind = s:mode_gap_indicator(frame)
    if !empty(ind)
      call add(mode_extra, ind)
    endif
  endif
  " Annotation row sits at the END of the header (just above the
  " content), so the cur_lines comparison in s:learn_on_change still
  " excludes it via header_offset.
  let header = base_header + mode_extra + s:waypoint_annotation(frame)
  let s:session.header_offset = len(header)

  setlocal modifiable
  silent! %delete _
  if has_key(frame, 'history') && !empty(frame.history)
    call s:stage_undo_history(frame, header)
  else
    call setline(1, header + frame.lines)
  endif

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
  call s:clear_waypoint_matches()

  if frame.kind ==# 'show'
    let buf_row = s:session.header_offset + frame.cursor[0]
    call cursor(buf_row, frame.cursor[1])
    " Optional 'highlight' field marks a non-cursor cell the prompt
    " is calling attention to (e.g. "look at column N"). If omitted,
    " the cursor block alone is the position indicator — we
    " deliberately don't auto-highlight the cursor's own cell,
    " because a same-cell highlight is hidden under the cursor and
    " conveys no extra information (same failure shape as 4.d's
    " green-target-under-cursor problem, at the lesson layer).
    if has_key(frame, 'highlight')
      let h_row = s:session.header_offset + frame.highlight[0]
      let s:session.target_match_id = matchaddpos('VfLearnShow',
        \ [[h_row, frame.highlight[1], 1]])
    endif
  else
    let buf_start_row = s:session.header_offset + frame.start[0]
    let buf_target_row = s:session.header_offset + frame.target[0]
    call cursor(buf_start_row, frame.start[1])
    " Editing- and mode-kind lessons hide the green single-cell target
    " — editing because the deletion-range red shows what to do, mode
    " because the '▶◀' indicator already marks the gap.
    if !is_mode && get(s:session, 'kind', 'motion') !=# 'editing'
      let s:session.target_match_id = matchaddpos('VfTarget',
        \ [[buf_target_row, frame.target[1], 1]], 20)
    endif
    if has_key(frame, 'deletion_range') && !empty(frame.deletion_range)
      let positions = []
      for pos in frame.deletion_range
        call add(positions,
          \ [s:session.header_offset + pos[0], pos[1], pos[2]])
      endfor
      let s:session.deletion_match_id = matchaddpos('VfDeletion', positions, 10)
    endif
    call s:add_waypoint_matches(frame)
  endif

  let s:session.advancing = 0
endfunction

function! s:learn_install_autocmds() abort
  let kind = get(s:session, 'kind', 'motion')
  if kind ==# 'mode_switch'
    " mode_switch lessons credit the instant vim's mode changes.
    " ModeChanged (8.2+) is sub-frame; 8.1 falls back to a 50ms
    " polling timer. Both call s:check_mode_for_learn_credit, which
    " routes credit into frame_complete + streak machinery instead
    " of items_correct. The auto-advance timer downstream gets the
    " user out of post-credit non-Normal modes without forcing
    " <Esc>+Space.
    call s:stop_mode_polling()
    if !exists('##ModeChanged')
      let s:session.mode_poll_timer = timer_start(50,
        \ function('s:check_mode_for_learn_credit'), {'repeat': -1})
    endif
    " Defang <CR> in cmdline mode so any text the user types after ':'
    " can't execute as an ex command against the lesson buffer. See
    " s:on_cmdline_enter_learn for the full cmdline flow.
    cnoremap <buffer> <CR> <C-c>
  endif
  augroup VfLearn
    autocmd!
    if kind ==# 'mode'
      " Mode-kind lessons track the round trip through insert mode,
      " same as the training: InsertEnter records the entry col so we
      " can disambiguate i/a/I/A, InsertLeave is when we evaluate.
      autocmd InsertEnter <buffer> call s:learn_on_insert_enter()
      autocmd InsertLeave <buffer> call s:learn_on_insert_leave()
      " Opt-in fast path for pinpoints that drill the entry key by
      " having the learner TYPE a known short text (e.g. 'foo') and
      " advance the moment the buffer matches target_lines_after_type.
      " No Esc needed — mode-leave has its own dedicated pinpoint
      " (switch_mode_to_insert), so we don't bill the learner twice
      " for it here. Mirrors s:install_autocmds in the training path.
      if get(s:session, 'credit_on_text_typed', 0)
        autocmd TextChangedI <buffer> call s:learn_on_text_changed_i()
      endif
    elseif kind ==# 'mode_switch'
      " ModeChanged (8.2+) gives synchronous credit; the polling
      " fallback for 8.1 was already started in the kind-dispatch
      " block above. Either way, the autocmds are scoped to this
      " augroup so learn_stop tears them down.
      "
      " CmdlineEnter is the only hook that lands while target='c'
      " is satisfiable — see s:install_autocmds for the full story.
      " Without this, hitting ':' freezes the lesson in cmdline mode.
      if exists('##ModeChanged')
        autocmd ModeChanged * call s:check_mode_for_learn_credit()
      endif
      autocmd CmdlineEnter : call s:on_cmdline_enter_learn()
    elseif kind ==# 'recall'
      " Recall lessons route every printable keystroke into recall_append
      " (mirrors the training). No autocmds needed — handlers fire via the
      " buffer-local mappings.
      call s:install_recall_maps()
    else
      " TextChanged is needed for the test phase on editing-kind pinpoints
      " where dw/db etc. modify the buffer without necessarily firing
      " CursorMoved (e.g. dw at col 1 leaves cursor at col 1).
      autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI <buffer>
        \ call s:learn_on_change()
    endif
  augroup END
  " Lesson keymaps. For recall lessons we skip q/p overrides because
  " those are letters that appear in answer strings (e.g. :q, :wq).
  " Esc still quits the recall lesson via install_recall_maps. Space
  " and CR likewise override recall's bindings — none of the current
  " recall pinpoints' answers contain Space or CR, so this is safe;
  " a future answer-with-spaces would need a dispatcher.
  nnoremap <buffer> <silent> <Space> :call <SID>learn_advance_show()<CR>
  nnoremap <buffer> <silent> <CR> :call <SID>learn_advance_show()<CR>
  if kind !=# 'recall'
    nnoremap <buffer> <silent> q :call vimfluency#learn_stop()<CR>
    nnoremap <buffer> <silent> p :call <SID>learn_start_train()<CR>
  endif
  " Ctrl-C → Esc, mirroring the training path. Vim's Ctrl-C exits insert
  " without firing InsertLeave by design, so unmapped it would leave
  " the mode-kind matcher hanging.
  inoremap <buffer> <silent> <C-c> <Esc>
endfunction

" Space/Enter: advance from a 'show' frame, from a completed 'try' frame,
" or from a completed test-phase item.
function! s:learn_advance_show() abort
  if empty(s:session) || s:session.mode !=# 'learn' || s:session.advancing | return | endif
  if s:session.phase ==# 'complete' | return | endif
  " Cancel any pending mode_switch auto-advance — the user wants to
  " advance NOW.
  call s:stop_learn_auto_advance()
  if s:session.phase ==# 'test'
    if s:session.frame_complete
      call s:learn_next()
    endif
    return
  endif
  let frame = s:session.frames[s:session.frame_idx]
  if frame.kind ==# 'show'
    call s:learn_next()
  elseif frame.kind ==# 'try' && s:session.frame_complete
    call s:learn_next()
  endif
endfunction

function! s:learn_on_change() abort
  if empty(s:session) || s:session.mode !=# 'learn' || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif
  if s:session.phase ==# 'complete' | return | endif
  if s:session.frame_complete | return | endif

  if s:session.phase ==# 'test'
    let item = s:session.current_test_item
    let header_offset = s:session.header_offset
    let cur_pos = [line('.') - header_offset, col('.')]
    let cur_lines = getline(header_offset + 1, '$')
    let start_lines = item.lines
    let target_lines = get(item, 'target_lines', item.lines)

    " Dedupe by (cursor, buffer) state. Collapses both the deferred
    " CursorMoved that fires after our cursor() call (sees the
    " initial state we saved in s:learn_test_next) and operations
    " that fire BOTH TextChanged and CursorMoved for one press
    " (>>, <<, dd — buffer changes plus cursor jumps to first
    " non-blank). See the matching dedupe in s:on_change for the
    " training path; same principle.
    let new_state = [cur_pos, cur_lines]
    if get(s:session, 'last_event_state', []) ==# new_state
      return
    endif
    let s:session.last_event_state = new_state
    let s:session.test_motion_count += 1

    if cur_lines ==# target_lines && cur_pos == item.target
      let s:session.frame_complete = 1
      let s:session.last_item_motions = s:session.test_motion_count
      let s:session.last_item_optimal = get(item, 'optimal_motions', 1)
      if s:session.last_item_motions <= s:session.last_item_optimal
        let s:session.streak += 1
        let s:session.wrongs = 0
      else
        let s:session.streak = 0
        let s:session.wrongs += 1
      endif
      call s:learn_render_complete()
    endif
    return
  endif

  let frame = s:session.frames[s:session.frame_idx]
  if frame.kind !=# 'try' | return | endif
  let buf_target_row = s:session.header_offset + frame.target[0]
  if [line('.'), col('.')] != [buf_target_row, frame.target[1]] | return | endif
  " For editing-kind frames where start == target (dw stays put), the
  " cursor-only check would fire on s:learn_show_frame's own cursor()
  " call and credit before the learner typed anything. Frames declare
  " target_lines so we can also require the buffer to be in its
  " post-edit state.
  if has_key(frame, 'target_lines')
    let cur_lines = getline(s:session.header_offset + 1, '$')
    if cur_lines !=# frame.target_lines | return | endif
  endif
  let s:session.frame_complete = 1
  call s:learn_render_complete()
endfunction

" Mode-kind lesson handlers. Mirror s:on_insert_enter / s:on_insert_leave
" from the training path, but evaluate against either the current setup-phase
" frame OR the current test-phase item depending on s:session.phase.
function! s:learn_on_insert_enter() abort
  if empty(s:session) || s:session.mode !=# 'learn' || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif
  if s:session.phase ==# 'complete' || s:session.frame_complete | return | endif
  let header_offset = s:session.header_offset
  let s:session.insert_entered = 1
  let s:session.insert_enter_pos = [line('.') - header_offset, col('.')]
  if s:session.phase ==# 'test'
    let s:session.test_motion_count += 1
  endif
  " Same one-shot guard as the training path (s:on_insert_enter).
  let s:session.first_text_change_pending = 1
endfunction

" Lesson TextChangedI handler — fires after every keystroke while in
" insert mode. Credits the moment the buffer matches the item's
" target_lines (the expected post-typing state). The learner doesn't
" have to press Esc; the existing InsertLeave will see frame_complete=1
" and no-op when our feedkeys <Esc> below lands. mode-leave fluency is
" out of scope for this lesson — the switch_mode_to_insert pinpoint
" drills that separately.
function! s:learn_on_text_changed_i() abort
  if empty(s:session) || s:session.mode !=# 'learn' || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif
  if s:session.phase ==# 'complete' || s:session.frame_complete | return | endif
  if !get(s:session, 'insert_entered', 0) | return | endif

  let item = {}
  if s:session.phase ==# 'test'
    let item = s:session.current_test_item
  else
    if s:session.frame_idx >= len(s:session.frames) | return | endif
    let frame = s:session.frames[s:session.frame_idx]
    if frame.kind !=# 'try' | return | endif
    let item = frame
  endif
  " Prefer target_lines_after_type when present — that's the explicit
  " post-typing target. Fall back to target_lines for items that
  " don't distinguish (the original mode-kind item shape).
  let target = get(item, 'target_lines_after_type',
    \ get(item, 'target_lines', []))
  if empty(target) | return | endif

  let header_offset = s:session.header_offset
  let cur_lines = getline(header_offset + 1, '$')
  " Same guard as the training path: skip the post-entry-key line-
  " insert TextChangedI (from o/O), which would otherwise pad
  " test_motion_count by 1 and trip the streak threshold.
  let pending = get(s:session, 'first_text_change_pending', 0)
  let s:session.first_text_change_pending = 0
  if pending && cur_lines ==# get(item, 'target_lines', [])
    return
  endif
  if cur_lines !=# target | return | endif
  " Cheat-defense: also require the InsertEnter col to match what the
  " expected entry key produces. Without this a learner could use a
  " different key to reach the same buffer state.
  if has_key(item, 'enter_at_row') && has_key(item, 'enter_at_col')
    if s:session.insert_enter_pos != [item.enter_at_row, item.enter_at_col]
      return
    endif
  endif

  let s:session.frame_complete = 1
  if s:session.phase ==# 'test'
    let s:session.last_item_motions = s:session.test_motion_count
    let s:session.last_item_optimal = get(item, 'optimal_motions', 1)
    if s:session.last_item_motions <= s:session.last_item_optimal
      let s:session.streak += 1
      let s:session.wrongs = 0
    else
      let s:session.streak = 0
      let s:session.wrongs += 1
    endif
  endif
  call s:learn_render_complete()
  " Drop the user back to Normal so the next frame renders cleanly.
  " 'i' inserts Esc at the start of the typeahead buffer so it
  " preempts any chars the learner over-typed in their reaction
  " window; frame_complete=1 makes the InsertLeave a no-op.
  call feedkeys("\<Esc>", 'ni')
  call s:stop_learn_auto_advance()
  let s:session.learn_auto_advance_timer = timer_start(600,
    \ function('s:learn_mode_switch_auto_advance'))
endfunction

function! s:learn_on_insert_leave() abort
  if empty(s:session) || s:session.mode !=# 'learn' || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif
  if s:session.phase ==# 'complete' || s:session.frame_complete | return | endif
  if !get(s:session, 'insert_entered', 0) | return | endif
  " For credit_on_text_typed pinpoints, credit comes from
  " TextChangedI exclusively — a bare Esc just resets state.
  if get(s:session, 'credit_on_text_typed', 0)
    if s:session.phase ==# 'test'
      let s:session.test_motion_count += 1
    endif
    let s:session.insert_entered = 0
    let s:session.insert_enter_pos = []
    return
  endif

  " Pull the item-shaped target from setup-phase frame or test-phase item.
  let item = {}
  if s:session.phase ==# 'test'
    let item = s:session.current_test_item
  else
    let frame = s:session.frames[s:session.frame_idx]
    if frame.kind !=# 'try' | return | endif
    let item = frame
  endif

  let header_offset = s:session.header_offset
  let cur_pos = [line('.') - header_offset, col('.')]
  let cur_lines = getline(header_offset + 1, '$')
  let target_lines = get(item, 'target_lines', item.lines)

  let entered_correct = s:session.insert_enter_pos
    \ == [item.enter_at_row, item.enter_at_col]
  let buffer_correct = cur_lines ==# target_lines
  let cursor_correct = cur_pos == item.target

  if s:session.phase ==# 'test'
    let s:session.test_motion_count += 1
  endif

  if entered_correct && buffer_correct && cursor_correct
    let s:session.frame_complete = 1
    if s:session.phase ==# 'test'
      let s:session.last_item_motions = s:session.test_motion_count
      let s:session.last_item_optimal = get(item, 'optimal_motions', 1)
      if s:session.last_item_motions <= s:session.last_item_optimal
        let s:session.streak += 1
        let s:session.wrongs = 0
      else
        let s:session.streak = 0
        let s:session.wrongs += 1
      endif
    endif
    call s:learn_render_complete()
  else
    " Reset so a fresh round trip can be evaluated. Free-operant —
    " the learner can keep retrying; no auto-fail on first wrong leave.
    let s:session.insert_entered = 0
    let s:session.insert_enter_pos = []
  endif
endfunction

" Repaint the header line in place to show the ✓/✗ confirmation. Done
" via setline rather than re-rendering the whole buffer so the learner's
" cursor and any visible buffer change stay on screen for them to observe.
" Also clears the target and deletion-range matches: once the answer is
" given, leaving them up creates a stale "what was supposed to happen"
" overlay that's especially confusing for editing kinds where the
" highlighted cells now sit on different characters than they did
" pre-deletion.
function! s:learn_render_complete() abort
  let s:session.advancing = 1
  setlocal modifiable
  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
  call s:clear_waypoint_matches()
  call setline(1, s:learn_header_line())
  let s:session.advancing = 0
  redraw
endfunction

function! s:learn_next() abort
  if s:session.phase ==# 'setup'
    let s:session.frame_idx += 1
    if s:session.frame_idx >= len(s:session.frames)
      let s:session.phase = 'test'
      let s:session.streak = 0
      call s:learn_test_next()
      return
    endif
    call s:learn_show_frame()
    return
  endif

  " phase == 'test'
  if s:session.streak >= s:session.required_streak
    let s:session.phase = 'complete'
    call s:learn_show_complete()
    return
  endif
  if s:session.wrongs >= s:session.max_wrongs
    call s:learn_restart('wrongs')
    return
  endif
  if s:session.test_items_seen >= s:session.max_test_items
    call s:learn_restart('cap')
    return
  endif
  call s:learn_test_next()
endfunction

" Final celebration screen after the learner hits 3-in-a-row in the
" test phase. Stays in the lesson tab; explicit p/q decide what's next.
function! s:learn_show_complete() abort
  let s:session.advancing = 1

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
  call s:clear_waypoint_matches()
  " Force back to Normal so q/t fire as Normal-mode mappings. The
  " mode_switch lessons end with the learner in whatever mode satisfied
  " the final test item (Insert/Visual/Replace/Cmd) — without this,
  " pressing q or t just inserts text instead of firing the mapping.
  " <C-\><C-n> is vim's universal "to Normal from anywhere" sequence.
  silent! call feedkeys("\<C-\>\<C-n>", 'n')
  " Recall lessons skipped the q/t overrides during input phases
  " (those letters belong to answer strings); install them now so
  " the completion screen's instructions work.
  if has_key(s:session, "input_row") | unlet s:session.input_row | endif
  nnoremap <buffer> <silent> q :call vimfluency#learn_stop()<CR>
  nnoremap <buffer> <silent> t :call <SID>learn_start_train()<CR>

  let streak = s:session.required_streak
  let duration = s:effective_duration()
  setlocal modifiable
  silent! %delete _
  call setline(1, [
    \ printf('LESSON %s  COMPLETE  [t=start training]  [q=quit]', s:session.id),
    \ '',
    \ printf('  ✓ %d in a row on %s — nice work.', streak, s:session.name),
    \ '',
    \ printf('  The training presents the same kind of items on a %d-second', duration),
    \ '  clock. The lesson just confirmed you know the rule; the training',
    \ '  is where you build fluency — the speed and automaticity that',
    \ '  make a motion useful during real editing. Knowing how a motion',
    \ '  works and being fluent at it are different things, and only',
    \ '  repetition under time pressure closes the gap.',
    \ '',
    \ '  Slow is smooth. Smooth is fast.',
    \ '',
    \ '  Each training writes a data point to the session log;',
    \ printf('  :VfChart %s plots your rate over days.', s:session.id),
    \ '',
    \ printf('    t   start :Vf %s', s:session.id),
    \ '    q   exit (run :Vf later when ready)',
    \ ])
  call cursor(1, 1)
  let s:session.advancing = 0
endfunction

" Triggered by the t mapping on the completion screen. No-op anywhere
" else, so t stays inert during normal lesson flow.
function! s:learn_start_train() abort
  if empty(s:session) || s:session.mode !=# 'learn' | return | endif
  if get(s:session, 'phase', '') !=# 'complete' | return | endif
  let id = s:session.id
  call vimfluency#learn_stop()
  call vimfluency#start(id)
endfunction

" Send the learner back to frame 0 of the lesson, preserving the tab,
" buffer, and autocmds. Echoes the reason so they know why they're
" being restarted.
function! s:learn_restart(reason) abort
  let id = s:session.id
  let cap = s:session.max_test_items
  let s:session.phase = 'setup'
  let s:session.frame_idx = 0
  let s:session.streak = 0
  let s:session.wrongs = 0
  let s:session.test_items_seen = 0
  let s:session.test_seq_idx = 0
  let s:session.test_motion_count = 0
  let s:session.frame_complete = 0
  let s:session.last_item_motions = 0
  let s:session.last_item_optimal = 0
  let s:session.current_test_item = {}
  call s:learn_show_frame()
  let target = s:session.required_streak
  if a:reason ==# 'cap'
    echo printf('lesson %s: hit %d-item test cap without %d-in-a-row — restarting from the top.',
      \ id, cap, target)
  elseif a:reason ==# 'wrongs'
    echo printf('lesson %s: 3 wrong in a row — restarting from the top.', id)
  endif
endfunction

" Generate a fresh test item from the pinpoint and render it. Reuses the
" pinpoint's generate() so test items have the same cheat-defense as
" training items — meaning the intended motion is the canonical answer and
" optimal_motions is the criterion for "first-try correct".
function! s:learn_test_next() abort
  let s:session.advancing = 1
  let s:session.frame_complete = 0
  let s:session.test_motion_count = 0
  let s:session.test_items_seen += 1
  " Reset mode-kind insert-tracking on every test item.
  let s:session.insert_entered = 0
  let s:session.insert_enter_pos = []
  " Reset recall input-row; we set it below if this is a recall item.
  if has_key(s:session, "input_row") | unlet s:session.input_row | endif

  let GenFn = function('vimfluency#pinpoints#' . s:session.module . '#generate')
  let kind = get(s:session, 'kind', 'motion')
  let cur_canon = kind ==# 'mode_switch' ? s:mode_canonical(mode(1)) : ''
  " test_sequence (declared in meta) drives the test phase through a
  " deterministic cycle of expected_motion values. We re-roll the
  " generator until it returns an item matching the next sequence
  " slot, advancing test_seq_idx after each pick. Falls back to the
  " original random behavior when no sequence is declared.
  let target_motion = ''
  if !empty(get(s:session, 'test_sequence', []))
    let seq = s:session.test_sequence
    let idx = get(s:session, 'test_seq_idx', 0)
    let target_motion = seq[idx % len(seq)]
    let s:session.test_seq_idx = idx + 1
  endif
  let item = {}
  let attempts = 0
  while attempts < 100
    let item = GenFn()
    let mode_ok = kind !=# 'mode_switch'
      \ || get(item, 'target_mode_canon', '') !=# cur_canon
    let motion_ok = empty(target_motion)
      \ || get(item, 'expected_motion', '') ==# target_motion
    if mode_ok && motion_ok
      break
    endif
    let attempts += 1
  endwhile
  let s:session.current_test_item = item
  " Initial state for the dedupe guard in s:learn_on_change. Same
  " logic as s:next_item — vim's deferred CursorMoved after the
  " cursor() call below sees this state and is skipped; subsequent
  " presses produce distinct states.
  let s:session.last_event_state = [item.start, copy(item.lines)]

  let is_mode = kind ==# 'mode'

  if kind ==# 'mode_switch'
    let prompt_lines = [
      \ s:learn_header_line(), '',
      \ '    Switch to '
      \   . s:mode_pretty(get(item, 'target_mode_canon', 'n')) . ' mode',
      \ '',
      \ '    (from a non-Normal mode, press <Esc> first)']
    let s:session.header_offset = len(prompt_lines)
    setlocal modifiable
    " Overwrite in place — see s:learn_show_frame and
    " s:render_mode_switch_item. %delete here would kick the user out
    " of Visual mode mid-test (they just credited a v-item and are
    " still in 'v' when the next test item renders), making the next
    " n-item look already-satisfied even though the user hasn't done
    " anything yet.
    call setline(1, prompt_lines)
    if line('$') > len(prompt_lines)
      silent! execute (len(prompt_lines) + 1) . ',$delete _'
    endif
    call cursor(min([len(prompt_lines), line('$')]), 1)
    if s:session.target_match_id != -1
      silent! call matchdelete(s:session.target_match_id)
      let s:session.target_match_id = -1
    endif
    if s:session.deletion_match_id != -1
      silent! call matchdelete(s:session.deletion_match_id)
      let s:session.deletion_match_id = -1
    endif
    call s:clear_waypoint_matches()
    let s:session.advancing = 0
    return
  endif

  if kind ==# 'recall'
    " Recall test items: the item's prompt + optional prompt_after
    " (e.g. T0.5 puts its mock vim screen below the input area).
    let pre = [s:learn_header_line(), '']
    let [lines, input_row] = s:recall_compose(item, pre)
    let s:session.recall_input = ''
    let s:session.input_prefix = '  > '
    let s:session.input_row = input_row
    setlocal modifiable
    silent! %delete _
    call setline(1, lines)
    call cursor(s:session.input_row, len(s:session.input_prefix) + 1)
    let s:session.advancing = 0
    return
  endif

  let has_waypoints = has_key(item, 'waypoints') && !empty(item.waypoints)
  let test_prompt = has_waypoints
    \ ? 'Reach each numbered target in order. Fewer keystrokes is better.'
    \ : (is_mode
    \    ? 'Enter insert at the marked gap, then press Esc.'
    \    : 'Reach the target — figure out the motion. Fewer keystrokes is better.')
  let prompt_lines = type(test_prompt) == v:t_list
    \ ? copy(test_prompt) : [test_prompt]
  let lesson_header = [s:learn_header_line(), ''] + prompt_lines + ['']

  " Editing items get the runner's prompt+divider header above the live
  " editing area, mirroring what the training shows.
  let editing_header = []
  if get(s:session, 'kind', 'motion') ==# 'editing'
    let prompt = get(item, 'prompt', 'edit to match the target')
    let editing_header = [prompt, repeat('─', 60)]
  endif
  " Mode items get the gap indicator above the content.
  let mode_extra = []
  if is_mode
    let ind = s:mode_gap_indicator(item)
    if !empty(ind)
      call add(mode_extra, ind)
    endif
  endif
  let full_header = lesson_header + editing_header + mode_extra + s:waypoint_annotation(item)
  let s:session.header_offset = len(full_header)

  setlocal modifiable
  silent! %delete _
  if has_key(item, 'history') && !empty(item.history)
    call s:stage_undo_history(item, full_header)
  else
    call setline(1, full_header + item.lines)
  endif
  call cursor(s:session.header_offset + item.start[0], item.start[1])

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  if !is_mode && get(s:session, 'kind', 'motion') !=# 'editing'
    let s:session.target_match_id = matchaddpos('VfTarget',
      \ [[s:session.header_offset + item.target[0], item.target[1], 1]], 20)
  endif

  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
  if has_key(item, 'deletion_range') && !empty(item.deletion_range)
    let positions = []
    for pos in item.deletion_range
      call add(positions,
        \ [s:session.header_offset + pos[0], pos[1], pos[2]])
    endfor
    let s:session.deletion_match_id = matchaddpos('VfDeletion', positions, 10)
  endif

  call s:clear_waypoint_matches()
  call s:add_waypoint_matches(item)

  let s:session.advancing = 0
endfunction

function! vimfluency#learn_stop() abort
  if empty(s:session) | return | endif
  silent! augroup VfLearn | autocmd! | augroup END
  call s:stop_mode_polling()
  call s:stop_learn_auto_advance()
  let id = s:session.id
  let prev_ttl = get(s:session, 'prev_ttimeoutlen', &ttimeoutlen)
  if has_key(s:session, 'tabnr')
    silent! execute 'tabclose ' . s:session.tabnr
  endif
  let &ttimeoutlen = prev_ttl
  let s:session = {}
  echo 'lesson ended for ' . id . ' — try :Vf ' . id
endfunction

" -----------------------------------------------------------------
" Standard Celeration Chart (text-only)
" -----------------------------------------------------------------

" Y-axis layout: log10 scale, 24 rows total. Default bounds span 3
" decades (1 → 1000); the zoom variant collapses to one decade (10 →
" 100) so sessions clustered in the middle of the full chart actually
" have room to separate visually.
let s:CHART_HEIGHT = 24
let s:CHART_LABEL_W = 6
" One column per calendar day (PT convention). Days with no training show
" as a gap, multi-training days stack at the same column.
let s:CHART_COLS_PER_DAY = 2

" Y-axis labels are picked to land on distinct rows under both round() and
" the height/decade ratio we use — denser than just decade boundaries so
" you can read the rate without counting rows. The picks here are
" semi-log "natural" gridlines (1, 2, 3, 5, 7 within each decade for
" full mode; finer for the single-decade zoom).
let s:CHART_BOUNDS_FULL = {
  \ 'log_top': 3.0,
  \ 'log_bot': 0.0,
  \ 'labels':  [1000, 500, 200, 100, 50, 20, 10, 5, 2, 1],
  \ }
let s:CHART_BOUNDS_ZOOM = {
  \ 'log_top': 2.0,
  \ 'log_bot': 1.0,
  \ 'labels':  [100, 70, 50, 40, 30, 20, 15, 10],
  \ }

function! s:chart_y(rate, bounds) abort
  if a:rate <= 0
    return s:CHART_HEIGHT
  endif
  let lr = log10(a:rate * 1.0)
  if lr < a:bounds.log_bot
    return s:CHART_HEIGHT
  endif
  if lr > a:bounds.log_top
    return 0
  endif
  let span = a:bounds.log_top - a:bounds.log_bot
  return float2nr(round((a:bounds.log_top - lr) / span * s:CHART_HEIGHT))
endfunction

" Julian day number for a YYYY-MM-DD prefix. Used as an integer day index
" so we can compute "days since first session" without depending on
" strptime() (which isn't on every platform).
function! s:julian_from_iso(ts) abort
  let y = str2nr(a:ts[0:3])
  let m = str2nr(a:ts[5:6])
  let d = str2nr(a:ts[8:9])
  let a = (14 - m) / 12
  let y2 = y + 4800 - a
  let m2 = m + 12 * a - 3
  return d + (153 * m2 + 2) / 5 + 365 * y2
    \ + y2 / 4 - y2 / 100 + y2 / 400 - 32045
endfunction

" Inverse of julian_from_iso — returns 'YYYY-MM-DD'. Standard Gregorian
" conversion (Fliegel-Van Flandern); pure integer arithmetic so it works
" on any vim build.
function! s:iso_from_julian(jul) abort
  let a = a:jul + 32044
  let b = (4 * a + 3) / 146097
  let c = a - (146097 * b) / 4
  let d = (4 * c + 3) / 1461
  let e = c - (1461 * d) / 4
  let m = (5 * e + 2) / 153
  let day = e - (153 * m + 2) / 5 + 1
  let month = m + 3 - 12 * (m / 10)
  let year = 100 * b + d - 4800 + m / 10
  return printf('%04d-%02d-%02d', year, month, day)
endfunction

function! vimfluency#chart(...) abort
  if a:0 < 1
    echo 'usage: :VfChart <pinpoint_id>'
    return
  endif
  call s:chart_render(a:1, s:CHART_BOUNDS_FULL, '')
endfunction

function! vimfluency#chart_zoom(...) abort
  if a:0 < 1
    echo 'usage: :VfChartZoom <pinpoint_id>'
    return
  endif
  call s:chart_render(a:1, s:CHART_BOUNDS_ZOOM, 'zoom')
endfunction

function! s:chart_render(id, bounds, variant) abort
  let log_path = vimfluency#log_dir() . '/sessions.jsonl'
  if !filereadable(log_path)
    echo 'no sessions logged yet (' . log_path . ')'
    return
  endif

  let sessions = []
  for line in readfile(log_path)
    if empty(line) | continue | endif
    try
      let r = json_decode(line)
      if get(r, 'pinpoint_id', '') ==# a:id
        call add(sessions, r)
      endif
    catch
    endtry
  endfor

  if empty(sessions)
    echo 'no sessions for pinpoint ' . a:id
    return
  endif

  call sort(sessions, {a, b -> a.timestamp ==# b.timestamp ? 0
    \ : (a.timestamp <# b.timestamp ? -1 : 1)})

  let lines = s:render_chart(a:id, sessions, a:bounds)
  call s:show_chart_buffer(a:id, lines, a:variant)
endfunction

function! s:render_chart(id, sessions, bounds) abort
  let n = len(a:sessions)
  let pinpoint_name = a:sessions[0].pinpoint_name
  let aim = a:sessions[0].aim
  let base_jul = s:julian_from_iso(a:sessions[0].timestamp)
  let last_jul = s:julian_from_iso(a:sessions[-1].timestamp)
  let n_days = last_jul - base_jul + 1
  let chart_w = n_days * s:CHART_COLS_PER_DAY
  let total_w = s:CHART_LABEL_W + 1 + chart_w + 1

  " Initialize grid: each row is a list of single-char strings
  let grid = []
  for r in range(s:CHART_HEIGHT + 1)
    call add(grid, repeat([' '], total_w))
  endfor

  " Y-axis labels: semi-log gridlines (not just decade boundaries) so
  " the rate at any row can be read without counting tick spacing.
  " The bounds.labels list is picked to avoid same-row collisions
  " under our round-to-row mapping.
  for rate in a:bounds.labels
    let row = s:chart_y(rate, a:bounds)
    if row >= 0 && row <= s:CHART_HEIGHT
      let label = printf('%5d', rate)
      for i in range(len(label))
        let grid[row][i] = label[i]
      endfor
    endif
  endfor

  " Vertical axis line
  for r in range(s:CHART_HEIGHT + 1)
    let grid[r][s:CHART_LABEL_W] = '│'
  endfor

  " Horizontal axis line at the bottom
  for c in range(s:CHART_LABEL_W, total_w - 1)
    let grid[s:CHART_HEIGHT][c] = '─'
  endfor
  let grid[s:CHART_HEIGHT][s:CHART_LABEL_W] = '└'

  " Aim line (dashed)
  let aim_row = s:chart_y(aim, a:bounds)
  if aim_row > 0 && aim_row < s:CHART_HEIGHT
    for c in range(s:CHART_LABEL_W + 1, total_w - 1)
      let grid[aim_row][c] = '-'
    endfor
  endif

  " Plot each session at its calendar-day column. Multi-session days
  " overlap at the same column (showing the spread when rates differ).
  " Sessions with frequency_per_min == 0 (user quit before any item, or
  " timed out at zero) are skipped — they pile on the axis floor and
  " distort the visual read. The raw record is still in sessions.jsonl
  " for any downstream analysis.
  for i in range(n)
    let session = a:sessions[i]
    let crate = get(session, 'frequency_per_min', 0)
    if crate <= 0 | continue | endif
    let day_idx = s:julian_from_iso(session.timestamp) - base_jul
    let col = s:CHART_LABEL_W + 1 + day_idx * s:CHART_COLS_PER_DAY
    if col >= total_w | break | endif

    " Plot errors first, then corrects, so the corrects dot wins on
    " collision (when rate and errors_per_min round to the same row
    " — common when wasted motions track close to credited items).
    " The rate is the headline metric; if one symbol has to obscure
    " the other, the dot should be the survivor. The exact errors
    " value is still available via :VfHistory.
    let erate = get(session, 'errors_per_min', 0)
    if erate > 0
      let erow = s:chart_y(erate, a:bounds)
      if erow >= 0 && erow <= s:CHART_HEIGHT
        let grid[erow][col] = '×'
      endif
    endif

    let crow = s:chart_y(crate, a:bounds)
    if crow >= 0 && crow <= s:CHART_HEIGHT
      let grid[crow][col] = '●'
    endif
  endfor

  " X-axis labels. Pick a calendar-day stride that fits ~10 labels max
  " with at least one blank col between 5-char 'MM-DD' labels (min
  " spacing in days = ceil(6 / cols_per_day)). The first day is always
  " labeled; the last day is added if it has room to the right of the
  " previous label.
  let max_labels = 10
  let min_spacing_days = (6 + s:CHART_COLS_PER_DAY - 1) / s:CHART_COLS_PER_DAY
  let raw_stride = (n_days + max_labels - 1) / max_labels
  let stride = max([min_spacing_days, raw_stride])

  let label_days = []
  let dd = 0
  while dd < n_days
    call add(label_days, dd)
    let dd += stride
  endwhile
  if !empty(label_days) && label_days[-1] != n_days - 1
    \ && (n_days - 1) - label_days[-1] >= min_spacing_days
    call add(label_days, n_days - 1)
  endif

  " Tick marks on the bottom axis at labeled day cols.
  for dd in label_days
    let col = s:CHART_LABEL_W + 1 + dd * s:CHART_COLS_PER_DAY
    if col < total_w
      let grid[s:CHART_HEIGHT][col] = '┴'
    endif
  endfor

  " X-axis date row: 'MM-DD' left-aligned at each tick. Left-align
  " (rather than centering on the tick) keeps the first label clear of
  " the y-axis label column.
  let xlabel = repeat([' '], total_w)
  for dd in label_days
    let col = s:CHART_LABEL_W + 1 + dd * s:CHART_COLS_PER_DAY
    let date_str = s:iso_from_julian(base_jul + dd)[5:9]
    if col + 4 < total_w
      for i in range(5)
        let xlabel[col + i] = date_str[i]
      endfor
    endif
  endfor

  " Compose output lines
  let out = []
  call add(out, printf('vimfluency celeration chart — %s (%s)', a:id, pinpoint_name))
  call add(out, 'rate per minute (log Y) over calendar date · one column per day')
  call add(out, printf('aim %d/min   ·   %d session(s)   ·   ● corrects   × errors   - aim',
    \ aim, n))
  call add(out, '')
  for row_chars in grid
    call add(out, join(row_chars, ''))
  endfor
  call add(out, join(xlabel, ''))

  call add(out, printf(' first session: %s', a:sessions[0].timestamp))
  call add(out, printf(' last  session: %s', a:sessions[-1].timestamp))
  call add(out, '')
  call add(out, ' Press q or <Enter> to close.')

  return out
endfunction

function! s:show_chart_buffer(id, lines, variant) abort
  tabnew
  let tabnr = tabpagenr()
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  let bufname_suffix = empty(a:variant) ? '' : '-' . a:variant
  let title_suffix = empty(a:variant) ? '' : ' (' . a:variant . ')'
  silent! execute 'keepalt file vf-chart' . bufname_suffix . '-' . a:id
  call setline(1, a:lines)
  setlocal nomodifiable nomodified
  let &l:statusline = ' celeration chart — ' . a:id . title_suffix . '   [press q or <Enter> to close]'
  let b:vf_summary_tabnr = tabnr
  let b:vf_summary_prev_laststatus = &laststatus
  set laststatus=2
  nnoremap <buffer> <silent> q :call vimfluency#close_summary()<CR>
  nnoremap <buffer> <silent> <CR> :call vimfluency#close_summary()<CR>
  call cursor(1, 1)
endfunction

" ─────────────────────────────────────────────────────────────────
" :VfDashboard — multi-panel view with hover-reactive context panels
"
" Layout (top to bottom, fixed for now; could grow toggles later):
"   profile         ~9 rows    learner-profile aggregates
"   hover           ~11 rows   chart + last-session for hovered drill
"   table           flex       column header (row 1) + data (rows 2+);
"                              cursor lives here, j/k snap to data rows
"
" The column header is the first line of the table buffer rather
" than its own window — keeps it visually butted up against the
" data with no separator-statusline strip between them.
"
" Buffers in the tab:
"   vf-dashboard-profile  (learner-profile aggregates, rendered once)
"   vf-dashboard-hover    (hovered-drill panels, refreshed on CursorMoved)
"   vf-dashboard-table    (interactive — cursor + key bindings)
" ─────────────────────────────────────────────────────────────────

let s:DASHBOARD_PROFILE_HEIGHT = 8
let s:DASHBOARD_HOVER_HEIGHT = 15

function! vimfluency#dashboard() abort
  let registry = vimfluency#discover_pinpoints()
  if empty(registry)
    echo 'no pinpoints built — see CATALOG.md'
    return
  endif
  call s:show_dashboard(registry, s:load_sessions_grouped())
endfunction

function! s:show_dashboard(registry, sessions) abort
  let view = s:build_list_view(a:registry, a:sessions, {})
  let split = s:split_view(view)
  let cols = &columns

  " Prepend the column-header row (last line of split.header_lines)
  " to the data lines so the table buffer renders both. All row-keyed
  " mappings shift down by 1 to account for the new header row.
  let table_lines = [split.header_lines[-1]] + split.data_lines
  let mapping = {}
  for [k, id] in items(split.mapping)
    let mapping[str2nr(k) + 1] = id
  endfor
  let pinpoint_rows = map(copy(split.pinpoint_rows), 'v:val + 1')

  tabnew
  let tabnr = tabpagenr()

  " --- Window 1 (initial, will become the table window at the bottom) ---
  silent! execute 'keepalt file vf-dashboard-table'
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal cursorline modifiable
  silent! %delete _
  call setline(1, table_lines)
  setlocal nomodifiable nomodified
  let table_winid = win_getid()
  let b:vf_list_line_to_id    = mapping
  let b:vf_list_pinpoint_rows = pinpoint_rows
  let b:vf_list_expanded = {}
  let b:vf_list_sort_col = ''
  let b:vf_list_sort_desc = 0
  let b:vf_dashboard_tabnr = tabnr
  let b:vf_dashboard_prev_laststatus = &laststatus
  let &l:statusline = ' Vim Fluency dashboard   [L=Learn  T=Train  C=Chart  q=close]'
  set laststatus=2

  " --- Window 2: profile aggregates at the very top ---
  topleft new
  execute 'resize ' . s:DASHBOARD_PROFILE_HEIGHT
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal winfixheight nocursorline
  silent! execute 'keepalt file vf-dashboard-profile'
  let profile_bufnr = bufnr('%')
  let &l:statusline = ' '

  " --- Window 3: hovered-drill panels between profile and table ---
  " From the table window, `aboveleft new` opens a window above it
  " (between profile and table) with a fresh buffer.
  call win_gotoid(table_winid)
  aboveleft new
  execute 'resize ' . s:DASHBOARD_HOVER_HEIGHT
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal winfixheight nocursorline
  silent! execute 'keepalt file vf-dashboard-hover'
  let hover_bufnr = bufnr('%')
  let &l:statusline = ' '

  " Return to the table window — that's where the cursor lives.
  call win_gotoid(table_winid)
  let b:vf_dashboard_hover_bufnr = hover_bufnr
  let b:vf_dashboard_profile_bufnr = profile_bufnr

  let first_line = empty(pinpoint_rows) ? 2 : pinpoint_rows[0]
  call cursor(first_line, 1)
  let b:vf_dashboard_last_row = first_line

  call s:dashboard_render_hover(mapping, first_line, a:registry, a:sessions, cols)
  call s:dashboard_render_profile(mapping, first_line, a:registry, a:sessions, cols)

  augroup VfDashboard
    autocmd!
    autocmd CursorMoved <buffer> call s:dashboard_on_cursor_moved()
    autocmd BufWipeout <buffer> silent! call s:dashboard_cleanup()
  augroup END

  " Key bindings on the table window. Reuses the existing :VfList
  " action callbacks since they read the same b:vf_list_* variables
  " we set above.
  nnoremap <buffer> <silent> L :call vimfluency#list_action('learn')<CR>
  nnoremap <buffer> <silent> T :call vimfluency#list_action('train')<CR>
  nnoremap <buffer> <silent> C :call vimfluency#list_action('chart')<CR>
  nnoremap <buffer> <silent> A :call vimfluency#list_set_aim()<CR>
  nnoremap <buffer> <silent> D :call vimfluency#list_set_duration()<CR>
  nnoremap <buffer> <silent> q :call vimfluency#close_summary()<CR>
  nnoremap <buffer> <silent> j :call vimfluency#list_move('next')<CR>
  nnoremap <buffer> <silent> k :call vimfluency#list_move('prev')<CR>
  nnoremap <buffer> <silent> gg :call vimfluency#list_move('first')<CR>
  nnoremap <buffer> <silent> G :call vimfluency#list_move('last')<CR>
endfunction

function! s:dashboard_on_cursor_moved() abort
  if !exists('b:vf_dashboard_hover_bufnr') | return | endif
  let row = line('.')
  if row == get(b:, 'vf_dashboard_last_row', -1) | return | endif
  let b:vf_dashboard_last_row = row
  " Re-fetch registry + sessions; the JSONL log only grows during
  " training, not while the dashboard is open, so this is cheap.
  let registry = vimfluency#discover_pinpoints()
  let sessions = s:load_sessions_grouped()
  call s:dashboard_render_hover(b:vf_list_line_to_id, row, registry, sessions, &columns)
  call s:dashboard_render_profile(b:vf_list_line_to_id, row, registry, sessions, &columns)
endfunction

function! s:dashboard_cleanup() abort
  for name in ['vf-dashboard-hover', 'vf-dashboard-profile']
    let b = bufnr(name)
    if b > 0 | silent! execute 'bwipeout! ' . b | endif
  endfor
  silent! autocmd! VfDashboard
endfunction

" Render the hover panel buffer: two celeration charts side-by-side.
" The hovered-drill chart is on the left (above LAST SESSION in the
" profile panel); the daily-drills celeration chart is on the right
" (above DAILY-related metrics there's nothing — the chart IS the
" daily metric on its own).
function! s:dashboard_render_hover(mapping, row, registry, sessions, cols) abort
  let id = get(a:mapping, a:row, '')

  let inner_w = a:cols - 2
  let left_w = (inner_w - 3) / 2
  let right_w = inner_w - 3 - left_w
  let chart_h = s:DASHBOARD_HOVER_HEIGHT - 1

  let hovered_lines = s:dashboard_chart_panel(id, a:registry, a:sessions, left_w, chart_h)

  " Aggregate daily counts across every logged session — same data
  " model as the profile's session-count totals.
  let by_day = {}
  for runs in values(a:sessions)
    for s in runs
      let day = strpart(get(s, 'timestamp', ''), 0, 10)
      if !empty(day) | let by_day[day] = get(by_day, day, 0) + 1 | endif
    endfor
  endfor
  let days_back = 14
  let today_str = strftime('%Y-%m-%d')
  let today_count = get(by_day, today_str, 0)
  let streak = s:dashboard_streak(by_day, today_str)
  let daily_lines = s:dashboard_daily_chart_panel(by_day, days_back, today_count, streak, right_w, chart_h)

  while len(hovered_lines) < chart_h | call add(hovered_lines, '') | endwhile
  while len(daily_lines) < chart_h | call add(daily_lines, '') | endwhile

  let lines = []
  for i in range(chart_h)
    let l = ' ' . s:pad_right(hovered_lines[i], left_w) . '   ' . s:pad_right(daily_lines[i], right_w)
    call add(lines, s:pad_right(l, a:cols))
  endfor

  call s:dashboard_write_buffer(get(b:, 'vf_dashboard_hover_bufnr', -1), lines)
endfunction

function! s:dashboard_chart_panel(id, registry, sessions, w, h) abort
  let runs = empty(a:id) ? [] : get(a:sessions, a:id, [])
  let usable = filter(copy(runs), 'get(v:val, "frequency_per_min", 0) > 0')
  call sort(usable, {a, b -> a.timestamp ==# b.timestamp ? 0
    \ : (a.timestamp <# b.timestamp ? -1 : 1)})

  let aim_overrides = get(s:load_settings(), 'aims', {})
  let eff_aim = 0
  if !empty(a:id) && has_key(a:registry, a:id)
    let eff_aim = get(aim_overrides, a:id, get(a:registry[a:id], 'aim', 0))
  endif

  let title = empty(a:id) ? 'HOVERED' : printf('HOVERED: %s', a:id)
  let lines = [s:panel_box_top(title, a:w)]

  let status = s:status_from_sessions(eff_aim, runs)
  let last_rate = empty(usable) ? 0 : usable[-1].frequency_per_min
  let icon = status ==# 'at_aim' ? '✓'
    \ : status ==# 'climbing' ? '▶'
    \ : '○'
  let summary = printf(' %s  aim %d/min  ·  last %s/min',
    \ icon, eff_aim, empty(usable) ? '—' : string(s:round1(last_rate)))
  call add(lines, '│' . s:pad_right(summary, a:w - 2) . '│')

  " The chart frame (axis labels + aim line) renders even when
  " there are no usable sessions yet — a stable visual placeholder
  " beats a collapsing '(no data)' box that pops in and out as the
  " cursor moves between trained / untrained drills.
  "
  " Bounds are FIXED at the Standard Celeration Chart's 1..1000
  " (log_bot=0, log_top=3) per Precision Teaching convention —
  " every chart, every pinpoint, every visit reads on the same
  " y-axis so the visual slope of one drill is directly
  " comparable to any other.
  let plot_h = max([a:h - 4, 3])
  let label_w = 5
  let plot_w = a:w - 4 - label_w
  let recent = len(usable) <= plot_w ? usable : usable[-plot_w :]
  let log_bot = 0.0
  let log_top = 3.0

  let aim_row = eff_aim > 0 ? s:dashboard_log_y(eff_aim, plot_h, log_bot, log_top) : -1
  let label_rows = {}
  let lg = log_top
  while lg >= log_bot
    call s:add_label_rows(label_rows, plot_h, log_bot, log_top, float2nr(pow(10.0, lg) + 0.5))
    let lg -= 1.0
  endwhile

  for r in range(plot_h)
    let label = has_key(label_rows, r)
      \ ? printf('%' . (label_w - 1) . 'd ', label_rows[r])
      \ : repeat(' ', label_w)
    let row_chars = []
    for c in range(plot_w)
      if c < len(recent)
        let rate = recent[c].frequency_per_min
        let plotted_row = s:dashboard_log_y(rate, plot_h, log_bot, log_top)
        if r == plotted_row
          call add(row_chars, rate >= eff_aim ? '●' : '○')
        elseif r == aim_row
          call add(row_chars, '·')
        else
          call add(row_chars, ' ')
        endif
      else
        call add(row_chars, r == aim_row ? '·' : ' ')
      endif
    endfor
    call add(lines, '│ ' . label . join(row_chars, '') . ' │')
  endfor
  call add(lines, '│ ' . s:pad_right(printf('last %d sessions  ·  aim line: ·  ·  ·  ·  log y-axis (rate/min)',
    \ len(recent)), label_w + plot_w) . ' │')
  call add(lines, s:panel_box_bottom(a:w))
  return lines
endfunction

" Helper used by both the hovered chart and the daily celeration
" chart to populate decade-boundary y-axis labels.
function! s:add_label_rows(label_rows, plot_h, log_bot, log_top, value) abort
  let row = s:dashboard_log_y(a:value * 1.0, a:plot_h, a:log_bot, a:log_top)
  if row >= 0 && row < a:plot_h && !has_key(a:label_rows, row)
    let a:label_rows[row] = a:value
  endif
endfunction

" Map a rate to a plot row (0 at top, plot_h-1 at bottom) using log10.
function! s:dashboard_log_y(rate, plot_h, log_bot, log_top) abort
  if a:rate <= 0 | return a:plot_h - 1 | endif
  let logr = log10(a:rate)
  let frac = (logr - a:log_bot) / (a:log_top - a:log_bot)
  let row = float2nr((1.0 - frac) * (a:plot_h - 1) + 0.5)
  return max([0, min([a:plot_h - 1, row])])
endfunction

function! s:dashboard_summary_panel(id, registry, sessions, w, h) abort
  let runs = get(a:sessions, a:id, [])
  let usable = filter(copy(runs), 'get(v:val, "frequency_per_min", 0) > 0')
  call sort(usable, {a, b -> a.timestamp ==# b.timestamp ? 0
    \ : (a.timestamp <# b.timestamp ? -1 : 1)})

  let title = 'LAST SESSION'
  let lines = [s:panel_box_top(title, a:w)]
  if empty(usable)
    call add(lines, '│' . s:pad_right(' (no sessions yet)', a:w - 2) . '│')
    call add(lines, s:panel_box_bottom(a:w))
    return lines
  endif
  let last = usable[-1]
  let date = strpart(get(last, 'timestamp', ''), 0, 10)
  let rate = string(s:round1(last.frequency_per_min))
  let aim_val = get(last, 'aim', 0)
  let dur = get(last, 'elapsed_seconds', get(last, 'duration_seconds', 0))
  let correct = get(last, 'items_correct', 0)
  let errors = string(s:round1(get(last, 'errors_per_min', 0)))
  let eff = get(last, 'efficiency_pct', 0)

  " Compact two-column layout — this panel lives in 1/4 of the
  " dashboard width, so we can't afford the wide one-line-per-stat
  " shape from the old half-width design.
  let eff_part = eff > 0 ? printf('   eff %d%%', float2nr(eff)) : ''
  let stat_rows = [
    \ printf(' %s', date),
    \ printf(' rate %s/min  ·  aim %d', rate, aim_val),
    \ printf(' %d items in %ds', correct, float2nr(dur)),
    \ printf(' errors %s/min%s', errors, eff_part),
    \ ]

  for r in stat_rows
    if len(lines) - 1 >= a:h - 1 | break | endif
    call add(lines, '│' . s:pad_right(r, a:w - 2) . '│')
  endfor
  call add(lines, s:panel_box_bottom(a:w))
  return lines
endfunction

" Render the profile panel buffer: dashboard banner at the very
" top, then four panels side-by-side. The first panel (LAST SESSION)
" is the only one that changes with the hovered row; the other three
" are aggregates over the whole training history.
"
" Session totals (total_sessions, total_elapsed) iterate over every
" entry in a:sessions, NOT just those that match a pinpoint in the
" current registry. The audit's renames left log entries under old
" pinpoint ids (e.g. 'insert_basic', 'discriminate_find_vs_till'),
" and those still count as real training time the learner spent
" even though the slug no longer maps to anything live.
function! s:dashboard_render_profile(mapping, row, registry, sessions, cols) abort
  let aim_overrides = get(s:load_settings(), 'aims', {})
  let at_aim = 0 | let climbing = 0 | let not_started = 0
  let total_pinpoints = len(a:registry)
  let by_rate = []  " [{id, ratio, rate, aim}] for non-empty pinpoints

  for [id, m] in items(a:registry)
    let runs = get(a:sessions, id, [])
    let eff_aim = get(aim_overrides, id, get(m, 'aim', 0))
    let status = s:status_from_sessions(eff_aim, runs)
    if     status ==# 'at_aim'      | let at_aim += 1
    elseif status ==# 'climbing'    | let climbing += 1
    else                            | let not_started += 1
    endif
    let usable = filter(copy(runs), 'get(v:val, "frequency_per_min", 0) > 0')
    if !empty(usable)
      let last = usable[-1]
      let rate = last.frequency_per_min
      if eff_aim > 0
        call add(by_rate, {'id': id, 'ratio': rate * 1.0 / eff_aim,
          \ 'rate': rate, 'aim': eff_aim})
      endif
    endif
  endfor

  " Aggregate over EVERY logged session — including sessions whose
  " pinpoint id no longer exists in the registry. See the function
  " docstring for the reasoning.
  let total_elapsed = 0.0
  let session_count = 0
  let by_day = {}
  for runs in values(a:sessions)
    for s in runs
      let total_elapsed += get(s, 'elapsed_seconds', 0)
      let session_count += 1
      let day = strpart(get(s, 'timestamp', ''), 0, 10)
      if !empty(day)
        let by_day[day] = get(by_day, day, 0) + 1
      endif
    endfor
  endfor

  call sort(by_rate, {a, b -> a.ratio < b.ratio ? 1 : (a.ratio > b.ratio ? -1 : 0)})
  let fastest = empty(by_rate) ? {} : by_rate[0]
  let slowest = empty(by_rate) ? {} : by_rate[-1]

  let days_back = 14
  let today_str = strftime('%Y-%m-%d')
  let today_count = get(by_day, today_str, 0)
  let streak = s:dashboard_streak(by_day, today_str)

  let banner = s:pad_right(printf('─ Vim Fluency ─── Path: General  │  %d sessions logged | %s trained ',
    \ session_count, s:format_duration(total_elapsed)), a:cols)

  let inner_w = a:cols - 2
  let panel_count = 4
  let gap = 3
  let pw = (inner_w - (panel_count - 1) * gap) / panel_count

  " Panel order: LAST SESSION (left, hover-reactive), STATUS,
  " FASTEST, NEEDS WORK. DAILY moved out to the hover row as its
  " own celeration chart.
  let hovered_id = get(a:mapping, a:row, '')
  let panel_h = s:DASHBOARD_PROFILE_HEIGHT - 2
  let panels = []
  call add(panels, s:dashboard_summary_panel(hovered_id, a:registry, a:sessions, pw, panel_h))
  call add(panels, s:dashboard_aim_panel(at_aim, climbing, not_started, total_pinpoints, total_elapsed, pw))
  call add(panels, s:dashboard_fastest_panel(fastest, pw))
  call add(panels, s:dashboard_slowest_panel(slowest, pw))

  " Profile panel rows below banner + 1 blank row.
  for p in panels
    while len(p) < panel_h | call add(p, '') | endwhile
  endfor

  let lines = [banner, '']
  for i in range(panel_h)
    let row_parts = []
    for p in panels
      call add(row_parts, s:pad_right(p[i], pw))
    endfor
    let line = ' ' . join(row_parts, repeat(' ', gap))
    call add(lines, s:pad_right(line, a:cols))
  endfor

  call s:dashboard_write_buffer(get(b:, 'vf_dashboard_profile_bufnr', -1), lines)
endfunction

function! s:dashboard_aim_panel(at, climbing, not_started, total, total_seconds, w) abort
  let lines = [s:panel_box_top('STATUS', a:w)]
  call add(lines, '│' . s:pad_right(printf(' ✓ at aim       %3d / %d', a:at, a:total), a:w - 2) . '│')
  call add(lines, '│' . s:pad_right(printf(' ▶ climbing     %3d / %d', a:climbing, a:total), a:w - 2) . '│')
  call add(lines, '│' . s:pad_right(printf(' ○ not started  %3d / %d', a:not_started, a:total), a:w - 2) . '│')
  call add(lines, s:panel_box_bottom(a:w))
  return lines
endfunction

function! s:dashboard_fastest_panel(fastest, w) abort
  let lines = [s:panel_box_top('FASTEST', a:w)]
  if empty(a:fastest)
    call add(lines, '│' . s:pad_right(' (no data)', a:w - 2) . '│')
  else
    call add(lines, '│' . s:pad_right(' ' . a:fastest.id, a:w - 2) . '│')
    call add(lines, '│' . s:pad_right(printf(' %s/min  (%d%% of aim)',
      \ string(s:round1(a:fastest.rate)), float2nr(a:fastest.ratio * 100)), a:w - 2) . '│')
  endif
  call add(lines, s:panel_box_bottom(a:w))
  return lines
endfunction

function! s:dashboard_slowest_panel(slowest, w) abort
  let lines = [s:panel_box_top('NEEDS WORK', a:w)]
  if empty(a:slowest)
    call add(lines, '│' . s:pad_right(' (no data)', a:w - 2) . '│')
  else
    call add(lines, '│' . s:pad_right(' ' . a:slowest.id, a:w - 2) . '│')
    call add(lines, '│' . s:pad_right(printf(' %s/min  (%d%% of aim)',
      \ string(s:round1(a:slowest.rate)), float2nr(a:slowest.ratio * 100)), a:w - 2) . '│')
  endif
  call add(lines, s:panel_box_bottom(a:w))
  return lines
endfunction

" Daily celeration chart: training session count per day plotted on
" a log y-axis. Same visual shape as the hovered-drill chart so the
" two panels read consistently. Days with zero training don't get a
" dot (log scale can't represent 0) — the gap itself is the cue.
function! s:dashboard_daily_chart_panel(by_day, days_back, today_count, streak, w, h) abort
  let title = printf('DAILY DRILLS (last %dd)', a:days_back)
  let lines = [s:panel_box_top(title, a:w)]

  let summary = printf(' today: %d  ·  streak: %d day%s',
    \ a:today_count, a:streak, a:streak == 1 ? '' : 's')
  call add(lines, '│' . s:pad_right(summary, a:w - 2) . '│')

  let plot_h = max([a:h - 4, 3])
  let label_w = 5
  let plot_w = a:w - 4 - label_w

  let counts = []
  for i in range(a:days_back - 1, 0, -1)
    let day = strftime('%Y-%m-%d', localtime() - i * 86400)
    call add(counts, get(a:by_day, day, 0))
  endfor

  " Same fixed Standard Celeration Chart bounds as the hovered-drill
  " chart (1..1000). The unit here is sessions-per-day rather than
  " rate/min, but the SCC philosophy is one y-axis everywhere — a
  " day with 30 sessions reads at the same vertical position
  " regardless of which chart you're looking at.
  let log_bot = 0.0
  let log_top = 3.0

  let label_rows = {}
  let lg = log_top
  while lg >= log_bot
    call s:add_label_rows(label_rows, plot_h, log_bot, log_top, float2nr(pow(10.0, lg) + 0.5))
    let lg -= 1.0
  endwhile

  " Place day-column anchors evenly across plot_w. With days_back=14
  " and plot_w >> 14 there's room to space the columns out; we
  " just centre each day in its slot.
  let col_per_day = plot_w * 1.0 / a:days_back
  let col_for_day = []
  for i in range(a:days_back)
    call add(col_for_day, float2nr(i * col_per_day + col_per_day / 2.0))
  endfor

  for r in range(plot_h)
    let label = has_key(label_rows, r)
      \ ? printf('%' . (label_w - 1) . 'd ', label_rows[r])
      \ : repeat(' ', label_w)
    let row_chars = repeat([' '], plot_w)
    for day_i in range(a:days_back)
      let n = counts[day_i]
      if n <= 0 | continue | endif
      let plotted_row = s:dashboard_log_y(n * 1.0, plot_h, log_bot, log_top)
      if r == plotted_row
        let c = col_for_day[day_i]
        if c < plot_w | let row_chars[c] = '●' | endif
      endif
    endfor
    call add(lines, '│ ' . label . join(row_chars, '') . ' │')
  endfor
  call add(lines, '│ ' . s:pad_right(printf('%dd ago' . repeat(' ',
    \ max([plot_w - 13, 0])) . 'today', a:days_back),
    \ label_w + plot_w) . ' │')
  call add(lines, s:panel_box_bottom(a:w))
  return lines
endfunction

function! s:dashboard_streak(by_day, today_str) abort
  let streak = 0
  let i = 0
  while 1
    let day = strftime('%Y-%m-%d', localtime() - i * 86400)
    if get(a:by_day, day, 0) > 0
      let streak += 1
      let i += 1
    else
      break
    endif
  endwhile
  return streak
endfunction

" Replace a panel buffer's contents without disturbing the cursor in
" the table window. Uses the buffer's number rather than walking
" windows so we can render from anywhere.
function! s:dashboard_write_buffer(bufnr, lines) abort
  if a:bufnr <= 0 | return | endif
  if !bufexists(a:bufnr) | return | endif
  let cur_winid = win_getid()
  for win in range(1, winnr('$'))
    if winbufnr(win) == a:bufnr
      execute win . 'wincmd w'
      setlocal modifiable
      silent! %delete _
      call setline(1, a:lines)
      setlocal nomodifiable nomodified
      break
    endif
  endfor
  call win_gotoid(cur_winid)
endfunction

" ──────────── small text helpers for the dashboard ────────────

function! s:panel_box_top(title, w) abort
  let title_padded = ' ' . a:title . ' '
  let dashes = repeat('─', max([a:w - len(title_padded) - 2, 0]))
  return '┌' . title_padded . dashes . '┐'
endfunction

function! s:panel_box_bottom(w) abort
  return '└' . repeat('─', a:w - 2) . '┘'
endfunction

function! s:pad_right(s, w) abort
  let l = strdisplaywidth(a:s)
  if l >= a:w
    " Trim by character so we don't split a UTF-8 sequence mid-byte
    " (the box-drawing chars in our panels are 3-byte sequences;
    " strpart would slice them into '�').
    let result = ''
    let width = 0
    for ch in split(a:s, '\zs')
      let chw = strdisplaywidth(ch)
      if width + chw > a:w | break | endif
      let result .= ch
      let width += chw
    endfor
    return result . repeat(' ', a:w - width)
  endif
  return a:s . repeat(' ', a:w - l)
endfunction

function! s:round1(f) abort
  return float2nr(a:f * 10 + 0.5) / 10.0
endfunction

function! s:format_duration(seconds) abort
  let s = float2nr(a:seconds)
  let h = s / 3600
  let m = (s % 3600) / 60
  let sec = s % 60
  if h > 0
    return printf('%dh %dm', h, m)
  elseif m > 0
    return printf('%dm %ds', m, sec)
  else
    return printf('%ds', sec)
  endif
endfunction
