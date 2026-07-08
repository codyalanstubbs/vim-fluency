" search_pattern_forward_backward — typed search: /foo to jump forward,
" ?foo to jump backward. Unlike */# (the word you're ON), this is for
" finding text you're NOT on — the everyday way to move through code by
" name.
"
" The pattern is always foo, and the target foo sits BOTH ahead of and
" behind the cursor (which rests on a unique non-foo word). Crucially,
" foo-like decoys (for, fob, fog, fox …) sit BETWEEN the cursor and each
" foo — so a short pattern lands on a decoy, not the target: /fo stops on
" 'for', only /foo skips the look-alikes to the real foo. The learner has
" to type the whole pattern. The green cell marks which foo to land on —
" ahead → /foo, behind → ?foo.
"
" Cheat defense: like */#, a counted word motion (2w) can land on the
" same cell but does not search. The pattern is typed, so the item
" declares `requires_search`: the runner credits only when @/ is NON-EMPTY
" (a real search ran) AND the cursor is on the green cell (s:search_ok,
" @/ cleared at item start). 2w leaves @/ empty → no credit; a partial
" pattern lands on a decoy → wrong cell → no credit; * on the unique
" cursor word finds no other match → never reaches a foo.
"
" kind 'motion': cursor-credited plus the @/ gate; green target is the cue.

" foo-like decoys: share foo's 'fo' prefix but differ at the 3rd letter,
" and none contains 'foo' as a substring (so /foo matches only foo).
let s:DECOYS = ['for', 'fob', 'fog', 'fox', 'foe', 'fop', 'fod', 'fon']
" cursor-word candidates: unique, not foo, not fo-prefixed.
let s:FILLERS = ['set', 'get', 'add', 'run', 'let', 'new',
  \ 'call', 'load', 'save', 'the', 'and', 'then', 'here', 'when']

function! vimfluency#drills#search_pattern_forward_backward#meta() abort
  return {'id': 'search_pattern_forward_backward', 'name': 'search for a pattern (/ vs ?)',
    \ 'aim': 40, 'allowed_keys': '/?foo', 'kind': 'motion',
    \ 'prereqs': ['search_word_forward_backward'], 'keys': '/foo / ?foo',
    \ 'commands_display': '/foo   ?foo', 'family': 'search',
    \ 'test_sequence': ['/', '?']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick_new(list, used) abort
  while 1
    let v = a:list[s:rand(len(a:list))]
    if index(a:used, v) < 0 | return v | endif
  endwhile
endfunction

function! vimfluency#drills#search_pattern_forward_backward#generate() abort
  " Four distinct decoys — two between the cursor and each foo.
  let d0 = s:pick_new(s:DECOYS, [])
  let d1 = s:pick_new(s:DECOYS, [d0])
  let d2 = s:pick_new(s:DECOYS, [d0, d1])
  let d3 = s:pick_new(s:DECOYS, [d0, d1, d2])
  let cur = s:FILLERS[s:rand(len(s:FILLERS))]

  " layout: foo d0 d1 CURSOR d2 d3 foo — foo both sides, decoys between.
  let tokens = ['foo', d0, d1, cur, d2, d3, 'foo']
  let line = join(tokens, ' ')
  let col_before = 1
  let cursor_col = 1 + 4 + len(d0) + 1 + len(d1) + 1   " 'foo '=4, then d0 ' ', d1 ' '
  let col_after = cursor_col + len(cur) + 1 + len(d2) + 1 + len(d3) + 1

  let forward = s:rand(2) == 0
  return {
    \ 'lines': [line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, forward ? col_after : col_before],
    \ 'requires_search': 1,
    \ 'prompt': 'Type the search to land on the green foo — the whole word (the fo* look-alikes catch a short pattern): /foo forward, ?foo backward.',
    \ 'expected_motion': forward ? '/' : '?',
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#search_pattern_forward_backward#lesson() abort
  " foo at cols 1 and 25; cursor on 'run' at col 13; decoys between.
  let buf = ['foo for fob run fog fox foo']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 13],
    \  'prompt': [
    \    'Jump to text you''re not on by typing what to find:',
    \    '',
    \    '    /foo<CR>   →   search FORWARD for foo',
    \    '    ?foo<CR>   →   search BACKWARD for foo',
    \    '',
    \    'The look-alikes (for, fob, fog, fox) sit in the way — /fo stops',
    \    'on ''for'', so type the whole word to reach the green foo.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 13], 'target': [1, 25],
    \  'expected_motion': '/', 'requires_search': 1, 'optimal_motions': 1,
    \  'prompt': 'Green is ahead — type /foo then <CR> (not /fo).'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 13], 'target': [1, 1],
    \  'expected_motion': '?', 'requires_search': 1, 'optimal_motions': 1,
    \  'prompt': 'Green is behind — type ?foo then <CR>.'},
    \ {'kind': 'try', 'lines': ['foo fop fod let foe fog foo'], 'start': [1, 13], 'target': [1, 25],
    \  'expected_motion': '/', 'requires_search': 1, 'optimal_motions': 1,
    \  'prompt': 'Ahead → /foo<CR>.'},
    \ {'kind': 'try', 'lines': ['foo fop fod let foe fog foo'], 'start': [1, 13], 'target': [1, 1],
    \  'expected_motion': '?', 'requires_search': 1, 'optimal_motions': 1,
    \  'prompt': 'Behind → ?foo<CR>.'},
    \ ]
endfunction
