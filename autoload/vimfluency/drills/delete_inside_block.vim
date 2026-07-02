" delete_inside_block — the letter aliases for the two most-used bracket
" objects: dib deletes inside a () block, diB inside a {} Block. vim
" names these pairs so you don't reach for Shift-9 / Shift-[ mid-command:
"
"   dib   ≡   di(   →   inside parentheses   (b = block)
"   diB   ≡   di{   →   inside braces        (B = Block)
"
" This drill exists to ESTABLISH that equivalence and juxtapose the two
" aliases: lowercase b → round (), uppercase B → curly {}. The literal
" di( / di{ live in delete_inside_brackets; this one trains the
" home-row-friendly shortcut and the b-vs-B discrimination.
"
" Editing kind, one pair per line, two-word content — the same shape and
" cheat defense as delete_inside_brackets.
"
" Cheat analysis (the alias must be strictly shortest):
"   - diw/daw: two-word content → grabs one word → wrong buffer.
"   - dt<close> from the interior: suffix only (cursor strictly interior).
"   - dd: PREFIX+SUFFIX present → deletes too much → wrong.
"   - di( for a dib item (and di{ for diB) reproduce the target — but
"     that's the EQUIVALENCE being taught, not a cheat, so they're not
"     in the gate. diB on a () line finds no {} → wrong, and vice versa,
"     so the two aliases never credit each other (that's the point).

let s:pairs = [
  \ {'open': '(', 'close': ')', 'obj': 'b'},
  \ {'open': '{', 'close': '}', 'obj': 'B'},
  \ ]
" content words: the pair wraps TWO of these (the iw/aw cheat defense).
let s:contents = ['title', 'price', 'header', 'submit', 'active',
  \ 'status', 'login', 'search', 'footer', 'button', 'toggle', 'hidden',
  \ 'open', 'menu', 'save', 'edit', 'list', 'item', 'dark', 'blue']
" plain-word prefix/suffix: non-empty, no delimiters, no spaces.
let s:words = ['set', 'add', 'run', 'call', 'wrap', 'sort',
  \ 'find', 'load', 'keep', 'push', 'emit', 'bind']

function! vimfluency#drills#delete_inside_block#meta() abort
  return {'id': 'delete_inside_block', 'name': 'delete inside block — parens vs braces (dib / diB)',
    \ 'aim': 55, 'allowed_keys': 'dibB', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_brackets'], 'keys': 'dib/diB', 'family': 'delete',
    \ 'test_sequence': ['dib', 'diB']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_block#generate() abort
  let prefix = s:pick(s:words)
  let suffix = s:pick(s:words)
  let pair = s:pairs[s:rand(len(s:pairs))]
  " Two distinct content words — the iw/aw cheat defense.
  let w1 = s:pick(s:contents)
  let w2 = s:pick(s:contents)
  while w2 ==# w1
    let w2 = s:pick(s:contents)
  endwhile
  let content = w1 . ' ' . w2

  let line = prefix . ' ' . pair.open . content . pair.close . ' ' . suffix

  " 1-indexed columns.
  let content_start = len(prefix) + 3   " prefix + space + open delimiter
  let content_end = content_start + len(content) - 1

  " Cursor strictly interior to the content (never first or last char).
  let cursor_col = content_start + 1 + s:rand(content_end - content_start - 1)

  let motion = 'di' . pair.obj
  let target_line = strpart(line, 0, content_start - 1)
    \ . strpart(line, content_end)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, content_start],
    \ 'deletion_range': [[1, content_start, len(content)]],
    \ 'prompt': 'Delete the highlighted range with the block alias: dib for ( ), diB for { }.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_block#lesson() abort
  return [
    \ {'kind': 'show', 'lines': ['run (one two) end'], 'cursor': [1, 8],
    \  'prompt': [
    \    'vim names the two commonest bracket pairs with a letter:',
    \    '',
    \    '    dib   →   inside a ( ) block   —   same as di(',
    \    '    diB   →   inside a { } Block   —   same as di{',
    \    '',
    \    'b = block (round parens), B = Block (curly braces). Handier than',
    \    'reaching for the bracket keys mid-command.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['run (one two) end'], 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'dib', 'optimal_motions': 1,
    \  'target_lines': ['run () end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Round parens → press dib (lowercase b).'},
    \ {'kind': 'try', 'lines': ['run {one two} end'], 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'diB', 'optimal_motions': 1,
    \  'target_lines': ['run {} end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Curly braces → press diB (uppercase B).'},
    \ {'kind': 'try', 'lines': ['call (dark blue) now'], 'start': [1, 9], 'target': [1, 7],
    \  'expected_motion': 'dib', 'optimal_motions': 1,
    \  'target_lines': ['call () now'],
    \  'deletion_range': [[1, 7, 9]],
    \  'prompt': 'Parens → dib.'},
    \ {'kind': 'try', 'lines': ['call {dark blue} now'], 'start': [1, 9], 'target': [1, 7],
    \  'expected_motion': 'diB', 'optimal_motions': 1,
    \  'target_lines': ['call {} now'],
    \  'deletion_range': [[1, 7, 9]],
    \  'prompt': 'Braces → diB.'},
    \ ]
endfunction
