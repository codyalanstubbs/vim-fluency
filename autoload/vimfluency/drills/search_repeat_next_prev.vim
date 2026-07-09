" search_repeat_next_prev — repeat the last search: n to the next match,
" N to the previous. The everyday follow-up to a search — you searched
" once, now cycle the hits without retyping the pattern.
"
" The runner PRE-SEEDS the search (as if you'd just run /word forward),
" so @/ already holds the pattern and n / N have something to repeat. A
" word appears several times with filler between; the cursor sits on a
" middle occurrence, and the green cell marks the neighbour — next → n,
" prev → N.
"
" Cheat defense (the hard one): because @/ is pre-seeded, it can't tell n
" from a counted motion (6w) that lands on the same match — @/ matches
" either way, and searchcount()/v:searchforward are identical (verified).
" So the runner INTERCEPTS n / N (search_repeat_maps): the maps set a
" one-shot flag, s:search_ok credits only when it's set, and any cursor
" event clears it. A counted motion never sets the flag → never credits,
" even landing exactly on the target.
"
" kind 'motion': cursor-credited plus the flag gate; green is the cue.

let s:SYMBOLS = ['count', 'value', 'user', 'data', 'node',
  \ 'total', 'index', 'result', 'item', 'name', 'buffer', 'config']
let s:FILLERS = ['set', 'get', 'add', 'run', 'let', 'new',
  \ 'call', 'load', 'save', 'the', 'and', 'then', 'here', 'when']

function! vimfluency#drills#search_repeat_next_prev#meta() abort
  return {'id': 'search_repeat_next_prev', 'name': 'repeat search next / prev (n / N)',
    \ 'aim': 55, 'allowed_keys': 'nN', 'kind': 'motion', 'search_repeat_maps': 1,
    \ 'prereqs': ['search_word_forward_backward'], 'keys': 'n/N', 'family': 'search',
    \ 'test_sequence': ['n', 'N']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#search_repeat_next_prev#generate() abort
  let w = s:pick(s:SYMBOLS)
  " filler, word, filler, word, filler, word, filler — three occurrences,
  " a filler between each pair so n / N skip a real gap.
  let tokens = [s:pick(s:FILLERS), w, s:pick(s:FILLERS), w,
    \ s:pick(s:FILLERS), w, s:pick(s:FILLERS)]
  let line = join(tokens, ' ')

  let cols = []
  let c = 1
  for i in range(len(tokens))
    if tokens[i] ==# w
      call add(cols, c)
    endif
    let c += len(tokens[i]) + 1
  endfor

  " cursor on the middle occurrence; n -> next (cols[2]), N -> prev (cols[0]).
  let forward = s:rand(2) == 0
  return {
    \ 'lines': [line],
    \ 'start': [1, cols[1]],
    \ 'target': [1, forward ? cols[2] : cols[0]],
    \ 'search_pattern': '\<' . w . '\>',
    \ 'prompt': 'Repeat the search to the green match: n forward, N backward.',
    \ 'expected_motion': forward ? 'n' : 'N',
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#search_repeat_next_prev#lesson() abort
  " value at cols 5, 15, 25; cursor on the middle value; search pre-seeded.
  let buf = ['set value get value use value']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 15],
    \  'prompt': [
    \    'You''ve already searched (say /value) — now cycle the matches',
    \    'without retyping:',
    \    '',
    \    '    n   →   the NEXT match (same direction)',
    \    '    N   →   the PREVIOUS match (opposite direction)',
    \    '',
    \    'The green cell shows which match to land on.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 15], 'target': [1, 25],
    \  'expected_motion': 'n', 'search_pattern': '\<value\>', 'optimal_motions': 1,
    \  'prompt': 'Green is ahead — press n for the next match.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 15], 'target': [1, 5],
    \  'expected_motion': 'N', 'search_pattern': '\<value\>', 'optimal_motions': 1,
    \  'prompt': 'Green is behind — press N for the previous match.'},
    \ {'kind': 'try', 'lines': ['run count and count plus count'], 'start': [1, 15], 'target': [1, 26],
    \  'expected_motion': 'n', 'search_pattern': '\<count\>', 'optimal_motions': 1,
    \  'prompt': 'Ahead → n.'},
    \ {'kind': 'try', 'lines': ['run count and count plus count'], 'start': [1, 15], 'target': [1, 5],
    \  'expected_motion': 'N', 'search_pattern': '\<count\>', 'optimal_motions': 1,
    \  'prompt': 'Behind → N.'},
    \ ]
endfunction
