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

function! vimfluency#discover_pinpoints() abort
  let registry = {}
  let files = globpath(&runtimepath, 'autoload/vimfluency/pinpoints/p*.vim', 0, 1)
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

function! vimfluency#list() abort
  let registry = vimfluency#discover_pinpoints()
  if empty(registry)
    echo 'no pinpoints found on runtimepath'
    return
  endif
  echo printf('%-8s %-32s %s', 'id', 'name', 'aim/min')
  for id in sort(keys(registry))
    let p = registry[id]
    echo printf('%-8s %-32s %d', p.id, p.name, p.aim)
  endfor
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
  let duration = len(positional) >= 2 ? str2nr(positional[1]) : 60
  let only_filter = has_key(kwargs, 'only')
    \ ? filter(split(kwargs.only, ','), '!empty(v:val)') : []

  let registry = vimfluency#discover_pinpoints()
  if !has_key(registry, id)
    echo 'unknown pinpoint: ' . id . '  (try :VfList)'
    return
  endif
  let info = registry[id]

  let s:session = {
    \ 'mode': 'probe',
    \ 'id': info.id,
    \ 'name': info.name,
    \ 'aim': info.aim,
    \ 'module': info.module,
    \ 'kind': get(info, 'kind', 'motion'),
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
    \ 'prev_laststatus': &laststatus,
    \ }

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
  while attempts < 100
    let item = GenFn()
    if empty(s:session.only_filter)
      \ || index(s:session.only_filter, get(item, 'expected_motion', '')) >= 0
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

  " Editing-kind probes get a 2-line header (prompt + divider) above the
  " live editing area. Match checks subtract the header offset.
  let header = []
  if s:session.kind ==# 'editing'
    let prompt = get(item, 'prompt', 'edit to match the target')
    let header = [prompt, repeat('─', 60)]
  endif
  let s:session.header_offset = len(header)

  setlocal modifiable
  silent! %delete _
  call setline(1, header + item.lines)
  call cursor(s:session.header_offset + item.start[0], item.start[1])

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  " Priority 20 puts the target on top of the deletion-range red, so
  " the "where the cursor will end up" cell is still legible when the
  " target sits inside the deletion range (e.g. dw, where target_col
  " == start_col == first deleted cell).
  let s:session.target_match_id = matchaddpos('VfTarget',
    \ [[s:session.header_offset + item.target[0], item.target[1], 1]], 20)

  " Deletion-range highlight (editing probes that mark which characters
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

  redrawstatus
  let s:session.advancing = 0
endfunction

function! s:install_autocmds() abort
  augroup VfProbe
    autocmd!
    autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI <buffer>
      \ call s:on_change()
  augroup END
  nnoremap <buffer> <silent> <Tab> :call <SID>skip()<CR>
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

  " Skip vim's deferred autocmd fire after our in-handler cursor() in
  " s:next_item: cursor is still at start AND buffer is still in start
  " state. Editing motions like `dw` keep the cursor at the same col
  " but change the buffer — the buffer-state check distinguishes those
  " from the spurious deferred fire.
  if cur_pos == item.start
    \ && cur_lines ==# start_lines
    \ && s:session.current_item_motions == 0
    return
  endif

  let s:session.current_item_motions += 1

  if cur_lines ==# target_lines && cur_pos == item.target
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
  endif
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
  if get(s:session, 'mode', 'probe') ==# 'learn'
    call vimfluency#learn_stop()
    return
  endif
  if has_key(s:session, 'timer')
    call timer_stop(s:session.timer)
  endif
  silent! augroup VfProbe | autocmd! | augroup END

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
  call add(lines, '  Press q or <Enter> to close.')

  " Render into the (still-open) probe buffer; user dismisses explicitly.
  let prev_laststatus = s:session.prev_laststatus
  let tabnr = s:session.tabnr
  let target_id = s:session.target_match_id
  let deletion_id = s:session.deletion_match_id
  let you_win = get(s:session, 'you_win', 0)
  let s:session = {}

  if you_win > 0 && win_id2win(you_win) > 0
    call win_gotoid(you_win)
    if target_id != -1
      silent! call matchdelete(target_id)
    endif
    if deletion_id != -1
      silent! call matchdelete(deletion_id)
    endif
    setlocal modifiable
    silent! %delete _
    call setline(1, lines)
    setlocal nomodifiable nomodified
    silent! execute 'keepalt file vf-summary-' . record.pinpoint_id
    let &l:statusline = ' session ended  [press q or <Enter> to close]'
    let b:vf_summary_tabnr = tabnr
    let b:vf_summary_prev_laststatus = prev_laststatus
    nnoremap <buffer> <silent> q :call vimfluency#close_summary()<CR>
    nnoremap <buffer> <silent> <CR> :call vimfluency#close_summary()<CR>
    call cursor(1, 1)
  else
    " probe window/tab is gone — fall back to echoing
    silent! execute 'tabclose ' . tabnr
    let &laststatus = prev_laststatus
    for line in lines
      echo line
    endfor
  endif
