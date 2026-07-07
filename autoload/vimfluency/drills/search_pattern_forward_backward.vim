" search_pattern_forward_backward — typed search: /pattern to jump
" forward, ?pattern to jump backward. Unlike */# (the word you're ON),
" this is for finding text you're NOT on — the everyday way to move
" through code by name.
"
" Each item: the target word sits BOTH ahead of and behind the cursor,
" which rests on a different (unique) word. The green cell marks the
" occurrence to land on — ahead → /word, behind → ?word. The learner
" reads the word and types it.
"
" Cheat defense: like */#, a counted word motion (2w) can land on the
" same cell but does not search. Here the pattern is learner-typed, so
" rather than an exact @/ match the item declares `requires_search`: the
" runner credits only when @/ is NON-EMPTY (a real /pattern ran) AND the
" cursor is on the green cell (s:search_ok, with @/ cleared at item
" start). 2w leaves @/ empty → no credit; * on the (unique) cursor word
" finds no other match → never reaches the target. /word is the shortest
" route that actually lands there.
"
" kind 'motion': cursor-credited plus the @/ gate; the green target is
" the cue.

let s:SYMBOLS = ['count', 'value', 'user', 'data', 'node',
  \ 'total', 'index', 'result', 'item', 'name', 'buffer', 'config']
let s:FILLERS = ['set', 'get', 'add', 'run', 'let', 'new',
  \ 'call', 'load', 'save', 'the', 'and', 'then', 'here', 'when']

function! vimfluency#drills#search_pattern_forward_backward#meta() abort
  return {'id': 'search_pattern_forward_backward', 'name': 'search for a pattern (/ vs ?)',
    \ 'aim': 40, 'allowed_keys': '/?', 'kind': 'motion',
    \ 'prereqs': ['search_word_forward_backward'], 'keys': '/pat / ?pat', 'family': 'search',
    \ 'test_sequence': ['/', '?']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Pick a value from list not already in `used`.
function! s:pick_new(list, used) abort
  while 1
    let v = a:list[s:rand(len(a:list))]
    if index(a:used, v) < 0 | return v | endif
  endwhile
endfunction

function! vimfluency#drills#search_pattern_forward_backward#generate() abort
  let w = s:SYMBOLS[s:rand(len(s:SYMBOLS))]
  " three distinct fillers — the cursor word must be unique so * on it
  " can't reach the target.
  let fa = s:pick_new(s:FILLERS, [])
  let cur = s:pick_new(s:FILLERS, [fa])
  let fb = s:pick_new(s:FILLERS, [fa, cur])

  " layout: word filler CURSOR filler word  (target both sides)
  let line = join([w, fa, cur, fb, w], ' ')
  let col_before = 1
  let cursor_col = 1 + len(w) + 1 + len(fa) + 1
  let col_after = cursor_col + len(cur) + 1 + len(fb) + 1

  let forward = s:rand(2) == 0
  return {
    \ 'lines': [line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, forward ? col_after : col_before],
    \ 'requires_search': 1,
    \ 'prompt': 'Type a search to land on the green word: /word forward, ?word backward.',
    \ 'expected_motion': forward ? '/' : '?',
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#search_pattern_forward_backward#lesson() abort
  " value at cols 1 and 21; cursor on 'index' at col 11.
  let buf = ['value set index run value']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 11],
    \  'prompt': [
    \    'Jump to text you''re not on by typing what to find:',
    \    '',
    \    '    /word<CR>   →   search FORWARD for word',
    \    '    ?word<CR>   →   search BACKWARD for word',
    \    '',
    \    'The green cell shows where to land — read the word and type it.',
    \    'n / N then repeat the search either way.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 11], 'target': [1, 21],
    \  'expected_motion': '/', 'requires_search': 1, 'optimal_motions': 1,
    \  'prompt': 'Green is ahead — type /value then <CR>.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 11], 'target': [1, 1],
    \  'expected_motion': '?', 'requires_search': 1, 'optimal_motions': 1,
    \  'prompt': 'Green is behind — type ?value then <CR>.'},
    \ {'kind': 'try', 'lines': ['count get here let count'], 'start': [1, 11], 'target': [1, 20],
    \  'expected_motion': '/', 'requires_search': 1, 'optimal_motions': 1,
    \  'prompt': 'Ahead → /count<CR>.'},
    \ {'kind': 'try', 'lines': ['count get here let count'], 'start': [1, 11], 'target': [1, 1],
    \  'expected_motion': '?', 'requires_search': 1, 'optimal_motions': 1,
    \  'prompt': 'Behind → ?count<CR>.'},
    \ ]
endfunction
