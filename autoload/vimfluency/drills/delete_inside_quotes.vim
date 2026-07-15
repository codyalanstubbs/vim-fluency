" delete_inside_quotes — the quote inner objects: di" di' di`.
" Attribute values ("…" / '…') and template literals (`…`) — the quoted
" strings frontend code is full of. The cognitive task is the
" delimiter→object mapping: read which quote wraps the cursor, fire the
" matching di<quote>.
"
" Split from the old delete_inside_pairs so quotes drill apart from the
" brackets: vim resolves quote objects by COUNTING quotes along the line
" (positional), not via matchpairs, so they're a distinct reflex. One
" quote pair per line keeps that heuristic unambiguous.
"
" Editing kind, like delete_inside_around_tag: red deletion_range marks
" the content, green suppressed, single-event delete (optimal 1), no
" typing payload (the free-operant fluency loop wants no friction).
"
" Cheat analysis (di<quote> must be strictly shortest) — one quote pair
" per line; the other quote objects aren't present, so only same-object
" and word/find alternatives compete, defeated as in the tag drill:
"   - diw/daw (the dangerous tie): SINGLE-word content would let diw
"     reproduce di<quote>. Content is always TWO words → diw grabs one
"     (verified: di" → "", ciw → "X two").
"   - dt<quote> from the interior deletes only the suffix (cursor is
"     strictly interior, never the first/last content char).
"   - dd (2 keystrokes) deletes the whole line, but PREFIX+SUFFIX are
"     always present → wrong buffer.
" Content and affix words are plain letters, so the only quote chars on
" the line are the pair itself — no stray quote confuses the count.

" open/close/obj: `obj` is the char typed in the text object (di<obj>).
let s:pairs = [
  \ {'open': '"', 'close': '"', 'obj': '"'},
  \ {'open': "'", 'close': "'", 'obj': "'"},
  \ {'open': '`', 'close': '`', 'obj': '`'},
  \ ]
" content words: the pair wraps TWO of these (the iw/aw cheat defense).
let s:contents = ['title', 'price', 'header', 'submit', 'active',
  \ 'status', 'login', 'search', 'footer', 'button', 'toggle', 'hidden',
  \ 'open', 'menu', 'save', 'edit', 'list', 'item', 'dark', 'blue']
" plain-word prefix/suffix: non-empty, no quote chars, no spaces.
let s:words = ['set', 'add', 'run', 'call', 'wrap', 'sort',
  \ 'find', 'load', 'keep', 'push', 'emit', 'bind']

function! vimfluency#drills#delete_inside_quotes#meta() abort
  return {'id': 'delete_inside_quotes', 'name': 'delete inside quotes (di" / di'' / di`)',
    \ 'aim': 55, 'allowed_keys': "di\"'`", 'kind': 'editing',
    \ 'prereqs': ['delete_inside_around_tag'], 'keys': "di\"/di'/di`", 'family': 'delete',
    \ 'test_sequence': ['di"', "di'", 'di`']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_quotes#generate() abort
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
  let content_start = len(prefix) + 3   " prefix + space + open quote
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
    \ 'prompt': 'Delete the highlighted range using d + the matching quote text object.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_quotes#lesson() abort
  return [
    \ {'kind': 'show', 'lines': ['set "one two" end'], 'cursor': [1, 8],
    \  'prompt': [
    \    'Three quote text objects — di deletes what''s INSIDE the pair,',
    \    'wherever the cursor sits between them:',
    \    '',
    \    '    di"   →   inside the double quotes',
    \    "    di'   →   inside the single quotes",
    \    '    di`   →   inside the backticks',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['set "one two" end'], 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'di"', 'optimal_motions': 1,
    \  'target_lines': ['set "" end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di" — empties the double quotes.'},
    \ {'kind': 'try', 'lines': ["add 'one two' end"], 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': "di'", 'optimal_motions': 1,
    \  'target_lines': ["add '' end"],
    \  'deletion_range': [[1, 6, 7]],
    \  'prompt': "Press di' — empties the single quotes."},
    \ {'kind': 'try', 'lines': ['run `one two` end'], 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'di`', 'optimal_motions': 1,
    \  'target_lines': ['run `` end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di` — empties the backticks.'},
    \ ]
endfunction
