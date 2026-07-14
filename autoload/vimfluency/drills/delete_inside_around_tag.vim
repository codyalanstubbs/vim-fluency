" delete_inside_around_tag — discriminate dit vs dat, the tag text
" objects. The first text-object cell in the registry and the frontend
" path's signature drill: `it` (inside tag) selects the content between
" a matching <tag>…</tag> pair; `at` (around tag) selects the whole
" block including both tags. The learner reads the highlighted deletion
" range and picks which text object describes it — inner content (dit)
" vs the entire tag block (dat).
"
" Same discrimination model as delete_char_vs_line and
" delete_to_word_start_forward_backward: the cursor sits in the strict
" interior of the content for BOTH motions, so the learner cannot
" shortcut by cursor inspection — only the extent of the red highlight
" distinguishes dit from dat.
"
" Buffer shape: a single line  PREFIX <tag>word1 word2</tag> SUFFIX  with
" plain-word prefix/suffix on either side of one tag. The content is
" always TWO words (the iw/aw defense — see below). No second tag, no
" stray angle brackets — one unambiguous <…>…</…> structure per item.
"
" Cheat analysis (the merge gate — dit/dat must be strictly shortest):
"   Both dit and dat are 3 keystrokes and register as ONE buffer-change
"   event (optimal_motions = 1, like dw). To stay strictly shortest,
"   every cheaper or equal alternative must yield a DIFFERENT buffer:
"
"   - diw / daw (3 keystrokes, the dangerous tie): if the content were a
"     SINGLE word, diw would delete exactly that word — identical buffer
"     AND cursor to dit, same keystroke count → a tie that breaks the
"     gate. The content is therefore always TWO words: diw grabs only
"     one of them (leaves " word2"), daw grabs one word + a space → both
"     yield a different buffer. This is the whole reason for two-word
"     content.
"   - dt< from the first content char WOULD span the whole content (tie),
"     so the cursor is placed in the strict INTERIOR (never first/last
"     char): dt< / df> then delete only the suffix → wrong buffer.
"   - Count / charwise delete (Nx, dl, d2w, …): from the interior no
"     one-directional ≤3-keystroke delete spans the whole content
"     without overshooting into the tags (battery-verified).
"   - dT< / dT> delete backward into the OPEN tag → wrong buffer.
"   - dd (2 keystrokes) deletes the whole line — but PREFIX and SUFFIX
"     are always present, so dd removes them too → wrong buffer. This is
"     why the tag is never alone on its line (the dat defense).
"   - di< / da< / di> operate on the angle-bracket pair of the CLOSE
"     tag from this cursor (verified: di< → "<>", da< → drops "</em>")
"     → wrong buffer, never our target.
"   - vit d / vat d are 4 keystrokes → longer.
"   Conclusion: with two-word content, an interior cursor, and a present
"   prefix+suffix, dit and dat are each the strictly shortest path to
"   their own target_lines (no ≤3-keystroke alternative reproduces both
"   the buffer and the cursor — see tests/test_generators.vim).
"
" Per-motion accounting: dit/dat each fire a single deduped
" TextChanged event, so a clean run scores actual=1 against
" optimal_motions=1. dat leaves the surrounding spaces untouched
" (real vim behavior: "the <em>x</em> fox" → "the  fox", double
" space) — the target_line reflects that faithfully.

let s:tags = ['em', 'b', 'i', 'a', 'code', 'span', 'strong',
  \ 'li', 'td', 'h1', 'h2', 'p', 'div', 'label']
" content words: the tag wraps TWO of these (the iw/aw cheat defense).
let s:contents = ['title', 'price', 'header', 'submit', 'active',
  \ 'status', 'login', 'search', 'footer', 'button', 'toggle', 'hidden',
  \ 'open', 'menu', 'save', 'edit', 'list', 'item', 'dark', 'blue']
" plain-word prefix/suffix: non-empty, no angle brackets, no spaces.
let s:words = ['the', 'set', 'add', 'new', 'show', 'wrap',
  \ 'sort', 'find', 'open', 'load', 'edit', 'keep']

function! vimfluency#drills#delete_inside_around_tag#meta() abort
  " Discrimination + text-object cognition on a 3-keystroke composite;
  " aim set a notch below the delete-family discrimination drills.
  " Starting guess — revise on data.
  return {'id': 'delete_inside_around_tag', 'name': 'delete inside vs around tag (dit / dat)',
    \ 'aim': 50, 'allowed_keys': 'dita', 'kind': 'editing',
    \ 'prereqs': ['delete_inside_angle_vs_tag'], 'keys': 'dit/dat', 'family': 'delete',
    \ 'test_sequence': ['dit', 'dat']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_around_tag#generate() abort
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

  " Cursor strictly interior to the content (never first or last char) —
  " this is the cheat defense against count / dt< style deletes.
  let cursor_col = content_start + 1 + s:rand(content_end - content_start - 1)

  let motion = s:rand(2) == 0 ? 'dit' : 'dat'
  if motion ==# 'dit'
    let del_start = content_start
    let del_len = len(content)
  else
    let del_start = block_start
    let del_len = len(block)
  endif
  " Both land the cursor at the column where the deletion began.
  let target_col = del_start

  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, target_col],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted range using d + a tag text object.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_around_tag#lesson() abort
  " Rule-first intro with parallel statements, then dit/dat as try
  " frames so the learner performs each delete and watches the buffer
  " change. Both demos start from the SAME interior cursor on the SAME
  " buffer, juxtaposing the two text objects directly. Wrong-operator
  " recovery is the runner's [u=undo if wrong] header (editing kind).
  let buf = ['the <em>save menu</em> fox']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 11],
    \  'prompt': [
    \    'Two tag text objects — the cursor is anywhere INSIDE the tag:',
    \    '',
    \    '    dit   →   deletes the content INSIDE the tag (between > and <)',
    \    '    dat   →   deletes the WHOLE tag — opening tag, content, closing tag',
    \    '',
    \    'i = inner, a = around. t = tag. d takes the text object as its range.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 11], 'target': [1, 9],
    \  'expected_motion': 'dit', 'optimal_motions': 1,
    \  'target_lines': ['the <em></em> fox'],
    \  'deletion_range': [[1, 9, 9]],
    \  'prompt': 'Press dit — empties the tag, leaving <em></em>. The tags stay.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 11], 'target': [1, 5],
    \  'expected_motion': 'dat', 'optimal_motions': 1,
    \  'target_lines': ['the  fox'],
    \  'deletion_range': [[1, 5, 18]],
    \  'prompt': 'Press dat — removes the whole tag, leaving "the  fox".'},
    \ {'kind': 'try', 'lines': ['add <li>dark blue</li> now'], 'start': [1, 11], 'target': [1, 9],
    \  'expected_motion': 'dit', 'optimal_motions': 1,
    \  'target_lines': ['add <li></li> now'],
    \  'deletion_range': [[1, 9, 9]],
    \  'prompt': 'Press dit.'},
    \ {'kind': 'try', 'lines': ['add <li>dark blue</li> now'], 'start': [1, 11], 'target': [1, 5],
    \  'expected_motion': 'dat', 'optimal_motions': 1,
    \  'target_lines': ['add  now'],
    \  'deletion_range': [[1, 5, 18]],
    \  'prompt': 'Press dat.'},
    \ ]
endfunction
