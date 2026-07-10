" delete_inside_around_word — discriminate diw vs daw, the word text
" objects. `iw` (inner word) selects just the word; `aw` (around word)
" selects the word PLUS one adjacent space. The around form is the clean
" "remove this word" move — it eats a space so you don't leave a double
" gap. The learner reads the highlighted deletion range and picks which
" object describes it: the word alone (diw) vs the word + its trailing
" space (daw).
"
" The whitespace is the whole lesson. `a` is NOT consistent about it
" across object types — aw and a-quote eat a space, but a-bracket and
" a-tag do not (delete_inside_around_tag leaves a double space). Here the
" difference between diw and daw IS that one space, so the target buffers
" differ by exactly it: diw -> "set  get" (double space), daw -> "set get".
"
" Same discrimination model as delete_inside_around_tag: the cursor sits
" in the strict INTERIOR of the word for BOTH motions, so the learner
" can't shortcut by cursor position — only the extent of the red highlight
" (does it cover the trailing space?) distinguishes diw from daw.
"
" Buffer shape: a single line  PREFIX word SUFFIX  — the target word
" always flanked by a plain word on each side. Two reasons: the trailing
" space daw eats always exists (so daw is deterministic — trailing, never
" leading), and the word is never alone on its line (the dd defense).
"
" Cheat analysis (the merge gate — diw/daw must be strictly shortest):
"   Both are 3 keystrokes and one buffer-change event (optimal_motions=1).
"   Every cheaper-or-equal alternative must yield a DIFFERENT buffer:
"   - dw (2 keystrokes, the dangerous tie): from the WORD START, dw
"     deletes "word " — the exact daw result, and shorter. Defeated by the
"     INTERIOR cursor: from inside the word, dw grabs only the tail
"     (partial word) -> different buffer. This is why the cursor is never
"     on the first char.
"   - the sibling object: on a diw item, daw eats an extra space (single
"     vs double gap) -> different buffer; on a daw item, diw leaves the
"     double gap -> different. The one space IS the discrimination.
"   - db / de from the interior delete only part of the word -> different.
"   - dd (2 keystrokes) deletes the whole line — but PREFIX and SUFFIX are
"     always present, so dd removes them too -> different.
"   Conclusion: with an interior cursor and a flanking prefix+suffix, diw
"   and daw are each the strictly shortest path to their own target_lines
"   (verified against real vim in tests/test_generators.vim).

" Target words — always >= 4 chars so the strict interior (never first or
" last char) is at least two cells wide.
let s:words = ['count', 'value', 'total', 'label', 'input', 'title',
  \ 'width', 'color', 'index', 'query', 'token', 'field', 'array',
  \ 'block', 'model', 'route', 'style', 'event', 'state', 'items']
" Plain-word prefix/suffix: non-empty, no spaces.
let s:sides = ['the', 'set', 'add', 'get', 'new', 'let', 'run', 'map',
  \ 'and', 'use', 'put', 'top', 'fix', 'old', 'raw']

function! vimfluency#drills#delete_inside_around_word#meta() abort
  return {'id': 'delete_inside_around_word', 'name': 'delete inside vs around word (diw / daw)',
    \ 'aim': 50, 'allowed_keys': 'diaw', 'kind': 'editing',
    \ 'prereqs': ['delete_char_vs_line'], 'keys': 'diw/daw', 'family': 'delete',
    \ 'test_sequence': ['diw', 'daw']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick(list) abort
  return a:list[s:rand(len(a:list))]
endfunction

function! vimfluency#drills#delete_inside_around_word#generate() abort
  let prefix = s:pick(s:sides)
  let suffix = s:pick(s:sides)
  let word = s:pick(s:words)
  let line = prefix . ' ' . word . ' ' . suffix

  " 1-indexed columns of the target word.
  let ws = len(prefix) + 2
  let we = ws + len(word) - 1

  " Cursor strictly interior (never first or last char) — the dw defense.
  let cursor_col = ws + 1 + s:rand(len(word) - 2)

  let motion = s:rand(2) == 0 ? 'diw' : 'daw'
  " Both delete from the word start; daw also swallows the one trailing
  " space (real vim behavior for a word with a following word).
  let del_start = ws
  let del_len = motion ==# 'diw' ? len(word) : len(word) + 1
  let target_col = del_start
  let target_line = strpart(line, 0, del_start - 1)
    \ . strpart(line, del_start - 1 + del_len)

  return {
    \ 'lines': [line],
    \ 'target_lines': [target_line],
    \ 'start': [1, cursor_col],
    \ 'target': [1, target_col],
    \ 'deletion_range': [[1, del_start, del_len]],
    \ 'prompt': 'Delete the highlighted range using d + a word text object.',
    \ 'expected_motion': motion,
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#delete_inside_around_word#lesson() abort
  " Rule-first with parallel statements, then diw/daw as try frames from
  " the SAME interior cursor on the SAME buffer — juxtaposing the two
  " objects directly. The red range's extent (word vs word+space) is the
  " discriminant; the whitespace rule is stated in the intro.
  let buf = ['set value get']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 7],
    \  'prompt': [
    \    'Two word text objects — the cursor is anywhere INSIDE the word:',
    \    '',
    \    '    diw   →   deletes just the WORD          set value get → set  get',
    \    '    daw   →   the word AND a trailing space   set value get → set get',
    \    '',
    \    'i = inner, a = around, w = word. daw eats one space so you do not',
    \    'leave a double gap — that''s the point of the a-word object.',
    \    '',
    \    'Read the red highlight: past the word into the space → daw;',
    \    'stops at the word → diw.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 7], 'target': [1, 5],
    \  'expected_motion': 'diw', 'optimal_motions': 1,
    \  'target_lines': ['set  get'],
    \  'deletion_range': [[1, 5, 5]],
    \  'prompt': 'Press diw — deletes value, leaving "set  get" (a double gap). The word only.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 7], 'target': [1, 5],
    \  'expected_motion': 'daw', 'optimal_motions': 1,
    \  'target_lines': ['set get'],
    \  'deletion_range': [[1, 5, 6]],
    \  'prompt': 'Press daw — deletes value AND a space, leaving "set get" (clean).'},
    \ {'kind': 'try', 'lines': ['add total now'], 'start': [1, 7], 'target': [1, 5],
    \  'expected_motion': 'diw', 'optimal_motions': 1,
    \  'target_lines': ['add  now'],
    \  'deletion_range': [[1, 5, 5]],
    \  'prompt': 'Press diw.'},
    \ {'kind': 'try', 'lines': ['add total now'], 'start': [1, 7], 'target': [1, 5],
    \  'expected_motion': 'daw', 'optimal_motions': 1,
    \  'target_lines': ['add now'],
    \  'deletion_range': [[1, 5, 6]],
    \  'prompt': 'Press daw.'},
    \ ]
endfunction
