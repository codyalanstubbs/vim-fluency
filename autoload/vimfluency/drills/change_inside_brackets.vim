" change_inside_brackets — the change form of the bracket inner objects:
" ci( ci{ ci[. The bread-and-butter frontend edit: land inside a call's
" args, a JSX expression, or an array and retype the contents in one
" motion. The change sibling of delete_inside_brackets — same delimiters
" and cheat defense, but c deletes AND drops into insert, so the learner
" types a fixed replacement and the runner credits on buffer match.
"
" kind 'mode' + credit_on_text_typed, exactly like change_inside_around_tag:
" the c-delete fires before InsertEnter (verified: at InsertEnter the
" content is gone and the cursor sits at content start), so target_lines
" is the content-removed state the first_text_change_pending guard
" absorbs. A clean run scores optimal = 1 (InsertEnter) + len(replacement).
"
" One bracket pair per line (multi-delimiter lines are unsafe — see
" delete_inside_brackets), two-word content, interior cursor. Cheat gate
" mirrors change_inside_around_tag: ciw/caw grab one word → wrong; cc/S
" change the whole line → wrong (prefix+suffix present); ct<close> from
" the interior changes only the suffix.

let s:pairs = [
  \ {'open': '(', 'close': ')', 'obj': '('},
  \ {'open': '{', 'close': '}', 'obj': '{'},
  \ {'open': '[', 'close': ']', 'obj': '['},
  \ ]
let s:contents = ['title', 'price', 'header', 'submit', 'active',
  \ 'status', 'login', 'search', 'footer', 'button', 'toggle', 'hidden',
  \ 'open', 'menu', 'save', 'edit', 'list', 'item', 'dark', 'blue']
let s:words = ['set', 'add', 'run', 'call', 'wrap', 'sort',
  \ 'find', 'load', 'keep', 'push', 'emit', 'bind']
" Fixed replacement typed after ci<bracket>; matches the insert/change
" family payload (insert_before_after_char, change_inside_around_tag).
let s:REPLACE = 'foo'

function! vimfluency#drills#change_inside_brackets#meta() abort
  return {'id': 'change_inside_brackets', 'name': 'change inside brackets (ci( / ci{ / ci[)',
    \ 'aim': 35, 'allowed_keys': 'ci({[foo', 'kind': 'mode',
    \ 'prereqs': ['delete_inside_brackets'], 'keys': 'ci(/ci{/ci[', 'family': 'change',
    \ 'parallel_to': ['change_inside_quotes', 'change_inside_around_tag'],
    \ 'credit_on_text_typed': 1,
    \ 'test_sequence': ['ci(', 'ci{', 'ci[']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#change_inside_brackets#generate() abort
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
  let content_start = len(prefix) + 3   " prefix + space + open delimiter
  let content_end = content_start + len(content) - 1

  " Cursor strictly interior to the content (never first or last char).
  let cursor_col = content_start + 1 + s:rand(content_end - content_start - 1)

  " c deletes the content and enters insert at content_start.
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
    \ 'prompt': printf('Change the highlighted range with c + the matching bracket text object, then type %s.', s:REPLACE),
    \ 'expected_motion': 'ci' . pair.obj,
    \ 'optimal_motions': 1 + len(s:REPLACE),
    \ }
endfunction

function! vimfluency#drills#change_inside_brackets#lesson() abort
  let t = s:REPLACE
  return [
    \ {'kind': 'show', 'lines': ['add (one two) end'], 'cursor': [1, 8],
    \  'prompt': [
    \    'Three bracket text objects with c — change, then type — cursor',
    \    'anywhere INSIDE the pair:',
    \    '',
    \    '    ci(   →   replace inside the parentheses',
    \    '    ci{   →   replace inside the braces',
    \    '    ci[   →   replace inside the brackets',
    \    '',
    \    'c deletes what''s inside and drops you into INSERT to retype it.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': ['add (one two) end'], 'start': [1, 8], 'target': [1, 6],
    \  'enter_at_row': 1, 'enter_at_col': 6,
    \  'target_lines': ['add () end'],
    \  'target_lines_after_type': ['add (' . t . ') end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'expected_motion': 'ci(', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press ci(, then type %s.', t)},
    \ {'kind': 'try', 'lines': ['run {one two} end'], 'start': [1, 8], 'target': [1, 6],
    \  'enter_at_row': 1, 'enter_at_col': 6,
    \  'target_lines': ['run {} end'],
    \  'target_lines_after_type': ['run {' . t . '} end'],
    \  'deletion_range': [[1, 6, 7]],
    \  'expected_motion': 'ci{', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press ci{, then type %s.', t)},
    \ {'kind': 'try', 'lines': ['call [one two] end'], 'start': [1, 9], 'target': [1, 7],
    \  'enter_at_row': 1, 'enter_at_col': 7,
    \  'target_lines': ['call [] end'],
    \  'target_lines_after_type': ['call [' . t . '] end'],
    \  'deletion_range': [[1, 7, 7]],
    \  'expected_motion': 'ci[', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press ci[, then type %s.', t)},
    \ ]
endfunction
