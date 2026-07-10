" search_repeat_next_prev — the real search-and-repeat workflow: run the
" search yourself, then cycle the hits with n / N without retyping.
"
" The buffer holds foo three times with filler between. The cursor starts
" on filler BEFORE the middle foo, so /foo<CR> lands on that middle match.
" From there the green cell marks a neighbour: the foo ahead → n (repeat
" forward), the foo behind → N (repeat backward). The learner types the
" search, watches where it lands, then repeats toward green.
"
" The runner CLEARS @/ at item start, so the learner must actually search
" (a stale pattern won't let n fire) — that's the /foo step, drilled here.
"
" Cheat defense (the hard one): once the learner has searched, @/ is
" non-empty, so it can't tell n from a counted motion (2w) landing on the
" same match — @/, searchcount() and v:searchforward are identical either
" way (verified). So the runner INTERCEPTS n / N (search_repeat_maps): the
" maps set a one-shot flag (requires_repeat), s:search_ok credits only when
" it's set, and any cursor event clears it. A counted motion never sets the
" flag → never credits, even landing exactly on the target, and /foo alone
" (cursor on the middle foo, flag still down) never credits either.
"
" kind 'motion': cursor-credited plus the flag gate; green is the cue.
" optimal is 2 events — the /foo jump, then the n/N repeat.

let s:FILLERS = ['set', 'get', 'add', 'run', 'let', 'new',
  \ 'call', 'load', 'save', 'the', 'and', 'then', 'here', 'when']

function! vimfluency#drills#search_repeat_next_prev#meta() abort
  return {'id': 'search_repeat_next_prev', 'name': 'search then repeat (n / N)',
    \ 'aim': 45, 'allowed_keys': 'nN', 'kind': 'motion', 'search_repeat_maps': 1,
    \ 'prereqs': ['search_pattern_forward_backward'], 'keys': 'n/N',
    \ 'commands_display': '/foo n   /foo N', 'family': 'search',
    \ 'test_sequence': ['n', 'N']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Four distinct fillers so the line reads naturally.
function! s:pick_fillers(count) abort
  let out = []
  while len(out) < a:count
    let f = s:FILLERS[s:rand(len(s:FILLERS))]
    if index(out, f) < 0
      call add(out, f)
    endif
  endwhile
  return out
endfunction

function! vimfluency#drills#search_repeat_next_prev#generate() abort
  let f = s:pick_fillers(4)
  " foo, filler, CURSOR-filler, filler, foo, filler, foo
  " /foo from the cursor lands on the middle foo (token 4); n -> the last
  " foo (token 6), N -> the first foo (token 0).
  let tokens = ['foo', f[0], f[1], f[2], 'foo', f[3], 'foo']
  let line = join(tokens, ' ')

  let foo_cols = []
  let cursor_col = 1
  let c = 1
  for i in range(len(tokens))
    if tokens[i] ==# 'foo'
      call add(foo_cols, c)
    endif
    if i == 2
      let cursor_col = c
    endif
    let c += len(tokens[i]) + 1
  endfor

  let forward = s:rand(2) == 0
  return {
    \ 'lines': [line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, forward ? foo_cols[2] : foo_cols[0]],
    \ 'requires_repeat': 1,
    \ 'prompt': 'Search /foo, then repeat to the green match: n forward, N backward.',
    \ 'expected_motion': forward ? 'n' : 'N',
    \ 'optimal_motions': 2,
    \ }
endfunction

function! vimfluency#drills#search_repeat_next_prev#lesson() abort
  " foo at cols 5, 18, 27; cursor on 'here' (col 10, before the middle foo),
  " so /foo lands on the middle foo (col 18).
  let buf = ['run foo here and foo then foo']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 10],
    \  'prompt': [
    \    'Search once, then cycle the matches without retyping the pattern:',
    \    '',
    \    '    /foo<CR>   →   jumps to the next foo (your search)',
    \    '    n          →   the NEXT match (repeat, same direction)',
    \    '    N          →   the PREVIOUS match (repeat, opposite way)',
    \    '',
    \    'Type /foo and press <CR> — the cursor lands on a foo. Then the',
    \    'green cell shows which neighbour to repeat to: ahead → n,',
    \    'behind → N.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 27],
    \  'expected_motion': 'n', 'requires_repeat': 1, 'optimal_motions': 2,
    \  'prompt': 'Type /foo<CR> to land on the middle foo, then n — green is ahead.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 10], 'target': [1, 5],
    \  'expected_motion': 'N', 'requires_repeat': 1, 'optimal_motions': 2,
    \  'prompt': 'Type /foo<CR> to land on the middle foo, then N — green is behind.'},
    \ {'kind': 'try', 'lines': ['let foo set foo get foo'], 'start': [1, 9], 'target': [1, 21],
    \  'expected_motion': 'n', 'requires_repeat': 1, 'optimal_motions': 2,
    \  'prompt': '/foo<CR>, then n — ahead.'},
    \ {'kind': 'try', 'lines': ['let foo set foo get foo'], 'start': [1, 9], 'target': [1, 5],
    \  'expected_motion': 'N', 'requires_repeat': 1, 'optimal_motions': 2,
    \  'prompt': '/foo<CR>, then N — behind.'},
    \ ]
endfunction

" Demo auto-play: search /foo to land on the first match, then repeat to the
" target with n / N. Fed through the main loop so the search sets @/ AND n/N
" fire the search_repeat_maps intercept that sets the credit flag (:normal!
" would bypass the buffer map, so the flag never sets and it never credits).
function! vimfluency#drills#search_repeat_next_prev#solve(item) abort
  return "/foo\r" . a:item.expected_motion
endfunction
