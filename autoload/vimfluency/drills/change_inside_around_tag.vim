" change_inside_around_tag — discriminate cit vs cat, the change
" form of the tag text objects and the move a frontend dev reaches for
" most: gut a tag's contents and retype them (cit), or replace the
" whole element (cat). The change sibling of delete_inside_around_tag —
" identical text objects (it = inside tag, at = around tag), identical
" buffer shape and cheat defense, but the c operator deletes AND drops
" into insert mode, so the learner then types a fixed replacement and
" the runner credits the moment the buffer matches.
"
" kind 'mode' + credit_on_text_typed: the InsertEnter/TextChangedI
" credit path (shared with the insert family) fits here because cit/cat
" end in insert mode. family 'change' (kind drives mechanics, family
" drives display). The c-delete fires before InsertEnter (verified: at
" InsertEnter the content is already gone and the cursor sits at the
" deletion start), so target_lines is the content/block-removed state —
" which the runner's first_text_change_pending guard absorbs, keeping a
" clean run at optimal = 1 (InsertEnter) + len(replacement).
"
" Cue: the red deletion_range marks inner content (cit) vs whole block
" (cat); the green target is suppressed whenever a deletion_range is
" present (see s:render) so it can't leak the discrimination. Same
" cursor (interior of the content) maps to either motion.
"
" Cheat analysis — cit/cat must be the strictly shortest path to their
" target_lines_after_type. The deletion ranges are identical to
" delete_inside_around_tag's, so the same defenses apply:
"   - ciw / caw (3 keystrokes, the dangerous tie): with SINGLE-word
"     content ciw would change exactly that word → identical result to
"     cit. Content is therefore always TWO words; ciw/caw then touch
"     only one word (verified: cit→"<em>new</em>", ciw→"<em>new menu</em>")
"     → different buffer.
"   - ct< / cf> from the interior change only the suffix → wrong buffer.
"     (Cursor is strictly interior, never the first/last content char.)
"   - cc / S change the whole line → wrong (prefix+suffix always present,
"     same reason dd can't shortcut dat).
"   - ci< / ca< hit the close tag's angle brackets → wrong buffer.
"   - dit then i then type is 4 keystrokes-to-insert → strictly longer.
"   The enter_at_col check (insert must begin where cit/cat lands) is a
"   secondary guard; the buffer-state match is the real gate.

let s:tags = ['em', 'b', 'i', 'a', 'code', 'span', 'strong',
  \ 'li', 'td', 'h1', 'h2', 'p', 'div', 'label']
" content words: the tag wraps TWO of these (the iw/aw cheat defense).
let s:contents = ['title', 'price', 'header', 'submit', 'active',
  \ 'status', 'login', 'search', 'footer', 'button', 'toggle', 'hidden',
  \ 'open', 'menu', 'save', 'edit', 'list', 'item', 'dark', 'blue']
let s:words = ['the', 'set', 'add', 'new', 'show', 'wrap',
  \ 'sort', 'find', 'open', 'load', 'edit', 'keep']
" Fixed replacement the learner types after cit/cat. Short enough to keep
" the focus on the text-object discrimination, not the typing; 'foo'
" matches the insert family's payload (insert_before_after_char).
let s:REPLACE = 'foo'

