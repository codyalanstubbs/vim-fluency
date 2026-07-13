" delete_inside_around_quotes — discriminate the inner vs around quote
" objects: di" / di' / di`  vs  da" / da' / da`. Inner empties the string
" (quotes stay); around takes the quotes too.
"
" The whitespace contrast is the point — and quotes fall on the OTHER side
" of it from brackets. Like aw (and unlike a-bracket / a-tag), the a-quote
" object EATS the trailing whitespace:
"   set "one two" end  --da\"-->  set end        (single gap — space eaten)
"   add (one two) end  --da(-->   add  end        (double gap — bracket kept it)
" So da" collapses the gap while da( leaves it. Same lesson, opposite rule.
"
" Editing kind, like delete_inside_quotes: red deletion_range is the cue,
" single-event delete (optimal 1). The cursor sits strictly INTERIOR to
" the content for every item, so only the red's extent tells di from da —
" and for da the red runs one cell PAST the close quote, over the space it
" swallows.
"
" Buffer shape: PREFIX "content" SUFFIX, content always TWO words. The
" suffix guarantees a trailing space exists, so da<quote> deterministically
" eats the TRAILING space (never the leading one).
"
" Cheat analysis (each motion strictly shortest to its own target):
"   - Two-word content defeats the diw/daw tie.
"   - Interior cursor defeats dt<quote>/df<quote> (partial from inside).
"   - PREFIX + SUFFIX present, so dd (whole line) is wrong.
"   - The SIBLING is the discrimination: di<q> leaves the quotes + a double
"     gap of its own, da<q> removes quotes AND a space — the targets differ.
"   Content/affix are plain letters, so the only quote chars on the line
"   are the pair itself — vim's positional quote count stays unambiguous.

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

function! vimfluency#drills#delete_inside_around_quotes#meta() abort
  return {'id': 'delete_inside_around_quotes',
    \ 'name': 'delete inside vs around quotes (di" / da" …)',
    \ 'aim': 48, 'allowed_keys': "dia\"'`", 'kind': 'editing',
    \ 'prereqs': ['delete_inside_quotes'], 'keys': "di\"/da\" …", 'family': 'delete',
    \ 'parallel_to': ['delete_inside_around_brackets'],
    \ 'test_sequence': ['di"', 'da"', "di'", "da'", 'di`', 'da`']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_around_quotes#generate() abort
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
  let block_start = len(prefix) + 2      " the open quote
  let content_start = block_start + 1
  let content_end = content_start + len(content) - 1

  " Cursor strictly interior to the content (never first or last char).
  let cursor_col = content_start + 1 + s:rand(content_end - content_start - 1)

  if s:rand(2) == 0
    let motion = 'di' . pair.obj
    let del_start = content_start
    let del_len = len(content)
  else
    let motion = 'da' . pair.obj
    let del_start = block_start
    " content + two quotes + the ONE trailing space a-quote swallows.
    let del_len = len(content) + 3
  endif
  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, del_start],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted range using d + a quote text object (di or da).',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_around_quotes#lesson() abort
  " Rule-first, then di/da paired on the SAME buffer per quote type so the
  " learner sees the quotes survive (di) then vanish WITH a space (da).
  let bufD = ['set "one two" end']
  let bufS = ["add 'one two' end"]
  let bufT = ['run `one two` end']
  return [
    \ {'kind': 'show', 'lines': bufD, 'cursor': [1, 8],
    \  'prompt': [
    \    'Inner vs around, for every quote pair — cursor anywhere inside:',
    \    '',
    \    '    di"   →   empties the string, keeps " "   set "one two" end → set "" end',
    \    '    da"   →   takes the quotes AND a space     set "one two" end → set end',
    \    '',
    \    'i = inner, a = around. da" eats the trailing space — like daw, and',
    \    'UNLIKE da( (which leaves a double gap). Quotes collapse; brackets don''t.',
    \    '',
    \    'Read the red: quotes inside it → da; content only → di.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': bufD, 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'di"', 'optimal_motions': 1,
    \  'target_lines': ['set "" end'], 'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di" — empties the double quotes, " " stay.'},
    \ {'kind': 'try', 'lines': bufD, 'start': [1, 8], 'target': [1, 5],
    \  'expected_motion': 'da"', 'optimal_motions': 1,
    \  'target_lines': ['set end'], 'deletion_range': [[1, 5, 10]],
    \  'prompt': 'Press da" — takes the quotes AND a space, leaving "set end".'},
    \ {'kind': 'try', 'lines': bufS, 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': "di'", 'optimal_motions': 1,
    \  'target_lines': ["add '' end"], 'deletion_range': [[1, 6, 7]],
    \  'prompt': "Press di' — empties the single quotes."},
    \ {'kind': 'try', 'lines': bufS, 'start': [1, 8], 'target': [1, 5],
    \  'expected_motion': "da'", 'optimal_motions': 1,
    \  'target_lines': ['add end'], 'deletion_range': [[1, 5, 10]],
    \  'prompt': "Press da' — takes the quotes AND a space."},
    \ {'kind': 'try', 'lines': bufT, 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': 'di`', 'optimal_motions': 1,
    \  'target_lines': ['run `` end'], 'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di` — empties the backticks.'},
    \ {'kind': 'try', 'lines': bufT, 'start': [1, 8], 'target': [1, 5],
    \  'expected_motion': 'da`', 'optimal_motions': 1,
    \  'target_lines': ['run end'], 'deletion_range': [[1, 5, 10]],
    \  'prompt': 'Press da` — takes the backticks AND a space.'},
    \ ]
endfunction
