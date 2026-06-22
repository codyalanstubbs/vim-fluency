" Render-free smoke check for :VfDemo (driven by verify-demo.sh).
"
" For each drill — those named in $VF_DRILLS (space-separated), else every
" drill discovered — run the demo briefly in ONE vim process and record
" whether the `correct` counter climbed. This asserts the auto-play
" actually solves items for every kind, which is what the preview GIFs
" depend on; it does NOT render pixels (no OCR-on-GIF guesswork).
"
" Why one process: launching a separate vim per drill is unreliable (pty
" startup races), so we loop drills inside a single event loop, snapshot
" the live statusline, end the (no-log) demo session, and move on.
"
" Writes one "<id> PASS|FAIL <correct>" line per drill to $VF_OUT, then
" quits. verify-demo.sh reads it and sets the exit status.

let g:vf_results = []
if !empty($VF_DRILLS)
  let g:vf_drills = split($VF_DRILLS)
else
  let g:vf_drills = sort(keys(vimfluency#discover_drills()))
endif
let g:vf_idx = 0

" Per-drill window. Plain motions step a chunk of the path per ~320ms
" tick, so far targets (long f/t scans, big diagonals) need several
" seconds to clear an item; 8s clears every drill reliably (a tighter
" window flakes on the slowest motions when the random items run long).
" Override with $VF_WINDOW for a quicker, looser pass.
let g:vf_window = str2nr($VF_WINDOW) > 0 ? str2nr($VF_WINDOW) : 8000

function! VfNext(timer) abort
  if g:vf_idx >= len(g:vf_drills)
    call writefile(g:vf_results, $VF_OUT)
    qall!
  endif
  call vimfluency#demo(g:vf_drills[g:vf_idx], 60)
  call timer_start(g:vf_window, 'VfSnap')
endfunction

function! VfSnap(timer) abort
  let n = str2nr(matchstr(vimfluency#statusline(), 'correct \zs\d\+'))
  call add(g:vf_results,
    \ printf('%s %s %d', g:vf_drills[g:vf_idx], n > 0 ? 'PASS' : 'FAIL', n))
  " Drop out of any mode the demo left us in, end the (no-log) session.
  call feedkeys("\<C-\>\<C-n>", 'n')
  call vimfluency#stop('demo')
  let g:vf_idx += 1
  call timer_start(700, 'VfNext')
endfunction

call timer_start(500, 'VfNext')
