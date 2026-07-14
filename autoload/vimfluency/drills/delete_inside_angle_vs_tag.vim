" delete_inside_angle_vs_tag — discriminate di< from dit, the two
" <>-related text objects that beginners conflate. On one element
" <tag attr>content</tag>:
"
"   cursor in the OPENING TAG  <tag attr>  → di<  removes  tag attr
"                                            (the angle-bracket interior)
"   cursor in the CONTENT       content     → dit  removes  content
"                                            (the tag's inner text)
"
" Same buffer, different cursor → different object. A Direct-Instruction
" juxtaposition drill: the two objects look alike (both live on the
" <…> characters) so the learner has to read WHERE the cursor sits and
" WHAT the red marks, not pattern-match on the angle brackets. di< here
" is exactly the cheat vector delete_inside_around_tag defends against —
" this drill turns that confusion into the thing being trained. Kept out
" of the frontend path on purpose: di< inside a tag is a rare real edit;
" this is a discrimination exercise, not a bread-and-butter reflex.
"
" Editing kind: red deletion_range marks the range, green suppressed,
" single-event delete (optimal 1).
"
" Cheat analysis (the chosen object must be strictly shortest):
"   - diw/daw (the dangerous tie): a single word in either region would
"     let diw reproduce the object. So BOTH regions are two words — the
"     angle interior is `tag attr` (name + one attribute), the content is
"     two words. diw then grabs just one → different buffer.
"   - dt> / dt< from the interior delete only a suffix (cursor is
"     strictly interior of its region, never the first/last char).
"   - dd deletes the whole element line; di</dit each remove only part,
"     so dd is always a different buffer.
"   - di< and dit on the same buffer produce DIFFERENT buffers, so they
"     never credit each other — that IS the discrimination.

let s:tags = ['div', 'span', 'button', 'input', 'label',
  \ 'section', 'nav', 'form', 'header', 'main']
" single attribute word so the angle interior is exactly two words.
let s:attrs = ['hidden', 'active', 'open', 'checked', 'required',
  \ 'disabled', 'selected', 'readonly', 'autofocus', 'draggable']
" content words: two of these (the iw cheat defense in the content).
let s:contents = ['title', 'price', 'submit', 'status', 'login',
  \ 'search', 'footer', 'toggle', 'menu', 'save', 'list', 'item']

function! vimfluency#drills#delete_inside_angle_vs_tag#meta() abort
  " Confusable-pair discrimination; aim a notch below the single-object
  " tag drill. Starting guess.
  return {'id': 'delete_inside_angle_vs_tag', 'name': 'delete inside angle vs tag (di< / dit)',
    \ 'aim': 45, 'allowed_keys': 'di<t', 'kind': 'editing',
    \ 'prereqs': ['delete_char_vs_line'], 'keys': 'di</dit', 'family': 'delete',
    \ 'test_sequence': ['di<', 'dit']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_angle_vs_tag#generate() abort
  let tag = s:pick(s:tags)
  let attr = s:pick(s:attrs)
  let w1 = s:pick(s:contents)
  let w2 = s:pick(s:contents)
  while w2 ==# w1
    let w2 = s:pick(s:contents)
  endwhile
  let content = w1 . ' ' . w2
  let angle = tag . ' ' . attr           " angle-bracket interior (two words)

  let line = '<' . angle . '>' . content . '</' . tag . '>'

  " 1-indexed columns.
  let angle_start = 2                      " first char after '<'
  let angle_end = angle_start + len(angle) - 1
  let content_start = angle_end + 2        " after the opening '>'
  let content_end = content_start + len(content) - 1

  let motion = s:rand(2) == 0 ? 'di<' : 'dit'
  if motion ==# 'di<'
    let del_start = angle_start
    let del_len = len(angle)
    " cursor strictly interior to the angle interior
    let cursor_col = angle_start + 1 + s:rand(len(angle) - 2)
  else
    let del_start = content_start
    let del_len = len(content)
    let cursor_col = content_start + 1 + s:rand(len(content) - 2)
  endif
  let target_col = del_start
  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, target_col],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted range: di< for the angle-bracket interior, dit for the tag content.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_angle_vs_tag#lesson() abort
  " Same buffer for both objects, cursor position the only difference —
  " the juxtaposition is the point.
  let buf1 = ['<div hidden>one two</div>']
  let buf2 = ['<button active>save list</button>']
  return [
    \ {'kind': 'show', 'lines': buf1, 'cursor': [1, 4],
    \  'prompt': [
    \    'Two objects that both live on the <…> characters:',
    \    '',
    \    '    di<   →   inside the ANGLE brackets — the tag name + attributes',
    \    '    dit   →   inside the TAG — the content between <…> and </…>',
    \    '',
    \    'Which one depends on where the cursor sits: in the opening tag,',
    \    'or in the content.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 4], 'target': [1, 2],
    \  'expected_motion': 'di<', 'optimal_motions': 1,
    \  'target_lines': ['<>one two</div>'],
    \  'deletion_range': [[1, 2, 10]],
    \  'prompt': 'Cursor is in the opening tag. Press di< — clears the tag name + attribute.'},
    \ {'kind': 'try', 'lines': buf1, 'start': [1, 15], 'target': [1, 13],
    \  'expected_motion': 'dit', 'optimal_motions': 1,
    \  'target_lines': ['<div hidden></div>'],
    \  'deletion_range': [[1, 13, 7]],
    \  'prompt': 'Cursor is in the content. Press dit — clears the text between the tags.'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 5], 'target': [1, 2],
    \  'expected_motion': 'di<', 'optimal_motions': 1,
    \  'target_lines': ['<>save list</button>'],
    \  'deletion_range': [[1, 2, 13]],
    \  'prompt': 'In the opening tag → di<.'},
    \ {'kind': 'try', 'lines': buf2, 'start': [1, 18], 'target': [1, 16],
    \  'expected_motion': 'dit', 'optimal_motions': 1,
    \  'target_lines': ['<button active></button>'],
    \  'deletion_range': [[1, 16, 9]],
    \  'prompt': 'In the content → dit.'},
    \ ]
endfunction
