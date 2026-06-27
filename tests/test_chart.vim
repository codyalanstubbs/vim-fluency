" Tests for the celeration chart. :VfChart now reuses the dashboard's
" SCC renderer (s:dashboard_chart_panel), so the chart is a boxed panel:
" ● corrects at/above aim, ○ corrects below aim, × errors, · aim line,
" fixed log-Y, today-anchored x-axis. The renderer anchors the x-axis to
" the real "today", so test sessions are dated relative to today (via
" localtime offsets) to stay inside the visible window.

function! s:session(days_ago, rate, ...) abort
  let erate = a:0 ? a:1 : 0
  let date = strftime('%Y-%m-%d', localtime() - a:days_ago * 86400)
  return {'timestamp': date . 'T12:00:00',
    \ 'drill_id': 'TEST', 'drill_name': 'test',
    \ 'aim': 50, 'frequency_per_min': a:rate, 'errors_per_min': erate}
endfunction

" Rates straddle the aim (50): 70 is at/above (●), 30 and 45 below (○).
let s:sessions = [
  \ s:session(4, 30.0, 5.0),
  \ s:session(2, 70.0, 8.0),
  \ s:session(0, 45.0, 3.0),
  \ ]
let s:rendered = vimfluency#_test_render_chart('TEST', s:sessions)
let s:rendered_text = join(s:rendered, "\n")

call Assert(s:rendered_text =~# 'STANDARD CELERATION CHART: TEST',
  \ 'chart: boxed title names the drill')
call Assert(s:rendered_text =~# '●',
  \ 'chart: plots at-aim corrects (●)')
call Assert(s:rendered_text =~# '○',
  \ 'chart: plots below-aim corrects (○)')
call Assert(s:rendered_text =~# '×',
  \ 'chart: plots errors (×)')
call Assert(s:rendered_text =~# '·',
  \ 'chart: draws dotted aim line (·)')
call Assert(s:rendered_text =~# 'today →',
  \ 'chart: x-axis carries the today marker')
call Assert(s:rendered_text =~# '┴',
  \ 'chart: bottom axis has tick marks')
call Assert(s:rendered_text =~# '[0-9][0-9]-[0-9][0-9]',
  \ 'chart: shows an MM-DD x-axis date label')

" Fixed range tops at ~316 (log_top 2.5): decade labels 100, 10, 1; no
" 1000 (the old full-range top is gone — matches the dashboard).
call Assert(s:rendered_text =~# ' 100',
  \ 'chart: shows the 100 decade label')
call Assert(s:rendered_text =~# '   1├',
  \ 'chart: shows the 1 decade label at the floor')
call Assert(s:rendered_text !~# '1000',
  \ 'chart: no 1000 label (range tops at ~316)')

" Zero-rate sessions are filtered (raw record stays in the log); the
" terminal view carries no analytics footer.
let s:with_zero = [
  \ s:session(4, 30.0),
  \ s:session(2, 0.0),
  \ s:session(0, 60.0),
  \ ]
let s:zero_text = join(vimfluency#_test_render_chart('TEST', s:with_zero), "\n")
call Assert(s:zero_text !~# 'celeration:',
  \ 'chart: no analytics footer (saved for web app)')

" Zoom variant: single decade 10-100. Decade labels 100 and 10 appear;
" the 1 label (out of the zoomed range) does not.
let s:zoom = vimfluency#_test_chart_bounds_zoom()
let s:zoom_text = join(vimfluency#_test_render_chart('TEST', s:sessions, s:zoom), "\n")
call Assert(s:zoom_text =~# ' 100',
  \ 'chart zoom: shows 100 label')
call Assert(s:zoom_text =~# '  10├',
  \ 'chart zoom: shows 10 label at the floor')
call Assert(s:zoom_text !~# '   1├',
  \ 'chart zoom: hides the 1 label (out of zoomed range)')

" Longer span: multiple MM-DD labels render without colliding.
let s:long = []
for s:k in [12, 10, 7, 5, 2, 0]
  call add(s:long, s:session(s:k, 30.0, 1.0))
endfor
let s:long_text = join(vimfluency#_test_render_chart('TEST', s:long), "\n")
let s:date_labels = len(split(s:long_text, '[0-9][0-9]-[0-9][0-9]', 1)) - 1
call Assert(s:date_labels >= 2,
  \ 'chart: long span renders multiple date labels')
