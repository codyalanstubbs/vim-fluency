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
" boxed SCC :VfChart shows in its tab buffer (via s:dashboard_chart_panel),
" but addressable from headless mode (where tabnew + getline misbehaves
" under -Es). Builds a one-drill registry stub so the aim line draws from
" the session's recorded aim. Fixed 80x28 panel for deterministic output.
function! vimfluency#_test_render_chart(id, sessions) abort
  let aim = empty(a:sessions) ? 0 : get(a:sessions[0], 'aim', 0)
  let registry = {a:id: {'aim': aim}}
  return s:dashboard_chart_panel(a:id, registry, {a:id: a:sessions}, 80, 28)
endfunction

function! vimfluency#_test_build_list_view(registry, sessions_by_id, ...) abort
  let expanded = a:0 >= 1 ? a:1 : {}
  let sort_col = a:0 >= 2 ? a:2 : ''
  let sort_desc = a:0 >= 3 ? a:3 : 0
  return s:build_list_view(a:registry, a:sessions_by_id, expanded,
    \ sort_col, sort_desc)
endfunction

function! vimfluency#_test_drill_has_lesson(id) abort
  return s:drill_has_lesson(a:id)
endfunction

function! vimfluency#_test_drill_has_sessions(id) abort
  return s:drill_has_sessions(a:id)
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

" Append an entry to s:session.current_item_events with an
" auto-stamped 't' (seconds since item_started_at, rounded to 3 dp
" to match time_seconds precision). Uses extend(copy(...)) so the
" caller can reuse a literal dict across iterations without one
" mutation bleeding into the next (vim dicts are reference-typed).
function! s:item_event(entry) abort
  if !has_key(s:session, 'current_item_events') | return | endif
  let t = s:round3(reltimefloat(reltime(s:session.item_started_at)))
  call add(s:session.current_item_events,
    \ extend(copy(a:entry), {'t': t}))
endfunction

" Returns the {lines, comment} snippet dict for command-kind items
" so the on-screen scenario the learner saw is logged with the item.
" Other kinds return {} — keeps the items_log schema uniform.
function! s:scenario_capture(item) abort
  if get(s:session, 'kind', '') !=# 'command' | return {} | endif
  let snip = get(a:item, 'snippet', {})
  if empty(snip) | return {} | endif
  return {'lines': get(snip, 'lines', []),
    \ 'comment': get(snip, 'comment', '')}
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
  " Trim the trailing pad — listchars=trail:· would render it as a
  " dotted tail after the last marker.
  return [substitute(annotation, '\s\+$', '', '')]
endfunction

" Build a marker row with ▼ above every cell of the item's
" deletion_range — but only when the item opts in via
" annotate_deletion. Solves the cursor-occlusion problem: a
" single-cell deletion at the cursor position (dl, x) hides its red
" VfDeletion highlight under the cursor block, making the item look
" target-less. The ▼ row keeps the deletion position readable.
"
" Opt-in (and set on EVERY item of an opting drill, both the
" occluded and the visible direction) rather than auto-detected:
" if the row only appeared when the cursor covers the deletion,
" its mere presence would be a tell ('row visible → dl') and the
" learner would discriminate on that instead of reading the
" deletion position. Same row for every item → the position of
" the ▼ relative to the cursor is the only cue.
"
" Single-row items only, mirroring s:waypoint_annotation.
function! s:deletion_annotation(item) abort
  if !get(a:item, 'annotate_deletion', 0) | return [] | endif
  if !has_key(a:item, 'deletion_range') || empty(a:item.deletion_range)
    return []
  endif
  if empty(a:item.lines) | return [] | endif
  let llen = len(a:item.lines[0])
  " Collect deletion columns on row 1, then emit left-to-right.
  " (Column-accounted append rather than strpart splicing — the
  " multi-byte ▼ would desync byte offsets for later splices.)
  let cols = {}
  for rng in a:item.deletion_range
    if rng[0] != 1 | continue | endif
    for c in range(rng[1], rng[1] + rng[2] - 1)
      if c >= 1 && c <= llen | let cols[c] = 1 | endif
    endfor
  endfor
  if empty(cols) | return [] | endif
  let annotation = ''
  for c in range(1, llen)
    let annotation .= has_key(cols, c) ? '▼' : ' '
  endfor
  " Trim the trailing pad — the training buffer sets
  " listchars=trail:· (for whitespace-sensitive drills), which would
  " render the padding right of the last ▼ as a dotted tail.
  return [substitute(annotation, '\s\+$', '', '')]
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
" User settings — per-drill aim overrides + global default duration.
" -----------------------------------------------------------------
"
" Settings live in $XDG_DATA_HOME/vimfluency/settings.json next to the
" session log. Two fields are recognized:
"   "aims":             {drill_id → integer rate per minute}
"   "default_duration": integer seconds (applies when :VfTrain has no arg)
"
" Defaults stay in each drill's meta(); the user's overrides sit on
" top via s:effective_aim() / s:effective_duration(). Status, charts,
" the VfList view, the breakdown ✓ mark, and the runner ALL read
" through the effective helpers, so a single override propagates
" everywhere.

" Renamed drill slugs: old id → current id. Old ids keep working
" everywhere — :VfTrain/:VfLearn/:VfChart args, session history, aim
" overrides — because every read path canonicalizes through this map.
" The JSONL log on disk is never rewritten; records that carry an old
" id (or the pre-rename drill_id field's old name, pinpoint_id — see
" s:rec_id) are remapped at read time so history and charts stay
" continuous across a rename. When renaming a slug, git mv the file,
" update every in-repo reference, and add one entry here.
let s:LEGACY_IDS = {
  \ 'move_to_line_edges_beginning_end':   'move_to_line_edges_start_end',
  \ 'delete_to_line_edges_beginning_end': 'delete_to_line_edges_start_end',
  \ 'switch_btwn_many_modes':             'switch_between_many_modes',
  \ 'move_to_till_forward':               'move_to_vs_till_forward',
  \ 'move_to_till_backward':              'move_to_vs_till_backward',
  \ 'move_to_till_forward_backward':      'move_to_vs_till_forward_backward',
  \ 'move_to_till_forward_in_words':      'move_to_vs_till_forward_in_words',
  \ 'move_to_till_backward_in_words':     'move_to_vs_till_backward_in_words',
  \ 'save_quit_ex_vs_normal_zz':          'save_quit_vs_zz',
  \ 'force_quit_ex_vs_normal_zq':         'force_quit_vs_zq',
  \ }

" Map a possibly-renamed drill id to its current slug.
function! vimfluency#canonical_id(id) abort
  return get(s:LEGACY_IDS, a:id, a:id)
endfunction

" Read a drill id from a session record. Two back-compat shapes are
" tolerated: the log field was renamed pinpoint_id -> drill_id, and
" some slugs were renamed (s:LEGACY_IDS). Both are normalized here so
" logs written by older versions stay readable — the file is never
" rewritten.
function! s:rec_id(rec) abort
  let id = get(a:rec, 'drill_id', get(a:rec, 'pinpoint_id', ''))
  return get(s:LEGACY_IDS, id, id)
endfunction

" Display name from a session record, tolerating the same
" pinpoint_name -> drill_name field rename.
function! s:rec_name(rec) abort
  return get(a:rec, 'drill_name', get(a:rec, 'pinpoint_name', ''))
endfunction

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
    " Migrate aim overrides stored under renamed drill ids. An
    " override already present under the new id wins; the next
    " s:save_settings() persists the migrated keys.
    for [old, new] in items(s:LEGACY_IDS)
      if has_key(parsed.aims, old)
        if !has_key(parsed.aims, new)
          let parsed.aims[new] = parsed.aims[old]
        endif
        call remove(parsed.aims, old)
      endif
    endfor
    return parsed
  catch
    return {'aims': {}}
  endtry
endfunction

function! s:save_settings(settings) abort
  call writefile([json_encode(a:settings)], s:settings_path())
endfunction

" Effective aim for a drill = user override (if set) else meta.aim.
function! s:effective_aim(id, meta) abort
  let aims = get(s:load_settings(), 'aims', {})
  return get(aims, a:id, get(a:meta, 'aim', 0))
endfunction

" Effective default duration in seconds for :VfTrain with no explicit arg.
" Explicit duration on :VfTrain <id> N is unaffected — this is JUST the
" default when the user doesn't specify.
function! s:effective_duration() abort
  return get(s:load_settings(), 'default_duration', 60)
endfunction

" Effective current path (specialty / curriculum focus). Defaults to
" 'general' when unset. The path doesn't filter anything yet — it's
" just a display field for now; the filtering layer ships in a
" later round once the path data model is designed.
function! s:effective_path() abort
  return get(s:load_settings(), 'current_path', 'general')
endfunction

" Display-format a path slug: title-case each whitespace-separated
" word ('frontend' → 'Frontend', 'web dev' → 'Web Dev').
function! s:format_path(p) abort
  if empty(a:p) | return 'General' | endif
  let words = split(a:p, '\s\+')
  let out = []
  for w in words
    call add(out, toupper(w[0]) . tolower(strpart(w, 1)))
  endfor
  return join(out, ' ')
endfunction

" :VfSetAim <id> <rate>  — store an aim override for one drill.
function! vimfluency#set_aim(id, rate) abort
  let id = vimfluency#canonical_id(a:id)
  let registry = vimfluency#discover_drills()
  if !has_key(registry, id)
    echo 'unknown drill: ' . id . '  (try :VfList)'
    return
  endif
  let rate = str2nr(a:rate)
  if rate <= 0
    echo 'aim must be a positive integer (rate per minute)'
    return
  endif
  let settings = s:load_settings()
  if !has_key(settings, 'aims') | let settings.aims = {} | endif
  let settings.aims[id] = rate
  call s:save_settings(settings)
  echo 'aim for ' . id . ' set to ' . rate . '/min'
    \ . ' (default ' . registry[id].aim . '/min)'
endfunction

" :VfResetAim <id>  — clear the aim override for one drill.
function! vimfluency#reset_aim(id) abort
  let id = vimfluency#canonical_id(a:id)
  let registry = vimfluency#discover_drills()
  if !has_key(registry, id)
    echo 'unknown drill: ' . id . '  (try :VfList)'
    return
  endif
  let settings = s:load_settings()
  let aims = get(settings, 'aims', {})
  if !has_key(aims, id)
    echo 'no aim override set for ' . id
    return
  endif
  call remove(aims, id)
  let settings.aims = aims
  call s:save_settings(settings)
  echo 'aim override cleared for ' . id
    \ . ' (reverted to ' . registry[id].aim . '/min)'
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

" :VfSetPath <name>  — store the learner's current path/specialty.
" Validates against the discovered paths registry; unknown ids
" are rejected with a list of what's available.
function! vimfluency#set_path(...) abort
  let raw = a:0 > 0 ? a:1 : ''
  let p = tolower(substitute(raw, '^\s*\(.\{-}\)\s*$', '\1', ''))
  if empty(p)
    echo 'path cannot be empty (use :VfResetPath to go back to general)'
    return
  endif
  let paths = vimfluency#discover_paths()
  if !has_key(paths, p)
    echo 'unknown path: ' . p . '  ·  available: ' . join(sort(keys(paths)), ', ')
    return
  endif
  let settings = s:load_settings()
  let settings.current_path = p
  call s:save_settings(settings)
  echo 'path set to ' . paths[p].name
endfunction

" :VfResetPath  — clear the path override (reverts to 'general').
function! vimfluency#reset_path() abort
  let settings = s:load_settings()
  if has_key(settings, 'current_path')
    call remove(settings, 'current_path')
    call s:save_settings(settings)
  endif
  echo 'path reset to General'
endfunction

" Test accessors.
function! vimfluency#_test_effective_aim(id, meta) abort
  return s:effective_aim(a:id, a:meta)
endfunction

function! vimfluency#_test_effective_duration() abort
  return s:effective_duration()
endfunction

function! vimfluency#_test_effective_path() abort
  return s:effective_path()
endfunction

function! vimfluency#discover_drills() abort
  let registry = {}
  let files = globpath(&runtimepath, 'autoload/vimfluency/drills/*.vim', 0, 1)
  for f in files
    let mod = fnamemodify(f, ':t:r')
    let MetaFn = function('vimfluency#drills#' . mod . '#meta')
    let info = MetaFn()
    let info.module = mod
    let registry[info.id] = info
  endfor
  return registry
endfunction

function! vimfluency#complete(arglead, cmdline, cursorpos) abort
  let registry = vimfluency#discover_drills()
  return filter(sort(keys(registry)), 'v:val =~# "^" . a:arglead')
endfunction

" Path discovery mirrors drill discovery: every
" autoload/vimfluency/paths/<id>.vim that exports #meta() shows up
" in the returned dict, keyed by its declared id. Meta shape:
"   { 'id', 'name', 'description', 'include_all', 'drill_ids' }
"
" `include_all: 1` is the sentinel for the wildcard 'no curation'
" path — s:filter_registry_by_path returns the full registry
" unchanged. Without include_all, only the listed drill_ids
" survive the filter (ids that don't resolve to a current drill
" are silently dropped, so paths don't need lockstep updates when
" drills rename or retire).
function! vimfluency#discover_paths() abort
  let registry = {}
  let files = globpath(&runtimepath, 'autoload/vimfluency/paths/*.vim', 0, 1)
  for f in files
    let mod = fnamemodify(f, ':t:r')
    let meta_fn = 'vimfluency#paths#' . mod . '#meta'
    try
      execute 'runtime autoload/vimfluency/paths/' . mod . '.vim'
      let MetaFn = function(meta_fn)
      let info = MetaFn()
      let info.module = mod
      let registry[info.id] = info
    catch
      " skip malformed path files silently
    endtry
  endfor
  return registry
endfunction

" Tab-completion for :VfSetPath.
function! vimfluency#complete_path(arglead, cmdline, cursorpos) abort
  let paths = vimfluency#discover_paths()
  return filter(sort(keys(paths)), 'v:val =~? "^" . a:arglead')
endfunction

" Look up the current path's meta. When the stored slug doesn't
" match any built-in path file, we synthesize a sensible default
" so the rest of the runtime never has to special-case 'no such
" path' — the synthesized record behaves like a no-op path with
" include_all set (returns the full registry).
function! s:current_path_meta() abort
  let path_id = s:effective_path()
  let paths = vimfluency#discover_paths()
  if has_key(paths, path_id) | return paths[path_id] | endif
  return {'id': path_id, 'name': s:format_path(path_id),
    \ 'description': '', 'include_all': 1, 'drill_ids': []}
endfunction

" Return the subset of `registry` that the current path covers.
function! s:filter_registry_by_path(registry) abort
  let meta = s:current_path_meta()
  if get(meta, 'include_all', 0) | return a:registry | endif
  let filtered = {}
  for id in get(meta, 'drill_ids', [])
    if has_key(a:registry, id) | let filtered[id] = a:registry[id] | endif
  endfor
  return filtered
endfunction

" Drills the :VfList view shows — the full registry narrowed to the
" current path, matching the dashboard. (The 'general' path includes
" everything, so this is a no-op there.) Every :VfList build/rebuild
" path routes through here so a sort / aim / breakdown rebuild can't
" silently re-expand to the full registry.
function! s:list_registry() abort
  return s:filter_registry_by_path(vimfluency#discover_drills())
endfunction

" :VfPaths — list the built-in paths plus the current selection.
function! vimfluency#list_paths() abort
  let paths = vimfluency#discover_paths()
  let current = s:effective_path()
  let registry = vimfluency#discover_drills()
  for id in sort(keys(paths))
    let meta = paths[id]
    let marker = id ==# current ? '▶' : ' '
    let scope = get(meta, 'include_all', 0)
      \ ? printf('all %d drills', len(registry))
      \ : printf('%d drills', len(s:filter_registry_by_path(registry)))
    if id !=# current && !get(meta, 'include_all', 0)
      " Compute size against this specific path, not the current one.
      let scope = printf('%d drills', len(filter(copy(get(meta, 'drill_ids', [])),
        \ 'has_key(registry, v:val)')))
    endif
    echo printf('%s %-15s  %-20s  (%s)', marker, id, meta.name, scope)
  endfor
endfunction

" Human-readable family labels for navigator display. Mirrors the
" `family` value in each drill's meta(). Unknown families fall
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
let s:S_DRILL        = 3     " 'drill' column (values: drill slug, max ~38 chars)
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
let s:BD_CMD_MARK     = 5     " ✓ if command's last_rate ≥ drill aim
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
  \ ['search',            'Search'],
  \ ['substitute',        'Substitute'],
  \ ['text-object-recall', 'Text objects'],
  \ ]

" Read sessions.jsonl once, return {drill_id → list of records}.
function! s:load_sessions_grouped() abort
  let log_path = vimfluency#log_dir() . '/sessions.jsonl'
  let by_id = {}
  if !filereadable(log_path) | return by_id | endif
  for line in readfile(log_path)
    if empty(line) | continue | endif
    try
      let r = json_decode(line)
      let id = s:rec_id(r)
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
" Under the slug-based ID scheme each prereq is a specific drill
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
" drill with no (in-registry) prereqs is 0. :VfList orders each
" family foundational-first by this depth, so a drill always sorts
" after the ones it builds on (raw prereq count would misorder — a
" word motion has one prereq but is deeper than a single-char motion
" with two). The cache doubles as a cycle guard (in-progress = 0).
function! s:drill_depth(id, registry, cache) abort
  if has_key(a:cache, a:id) | return a:cache[a:id] | endif
  let a:cache[a:id] = 0
  let max_d = 0
  for prereq in get(a:registry[a:id], 'prereqs', [])
    if has_key(a:registry, prereq)
      let max_d = max([max_d, s:drill_depth(prereq, a:registry, a:cache) + 1])
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
" base characters. Auto-derived on every breakdown row; a drill can
" override per-command via meta()'s `stroke_counts: {motion → N}`.
"
" Ex commands (anything starting with ':') don't execute until the
" learner presses <Enter>, so we add 1 for that trailing keystroke.
" Without this, ':q!' counted as 5 strokes (:=2, q=1, !=2) but the
" learner actually pressed 6 keys to run it — which the stroke-rate
" column needs to know about to be honest.
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
  if !empty(a:cmd) && a:cmd[0] ==# ':' | let n += 1 | endif
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

" Sort-primary string for one drill, keyed by the user-chosen
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
" is the single source of truth for which line is which drill —
" the coordinate map is recorded as each row is emitted, never
" re-parsed from formatted text. Returns:
"   lines         — buffer lines
"   mapping       — 1-indexed line → drill id (main rows AND
"                   per-motion sub-rows, so action keys resolve from
"                   either)
"   drill_rows — sorted line numbers of MAIN rows only; j/k
"                   navigation snaps to these
" `expanded` is a dict {id: 1} of drills whose per-motion
" breakdown should be shown (toggled by B). Breakdown rows are NOT
" auto-shown — the default view is just the drill rows.
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
  let effective_aims = {}    " effective aim per drill (override or meta.aim)
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
    call s:drill_depth(id, a:registry, depth)
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
  let drill_rows = []

  " Line 1 is the dynamic fluency banner — the same one the dashboard's
  " top window shows — so :VfList and :Vf report identical path / status
  " / session stats. The dashboard discards lines 1-6 of this output
  " (it only reuses the column-header row), so this is :VfList-only.
  call add(lines, s:fluency_banner_line(a:registry, a:sessions_by_id, &columns))
  call add(lines, '')
  call add(lines, 'Move with j/k, then:  (L)earn  (T)rain  (C)hart  (B)reakdown  set (A)im  (D)uration  (P)ath  to (V)f dashboard   ·   Q closes')
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
    " 'commands' renders meta()'s `keys` field with the slash separators
    " turned into spaces (i/a/I/A → i a I A). That mangles commands whose
    " keystrokes CONTAIN a slash (/foo, :s/…/g), so those drills provide a
    " verbatim `commands_display` to opt out of the substitution.
    let commands = get(m, 'commands_display',
      \ substitute(get(m, 'keys', ''), '/', ' ', 'g'))
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
    call add(drill_rows, len(lines))

    if get(a:expanded, id, 0)
      call s:append_breakdown(lines, mapping, id, m, status_map,
        \ s:per_motion_from_sessions(get(a:sessions_by_id, id, [])),
        \ effective_aims[id])
    endif
  endfor


  return {'lines': lines, 'mapping': mapping, 'drill_rows': drill_rows}
