" change_inside_quotes — the change form of the quote inner objects:
" ci" ci' ci`. The single most-used frontend text-object edit: swap an
" attribute value ("…" / '…') or a template literal (`…`). The change
" sibling of delete_inside_quotes.
"
" kind 'mode' + credit_on_text_typed, like change_inside_around_tag: the
" c-delete fires before InsertEnter, so target_lines is the removed
" state the first_text_change_pending guard absorbs; a clean run scores
" optimal = 1 (InsertEnter) + len(replacement).
"
" One quote pair per line (vim counts quotes positionally along the
" line), two-word content, interior cursor. Cheat gate mirrors the tag
" change drill: ciw/caw grab one word → wrong; cc/S change the whole
" line → wrong (prefix+suffix present); ct<quote> from the interior
" changes only the suffix. Content and affix words are plain letters, so
" the only quote chars on the line are the pair itself.

let s:pairs = [
  \ {'open': '"', 'close': '"', 'obj': '"'},
  \ {'open': "'", 'close': "'", 'obj': "'"},
  \ {'open': '`', 'close': '`', 'obj': '`'},
  \ ]
let s:contents = ['title', 'price', 'header', 'submit', 'active',
  \ 'status', 'login', 'search', 'footer', 'button', 'toggle', 'hidden',
  \ 'open', 'menu', 'save', 'edit', 'list', 'item', 'dark', 'blue']
let s:words = ['set', 'add', 'run', 'call', 'wrap', 'sort',
  \ 'find', 'load', 'keep', 'push', 'emit', 'bind']
let s:REPLACE = 'foo'

function! vimfluency#drills#change_inside_quotes#meta() abort
  return {'id': 'change_inside_quotes', 'name': 'change inside quotes (ci" / ci'' / ci`)',
    \ 'aim': 35, 'allowed_keys': "ci\"'`foo", 'kind': 'mode',
    \ 'prereqs': ['delete_inside_quotes'], 'keys': "ci\"/ci'/ci`", 'family': 'change',
    \ 'credit_on_text_typed': 1,
    \ 'test_sequence': ['ci"', "ci'", 'ci`']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#change_inside_quotes#generate() abort
  let prefix = s:pick(s:words)
  let suffix = s:pick(s:words)
  let pair = s:pairs[s:rand(len(s:pairs))]
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

  let removed = strpart(line, 0, content_start - 1) . strpart(line, content_end)
  let after_type = strpart(line, 0, content_start - 1) . s:REPLACE
    \ . strpart(line, content_end)

  return {
    \ 'lines': [line],
    \ 'start': [1, cursor_col],
    \ 'enter_at_row': 1,
    \ 'enter_at_col': content_start,
    \ 'target_lines': [removed],
    \ 'target_lines_after_type': [after_type],
    \ 'target': [1, content_start],
    \ 'deletion_range': [[1, content_start, len(content)]],
    \ 'prompt': printf('Change the highlighted range with c + the matching quote text object, then type %s.', s:REPLACE),
    \ 'expected_motion': 'ci' . pair.obj,
    \ 'optimal_motions': 1 + len(s:REPLACE),
    \ }
endfunction

function! vimfluency#drills#change_inside_quotes#lesson() abort
  let t = s:REPLACE
  return [
    \ {'kind': 'show', 'lines': ['set "one two" end'], 'cursor': [1, 8],
    \  'prompt': [
    \    'Three quote text objects with c — change, then type — cursor',
    \    'anywhere INSIDE the pair:',
    \    '',
    \    '    ci"   →   replace inside the double quotes',
    \    "    ci'   →   replace inside the single quotes",
    \    '    ci`   →   replace inside the backticks',
    \    '',
    \    'c deletes what''s inside and drops you into INSERT to retype it.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['set "one two" end'], 'start': [1, 8], 'target': [1, 6],
    \  'enter_at_row': 1, 'enter_at_col': 6,
    \  'target_lines': ['set "" end'],
    \  'target_lines_after_type': ['set "' . t . '" end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'expected_motion': 'ci"', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press ci", then type %s.', t)},
    \ {'kind': 'try', 'lines': ["add 'one two' end"], 'start': [1, 8], 'target': [1, 6],
    \  'enter_at_row': 1, 'enter_at_col': 6,
    \  'target_lines': ["add '' end"],
    \  'target_lines_after_type': ["add '" . t . "' end"],
    \  'deletion_range': [[1, 6, 7]],
    \  'expected_motion': "ci'", 'optimal_motions': 1 + len(t),
    \  'prompt': printf("Press ci', then type %s.", t)},
    \ {'kind': 'try', 'lines': ['run `one two` end'], 'start': [1, 8], 'target': [1, 6],
    \  'enter_at_row': 1, 'enter_at_col': 6,
    \  'target_lines': ['run `` end'],
    \  'target_lines_after_type': ['run `' . t . '` end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'expected_motion': 'ci`', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press ci`, then type %s.', t)},
    \ ]
endfunction
