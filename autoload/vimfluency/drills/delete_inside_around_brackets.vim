" delete_inside_around_brackets — discriminate the inner vs around bracket
" objects: di( / di{ / di[  vs  da( / da{ / da[. The inner form empties the
" pair (delimiters stay); the around form takes the delimiters too.
"
" The whitespace contrast is the point (paired with delete_inside_around_word).
" Unlike aw, the a-bracket object does NOT eat surrounding whitespace: the
" spaces flanking the pair stay put, so da( leaves a DOUBLE gap —
"   add (one two) end  --da(-->  add  end
" whereas daw would have collapsed to a single space. Same for {} and [].
"
" Editing kind, like delete_inside_brackets / delete_inside_around_tag:
" red deletion_range is the cue, single-event delete (optimal 1). The
" cursor sits strictly INTERIOR to the content for every item, so the
" learner can't shortcut by cursor position — only the red's extent
" (content alone, or content wrapped in its delimiters) tells di from da.
"
" Cheat analysis (each motion strictly shortest to its own target):
"   - Two-word content defeats the diw/daw tie (diw/daw grab one word).
"   - Interior cursor defeats dt<close>/df<close> (forward, partial) and
"     dT<open>/dF<open> (backward, partial): no one-directional <=3-key
"     delete spans (content) — let alone the whole (content) block — from
"     inside. d% from the interior lands on a bracket and deletes a
"     partial span, never the target.
"   - PREFIX + SUFFIX always present, so dd (whole line) is wrong.
"   - The SIBLING is the discrimination: di<b> leaves the delimiters (and
"     a hollow pair), da<b> removes them (and leaves a double gap) — the
"     two targets differ, verified in the cheat gate.
"   Closing-bracket synonyms (di)=di(, da}=da{, …) are the SAME object, not
"   cheats — a buffer-state match credits them.

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

function! vimfluency#drills#delete_inside_around_brackets#meta() abort
  return {'id': 'delete_inside_around_brackets',
    \ 'name': 'delete inside vs around brackets (di( / da( …)',
    \ 'aim': 48, 'allowed_keys': 'dia({[', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_around_paren', 'delete_inside_around_brace',
    \   'delete_inside_around_square_bracket'],
    \ 'keys': 'di(/da( …', 'family': 'delete',
    \ 'parallel_to': ['delete_inside_around_quotes'],
    \ 'test_sequence': ['di(', 'da(', 'di{', 'da{', 'di[', 'da[']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_around_brackets#generate() abort
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
  let block_start = len(prefix) + 2      " the open delimiter
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
    let del_len = len(content) + 2   " + the two delimiters (no whitespace)
  endif
  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, del_start],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted range using d + a bracket text object (di or da).',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_around_brackets#lesson() abort
  " Rule-first, then di/da paired on the SAME buffer for each bracket so
  " the learner sees the delimiters survive (di) then vanish (da) from one
  " starting cursor — the direct juxtaposition.
  let bufP = ['add (one two) end']
  let bufB = ['run {one two} end']
  let bufK = ['call [one two] end']
  return [
    \ {'kind': 'show', 'lines': bufP, 'cursor': [1, 9],
    \  'prompt': [
    \    'Inner vs around, for every bracket pair — cursor anywhere inside:',
    \    '',
    \    '    di(   →   empties the pair, keeps ( )      add (one two) end → add () end',
    \    '    da(   →   takes the brackets too           add (one two) end → add  end',
    \    '',
    \    'i = inner, a = around. Note da( leaves a DOUBLE space — unlike daw,',
    \    'the bracket object does not eat the surrounding whitespace.',
    \    '',
    \    'Read the red: brackets inside it → da; content only → di.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': bufP, 'start': [1, 9], 'target': [1, 6],
    \  'expected_motion': 'di(', 'optimal_motions': 1,
    \  'target_lines': ['add () end'], 'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di( — empties the parentheses, ( ) stay.'},
    \ {'kind': 'try', 'lines': bufP, 'start': [1, 9], 'target': [1, 5],
    \  'expected_motion': 'da(', 'optimal_motions': 1,
    \  'target_lines': ['add  end'], 'deletion_range': [[1, 5, 9]],
    \  'prompt': 'Press da( — takes the ( ) too, leaving "add  end" (double gap).'},
    \ {'kind': 'try', 'lines': bufB, 'start': [1, 9], 'target': [1, 6],
    \  'expected_motion': 'di{', 'optimal_motions': 1,
    \  'target_lines': ['run {} end'], 'deletion_range': [[1, 6, 7]],
    \  'prompt': 'Press di{ — empties the braces.'},
    \ {'kind': 'try', 'lines': bufB, 'start': [1, 9], 'target': [1, 5],
    \  'expected_motion': 'da{', 'optimal_motions': 1,
    \  'target_lines': ['run  end'], 'deletion_range': [[1, 5, 9]],
    \  'prompt': 'Press da{ — takes the braces too.'},
    \ {'kind': 'try', 'lines': bufK, 'start': [1, 10], 'target': [1, 7],
    \  'expected_motion': 'di[', 'optimal_motions': 1,
    \  'target_lines': ['call [] end'], 'deletion_range': [[1, 7, 7]],
    \  'prompt': 'Press di[ — empties the brackets.'},
    \ {'kind': 'try', 'lines': bufK, 'start': [1, 10], 'target': [1, 6],
    \  'expected_motion': 'da[', 'optimal_motions': 1,
    \  'target_lines': ['call  end'], 'deletion_range': [[1, 6, 9]],
    \  'prompt': 'Press da[ — takes the brackets too.'},
    \ ]
endfunction
