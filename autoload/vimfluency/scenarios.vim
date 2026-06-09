" Shared scenario assets for the save / quit family. Each pinpoint
" in that family calls these helpers to render a realistic buffer
" snippet with a single comment line at the top stating the goal.
"
" Why this lives outside autoload/vimfluency/pinpoints/: pinpoint
" discovery globs that subdirectory and any file there is treated
" as a pinpoint. Shared utilities belong one level up.

" Snippet pool. Each entry pairs a list of buffer lines with the
" language-appropriate comment prefix that the renderer uses for
" the 'Goal: …' line. JSON (no native comment syntax) is omitted
" rather than rendered with an invalid prefix.
let s:SNIPPETS = [
  \ {'comment': '//',
  \  'lines': [
  \    'function compute(x) {',
  \    '    let y = x * 2',
  \    '    return y + 1',
  \    '}']},
  \ {'comment': '<!--',
  \  'lines': [
  \    '# meeting notes',
  \    '',
  \    '- review the proposal',
  \    '- ship the prototype',
  \    '- thank the team']},
  \ {'comment': '//',
  \  'lines': [
  \    'const PI = 3.14159',
  \    'const E  = 2.71828',
  \    '',
  \    'export { PI, E }']},
  \ {'comment': '<!--',
  \  'lines': [
  \    '<h1>Welcome</h1>',
  \    '<p>This is a draft.</p>',
  \    '<p>Working on it.</p>']},
  \ {'comment': '--',
  \  'lines': [
  \    'SELECT name, age',
  \    '  FROM users',
  \    ' WHERE age > 18',
  \    ' ORDER BY name;']},
  \ {'comment': '#',
  \  'lines': [
  \    'def greet(name):',
  \    '    print(f"hi, {name}")',
  \    '',
  \    'greet("vim")']},
  \ {'comment': '#',
  \  'lines': [
  \    'name: vim-fluency',
  \    'version: 0.1.0',
  \    'license: MIT']},
  \ {'comment': '#',
  \  'lines': [
  \    '#!/bin/bash',
  \    'set -euo pipefail',
  \    'echo "deploy starting"',
  \    'kubectl apply -f .']},
  \ {'comment': '"',
  \  'lines': [
  \    'set number',
  \    'set expandtab',
  \    'set shiftwidth=2',
  \    'colorscheme habamax']},
  \ ]

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Pick a random snippet. Returns a dict {lines, comment}. The
" comment field is the leading marker the renderer prepends to the
" goal line (e.g. '#' for python, '//' for js, '<!--' for html).
function! vimfluency#scenarios#snippet() abort
  return s:SNIPPETS[s:rand(len(s:SNIPPETS))]
endfunction

" Build the goal comment line for a given snippet's comment style.
" For block-comment languages (HTML <!-- … -->) the closing marker
" is appended; for line-comment languages (//, #, --, ") nothing
" trails. Single-line by construction.
function! vimfluency#scenarios#goal_comment(snippet, goal) abort
  let prefix = a:snippet.comment
  if prefix ==# '<!--'
    return printf('<!-- Goal: %s -->', a:goal)
  endif
  return printf('%s Goal: %s', prefix, a:goal)
endfunction
