" delete_inside_pairs — the delimiter text objects: di" di( di{ di[.
" One drill covering the quote and bracket inner objects a frontend dev
" reaches for constantly — attribute values ("…"), JSX expressions and
" objects ({…}), call args (…), arrays […]. The cognitive task is the
" delimiter→object mapping: read which pair wraps the cursor, fire the
" matching di<pair>. That reflex is the whole skill; once di" is fluent,
" ci" is just a verb swap.
"
" Editing kind, like delete_inside_around_tag: the red deletion_range
" marks the content to remove, green target is suppressed, and each
" delete is a single event (optimal_motions = 1). No typing payload —
" the free-operant fluency loop wants no friction, so this drills the
" object selection with delete rather than change.
"
" Buffer shape: PREFIX <open>word1 word2<close> SUFFIX — exactly ONE
" delimiter pair per line, plain-word prefix/suffix (no stray
" delimiters), TWO-word content. Inside-delete is uniform across every
" delimiter (remove the content, land the cursor at content start), so
" quotes and brackets share one code path here; the a"-eats-a-space vs
" a(-doesn't asymmetry only matters for the AROUND objects, which this
" drill deliberately omits.
"
" Cheat analysis (di<pair> must be strictly shortest):
"   Multi-delimiter lines are unsafe — vim's quote-pairing heuristic and
"   forward brace search make the wrong-delimiter object do incoherent
"   things (verified). ONE pair per line keeps it airtight: the other
"   delimiter objects simply aren't present, so only same-object and
"   word/find alternatives can compete, and those are defeated exactly
"   as in delete_inside_around_tag:
"     - diw / daw (the dangerous tie): SINGLE-word content would let diw
"       reproduce di<pair>. Content is always TWO words → diw grabs one
"       (verified: di" → "", ciw → "X two").
"     - dt<close> / df<close> from the interior delete only the suffix
"       (cursor is strictly interior, never the first/last content char).
"     - dd (2 keystrokes) deletes the whole line, but PREFIX+SUFFIX are
"       always present → wrong buffer.
"   Synonyms (dib=di(, diB=di{, di)=di(, di]=di[) are the SAME object,
"   not cheats — buffer-state match credits them regardless.

" open/close/obj: `obj` is the char typed in the text object (di<obj>).
let s:pairs = [
  \ {'open': '"', 'close': '"', 'obj': '"'},
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

function! vimfluency#drills#delete_inside_pairs#meta() abort
  " Four-cell delimiter discrimination, single-event delete. Same band as
  " the other editing-kind discrimination drills. Starting guess.
  return {'id': 'delete_inside_pairs', 'name': 'delete inside quotes/brackets (di" / di( / di{ / di[)',
    \ 'aim': 55, 'allowed_keys': 'di"({[', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_around_tag'], 'keys': 'di"/di(/di{/di[', 'family': 'delete',
    \ 'test_sequence': ['di"', 'di(', 'di{', 'di[']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_pairs#generate() abort
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

  " Cursor strictly interior to the content (never first or last char) —
  " the cheat defense against count / dt<close> style deletes.
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
    \ 'prompt': 'Delete the highlighted range using d + the matching delimiter text object.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_pairs#lesson() abort
  " Rule-first intro naming the four objects with parallel statements,
  " then one try frame per delimiter so the learner performs each delete
  " and watches the pair empty. Wrong-object recovery is the runner's
  " [u=undo if wrong] header (editing kind).
  return [
    \ {'kind': 'show', 'lines': ['set "one two" end'], 'cursor': [1, 8],
    \  'prompt': [
    \    'Four delimiter text objects — di deletes what''s INSIDE the pair,',
    \    'wherever the cursor sits between them:',
    \    '',
    \    '    di"   →   inside the quotes',
    \    '    di(   →   inside the parentheses   ( di) and dib do the same )',
    \    '    di{   →   inside the braces        ( di} and diB do the same )',
    \    '    di[   →   inside the brackets      ( di] does the same )',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['set "one two" end'], 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'di"', 'optimal_motions': 1,
    \  'target_lines': ['set "" end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di" — empties the quotes.'},
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
