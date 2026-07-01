" frontend — vim for people who live in markup: HTML, JSX, Vue, CSS.
" It's the foundational survival set with two things layered on top:
"
"   1. The tag text objects (dit/dat, cit/cat) — the signature move.
"      Gut an element's contents, swap a class, replace a whole node.
"      This is the reason a frontend dev picks this path over General,
"      so the two tag drills lead the list.
"   2. Two motions markup leans on harder than prose does:
"        - f/F (move_to_char) — jump straight to the delimiters markup
"          is dense with: " = > < { and the like.
"        - >>/<< (indent_vs_dedent) — nested elements live and die by
"          indentation.
"
" Everything past that — the rest of the change/yank/paste families,
" quote/bracket/paren text objects (ci\"/ci(/ci{), Visual mode, search
" and :s — is deferred to follow-on paths and stays reachable via the
" `general` path. This is a focused on-ramp, not the whole language.
"
" As in foundational, ids listed here that aren't in the registry (a
" planned-but-unshipped drill) are silently dropped by
" s:filter_registry_by_path, so the path survives rename / removal
" churn without a coordinated edit.

function! vimfluency#paths#frontend#meta() abort
  return {'id': 'frontend',
    \ 'name': 'Frontend',
    \ 'description': 'Vim for markup — the survival core plus the tag text objects.',
    \ 'include_all': 0,
    \ 'drill_ids': [
    \   'delete_inside_around_tag',
    \   'change_inside_around_tag',
    \   'switch_mode_to_insert',
    \   'switch_mode_to_command_line',
    \   'insert_before_after_char',
    \   'insert_start_end_line',
    \   'insert_line_above_below',
    \   'save_vs_quit',
    \   'save_quit_vs_force_quit',
    \   'undo_redo',
    \   'delete_char_vs_line',
    \   'move_single_char_up_down_left_right',
    \   'move_to_line_edges_start_end',
    \   'move_to_word_start_forward_backward',
    \   'move_to_char_forward_backward',
    \   'indent_vs_dedent',
    \ ]}
endfunction