endfunction

" Append the B-toggle breakdown for one expanded drill. Two
" sub-sections, in order:
"   prereqs:   every in-registry prereq, ▶/✓/○ icon + name only
"   commands:  per-command sub-table — last_rate, stroke_count, and
"              stroke_rate (last_rate / strokes); ✓ if the command's
"              last_rate ≥ drill aim
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
  let registry = vimfluency#discover_drills()
  if empty(registry)
    echo 'no drills built — see CATALOG.md'
    return
  endif
  " Narrow to the current path, like the dashboard. (No-op on 'general'.)
  let registry = s:filter_registry_by_path(registry)
  " Reuse an open list if there is one — a second vf-list tab would
  " cross-wire the shared machinery: the `keepalt file vf-list` rename
  " fails silently on the duplicate, and bufnr('vf-list-header') in
  " s:apply_view / cleanup resolves to the FIRST list's header.
  let list_bufnr = bufnr('vf-list')
  if list_bufnr > 0
    for t in range(1, tabpagenr('$'))
      if index(tabpagebuflist(t), list_bufnr) >= 0
        execute 'tabnext ' . t
        for win in range(1, winnr('$'))
          if winbufnr(win) == list_bufnr
            execute win . 'wincmd w'
            break
          endif
        endfor
        call s:apply_view(s:build_list_view(registry,
          \ s:load_sessions_grouped(), get(b:, 'vf_list_expanded', {}),
          \ get(b:, 'vf_list_sort_col', ''), get(b:, 'vf_list_sort_desc', 0)))
        return
      endif
    endfor
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
" data slice, and translate view.mapping / view.drill_rows (keyed
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
  let drill_rows = []
  for r in a:view.drill_rows
    let dr = r - s:HEADER_COUNT
    if dr >= 1 | call add(drill_rows, dr) | endif
  endfor
  return {'header_lines': header_lines, 'data_lines': data_lines,
    \ 'mapping': mapping, 'drill_rows': drill_rows}
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
  let b:vf_list_drill_rows = split.drill_rows
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
  let &l:statusline = ' drill list   [L=Learn  T=Train  C=Chart  V=Dashboard  B=Breakdown  A=Aim  D=Duration  P=Path  s+col=Sort  Q=close]'
  let b:vf_summary_tabnr = tabnr
  let b:vf_summary_prev_laststatus = &laststatus
  let b:vf_list_line_to_id    = split.mapping
  let b:vf_list_drill_rows = split.drill_rows
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

  " Action keys: L=lesson, T=train, C=chart, B=toggle breakdown,
  " V=jump to the dashboard (on the hovered drill), P=switch path.
  nnoremap <buffer> <silent> L :call vimfluency#list_action('learn')<CR>
  nnoremap <buffer> <silent> T :call vimfluency#list_action('train')<CR>
  nnoremap <buffer> <silent> C :call vimfluency#list_action('chart')<CR>
  nnoremap <buffer> <silent> V :call vimfluency#list_action('dashboard')<CR>
  nnoremap <buffer> <silent> B :call vimfluency#list_toggle_breakdown()<CR>
  nnoremap <buffer> <silent> A :call vimfluency#list_set_aim()<CR>
  nnoremap <buffer> <silent> D :call vimfluency#list_set_duration()<CR>
  nnoremap <buffer> <silent> P :call vimfluency#list_set_path()<CR>
  nnoremap <buffer> <silent> Q :call vimfluency#close_summary()<CR>
  " Lowercase q kept as a silent alias for muscle memory; Q is the
  " documented key (uppercase nav keys everywhere — see s:show_end_screen).
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

  " Drill-only navigation. j/k snap between MAIN rows (no
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

  " Land cursor on the first drill row.
  let first_line = empty(split.drill_rows) ? 1 : split.drill_rows[0]
  call cursor(first_line, 1)
endfunction

" Drill-only cursor movement inside the :VfList buffer. Snaps to
" the next/prev row in b:vf_list_drill_rows; at the ends, stays
" put (no wrap, matches standard vim's no-wrap-by-default posture).
function! vimfluency#list_move(action) abort
  if !exists('b:vf_list_drill_rows') | return | endif
  let rows = b:vf_list_drill_rows
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

" Invoked by the buffer-local L/T/C mappings. Reads the drill id
" off the cursor line, confirms the action can actually proceed, then
" closes the list tab and launches it.
"
" The pre-flight check matters: close_summary() destroys the list tab,
" so if we closed first and the action then no-op'd (Chart on a
" drill with no logged sessions, Learn on a drill with no
" lesson), the list would vanish with only a fleeting message. Check
" before closing so a no-op leaves the list intact with a hint.
function! vimfluency#list_action(action) abort
  if !exists('b:vf_list_line_to_id') | return | endif
  let id = get(b:vf_list_line_to_id, line('.'), '')

  " View-to-view cross-links (the dashboard ⇆ list hop) don't need a
  " drill row — they navigate to a whole view. The hovered id, when
  " present, lets the dashboard land on the matching row. This is what
  " closes the navigation loop: from either home view you can reach the
  " other (and from there charts / trainings / lessons / the end
  " screen, which all link back here).
  if a:action ==# 'list' || a:action ==# 'dashboard'
    call vimfluency#close_summary()
    if a:action ==# 'list'
      call vimfluency#list()
    else
      call vimfluency#dashboard(id)
    endif
    return
  endif

  if empty(id)
    echo 'cursor must be on a drill row'
    return
  endif

  if a:action ==# 'chart' && !s:drill_has_sessions(id)
    echo 'no sessions logged yet for ' . id . ' — train it first (T)'
    return
  endif
  if a:action ==# 'learn' && !s:drill_has_lesson(id)
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

" True if sessions.jsonl has at least one record for this drill.
" Mirrors the filter vimfluency#chart uses to decide it has data.
function! s:drill_has_sessions(id) abort
  let grouped = s:load_sessions_grouped()
  return has_key(grouped, a:id) && !empty(grouped[a:id])
endfunction

" True if the drill module exports a #lesson() function.
function! s:drill_has_lesson(id) abort
  let registry = vimfluency#discover_drills()
  if !has_key(registry, a:id) | return 0 | endif
  return exists('*vimfluency#drills#' . registry[a:id].module . '#lesson')
endfunction

" True when B would show something useful: either the last session has
" 2+ motions to break down, or the drill declares at least one
" in-registry prereq whose status the user can drill into. A
" single-motion session with no prereqs just restates the row's
" last_rate, so B stays a no-op there.
function! s:drill_has_breakdown(id) abort
  let registry = vimfluency#discover_drills()
  let meta = get(registry, a:id, {})
  let prereqs = filter(copy(get(meta, 'prereqs', [])),
    \ 'has_key(registry, v:val)')
  let grouped = s:load_sessions_grouped()
  let pm = s:per_motion_from_sessions(get(grouped, a:id, []))
  return !empty(prereqs) || len(pm) >= 2
endfunction

" B toggles the breakdown for the drill under the cursor — per-motion
" rates from the last session AND a prereq status sub-list. Rebuilds
" the whole buffer (cheap — a few dozen lines) with the expanded set
" updated, then restores the cursor to the same drill.
function! vimfluency#list_toggle_breakdown() abort
  if !exists('b:vf_list_line_to_id') | return | endif
  let id = get(b:vf_list_line_to_id, line('.'), '')
  if empty(id)
    echo 'cursor must be on a drill row'
    return
  endif
  if !has_key(b:vf_list_expanded, id) && !s:drill_has_breakdown(id)
    echo 'nothing to break down for ' . id
      \ . ' (no prereqs, and no multi-motion session yet)'
    return
  endif
  if has_key(b:vf_list_expanded, id)
    call remove(b:vf_list_expanded, id)
  else
    let b:vf_list_expanded[id] = 1
  endif

  let registry = s:list_registry()
  let view = s:build_list_view(registry, s:load_sessions_grouped(),
    \ b:vf_list_expanded,
    \ get(b:, 'vf_list_sort_col', ''),
    \ get(b:, 'vf_list_sort_desc', 0))
  call s:apply_view(view)
  " Restore the cursor to the toggled drill's main row.
  for row in b:vf_list_drill_rows
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
" Cursor stays on the SAME Nth drill row across the resort — it
" does NOT follow the drill id. So if you sort and your row's
" drill moves to the bottom, the cursor stays put and the row
" underneath you changes.
function! vimfluency#list_sort(col) abort
  if !exists('b:vf_list_line_to_id') | return | endif

  " Find which Nth drill row the cursor is on (or just past, when
  " sitting on a breakdown sub-row under that drill).
  let cur_line = line('.')
  let cur_idx = -1
  for i in range(len(b:vf_list_drill_rows))
    if b:vf_list_drill_rows[i] <= cur_line
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

  let registry = s:list_registry()
  let view = s:build_list_view(registry, s:load_sessions_grouped(),
    \ b:vf_list_expanded, b:vf_list_sort_col, b:vf_list_sort_desc)
  call s:apply_view(view)
  if cur_idx >= 0 && cur_idx < len(b:vf_list_drill_rows)
    call cursor(b:vf_list_drill_rows[cur_idx], 1)
  elseif !empty(b:vf_list_drill_rows)
    call cursor(b:vf_list_drill_rows[0], 1)
  endif
endfunction

" Rebuild the VfList buffer in place and keep the cursor on the same
" drill id. Used after :A / :D updates so the user's eye stays on
" the row they just modified, even if the row moves under the current
" sort.
function! s:rebuild_list_buffer_keeping_drill(id) abort
  let registry = s:list_registry()
  let view = s:build_list_view(registry, s:load_sessions_grouped(),
    \ b:vf_list_expanded,
    \ get(b:, 'vf_list_sort_col', ''),
    \ get(b:, 'vf_list_sort_desc', 0))
  call s:apply_view(view)
  for row in b:vf_list_drill_rows
    if get(b:vf_list_line_to_id, row, '') ==# a:id
      call cursor(row, 1)
      return
    endif
  endfor
  if !empty(b:vf_list_drill_rows)
    call cursor(b:vf_list_drill_rows[0], 1)
  endif
endfunction

" A on a drill row → prompt for an aim. Positive int sets the
" override; 0 (or empty Esc) cancels; if the user types 0 AND there's
" an existing override, it's cleared (so the same key handles set and
" reset without separate bindings).
function! vimfluency#list_set_aim() abort
  if !exists('b:vf_list_line_to_id') | return | endif
  let id = get(b:vf_list_line_to_id, line('.'), '')
  if empty(id)
    echo 'cursor must be on a drill row'
    return
  endif
  let registry = vimfluency#discover_drills()
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
  call s:rebuild_list_buffer_keeping_drill(id)
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

let s:pending_demo = {}
let s:pending_learn_demo = {}

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
    echo 'usage: :VfTrain <id> [duration] [only=motion[,motion...]]'
    return
  endif
  let id = vimfluency#canonical_id(positional[0])
  " Duration precedence: explicit arg > user's global default > 60s.
  if len(positional) >= 2 && positional[1] !~# '^[1-9]\d*$'
    echo 'duration must be a positive number of seconds, got: ' . positional[1]
    return
  endif
  let duration = len(positional) >= 2
    \ ? str2nr(positional[1])
    \ : s:effective_duration()
  let only_filter = has_key(kwargs, 'only')
    \ ? filter(split(kwargs.only, ','), '!empty(v:val)') : []

  let registry = vimfluency#discover_drills()
  if !has_key(registry, id)
    echo 'unknown drill: ' . id . '  (try :VfList)'
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
    \ 'current_item_events': [],
    \ 'current_item': {},
    \ 'item_started_at': reltime(),
    \ 'advancing': 0,
    \ 'target_match_id': -1,
    \ 'header_offset': 0,
    \ 'deletion_match_id': -1,
    \ 'waypoint_match_ids': [],
    \ 'prev_laststatus': &laststatus,
    \ 'prev_ttimeoutlen': &ttimeoutlen,
    \ 'prev_cpoptions': &cpoptions,
    \ 'prev_clipboard': &clipboard,
    \ 'prev_search': @/,
    \ }
  " ttimeoutlen is what gates how long vim waits after Esc / Ctrl+[
  " to see if a function-key sequence is starting. Default is 100ms
  " (newer vim) or -1=timeoutlen=1000ms (older). That delay is what
  " makes the to-Normal transition feel laggy in mode_switch — the
  " ModeChanged event can't fire until vim commits to interpreting
  " the byte as Esc. Drop it to 10ms during the session and restore
  " in vimfluency#stop.
  set ttimeoutlen=10
  " Repeat-find drills (; / ,) depend on the modern t/T-repeat
  " behavior: ; after t{c} skips to the NEXT match even though the
  " cursor sits one cell before the current one. The vi-compat
  " cpoptions ';' flag breaks that (; sticks in place), which would
  " freeze a t-repeat item — it could never be credited. cpoptions
  " is global-only, so strip ';' for the session and restore in
  " vimfluency#stop. Harmless for non-t drills (f/F/;/, are
  " unaffected by the flag).
  set cpoptions-=;
  " Neutralize 'clipboard' for the session: with unnamed / unnamedplus the
  " unnamed register aliases * / +, so drill yanks (yy/dd/x) would clobber
  " the user's system clipboard, and paste drills couldn't pre-seed @"
  " (p/P would read the empty/stale clipboard → "Nothing in register").
  " Empty it here; restored in vimfluency#stop.
  set clipboard=

  " Self-driving demo: flag the session so a paced timer (below) plays
  " it. NOTE: items are still random per render — byte-identical
  " re-renders would need the generators to thread an explicit rand()
  " seed list (vim's srand(N) does NOT seed the argless rand()). Not
  " required for correctness: auto-play solves whatever item appears.
  if !empty(s:pending_demo)
    let s:session.demo = 1
    let s:pending_demo = {}
  endif

  call s:setup_window()
  call s:next_item()
  call s:install_autocmds()
  let s:session.timer = timer_start(200, function('s:on_tick'), {'repeat': -1})
  if get(s:session, 'demo', 0)
    " Feed the canonical motion for each item on a paced timer; the
    " normal CursorMoved credit path does the rest, so the preview
    " scores honestly. Per-item keys are set in s:next_item.
    let s:session.demo_timer = timer_start(320, function('s:demo_tick'), {'repeat': -1})
  endif
endfunction

" -----------------------------------------------------------------
" Self-driving demo mode (content / preview generation)
" -----------------------------------------------------------------
" :VfDemo <id> [duration] runs a real training session, but the plugin
" performs the optimal motion for each item itself — so previews score
" honestly (the rate climbs) for content/GIFs. Prototype scope: motion
" drills whose expected_motion is a single repeatable key pressed
" optimal_motions times (w/b word motions are the worked example).
" Other kinds simply don't auto-play yet (the session waits as usual).
function! vimfluency#demo(...) abort
  if !empty(s:session)
    echo 'a session is already active; :VfQuit first'
    return
  endif
  if a:0 < 1
    echo 'usage: :VfDemo <id> [duration]'
    return
  endif
  let s:pending_demo = {'on': 1}
  if a:0 >= 2
    call vimfluency#start(a:1, a:2)
  else
    call vimfluency#start(a:1)
  endif
endfunction

" :VfLearnDemo <id> — auto-play a whole lesson for preview GIFs. Sets a
" pending flag that vimfluency#learn consumes to start the lesson demo
" timer. Dev-only / undocumented, like :VfDemo. Lessons never write the
" session log, so there's no data to guard here.
function! vimfluency#learn_demo(...) abort
  if !empty(s:session)
    echo 'a session is already active; :VfQuit first'
    return
  endif
  if a:0 < 1
    echo 'usage: :VfLearnDemo <id>'
    return
  endif
  let s:pending_learn_demo = {'on': 1}
  call vimfluency#learn(a:1)
endfunction

