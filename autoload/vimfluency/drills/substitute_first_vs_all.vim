" substitute_first_vs_all — discriminate the /g flag, the other
" substitute axis (substitute_line_vs_file covers the % scope). Both act
" on the current line; what varies is how many matches:
"
"   :s/foo/bar/     →   the FIRST foo on the line
"   :s/foo/bar/g    →   EVERY foo on the line
"
" kind 'command', same shape as substitute_line_vs_file: read the Goal,
" type the Ex command, credited on an exact string match. foo→bar fixed
" so the two commands are stable strings the test phase can cycle.
"
" Every snippet carries foo MORE THAN ONCE on line 1 (the cursor line),
" so first-vs-all is a real, visible difference — the runner paints
" after_lines on success, and the learner sees :s change one foo while
" :s...g changes them all. That contrast IS the lesson for the g flag.

let s:GOALS = {
  \ ':s/foo/bar/': 'replace the first foo with bar on this line',
  \ ':s/foo/bar/g': 'replace every foo with bar on this line',
  \ }
let s:CMDS = [':s/foo/bar/', ':s/foo/bar/g']

" Line 1 (the cursor line) has foo at least twice so /g does strictly
" more than the bare command.
let s:SNIPPETS = [
  \ {'comment': '//', 'lines': ['foo = foo + 1', 'return foo', 'done']},
  \ {'comment': '#', 'lines': ['foo(foo, foo)', 'print(x)', 'exit']},
  \ {'comment': '//', 'lines': ['let foo = foo', 'call(foo)', 'end']},
  \ ]

function! vimfluency#drills#substitute_first_vs_all#meta() abort
  return {'id': 'substitute_first_vs_all', 'name': 'substitute first vs all (:s vs :s…g)',
    \ 'aim': 25, 'allowed_keys': ':sfobarg/', 'kind': 'command',
    \ 'prereqs': ['substitute_line_vs_file'],
    \ 'keys': ':s// / :s//g', 'family': 'substitute',
    \ 'test_sequence': [':s/foo/bar/', ':s/foo/bar/g']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

" Line 1 after the substitute: first match (no flag) or every match (g).
function! s:after_lines(snippet, all) abort
  let out = copy(a:snippet.lines)
  let out[0] = substitute(out[0], 'foo', 'bar', a:all ? 'g' : '')
  return out
endfunction

function! vimfluency#drills#substitute_first_vs_all#generate() abort
  let cmd = s:CMDS[s:rand(len(s:CMDS))]
  let snippet = s:SNIPPETS[s:rand(len(s:SNIPPETS))]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'snippet': snippet,
    \ 'after_lines': s:after_lines(snippet, cmd[-1 :] ==# 'g'),
    \ 'goal': s:GOALS[cmd],
    \ 'expected_answer': cmd,
    \ 'expected_motion': cmd,
    \ 'optimal_motions': len(cmd),
    \ }
endfunction

function! vimfluency#drills#substitute_first_vs_all#lesson() abort
  let snippet = s:SNIPPETS[0]
  return [
    \ {'kind': 'show', 'lines': [], 'cursor': [1, 1],
    \  'prompt': [
    \    'The trailing g on a substitute means "all matches", not just',
    \    'the first — on the current line:',
    \    '',
    \    '    :s/foo/bar/    →   the FIRST foo on this line',
    \    '    :s/foo/bar/g   →   EVERY foo on this line',
    \    '',
    \    'Watch the snippet change: without g, one foo flips; with g, all',
    \    'of them do. Type the command, then <CR>.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':s/foo/bar/', 'expected_motion': ':s/foo/bar/',
    \  'optimal_motions': len(':s/foo/bar/'),
    \  'snippet': snippet, 'after_lines': s:after_lines(snippet, 0),
    \  'goal': s:GOALS[':s/foo/bar/']},
    \ {'kind': 'try', 'lines': [],
    \  'expected_answer': ':s/foo/bar/g', 'expected_motion': ':s/foo/bar/g',
    \  'optimal_motions': len(':s/foo/bar/g'),
    \  'snippet': snippet, 'after_lines': s:after_lines(snippet, 1),
    \  'goal': s:GOALS[':s/foo/bar/g']},
    \ ]
endfunction
