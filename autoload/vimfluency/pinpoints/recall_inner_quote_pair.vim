" recall_inner_quote_pair — Inner quote text object: discriminate i" vs i'.
"
" Foundation pair for quote text objects. Holds the 'i' rule constant
" (inner content) and varies the delimiter. The visible quote char in
" the buffer cue is the entire discriminative cue.
"
" Training shape: recall kind, binary discrimination on quote-delim type.
" The learner sees a buffer line with a quoted string and an arrow (^)
" pointing into the inner content. They type i + delim. Auto-credits
" on exact match.
"
" Cheat-defense:
"   - Each cue has exactly one quoted string on the visible line, with
"     the arrow inside the inner content. No outer text contains quote
"     characters that could be mistaken for delimiters.
"   - The delim is the only varying axis between items — minimal pair.
"   - Inner content word is randomized from a small pool of pure-alpha
"     words so the cursor column varies across items. The user can't
"     memorize a position, only the rule.
"   - The 'a' variants live in 3.6 (i-vs-a discrimination across all
"     text-object families). Mixing i and a here would be a hidden
"     second axis (see [[2026-05-14-recall-is-discrimination]]).
"   - Single-char inputs (just " or ') don't credit — the rule requires
"     the leading i. Always typing i" gets ~50% on a balanced sample;
"     the per-motion stats in :VfHistory expose any one-sided guesser.

let s:INNER_WORDS = ['hello', 'world', 'value', 'name',
  \ 'data', 'foo', 'bar', 'baz', 'key', 'item']

let s:DELIMS = ['"', "'"]

function! vimfluency#pinpoints#recall_inner_quote_pair#meta() abort
  " Aim mirrors T0.3a (40/min) — binary recall, two-keystroke answer.
  " Same shape, same cognitive load. Starting guess; revise on data.
  return {'id': 'recall_inner_quote_pair', 'name': 'inner quote — i" vs i' . "'",
    \ 'aim': 40, 'allowed_keys': 'i"' . "'", 'kind': 'recall',
    \ 'prereqs': ['change_current_mode', 'insert_basic'], 'keys': "i\"/i'", 'family': 'text-object-recall'}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Build a cue: a context line with one quoted string and an arrow row
" pointing into the inner content. Returns [cue_line, arrow_line].
function! s:make_cue(delim) abort
  let inner = s:INNER_WORDS[s:rand(len(s:INNER_WORDS))]
  let prefix = '  some text '
  let suffix = ' more'
  let cue_line = prefix . a:delim . inner . a:delim . suffix
  " cursor sits at the middle char of the inner word (0-indexed col).
  let cursor_col = len(prefix) + 1 + len(inner) / 2
  let arrow_line = repeat(' ', cursor_col) . '^'
  return [cue_line, arrow_line]
endfunction

function! vimfluency#pinpoints#recall_inner_quote_pair#generate() abort
  let delim = s:DELIMS[s:rand(len(s:DELIMS))]
  let answer = 'i' . delim
  let [cue_line, arrow_line] = s:make_cue(delim)
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'prompt': [
    \   'Type the text object to select the inner content:',
    \   '',
    \   cue_line,
    \   arrow_line],
    \ 'expected_answer': answer,
    \ 'expected_motion': answer,
    \ 'optimal_motions': len(answer),
    \ }
endfunction

" DI sequence: a show frame states the rule in parallel form, then one
" try frame per delim so the learner produces each answer at least once
" before the runner's test phase starts generating novel items.
function! vimfluency#pinpoints#recall_inner_quote_pair#lesson() abort
  let frames = [{'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \ 'prompt': [
    \   'inner quote text objects.',
    \   '',
    \   'i" selects the inner content of a "double-quoted" string.',
    \   "i' selects the inner content of a 'single-quoted' string.",
    \   '',
    \   'In the cue, the arrow (^) marks the cursor inside the',
    \   'inner content. Read the visible delimiter and type i +',
    \   'that delimiter.',
    \   '',
    \   'Press <Space> to begin.']}]
  for delim in s:DELIMS
    let answer = 'i' . delim
    let [cue_line, arrow_line] = s:make_cue(delim)
    call add(frames, {
      \ 'kind': 'try', 'lines': [],
      \ 'expected_answer': answer,
      \ 'expected_motion': answer,
      \ 'optimal_motions': len(answer),
      \ 'prompt': [
      \   'Cursor inside ' . delim . '...' . delim . ' — type the inner text object:',
      \   '',
      \   cue_line,
      \   arrow_line]})
  endfor
  return frames
endfunction
