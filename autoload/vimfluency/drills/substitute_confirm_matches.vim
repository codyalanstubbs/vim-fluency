" substitute_confirm_matches — the confirm flag (:s//gc). The whole point
" of c is SELECTIVE replacement: vim stops on each match and asks
"   replace with bar (y/n/a/q/l/^E/^Y)?
" and you answer per match. /g replaces every match blindly; /gc lets a
" human pick. So this drill is genuinely interactive — the learner runs
" :s/foo/bar/gc and then types y / n to hit a specific subset.
"
" The line holds foo four times; the ones to replace are highlighted green
" (replace_cells) AND flagged with a ▼ marker row above them. The green is
" transient — vim's confirm loop whites it out the instant it lands on a
" match — so the durable cue the learner reads mid-loop is the ▼. Run the
" substitute, then confirm y on each ▼ foo and n on the rest, left to
" right. foo -> bar is length-preserving, so columns never shift and the
" cursor ends on the last match (a fixed cell) — kind 'editing' credits on
" the resulting buffer.
"
" Cheat defense: the target is a SUBSET of identical foo's, so no plainer
" substitute reaches it — /g (or /gc answered all-y) replaces all four
" (wrong buffer), and no :s pattern can single out identical matches. Only
" the confirm loop selects them. (Hand-editing each foo with ciw reaches
" the same buffer but is a different family and strictly more events, so
" the efficiency count steers back to /gc — same footing as the other
" substitute drills, whose Ex commands also aren't keystroke-minimal vs
" manual editing.)

let s:FILLERS = ['let', 'add', 'run', 'end', 'get', 'set', 'new', 'the',
  \ 'and', 'put', 'pop', 'log', 'map', 'use', 'try', 'fix']

function! vimfluency#drills#substitute_confirm_matches#meta() abort
  return {'id': 'substitute_confirm_matches', 'name': 'substitute with confirm (:s//gc)',
    \ 'aim': 18, 'allowed_keys': ':sfobarg/cynaq', 'kind': 'editing',
    \ 'prereqs': ['substitute_first_vs_all'], 'keys': ':s//gc + y/n',
    \ 'commands_display': ':s//gc + y/n', 'family': 'substitute',
    \ 'test_sequence': [':s/foo/bar/gc']}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! s:pick_fillers(count) abort
  let out = []
  while len(out) < a:count
    let f = s:FILLERS[s:rand(len(s:FILLERS))]
    if index(out, f) < 0
      call add(out, f)
    endif
  endwhile
  return out
endfunction

" k distinct indices of 0..n-1, sorted ascending.
function! s:pick_subset(n, k) abort
  let pool = range(a:n)
  let out = []
  while len(out) < a:k
    call add(out, remove(pool, s:rand(len(pool))))
  endwhile
  return sort(out)
endfunction

function! vimfluency#drills#substitute_confirm_matches#generate() abort
  let f = s:pick_fillers(4)
  " filler foo filler foo filler foo filler foo — four matches, never
  " adjacent, so a subset genuinely needs the interactive loop.
  let tokens = [f[0], 'foo', f[1], 'foo', f[2], 'foo', f[3], 'foo']
  let line = join(tokens, ' ')

  let foo_cols = []
  let c = 1
  for t in tokens
    if t ==# 'foo'
      call add(foo_cols, c)
    endif
    let c += len(t) + 1
  endfor

  " replace 2 or 3 of the 4 (never all — that's /g — and never a lone one,
  " where hand-editing would win).
  let replace = s:pick_subset(4, 2 + s:rand(2))

  let target_tokens = copy(tokens)
  let replace_cells = []
  for i in replace
    let target_tokens[2 * i + 1] = 'bar'
    call add(replace_cells, [1, foo_cols[i], 3])
  endfor

  return {
    \ 'lines': [line],
    \ 'start': [1, 1],
    \ 'target': [1, foo_cols[3]],
    \ 'target_lines': [join(target_tokens, ' ')],
    \ 'replace_cells': replace_cells,
    \ 'ignore_cursor': 1,
    \ 'prompt': 'Run :s/foo/bar/gc, then y on each ▼ foo and n on the rest.',
    \ 'expected_motion': ':s/foo/bar/gc',
    \ 'optimal_motions': 1,
    \ }
endfunction

function! vimfluency#drills#substitute_confirm_matches#lesson() abort
  " A: replace 1st + 3rd (5, 21), skip 2nd (13) -> y n y
  let bufA = ['let foo add foo run foo']
  " B: replace 2nd + 3rd (13, 21), skip 1st + 4th -> n y y n
  let bufB = ['set foo pop foo map foo fix foo']
  return [
    \ {'kind': 'show', 'lines': ['pick foo drop foo keep foo'], 'cursor': [1, 1],
    \  'prompt': [
    \    'The c flag makes :substitute PAUSE at each match and ask you to',
    \    'confirm — that''s how you replace SOME matches, not all:',
    \    '',
    \    '    :s/foo/bar/gc',
    \    '',
    \    'Vim stops on each foo and prompts  replace with bar (y/n/a/q/l)?',
    \    '    y = yes, replace     n = no, skip',
    \    '    a = all the rest     q = quit',
    \    '',
    \    'The foo''s to replace are green AND marked ▼. The green disappears',
    \    'under vim''s prompt as it lands on each match, so read the ▼: run',
    \    'the substitute, then y on each ▼ foo and n on the rest.',
    \    '',
    \    'Press <Space> to continue.']},
    \ {'kind': 'try', 'lines': bufA, 'start': [1, 1], 'target': [1, 21],
    \  'target_lines': ['let bar add foo run bar'],
    \  'replace_cells': [[1, 5, 3], [1, 21, 3]], 'ignore_cursor': 1,
    \  'expected_motion': ':s/foo/bar/gc', 'optimal_motions': 1,
    \  'prompt': 'Run :s/foo/bar/gc, then y n y — replace the two ▼ foo''s, skip the middle one.'},
    \ {'kind': 'try', 'lines': bufB, 'start': [1, 1], 'target': [1, 29],
    \  'target_lines': ['set foo pop bar map bar fix foo'],
    \  'replace_cells': [[1, 13, 3], [1, 21, 3]], 'ignore_cursor': 1,
    \  'expected_motion': ':s/foo/bar/gc', 'optimal_motions': 1,
    \  'prompt': 'Run :s/foo/bar/gc, then n y y n — only the two ▼ foo''s in the middle.'},
    \ ]
endfunction

" Demo auto-play: run :s/foo/bar/gc, then answer each foo left-to-right — y
" where its column is a replace_cell (a ▼ match), n otherwise. Returned as a
" LIST so the demo paces it — the command on one tick, then one y/n per tick
" — and the viewer watches each match get confirmed or skipped in turn (a
" single string would answer the whole confirm loop in one frame). Credit is
" on the resulting buffer once the substitute completes.
function! vimfluency#drills#substitute_confirm_matches#solve(item) abort
  let rcols = map(copy(a:item.replace_cells), 'v:val[1]')
  let steps = [":s/foo/bar/gc\r"]
  let i = 0
  while 1
    let idx = match(a:item.lines[0], 'foo', i)
    if idx < 0 | break | endif
    call add(steps, index(rcols, idx + 1) >= 0 ? 'y' : 'n')
    let i = idx + 3
  endwhile
  return steps
endfunction
