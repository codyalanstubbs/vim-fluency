" search_word_forward_backward — jump to the next (*) or previous (#)
" occurrence of the word under the cursor. The backend code-navigation
" signature: land on a repeated symbol without reaching for a pattern.
"
" The word appears several times with filler between; the cursor sits on
" a middle occurrence, and the green cell marks the neighbour to land on
" — ahead → *, behind → #.
"
" Cheat defense (the interesting one): * and # are motions, so a counted
" word motion (e.g. 2w) can land on the SAME cell in the same one event —
" a cursor-position credit alone would tie. What distinguishes a real
" search is the search register: * / # set @/ to \<word\>, but 2w leaves
" it untouched. So this drill declares `expected_search` and the runner
" credits only when @/ matches (s:search_ok) — with @/ cleared at item
" start (s:seed_register) so a stale pattern can't satisfy it. 2w reaches
" the cell but never credits; a typed /\<word\> would credit but costs
" far more keystrokes, so * / # stay strictly shortest.
"
" kind 'motion': cursor-credited (plus the @/ gate); the green target is
" the cue, same as the other motion drills.

" Repeated 'symbol' words (the thing you'd * on in code).
let s:SYMBOLS = ['count', 'value', 'user', 'data', 'node',
  \ 'total', 'index', 'result', 'item', 'name', 'buffer', 'config']
" Filler words between occurrences — disjoint from SYMBOLS.
let s:FILLERS = ['set', 'get', 'add', 'run', 'let', 'new',
  \ 'call', 'load', 'save', 'the', 'and', 'then']

function! vimfluency#drills#search_word_forward_backward#meta() abort
  return {'id': 'search_word_forward_backward', 'name': 'search word under cursor (* / #)',
    \ 'aim': 45, 'allowed_keys': '*#', 'kind': 'motion',
    \ 'prereqs': [], 'keys': '*/#', 'family': 'search',
    \ 'test_sequence': ['*', '#']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#search_word_forward_backward#generate() abort
  let w = s:pick(s:SYMBOLS)
  let n = 3                      " three occurrences → one clean middle

  " tokens: filler, then (word, filler) per occurrence — one filler
  " between every pair of occurrences, so * / # skip a real gap.
  let tokens = [s:pick(s:FILLERS)]
  let occ_idx = []
  for i in range(n)
    call add(tokens, w)
    call add(occ_idx, len(tokens) - 1)
    call add(tokens, s:pick(s:FILLERS))
  endfor
  let line = join(tokens, ' ')

  " 1-indexed start column of each occurrence.
  let cols = []
  let c = 1
  for i in range(len(tokens))
    if index(occ_idx, i) >= 0
      call add(cols, c)
    endif
    let c += len(tokens[i]) + 1
  endfor

  let mid = n / 2               " 1 → the middle of three
  let forward = s:rand(2) == 0
  let target_col = forward ? cols[mid + 1] : cols[mid - 1]

  return {
    \ 'lines': [line],
    \ 'start': [1, cols[mid]],
    \ 'target': [1, target_col],
    \ 'expected_search': '\<' . w . '\>',
    \ 'prompt': 'Jump to the highlighted occurrence of the word under the cursor: * forward, # backward.',
    \ 'expected_motion': forward ? '*' : '#',
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#search_word_forward_backward#lesson() abort
  " value at cols 5, 15, 25; cursor on the middle one.
  let buf = ['set value get value use value']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 15],
    \  'prompt': [
    \    'Land on another occurrence of the word under the cursor — no',
    \    'pattern to type:',
    \    '',
    \    '    *   →   jump to the NEXT occurrence (forward)',
    \    '    #   →   jump to the PREVIOUS occurrence (backward)',
    \    '',
    \    'Both match the whole word and set the search, so n / N can',
    \    'then repeat it. The green cell shows where to land.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 15], 'target': [1, 25],
    \  'expected_motion': '*', 'expected_search': '\<value\>', 'optimal_motions': 1,
    \  'prompt': 'Green is ahead — press * to jump to the next value.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 15], 'target': [1, 5],
    \  'expected_motion': '#', 'expected_search': '\<value\>', 'optimal_motions': 1,
    \  'prompt': 'Green is behind — press # to jump to the previous value.'},
    \ {'kind': 'try', 'lines': ['run count and count plus count'], 'start': [1, 15], 'target': [1, 26],
    \  'expected_motion': '*', 'expected_search': '\<count\>', 'optimal_motions': 1,
    \  'prompt': 'Ahead → *.'},
    \ {'kind': 'try', 'lines': ['run count and count plus count'], 'start': [1, 15], 'target': [1, 5],
    \  'expected_motion': '#', 'expected_search': '\<count\>', 'optimal_motions': 1,
    \  'prompt': 'Behind → #.'},
    \ ]
endfunction

" Demo auto-play (:VfDemo / :VfLearnDemo): * / # search the word under the
" cursor and set @/, which the credit gate reads. The demo feeds this through
" the main loop (a search run in the demo's :normal! timer has its @/ discarded
" by vim's timer save/restore), so just hand back the key.
function! vimfluency#drills#search_word_forward_backward#solve(item) abort
  return a:item.expected_motion
endfunction
