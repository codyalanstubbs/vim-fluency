" backend — vim for people who move through and refactor code: server
" code, scripts, config, tests. The survival core plus what a backend
" dev reaches for that a prose or markup writer doesn't:
"
"   1. Navigate by symbol and refactor — the signatures, so they lead:
"        - */# (search_word_forward_backward) — jump to the next/prev
"          occurrence of the identifier under the cursor, no pattern to
"          type. The core code-reading move. / ? (typed search,
"          search_pattern_forward_backward) — find text you're NOT on.
"          And n / N (search_repeat_next_prev) — cycle the matches.
"        - :s / :%s (substitute_line_vs_file) — rename on this line vs
"          across the whole file — and the /g flag, first match vs all
"          on the line (substitute_first_vs_all).
"   2. The code-structure text objects — edit what's inside the brackets,
"      quotes, and blocks code is built from:
"        - di(/di{/di[ and ci(/ci{/ci[ (delete/change_inside_brackets) —
"          call args, arrays, objects, expressions.
"        - di\"/di'/di` and ci\"/ci'/ci` (delete/change_inside_quotes) —
"          string literals.
"        - dib/diB (delete_inside_block) — the () and {} home-row aliases.
"      (The TAG objects dit/dat, cit/cat are markup — they live in the
"      frontend path, not here.)
"   3. Code-weighted navigation and line surgery: f/F to hit delimiters,
"      w/b/e word motions, 0/$ line edges, and yy/p, ddp/ddkP to copy and
"      reorder lines.
"
" Deferred to follow-on paths (and reachable via `general`): the
" substitute confirm flag (/gc), the around objects, macros (q/@),
" marks, and the quickfix list.
"
" Ids not yet in the registry (a planned-but-unshipped drill) are silently
" dropped by s:filter_registry_by_path, so the path survives rename /
" removal churn without a coordinated edit.

function! vimfluency#paths#backend#meta() abort
  return {'id': 'backend',
    \ 'name': 'Backend',
    \ 'description': 'Vim for code — navigate by symbol, refactor, edit code structures.',
    \ 'include_all': 0,
    \ 'drill_ids': [
    \   'search_word_forward_backward',
    \   'search_pattern_forward_backward',
    \   'search_repeat_next_prev',
    \   'substitute_line_vs_file',
    \   'substitute_first_vs_all',
    \   'delete_inside_brackets',
    \   'change_inside_brackets',
    \   'delete_inside_quotes',
    \   'change_inside_quotes',
    \   'delete_inside_block',
    \   'move_to_char_forward_backward',
    \   'move_to_word_start_forward_backward',
    \   'move_to_word_end_forward_backward',
    \   'move_to_line_edges_start_end',
    \   'move_single_char_up_down_left_right',
    \   'delete_char_vs_line',
    \   'copy_line_to_target',
    \   'paste_line_below_above',
    \   'move_line_down_up',
    \   'undo_redo',
    \   'switch_mode_to_insert',
    \   'switch_mode_to_command_line',
    \   'insert_before_after_char',
    \   'save_vs_quit',
    \ ]}
endfunction