function! vimfluency#drills#change_inside_around_tag#meta() abort
  " Discrimination + a 3-char payload, like insert_before_after_char's
  " band but with the it/at cognition on top. Starting guess.
  return {'id': 'change_inside_around_tag', 'name': 'change inside vs around tag (cit / cat)',
    \ 'aim': 35, 'allowed_keys': 'citanew', 'kind': 'mode',
    \ 'prereqs': ['delete_inside_around_tag'], 'keys': 'cit/cat', 'family': 'change',
    \ 'parallel_to': ['delete_inside_around_tag'],
    \ 'credit_on_text_typed': 1,
    \ 'test_sequence': ['cit', 'cat']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#change_inside_around_tag#generate() abort
  let prefix = s:pick(s:words)
  let suffix = s:pick(s:words)
  let tag = s:pick(s:tags)
  " Two distinct content words — the iw/aw cheat defense.
  let w1 = s:pick(s:contents)
  let w2 = s:pick(s:contents)
  while w2 ==# w1
    let w2 = s:pick(s:contents)
  endwhile
  let content = w1 . ' ' . w2

  let open = '<' . tag . '>'
  let close = '</' . tag . '>'
  let block = open . content . close
  let line = prefix . ' ' . block . ' ' . suffix

  " 1-indexed columns.
  let block_start = len(prefix) + 2            " col of the open '<'
  let content_start = block_start + len(open)  " first content char
  let content_end = content_start + len(content) - 1
  let block_end = block_start + len(block) - 1

  " Cursor strictly interior to the content (never first or last char) —
  " the cheat defense against count / ct< style changes.
  let cursor_col = content_start + 1 + s:rand(content_end - content_start - 1)

  let motion = s:rand(2) == 0 ? 'cit' : 'cat'
  if motion ==# 'cit'
    let del_start = content_start
    let del_len = len(content)
    " c deletes the content and enters insert at content_start.
    let removed = strpart(line, 0, content_start - 1) . strpart(line, content_end)
  else
    let del_start = block_start
    let del_len = len(block)
    let removed = strpart(line, 0, block_start - 1) . strpart(line, block_end)
  endif
  " Insert begins at the deletion start; typed text lands there.
  let after_type = strpart(line, 0, del_start - 1) . s:REPLACE
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'start': [1, cursor_col],
    \ 'enter_at_row': 1,
    \ 'enter_at_col': del_start,
    \ 'target_lines': [removed],
    \ 'target_lines_after_type': [after_type],
    \ 'target': [1, del_start],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': printf('Change the highlighted range with c + a tag text object, then type %s.', s:REPLACE),
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1 + len(s:REPLACE),
    \ }
endfunction

function! vimfluency#drills#change_inside_around_tag#lesson() abort
  " Rule-first intro, then cit/cat as try frames from the same interior
  " cursor on the same buffer. credit_on_text_typed try frames carry
  " enter_at_col + target_lines_after_type (the insert family's contract);
  " the learner presses the keys, types the replacement, and the frame
  " advances the moment the text appears.
  let t = s:REPLACE
  let buf = ['the <em>save menu</em> fox']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 11],
    \  'prompt': [
    \    'Two tag text objects with c — change, then type — cursor INSIDE the tag:',
    \    '',
    \    '    cit   →   replaces the content INSIDE the tag (keeps the tags)',
    \    '    cat   →   replaces the WHOLE tag (opening tag, content, closing tag)',
    \    '',
    \    'c deletes the text object and drops you into INSERT to retype it.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 11], 'target': [1, 9],
    \  'enter_at_row': 1, 'enter_at_col': 9,
    \  'target_lines': ['the <em></em> fox'],
    \  'target_lines_after_type': ['the <em>' . t . '</em> fox'],
    \  'deletion_range': [[1, 9, 9]],
    \  'expected_motion': 'cit', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press cit, then type %s — the tags stay, the content changes.', t)},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 11], 'target': [1, 5],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': ['the  fox'],
    \  'target_lines_after_type': ['the ' . t . ' fox'],
    \  'deletion_range': [[1, 5, 18]],
    \  'expected_motion': 'cat', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press cat, then type %s — the whole tag is gone.', t)},
    \ {'kind': 'try', 'lines': ['add <li>dark blue</li> now'], 'start': [1, 11], 'target': [1, 9],
    \  'enter_at_row': 1, 'enter_at_col': 9,
    \  'target_lines': ['add <li></li> now'],
    \  'target_lines_after_type': ['add <li>' . t . '</li> now'],
    \  'deletion_range': [[1, 9, 9]],
    \  'expected_motion': 'cit', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press cit, then type %s.', t)},
    \ {'kind': 'try', 'lines': ['add <li>dark blue</li> now'], 'start': [1, 11], 'target': [1, 5],
    \  'enter_at_row': 1, 'enter_at_col': 5,
    \  'target_lines': ['add  now'],
    \  'target_lines_after_type': ['add ' . t . ' now'],
    \  'deletion_range': [[1, 5, 18]],
    \  'expected_motion': 'cat', 'optimal_motions': 1 + len(t),
    \  'prompt': printf('Press cat, then type %s.', t)},
    \ ]
endfunction
