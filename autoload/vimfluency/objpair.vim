" objpair — shared generator + lesson for the inner/around object PAIR
" drills: di<x> / da<x> for ONE delimiter (parens, braces, square
" brackets, and the three quotes). Split out from the old
" delete_inside_around_brackets / _quotes trios so each delimiter drills
" as a focused two-motion discrimination (like delete_inside_around_tag),
" not a six-way one.
"
" Brackets and quotes share IDENTICAL geometry — a single-char open/close
" wrapping two-word content, flanked by plain words — so one generator
" serves both. They differ only in what `a` eats:
"   eat_space = 0 (brackets): the surrounding gap stays, so da leaves a
"     DOUBLE space   add (one two) end --da(--> add  end
"   eat_space = 1 (quotes): a-quote swallows one trailing space (like aw),
"     so da leaves a SINGLE gap   set "one two" end --da"--> set end
" That difference is the whole lesson, and it's validated against real vim
" by the shared property harness (s:assert_inner_object_drill).
"
" Editing kind: red deletion_range is the cue, single-event delete
" (optimal 1). The cursor sits strictly INTERIOR to the content for every
" item, so only the red's extent (content alone vs content wrapped in its
" delimiters — one cell past the close for the space-eating quotes) tells
" di from da.
"
" Cheat analysis (each motion strictly shortest to its own target):
"   - Two-word content defeats the diw/daw tie (they grab one word).
"   - Interior cursor defeats dt<close>/df<close> (forward, partial),
"     dT<open>/dF<open> (backward, partial), and d% (lands on a bracket,
"     deletes a partial span) — no one-directional <=3-key delete spans
"     the object from inside.
"   - PREFIX + SUFFIX always present, so dd (whole line) is wrong.
"   - The SIBLING is the discrimination: di leaves the delimiters, da
"     removes them (and, for quotes, a space) — the targets differ.
"   Closing-delimiter synonyms (di)=di(, da}=da{, …) are the SAME object,
"   not cheats — a buffer-state match credits them.

" content words: the pair wraps TWO of these (the iw/aw cheat defense).
let s:contents = ['title', 'price', 'header', 'submit', 'active',
  \ 'status', 'login', 'search', 'footer', 'button', 'toggle', 'hidden',
  \ 'open', 'menu', 'save', 'edit', 'list', 'item', 'dark', 'blue']
" plain-word prefix/suffix: non-empty, no delimiters, no spaces.
let s:words = ['set', 'add', 'run', 'call', 'wrap', 'sort',
  \ 'find', 'load', 'keep', 'push', 'emit', 'bind']

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

" One di<obj>/da<obj> item for the given delimiter. eat_space: 1 if the
" around object swallows a trailing space (quotes), 0 if not (brackets).
function! vimfluency#objpair#gen(open, close, obj, eat_space) abort
  let prefix = s:pick(s:words)
  let suffix = s:pick(s:words)
  " Two distinct content words — the iw/aw cheat defense.
  let w1 = s:pick(s:contents)
  let w2 = s:pick(s:contents)
  while w2 ==# w1
    let w2 = s:pick(s:contents)
  endwhile
  let content = w1 . ' ' . w2

  let line = prefix . ' ' . a:open . content . a:close . ' ' . suffix

  " 1-indexed columns.
  let block_start = len(prefix) + 2      " the open delimiter
  let content_start = block_start + 1
  let content_end = content_start + len(content) - 1

  " Cursor strictly interior to the content (never first or last char).
  let cursor_col = content_start + 1 + s:rand(content_end - content_start - 1)

  if s:rand(2) == 0
    let motion = 'di' . a:obj
    let del_start = content_start
    let del_len = len(content)
  else
    let motion = 'da' . a:obj
    let del_start = block_start
    " content + two delimiters (+ the one trailing space quotes swallow).
    let del_len = len(content) + 2 + a:eat_space
  endif
  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, del_start],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted range using d + a text object (di or da).',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

" Lesson: rule-first show frame, then di/da paired on the SAME buffer
" (twice) so the learner watches the delimiters survive (di) then vanish
" (da) from one starting cursor. All columns fixed by the 3-char affixes
" and 'one two' content, so both bracket and quote families reuse them.
function! vimfluency#objpair#lesson(open, close, obj, eat_space) abort
  let di = 'di' . a:obj
  let da = 'da' . a:obj
  " "set (one two) end" — open at col 5, content 6-12, close 13, suffix 15.
  let buf1 = ['set ' . a:open . 'one two' . a:close . ' end']
  let buf2 = ['run ' . a:open . 'one two' . a:close . ' now']
  let di1 = ['set ' . a:open . a:close . ' end']
  let di2 = ['run ' . a:open . a:close . ' now']
  let da1 = [a:eat_space ? 'set end' : 'set  end']
  let da2 = [a:eat_space ? 'run now' : 'run  now']
  let da_len = 7 + 2 + a:eat_space
  let whitespace_note = a:eat_space
    \ ? 'i = inner, a = around. ' . da . ' eats the trailing space — like daw.'
    \ : 'i = inner, a = around. ' . da . ' does NOT eat whitespace — it leaves a double gap.'
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 8],
    \  'prompt': [
    \    'Inner vs around — the cursor is anywhere inside the ' . a:open . a:close . ' pair:',
    \    '',
    \    '    ' . di . '   →   empties the pair, keeps ' . a:open . ' ' . a:close,
    \    '    ' . da . '   →   takes ' . a:open . ' ' . a:close
    \      . (a:eat_space ? ' AND one space' : ' too'),
    \    '',
    \    whitespace_note,
    \    '',
    \    'Read the red highlight: delimiters inside it → ' . da . '; content only → ' . di . '.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': di, 'optimal_motions': 1,
    \  'target_lines': di1, 'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press ' . di . ' — empties the pair, ' . a:open . ' ' . a:close . ' stay.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 8], 'target': [1, 5],
    \  'expected_motion': da, 'optimal_motions': 1,
    \  'target_lines': da1, 'deletion_range': [[1, 5, da_len]],
    \  'prompt': 'Press ' . da . ' — takes ' . a:open . a:close
    \    . (a:eat_space ? ' and a space (single gap).' : ' too (double gap).')},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 8], 'target': [1, 6],
    \  'expected_motion': di, 'optimal_motions': 1,
    \  'target_lines': di2, 'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press ' . di . '.'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 8], 'target': [1, 5],
    \  'expected_motion': da, 'optimal_motions': 1,
    \  'target_lines': da2, 'deletion_range': [[1, 5, da_len]],
    \  'prompt': 'Press ' . da . '.'},
    \ ]
endfunction
