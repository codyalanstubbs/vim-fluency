" Shared scenario assets for the save / quit family. Each pinpoint in
" that family calls these helpers to render a realistic buffer
" (status header + code or text snippet + goal line) instead of the
" old abstract one-word prompt.
"
" Why this lives outside autoload/vimfluency/pinpoints/: pinpoint
" discovery globs that subdirectory and any file there is treated
" as a pinpoint. Shared utilities for pinpoints belong one level up.

" Snippet pool. Each entry is a list of buffer lines that LOOK like
" something the learner might have open — a function, notes, config,
" markup. The content is cosmetic: the discrimination cue is the
" status header + goal line, not what's in the file. Rotating the
" snippet between items is the visual-change axis that the previous
" empty-buffer version lacked.
let s:SNIPPETS = [
  \ ['function compute(x) {',
  \  '    let y = x * 2',
  \  '    return y + 1',
  \  '}'],
  \ ['# meeting notes',
  \  '',
  \  '- review the proposal',
  \  '- ship the prototype',
  \  '- thank the team'],
  \ ['const PI = 3.14159',
  \  'const E  = 2.71828',
  \  '',
  \  'export { PI, E }'],
  \ ['<h1>Welcome</h1>',
  \  '<p>This is a draft.</p>',
  \  '<p>Working on it.</p>'],
  \ ['SELECT name, age',
  \  '  FROM users',
  \  ' WHERE age > 18',
  \  ' ORDER BY name;'],
  \ ['def greet(name):',
  \  '    print(f"hi, {name}")',
  \  '',
  \  'greet("vim")'],
  \ ['name: vim-fluency',
  \  'version: 0.1.0',
  \  'license: MIT'],
  \ ['#!/bin/bash',
  \  'set -euo pipefail',
  \  'echo "deploy starting"',
  \  'kubectl apply -f .'],
  \ ['{',
  \  '  "name": "vim",',
  \  '  "ok":   true',
  \  '}'],
  \ ['set number',
  \  'set expandtab',
  \  'set shiftwidth=2',
  \  'colorscheme habamax'],
  \ ]

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Pick a random snippet (list of lines). Cosmetic only.
function! vimfluency#scenarios#snippet() abort
  return s:SNIPPETS[s:rand(len(s:SNIPPETS))]
endfunction

" Format 'modified · N unsaved change[s]' with singular/plural
" handling. The status header in the rendered buffer is the
" load-bearing discrimination cue (modified=yes → save commands;
" modified=no → plain quit), so its wording matters.
function! vimfluency#scenarios#modified_status(n_changes) abort
  return printf('modified · %d unsaved change%s', a:n_changes,
    \ a:n_changes == 1 ? '' : 's')
endfunction

function! vimfluency#scenarios#clean_status() abort
  return 'clean · no unsaved changes'
endfunction

" Compose the prompt list for a recall item. The recall composer
" (s:recall_compose in autoload/vimfluency.vim) renders the prompt
" verbatim above the input line, so the layout we build here is what
" the learner sees:
"
"   ─── status: <status> ───
"   (blank)
"   <snippet lines, 2-col-indented>
"   (blank)
"   Goal: <goal>
"
" status:  e.g. 'modified · 3 unsaved changes' or 'clean · no unsaved changes'
" snippet: list of snippet lines (typically from #snippet())
" goal:    single-line description of the action the learner should take
function! vimfluency#scenarios#compose(status, snippet, goal) abort
  let lines = ['  ─── status: ' . a:status . ' ───', '']
  for l in a:snippet
    call add(lines, '  ' . l)
  endfor
  call add(lines, '')
  call add(lines, '  Goal: ' . a:goal)
  return lines
endfunction
