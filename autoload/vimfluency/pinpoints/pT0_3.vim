" T0.3 — Save / quit / force-quit. Recall probe over the five canonical
" exits: :w, :q, :wq, :q!, ZZ.
"
" Probe shape: recall kind. The buffer renders a prompt that uniquely
" describes one of the five forms; the learner types the keystroke
" string. Auto-credits on exact match (no <CR> needed — saves a press
" and keeps the free-operant rhythm).
"
" Cheat-defense: each prompt names the form's distinguishing trait.
"   - "save the file" → :w (write only, no quit)
"   - "quit (no pending changes)" → :q (no force, no save)
"   - "save and quit using an Ex command" → :wq
"   - "save and quit using the normal-mode shortcut" → ZZ
"   - "quit without saving" → :q! (discards changes; force)
" :wq and ZZ are aliases in vim's behavior model but distinct
" keystrokes; the catalog tracks them separately because the learner
" needs both in their motor repertoire. The differentiating phrase
" "Ex command" vs "normal-mode shortcut" is the discriminant.
"
" Per-motion bucket: expected_motion == expected_answer for each item,
" so the summary breaks out the five forms independently. Lets the
" learner see which exit form is slowest (typically :q! and ZZ at first).

let s:items = [
  \ {'answer': ':w',
  \  'prompt': 'Save the file (without quitting).'},
  \ {'answer': ':q',
  \  'prompt': 'Quit (assumes no pending changes).'},
  \ {'answer': ':wq',
  \  'prompt': 'Save and quit, using an Ex command.'},
  \ {'answer': ':q!',
  \  'prompt': 'Quit without saving — discard any changes.'},
  \ {'answer': 'ZZ',
  \  'prompt': 'Save and quit, using the normal-mode shortcut.'},
  \ ]

function! vimfluency#pinpoints#pT0_3#meta() abort
  " Recall aim sits below most motion aims because reading and
  " producing a 2-4 char string from a prose prompt has a higher
  " per-item cognitive cost than a single keystroke at a green cell.
  " Catalog starts T0.3 at 30/min.
  return {'id': 'T0.3', 'name': 'save / quit / force-quit',
    \ 'aim': 30, 'allowed_keys': ':wq!Z', 'kind': 'recall',
    \ 'prereqs': []}
endfunction

function! s:rand(n) abort
  return rand() % a:n
endfunction

function! vimfluency#pinpoints#pT0_3#generate() abort
  let pick = s:items[s:rand(len(s:items))]
  " optimal_motions = answer length: one keystroke per char (':' counts,
  " 'w' counts, etc.). The auto-credit triggers on match without an
  " explicit submit, so no +1 for <CR>.
  let prompt_lines = [
    \ '  Type the keystrokes that would:',
    \ '',
    \ '    ' . pick.prompt,
    \ ]
  return {
    \ 'lines': [],
    \ 'start': [1, 1],
    \ 'target': [1, 1],
    \ 'prompt': prompt_lines,
    \ 'expected_answer': pick.answer,
    \ 'expected_motion': pick.answer,
    \ 'optimal_motions': len(pick.answer),
    \ }
endfunction
