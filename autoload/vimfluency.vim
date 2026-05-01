" Session state. Empty dict when no session is active.
let s:session = {}

function! s:round3(x) abort
  return str2float(printf('%.3f', a:x))
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
  let s:session.target_match_id = matchaddpos('VfTarget',
    \ [[s:session.header_offset + item.target[0], item.target[1], 1]])

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
    let s:session.deletion_match_id = matchaddpos('VfDeletion', positions)
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
    \ 'frames': frames,
    \ 'frame_idx': 0,
    \ 'prev_laststatus': &laststatus,
    \ 'target_match_id': -1,
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

function! s:learn_show_frame() abort
  let s:session.advancing = 1
  let frame = s:session.frames[s:session.frame_idx]

  let total = len(s:session.frames)
  let idx = s:session.frame_idx + 1
  let hint = frame.kind ==# 'show' ? '[Space=next]' : '[reach the green cell]'
  let header = [
    \ printf('LESSON %s  (%d/%d)  %s  [q=quit]',
    \   s:session.id, idx, total, hint),
    \ '',
    \ frame.prompt,
    \ '',
    \ ]
  let s:session.header_offset = len(header)

  setlocal modifiable
  silent! %delete _
  call setline(1, header + frame.lines)

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif

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
      \ [[buf_target_row, frame.target[1], 1]])
  endif

  let s:session.advancing = 0
endfunction

function! s:learn_install_autocmds() abort
  augroup VfLearn
    autocmd!
    autocmd CursorMoved,CursorMovedI <buffer> call s:learn_on_change()
  augroup END
  nnoremap <buffer> <silent> <Space> :call <SID>learn_advance_show()<CR>
  nnoremap <buffer> <silent> <CR> :call <SID>learn_advance_show()<CR>
  nnoremap <buffer> <silent> q :call vimfluency#learn_stop()<CR>
endfunction

function! s:learn_advance_show() abort
  if empty(s:session) || s:session.mode !=# 'learn' || s:session.advancing | return | endif
  if s:session.frames[s:session.frame_idx].kind !=# 'show' | return | endif
  call s:learn_next()
endfunction

function! s:learn_on_change() abort
  if empty(s:session) || s:session.mode !=# 'learn' || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif
  let frame = s:session.frames[s:session.frame_idx]
  if frame.kind !=# 'try' | return | endif
  let buf_target_row = s:session.header_offset + frame.target[0]
  if [line('.'), col('.')] == [buf_target_row, frame.target[1]]
    call s:learn_next()
  endif
endfunction

function! s:learn_next() abort
  let s:session.frame_idx += 1
  if s:session.frame_idx >= len(s:session.frames)
    call vimfluency#learn_stop()
    return
  endif
  call s:learn_show_frame()
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
