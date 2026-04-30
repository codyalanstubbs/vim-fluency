" Session state. Empty dict when no session is active.
let s:session = {}

function! s:round3(x) abort
  return str2float(printf('%.3f', a:x))
endfunction

function! toi#log_dir() abort
  let dir = exists('$XDG_DATA_HOME') && !empty($XDG_DATA_HOME)
    \ ? $XDG_DATA_HOME . '/toi'
    \ : expand('~/.local/share/toi')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  return dir
endfunction

function! toi#discover_pinpoints() abort
  let registry = {}
  let files = globpath(&runtimepath, 'autoload/toi/pinpoints/p*.vim', 0, 1)
  for f in files
    let mod = fnamemodify(f, ':t:r')
    let MetaFn = function('toi#pinpoints#' . mod . '#meta')
    let info = MetaFn()
    let info.module = mod
    let registry[info.id] = info
  endfor
  return registry
endfunction

function! toi#complete(arglead, cmdline, cursorpos) abort
  let registry = toi#discover_pinpoints()
  return filter(sort(keys(registry)), 'v:val =~# "^" . a:arglead')
endfunction

function! toi#list() abort
  let registry = toi#discover_pinpoints()
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

function! toi#start(...) abort
  if !empty(s:session)
    echo 'a session is already active; :ToiQuit first'
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
    echo 'usage: :Toi <id> [duration] [only=motion[,motion...]]'
    return
  endif
  let id = positional[0]
  let duration = len(positional) >= 2 ? str2nr(positional[1]) : 60
  let only_filter = has_key(kwargs, 'only')
    \ ? filter(split(kwargs.only, ','), '!empty(v:val)') : []

  let registry = toi#discover_pinpoints()
  if !has_key(registry, id)
    echo 'unknown pinpoint: ' . id . '  (try :ToiList)'
    return
  endif
  let info = registry[id]

  let s:session = {
    \ 'mode': 'probe',
    \ 'id': info.id,
    \ 'name': info.name,
    \ 'aim': info.aim,
    \ 'module': info.module,
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
  let &l:statusline = '%{toi#statusline()}'
  set laststatus=2
  let s:session.you_win = win_getid()
endfunction

function! toi#statusline() abort
  if empty(s:session) | return '' | endif
  let elapsed = reltimefloat(reltime(s:session.started_at))
  let remaining = max([0, s:session.duration - elapsed])
  let rate = elapsed > 0 ? s:session.items_correct * 60.0 / elapsed : 0.0
  let filter_tag = empty(get(s:session, 'only_filter', []))
    \ ? '' : ' [only=' . join(s:session.only_filter, ',') . ']'
  return printf(' %s — %s%s   time %ds   correct %d   rate %.1f/min   aim %d/min   [Tab=skip :ToiQuit=quit]',
    \ s:session.id, s:session.name, filter_tag,
    \ float2nr(remaining), s:session.items_correct, rate, s:session.aim)
endfunction

function! s:next_item() abort
  let s:session.advancing = 1
  let GenFn = function('toi#pinpoints#' . s:session.module . '#generate')
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
    call toi#stop('filter_error')
    return
  endif
  let s:session.current_item = item
  let s:session.item_started_at = reltime()
  let s:session.current_item_motions = 0

  setlocal modifiable
  silent! %delete _
  call setline(1, item.lines)
  call cursor(item.start[0], item.start[1])

  if s:session.target_match_id != -1
    silent! call matchdelete(s:session.target_match_id)
    let s:session.target_match_id = -1
  endif
  let s:session.target_match_id = matchaddpos('ToiTarget', [[item.target[0], item.target[1], 1]])

  redrawstatus
  let s:session.advancing = 0
endfunction

function! s:install_autocmds() abort
  augroup ToiProbe
    autocmd!
    autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI <buffer>
      \ call s:on_change()
  augroup END
  nnoremap <buffer> <silent> <Tab> :call <SID>skip()<CR>
endfunction

function! s:on_change() abort
  if empty(s:session) || s:session.advancing | return | endif
  if win_getid() != s:session.you_win | return | endif

  let s:session.current_item_motions += 1

  let item = s:session.current_item
  let cur_lines = getline(1, '$')
  let cur_pos = [line('.'), col('.')]

  if cur_lines ==# item.lines && cur_pos == item.target
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
    call toi#stop('time')
    return
  endif
  if win_getid() == s:session.you_win
    redrawstatus
  endif
endfunction

function! toi#stop(reason) abort
  if empty(s:session) | return | endif
  if get(s:session, 'mode', 'probe') ==# 'learn'
    call toi#learn_stop()
    return
  endif
  if has_key(s:session, 'timer')
    call timer_stop(s:session.timer)
  endif
  silent! augroup ToiProbe | autocmd! | augroup END

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
  call writefile([json_encode(record)], toi#log_dir() . '/sessions.jsonl', 'a')

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
  call add(lines, '  logged: ' . toi#log_dir() . '/sessions.jsonl')
  call add(lines, '')
  call add(lines, '  Press q or <Enter> to close.')

  " Render into the (still-open) probe buffer; user dismisses explicitly.
  let prev_laststatus = s:session.prev_laststatus
  let tabnr = s:session.tabnr
  let target_id = s:session.target_match_id
  let you_win = get(s:session, 'you_win', 0)
  let s:session = {}

  if you_win > 0 && win_id2win(you_win) > 0
    call win_gotoid(you_win)
    if target_id != -1
      silent! call matchdelete(target_id)
    endif
    setlocal modifiable
    silent! %delete _
    call setline(1, lines)
    setlocal nomodifiable nomodified
    let &l:statusline = ' session ended  [press q or <Enter> to close]'
    let b:toi_summary_tabnr = tabnr
    let b:toi_summary_prev_laststatus = prev_laststatus
    nnoremap <buffer> <silent> q :call toi#close_summary()<CR>
    nnoremap <buffer> <silent> <CR> :call toi#close_summary()<CR>
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

function! toi#close_summary() abort
  if exists('b:toi_summary_tabnr')
    let tabnr = b:toi_summary_tabnr
    let prev_ls = b:toi_summary_prev_laststatus
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

function! toi#history(...) abort
  let filter_id = a:0 >= 1 ? a:1 : ''
  let log_path = toi#log_dir() . '/sessions.jsonl'
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

  echo printf('toi history — %d session(s) across %d pinpoint(s)',
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

function! toi#learn(...) abort
  if !empty(s:session)
    echo 'a session is already active; :ToiQuit first'
    return
  endif
  if a:0 < 1
    echo 'usage: :ToiLearn <pinpoint_id>'
    return
  endif
  let id = a:1
  let registry = toi#discover_pinpoints()
  if !has_key(registry, id)
    echo 'unknown pinpoint: ' . id
    return
  endif
  let info = registry[id]
  let lesson_fn = 'toi#pinpoints#' . info.module . '#lesson'
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
    let s:session.target_match_id = matchaddpos('ToiLearnShow',
      \ [[buf_row, frame.cursor[1], 1]])
  else
    let buf_start_row = s:session.header_offset + frame.start[0]
    let buf_target_row = s:session.header_offset + frame.target[0]
    call cursor(buf_start_row, frame.start[1])
    let s:session.target_match_id = matchaddpos('ToiTarget',
      \ [[buf_target_row, frame.target[1], 1]])
  endif

  let s:session.advancing = 0
endfunction

function! s:learn_install_autocmds() abort
  augroup ToiLearn
    autocmd!
    autocmd CursorMoved,CursorMovedI <buffer> call s:learn_on_change()
  augroup END
  nnoremap <buffer> <silent> <Space> :call <SID>learn_advance_show()<CR>
  nnoremap <buffer> <silent> <CR> :call <SID>learn_advance_show()<CR>
  nnoremap <buffer> <silent> q :call toi#learn_stop()<CR>
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
    call toi#learn_stop()
    return
  endif
  call s:learn_show_frame()
endfunction

function! toi#learn_stop() abort
  if empty(s:session) | return | endif
  silent! augroup ToiLearn | autocmd! | augroup END
  let id = s:session.id
  if has_key(s:session, 'tabnr')
    silent! execute 'tabclose ' . s:session.tabnr
  endif
  let s:session = {}
  echo 'lesson ended for ' . id . ' — try :Toi ' . id
endfunction
