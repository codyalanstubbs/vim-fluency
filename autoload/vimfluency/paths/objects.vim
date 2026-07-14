" objects — the text-object deep dive. Vim's real editing leverage: name
" a region by its STRUCTURE (a word, the inside of a bracket pair, a
" quoted string, an HTML tag) and operate on it, instead of counting
" characters. This is the follow-on path the foundational / frontend /
" backend deferral notes point at for the AROUND objects, gathered here
" with the inner objects into one coherent progression.
"
" The whole i-vs-a system, built up in order:
"
"   1. The word object (delete_inside_around_word: diw/daw) — the simplest
"      object, and the first taste of the around form's whitespace rule.
"   2. The tag object (delete_inside_around_tag / change_inside_around_tag:
"      dit/dat, cit/cat) — inner and around together, the markup signature.
"   3. The inner delimiter objects — brackets (delete_inside_brackets),
"      quotes (delete_inside_quotes), the dib/diB block aliases
"      (delete_inside_block), di< vs dit (delete_inside_angle_vs_tag), and
"      the change forms (change_inside_brackets / _quotes). Read which
"      delimiter wraps the cursor, fire the matching object.
"   4. The around delimiter PAIRS — one focused di/da drill per delimiter:
"      paren, brace, square_bracket (no whitespace eaten → double gap) and
"      double_quote, single_quote, backtick (a-quote eats a space → single
"      gap). The a-does-NOT-always-eat-whitespace lesson, one pair at a time.
"   5. The around TRIOS (delete_inside_around_brackets / _quotes) — the
"      six-way capstone that mixes di/da across all three pairs at once,
"      gated behind the pairs above.
"
" A learner can pick this path directly, so a small survival core rides
" along at the end (enter/exit insert, save/quit, undo, move, delete a
" char/line) — enough not to get trapped while the objects lead.
"
" Ids listed here that aren't in the registry are silently dropped by
" s:filter_registry_by_path, so the path survives rename / removal churn.

function! vimfluency#paths#objects#meta() abort
  return {'id': 'objects',
    \ 'name': 'Text Objects',
    \ 'description': 'Vim''s text objects — delete and change, inside and around: words, brackets, quotes, tags.',
    \ 'include_all': 0,
    \ 'drill_ids': [
    \   'delete_inside_around_word',
    \   'delete_inside_around_tag',
    \   'change_inside_around_tag',
    \   'delete_inside_brackets',
    \   'delete_inside_quotes',
    \   'delete_inside_block',
    \   'delete_inside_angle_vs_tag',
    \   'change_inside_brackets',
    \   'change_inside_quotes',
    \   'delete_inside_around_paren',
    \   'delete_inside_around_brace',
    \   'delete_inside_around_square_bracket',
    \   'delete_inside_around_double_quote',
    \   'delete_inside_around_single_quote',
    \   'delete_inside_around_backtick',
    \   'delete_inside_around_brackets',
    \   'delete_inside_around_quotes',
    \   'switch_mode_to_insert',
    \   'switch_mode_to_command_line',
    \   'insert_before_after_char',
    \   'save_vs_quit',
    \   'undo_redo',
    \   'delete_char_vs_line',
    \   'move_single_char_up_down_left_right',
    \   'move_to_line_edges_start_end',
    \   'move_to_word_start_forward_backward',
    \   'move_to_char_forward_backward',
    \ ]}
endfunction
