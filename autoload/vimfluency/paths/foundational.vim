" foundational — the MINIMUM viable beginner path: the smallest set
" that lets a learner survive a vim session and do basic editing
" without getting trapped. Enter/exit insert (i + Esc/Ctrl-[), escape
" the command line, position-aware insert (i/a, I/A, o/O), save/quit
" (:w/:q/:wq/:q!), undo, delete a char/line (x/dd), copy/paste a line
" (yy then p/P), move (hjkl), jump to line start/end (0/$), and word
" motion (w/b).
"
" Deliberately a SUBSET, not a course. Efficiency refinements and
" anything past survival — the ZZ/ZQ shortcuts, Replace/Visual mode,
" ^/g_ line edges, word-end e/ge, the narrower h/l & j/k fallbacks,
" find-char, the rest of the delete family, change, the text-object and
" charwise yank/paste forms, indent, etc. — are left for follow-on
" paths. They all stay reachable via the `general` path.
"
" When `drill_ids` lists an id that isn't in the registry (e.g. a
" planned-but-not-shipped drill or an id this path predates),
" s:filter_registry_by_path silently drops it — so the path stays
" correct under rename / removal churn without a coordinated edit.

function! vimfluency#paths#foundational#meta() abort
  return {'id': 'foundational',
    \ 'name': 'Foundational',
    \ 'description': 'The minimum to survive and edit — where every learner starts.',
    \ 'include_all': 0,
    \ 'drill_ids': [
    \   'switch_mode_to_insert',
    \   'switch_mode_to_command_line',
    \   'insert_before_after_char',
    \   'insert_start_end_line',
    \   'insert_line_above_below',
    \   'save_vs_quit',
    \   'save_quit_vs_force_quit',
    \   'undo_redo',
    \   'delete_char_vs_line',
    \   'copy_line_to_target',
    \   'paste_line_below_above',
    \   'move_single_char_up_down_left_right',
    \   'move_to_line_edges_start_end',
    \   'move_to_word_start_forward_backward',
    \ ]}
endfunction
