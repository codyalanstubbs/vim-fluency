" Tests for the celeration chart rendering. The chart only shows
" corrects (●), errors (×), and the aim line (-) — analytics like
" celeration trend lines and rate fits live in the JSONL log for
" downstream tools, not in this terminal view.

function! s:session(date, rate, ...) abort
  let erate = a:0 ? a:1 : 0
  return {'timestamp': a:date . 'T12:00:00',
    \ 'drill_id': 'TEST', 'drill_name': 'test',
    \ 'aim': 50, 'frequency_per_min': a:rate, 'errors_per_min': erate}
endfunction

" Rates kept below aim so the aim line isn't fragmented by data points
" landing in the same row as the dashes.
let s:sessions = [
  \ s:session('2026-01-01', 20.0, 5.0),
  \ s:session('2026-01-02', 30.0, 3.0),
  \ s:session('2026-01-03', 40.0, 2.0),
  \ ]
let s:rendered = vimfluency#_test_render_chart('TEST', s:sessions)
let s:rendered_text = join(s:rendered, "\n")

call Assert(s:rendered_text =~# 'progress chart — TEST',
  \ 'render_chart: header includes drill id')
call Assert(s:rendered_text =~# 'aim 50/min',
  \ 'render_chart: legend shows aim')
call Assert(s:rendered_text =~# '●',
  \ 'render_chart: plots corrects (●)')
call Assert(s:rendered_text =~# '×',
  \ 'render_chart: plots errors (×)')
call Assert(s:rendered_text =~# '-----',
  \ 'render_chart: draws aim line')

" Zero-rate sessions are quietly filtered (raw record stays in the log).
let s:with_zero = [
  \ s:session('2026-01-01', 30.0),
  \ s:session('2026-01-02', 0.0),
  \ s:session('2026-01-03', 60.0),
  \ ]
let s:zero_text = join(vimfluency#_test_render_chart('TEST', s:with_zero), "\n")
call Assert(s:zero_text !~# 'celeration:',
  \ 'render_chart: no analytics footer (saved for web app)')
call Assert(s:zero_text !~# 'excluded:',
  \ 'render_chart: no quit-session diagnostics in terminal view')

" Zoom variant: 10-100 single decade. Only the bounding labels should
" appear on the y-axis; 1000 and 1 belong to the full-range chart.
let s:zoom = vimfluency#_test_chart_bounds_zoom()
let s:zoom_text = join(vimfluency#_test_render_chart('TEST', s:sessions, s:zoom), "\n")
call Assert(s:zoom_text =~# ' 100',
  \ 'render_chart zoom: shows 100 label')
call Assert(s:zoom_text =~# '  10',
  \ 'render_chart zoom: shows 10 label')
call Assert(s:zoom_text !~# '1000',
  \ 'render_chart zoom: hides 1000 label (out of zoomed range)')

" Denser y-axis labels: full mode now shows semi-log gridlines, not
" just decade boundaries.
call Assert(s:rendered_text =~# '   50',
  \ 'render_chart: shows intra-decade y label (50)')
call Assert(s:rendered_text =~# '    5',
  \ 'render_chart: shows intra-decade y label (5)')

" X-axis labels: the first session date appears in MM-DD form, and
" there is a tick mark on the bottom axis.
call Assert(s:rendered_text =~# '01-01',
  \ 'render_chart: shows x-axis date label for first day')
call Assert(s:rendered_text =~# '┴',
  \ 'render_chart: bottom axis has tick marks')

" Longer date span: x-axis stride spaces out labels so multiple dates
" appear without colliding.
let s:long = []
let s:days = [1, 4, 7, 10, 13, 16, 19]
for s:d in s:days
  call add(s:long, s:session(printf('2026-01-%02d', s:d), 30.0, 1.0))
endfor
let s:long_text = join(vimfluency#_test_render_chart('TEST', s:long), "\n")
call Assert(s:long_text =~# '01-01',
  \ 'render_chart: long span labels first date')
call Assert(s:long_text =~# '01-19',
  \ 'render_chart: long span anchors last date')
