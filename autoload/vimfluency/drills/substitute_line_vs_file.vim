" substitute_line_vs_file — discriminate :s vs :%s, the substitute
" scope. Both replace every occurrence (the /g flag); what varies is the
" range:
"
"   :s/foo/bar/g    →   this line only
"   :%s/foo/bar/g   →   every line in the file (the whole-file rename)
"
" kind 'command': the learner reads the Goal (a code comment above a
" snippet) and types the matching Ex command; the runner captures it via
" input(':') and credits on an exact string match — the buffer is never
" executed against, so the snippet is pure scenario. Same shape as
" save_vs_quit.
"
" foo→bar is fixed so the two commands are stable strings the test phase
" can cycle through (test_sequence must list exact expected_motion
" values); the snippet rotates for visual variety, and every snippet
" carries foo on more than one line so the line-vs-file distinction is
" real. The Goal's 'this line' / 'the file' wording is the single
" discriminative cue — the % is the whole answer.

let s:GOALS = {
  \ ':s/foo/bar/g': 'replace every foo with bar on this line',
  \ ':%s/foo/bar/g': 'replace every foo with bar in the file',
  \ }
let s:CMDS = [':s/foo/bar/g', ':%s/foo/bar/g']

" Snippets carry foo on line 1 (where the cursor sits → ':s' scope) and
" on later lines (so ':%s' does strictly more).
let s:SNIPPETS = [
  \ {'comment': '//', 'lines': [
  \   'let foo = load()',
  \   'return foo.id',
  \   'log(foo)']},
  \ {'comment': '#', 'lines': [
  \   'foo = fetch()',
  \   'print(foo)',
  \   'del foo']},
  \ {'comment': '//', 'lines': [
  \   'const foo = 0',
  \   'foo += step',
  \   'emit(foo)']},
  \ ]

function! vimfluency#drills#substitute_line_vs_file#meta() abort
  return {'id': 'substitute_line_vs_file', 'name': 'substitute line vs file (:s / :%s)',
    \ 'aim': 25, 'allowed_keys': ':%sfobarg/', 'kind': 'command',
    \ 'prereqs': ['switch_mode_to_command_line'],
    \ 'keys': ':s//g / :%s//g', 'family': 'substitute',
    \ 'test_sequence': [':s/foo/bar/g', ':%s/foo/bar/g']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" The snippet after the substitution runs: foo→bar on every line (file
" scope, :%s) or on the first line only (line scope, :s) — mirroring the
" command so the learner sees the result the runner paints on success.
function! s:after_lines(snippet, file_scope) abort
  let out = copy(a:snippet.lines)
  if a:file_scope
    call map(out, 'substitute(v:val, "foo", "bar", "g")')
  else
    let out[0] = substitute(out[0], 'foo', 'bar', 'g')
  endif
  return out
endfunction

function! vimfluency#drills#substitute_line_vs_file#generate() abort
  let cmd = s:CMDS[s:rand(len(s:CMDS))]
  let snippet = s:SNIPPETS[s:rand(len(s:SNIPPETS))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'snippet': snippet,
    \ 'after_lines': s:after_lines(snippet, cmd =~# '^:%s'),
    \ 'goal': s:GOALS[cmd],
    \ 'expected_answer': cmd,
    \ 'expected_motion': cmd,
    \ 'optimal_motions': len(cmd),
    \ }
endfunction

function! vimfluency#drills#substitute_line_vs_file#lesson() abort
  let snippet = s:SNIPPETS[0]
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'Substitute — :s replaces text. The scope is the range prefix:',
    \    '',
    \    '    :s/foo/bar/g    →   every foo on THIS LINE',
    \    '    :%s/foo/bar/g   →   every foo in the WHOLE FILE',
    \    '',
    \    'The trailing g means "all matches", not just the first; the',
    \    'leading % means "all lines". Type the command, then <CR>.',
    \    '',
    \    'Each item shows a snippet with the Goal as a comment:',
    \    '  Goal: ... on this line   →   :s/foo/bar/g<CR>',
    \    '  Goal: ... in the file    →   :%s/foo/bar/g<CR>',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':s/foo/bar/g', 'expected_motion': ':s/foo/bar/g',
    \  'optimal_motions': len(':s/foo/bar/g'),
    \  'snippet': snippet, 'after_lines': s:after_lines(snippet, 0),
    \  'goal': s:GOALS[':s/foo/bar/g']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':%s/foo/bar/g', 'expected_motion': ':%s/foo/bar/g',
    \  'optimal_motions': len(':%s/foo/bar/g'),
    \  'snippet': snippet, 'after_lines': s:after_lines(snippet, 1),
    \  'goal': s:GOALS[':%s/foo/bar/g']},
    \ ]
endfunction
