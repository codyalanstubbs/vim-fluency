" Render-free smoke check for :VfLearnDemo (driven by verify-learn.sh).
"
" The learn twin of verify-demo.vim. For each drill with a lesson — those
" named in $VF_DRILLS (space-separated), else every drill that defines
" #lesson() — auto-play the whole lesson and record whether it GRADUATES
" (reaches the shared end screen) within a window. This asserts the lesson
" demo can perform every frame of the lesson (rule frames, each try frame's
" canonical motion, and the test phase to the streak) for every kind, which
" is what the :VfLearn preview GIFs depend on; it does NOT render pixels.
"
" Graduation signal: s:learn_show_complete renames the lesson window's
" buffer to 'vf-complete' (the end screen). A stalled lesson never creates
" it. We wipe vf-complete / vf-lesson-* between drills so a prior drill's
" end screen can't be mistaken for this one's (and so the next graduation's
" `keepalt file vf-complete` rename doesn't collide with a stale buffer).
"
" Why one process: launching a separate vim per drill is unreliable (pty
" startup races), so we loop drills inside a single event loop.
"
" Writes one '<id> PASS|FAIL <secs>' line per drill to $VF_OUT (secs = how
" long until graduation, or the window on FAIL), then quits. verify-learn.sh
" reads it and sets the exit status.

let g:vf_results = []
if !empty($VF_DRILLS)
  let g:vf_drills = split($VF_DRILLS)
else
  " Default: every drill that defines a lesson (exists() is reliable here
  " because discover_drills() sources each drill file, defining #lesson).
  let g:vf_drills = []
  for k in sort(keys(vimfluency#discover_drills()))
    if exists('*vimfluency#drills#' . k . '#lesson')
      call add(g:vf_drills, k)
    endif
  endfor
endif
let g:vf_idx = 0

" Lessons graduate in ~10-30s (setup frames + a 3x-sequence test streak at
" a ~350ms tick; the slowest are editing/change lessons that type a payload
" char-by-char). 45s is a safe cap with margin; we poll and move on the
" instant a lesson graduates, so a passing drill only uses as long as it
" needs — the cap only bounds a genuine stall. Override with $VF_WINDOW (ms)
" for a quicker, looser pass.
let g:vf_window = str2nr($VF_WINDOW) > 0 ? str2nr($VF_WINDOW) : 45000
let g:vf_poll = 500
let g:vf_max_polls = g:vf_window / g:vf_poll

" Wipe the end screen + any lesson buffers so each drill starts from a
" clean slate and graduation detection is unambiguous.
function! VfCleanup() abort
  silent! call vimfluency#learn_stop()
  for b in range(1, bufnr('$'))
    if !bufexists(b) | continue | endif
    let nm = bufname(b)
    if nm =~# 'vf-complete$' || nm =~# 'vf-lesson-'
      silent! execute 'bwipeout! ' . b
    endif
  endfor
  silent! call feedkeys("\<C-\>\<C-n>", 'n')
endfunction

function! VfStart(timer) abort
  if g:vf_idx >= len(g:vf_drills)
    call writefile(g:vf_results, $VF_OUT)
    qall!
  endif
  let g:vf_polls = 0
  call vimfluency#learn_demo(g:vf_drills[g:vf_idx])
  let g:vf_poll_timer = timer_start(g:vf_poll, 'VfPoll', {'repeat': -1})
endfunction

function! VfPoll(timer) abort
  let g:vf_polls += 1
  let done = bufexists('vf-complete')
  if done || g:vf_polls >= g:vf_max_polls
    silent! call timer_stop(g:vf_poll_timer)
    let secs = printf('%.1f', g:vf_polls * g:vf_poll / 1000.0)
    call add(g:vf_results,
      \ printf('%s %s %ss', g:vf_drills[g:vf_idx], done ? 'PASS' : 'FAIL', secs))
    call VfCleanup()
    let g:vf_idx += 1
    call timer_start(700, 'VfStart')
  endif
endfunction

call timer_start(500, 'VfStart')