" The demo solution for one item: a keystroke plan {seq, feed, ...} that
" s:demo_tick plays back, paced one unit per tick so every motion is
" VISIBLE in a preview GIF (not bursted between frames). Each kind credits
" through a different mechanism, so the feed strategy differs:
"   'step'   — motion: play the path a chunk at a time via :normal!
"              (curswant-faithful — feedkeys from a timer loses the desired
"              column, landing j/k in column 1). Credit via s:on_change,
"              since :normal! in a timer doesn't fire CursorMoved.
"   'repeat' — editing: first walk the visible j/k navigation to the
"              operation row, then apply the operator (via :normal!) until
"              the buffer matches the target. The navigation is part of the
"              drilled skill (e.g. delete_char_vs_line), so it is performed,
"              not skipped with a silent cursor jump.
"   'type'   — insert (mode kind): feed the entry key then the payload one
"              char per tick via feedkeys (real insert mode — :normal! 'i…'
"              would auto-exit before the payload lands). Natural
"              TextChangedI credits; the runner Escs on credit. The learner
"              sees the text typed in, char by char.
"   'burst'  — command / visual: a short mode-changing solve fired whole
"              (the cmdline result / selection shows immediately).
" mode_switch is driven separately (s:demo_tick_mode_switch).
function! s:demo_solution(item) abort
  let kind = get(s:session, 'kind', 'motion')
  let em = get(a:item, 'expected_motion', '')
  let opt = get(a:item, 'optimal_motions', 1)

  if kind ==# 'command'
    " ':...' submits through the fake cmdline and needs <CR>; ZZ/ZQ run
    " straight off the normal-mode map. Fed with remaps on (the ':' and
    " ZZ/ZQ buffer maps must fire) — see s:demo_play_burst.
    return {'seq': em[0] ==# ':' ? em . "\<CR>" : em, 'feed': 'burst'}
  endif

  if kind ==# 'visual_motion'
    " expected_motion already encodes the v/V/<C-v> prefix and the motion
    " (e.g. 'vl'); the runner feeds <C-\><C-n> itself once it credits.
    return {'seq': em, 'feed': 'burst'}
  endif

  if kind ==# 'mode'
    " Insert-family: entry key (i/a/I/A/o/O) + the payload the drill
    " expects typed, derived from the item so we never hard-code it.
    return {'seq': em . s:demo_insert_payload(a:item), 'feed': 'type'}
  endif

  if kind ==# 'editing'
    " expected_motion is the literal operator keystrokes (dw, >>, x, dd,
    " <C-r>, ...). Most editing items operate at the cursor's start row;
    " the discrimination drills (delete_char_vs_line) deliberately start
    " the cursor on a DIFFERENT line than the one to operate on — flagged
    " by a single-line deletion_range on another row. The j/k hop to that
    " row is part of the drilled skill, so the demo walks it visibly as
    " `nav` (rather than jumping the cursor there silently).
    let dr = get(a:item, 'deletion_range', [])
    let op_row = (len(dr) == 1 && dr[0][0] != a:item.start[0])
      \ ? dr[0][0] : a:item.start[0]
    let drow = op_row - a:item.start[0]
    let nav = drow == 0 ? '' : repeat(drow > 0 ? 'j' : 'k', abs(drow))
    return {'seq': s:demo_feedable(em), 'feed': 'repeat', 'nav': nav}
  endif

  " Search motions (* # / ?) credit through the search register @/, which
  " the runner's search-credit gate reads. They MUST be fed through the
  " main loop (feed 'burst' = feedkeys), NOT played via :normal! like the
  " other motions: vim saves and restores @/ around a timer callback (a
  " background timer must not disturb editor state), so a search run inside
  " the demo tick has its @/ side-effect discarded and never credits.
  "   * / #  — search the word under the cursor (sets @/ = \<word\>).
  "   / / ?  — a typed pattern: the target cell's whole word, submitted
  "            with <CR> (a short pattern would stop on a fo* look-alike
  "            decoy, so type the whole word).
  if em ==# '*' || em ==# '#'
    return {'seq': em, 'feed': 'burst'}
  endif
  if (em ==# '/' || em ==# '?') && has_key(a:item, 'target')
    let tcol = a:item.target[1]
    let line = a:item.lines[a:item.target[0] - 1]
    let word = matchstr(line[tcol - 1 :], '^\S\+')
    return {'seq': em . word . "\r", 'feed': 'burst'}
  endif

  " motion (default): a list of keystroke atoms played one (or a chunk)
  " per tick via :normal!. An atom is one complete motion, so a multi-char
  " motion (ge/g_, or a primed find like 'fx') is never split mid-key.
  if has_key(a:item, 'solve')
    " Drill-provided plan for motions the demo can't synthesize from
    " start→target — repeat-find/till, where the expert primes with
    " f/t/F/T then repeats with ;/, (two visible jumps via the waypoint).
    return {'atoms': a:item.solve, 'feed': 'step'}
  endif
  " Char-search motions (f/F/t/T): one jump straight to the target. The
  " search char is read off the item by universal vim semantics — f/F land
  " ON the char (at the target), t/T land one cell short (the char sits
  " just past the landing). Without this they'd fall to the hjkl crawl
  " below, hiding the single find that IS the skill.
  if em =~# '^[fFtT]$' && has_key(a:item, 'target')
    let tc = a:item.target[1]
    let line = a:item.lines[a:item.target[0] - 1]
    if em ==# 't'
      let ch = line[tc]          " forward till stops one before the char
    elseif em ==# 'T'
      let ch = line[tc - 2]      " backward till stops one after the char
    else                          " f / F land on the char itself
      let ch = line[tc - 1]
    endif
    return {'atoms': [em . ch], 'feed': 'step'}
  endif
  " gg lands on the buffer's ABSOLUTE first line. In a lesson (fills_buffer
  " drills, header_offset > 0) that's the prompt header, not the first
  " content line, so the lesson remaps gg -> a counted (header_offset+1)G
  " to reach content top. The demo plays motions with :normal! (no remap),
  " which bypasses that map — so translate gg the same way here. In training
  " header_offset is 0, where this reduces to 1G (== gg). (G needs no fixup:
  " the content is the last thing in the buffer, so G's last line already is
  " the last content line.)
  if em ==# 'gg'
    return {'atoms': [(get(s:session, 'header_offset', 0) + 1) . 'G'], 'feed': 'step'}
  endif
  " A single feedable key, repeated optimal_motions times. Includes the
  " whole-file jump G (one press lands on the last line).
  if em =~# '^[hjklwbeWBE0$^G]$' || em ==# 'ge' || em ==# 'g_'
    return {'atoms': repeat([em], opt), 'feed': 'step'}
  endif
  " Otherwise synthesize a start→target hjkl path. expected_motion is NOT
  " always a feedable key — the 4-way char drill labels diagonals 'diag'
  " with optimal_motions = Manhattan distance.
  if has_key(a:item, 'start') && has_key(a:item, 'target')
    let drow = a:item.target[0] - a:item.start[0]
    let dcol = a:item.target[1] - a:item.start[1]
    return {'atoms': repeat([drow > 0 ? 'j' : 'k'], abs(drow))
      \ + repeat([dcol > 0 ? 'l' : 'h'], abs(dcol)), 'feed': 'step'}
  endif
  return {'atoms': [], 'feed': 'step'}
endfunction

" Translate a display token into feedable keys. expected_motion is a
" human-readable label in a few drills (undo_redo's redo is the literal
" five-char string '<C-r>', not the keycode).
function! s:demo_feedable(token) abort
  if a:token ==# '<C-r>' | return "\<C-r>" | endif
  return a:token
endfunction

" The text an insert-family (mode-kind) item expects typed, derived from
" the item rather than read from the drill's private constant. At
" enter_at_row the line grows from target_lines[row] to
" target_lines_after_type[row] by a pure insertion at enter_at_col; the
" inserted run is the payload. Works uniformly for i/a/I/A (insert into
" an existing line) and o/O (the opened blank line, where the "before"
" line is '' and enter_at_col is 1).
function! s:demo_insert_payload(item) abort
  let row = get(a:item, 'enter_at_row', 1)
  let col = get(a:item, 'enter_at_col', 1)
  let after_lines = get(a:item, 'target_lines_after_type', [])
  let before_lines = get(a:item, 'target_lines', get(a:item, 'lines', []))
  if row > len(after_lines) | return '' | endif
  let after = after_lines[row - 1]
  let before = row <= len(before_lines) ? before_lines[row - 1] : ''
  let n = len(after) - len(before)
  if n <= 0 | return '' | endif
  return strpart(after, col - 1, n)
endfunction

function! s:demo_tick(timer) abort
  if empty(s:session) | return | endif
  if get(s:session, 'advancing', 0) | return | endif
  call s:demo_dispatch()
endfunction

" Play the current item one tick's worth, routed by the loaded feed
" strategy. Shared by the training tick (s:demo_tick) and the lesson tick
" (s:learn_demo_tick) — both call s:demo_load to install demo_atoms/feed
" for the current item first, so this just performs it.
function! s:demo_dispatch() abort
  " mode_switch is a mode state machine, not a keystroke sequence.
  if get(s:session, 'kind', 'motion') ==# 'mode_switch'
    call s:demo_tick_mode_switch()
    return
  endif
  let feed = get(s:session, 'demo_feed', 'step')
  if feed ==# 'type'
    call s:demo_play_type()
  elseif feed ==# 'burst'
    call s:demo_play_burst()
  elseif feed ==# 'repeat'
    call s:demo_play_editing()
  else
    call s:demo_play_motion()
  endif
endfunction

" Credit the just-performed motion/editing item through the right path —
" the lesson runner and the training runner have separate credit
" functions. (type/burst/mode_switch feeds credit through their own
" installed autocmds, so they don't call this.)
function! s:demo_credit() abort
  if get(s:session, 'mode', 'train') ==# 'learn'
    call s:learn_on_change()
  else
    call s:on_change()
  endif
endfunction

" A monotonic "did the current item just get credited?" probe — training
" bumps items_correct, the lesson sets frame_complete. The play functions
" compare this before/after a credit attempt to decide whether to stall.
function! s:demo_progress() abort
  return get(s:session, 'mode', 'train') ==# 'learn'
    \ ? get(s:session, 'frame_complete', 0)
    \ : get(s:session, 'items_correct', 0)
endfunction

" Load the demo solution for one item into the session (demo_atoms /
" demo_seq / demo_feed / demo_nav / demo_step_chunk, and reset the
" per-item anchor + stall). Called by s:next_item (training) and the
" lesson tick (per try-frame / test-item). mode_switch derives its
" keystrokes live from mode() each tick, so it needs no queued sequence.
function! s:demo_load(item) abort
  let s:session.demo_anchored = 0
  let s:session.demo_stall = 0
  if s:session.kind ==# 'mode_switch'
    let s:session.demo_atoms = []
    let s:session.demo_feed = 'step'
    return
  endif
  let sol = s:demo_solution(a:item)
  let s:session.demo_feed = sol.feed
  if sol.feed ==# 'step'
    let s:session.demo_atoms = sol.atoms
    let s:session.demo_step_chunk = max([1, len(sol.atoms) / 6])
  else
    let s:session.demo_seq = sol.seq
    let s:session.demo_nav = get(sol, 'nav', '')
  endif
endfunction

" -----------------------------------------------------------------
" Lesson auto-play (:VfLearnDemo) — drives a whole :VfLearn lesson on a
" timer for preview GIFs: reads each show frame, performs each try frame's
" canonical motion, applies the rule through the test phase to graduation,
" and lands on the end screen. Reuses the training demo's solution +
" play machinery (s:demo_load / s:demo_dispatch, crediting via the
" lesson path through s:demo_credit); this driver only adds the
" frame/Space advancement and the setup→test→complete walk.
" -----------------------------------------------------------------
function! s:learn_demo_tick(timer) abort
  if empty(s:session) || get(s:session, 'mode', '') !=# 'learn' | return | endif
  if get(s:session, 'advancing', 0) | return | endif
  let phase = get(s:session, 'phase', '')
  if phase ==# 'complete'
    " Lesson graduated — the end screen is up. Stop driving.
    if has_key(s:session, 'learn_demo_timer')
      call timer_stop(s:session.learn_demo_timer)
      unlet s:session.learn_demo_timer
    endif
    return
  endif
  " A credited try frame / test item shows "✓ Press <Space>" — advance it
  " (a learner would press Space; we call the advance handler directly).
  if get(s:session, 'frame_complete', 0)
    call s:learn_advance_show()
    return
  endif
  " Pick the current item to perform.
  let item = {}
  if phase ==# 'setup'
    if s:session.frame_idx >= len(s:session.frames) | return | endif
    let frame = s:session.frames[s:session.frame_idx]
    if get(frame, 'kind', '') ==# 'show'
      call s:learn_advance_show()          " read it, move on
      return
    endif
    let item = frame                        " a try frame
  elseif phase ==# 'test'
    let item = get(s:session, 'current_test_item', {})
  endif
  " Motion / editing / visual frames anchor the play at item.start. The
  " keystroke-only kinds don't: command frames credit on the typed Ex
  " command (per-frame fake cmdline), and mode / mode_switch frames credit
  " on reaching a target mode — none carry a cursor target, so none have a
  " 'start'. Require 'start' only for the anchored kinds; without this the
  " lesson demo returns here every tick and the lesson never graduates.
  if empty(item) | return | endif
  if !has_key(item, 'start')
    \ && index(['command', 'mode', 'mode_switch', 'recall'],
    \          get(s:session, 'kind', 'motion')) < 0
    return
  endif
  " (Re)load the solution when the item changes; current_item is what the
  " play functions + s:demo_anchor read.
  let key = phase . ':' . s:session.frame_idx . ':'
    \ . get(s:session, 'test_items_seen', 0)
  if get(s:session, 'learn_demo_key', '') !=# key
    let s:session.learn_demo_key = key
    let s:session.current_item = item
    call s:demo_load(item)
  endif
  call s:demo_dispatch()
endfunction

" Anchor the cursor at item.start once per item. Between s:next_item and
" the first tick the cursor can settle off-row (a CursorMoved repaint), so
" a vertical/synth motion path or an o/O entry would start from the wrong
" place. Subsequent ticks leave the cursor where the played keys put it.
function! s:demo_anchor() abort
  if get(s:session, 'demo_anchored', 0) | return | endif
  let it = s:session.current_item
  call cursor(s:session.header_offset + it.start[0], it.start[1])
  let s:session.demo_anchored = 1
endfunction

" Stuck-item escape: a step/type item whose keys ran out (or an operator
" that never matched) without crediting — a rare off-by-one on some item.
" Skip after a few grace ticks so one bad item doesn't freeze the preview;
" the rate keeps climbing on the items that do solve.
function! s:demo_stall_skip() abort
  if get(s:session, 'mode', 'train') !=# 'train' | return | endif
  let s:session.demo_stall = get(s:session, 'demo_stall', 0) + 1
  if s:session.demo_stall >= 3
    let s:session.demo_stall = 0
    call s:skip()
  endif
endfunction

" motion: play the next chunk of atoms (1 for short motions — a visible
" walk — more for far targets so they don't crawl) via :normal!. :normal!
" not feedkeys: a motion fed async from a timer loses curswant, so j/k land
" in column 1.
"
" Crediting is deferred by one tick: we play the path to exhaustion, and
" only on the FOLLOWING tick (cursor now resting on the target, that frame
" already rendered) call s:on_change to credit and advance. Without the
" pause a single-jump motion (f/t/$/gg/…) lands on the target and credits
" inside one tick — no frame ever shows the cursor on the target, so the
" jump is invisible in the preview. The pause makes every landing visible.
function! s:demo_play_motion() abort
  " Only in Normal mode — else a fed key lands in a cmdline the tape opened
  " to type :VfQuit, corrupting it.
  if mode() !=# 'n' | return | endif
  let atoms = get(s:session, 'demo_atoms', [])
  if !empty(atoms)
    let s:session.demo_stall = 0
    call s:demo_anchor()
    let chunk = get(s:session, 'demo_step_chunk', 1)
    let take = atoms[0 : chunk - 1]
    let s:session.demo_atoms = atoms[chunk :]
    execute 'normal! ' . join(take, '')
    return
  endif
  " Path exhausted — the cursor landed on the target a tick ago (that frame
  " was rendered, so the jump/walk is visible). Credit now; if it didn't
  " land (a rare off-by-one), skip after a few grace ticks.
  let before = s:demo_progress()
  call s:demo_credit()
  if s:demo_progress() == before
    call s:demo_stall_skip()
  endif
endfunction

" editing: walk the visible j/k navigation first, then apply the operator
" until the buffer matches the target. Both via :normal! + s:on_change
" (feedkeys from a timer mis-fires operators into operator-pending across
" the tick gap; CursorMoved doesn't fire for :normal! in a timer).
function! s:demo_play_editing() abort
  if mode() !=# 'n' | return | endif
  let nav = get(s:session, 'demo_nav', '')
  if !empty(nav)
    execute 'normal! ' . nav[0]
    let s:session.demo_nav = nav[1:]
    call s:demo_credit()
    return
  endif
  let item = s:session.current_item
  if getline(s:session.header_offset + 1, '$')
    \ ==# get(item, 'target_lines', item.lines)
    return
  endif
  " Anchor at the operation site (after the navigation we're already here,
  " so no visible jump). delete_char_vs_line's op row differs from start;
  " every other editing drill operates at start. Keep the start column.
  let dr = get(item, 'deletion_range', [])
  let row = (len(dr) == 1 && dr[0][0] != item.start[0])
    \ ? dr[0][0] : item.start[0]
  call cursor(s:session.header_offset + row, item.start[1])
  let before = s:demo_progress()
  execute 'normal! ' . s:session.demo_seq
  call s:demo_credit()
  " If applying the operator didn't credit, count it toward a stall so a
  " never-matching item can't loop forever. A credit resets the per-item
  " state, so only genuine no-progress ticks accumulate.
  if s:demo_progress() == before
    call s:demo_stall_skip()
  endif
endfunction

" insert (mode kind): type the entry key then the payload one char per
" tick via feedkeys (real insert mode — :normal! 'i…' would auto-exit
" before the payload lands), letting the natural InsertEnter / TextChangedI
" autocmds credit. The runner Escs back to Normal on credit.
function! s:demo_play_type() abort
  let seq = get(s:session, 'demo_seq', '')
  if empty(seq) | call s:demo_stall_skip() | return | endif
  let s:session.demo_stall = 0
  " Don't feed a real cmdline (tape typing :VfQuit); insert mode is fine.
  if mode() ==# 'c' | return | endif
  call s:demo_anchor()
  call feedkeys(seq[0], 'n')
  let s:session.demo_seq = seq[1:]
endfunction

" command / visual: a short mode-changing solve fired whole; remaps ON so
" the command kind's ':' / ZZ buffer maps fire. Natural autocmds credit.
function! s:demo_play_burst() abort
  let seq = get(s:session, 'demo_seq', '')
  if empty(seq) | return | endif
  if mode() ==# 'c' | return | endif
  let s:session.demo_seq = ''
  call feedkeys(seq, 'm')
endfunction

" mode_switch auto-play: drive vim's mode toward the item's target one
" keystroke at a time. The runner credits the instant mode() matches, so
" we just take the single step that makes progress and let the next tick
" re-evaluate against the freshly-generated target.
function! s:demo_tick_mode_switch() abort
  let target = get(s:session.current_item, 'target_mode_canon', 'n')
  let now = s:mode_canonical(mode(1))
  if now ==# target | return | endif        " already there — wait for advance
  if now !=# 'n'
    " Leave the current mode first. Don't disturb a non-empty cmdline —
    " that's the tape typing a real command (e.g. :VfQuit), not the empty
    " ':' we open for a c-target item.
    if now ==# 'c' && !empty(getcmdline()) | return | endif
    call feedkeys("\<Esc>", 'n')
    return
  endif
  " In Normal: press the one key that enters the target mode. ':' opens
  " the real cmdline (credited via CmdlineEnter), leaving us in 'c'; the
  " next item's first tick <Esc>s back out.
  call feedkeys(get({'i': 'i', 'v': 'v', 'r': 'R', 'c': ':'}, target, ''), 'n')
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
  " No max() here: Floats in max()/min() need vim 9.1 (E805 before).
  let remaining = s:session.duration - elapsed
  if remaining < 0 | let remaining = 0.0 | endif
  let rate = elapsed > 0 ? s:session.items_correct * 60.0 / elapsed : 0.0
  let filter_tag = empty(get(s:session, 'only_filter', []))
    \ ? '' : ' [only=' . join(s:session.only_filter, ',') . ']'
  return printf(' %s — %s%s   time %ds   correct %d   rate %.1f/min   aim %d/min   [Tab=skip :VfQuit=quit]',
    \ s:session.id, s:session.name, filter_tag,
    \ float2nr(remaining), s:session.items_correct, rate, s:session.aim)
endfunction

function! s:next_item() abort
  let s:session.advancing = 1
  let GenFn = function('vimfluency#drills#' . s:session.module . '#generate')
  let item = {}
  let attempts = 0
  let cur_canon = s:session.kind ==# 'mode_switch' ? s:mode_canonical(mode(1)) : ''
  " Anti-streak guard: reject candidates whose expected_motion would
  " make the streak of identical commands hit 3. Drills randomize
  " each call independently — without this, a 2-command drill rolls
  " 4-5 of the same command in a row often enough to feel mechanical,
  " especially when the on-screen scenario is static (save/quit).
  " The constraint relaxes after STREAK_GIVEUP attempts so degenerate
  " filter combinations (e.g. only=:w on a multi-cmd drill) still
  " return an item.
  let recent = get(s:session, 'recent_motions', [])
  let STREAK_GIVEUP = 50
  while attempts < 100
    let item = GenFn()
    let cand = get(item, 'expected_motion', '')
    let filter_ok = empty(s:session.only_filter)
      \ || index(s:session.only_filter, cand) >= 0
    " mode_switch needs target != current (otherwise the user has
    " nothing to do, and we don't want the same target twice in a row).
    let mode_ok = s:session.kind !=# 'mode_switch'
      \ || get(item, 'target_mode_canon', '') !=# cur_canon
    " Streak check is the LAST gate so the explicit filters win. Two
    " identical motions queued → reject a third. Skipped past
    " STREAK_GIVEUP so we can't infinite-loop on a sole-survivor.
    let streak_ok = attempts >= STREAK_GIVEUP
      \ || len(recent) < 2
      \ || cand !=# recent[-1]
      \ || cand !=# recent[-2]
    if filter_ok && mode_ok && streak_ok
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
  " Push the chosen motion onto the recent-history ring (cap at 2 —
  " we only need the last two for the streak check).
  let recent = get(s:session, 'recent_motions', [])
  call add(recent, get(item, 'expected_motion', ''))
  if len(recent) > 2 | call remove(recent, 0, len(recent) - 3) | endif
  let s:session.recent_motions = recent
  let s:session.current_item = item
  let s:session.item_started_at = reltime()
  let s:session.current_item_motions = 0
  let s:session.current_item_events = []
  " Initial state for the dedupe guard in s:on_change. The deferred
  " CursorMoved that fires after our cursor() call below sees this
  " same state and is skipped as a duplicate. Subsequent presses
  " produce distinct states and increment the count.
  let s:session.last_event_state = [item.start, copy(item.lines)]

  " Demo mode: queue the solution s:demo_tick performs for this item.
  " Set here, before the per-kind render branches that return early
  " (recall / command / mode / mode_switch), so every kind gets it.
  if get(s:session, 'demo', 0)
    call s:demo_load(item)
  endif

  " Recall and mode kinds have their own item-rendering paths; they share
  " bookkeeping with motion/editing but the buffer layout and credit
  " trigger differ enough that branching here is cleaner than a unified
  " render.
  if s:session.kind ==# 'recall'
    call s:render_recall_item(item)
    let s:session.advancing = 0
    return
  endif
  if s:session.kind ==# 'command'
    call s:render_command_item(item)
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
    " ▶◀ seam indicator for before/after-a-char editing drills (the
    " charwise p/P paste drill). Empty for items without enter_at_col.
    let ind = s:mode_gap_indicator(item)
    if !empty(ind) | call add(header, ind) | endif
  endif
  " Waypoint annotation row sits at the END of the header (just above the
  " content) so the deferred-fire guard's cur_lines comparison still
  " excludes it via header_offset. Same scaffolding as in lessons —
  " training sessions need it too so the learner can disambiguate ; vs , scenarios
  " for items where cursor sits between two char occurrences.
  let header += s:waypoint_annotation(item)
  let header += s:deletion_annotation(item)
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
  call s:seed_register(item)

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  " When a deletion_range cue is present (editing-kind deletes, and the
  " change-kind tag drills that delete-then-insert) the red range alone
  " tells the learner what to do; drawing a green target both makes the
  " discrimination "is green visible?" instead of "where is red?" AND
  " leaks the answer — green at the inner-content vs whole-block start
  " column would distinguish dit/dat (cit/cat) for free. So suppress
  " green whenever red is shown. Motion-kind sessions (no deletion_range)
  " still get the green cell since that's the entire cue.
  " show_target lets a buffer-changing drill opt back into the green cell
  " when the target IS the cue (the paste family: no red range, the green
  " marks where the copied text should land).
  if (s:session.kind !=# 'editing' || get(item, 'show_target', 0))
    \ && (!has_key(item, 'deletion_range') || empty(item.deletion_range))
    let s:session.target_match_id = matchaddpos('VfTarget',
      \ get(item, 'target_full_line', 0)
      \   ? [[s:session.header_offset + item.target[0]]]
      \   : [[s:session.header_offset + item.target[0], item.target[1], 1]], 20)
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
  if s:session.kind ==# 'command'
    " Same story for command kind: ':', ZZ, ZQ, <Tab> are all
    " buffer-local mappings installed per-render. No autocmds to
    " hook here.
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
    " Escape hatch: :VfQuit executes for real so the learner can end
    " the session — every other ex command is cancelled.
    cnoremap <buffer> <expr> <CR> getcmdtype() ==# ':' && getcmdline() =~# '^VfQuit\>' ? "\<CR>" : "\<C-c>"
    nnoremap <buffer> <silent> <Tab> :call <SID>skip()<CR>
    " Jumplist escape hatch — see the matching <C-o> block in the
    " general-kind branch below for the full rationale.
    nnoremap <buffer> <silent> <C-o> <Nop>
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
      " Opt-in: when the drill declares credit_on_text_typed,
      " the training credits the moment the buffer matches
      " target_lines_after_type (the post-typing target). The
      " learner doesn't have to press Esc — the leave-mode
      " keystroke is drilled separately in switch_mode_to_insert.
      " Each typed char fires TextChangedI so motion counting stays
      " honest. The o/O caveat above doesn't apply here because no
      " current credit_on_text_typed drill uses o/O.
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
  " Ctrl-O walks the jumplist, which still holds pre-session
  " positions — inside the training buffer it jumps to a stale
  " location (reads as 'top-left corner') and a second press
  " escapes the session entirely. There IS no meaningful
  " in-session jumplist (f/F/t/T/hjkl don't set entries), so
  " block it. (<C-i> needs no map: terminals fold it into <Tab>,
  " which is already the skip key.)
  nnoremap <buffer> <silent> <C-o> <Nop>
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
  " Detect a buffer change against the prior state (pure motion items
  " keep cur_lines == start_lines forever, editing items vary it).
  " prev_lines comes from the dedupe state; first event compares
  " against start_lines via the init in s:next_item.
  let prev_state = get(s:session, 'last_event_state', [cur_pos, start_lines])
  let buf_changed = cur_lines !=# prev_state[1]
  let s:session.last_event_state = new_state

  let s:session.current_item_motions += 1
  if buf_changed
    call s:item_event({'kind': 'text', 'pos': cur_pos,
      \ 'lines_hash': sha256(join(cur_lines, "\n"))[:6]})
  else
    call s:item_event({'kind': 'cursor', 'pos': cur_pos})
  endif

  if s:session.kind ==# 'visual_motion'
    " Credit when the learner is in the right visual sub-mode AND
    " their selection's anchor + cursor positions match the item's
    " expected range. getpos('v') is the visual-mode anchor (where v
    " / V / Ctrl-V was pressed); outside visual mode it falls back to
    " the cursor position, so the mode() gate MUST run first.
    " s:mode_canonical is deliberately NOT called — v-family drills
    " discriminate the sub-modes that the canonical collapses.
    let expected_mode = get(item, 'expected_sub_mode', 'v')
    if mode(1) ==# expected_mode
      let v_pos = getpos('v')
      let anchor = [v_pos[1] - header_offset, v_pos[2]]
      let exp_start = get(item, 'expected_selection_start', item.start)
      let exp_end   = get(item, 'expected_selection_end',   item.target)
      if anchor == exp_start && cur_pos == exp_end
        " +1 for the v / V / Ctrl-V keystroke that put the learner
        " into visual mode. That keystroke didn't move the cursor
        " (mode change only) so it never fired CursorMoved and
        " current_item_motions never counted it. Without this fixup
        " a perfect run scored actual=1 vs optimal=2 → 200%
        " efficiency per item, distorting the session average.
        " Known limitation: multiple v-presses in one item (e.g. v,
        " Esc, v, l) only count once — accurate tracking of
        " mode-toggle keystrokes would require ModeChanged hooks
        " and is deferred.
        let s:session.current_item_motions += 1
        " Queue an "exit any mode → normal" before crediting. Without
        " this the learner stays in visual mode after credit, and the
        " next training item (or the lesson's Space-advance prompt)
        " sees their keystrokes as visual-mode motions instead of
        " normal-mode commands. <C-\><C-n> is vim's idempotent
        " "drop to normal from anywhere"; 'n' flag = no remap.
        call feedkeys("\<C-\>\<C-n>", 'n')
        call s:credit_item()
      endif
    endif
    return
  endif

  if cur_lines ==# target_lines && cur_pos == item.target && s:search_ok(item)
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
    \ 'events': copy(s:session.current_item_events),
    \ 'snippet': s:scenario_capture(item),
    \ 'goal': get(item, 'goal', ''),
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
  " Block jumplist-back (stale pre-session entries escape the buffer).
  nnoremap <buffer> <silent> <C-o> <Nop>
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
  call s:item_event({'kind': 'key', 'k': a:c})
  call s:recall_repaint()
  call s:recall_check_match()
endfunction

function! s:recall_backspace() abort
  if empty(s:session) || s:session.advancing | return | endif
  if !has_key(s:session, 'input_row') | return | endif
  call s:recall_increment_motions()
  call s:item_event({'kind': 'bs'})
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
" Command kind — live-buffer Ex/normal-mode command capture
"
" The learner reads a status header + goal above a realistic
" code/text snippet and types the matching vim command (Ex form
" like :wq or normal-mode shortcut like ZZ). We intercept the
" keystrokes via buffer-local mappings so the command never
" actually executes — vim doesn't quit, the snippet doesn't get
" written, but the LEARNER's experience is "I pressed :wq<Enter>
" and the screen advanced." Free-operant: wrong commands echo a
" hint and the learner keeps going without an auto-fail.
" -----------------------------------------------------------------

" Render a command item. Header (status + goal + divider) above the
" snippet; cursor parks in the snippet area. Buffer is nomodifiable
" so the learner can't accidentally edit the "file" they're staring
" at. Command capture mappings are installed every render — they're
" buffer-local but the buffer is reused across items, so re-mapping
" is a no-op once they're in place.
function! s:render_command_item(item) abort
  let snippet = get(a:item, 'snippet', {'lines': [], 'comment': '#'})
  let goal    = get(a:item, 'goal', '')
  " Buffer is just the snippet with a single language-appropriate
  " comment line at the top that states the goal. No status banner,
  " no divider — the snippet is the scenario, the comment is the
  " cue.
  let header = [vimfluency#scenarios#goal_comment(snippet, goal)]
  let s:session.header_offset = len(header)
  setlocal modifiable
  silent! %delete _
  call setline(1, header + snippet.lines)
  setlocal nomodifiable nomodified
  call cursor(len(header) + 1, 1)
  call s:install_command_maps()
  redraw
endfunction

" Buffer-local key intercepts. ':' opens our fake cmdline (input())
" so the user feels like they're typing an Ex command but vim never
" sees it as one to execute. ZZ / ZQ are captured as normal-mode
" shortcuts the same way real vim sees them. Tab skips; <C-c>
" inside input() cancels cleanly.
function! s:install_command_maps() abort
  nnoremap <buffer> <silent> : :call <SID>command_fake_cmdline()<CR>
  nnoremap <buffer> <silent> ZZ :call <SID>command_check('ZZ')<CR>
  nnoremap <buffer> <silent> ZQ :call <SID>command_check('ZQ')<CR>
  nnoremap <buffer> <silent> <Tab> :call <SID>skip()<CR>
  " Block jumplist-back (stale pre-session entries escape the buffer).
  nnoremap <buffer> <silent> <C-o> <Nop>
endfunction

" input('-style fake cmdline. The leading ':' prompt makes it look
" visually identical to real vim cmdline. Empty input (user pressed
" <CR> or <Esc> without typing) silently aborts — same as cancelling
" a real :w typo.
function! s:command_fake_cmdline() abort
  let cmd = input(':')
  redraw
  " The session timer keeps ticking while input() is pending — the
  " session may have ended (stop on timeout) before input returned.
  if empty(s:session) | return | endif
  if empty(cmd) | return | endif
  " Escape hatch: :VfQuit always passes through to the real handler
  " so the learner can stop the drill even though every other ':'
  " command gets captured rather than executed.
  if cmd =~# '^VfQuit\>'
    execute cmd
    return
  endif
  call s:command_check(':' . cmd)
endfunction

" Credit-or-reject for a typed command. Counts every attempt's
" keystrokes against the motion total so multi-attempt items
" register the inefficiency (per-motion stats stay honest).
" Branches on mode/phase like s:recall_check_match.
function! s:command_check(typed) abort
  if empty(s:session) | return | endif
  let s:session.current_item_motions
    \ = get(s:session, 'current_item_motions', 0) + len(a:typed)
  let mode = get(s:session, 'mode', 'train')
  if mode ==# 'train'
    let item = s:session.current_item
  elseif get(s:session, 'phase', '') ==# 'test'
    let item = s:session.current_test_item
    let s:session.test_motion_count
      \ = get(s:session, 'test_motion_count', 0) + len(a:typed)
  else
    let frame = s:session.frames[s:session.frame_idx]
    if frame.kind !=# 'try' | return | endif
    let item = frame
  endif
  let expected = get(item, 'expected_motion', '')
  call s:item_event({'kind': 'command', 'k': a:typed,
    \ 'ok': a:typed ==# expected ? v:true : v:false})
  if a:typed !=# expected
    redraw
    echohl WarningMsg
    echo printf('  typed %s — check the Goal and try again', a:typed)
    echohl None
    return
  endif

  " Buffer-transforming commands (substitute) leave no visual trace on
  " their own — the command is captured, not executed. When the item
  " carries the post-command snippet, paint it so the learner SEES the
  " result. It survives the lesson's ✓ repaint (which only rewrites the
  " header line); in training the next item renders over it immediately.
  if has_key(item, 'after_lines')
    \ && win_getid() == get(s:session, 'you_win', -1)
    setlocal modifiable
    call setline(s:session.header_offset + 1, item.after_lines)
    setlocal nomodifiable
  endif

  if mode ==# 'train'
    call s:credit_item()
    return
  endif

  " Lesson: same frame-complete + streak update path the recall
  " match uses, so the lesson runner can advance / repaint without
  " caring whether the answer arrived via cnoremap or input().
  let s:session.frame_complete = 1
  if get(s:session, 'phase', '') ==# 'test'
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
" Pre-load the unnamed register from an item's register_payload, charwise
" — for paste drills that credit p/P without making the learner yank
" first (the yank is taught in the lesson intro). No-op for other items.
function! s:seed_register(item) abort
  if has_key(a:item, 'register_payload')
    call setreg('"', a:item.register_payload, 'c')
  endif
  " Clear @/ for search drills so a STALE pattern (from a prior item, or
  " the user's pre-session search) can't satisfy the search-credit check.
  " Only a fresh search in THIS item should count — this is what defeats
  " a counted word motion (2w) landing on the same cell.
  if !empty(get(a:item, 'expected_search', '')) || get(a:item, 'requires_search', 0)
    call setreg('/', '')
  endif
endfunction

" Search drills credit only when a real search happened this item — a
" motion like 2w that lands on the same cell leaves @/ untouched (and it
" was cleared at item start). Two modes:
"   expected_search — @/ must equal this EXACT pattern (*/# set \<word\>).
"   requires_search — @/ just has to be non-empty (typed /pattern, where
"                     the learner chooses the pattern).
" Everything else (no search fields) is always ok.
function! s:search_ok(item) abort
  let want = get(a:item, 'expected_search', '')
  if !empty(want)
    return getreg('/') ==# want
  endif
  if get(a:item, 'requires_search', 0)
    return !empty(getreg('/'))
  endif
  return 1
endfunction

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
" exactly the pedagogy the drill demands. The cnoremap that
" defangs <CR> in cmdline is session-wide (installed once in
" s:install_autocmds), not per-press.
function! s:on_cmdline_enter_train() abort
  if empty(s:session) | return | endif
  " Global autocmd — never credit (or repaint) from another window,
  " where setline() would clobber a real buffer.
  if win_getid() != get(s:session, 'you_win', -1) | return | endif
  if get(s:session, 'advancing', 0) | return | endif
  let target = get(s:session.current_item, 'target_mode_canon', '')
  if target !=# 'c' | return | endif
  let s:session.current_item_motions = s:mode_switch_strokes('c')
  call s:item_event({'kind': 'mode', 'to': 'c'})
  call s:credit_item()
endfunction

function! s:check_mode_for_credit(...) abort
  if empty(s:session) | return | endif
  " Global autocmd / polling timer — never credit (or repaint) from
  " another window, where setline() would clobber a real buffer.
  if win_getid() != get(s:session, 'you_win', -1) | return | endif
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
    call s:item_event({'kind': 'mode', 'to': canon})
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
  " Global autocmd — never credit from another window (see the
  " training twin above).
  if win_getid() != get(s:session, 'you_win', -1) | return | endif
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
  " Global autocmd / polling timer — never credit from another window
  " (see the training twin above).
  if win_getid() != get(s:session, 'you_win', -1) | return | endif
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
      let s:session.wrongs = 0
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
  let header += s:deletion_annotation(a:item)
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
  " Deletion-range red for mode-kind drills that delete-then-insert
  " (cit/cat) — same cue as the editing renderer. Plain insert drills
  " (i/a/o) carry no deletion_range, so this is a no-op for them. The
  " InsertEnter handler clears it again the moment the change fires, so
  " the fixed-position highlight never lingers over the shifted text.
  if has_key(a:item, 'deletion_range') && !empty(a:item.deletion_range)
    let positions = []
    for pos in a:item.deletion_range
      call add(positions,
        \ [s:session.header_offset + pos[0], pos[1], pos[2]])
    endfor
    let s:session.deletion_match_id = matchaddpos('VfDeletion', positions, 10)
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
  " Clear the deletion-range red the moment insert begins: for the
  " change tag drills (cit/cat) the marked text has just been deleted,
  " so the fixed-position highlight would otherwise sit stale over the
  " shifted-left remainder while the learner types the replacement.
  " No-op for plain insert drills (i/a/o carry no deletion_range).
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
  let header_offset = s:session.header_offset
  let s:session.insert_entered = 1
  let s:session.insert_enter_pos = [line('.') - header_offset, col('.')]
  let s:session.current_item_motions += 1
  call s:item_event({'kind': 'insert_enter', 'pos': s:session.insert_enter_pos})
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
  call s:item_event({'kind': 'insert_leave'})
  " For credit_on_text_typed drills, credit is exclusively the
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
" in insert mode for drills with credit_on_text_typed set. Mirrors
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
  call s:item_event({'kind': 'text_typed_i',
    \ 'lines_hash': sha256(join(cur_lines, "\n"))[:6]})
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
  " Train-only: lessons share the recall/command key maps that bind
  " <Tab> here, but a learn session has none of the fields below.
  if empty(s:session) || get(s:session, 'mode', 'train') !=# 'train'
    return
  endif
  if s:session.advancing | return | endif
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
    \ 'events': copy(s:session.current_item_events),
    \ 'snippet': s:scenario_capture(item),
    \ 'goal': get(item, 'goal', ''),
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
  if has_key(s:session, 'demo_timer')
    call timer_stop(s:session.demo_timer)
  endif
  call s:stop_mode_polling()
  silent! augroup VfTrain | autocmd! | augroup END

  " No min() here: Floats in max()/min() need vim 9.1 (E805 before).
  let elapsed = reltimefloat(reltime(s:session.started_at))
  if elapsed > s:session.duration
    let elapsed = s:session.duration * 1.0
  endif
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

  " Hits = correct items the learner solved with no wasted motions
  " (actual ≤ optimal). Misses = wasted motions + skips, both treated
  " as the same per-minute "miss" rate the SCC convention plots.
  " Logged separately from items_correct so the dashboard can show
  " hits_rate / miss_rate without recomputing from items_log.
  let items_hit = 0
  for it in s:session.items_log
    if get(it, 'outcome', '') ==# 'correct'
      \ && get(it, 'actual_motions', 0) <= get(it, 'optimal_motions', 0)
      let items_hit += 1
    endif
  endfor
  let hits_per_min = elapsed > 0 ? items_hit * 60.0 / elapsed : 0.0
  let miss_per_min = elapsed > 0
    \ ? (wasted + s:session.items_skipped) * 60.0 / elapsed : 0.0

  let record = {
    \ 'timestamp': strftime('%Y-%m-%dT%H:%M:%S'),
    \ 'drill_id': s:session.id,
    \ 'drill_name': s:session.name,
    \ 'aim': s:session.aim,
    \ 'duration_seconds': s:session.duration,
    \ 'elapsed_seconds': s:round3(elapsed),
    \ 'items_correct': s:session.items_correct,
    \ 'items_skipped': s:session.items_skipped,
    \ 'items_hit': items_hit,
    \ 'frequency_per_min': s:round3(rate),
    \ 'hits_per_min': s:round3(hits_per_min),
    \ 'miss_per_min': s:round3(miss_per_min),
    \ 'errors_per_min': s:round3(errors_per_min),
    \ 'total_motions': s:session.total_motions,
    \ 'total_optimal_motions': s:session.total_optimal_motions,
    \ 'efficiency_pct': s:round3(efficiency_pct),
    \ 'end_reason': a:reason,
    \ 'only_filter': s:session.only_filter,
    \ 'per_motion': per_motion_out,
    \ 'items': s:session.items_log,
    \ }
  " Demo sessions (:VfDemo) are auto-played at superhuman speed — they
  " must NEVER touch the real session log or the contributed dataset.
  " A failed write must not abort teardown — the session would stay
  " marked active with the tab open and laststatus unrestored.
  if !get(s:session, 'demo', 0)
    try
      call writefile([json_encode(record)], vimfluency#log_dir() . '/sessions.jsonl', 'a')
    catch
      echohl WarningMsg
      echom 'vimfluency: could not write session log: ' . v:exception
      echohl None
    endtry
  endif

  " Post-session flow: land on the shared end screen (see
  " s:show_end_screen), which shows this drill's last-session
  " frequency + breakdown and offers single-key navigation to every
  " other view. We reuse the training window in place rather than
  " closing the tab — the training tab is a single-window scratch
  " buffer, so s:show_end_screen repurposes it (mirrors the lesson
  " path in s:learn_show_complete).
  let prev_laststatus = s:session.prev_laststatus
  let prev_ttimeoutlen = get(s:session, 'prev_ttimeoutlen', &ttimeoutlen)
  let prev_cpoptions = get(s:session, 'prev_cpoptions', &cpoptions)
  let prev_clipboard = get(s:session, 'prev_clipboard', &clipboard)
  let prev_search = get(s:session, 'prev_search', @/)
  let you_win = get(s:session, 'you_win', -1)
  let drill_id = record.drill_id
  let s:session = {}

  let &ttimeoutlen = prev_ttimeoutlen
  let &cpoptions = prev_cpoptions
  let &clipboard = prev_clipboard
  let @/ = prev_search
  " Restore the user's laststatus FIRST so the end screen captures it
  " as the value to put back when the learner finally quits the screen.
  let &laststatus = prev_laststatus
  if you_win > 0 && win_id2tabwin(you_win)[0] > 0
    call win_gotoid(you_win)
  endif
  call s:show_end_screen(drill_id, 'train')
endfunction

" Shared completion screen for both :VfTrain and :VfLearn. Renders the
" drill's last-session frequency + per-motion breakdown (the same
" LAST SESSION panel the dashboard draws) plus an empty-state nudge
" when nothing's been trained yet — a brand-new learner reaching this
" via :VfLearn always hits that case — and a single-key navigation
" menu to every other view.
"
" The caller has already torn down its session and parked the cursor
" in the just-finished session's window (a single-window nofile/
" bufhidden=wipe scratch tab in both the train and lesson paths). We
" repurpose that buffer in place: clear its buffer-local maps across
" every mode (the lesson installs a cmdline <CR> defang we must drop
" so ':' commands work here) and rewrite the lines. origin is 'train'
" or 'learn' and only changes the heading.
function! s:show_end_screen(id, origin) abort
  let registry = vimfluency#discover_drills()
  let sessions = s:load_sessions_grouped()
  let meta = get(registry, a:id, {})
  let name = get(meta, 'name', a:id)
  let runs = get(sessions, a:id, [])
  let has_data = !empty(filter(copy(runs),
    \ 'get(v:val, "frequency_per_min", 0) > 0'))

  " The caller reused the just-finished session's window. Two pieces of
  " that session's state would otherwise bleed into the end screen:
  "  - clearmatches(): the training's VfTarget (green) / VfDeletion
  "    (red) cursor-target highlights are window-local matchadd()s, so
  "    without clearing them they keep painting over the end screen.
  "  - <C-\><C-n>: a session can end (timer expiry, :VfQuit) while the
  "    learner is mid-Insert/Visual on a mode / insert drill. Forcing
  "    Normal first means their next keystrokes fire the nav maps
  "    instead of typing into the top line of the end-screen buffer.
  "    (feedkeys queues it; it runs after this function returns, before
  "    the user can type.)
  silent! call clearmatches()
  silent! call feedkeys("\<C-\>\<C-n>", 'n')

  silent! mapclear <buffer>
  silent! imapclear <buffer>
  silent! cmapclear <buffer>
  silent! vmapclear <buffer>
  setlocal modifiable nolist nocursorline
  silent! execute 'keepalt file vf-complete'
  silent! %delete _

  " w/h=58/2: the panel renders its full body with zero padding when
  " h is 2 (it only pads UP to h-1, never truncates) — exact fit.
  let w = 58
  let panel = s:dashboard_last_session_breakdown_panel(
    \ a:id, registry, sessions, w, 2)
  let head = a:origin ==# 'learn' ? 'LESSON COMPLETE' : 'SESSION COMPLETE'
  let lines = [printf('  %s — %s', head, name), '']
  call extend(lines, map(copy(panel.lines), '"  " . v:val'))
  call add(lines, '')
  if !has_data
    call add(lines, '  No training sessions recorded for this drill yet —')
    call add(lines, '  press  T  to train and log your first rate.')
    call add(lines, '')
  endif
  " Navigation keys are uppercase everywhere (matching the dashboard /
  " :VfList convention: L=Learn, T=Train, C=Chart).
  call add(lines, '  Where to next?')
  call add(lines, printf('    T   %-21s:VfTrain %s', 'train this drill', a:id))
  call add(lines, printf('    L   %-21s:VfLearn %s', 'learn this drill', a:id))
  call add(lines, printf('    C   %-21s:VfChart %s', 'chart your progress', a:id))
  call add(lines, printf('    I   %-21s:VfList', 'open the drill list'))
  call add(lines, printf('    V   %-21s:Vf', 'open the dashboard'))
  call add(lines, '    Q   quit')
  call setline(1, lines)
  setlocal nomodifiable nomodified
  call cursor(1, 1)

  let b:vf_end_id = a:id
  let b:vf_end_prev_laststatus = &laststatus
  let &l:statusline = ' Vim Fluency   [T=Train  L=Learn  C=Chart  I=List  V=Dashboard  Q=Quit]'
  set laststatus=2

  nnoremap <buffer> <silent> T :call vimfluency#end_nav('train')<CR>
  nnoremap <buffer> <silent> L :call vimfluency#end_nav('learn')<CR>
  nnoremap <buffer> <silent> C :call vimfluency#end_nav('chart')<CR>
  nnoremap <buffer> <silent> I :call vimfluency#end_nav('list')<CR>
  nnoremap <buffer> <silent> V :call vimfluency#end_nav('dashboard')<CR>
  nnoremap <buffer> <silent> Q :call vimfluency#end_nav('quit')<CR>
  " Lowercase q kept as a silent alias for muscle memory (also stops a
  " bare q from starting macro recording on this read-only buffer).
  nnoremap <buffer> <silent> q :call vimfluency#end_nav('quit')<CR>
endfunction

" Navigation from the shared end screen. Closes the end-screen tab
" (or blanks it when it's the only tab open) and dispatches to the
" chosen view. Each destination command opens its own tab.
function! vimfluency#end_nav(action) abort
  let id = get(b:, 'vf_end_id', '')
  let prev_ls = get(b:, 'vf_end_prev_laststatus', &laststatus)
  if tabpagenr('$') > 1
    silent! tabclose
  else
    silent! enew
  endif
  let &laststatus = prev_ls
  if a:action ==# 'train'
    call vimfluency#start(id)
  elseif a:action ==# 'learn'
    call vimfluency#learn(id)
  elseif a:action ==# 'chart'
    call vimfluency#chart(id)
  elseif a:action ==# 'list'
    call vimfluency#list()
  elseif a:action ==# 'dashboard'
    call vimfluency#dashboard(id)
  endif
endfunction

" Close the list/chart/dashboard tab the cursor is in. b:vf_summary_tabnr
" is only a sentinel marking the buffer as ours — the mapping that calls
" this is buffer-local, so the CURRENT tab is always the right one to
" close (stored tab numbers go stale when other tabs open/close).
function! vimfluency#close_summary() abort
  if exists('b:vf_summary_tabnr')
    let prev_ls = b:vf_summary_prev_laststatus
    silent! tabclose
    let &laststatus = prev_ls
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
  let filter_id = a:0 >= 1 ? vimfluency#canonical_id(a:1) : ''
  let log_path = vimfluency#log_dir() . '/sessions.jsonl'
  if !filereadable(log_path)
    echo 'no sessions logged yet (' . log_path . ')'
    return
  endif

  let records = []
  for line in readfile(log_path)
    if empty(line) | continue | endif
    try
      let rec = json_decode(line)
      " A JSON-valid line that isn't a session record (hand-edited
      " log, older schema) must not crash the whole listing. s:rec_id
      " also resolves the legacy pinpoint_id field and renamed slugs,
      " so we stamp the normalized id back onto the record for the
      " grouping and filtering below.
      if type(rec) == type({})
        let rid = s:rec_id(rec)
        if !empty(rid)
          let rec.drill_id = rid
          call add(records, rec)
        endif
      endif
    catch
      " skip malformed line
    endtry
  endfor

  if !empty(filter_id)
    call filter(records, 'get(v:val, "drill_id", "") ==# filter_id')
    if empty(records)
      echo 'no sessions for drill ' . filter_id
      return
    endif
  endif

  if empty(records)
    echo 'no sessions logged yet'
    return
  endif

  " group by drill_id, chronological order preserved (file is append-only)
  let groups = {}
  let order = []
  for r in records
    if !has_key(groups, r.drill_id)
      let groups[r.drill_id] = []
      call add(order, r.drill_id)
    endif
    call add(groups[r.drill_id], r)
  endfor

  echo printf('vimfluency history — %d session(s) across %d drill(s)',
    \ len(records), len(groups))
  for pid in sort(order)
    let g = groups[pid]
    " Defensive field access: older or hand-edited records may lack
    " fields, and numbers may round-trip as Number or Float — the
    " 1.0* / float2nr coercions keep printf's %f and %d happy.
    let aim = float2nr(1.0 * get(g[0], 'aim', 0))
    let name = !empty(s:rec_name(g[0])) ? s:rec_name(g[0]) : pid
    let n = len(g)
    let first_rate = 1.0 * get(g[0], 'frequency_per_min', 0)
    let last_rate = 1.0 * get(g[-1], 'frequency_per_min', 0)

    let header = printf(' %s — %s   aim %d/min   n=%d', pid, name, aim, n)
    if n >= 2 && first_rate > 0
      let mult = last_rate / first_rate
      let header .= printf('   first→last ×%.2f', mult)
    endif
    echo ''
    echo header
    for r in g
      let ts = substitute(get(r, 'timestamp', ''), 'T', ' ', '')
      let rrate = 1.0 * get(r, 'frequency_per_min', 0)
      echo printf('   %s  %5.1f/min  %s  correct %2d  skipped %d',
        \ ts, rrate,
        \ s:rate_bar(rrate, aim),
        \ float2nr(1.0 * get(r, 'items_correct', 0)),
        \ float2nr(1.0 * get(r, 'items_skipped', 0)))
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
    echo 'usage: :VfLearn <drill_id>'
    return
  endif
  let id = vimfluency#canonical_id(a:1)
  let registry = vimfluency#discover_drills()
  if !has_key(registry, id)
    echo 'unknown drill: ' . id
    return
  endif
  let info = registry[id]
  let lesson_fn = 'vimfluency#drills#' . info.module . '#lesson'
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
    \ 'fills_buffer': get(info, 'fills_buffer', 0),
    \ 'allowed_keys': get(info, 'allowed_keys', ''),
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
    \ 'prev_ttimeoutlen': &ttimeoutlen,
    \ 'prev_cpoptions': &cpoptions,
    \ 'prev_clipboard': &clipboard,
    \ 'prev_search': @/,
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
  " See vimfluency#start: strip the cpoptions ';' flag so ; / , after
  " a t/T find skip to the next match instead of sticking. Restored
  " in vimfluency#learn_stop.
  set cpoptions-=;
  " See vimfluency#start: neutralize 'clipboard' so drill yanks don't
  " clobber the system clipboard and paste drills can pre-seed @".
  " Restored in vimfluency#learn_stop.
  set clipboard=

  call s:learn_setup_window()
  call s:learn_show_frame()
  call s:learn_install_autocmds()

  " :VfLearnDemo — drive the lesson on a paced timer for preview GIFs.
  if !empty(s:pending_learn_demo)
    let s:pending_learn_demo = {}
    let s:session.demo = 1
    let s:session.learn_demo_key = ''
    let s:session.learn_demo_timer =
      \ timer_start(350, function('s:learn_demo_tick'), {'repeat': -1})
  endif
endfunction

function! s:learn_setup_window() abort
  tabnew
  let s:session.tabnr = tabpagenr()
  let s:session.you_win = win_getid()
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal list listchars=trail:·,nbsp:·
  setlocal shiftwidth=4 softtabstop=4 expandtab
  silent! execute 'keepalt file vf-lesson-' . s:session.id
  let s:session.you_win = win_getid()
  " Whole-buffer-motion drills (fills_buffer, e.g. move_to_file_edges:
  " gg / G) collide with the lesson's in-buffer prompt header. The
  " content is rendered BELOW the header (rows header_offset+1 .. ), so
  " a real gg would land on the prompt chrome — never on the first
  " content line — and a gg item could never be credited. (G already
  " lands correctly: the content is the last thing in the buffer, so
  " G's last-line target IS the last content line — no remap needed.)
  "
  " Remap gg via <expr> to a REAL counted jump, "(header_offset+1)G",
  " so it lands on the first content line and fires CursorMoved through
  " the normal motion path (a :call cursor() mapping would move the
  " cursor but not trigger the credit autocmd). The <expr> reads
  " header_offset at press time, so it tracks every frame's offset and
  " persists across the setup frames and the test phase (same reused
  " buffer). Training (vf-<id>, header_offset 0) uses real gg untouched.
  if get(s:session, 'fills_buffer', 0)
    nnoremap <buffer> <expr> gg <SID>learn_top_keys()
  endif
endfunction

" RHS of the fills_buffer gg remap. Edge content lines are non-indented
" (the drill's cheat-analysis guarantees a column-1 target), so the
" counted G lands at column 1 — gg / G's first-non-blank destination.
function! s:learn_top_keys() abort
  return (s:session.header_offset + 1) . 'G'
endfunction

" Cue-aware goal text for an editing-kind lesson item/frame: name what the
" learner is actually looking at, instead of always claiming a green cell
" (editing drills cue with a red range, the ▶◀ seam, or a green target —
" or nothing, when the prompt alone carries the task).
function! s:learn_cue_goal(item) abort
  if has_key(a:item, 'deletion_range') && !empty(a:item.deletion_range)
    return 'delete the red range'
  elseif has_key(a:item, 'enter_at_col')
    return 'paste at the ▶◀'
  elseif get(a:item, 'show_target', 0)
    return get(a:item, 'target_full_line', 0) ? 'reach the green line' : 'reach the green cell'
  endif
  return 'edit to match the target'
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
          let hint = printf('✓ %d/%d streak!  [Space=finish]',
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
      elseif kind ==# 'editing'
        let goal = s:learn_cue_goal(get(s:session, 'current_test_item', {}))
          \ . ', fewest keystrokes'
      else
        let goal = 'reach the green cell, fewest keystrokes'
      endif
      let hint = printf('streak %d/%d  [%s]', cur, req, goal)
      if kind ==# 'editing'
        let hint .= '  [u=undo if wrong]'
      endif
    endif
    let quit_hint = kind ==# 'recall' ? '[Esc=quit]' : '[Q=quit]'
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
    elseif kind ==# 'editing'
      let hint = '[' . s:learn_cue_goal(frame) . ']'
    else
      let hint = '[reach the green cell]'
    endif
    if kind ==# 'editing'
      let hint .= '  [u=undo if wrong]'
    endif
  endif
  let quit_hint = kind ==# 'recall' ? '[Esc=quit]' : '[Q=quit]'
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
  let is_command = kind ==# 'command'

  " prompt may be a string or a list of lines — multi-line lets a
  " drill wrap long instructions at a readable width instead of
  " forcing a horizontal scroll. Command-kind try frames carry no
  " prompt (their cue is the status header + goal rendered inline by
  " the command-kind branch below); treat that case as empty.
  let frame_prompt = get(frame, 'prompt', '')
  let prompt_lines = type(frame_prompt) == v:t_list
    \ ? copy(frame_prompt)
    \ : (empty(frame_prompt) ? [] : [frame_prompt])
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
  if is_command
    " Command lessons render the same live-buffer scenario the
    " training does — a single comment-line goal at the top of a
    " realistic snippet — for try frames; show frames stay static
    " rule statements built from frame.prompt.
    if frame.kind ==# 'try'
      let snippet = get(frame, 'snippet', {'lines': [], 'comment': '#'})
      let goal    = get(frame, 'goal', '')
      let scene_header = [vimfluency#scenarios#goal_comment(snippet, goal)]
      let pre = [s:learn_header_line(), '']
      let s:session.header_offset = len(pre) + len(scene_header)
      setlocal modifiable
      silent! %delete _
      call setline(1, pre + scene_header + snippet.lines)
      setlocal nomodifiable nomodified
      call cursor(len(pre) + len(scene_header) + 1, 1)
      call s:install_command_maps()
    else
      setlocal modifiable
      silent! %delete _
      call setline(1, base_header)
      setlocal nomodifiable nomodified
      call cursor(len(base_header), 1)
    endif
    let s:session.advancing = 0
    return
  endif
  " Mode-kind frames may get a '▶◀' gap indicator row — try frames
  " always do (it's the cue); show frames optionally, when they
  " declare enter_at_col to demonstrate the cue itself.
  " Indicator shows whenever the frame declares enter_at_col — mode
  " frames (the ▶◀ gap) and the charwise editing paste drill alike.
  let mode_extra = []
  let ind = s:mode_gap_indicator(frame)
  if !empty(ind)
    call add(mode_extra, ind)
  endif
  " Annotation row sits at the END of the header (just above the
  " content), so the cur_lines comparison in s:learn_on_change still
  " excludes it via header_offset.
  let header = base_header + mode_extra + s:waypoint_annotation(frame)
    \ + s:deletion_annotation(frame)
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
    if !is_mode && (get(s:session, 'kind', 'motion') !=# 'editing'
      \ || get(frame, 'show_target', 0))
      let s:session.target_match_id = matchaddpos('VfTarget',
        \ get(frame, 'target_full_line', 0)
        \   ? [[buf_target_row]]
        \   : [[buf_target_row, frame.target[1], 1]], 20)
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
  call s:seed_register(frame)

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
    " Escape hatch: :VfQuit executes for real so the learner can end
    " the session — every other ex command is cancelled.
    cnoremap <buffer> <expr> <CR> getcmdtype() ==# ':' && getcmdline() =~# '^VfQuit\>' ? "\<CR>" : "\<C-c>"
  endif
  augroup VfLearn
    autocmd!
    if kind ==# 'mode'
      " Mode-kind lessons track the round trip through insert mode,
      " same as the training: InsertEnter records the entry col so we
      " can disambiguate i/a/I/A, InsertLeave is when we evaluate.
      autocmd InsertEnter <buffer> call s:learn_on_insert_enter()
      autocmd InsertLeave <buffer> call s:learn_on_insert_leave()
      " Opt-in fast path for drills that drill the entry key by
      " having the learner TYPE a known short text (e.g. 'foo') and
      " advance the moment the buffer matches target_lines_after_type.
      " No Esc needed — mode-leave has its own dedicated drill
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
    elseif kind ==# 'command'
      " Command lessons capture credits through the buffer-local maps
      " installed per-frame by s:render_command_item / the command
      " branches of s:learn_render_frame and s:learn_test_next — same
      " story as the training path. No CursorMoved autocmds: the cue
      " is keystroke-based, and s:learn_on_change would crash on
      " frame.target lookups since command-kind try frames don't
      " carry one.
    else
      " TextChanged is needed for the test phase on editing-kind drills
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
  " recall drills' answers contain Space or CR, so this is safe;
  " a future answer-with-spaces would need a dispatcher.
  nnoremap <buffer> <silent> <Space> :call <SID>learn_advance_show()<CR>
  nnoremap <buffer> <silent> <CR> :call <SID>learn_advance_show()<CR>
  if kind !=# 'recall'
    " Q is the documented quit key (uppercase nav keys everywhere);
    " lowercase q / p are muscle-memory aliases (q=quit, p=practice).
    " But skip either when the drill actually PRESSES that key — the
    " paste drills press p, so the map would shadow the paste (same
    " reason recall skips q/p, since :q/:wq contain them). Uppercase Q
    " stays: the drilled keys here are the lowercase forms.
    let drilled = get(s:session, 'allowed_keys', '')
    nnoremap <buffer> <silent> Q :call vimfluency#learn_stop()<CR>
    if stridx(drilled, 'q') < 0
      nnoremap <buffer> <silent> q :call vimfluency#learn_stop()<CR>
    endif
    if stridx(drilled, 'p') < 0
      nnoremap <buffer> <silent> p :call <SID>learn_start_train()<CR>
    endif
  endif
  " Ctrl-C → Esc, mirroring the training path. Vim's Ctrl-C exits insert
  " without firing InsertLeave by design, so unmapped it would leave
  " the mode-kind matcher hanging.
  inoremap <buffer> <silent> <C-c> <Esc>
  " Block jumplist-back (stale pre-session entries escape the buffer).
  nnoremap <buffer> <silent> <C-o> <Nop>
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

  " visual_motion kind: use mode + visual-anchor predicate (same as the
  " training path), then queue <C-\><C-n> to drop to normal mode so the
  " learner's next <Space> hits the lesson's advance mapping instead of
  " being interpreted as a visual-mode motion. Handles both the
  " setup-phase try frame and the test-phase item — they share the
  " same item shape (snippet/start/target/expected_selection_*).
  if s:session.kind ==# 'visual_motion'
    let header_offset = s:session.header_offset
    let cur_pos = [line('.') - header_offset, col('.')]
    if s:session.phase ==# 'test'
      let item = s:session.current_test_item
      " Dedupe + per-CursorMoved motion count, mirroring the
      " test-phase block further down. Without this the visual_motion
      " test phase never increments test_motion_count, so streak
      " always sees last_item_motions == 0 ≤ optimal and graduates
      " on every item regardless of efficiency.
      let cur_lines = getline(header_offset + 1, '$')
      let new_state = [cur_pos, cur_lines]
      if get(s:session, 'last_event_state', []) ==# new_state | return | endif
      let s:session.last_event_state = new_state
      let s:session.test_motion_count += 1
    else
      let frame = s:session.frames[s:session.frame_idx]
      if frame.kind !=# 'try' | return | endif
      let item = frame
    endif
    let expected_mode = get(item, 'expected_sub_mode', 'v')
    if mode(1) !=# expected_mode | return | endif
    let v_pos = getpos('v')
    let anchor = [v_pos[1] - header_offset, v_pos[2]]
    let exp_start = get(item, 'expected_selection_start', item.start)
    let exp_end   = get(item, 'expected_selection_end',   item.target)
    if anchor != exp_start || cur_pos != exp_end | return | endif

    " +1 for the v / V / Ctrl-V keystroke (mode change, no
    " CursorMoved). See the matching comment in s:on_change's
    " visual_motion branch — same fixup, same limitation.
    if s:session.phase ==# 'test'
      let s:session.test_motion_count += 1
    endif
    call feedkeys("\<C-\>\<C-n>", 'n')
    let s:session.frame_complete = 1
    if s:session.phase ==# 'test'
      let s:session.last_item_motions = get(s:session, 'test_motion_count', 0)
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
    return
  endif

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

    if cur_lines ==# target_lines && cur_pos == item.target && s:search_ok(item)
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
  " Clear the deletion-range red the moment insert begins — see
  " s:on_insert_enter for the rationale (stale cit/cat highlight over
  " the shifted remainder; no-op for plain insert frames).
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
    let s:session.deletion_match_id = -1
  endif
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
" out of scope for this lesson — the switch_mode_to_insert drill
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
  " For credit_on_text_typed drills, credit comes from
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

" Reached when the learner hits the required streak in the test phase.
" Tears the lesson session down and lands on the shared end screen
" (s:show_end_screen) — the same screen :VfTrain ends on — reusing the
" lesson window in place. The end screen shows this drill's last
" training session's frequency + breakdown (an empty-state nudge to
" train when there's none yet) and the navigation menu.
function! s:learn_show_complete() abort
  let s:session.advancing = 1
  let id = s:session.id

  " Tear down lesson autocmds / timers and restore the options the
  " lesson changed, but keep the window — s:show_end_screen repurposes
  " the lesson buffer as the end screen.
  silent! augroup VfLearn | autocmd! | augroup END
  if has_key(s:session, 'learn_demo_timer')
    call timer_stop(s:session.learn_demo_timer)
  endif
  call s:stop_mode_polling()
  call s:stop_learn_auto_advance()
  let &ttimeoutlen = get(s:session, 'prev_ttimeoutlen', &ttimeoutlen)
  let &cpoptions = get(s:session, 'prev_cpoptions', &cpoptions)
  let &clipboard = get(s:session, 'prev_clipboard', &clipboard)
  let @/ = get(s:session, 'prev_search', @/)
  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
  endif
  if s:session.deletion_match_id != -1
    silent! call matchdelete(s:session.deletion_match_id)
  endif
  call s:clear_waypoint_matches()

  let you_win = get(s:session, 'you_win', -1)
  " The completion can fire from the mode_switch auto-advance timer
  " while the learner is still in Insert/Visual/Replace/Cmd mode.
  " <C-\><C-n> is vim's universal "to Normal from anywhere" — without
  " it the end screen's nnoremaps would type into the buffer.
  silent! call feedkeys("\<C-\>\<C-n>", 'n')
  let s:session = {}
  if you_win > 0 && win_id2tabwin(you_win)[0] > 0
    call win_gotoid(you_win)
  endif
  call s:show_end_screen(id, 'learn')
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

" Generate a fresh test item from the drill and render it. Reuses the
" drill's generate() so test items have the same cheat-defense as
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

  let GenFn = function('vimfluency#drills#' . s:session.module . '#generate')
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

  if kind ==# 'command'
    " Same live-buffer scenario rendering as the training path, with
    " the lesson header line prepended so the learner sees their
    " streak. test_motion_count is reset here so the streak math in
    " s:command_check measures only THIS item's keystrokes.
    let s:session.test_motion_count = 0
    let snippet = get(item, 'snippet', {'lines': [], 'comment': '#'})
    let goal    = get(item, 'goal', '')
    let pre = [s:learn_header_line(), '',
      \ 'Apply the rule — read the buffer and type the right command.', '']
    let scene_header = [vimfluency#scenarios#goal_comment(snippet, goal)]
    let s:session.header_offset = len(pre) + len(scene_header)
    setlocal modifiable
    silent! %delete _
    call setline(1, pre + scene_header + snippet.lines)
    setlocal nomodifiable nomodified
    call cursor(len(pre) + len(scene_header) + 1, 1)
    call s:install_command_maps()
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
  " Gap indicator: mode items, and the charwise editing paste drill
  " (any item declaring enter_at_col).
  let mode_extra = []
  let ind = s:mode_gap_indicator(item)
  if !empty(ind)
    call add(mode_extra, ind)
  endif
  let full_header = lesson_header + editing_header + mode_extra
    \ + s:waypoint_annotation(item) + s:deletion_annotation(item)
  let s:session.header_offset = len(full_header)

  setlocal modifiable
  silent! %delete _
  if has_key(item, 'history') && !empty(item.history)
    call s:stage_undo_history(item, full_header)
  else
    call setline(1, full_header + item.lines)
  endif
  call cursor(s:session.header_offset + item.start[0], item.start[1])
  call s:seed_register(item)

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  if !is_mode && (get(s:session, 'kind', 'motion') !=# 'editing'
    \ || get(item, 'show_target', 0))
    let s:session.target_match_id = matchaddpos('VfTarget',
      \ get(item, 'target_full_line', 0)
      \   ? [[s:session.header_offset + item.target[0]]]
      \   : [[s:session.header_offset + item.target[0], item.target[1], 1]], 20)
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
  if has_key(s:session, 'learn_demo_timer')
    call timer_stop(s:session.learn_demo_timer)
  endif
  call s:stop_mode_polling()
  call s:stop_learn_auto_advance()
  let id = s:session.id
  let prev_ttl = get(s:session, 'prev_ttimeoutlen', &ttimeoutlen)
  let prev_cpo = get(s:session, 'prev_cpoptions', &cpoptions)
  let prev_clip = get(s:session, 'prev_clipboard', &clipboard)
  let prev_srch = get(s:session, 'prev_search', @/)
  " Resolve the tab by window id at close time — the tab NUMBER captured
  " at setup goes stale if the user opens/closes tabs mid-session.
  let tabnr = win_id2tabwin(get(s:session, 'you_win', -1))[0]
  if tabnr > 0
    silent! execute 'tabclose ' . tabnr
  endif
  let &ttimeoutlen = prev_ttl
  let &cpoptions = prev_cpo
  let &clipboard = prev_clip
  let @/ = prev_srch
  let s:session = {}
  echo 'lesson ended for ' . id . ' — try :VfTrain ' . id
endfunction

" -----------------------------------------------------------------
" Standard Celeration Chart (text-only)
" -----------------------------------------------------------------

" :VfChart reuses the dashboard's celeration-chart renderer
" (s:dashboard_chart_panel), sized to the full buffer, so the standalone
" chart and the dashboard's hovered chart are visually identical — same
" box, ●/○ aim split, dotted aim line, today-anchored x-axis, and a
" fixed log-Y range (1..~316, kept fixed for cross-chart comparability
" per Precision Teaching).

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
    echo 'usage: :VfChart <drill_id>'
    return
  endif
  call s:chart_render(vimfluency#canonical_id(a:1))
endfunction

function! s:chart_render(id) abort
  let registry = vimfluency#discover_drills()
  let grouped = s:load_sessions_grouped()
  if !has_key(registry, a:id) && !has_key(grouped, a:id)
    echo 'unknown drill: ' . a:id
    return
  endif
  " Reuse the dashboard's SCC renderer, sized to the full buffer — the
  " standalone chart IS the dashboard chart, just larger. The new tab's
  " window is &lines minus the statusline + command line.
  let lines = s:dashboard_chart_panel(
    \ a:id, registry, grouped, &columns, &lines - 2)
  call s:show_chart_buffer(a:id, lines)
endfunction

function! s:show_chart_buffer(id, lines) abort
  tabnew
  let tabnr = tabpagenr()
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  silent! execute 'keepalt file vf-chart-' . a:id
  call setline(1, a:lines)
  setlocal nomodifiable nomodified
  let &l:statusline = ' chart — ' . a:id
    \ . '   [T=Train  L=Learn  I=List  V=Dashboard  Q=Close]'
  let b:vf_summary_tabnr = tabnr
  let b:vf_summary_prev_laststatus = &laststatus
  " Remember which drill this chart is for so the nav keys can route to
  " the right train / learn / dashboard target.
  let b:vf_chart_id = a:id
  set laststatus=2
  " Navigation keys — same loop as every other view (see
  " s:show_end_screen): jump straight to this drill's training,
  " lesson, the list, or the dashboard without closing by hand.
  " Q / <Enter> close.
  nnoremap <buffer> <silent> T :call vimfluency#chart_nav('train')<CR>
  nnoremap <buffer> <silent> L :call vimfluency#chart_nav('learn')<CR>
  nnoremap <buffer> <silent> I :call vimfluency#chart_nav('list')<CR>
  nnoremap <buffer> <silent> V :call vimfluency#chart_nav('dashboard')<CR>
  nnoremap <buffer> <silent> Q :call vimfluency#close_summary()<CR>
  " Lowercase q kept as a silent alias for muscle memory; Q is the
  " documented key (uppercase nav keys everywhere — see s:show_end_screen).
  nnoremap <buffer> <silent> q :call vimfluency#close_summary()<CR>
  nnoremap <buffer> <silent> <CR> :call vimfluency#close_summary()<CR>
  call cursor(1, 1)
endfunction

" Navigation from a progress chart. Mirrors vimfluency#end_nav: closes
" the chart tab, then opens the chosen view for the chart's drill. Learn
" is guarded (a no-op with a hint when the drill has no lesson) so the
" chart doesn't vanish behind a fleeting message — same discipline as
" vimfluency#list_action.
function! vimfluency#chart_nav(action) abort
  let id = get(b:, 'vf_chart_id', '')
  if a:action ==# 'learn' && !s:drill_has_lesson(id)
    echo 'no lesson written for ' . id . ' yet'
    return
  endif
  call vimfluency#close_summary()
  if a:action ==# 'train'
    call vimfluency#start(id)
  elseif a:action ==# 'learn'
    call vimfluency#learn(id)
  elseif a:action ==# 'list'
    call vimfluency#list()
  elseif a:action ==# 'dashboard'
    call vimfluency#dashboard(id)
  endif
endfunction

" ─────────────────────────────────────────────────────────────────
" :Vf — multi-panel view with hover-reactive context panels
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

" Dashboard window dimensions. The banner buffer holds the one-line
" 'Vim Fluency — Path: ... status counts ... sessions trained'
" header (1 content row + its statusline). The hover buffer hosts
" the two side-by-side celeration charts and absorbs the vertical
" space freed by the removal of the old profile / DRILLS SUMMARY
" row. The last-session buffer is a vertical side panel to the
" right of the table at the bottom of the screen; its width is
" tuned to fit the breakdown (drill id title + commands sub-table).
let s:DASHBOARD_BANNER_HEIGHT = 1
let s:DASHBOARD_HOVER_HEIGHT = 28
let s:DASHBOARD_LAST_SESSION_WIDTH = 60

" Hover-panel data cache: registry + grouped sessions, filled when the
" dashboard is (re)built and dropped on close. Hover repaints on every
" j/k — re-parsing sessions.jsonl there is the wrong cost model.
let s:dashboard_cache = {}

" :Vf [drill_id]. Optional id lands the cursor on that
" row (matching :VfTrain <id> / training-end auto-return). If a dashboard
" tab already exists, switch to it and rebuild in place rather than
" opening a duplicate.
function! vimfluency#dashboard(...) abort
  let registry = vimfluency#discover_drills()
  if empty(registry)
    echo 'no drills built — see CATALOG.md'
    return
  endif
  let target_id = a:0 > 0 ? vimfluency#canonical_id(a:1) : ''

  " Reuse an open dashboard if there is one — switch to its tab and
  " rebuild in place so the just-finished session shows up in LAST
  " SESSION without a second dashboard tab piling up.
  let table_bufnr = bufnr('vf-dashboard-table')
  if table_bufnr > 0
    for t in range(1, tabpagenr('$'))
      let buflist = tabpagebuflist(t)
      if index(buflist, table_bufnr) >= 0
        execute 'tabnext ' . t
        for win in range(1, winnr('$'))
          if winbufnr(win) == table_bufnr
            execute win . 'wincmd w'
            call s:rebuild_dashboard_keeping_drill(target_id)
            return
          endif
        endfor
      endif
    endfor
  endif

  call s:show_dashboard(registry, s:load_sessions_grouped(), target_id)
endfunction

function! s:show_dashboard(registry, sessions, ...) abort
  let target_id = a:0 > 0 ? a:1 : ''
  " Filter the registry to the current path. The dashboard is a
  " curated view; :VfTrain <id> / :VfLearn <id> still work on every
  " drill regardless of which path is active.
  let path_registry = s:filter_registry_by_path(a:registry)
  let view = s:build_list_view(path_registry, a:sessions, {})
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
  let drill_rows = map(copy(split.drill_rows), 'v:val + 1')

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
  let b:vf_list_drill_rows = drill_rows
  let b:vf_list_expanded = {}
  let b:vf_list_sort_col = ''
  let b:vf_list_sort_desc = 0
  " Same b:vf_summary_* names the list/chart buffers use, so the q
  " mapping's vimfluency#close_summary() works here too.
  let b:vf_summary_tabnr = tabnr
  let b:vf_summary_prev_laststatus = &laststatus
  let &l:statusline = ' Vim Fluency dashboard   [L=Learn  T=Train  C=Chart  I=List  A=Aim  D=Duration  P=Path  B=Breakdown  s=sort  Q=close]'
  set laststatus=2

  " --- Window 2: banner at the very top (1 content row) ---
  " The banner row holds the path + fluency + sessions/trained stats.
  " It's its own window so the hover charts below can grow into the
  " space without the table needing to know banner mechanics.
  topleft new
  execute 'resize ' . s:DASHBOARD_BANNER_HEIGHT
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal winfixheight nocursorline
  silent! execute 'keepalt file vf-dashboard-banner'
  let banner_bufnr = bufnr('%')
  let &l:statusline = ' '

  " --- Window 3: hovered-drill chart row between banner and table ---
  " Now tall enough to be the visual centerpiece of the dashboard —
  " absorbs the vertical space the old profile / DRILLS SUMMARY
  " row used to take.
  call win_gotoid(table_winid)
  aboveleft new
  execute 'resize ' . s:DASHBOARD_HOVER_HEIGHT
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal winfixheight nocursorline
  silent! execute 'keepalt file vf-dashboard-hover'
  let hover_bufnr = bufnr('%')
  let &l:statusline = ' '

  " --- Window 4: LAST SESSION side panel beside the table ---
  " A vertical split on the right of the table. The drill-specific
  " breakdown (date / rate / aim / eff, prereqs, per-command
  " sub-table) lives here and updates as the table's cursor moves.
  call win_gotoid(table_winid)
  execute 'rightbelow vertical ' . s:DASHBOARD_LAST_SESSION_WIDTH . 'new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  setlocal winfixwidth nocursorline
  silent! execute 'keepalt file vf-dashboard-last-session'
  let last_session_bufnr = bufnr('%')
  let &l:statusline = ' [j/k=scroll  J/<CR>=jump to prereq  Q/Esc/B=back to table] '

  " Keybindings on the last-session window: q / <Esc> / B jump back
  " to the table. J / <CR> on a prereq line jumps the table cursor
  " to that prereq's row. Stored buffer-local so they don't leak
  " when the dashboard closes.
  nnoremap <buffer> <silent> Q    :call vimfluency#dashboard_return_to_table()<CR>
  nnoremap <buffer> <silent> q    :call vimfluency#dashboard_return_to_table()<CR>
  nnoremap <buffer> <silent> <Esc> :call vimfluency#dashboard_return_to_table()<CR>
  nnoremap <buffer> <silent> B    :call vimfluency#dashboard_return_to_table()<CR>
  nnoremap <buffer> <silent> J    :call vimfluency#dashboard_jump_to_prereq()<CR>
  nnoremap <buffer> <silent> <CR> :call vimfluency#dashboard_jump_to_prereq()<CR>

  " Return to the table window — that's where the cursor lives.
  call win_gotoid(table_winid)
  let b:vf_dashboard_hover_bufnr = hover_bufnr
  let b:vf_dashboard_banner_bufnr = banner_bufnr
  let b:vf_dashboard_last_session_bufnr = last_session_bufnr

  " Land on target_id when given (passed from :Vf <id> or
  " the post-training return path); fall back to the first drill
  " row otherwise.
  let first_line = empty(drill_rows) ? 2 : drill_rows[0]
  if !empty(target_id)
    for row in drill_rows
      if get(mapping, row, '') ==# target_id
        let first_line = row | break
      endif
    endfor
  endif
  call cursor(first_line, 1)
  let b:vf_dashboard_last_row = first_line
  let s:dashboard_cache = {'registry': a:registry, 'sessions': a:sessions}

  call s:dashboard_render_hover(mapping, first_line, path_registry, a:sessions, cols)
  call s:dashboard_render_banner(path_registry, a:sessions, cols)
  call s:dashboard_render_last_session(mapping, first_line, path_registry, a:sessions)

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
  nnoremap <buffer> <silent> I :call vimfluency#list_action('list')<CR>
  nnoremap <buffer> <silent> A :call vimfluency#dashboard_set_aim()<CR>
  nnoremap <buffer> <silent> D :call vimfluency#dashboard_set_duration()<CR>
  nnoremap <buffer> <silent> P :call vimfluency#dashboard_set_path()<CR>
  nnoremap <buffer> <silent> B :call vimfluency#dashboard_inspect_last_session()<CR>
  nnoremap <buffer> <silent> Q :call vimfluency#close_summary()<CR>
  " Lowercase q kept as a silent alias for muscle memory; Q is the
  " documented key (uppercase nav keys everywhere — see s:show_end_screen).
  nnoremap <buffer> <silent> q :call vimfluency#close_summary()<CR>
  nnoremap <buffer> <silent> j :call vimfluency#list_move('next')<CR>
  nnoremap <buffer> <silent> k :call vimfluency#list_move('prev')<CR>
  nnoremap <buffer> <silent> gg :call vimfluency#list_move('first')<CR>
  nnoremap <buffer> <silent> G :call vimfluency#list_move('last')<CR>
  " Sort keybindings — same column keys as :VfList. The 2-key chords
  " must be installed before the bare `s` help mapping so vim's
  " longest-match-wins resolution gives the chords priority.
  nnoremap <buffer> <silent> sd :call vimfluency#dashboard_sort('drill')<CR>
  nnoremap <buffer> <silent> sc :call vimfluency#dashboard_sort('commands')<CR>
  nnoremap <buffer> <silent> sp :call vimfluency#dashboard_sort('prereqs_n')<CR>
  nnoremap <buffer> <silent> sa :call vimfluency#dashboard_sort('aim')<CR>
  nnoremap <buffer> <silent> sr :call vimfluency#dashboard_sort('last_rate')<CR>
  nnoremap <buffer> <silent> ss :call vimfluency#dashboard_sort('last_session')<CR>
  nnoremap <buffer> <silent> sn :call vimfluency#dashboard_sort('runs')<CR>
  nnoremap <buffer> <silent> sf :call vimfluency#dashboard_sort('family')<CR>
  nnoremap <buffer> <silent> s<Space> :call vimfluency#dashboard_sort('')<CR>
  nnoremap <buffer> <silent> s :call vimfluency#list_sort_help()<CR>
endfunction

" Sort the dashboard table by the given column and rebuild in place.
" Same flip semantics as vimfluency#list_sort (same col reverses,
" empty col resets to default order), but the cursor FOLLOWS the
" hovered drill to its new row rather than staying on the same
" Nth row — the hover panels (chart, LAST SESSION) track the
" hovered drill, and having them silently switch to whatever row
" slid under the cursor would be disorienting on a dashboard.
function! vimfluency#dashboard_sort(col) abort
  if !exists('b:vf_list_line_to_id') | return | endif
  if empty(a:col)
    let b:vf_list_sort_col = ''
    let b:vf_list_sort_desc = 0
  elseif get(b:, 'vf_list_sort_col', '') ==# a:col
    let b:vf_list_sort_desc = !get(b:, 'vf_list_sort_desc', 0)
  else
    let b:vf_list_sort_col = a:col
    let b:vf_list_sort_desc = 0
  endif
  let id = get(b:vf_list_line_to_id, line('.'), '')
  call s:rebuild_dashboard_keeping_drill(id)
endfunction

function! s:dashboard_on_cursor_moved() abort
  if !exists('b:vf_dashboard_hover_bufnr') | return | endif
  let row = line('.')
  if row == get(b:, 'vf_dashboard_last_row', -1) | return | endif
  let b:vf_dashboard_last_row = row
  " Registry + sessions come from the cache filled at dashboard
  " build/rebuild time. Nothing the JSONL log records changes while
  " the dashboard is open (training rebuilds the dashboard, which
  " refreshes the cache), and re-parsing the whole log — records
  " embed full items_log — on every j/k makes hovering sluggish as
  " the log grows.
  if empty(s:dashboard_cache)
    let s:dashboard_cache = {
      \ 'registry': vimfluency#discover_drills(),
      \ 'sessions': s:load_sessions_grouped(),
      \ }
  endif
  let registry = s:dashboard_cache.registry
  let sessions = s:dashboard_cache.sessions
  let path_registry = s:filter_registry_by_path(registry)
  call s:dashboard_render_hover(b:vf_list_line_to_id, row, path_registry, sessions, &columns)
  call s:dashboard_render_banner(path_registry, sessions, &columns)
  call s:dashboard_render_last_session(b:vf_list_line_to_id, row, path_registry, sessions)
endfunction

function! s:dashboard_cleanup() abort
  for name in ['vf-dashboard-hover', 'vf-dashboard-banner', 'vf-dashboard-last-session']
    let b = bufnr(name)
    if b > 0 | silent! execute 'bwipeout! ' . b | endif
  endfor
  silent! autocmd! VfDashboard
  " Cached sessions embed every item log — don't hold them after close.
  let s:dashboard_cache = {}
endfunction

" Rebuild the dashboard table + panels after a settings change
" (aim, path, etc.). Mirrors s:rebuild_list_buffer_keeping_drill
" but writes into the dashboard's vf-dashboard-table buffer and
" refreshes the hover and profile side panels too. The column-header
" row is prepended to the data lines (same +1 shift on row→id
" mapping as the initial setup in s:show_dashboard).
function! s:rebuild_dashboard_keeping_drill(id) abort
  let registry = vimfluency#discover_drills()
  let path_registry = s:filter_registry_by_path(registry)
  let sessions = s:load_sessions_grouped()
  let s:dashboard_cache = {'registry': registry, 'sessions': sessions}
  let view = s:build_list_view(path_registry, sessions, get(b:, 'vf_list_expanded', {}),
    \ get(b:, 'vf_list_sort_col', ''), get(b:, 'vf_list_sort_desc', 0))
  let split = s:split_view(view)

  let table_lines = [split.header_lines[-1]] + split.data_lines
  let mapping = {}
  for [k, id] in items(split.mapping)
    let mapping[str2nr(k) + 1] = id
  endfor
  let drill_rows = map(copy(split.drill_rows), 'v:val + 1')

  setlocal modifiable
  silent! %delete _
  call setline(1, table_lines)
  setlocal nomodifiable nomodified
  let b:vf_list_line_to_id    = mapping
  let b:vf_list_drill_rows = drill_rows

  let landing = empty(drill_rows) ? 2 : drill_rows[0]
  for row in drill_rows
    if get(mapping, row, '') ==# a:id
      let landing = row | break
    endif
  endfor
  call cursor(landing, 1)
  let b:vf_dashboard_last_row = landing

  call s:dashboard_render_hover(mapping, landing, path_registry, sessions, &columns)
  call s:dashboard_render_banner(path_registry, sessions, &columns)
  call s:dashboard_render_last_session(mapping, landing, path_registry, sessions)
endfunction

" A → prompt to set or reset the aim for the hovered drill.
" Same set/reset semantics as vimfluency#list_set_aim, but the
" rebuild path targets the dashboard buffers.
function! vimfluency#dashboard_set_aim() abort
  if !exists('b:vf_list_line_to_id') | return | endif
  let id = get(b:vf_list_line_to_id, line('.'), '')
  if empty(id)
    echo 'cursor must be on a drill row'
    return
  endif
  let registry = vimfluency#discover_drills()
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
  call s:rebuild_dashboard_keeping_drill(id)
endfunction

" D → prompt for the global default duration. Duration doesn't
" surface in the dashboard layout itself, so no rebuild — just
" reuse the existing list_set_duration prompt.
function! vimfluency#dashboard_set_duration() abort
  call vimfluency#list_set_duration()
endfunction

" P → prompt to set the current path. Tab-completes from the
" discovered paths registry. Empty cancels; 'general' resets.
" Shared P-key path picker for both :Vf and :VfList: prompt (with Tab
" completion), apply the selection, and return 1 if a path was chosen
" (caller should rebuild its view), 0 on cancel.
function! s:prompt_set_path() abort
  let cur = s:effective_path()
  let paths = vimfluency#discover_paths()
  let available = join(sort(keys(paths)), ', ')
  let prompt = printf('current path [%s] · available: %s (Tab completes, Esc = cancel): ',
    \ cur, available)
  let response = input(prompt, '', 'customlist,vimfluency#complete_path')
  redraw
  let trimmed = tolower(substitute(response, '^\s*\(.\{-}\)\s*$', '\1', ''))
  if empty(trimmed)
    echo 'cancelled'
    return 0
  endif
  if trimmed ==# 'general'
    call vimfluency#reset_path()
  else
    call vimfluency#set_path(trimmed)
  endif
  return 1
endfunction

function! vimfluency#dashboard_set_path() abort
  if !s:prompt_set_path() | return | endif
  let id = get(b:vf_list_line_to_id, line('.'), '')
  call s:rebuild_dashboard_keeping_drill(id)
endfunction

" P on :VfList → same picker, then rebuild the list with the new path
" filter (the hovered drill may drop out of scope; the rebuild lands
" the cursor on the first row when its id is gone).
function! vimfluency#list_set_path() abort
  if !s:prompt_set_path() | return | endif
  let id = exists('b:vf_list_line_to_id')
    \ ? get(b:vf_list_line_to_id, line('.'), '') : ''
  call s:rebuild_list_buffer_keeping_drill(id)
endfunction

" `B` action from the table: drop the cursor into the profile
" window with the view scrolled to the top of the LAST SESSION
" panel so the learner can move down with j/k to reach commands /
" prereqs that overflow the window. The LAST SESSION buffer is the
" side panel beside the table — its full breakdown is rendered
" without truncation; only the visible slice changes here.
function! vimfluency#dashboard_inspect_last_session() abort
  if !exists('b:vf_dashboard_last_session_bufnr') | return | endif
  let bufnr = b:vf_dashboard_last_session_bufnr
  for win in range(1, winnr('$'))
    if winbufnr(win) == bufnr
      execute win . 'wincmd w'
      " Row 1 is the LAST SESSION title (the buffer now starts
      " straight into the panel — no banner / blank spacer ahead
      " of it). Land on the title so the learner sees what they're
      " scrolling.
      keepjumps call cursor(1, 1)
      normal! zt
      return
    endif
  endfor
endfunction

" Inverse of dashboard_inspect_last_session: return the cursor to
" the dashboard's table window. Bound to q / <Esc> / B from the
" LAST SESSION window so any of the three feels natural.
function! vimfluency#dashboard_return_to_table() abort
  let table_bufnr = bufnr('vf-dashboard-table')
  if table_bufnr <= 0 | return | endif
  for win in range(1, winnr('$'))
    if winbufnr(win) == table_bufnr
      execute win . 'wincmd w'
      return
    endif
  endfor
endfunction

" J / <CR> from the LAST SESSION pane: if the cursor is on a prereq
" line, switch to the table window and move its cursor to that
" prereq's row. The render path stores the buffer-line → prereq-id
" map on b:vf_dashboard_prereq_map; we look up the current line and
" then re-use the table's existing line→id mapping to find the
" target row. Errors when the path filter excludes the prereq from
" the visible table (e.g. the user is on Foundational but the
" prereq lives in a different path).
function! vimfluency#dashboard_jump_to_prereq() abort
  let prereq_map = get(b:, 'vf_dashboard_prereq_map', {})
  let prereq_id = get(prereq_map, line('.'), '')
  if empty(prereq_id)
    echo 'cursor is not on a prereq line'
    return
  endif

  let table_bufnr = bufnr('vf-dashboard-table')
  if table_bufnr <= 0 | return | endif
  let table_winid = -1
  for win in range(1, winnr('$'))
    if winbufnr(win) == table_bufnr
      execute win . 'wincmd w'
      let table_winid = win_getid()
      break
    endif
  endfor
  if table_winid < 0 | return | endif

  let mapping = get(b:, 'vf_list_line_to_id', {})
  for [k, v] in items(mapping)
    if v ==# prereq_id
      call cursor(str2nr(k), 1)
      return
    endif
  endfor
  echo printf('prereq %s not in current path — try changing path with P', prereq_id)
endfunction

" Render the hover panel buffer: two celeration charts side-by-side.
" DRILLS PER DAY (the at-a-glance "did I show up today" chart) lives
" on the LEFT so it's the first chart the learner's eye lands on;
" the hovered drill's STANDARD CELERATION CHART sits on the RIGHT
" where the per-drill detail naturally trails the macro view.
function! s:dashboard_render_hover(mapping, row, registry, sessions, cols) abort
  let id = get(a:mapping, a:row, '')

  let inner_w = a:cols - 2
  let left_w = (inner_w - 3) / 2
  let right_w = inner_w - 3 - left_w
  let chart_h = s:DASHBOARD_HOVER_HEIGHT - 1

  " Aggregate daily counts across every logged session — same data
  " model as the banner's session-count totals.
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
  let daily_lines = s:dashboard_daily_chart_panel(by_day, days_back, today_count, streak, left_w, chart_h)

  let hovered_lines = s:dashboard_chart_panel(id, a:registry, a:sessions, right_w, chart_h)

  while len(daily_lines) < chart_h | call add(daily_lines, '') | endwhile
  while len(hovered_lines) < chart_h | call add(hovered_lines, '') | endwhile

  let lines = []
  for i in range(chart_h)
    let l = ' ' . s:pad_right(daily_lines[i], left_w) . '   ' . s:pad_right(hovered_lines[i], right_w)
    call add(lines, s:pad_right(l, a:cols))
  endfor

  call s:dashboard_write_buffer(get(b:, 'vf_dashboard_hover_bufnr', -1), lines)
endfunction

" Render the Standard Celeration Chart for one drill as a boxed panel of
" width a:w and height a:h. Used by the dashboard's hover window AND by
" :VfChart (sized to the full buffer) so the two charts are identical.
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

  let title = empty(a:id)
    \ ? 'STANDARD CELERATION CHART'
    \ : printf('STANDARD CELERATION CHART: %s', a:id)
  let lines = [s:panel_box_top(title, a:w)]

  " Key row sits where the old 'aim X/min · last Y/min' summary
  " lived. The aim/last numbers were redundant with the drills
  " table + LAST SESSION breakdown; the key row now carries the
  " chart's symbol vocabulary instead. 'log y' starts at column 2,
  " which puts the 'y' character directly above the y-axis (col 6
  " inside the box with label_w = 4) so the label visually attaches
  " to the axis it describes.
  let key = ' log y (y = n/min) | ●/○ cor_rate (● ≥ aim) | × err_rate | ··· aim_rate'
  call add(lines, '│' . s:pad_right(key, a:w - 2) . '│')

  " The chart frame (y-axis + x-axis + tick marks + decade labels +
  " aim line) renders even when there are no usable sessions yet —
  " a stable visual placeholder beats a collapsing '(no data)' box
  " that pops in and out as the cursor moves between trained /
  " untrained drills.
  "
  " Bounds are FIXED for cross-chart comparability per Precision
  " Teaching's celeration-chart philosophy. The range is 1..~316
  " (log_bot=0, log_top=2.5), trimmed from the textbook 1..1000
  " because no realistic training rate hits 1000/min — the upper
  " half-decade of an unbounded SCC is wasted space here. Decade
  " labels still land cleanly at 100, 10, 1; the top of the chart
  " is the 10^2.5 boundary.
  "
  " X-axis is calendar-date based (PT convention), matching :VfChart:
  " one column per day, multi-session days stack at the same column,
  " gaps render days with no training. When the trained-day span
  " exceeds the available plot width, only the most recent days fit;
  " older sessions scroll off the left edge — the dashboard SCC is
  " an at-a-glance view, the full history lives in :VfChart.
  "
  " Axes use box-drawing characters: │ for the y-axis line, ─ for
  " the x-axis line, └ at their meeting corner. Tick marks point
  " INWARD: ├ on the y-axis at each decade label, ┴ on the x-axis
  " at each labeled day. Errors plot as × at their error-rate row.
  let label_w = 4
  let plot_w = a:w - 5 - label_w
  " Non-plot rows: top border + key row + x-axis line + MM-DD label
  " row + bottom border = 5.
  let plot_h = max([a:h - 5, 3])
  let log_bot = 0.0
  let log_top = 2.5
  let cols_per_day = 1

  " Bucket sessions by julian day. The x-axis is anchored to TODAY:
  " the rightmost column is today's date, and days extend backward
  " to fill plot_w. This makes 'have I trained recently?' immediately
  " visible — a gap on the right edge means the learner hasn't shown
  " up today; a dot at the right edge means they have. Sessions
  " older than the visible window scroll off the LEFT edge.
  " Always render the full window even with no sessions, so an
  " untrained drill shows the same frame the trained ones do.
  let max_days = plot_w / cols_per_day
  let today_jul = s:julian_from_iso(strftime('%Y-%m-%d'))
  let n_days = max_days
  let base_jul = today_jul - n_days + 1
  " day_idx → list of {rate, errors} per session that fell on that
  " day. Classical PT measurement: rate is items_correct/min
  " (frequency_per_min), errors is wasted_motions/min
  " (errors_per_min). Skips are tracked in the LAST SESSION pane's
  " counts block — they're not a rate (the trial didn't happen)
  " and Lindsley/Morningside SCC convention keeps them off the
  " corrects/errors lines.
  let day_data = {}
  for s in usable
    let day_idx = s:julian_from_iso(s.timestamp) - base_jul
    if day_idx < 0 || day_idx >= n_days | continue | endif
    if !has_key(day_data, day_idx) | let day_data[day_idx] = [] | endif
    call add(day_data[day_idx], {
      \ 'rate':   get(s, 'frequency_per_min', 0),
      \ 'errors': get(s, 'errors_per_min', 0)})
  endfor

  let aim_row = eff_aim > 0 ? s:dashboard_log_y(eff_aim, plot_h, log_bot, log_top) : -1
  " Iterate from the highest decade boundary that fits below log_top
  " down through every integer log10 step in range. Without floor()
  " here, a non-integer log_top (e.g. 2.5) produces labels at the
  " half-decades (316, 32, 3) instead of the round powers of 10.
  let label_rows = {}
  let lg = floor(log_top)
  while lg >= log_bot
    call s:add_label_rows(label_rows, plot_h, log_bot, log_top, float2nr(pow(10.0, lg) + 0.5))
    let lg -= 1.0
  endwhile

  " Plot rows. Each visible plot col c maps to day_idx = c/cols_per_day.
  " Multi-session days lay down all their dots at the same column;
  " distinct rates fall on distinct rows, identical rates collide
  " (acceptable — the chart is a rate signal, not a session count).
  " Errors render as × FIRST so the rate ● wins on collision (the
  " rate is the headline metric; errors live on a separate per-row).
  for r in range(plot_h)
    let label = has_key(label_rows, r)
      \ ? printf('%' . label_w . 'd', label_rows[r])
      \ : repeat(' ', label_w)
    let axis_char = has_key(label_rows, r) ? '├' : '│'
    let row_chars = []
    for c in range(plot_w)
      let day_idx = c / cols_per_day
      let drawn = ' '
      if c % cols_per_day == 0 && has_key(day_data, day_idx)
        for entry in day_data[day_idx]
          if entry.errors > 0
            let erow = s:dashboard_log_y(entry.errors, plot_h, log_bot, log_top)
            if r == erow | let drawn = '×' | endif
          endif
        endfor
        for entry in day_data[day_idx]
          let crow = s:dashboard_log_y(entry.rate, plot_h, log_bot, log_top)
          if r == crow | let drawn = entry.rate >= eff_aim ? '●' : '○' | endif
        endfor
      endif
      if drawn ==# ' ' && r == aim_row | let drawn = '·' | endif
      call add(row_chars, drawn)
    endfor
    call add(lines, '│ ' . label . axis_char . join(row_chars, '') . ' │')
  endfor

  " Compute labeled-day positions for x-axis ticks + MM-DD labels.
  " Same stride logic as :VfChart: cap ~5 labels for the dashboard's
  " narrower panel, with minimum spacing to keep 5-char MM-DD labels
  " from overlapping. Anchor the walk from the RIGHT (today) so today
  " gets a labeled tick whenever stride permits; the leftmost end of
  " the window only gets a label when stride lands cleanly there.
  " Stop adding labels once one would overflow plot_w (its 5-char
  " text wouldn't fit between the tick and the right border).
  let max_labels = 5
  let min_spacing_days = (6 + cols_per_day - 1) / cols_per_day
  let label_days = []
  if n_days > 0
    let raw_stride = (n_days + max_labels - 1) / max_labels
    let stride = max([min_spacing_days, raw_stride])
    let dd = n_days - 1
    while dd >= 0
      let col = dd * cols_per_day
      if col + 5 <= plot_w | call add(label_days, dd) | endif
      let dd -= stride
    endwhile
  endif

  " X-axis line with corner + inward ticks at every labeled day.
  let xaxis_chars = repeat(['─'], plot_w)
  for dd in label_days
    let col = dd * cols_per_day
    if col >= 0 && col < plot_w | let xaxis_chars[col] = '┴' | endif
  endfor
  call add(lines, '│ ' . repeat(' ', label_w) . '└' . join(xaxis_chars, '') . ' │')

  " X-axis date row: MM-DD left-aligned at each tick. Left-align
  " (rather than centering on the tick) keeps the first label clear
  " of the y-axis label column and matches :VfChart. The rightmost
  " 7 cells get overlaid with 'today →' — the arrow lands on the
  " very last column so the chart's calendar anchor is declared by
  " the axis itself rather than by a separate key-row footnote.
  let xlabel = repeat([' '], plot_w)
  for dd in label_days
    let col = dd * cols_per_day
    let date_str = s:iso_from_julian(base_jul + dd)[5:9]
    if col >= 0 && col + 4 < plot_w
      for i in range(5)
        let xlabel[col + i] = date_str[i]
      endfor
    endif
  endfor
  call s:overlay_today_marker(xlabel, plot_w)
  call add(lines, '│ ' . repeat(' ', label_w + 1) . join(xlabel, '') . ' │')

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

" LAST SESSION + breakdown for the hovered drill. Now lives in
" half the profile-row width (was 1/4), so we have room for the
" prereqs list and per-command sub-table the :VfList B-breakdown
" surfaces.
function! s:dashboard_last_session_breakdown_panel(id, registry, sessions, w, h) abort
  let runs = empty(a:id) ? [] : get(a:sessions, a:id, [])
  let usable = filter(copy(runs), 'get(v:val, "frequency_per_min", 0) > 0')
  call sort(usable, {a, b -> a.timestamp ==# b.timestamp ? 0
    \ : (a.timestamp <# b.timestamp ? -1 : 1)})

  " Title carries the date of the last session (when available) so the
  " learner sees recency at a glance; falls back to the plain title
  " for untrained drills.
  let last_date = empty(usable)
    \ ? ''
    \ : strpart(get(usable[-1], 'timestamp', ''), 0, 10)
  let title = empty(last_date)
    \ ? 'LAST SESSION'
    \ : printf('LAST SESSION: %s', last_date)
  let lines = [s:panel_box_top(title, a:w)]
  if empty(a:id) || !has_key(a:registry, a:id)
    call add(lines, '│' . s:pad_right(' (no row hovered)', a:w - 2) . '│')
    while len(lines) < a:h - 1 | call add(lines, '│' . repeat(' ', a:w - 2) . '│') | endwhile
    call add(lines, s:panel_box_bottom(a:w))
    return {'lines': lines, 'prereq_map': {}}
  endif

  let body = []
  if empty(usable)
    call add(body, ' (no sessions yet)')
  else
    let last = usable[-1]
    let dur = get(last, 'elapsed_seconds', get(last, 'duration_seconds', 0))
    let aim_val = get(last, 'aim', 0)
    let correct = get(last, 'items_correct', 0)
    let skipped = get(last, 'items_skipped', 0)
    let total = correct + skipped
    let wasted = max([0,
      \ get(last, 'total_motions', 0) - get(last, 'total_optimal_motions', 0)])
    let total_m = get(last, 'total_motions', 0)
    let opt_m   = get(last, 'total_optimal_motions', 0)
    let eff     = get(last, 'efficiency_pct', 0)

    " Classical PT rates: corrects per minute and errors per minute
    " (wasted motions per minute). Skips don't fold into either —
    " they're an abandoned-trial signal, not within-trial noise, and
    " they live in the counts block below as their own row.
    let rate = get(last, 'frequency_per_min', 0)
    if rate <= 0
      let rate = dur > 0 ? correct * 60.0 / dur : 0.0
    endif
    let err_rate = get(last, 'errors_per_min', 0)
    if err_rate <= 0
      let err_rate = dur > 0 ? wasted * 60.0 / dur : 0.0
    endif

    " Two-column layout: 12-char label area (left-aligned) then the
    " value. Numeric fields right-pad to widen the value column so
    " the trailing descriptor parentheticals on the rate / error /
    " efficiency rows line up vertically.
    call add(body, printf('  %-12s%s', 'drill:',    a:id))
    call add(body, printf('  %-12s%5.1fs', 'duration:', dur))
    call add(body, '')
    call add(body, printf('  %-12s%5.1f/min', 'aim_rate:', aim_val * 1.0))
    call add(body, printf('  %-12s%5.1f/min  (items reaching the target)',
      \ 'cor_rate:', rate))
    call add(body, printf('  %-12s%5.1f/min  (wasted motions)',
      \ 'err_rate:', err_rate))
    call add(body, '')
    call add(body, printf('  %-12s%4d%%      (%d motions for %d optimal)',
      \ 'efficiency:', float2nr(eff), total_m, opt_m))
    call add(body, printf('  %-12s%4d', 'correct:',  correct))
    call add(body, printf('  %-12s%4d', 'errors:',   wasted))
    call add(body, printf('  %-12s%4d', 'skipped:',  skipped))
    call add(body, printf('  %-12s%4d', 'total:',    total))
  endif

  " Sub-blocks: commands first (the just-trained breakdown), then
  " prereqs (diagnostic context for the drill). A blank line
  " separates each section from the stats block above and from each
  " other so the panel reads as three distinct paragraphs.
  let meta = a:registry[a:id]

  " Commands sub-table — header + one row per motion in the last
  " session. Mirrors the breakdown columns from s:append_breakdown
  " (command, last_rate, stroke_count, stroke_rate).
  if !empty(usable)
    let pm = get(usable[-1], 'per_motion', {})
    if !empty(pm)
      let eff_aim_for_drill = get(get(s:load_settings(), 'aims', {}), a:id, get(meta, 'aim', 0))
      let stroke_overrides = get(meta, 'stroke_counts', {})
      call add(body, '')
      call add(body, '  commands:')
      call add(body, printf('   %-6s  %9s  %7s  %s',
        \ 'command', 'last_rate', 'strokes', 'stroke_rate'))
      for motion in sort(keys(pm))
        let mrate_f = get(pm[motion], 'rate_per_min', 0)
        let mrate_i = float2nr(mrate_f + 0.5)
        let strokes = get(stroke_overrides, motion, s:command_strokes(motion))
        let mark = mrate_i >= eff_aim_for_drill ? '✓' : ' '
        call add(body, printf(' %s %-6s  %6d/min  %4d str  %s',
          \ mark, motion, mrate_i, strokes,
          \ s:stroke_rate_field(mrate_f, strokes)))
      endfor
    endif
  endif

  " Prereqs sub-block — one line per prereq with its current status
  " icon, matching the :VfList B-breakdown formatting. Track each
  " prereq line's body index so the renderer can build a buffer-line
  " → prereq-id map for the J keystroke (jump to prereq in table).
  " body index → prereq id; populated only when prereqs are listed.
  " Initialized at function scope so the post-build map-construction
  " loop runs cleanly even when no prereqs exist.
  let body_prereq_lines = {}
  let prereqs = filter(copy(get(meta, 'prereqs', [])),
    \ 'has_key(a:registry, v:val)')
  if !empty(prereqs)
    call add(body, '')
    call add(body, '  prereqs:')
    let aim_overrides = get(s:load_settings(), 'aims', {})
    for p in prereqs
      let p_runs = get(a:sessions, p, [])
      let p_meta = a:registry[p]
      let p_aim = get(aim_overrides, p, get(p_meta, 'aim', 0))
      let p_status = s:status_from_sessions(p_aim, p_runs)
      call add(body, printf('   %s %s', s:status_icon(p_status), p))
      let body_prereq_lines[len(body) - 1] = p
    endfor
  endif

  " LAST SESSION renders the *full* body — no truncation. Drills with
  " more commands / prereqs than fit in the side panel push the
  " bottom below the visible window; the user reaches them by
  " pressing `B` to jump into the panel and scrolling (j/k).
  "
  " Build the prereq line→id map keyed on the line index INSIDE this
  " returned list (so the caller doesn't need to know about the
  " 'box_top + body' offset arithmetic). Body item i lives at
  " lines[i + 1] because lines[0] is the top border.
  let prereq_map = {}
  for [bi, p] in items(body_prereq_lines)
    let prereq_map[str2nr(bi) + 1] = p
  endfor
  for r in body
    call add(lines, '│' . s:pad_right(r, a:w - 2) . '│')
  endfor
  while len(lines) < a:h - 1 | call add(lines, '│' . repeat(' ', a:w - 2) . '│') | endwhile
  call add(lines, s:panel_box_bottom(a:w))
  return {'lines': lines, 'prereq_map': prereq_map}
endfunction

" Build the one-line fluency banner shared by the dashboard's top
" window and the :VfList sticky header: path name, drills-fluent
" fraction, at-aim / climbing / not-started status counts, then the
" global session totals, padded to `cols`.
"
" at_aim / climbing / not_started count only drills in a:registry (so
" they respect the current path filter), but the session totals
" (session_count, total_elapsed) iterate over EVERY entry in
" a:sessions, NOT just those that match a drill in the current
" registry. The audit's renames left log entries under old drill ids
" (e.g. 'insert_basic', 'discriminate_find_vs_till'), and those still
" count as real training time the learner spent even though the slug
" no longer maps to anything live.
function! s:fluency_banner_line(registry, sessions, cols) abort
  let aim_overrides = get(s:load_settings(), 'aims', {})
  let at_aim = 0 | let climbing = 0 | let not_started = 0
  let total_drills = len(a:registry)

  for [id, m] in items(a:registry)
    let runs = get(a:sessions, id, [])
    let eff_aim = get(aim_overrides, id, get(m, 'aim', 0))
    let status = s:status_from_sessions(eff_aim, runs)
    if     status ==# 'at_aim'      | let at_aim += 1
    elseif status ==# 'climbing'    | let climbing += 1
    else                            | let not_started += 1
    endif
  endfor

  let total_elapsed = 0.0
  let session_count = 0
  for runs in values(a:sessions)
    for s in runs
      let total_elapsed += get(s, 'elapsed_seconds', 0)
      let session_count += 1
    endfor
  endfor

  let fluent_pct = total_drills > 0
    \ ? float2nr(at_aim * 100.0 / total_drills + 0.5)
    \ : 0
  let path_scope = total_drills > 0
    \ ? printf(' (%d/%d drills fluent · %d%%)', at_aim, total_drills, fluent_pct)
    \ : ''
  let status_block = printf('✓ %d  ▶ %d  ○ %d',
    \ at_aim, climbing, not_started)
  return s:pad_right(printf(
    \ '─ Vim Fluency ─── Path: %s%s  │  %s  │  %d sessions | %s trained ',
    \ s:format_path(s:effective_path()), path_scope, status_block,
    \ session_count, s:format_duration(total_elapsed)), a:cols)
endfunction

function! s:dashboard_render_banner(registry, sessions, cols) abort
  call s:dashboard_write_buffer(
    \ get(b:, 'vf_dashboard_banner_bufnr', -1),
    \ [s:fluency_banner_line(a:registry, a:sessions, a:cols)])
endfunction

" Render the LAST SESSION side panel (right of the table). Reuses
" s:dashboard_last_session_breakdown_panel for the box shape; the
" panel renders the *full* breakdown — no truncation — and the
" learner reaches commands / prereqs that fall below the visible
" window by pressing B (which drops the cursor into this buffer
" with the title scrolled to the top).
function! s:dashboard_render_last_session(mapping, row, registry, sessions) abort
  let bufnr = get(b:, 'vf_dashboard_last_session_bufnr', -1)
  if bufnr <= 0 | return | endif
  let hovered_id = get(a:mapping, a:row, '')
  " Panel width is the side-panel width minus a one-column gutter on
  " either side (matches the rest of the dashboard's `gap` aesthetic).
  let w = s:DASHBOARD_LAST_SESSION_WIDTH - 2
  " Size the panel to fill the visible window so the bottom border
  " sits at the window's bottom edge — without this, short drills
  " leave the box closing mid-window and the rest of the panel
  " looking empty. We fall back to a small minimum if we can't
  " find the window (the buffer renders before the window settles
  " on first show). Long drills (more rows than the window holds)
  " overflow past the bottom and are scrollable via B + j/k.
  let win_h = 6
  for win in range(1, winnr('$'))
    if winbufnr(win) == bufnr
      let win_h = max([winheight(win), 6])
      break
    endif
  endfor
  let result = s:dashboard_last_session_breakdown_panel(
    \ hovered_id, a:registry, a:sessions, w, win_h)
  let padded = []
  for l in result.lines
    call add(padded, ' ' . l)
  endfor
  call s:dashboard_write_buffer(bufnr, padded)
  " Stash the buffer-line → prereq-id map on the last-session buffer
  " so J (jump-to-prereq) can resolve the cursor row to an id without
  " re-parsing the rendered text. Panel returns 0-indexed line numbers
  " inside its own lines[] list; the buffer is 1-indexed, so shift +1.
  let buffer_prereq_map = {}
  for [k, p] in items(result.prereq_map)
    let buffer_prereq_map[str2nr(k) + 1] = p
  endfor
  call setbufvar(bufnr, 'vf_dashboard_prereq_map', buffer_prereq_map)
endfunction

" Drills-per-day celeration chart: training session count per day
" plotted on a log y-axis. Mirrors the SCC's x-axis style — calendar
" anchored to today on the right, MM-DD labels at strided ticks,
" same footer convention — so the two charts read as a pair.
" Days with zero training don't get a dot (log scale can't represent
" 0) — the gap itself is the cue.
function! s:dashboard_daily_chart_panel(by_day, days_back, today_count, streak, w, h) abort
  " Title carries the live stats inline — today's count and streak
  " — separated by │ the same way the top-of-dashboard banner
  " groups its sub-statistics. Frees the row below the title for
  " the chart's key (legend).
  let title = printf('DRILLS PER DAY (last %dd)  │  today: %d  │  streak: %d day%s',
    \ a:days_back, a:today_count, a:streak, a:streak == 1 ? '' : 's')
  let lines = [s:panel_box_top(title, a:w)]

  " Key row — same structural slot the SCC uses, and 'log y' starts
  " at column 2 so the 'y' character sits directly above the y-axis.
  let key = ' log y (y = drills/day)'
  call add(lines, '│' . s:pad_right(key, a:w - 2) . '│')

  let label_w = 4
  let plot_w = a:w - 5 - label_w
  " Non-plot rows: top border + key row + x-axis line + MM-DD label
  " row + bottom border = 5.
  let plot_h = max([a:h - 5, 3])

  " Walk the day window from oldest (i=0) to today (i=n_days-1).
  " Anchor today to the right edge (col plot_w - 1); leftmost day
  " sits at col 0. Use julian day math so the date lookup matches
  " what the SCC does — by_day is keyed on YYYY-MM-DD.
  let today_jul = s:julian_from_iso(strftime('%Y-%m-%d'))
  let n_days = a:days_back
  let base_jul = today_jul - n_days + 1
  let cols_per_day = n_days > 1 ? (plot_w - 1) * 1.0 / (n_days - 1) : 0.0
  let col_for_day = []
  let counts = []
  for i in range(n_days)
    " float2nr(round(...)) lands the rightmost day flush at plot_w-1
    " (today) and the leftmost at col 0 — float2nr alone truncates,
    " which leaves today one column shy of the edge.
    call add(col_for_day, n_days > 1
      \ ? float2nr(round(i * cols_per_day)) : 0)
    call add(counts, get(a:by_day, s:iso_from_julian(base_jul + i), 0))
  endfor

  " Same fixed bounds as the SCC (1..~316). The unit here is
  " sessions-per-day rather than rate/min, but the SCC philosophy
  " is one y-axis everywhere — a day with 30 sessions reads at the
  " same vertical position regardless of which chart you're
  " looking at.
  let log_bot = 0.0
  let log_top = 2.5

  let label_rows = {}
  let lg = floor(log_top)
  while lg >= log_bot
    call s:add_label_rows(label_rows, plot_h, log_bot, log_top, float2nr(pow(10.0, lg) + 0.5))
    let lg -= 1.0
  endwhile

  for r in range(plot_h)
    let label = has_key(label_rows, r)
      \ ? printf('%' . label_w . 'd', label_rows[r])
      \ : repeat(' ', label_w)
    let axis_char = has_key(label_rows, r) ? '├' : '│'
    let row_chars = repeat([' '], plot_w)
    for day_i in range(n_days)
      let n = counts[day_i]
      if n <= 0 | continue | endif
      let plotted_row = s:dashboard_log_y(n * 1.0, plot_h, log_bot, log_top)
      if r == plotted_row
        let c = col_for_day[day_i]
        if c < plot_w | let row_chars[c] = '●' | endif
      endif
    endfor
    call add(lines, '│ ' . label . axis_char . join(row_chars, '') . ' │')
  endfor

  " Same right-anchored stride walk as the SCC. Today (day_i =
  " n_days - 1) sits flush at plot_w - 1, so its 5-char label
  " would overflow — the 'right edge = today' footer note carries
  " the convention.
  let max_labels = 4
  let raw_stride = (n_days + max_labels - 1) / max_labels
  let stride = max([2, raw_stride])
  let label_days = []
  let dd = n_days - 1
  while dd >= 0
    let col = col_for_day[dd]
    if col + 5 <= plot_w | call add(label_days, dd) | endif
    let dd -= stride
  endwhile

  let xaxis_chars = repeat(['─'], plot_w)
  for dd in label_days
    let col = col_for_day[dd]
    if col >= 0 && col < plot_w | let xaxis_chars[col] = '┴' | endif
  endfor
  call add(lines, '│ ' . repeat(' ', label_w) . '└' . join(xaxis_chars, '') . ' │')

  let xlabel = repeat([' '], plot_w)
  for dd in label_days
    let col = col_for_day[dd]
    let date_str = s:iso_from_julian(base_jul + dd)[5:9]
    if col + 4 < plot_w
      for i in range(5)
        let xlabel[col + i] = date_str[i]
      endfor
    endif
  endfor
  call s:overlay_today_marker(xlabel, plot_w)
  call add(lines, '│ ' . repeat(' ', label_w + 1) . join(xlabel, '') . ' │')

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
      " Reset scroll: the profile buffer can be taller than the
      " profile window (when LAST SESSION has prereqs + many
      " commands). After re-rendering we want the window scrolled
      " to line 1 so the next hover-driven update starts from the
      " top rather than wherever the user previously scrolled to.
      keepjumps call cursor(1, 1)
      normal! zt
      break
    endif
  endfor
  call win_gotoid(cur_winid)
endfunction

" Overlay 'today →' on the rightmost cells of an x-axis label list.
" The arrow lands on the very last column (plot_w - 1); the word
" 'today' sits to its left, separated by a space. Replaces whatever
" was there before — by design, since today is the calendar anchor
" and visually owns the right edge.
function! s:overlay_today_marker(cells, plot_w) abort
  let marker = ['t', 'o', 'd', 'a', 'y', ' ', '→']
  let start = a:plot_w - len(marker)
  if start < 0 | return | endif
  for i in range(len(marker))
    let a:cells[start + i] = marker[i]
  endfor
endfunction

" ──────────── small text helpers for the dashboard ────────────

function! s:panel_box_top(title, w) abort
  let title_padded = ' ' . a:title . ' '
  " strdisplaywidth (not len()) so multi-byte glyphs in the title —
  " ✓, ▶, │ — count as their on-screen cell width instead of their
  " UTF-8 byte count. Without this the dash run is too short and the
  " box's right edge slides left every time we land a UTF-8 char in
  " the title.
  let dashes = repeat('─', max([a:w - strdisplaywidth(title_padded) - 2, 0]))
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
