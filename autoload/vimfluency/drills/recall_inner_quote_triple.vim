" recall_inner_quote_triple — Inner quote text object: introduce i` (backtick).
"
" Builds on 3.2a. The rule and training shape are identical; the only
" change is the delim alphabet — backtick joins the active set so the
" learner has to discriminate three delimiters instead of two.
"
" Aim sits a tick below 3.2a's 40/min — backtick is rarer in code than
" " and ', and the three-way set is mildly harder to keep separate
" than the two-way pair. Starting guess.
"
" Cheat-defense:
"   - Same shape as 3.2a (one quoted string per cue, arrow inside the
"     inner content, varied inner-word column). The single new axis
"     cell is the backtick delim; everything else is held identical.
"   - Items balance across all three delims so a one-sided guesser
"     (always typing i" or always typing i`) is exposed in the
"     per-motion stats.

let s:INNER_WORDS = ['hello', 'world', 'value', 'name',
  \ 'data', 'foo', 'bar', 'baz', 'key', 'item']

let s:DELIMS = ['"', "'", '`']

function! vimfluency#drills#recall_inner_quote_triple#meta() abort
  return {'id': 'recall_inner_quote_triple', 'name': 'inner quote — add i`',
    \ 'aim': 35, 'allowed_keys': 'i"' . "'" . '`', 'kind': 'recall',
    \ 'prereqs': ['recall_inner_quote_pair'], 'keys': "i\"/i'/i`", 'family': 'text-object-recall',
    \ 'test_sequence': ['i"', "i'", 'i`']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:make_cue(delim) abort
  let inner = s:INNER_WORDS[s:rand(len(s:INNER_WORDS))]
  let prefix = '  some text '
  let suffix = ' more'
  let cue_line = prefix . a:delim . inner . a:delim . suffix
  let cursor_col = len(prefix) + 1 + len(inner) / 2
  let arrow_line = repeat(' ', cursor_col) . '^'
  return [cue_line, arrow_line]
endfunction

function! vimfluency#drills#recall_inner_quote_triple#generate() abort
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

" Lesson focuses on the new delim. The opener restates the rule (so
" the learner doesn't have to remember 3.2a in isolation) and then
" the try frames cycle through all three delims — backtick first so
" the new cell gets the introduction, then ' and " for retention.
function! vimfluency#drills#recall_inner_quote_triple#lesson() abort
  let frames = [{'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \ 'prompt': [
    \   'inner quote text objects, now with backtick.',
    \   '',
    \   'The rule is the same as 3.2a:',
    \   '  i{delim} selects the inner content between matching',
    \   '  {delim} characters on the same line.',
    \   '',
    \   'i` selects the inner content of a `backtick-quoted` string.',
    \   '',
    \   'Press <Space> to begin.']}]
  " New cell first so it gets the introduction, then the prior pair.
  for delim in ['`', "'", '"']
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
