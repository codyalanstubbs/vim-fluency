" foundational — the survival + basic-motion curriculum a vim learner
" needs before anything more specialized. Mode-switching, the four
" positional insert-entries, save/quit, undo, hjkl, line edges,
" word motion. Everything else (find char, deletes, indent, etc.) is
" left for a follow-on path.
"
" When `path_pinpoint_ids` lists an id that isn't in the registry
" (e.g. a planned-but-not-shipped pinpoint or an id this path
" predates), s:filter_registry_by_path silently drops it — so the
" path stays correct under rename / removal churn without
" requiring a coordinated edit.

function! vimfluency#paths#foundational#meta() abort
  return {'id': 'foundational',
    \ 'name': 'Foundational',
    \ 'description': 'Survival skills + basic motion — where every learner starts.',
    \ 'include_all': 0,
    \ 'pinpoint_ids': [
    \   'switch_mode_to_insert',
    \   'switch_mode_to_visual',
    \   'switch_mode_to_replace',
    \   'switch_mode_to_command_line',
    \   'switch_between_many_modes',
    \   'insert_before_after_char',
    \   'insert_start_end_line',
    \   'insert_before_after_char_start_end_line',
    \   'insert_line_above_below',
    \   'save_vs_quit',
    \   'save_quit_vs_force_quit',
    \   'save_quit_ex_vs_normal_zz',
    \   'force_quit_ex_vs_normal_zq',
    \   'undo_redo',
    \   'move_single_char_left_right',
    \   'move_single_char_up_down',
    \   'move_single_char_up_down_left_right',
    \   'move_to_line_edges_start_end',
    \   'move_to_line_edges_non_white_space',
    \   'move_to_line_edges_all',
    \   'move_to_word_start_forward_backward',
    \   'move_to_word_end_forward_backward',
    \ ]}
endfunction
