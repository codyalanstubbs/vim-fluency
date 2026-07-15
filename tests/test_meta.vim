" Property tests over each drill's meta(). Asserts the contract:
" id, name, aim, allowed_keys, prereqs are all present and well-typed.
" The :VfList navigator relies on prereqs to compute eligibility (now
" diagnostic, not gating) — a missing field is a runtime hazard, not
" a cosmetic issue.

let s:expected = [
  \ {'id': 'switch_mode_to_insert', 'prereqs': []},
  \ {'id': 'switch_mode_to_visual', 'prereqs': []},
  \ {'id': 'switch_mode_to_replace', 'prereqs': []},
  \ {'id': 'switch_mode_to_command_line', 'prereqs': []},
  \ {'id': 'switch_between_many_modes',
  \   'prereqs': ['switch_mode_to_insert', 'switch_mode_to_visual',
  \               'switch_mode_to_replace', 'switch_mode_to_command_line']},
  \ {'id': 'insert_before_after_char', 'prereqs': []},
  \ {'id': 'insert_start_end_line', 'prereqs': []},
  \ {'id': 'insert_before_after_char_start_end_line',
  \   'prereqs': ['insert_before_after_char', 'insert_start_end_line']},
  \ {'id': 'insert_line_above_below', 'prereqs': []},
  \ {'id': 'save_vs_quit', 'prereqs': []},
  \ {'id': 'save_quit_vs_force_quit', 'prereqs': []},
  \ {'id': 'save_quit_vs_zz', 'prereqs': []},
  \ {'id': 'force_quit_vs_zq', 'prereqs': []},
  \ {'id': 'undo_redo', 'prereqs': []},
  \ {'id': 'move_single_char_up_down_left_right',
  \   'prereqs': ['move_single_char_left_right', 'move_single_char_up_down']},
  \ {'id': 'move_to_line_edges_all',
  \   'prereqs': ['move_to_line_edges_start_end',
  \               'move_to_line_edges_non_white_space']},
  \ {'id': 'move_single_char_left_right', 'prereqs': []},
  \ {'id': 'move_single_char_up_down', 'prereqs': []},
  \ {'id': 'move_to_line_edges_start_end', 'prereqs': []},
  \ {'id': 'move_to_line_edges_non_white_space', 'prereqs': []},
  \ {'id': 'move_to_word_start_forward_backward', 'prereqs': []},
  \ {'id': 'move_to_word_end_forward_backward', 'prereqs': []},
  \ {'id': 'move_to_file_edges', 'prereqs': ['move_single_char_up_down']},
  \ {'id': 'move_to_char_forward_backward', 'prereqs': ['move_single_char_up_down_left_right']},
  \ {'id': 'move_till_char_forward_backward', 'prereqs': ['move_to_char_forward_backward']},
  \ {'id': 'move_repeat_last_find_forward', 'prereqs': ['move_to_char_forward_backward']},
  \ {'id': 'move_repeat_last_till_forward', 'prereqs': ['move_till_char_forward_backward']},
  \ {'id': 'move_repeat_last_till_backward', 'prereqs': ['move_till_char_forward_backward']},
  \ {'id': 'move_repeat_last_till_forward_backward', 'prereqs': ['move_repeat_last_till_forward', 'move_repeat_last_till_backward']},
  \ {'id': 'move_repeat_last_find_vs_till_forward', 'prereqs': ['move_repeat_last_find_forward', 'move_repeat_last_till_forward']},
  \ {'id': 'move_repeat_last_find_backward', 'prereqs': ['move_to_char_forward_backward']},
  \ {'id': 'move_repeat_last_find_vs_till_backward', 'prereqs': ['move_repeat_last_find_backward', 'move_repeat_last_till_backward']},
  \ {'id': 'move_repeat_last_find_vs_till_forward_backward', 'prereqs': ['move_repeat_last_find_vs_till_forward', 'move_repeat_last_find_vs_till_backward']},
  \ {'id': 'move_repeat_last_find_forward_backward', 'prereqs': ['move_repeat_last_find_forward', 'move_repeat_last_find_backward']},
  \ {'id': 'move_to_vs_till_forward', 'prereqs': []},
  \ {'id': 'move_to_vs_till_backward', 'prereqs': []},
  \ {'id': 'move_to_vs_till_forward_in_words', 'prereqs': ['move_to_vs_till_forward']},
  \ {'id': 'move_to_vs_till_backward_in_words', 'prereqs': ['move_to_vs_till_backward']},
  \ {'id': 'move_to_vs_till_forward_backward',
  \   'prereqs': ['move_to_char_forward_backward',
  \               'move_till_char_forward_backward',
  \               'move_to_vs_till_forward', 'move_to_vs_till_backward']},
  \ {'id': 'delete_char_vs_line', 'prereqs': []},
  \ {'id': 'indent_vs_dedent', 'prereqs': []},
  \ {'id': 'delete_to_word_start_forward_backward', 'prereqs': ['move_to_word_start_forward_backward']},
  \ {'id': 'delete_to_line_edges_start_end',   'prereqs': ['move_to_line_edges_start_end']},
  \ {'id': 'delete_single_char_left_right',        'prereqs': ['move_single_char_left_right']},
  \ {'id': 'delete_two_lines_down_up',             'prereqs': ['move_single_char_up_down']},
  \ {'id': 'visual_select_single_char_left_right',
  \   'prereqs': ['switch_mode_to_visual', 'move_single_char_left_right']},
  \ {'id': 'visual_select_single_char_up_down',
  \   'prereqs': ['switch_mode_to_visual', 'move_single_char_up_down']},
  \ {'id': 'visual_select_single_char_up_down_left_right',
  \   'prereqs': ['visual_select_single_char_left_right',
  \               'visual_select_single_char_up_down']},
  \ ]

let s:registry = vimfluency#discover_drills()

for s:e in s:expected
  let s:prefix = 'meta[' . s:e.id . ']: '
  call Assert(has_key(s:registry, s:e.id),
    \ s:prefix . 'drill discovered by runtime')
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
