" 1C.4 — discriminate f vs t (and F vs T).
"
" The Disc training from CATALOG: same buffers and target geometry as
" 1C.1 / 1C.2, but the user can't predict which motion is needed.
" Each generated item is a 1C.1 item (target ON a char → fc/Fc) or a
" 1C.2 item (target ONE OFF a char → tc/Tc), picked 50/50. The
" cognitive task is: read the target's position relative to the
" surrounding chars and pick the right motion before executing.
"
" Cheat-defense is inherited entirely from p1C_1 and p1C_2 — we just
" delegate to their generators. Optimal_motions is 1 for every item
" (a single f/F/t/T).
"
" Prereqs: 1C.1 and 1C.2 should be at aim before drilling 1C.4.

function! vimfluency#pinpoints#p1C_4#meta() abort
  return {'id': '1C.4', 'name': 'discriminate f/t (F/T)',
    \ 'aim': 35, 'allowed_keys': 'fFtT', 'prereqs': ['1C.1', '1C.2']}
endfunction

function! vimfluency#pinpoints#p1C_4#lesson() abort
  " The first frame names the discrimination rule. The four try frames
  " walk through one example of each motion in the same buffer so the
  " learner sees the off-by-one shift between f and t side by side.
  " The test phase that runs after these frames generates novel items
  " with no prompt naming the motion — that's where the discrimination
  " is exercised cold.
  let buf = ['the cat ran past us today']
  return [
    \ {'kind': 'show', 'lines': buf, 'cursor': [1, 1],
    \  'prompt': 'f lands ON the char. t lands ONE CELL BEFORE the char. F and T are the backward versions. Read the target''s position relative to the next char to pick.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 13],
    \  'prompt': 'Target is ON the p — use fp.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 1], 'target': [1, 12],
    \  'prompt': 'Target is ONE BEFORE the p — use tp.'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 25], 'target': [1, 13],
    \  'prompt': 'Target is ON the p — use Fp (backward).'},
    \ {'kind': 'try', 'lines': buf, 'start': [1, 25], 'target': [1, 14],
    \  'prompt': 'Target is ONE AFTER the p — use Tp (backward).'},
    \ ]
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#p1C_4#generate() abort
  " 50/50 mix of 1C.1 (f/F) items and 1C.2 (t/T) items. Each delegated
  " generator already handles its own cheat-defense, target uniqueness,
  " and word-margin constraints, so 1C.4 inherits all of that.
  if s:rand(2) == 0
    return vimfluency#pinpoints#p1C_1#generate()
  else
    return vimfluency#pinpoints#p1C_2#generate()
  endif
endfunction
