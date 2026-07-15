" delete_inside_brackets — the bracket inner objects: di( di{ di[.
" The matchpairs-based delimiters a frontend dev reaches for in JS/JSX:
" call args and grouping (…), expressions and objects {…}, arrays […].
" The cognitive task is the delimiter→object mapping: read which bracket
" wraps the cursor, fire the matching di<bracket>.
"
" Split from the old delete_inside_pairs so the matchpairs brackets and
" the positional quotes drill separately — they behave differently in
" vim (matchpairs vs on-line quote counting) and reward as distinct
" reflexes. Angle brackets (di<) are deliberately excluded: di< inside a
" tag targets the tag's <…> and is confusable with dit, so it lives in
" its own delete_inside_angle_vs_tag discrimination drill, not here.
"
" Editing kind, like delete_inside_around_tag: red deletion_range marks
" the content, green suppressed, single-event delete (optimal 1), no
" typing payload (the free-operant fluency loop wants no friction).
"
" Cheat analysis (di<bracket> must be strictly shortest) — one bracket
" pair per line keeps it airtight; the other bracket objects simply
" aren't present, so only same-object and word/find alternatives compete
" and they're defeated exactly as in delete_inside_around_tag:
"   - diw/daw (the dangerous tie): SINGLE-word content would let diw
"     reproduce di<bracket>. Content is always TWO words → diw grabs one.
"   - dt<close> / df<close> from the interior delete only the suffix
"     (cursor is strictly interior, never the first/last content char).
"   - dd (2 keystrokes) deletes the whole line, but PREFIX+SUFFIX are
"     always present → wrong buffer.
"   Synonyms — the closing-bracket forms di)=di(, di}=di{, di]=di[ — are
"   the SAME object, not cheats; buffer-state match credits them. (The
"   dib/diB letter aliases get their own juxtaposition drill,
"   delete_inside_block.)

" open/close/obj: `obj` is the char typed in the text object (di<obj>).
let s:pairs = [
  \ {'open': '(', 'close': ')', 'obj': '('},
  \ {'open': '{', 'close': '}', 'obj': '{'},
  \ {'open': '[', 'close': ']', 'obj': '['},
  \ ]
" content words: the pair wraps TWO of these (the iw/aw cheat defense).
let s:contents = ['title', 'price', 'header', 'submit', 'active',
  \ 'status', 'login', 'search', 'footer', 'button', 'toggle', 'hidden',
  \ 'open', 'menu', 'save', 'edit', 'list', 'item', 'dark', 'blue']
" plain-word prefix/suffix: non-empty, no delimiters, no spaces.
let s:words = ['set', 'add', 'run', 'call', 'wrap', 'sort',
  \ 'find', 'load', 'keep', 'push', 'emit', 'bind']

function! vimfluency#drills#delete_inside_brackets#meta() abort
  return {'id': 'delete_inside_brackets', 'name': 'delete inside brackets (di( / di{ / di[)',
    \ 'aim': 55, 'allowed_keys': 'di({[', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_around_tag'], 'keys': 'di(/di{/di[', 'family': 'delete',
    \ 'test_sequence': ['di(', 'di{', 'di[']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_brackets#generate() abort
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
    \ 'prompt': 'Delete the highlighted range using d + the matching bracket text object.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_brackets#lesson() abort
  return [
    \ {'kind': 'show', 'lines': ['add (one two) end'], 'cursor': [1, 8],
    \  'prompt': [
    \    'Three bracket text objects — di deletes what''s INSIDE the pair,',
    \    'wherever the cursor sits between them:',
    \    '',
    \    '    di(   →   inside the parentheses   ( di) does the same )',
    \    '    di{   →   inside the braces        ( di} does the same )',
    \    '    di[   →   inside the brackets      ( di] does the same )',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['add (one two) end'], 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'di(', 'optimal_motions': 1,
    \  'target_lines': ['add () end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di( — empties the parentheses.'},
    \ {'kind': 'try', 'lines': ['run {one two} end'], 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'di{', 'optimal_motions': 1,
    \  'target_lines': ['run {} end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di{ — empties the braces.'},
    \ {'kind': 'try', 'lines': ['call [one two] end'], 'start': [1, 9], 'target': [1, 7],
    \  'expected_motion': 'di[', 'optimal_motions': 1,
    \  'target_lines': ['call [] end'],
    \  'deletion_range': [[1, 7, 7]],
    \  'prompt': 'Press di[ — empties the brackets.'},
    \ ]
endfunction
