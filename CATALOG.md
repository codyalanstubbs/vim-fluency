# Vim Drill Catalog

> **Generated file — do not edit by hand.** Produced from each
> drill's `meta()` by `scripts/gen-catalog.sh`. Run that script after
> adding or changing a drill; CI checks this copy is fresh.

Drills currently shipped, grouped by family. The live,
always-current view is `:VfList` (with per-drill rate/aim status);
this file is the static snapshot for browsing on GitHub.

## Columns

- **id (slug)** — what you type into `:VfTrain <id>` / `:VfLearn <id>` / `:VfChart <id>`.
- **name** — human-readable label for the trained behavior.
- **keys** — the drilled keystrokes (slash-separated).
- **kind** — training kind (`motion` is the default; others: `editing`, `mode`, `mode_switch`, `command`, `recall`, `visual_motion`). See `:help vf-kinds`.
- **aim** — starting-guess fluency rate (correct/min); revised from community data, not intuition.
- **prereqs** — drill slugs suggested as fallbacks when a rate plateaus. **Diagnostic, not gating** — any drill is trainable at any time.

## Survival

| id (slug) | name | keys | kind | aim | prereqs |
|---|---|---|---|---|---|
| `force_quit_vs_zq` | force quit, Ex vs normal (:q! / ZQ) | `:q!/ZQ` | `command` | 25 | — |
| `insert_before_after_char` | insert before / after char (i / a) | `i/a` | `mode` | 35 | — |
| `insert_before_after_char_start_end_line` | enter insert mode (i / a / I / A) | `i/a/I/A` | `mode` | 25 | `insert_before_after_char`, `insert_start_end_line` |
| `insert_line_above_below` | insert new line above / below (o / O) | `o/O` | `mode` | 30 | — |
| `insert_start_end_line` | insert at line start / end (I / A) | `I/A` | `mode` | 40 | — |
| `save_quit_vs_force_quit` | save & quit vs force quit (:wq / :q!) | `:wq/:q!` | `command` | 35 | — |
| `save_quit_vs_zz` | save & quit, Ex vs normal (:wq / ZZ) | `:wq/ZZ` | `command` | 45 | — |
| `save_vs_quit` | save vs quit (:w / :q) | `:w/:q` | `command` | 55 | — |
| `switch_between_many_modes` | switch between many modes (i v R : Ctrl+[) | `i/v/R/:/C-[` | `mode_switch` | 70 | `switch_mode_to_insert`, `switch_mode_to_visual`, `switch_mode_to_replace`, `switch_mode_to_command_line` |
| `switch_mode_to_command_line` | switch mode to command line (: / Ctrl+[) | `:/C-[` | `mode_switch` | 100 | — |
| `switch_mode_to_insert` | switch mode to insert (i / Ctrl+[) | `i/C-[` | `mode_switch` | 110 | — |
| `switch_mode_to_replace` | switch mode to replace (R / Ctrl+[) | `R/C-[` | `mode_switch` | 90 | — |
| `switch_mode_to_visual` | switch mode to visual (v / Ctrl+[) | `v/C-[` | `mode_switch` | 90 | — |
| `undo_redo` | undo / redo (u / Ctrl-r) | `u/C-r` | `editing` | 80 | — |

## Motions

| id (slug) | name | keys | kind | aim | prereqs |
|---|---|---|---|---|---|
| `move_repeat_last_find_backward` | repeat last find, backward (; ,) | `;/,` | `motion` | 25 | `move_repeat_last_find_forward`, `move_to_char_forward_backward` |
| `move_repeat_last_find_forward` | repeat last find, forward (; ,) | `;/,` | `motion` | 25 | `move_to_char_forward_backward` |
| `move_repeat_last_find_forward_backward` | repeat last find (; ,) | `;/,` | `motion` | 20 | `move_repeat_last_find_forward`, `move_to_char_forward_backward` |
| `move_repeat_last_find_vs_till_backward` | repeat last find vs till, backward (; ,) | `;/,` | `motion` | 20 | `move_repeat_last_find_backward`, `move_repeat_last_till_backward` |
| `move_repeat_last_find_vs_till_forward` | repeat last find vs till, forward (; ,) | `;/,` | `motion` | 20 | `move_repeat_last_find_forward`, `move_repeat_last_till_forward` |
| `move_repeat_last_find_vs_till_forward_backward` | repeat last find/till, all ways (; ,) | `;/,` | `motion` | 20 | `move_repeat_last_find_vs_till_forward`, `move_repeat_last_find_vs_till_backward` |
| `move_repeat_last_till_backward` | repeat last till, backward (; ,) | `;/,` | `motion` | 25 | `move_repeat_last_till_forward`, `move_till_char_forward_backward` |
| `move_repeat_last_till_forward` | repeat last till, forward (; ,) | `;/,` | `motion` | 25 | `move_repeat_last_find_forward`, `move_till_char_forward_backward` |
| `move_repeat_last_till_forward_backward` | repeat last till, both ways (; ,) | `;/,` | `motion` | 20 | `move_repeat_last_till_forward`, `move_repeat_last_till_backward` |
| `move_single_char_left_right` | move one char left / right (h / l) | `h/l` | `motion` | 80 | — |
| `move_single_char_up_down` | move one char down / up (j / k) | `j/k` | `motion` | 90 | — |
| `move_single_char_up_down_left_right` | move one char, 4-way (hjkl) | `h/j/k/l` | `motion` | 60 | `move_single_char_left_right`, `move_single_char_up_down` |
| `move_till_char_forward_backward` | till char (t / T) | `t/T` | `motion` | 25 | `move_to_char_forward_backward` |
| `move_to_char_forward_backward` | find char (f / F) | `f/F` | `motion` | 30 | `move_single_char_up_down_left_right` |
| `move_to_file_edges` | go to file top/bottom (gg G) | `gg/G` | `motion` | 65 | `move_single_char_up_down` |
| `move_to_line_edges_all` | line edges, all (0 ^ $ g_) | `0/^/$/g_` | `motion` | 35 | `move_to_line_edges_start_end`, `move_to_line_edges_non_white_space` |
| `move_to_line_edges_non_white_space` | non-blank line edges (^ / g_) | `^/g_` | `motion` | 50 | — |
| `move_to_line_edges_start_end` | line edges (0 / $) | `0/$` | `motion` | 90 | — |
| `move_to_vs_till_backward` | find vs till, backward (F / T) | `F/T` | `motion` | 20 | — |
| `move_to_vs_till_backward_in_words` | find vs till in words, backward (F / T) | `F/T` | `motion` | 20 | `move_to_vs_till_backward` |
| `move_to_vs_till_forward` | find vs till, forward (f / t) | `f/t` | `motion` | 20 | — |
| `move_to_vs_till_forward_backward` | find vs till, 4-way (f / F / t / T) | `f/F/t/T` | `motion` | 20 | `move_to_char_forward_backward`, `move_till_char_forward_backward`, `move_to_vs_till_forward`, `move_to_vs_till_backward` |
| `move_to_vs_till_forward_in_words` | find vs till in words, forward (f / t) | `f/t` | `motion` | 20 | `move_to_vs_till_forward` |
| `move_to_word_end_forward_backward` | word end forward / backward (e / ge) | `e/ge` | `motion` | 40 | — |
| `move_to_word_start_forward_backward` | word start forward / backward (w / b) | `w/b` | `motion` | 55 | — |

## Visual mode

| id (slug) | name | keys | kind | aim | prereqs |
|---|---|---|---|---|---|
| `visual_select_single_char_left_right` | extend selection left / right (vh / vl) | `vh/vl` | `visual_motion` | 70 | `switch_mode_to_visual`, `move_single_char_left_right` |
| `visual_select_single_char_up_down` | extend selection down / up (vj / vk) | `vj/vk` | `visual_motion` | 65 | `switch_mode_to_visual`, `move_single_char_up_down` |
| `visual_select_single_char_up_down_left_right` | extend selection, 4-way (vh vj vk vl) | `vh/vj/vk/vl` | `visual_motion` | 65 | `visual_select_single_char_left_right`, `visual_select_single_char_up_down` |

## Delete

| id (slug) | name | keys | kind | aim | prereqs |
|---|---|---|---|---|---|
| `delete_char_vs_line` | delete char vs line (x / dd) | `x/dd` | `editing` | 60 | — |
| `delete_inside_around_tag` | delete inside vs around tag (dit / dat) | `dit/dat` | `editing` | 50 | `delete_char_vs_line` |
| `delete_single_char_left_right` | delete one char (dl / dh) | `dl/dh` | `editing` | 55 | `move_single_char_left_right` |
| `delete_to_line_edges_start_end` | delete to line edges (d0 / d$) | `d0/d$` | `editing` | 45 | `move_to_line_edges_start_end` |
| `delete_to_word_start_forward_backward` | delete with word motion (dw / db) | `dw/db` | `editing` | 60 | `move_to_word_start_forward_backward` |
| `delete_two_lines_down_up` | delete two lines (dj / dk) | `dj/dk` | `editing` | 70 | `move_single_char_up_down` |

## Change

| id (slug) | name | keys | kind | aim | prereqs |
|---|---|---|---|---|---|
| `change_inside_around_tag` | change inside vs around tag (cit / cat) | `cit/cat` | `mode` | 35 | `delete_inside_around_tag` |

## Indent

| id (slug) | name | keys | kind | aim | prereqs |
|---|---|---|---|---|---|
| `indent_vs_dedent` | indent vs dedent (>> / <<) | `>>/<<` | `editing` | 50 | — |

_50 drills across 6 families. Regenerate with `scripts/gen-catalog.sh`._