endfunction

function! vimfluency#close_summary() abort
  if exists('b:vf_summary_tabnr')
    let tabnr = b:vf_summary_tabnr
    let prev_ls = b:vf_summary_prev_laststatus
    silent! execute 'tabclose ' . tabnr
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
" Lesson mode (DI-style example/non-example sequencing before a probe)
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
    \ 'frames': frames,
    \ 'frame_idx': 0,
    \ 'frame_complete': 0,
    \ 'phase': 'setup',
    \ 'streak': 0,
    \ 'required_streak': 3,
    \ 'max_test_items': 20,
    \ 'max_wrongs': 3,
    \ 'test_items_seen': 0,
    \ 'wrongs': 0,
    \ 'test_motion_count': 0,
    \ 'last_item_motions': 0,
    \ 'last_item_optimal': 0,
    \ 'current_test_item': {},
    \ 'prev_laststatus': &laststatus,
    \ 'target_match_id': -1,
    \ 'deletion_match_id': -1,
    \ 'waypoint_match_ids': [],
    \ 'advancing': 0,
    \ }

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
    if s:session.frame_complete
      if s:session.last_item_motions <= s:session.last_item_optimal
        if s:session.streak >= s:session.required_streak
          let hint = printf('✓ %d/%d streak!  [Space=start probe]',
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
      let hint = printf('streak %d/%d  [reach the green cell, fewest keystrokes]',
        \ cur, req)
      if get(s:session, 'kind', 'motion') ==# 'editing'
        let hint .= '  [u=undo if wrong]'
      endif
    endif
    return printf('LESSON %s  TEST  %s  [q=quit]', s:session.id, hint)
  endif

  let frame = s:session.frames[s:session.frame_idx]
  let total = len(s:session.frames)
  let idx = s:session.frame_idx + 1
  if s:session.frame_complete
    let hint = '✓ correct  [Space=next]'
  elseif frame.kind ==# 'show'
    let hint = '[Space=next]'
  else
    let hint = '[reach the green cell]'
    if get(s:session, 'kind', 'motion') ==# 'editing'
      let hint .= '  [u=undo if wrong]'
    endif
  endif
  return printf('LESSON %s  SETUP %d/%d  %s  [q=quit]',
    \ s:session.id, idx, total, hint)
endfunction

function! s:learn_show_frame() abort
  let s:session.advancing = 1
  let s:session.frame_complete = 0
  let frame = s:session.frames[s:session.frame_idx]

  let base_header = [
    \ s:learn_header_line(),
    \ '',
    \ frame.prompt,
    \ '',
    \ ]
  " Annotation row sits at the END of the header (just above the
  " content), so the cur_lines comparison in s:learn_on_change still
  " excludes it via header_offset.
  let header = base_header + s:waypoint_annotation(frame)
  let s:session.header_offset = len(header)

  setlocal modifiable
  silent! %delete _
  call setline(1, header + frame.lines)

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
    let s:session.target_match_id = matchaddpos('VfLearnShow',
      \ [[buf_row, frame.cursor[1], 1]])
  else
    let buf_start_row = s:session.header_offset + frame.start[0]
    let buf_target_row = s:session.header_offset + frame.target[0]
    call cursor(buf_start_row, frame.start[1])
    let s:session.target_match_id = matchaddpos('VfTarget',
      \ [[buf_target_row, frame.target[1], 1]], 20)
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
  augroup VfLearn
    autocmd!
    " TextChanged is needed for the test phase on editing-kind pinpoints
    " where dw/db etc. modify the buffer without necessarily firing
    " CursorMoved (e.g. dw at col 1 leaves cursor at col 1).
    autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI <buffer>
      \ call s:learn_on_change()
  augroup END
  nnoremap <buffer> <silent> <Space> :call <SID>learn_advance_show()<CR>
  nnoremap <buffer> <silent> <CR> :call <SID>learn_advance_show()<CR>
  nnoremap <buffer> <silent> q :call vimfluency#learn_stop()<CR>
  nnoremap <buffer> <silent> p :call <SID>learn_start_probe()<CR>
endfunction

" Space/Enter: advance from a 'show' frame, from a completed 'try' frame,
" or from a completed test-phase item.
function! s:learn_advance_show() abort
  if empty(s:session) || s:session.mode !=# 'learn' || s:session.advancing | return | endif
  if s:session.phase ==# 'complete' | return | endif
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

    " Deferred-autocmd guard: skip the spurious CursorMoved that fires
    " after our in-handler cursor() in s:learn_test_next.
    if cur_pos == item.start && cur_lines ==# start_lines
      \ && s:session.test_motion_count == 0
      return
    endif
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

  setlocal modifiable
  silent! %delete _
  call setline(1, [
    \ printf('LESSON %s  COMPLETE  [p=start probe]  [q=quit]', s:session.id),
    \ '',
    \ printf('  ✓ 3 in a row on %s — nice work.', s:session.name),
    \ '',
    \ '  The probe presents the same kind of items, but on a 60-second',
    \ '  clock. The lesson just confirmed you know the rule; the probe',
    \ '  is where you build fluency — the speed and automaticity that',
    \ '  make a motion useful during real editing. Knowing how a motion',
    \ '  works and being fluent at it are different things, and only',
    \ '  repetition under time pressure closes the gap.',
    \ '',
    \ '  Smooth is slow. Slow is fast.',
    \ '',
    \ '  Each probe writes a data point to the session log;',
    \ printf('  :VfChart %s plots your rate over days.', s:session.id),
    \ '',
    \ printf('    p   start :Vf %s', s:session.id),
    \ '    q   exit (run :Vf later when ready)',
    \ ])
  call cursor(1, 1)
  let s:session.advancing = 0
endfunction

" Triggered by the p mapping on the completion screen. No-op anywhere
" else, so p stays inert during normal lesson flow.
function! s:learn_start_probe() abort
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
  let s:session.test_motion_count = 0
  let s:session.frame_complete = 0
  let s:session.last_item_motions = 0
  let s:session.last_item_optimal = 0
  let s:session.current_test_item = {}
  call s:learn_show_frame()
  if a:reason ==# 'cap'
    echo printf('lesson %s: hit %d-item test cap without 3-in-a-row — restarting from the top.',
      \ id, cap)
  elseif a:reason ==# 'wrongs'
    echo printf('lesson %s: 3 wrong in a row — restarting from the top.', id)
  endif
endfunction

" Generate a fresh test item from the pinpoint and render it. Reuses the
" pinpoint's generate() so test items have the same cheat-defense as
" probe items — meaning the intended motion is the canonical answer and
" optimal_motions is the criterion for "first-try correct".
function! s:learn_test_next() abort
  let s:session.advancing = 1
  let s:session.frame_complete = 0
  let s:session.test_motion_count = 0
  let s:session.test_items_seen += 1

  let GenFn = function('vimfluency#pinpoints#' . s:session.module . '#generate')
  let item = GenFn()
  let s:session.current_test_item = item

  let has_waypoints = has_key(item, 'waypoints') && !empty(item.waypoints)
  let test_prompt = has_waypoints
    \ ? 'Reach each numbered target in order. Fewer keystrokes is better.'
    \ : 'Reach the target — figure out the motion. Fewer keystrokes is better.'
  let lesson_header = [
    \ s:learn_header_line(),
    \ '',
    \ test_prompt,
    \ '',
    \ ]

  " Editing items get the runner's prompt+divider header above the live
  " editing area, mirroring what the probe shows.
  let editing_header = []
  if get(s:session, 'kind', 'motion') ==# 'editing'
    let prompt = get(item, 'prompt', 'edit to match the target')
    let editing_header = [prompt, repeat('─', 60)]
  endif
  let full_header = lesson_header + editing_header + s:waypoint_annotation(item)
  let s:session.header_offset = len(full_header)

  setlocal modifiable
  silent! %delete _
  call setline(1, full_header + item.lines)
  call cursor(s:session.header_offset + item.start[0], item.start[1])

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  let s:session.target_match_id = matchaddpos('VfTarget',
    \ [[s:session.header_offset + item.target[0], item.target[1], 1]], 20)

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
  let id = s:session.id
  if has_key(s:session, 'tabnr')
    silent! execute 'tabclose ' . s:session.tabnr
  endif
  let s:session = {}
  echo 'lesson ended for ' . id . ' — try :Vf ' . id
endfunction

" -----------------------------------------------------------------
" Standard Celeration Chart (text-only)
" -----------------------------------------------------------------

" Y-axis layout: log10 scale, 3 decades (1 → 1000), 24 rows total.
let s:CHART_HEIGHT = 24
let s:CHART_DECADES = 3
let s:CHART_LOG_TOP = 3.0    " log10(1000)
let s:CHART_LOG_BOT = 0.0    " log10(1)
let s:CHART_LABEL_W = 6
let s:CHART_COLS_PER_SESSION = 2

function! s:chart_y(rate) abort
  if a:rate <= 0
    return s:CHART_HEIGHT
  endif
  let lr = log10(a:rate * 1.0)
  if lr < s:CHART_LOG_BOT
    return s:CHART_HEIGHT
  endif
  if lr > s:CHART_LOG_TOP
    return 0
  endif
  let span = s:CHART_LOG_TOP - s:CHART_LOG_BOT
  return float2nr(round((s:CHART_LOG_TOP - lr) / span * s:CHART_HEIGHT))
endfunction

function! vimfluency#chart(...) abort
  if a:0 < 1
    echo 'usage: :VfChart <pinpoint_id>'
    return
  endif
  let id = a:1
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
      if get(r, 'pinpoint_id', '') ==# id
        call add(sessions, r)
      endif
    catch
    endtry
  endfor

  if empty(sessions)
    echo 'no sessions for pinpoint ' . id
    return
  endif

  call sort(sessions, {a, b -> a.timestamp ==# b.timestamp ? 0
    \ : (a.timestamp <# b.timestamp ? -1 : 1)})

  let lines = s:render_chart(id, sessions)
  call s:show_chart_buffer(id, lines)
endfunction

function! s:render_chart(id, sessions) abort
  let n = len(a:sessions)
  let pinpoint_name = a:sessions[0].pinpoint_name
  let aim = a:sessions[0].aim
  let chart_w = n * s:CHART_COLS_PER_SESSION
  let total_w = s:CHART_LABEL_W + 1 + chart_w + 1

  " Initialize grid: each row is a list of single-char strings
  let grid = []
  for r in range(s:CHART_HEIGHT + 1)
    call add(grid, repeat([' '], total_w))
  endfor

  " Y-axis labels at decade boundaries
  for [rate, lbl] in [[1000, '1000'], [100, ' 100'], [10, '  10'], [1, '   1']]
    let row = s:chart_y(rate)
    if row >= 0 && row <= s:CHART_HEIGHT
      let label = printf('%5s', lbl)
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
  let aim_row = s:chart_y(aim)
  if aim_row > 0 && aim_row < s:CHART_HEIGHT
    for c in range(s:CHART_LABEL_W + 1, total_w - 1)
      let grid[aim_row][c] = '-'
    endfor
  endif

  " Plot each session
  for i in range(n)
    let session = a:sessions[i]
    let col = s:CHART_LABEL_W + 1 + i * s:CHART_COLS_PER_SESSION
    if col >= total_w | break | endif

    let crate = get(session, 'frequency_per_min', 0)
    let crow = s:chart_y(crate)
    if crow >= 0 && crow <= s:CHART_HEIGHT
      let grid[crow][col] = '●'
    endif

    let erate = get(session, 'errors_per_min', 0)
    if erate > 0
      let erow = s:chart_y(erate)
      if erow >= 0 && erow <= s:CHART_HEIGHT
        let grid[erow][col] = '×'
      endif
    endif
  endfor

  " Compose output lines
  let out = []
  call add(out, printf('vimfluency celeration chart — %s (%s)', a:id, pinpoint_name))
  call add(out, printf('aim %d/min   ·   %d session(s)   ·   ● corrects   × errors   - aim',
    \ aim, n))
  call add(out, '')
  for row_chars in grid
    call add(out, join(row_chars, ''))
  endfor

  " Compute first→last celeration for the corrects line
  if n >= 2
    let first = a:sessions[0].frequency_per_min
    let last = a:sessions[-1].frequency_per_min
    if first > 0
      call add(out, printf(' first→last on corrects: ×%.2f over %d sessions',
        \ last / first, n))
    endif
  endif
  call add(out, printf(' first session: %s', a:sessions[0].timestamp))
  call add(out, printf(' last  session: %s', a:sessions[-1].timestamp))
  call add(out, '')
  call add(out, ' Press q or <Enter> to close.')

  return out
endfunction

function! s:show_chart_buffer(id, lines) abort
  tabnew
  let tabnr = tabpagenr()
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  silent! execute 'keepalt file vf-chart-' . a:id
  call setline(1, a:lines)
  setlocal nomodifiable nomodified
  let &l:statusline = ' celeration chart — ' . a:id . '   [press q or <Enter> to close]'
  let b:vf_summary_tabnr = tabnr
  let b:vf_summary_prev_laststatus = &laststatus
  set laststatus=2
  nnoremap <buffer> <silent> q :call vimfluency#close_summary()<CR>
  nnoremap <buffer> <silent> <CR> :call vimfluency#close_summary()<CR>
  call cursor(1, 1)
endfunction
