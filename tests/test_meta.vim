" Property tests over each pinpoint's meta(). Asserts the contract:
" id, name, aim, allowed_keys, prereqs are all present and well-typed.
" The :VfList navigator relies on prereqs to compute eligibility (now
" diagnostic, not gating) — a missing field is a runtime hazard, not
" a cosmetic issue.

let s:expected = [
  \ {'id': 'switch_mode_to_insert', 'prereqs': []},
  \ {'id': 'switch_mode_to_visual', 'prereqs': []},
  \ {'id': 'switch_mode_to_replace', 'prereqs': []},
  \ {'id': 'switch_mode_to_command_line', 'prereqs': []},
  \ {'id': 'switch_btwn_many_modes',
  \   'prereqs': ['switch_mode_to_insert', 'switch_mode_to_visual',
  \               'switch_mode_to_replace', 'switch_mode_to_command_line']},
  \ {'id': 'insert_before_after_char', 'prereqs': []},
  \ {'id': 'insert_start_end_line', 'prereqs': []},
  \ {'id': 'insert_before_after_char_start_end_line',
  \   'prereqs': ['insert_before_after_char', 'insert_start_end_line']},
  \ {'id': 'insert_line_above_below', 'prereqs': []},
  \ {'id': 'save_vs_quit', 'prereqs': []},
  \ {'id': 'save_quit_vs_force_quit', 'prereqs': []},
  \ {'id': 'save_quit_ex_vs_normal_zz', 'prereqs': []},
  \ {'id': 'force_quit_ex_vs_normal_zq', 'prereqs': []},
  \ {'id': 'undo_redo', 'prereqs': []},
  \ {'id': 'move_single_char_up_down_left_right',
  \   'prereqs': ['move_single_char_left_right', 'move_single_char_up_down']},
  \ {'id': 'move_to_line_edges_all',
  \   'prereqs': ['move_to_line_edges_beginning_end',
  \               'move_to_line_edges_non_white_space']},
  \ {'id': 'move_single_char_left_right', 'prereqs': []},
  \ {'id': 'move_single_char_up_down', 'prereqs': []},
  \ {'id': 'move_to_line_edges_beginning_end', 'prereqs': []},
  \ {'id': 'move_to_line_edges_non_white_space', 'prereqs': []},
  \ {'id': 'move_to_word_start_forward_backward', 'prereqs': []},
  \ {'id': 'move_to_word_end_forward_backward', 'prereqs': []},
  \ {'id': 'move_to_char_forward_backward', 'prereqs': ['move_single_char_up_down_left_right']},
  \ {'id': 'move_till_char_forward_backward', 'prereqs': ['move_to_char_forward_backward']},
  \ {'id': 'move_repeat_last_find_forward_backward', 'prereqs': ['move_to_char_forward_backward', 'move_till_char_forward_backward']},
  \ {'id': 'move_to_till_forward', 'prereqs': []},
  \ {'id': 'move_to_till_backward', 'prereqs': []},
  \ {'id': 'move_to_till_forward_backward',
  \   'prereqs': ['move_to_char_forward_backward',
  \               'move_till_char_forward_backward',
  \               'move_to_till_forward', 'move_to_till_backward']},
  \ {'id': 'delete_char_vs_line', 'prereqs': []},
  \ {'id': 'discriminate_indent_vs_dedent',  'prereqs': ['switch_mode_to_insert', 'insert_before_after_char_start_end_line']},
  \ {'id': 'recall_inner_quote_pair', 'prereqs': ['switch_mode_to_insert', 'insert_before_after_char_start_end_line']},
  \ {'id': 'recall_inner_quote_triple', 'prereqs': ['recall_inner_quote_pair']},
  \ {'id': 'delete_to_word_start_forward_backward', 'prereqs': ['move_to_word_start_forward_backward']},
  \ {'id': 'delete_to_line_edges_beginning_end',   'prereqs': ['move_to_line_edges_beginning_end']},
  \ {'id': 'delete_single_char_left_right',        'prereqs': ['move_single_char_left_right']},
  \ {'id': 'delete_two_lines_down_up',             'prereqs': ['move_single_char_up_down']},
  \ ]

let s:registry = vimfluency#discover_pinpoints()

for s:e in s:expected
  let s:prefix = 'meta[' . s:e.id . ']: '
  call Assert(has_key(s:registry, s:e.id),
    \ s:prefix . 'pinpoint discovered by runtime')
  if !has_key(s:registry, s:e.id) | continue | endif
  let s:m = s:registry[s:e.id]
  call Assert(has_key(s:m, 'id'),           s:prefix . 'has id')
  call Assert(has_key(s:m, 'name'),         s:prefix . 'has name')
  call Assert(has_key(s:m, 'aim'),          s:prefix . 'has aim')
  call Assert(has_key(s:m, 'allowed_keys'), s:prefix . 'has allowed_keys')
  call Assert(has_key(s:m, 'prereqs'),      s:prefix . 'has prereqs')
  call Assert(has_key(s:m, 'family'),       s:prefix . 'has family')
  if has_key(s:m, 'prereqs')
    call Assert(type(s:m.prereqs) == v:t_list,
      \ s:prefix . 'prereqs is a list')
    call AssertEq(s:m.prereqs, s:e.prereqs,
      \ s:prefix . 'prereqs match expected')
  endif
endfor
