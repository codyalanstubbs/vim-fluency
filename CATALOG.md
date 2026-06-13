# Vim Drill Catalog

Drills currently shipped, grouped by **family**. (Internally a drill
is called a "pinpoint" — the Precision Teaching term for a precisely
specified behavior to measure.) The actual behavioral hierarchy lives
in each drill's `prereqs` list; this catalog is the flat index. Use
`:VfList` to see status (rate, aim); press `B` on any row for a
breakdown that lists every prereq with its own met/unmet status.

Forward-looking spec rows (drills under design but not yet built)
live in `.strategy/catalog-v2/` slice documents, not here. This file
is the source of truth for *what's actually shipped*.

## Conventions

- **id (slug)** — the identifier a user types into `:Vf <id>` /
  `:VfLearn <id>` / `:VfChart <id>`. Slugs are descriptive snake_case
  (e.g. `move_single_char_left_right`). Tab-completion in `:Vf` works.
- **Training format** — what the learner sees and produces:
  - `S→K` — show before/after state; learner types minimal keystrokes
  - `K→S` — show keystrokes; learner predicts state
  - `Disc` — discrimination: pick the more efficient of two paths
  - `Recall` — name the keystroke that does X
  - `Mode` — round-trip through insert/visual/etc.
- **Aim** — starting guess for fluency rate (correct/min). Will be
  replaced by community-aggregated rates per
  `.strategy/data-contribution.md`.
- **Prereqs** — specific drill slugs that suggest fallbacks when a
  rate plateaus. **Diagnostic, not gating.** A learner can train any
  drill at any time; press `B` on its `:VfList` row to see each
  prereq's met/unmet status.
- **Family** — verb-family or functional grouping (`survival`,
  `motion`, `delete`, `change`, `yank`, `paste`, `v`, `indent`, etc.).
  Used by `:VfList` to group drills visually.

## Survival family

| id (slug) | Behavior | Format | Aim | Prereqs |
|---|---|---|---|---|
| `switch_mode_to_insert` | 2-cell: enter INSERT (`i`) or return to Normal (`Ctrl+[` / `Esc`) | Mode | 80 | — |
| `switch_mode_to_visual` | 2-cell: enter VISUAL (`v`) or return to Normal (`Ctrl+[` / `Esc`) | Mode | 80 | — |
| `switch_mode_to_replace` | 2-cell: enter REPLACE (`R`, capital) or return to Normal (`Ctrl+[` / `Esc`) | Mode | 80 | — |
| `switch_mode_to_command_line` | 2-cell: enter COMMAND (`:`) or return to Normal (`Ctrl+[` / `Esc`) | Mode | 80 | — |
| `switch_btwn_many_modes` | Composite: strict alternation between Normal and the four non-Normal modes; each item is one stroke (entry key or `Ctrl+[`) | Mode | 70 | `switch_mode_to_insert`, `switch_mode_to_visual`, `switch_mode_to_replace`, `switch_mode_to_command_line` |
| `insert_before_after_char` | 2-cell: `i` (insert before cursor) vs `a` (append after cursor) — type a short payload at the marked gap | Mode | 60 | — |
| `insert_start_end_line` | 2-cell: `I` (insert at first non-blank) vs `A` (append at end of line) — type a short payload at the marked gap | Mode | 60 | — |
| `insert_before_after_char_start_end_line` | 4-way composite over `i`, `a`, `I`, `A` — type a short payload at the marked gap | Mode | 50 | `insert_before_after_char`, `insert_start_end_line` |
| `insert_line_above_below` | Open new line (`o`, `O`) — type a short payload on the new line | Mode | 40 | — |
| `save_vs_quit` | Discriminate `:w` vs `:q` | Disc | 40 | — |
| `save_quit_vs_force_quit` | Discriminate `:wq` vs `:q!` | Disc | 35 | — |
| `save_quit_ex_vs_normal_zz` | Discriminate `:wq` vs `ZZ` (Ex vs normal-mode) | Disc | 35 | — |
| `force_quit_ex_vs_normal_zq` | Discriminate `:q!` vs `ZQ` (Ex vs normal-mode) | Disc | 35 | — |
| `undo_redo` | Undo / redo (`u`, `Ctrl-r`) | S→K | 50 | — |

## Motion family

Cursor-only behaviors. No buffer change.

| id (slug) | Behavior | Format | Aim | Prereqs |
|---|---|---|---|---|
| `move_single_char_up_down_left_right` | `hjkl` (4-direction) | S→K | 60 | `move_single_char_left_right`, `move_single_char_up_down` |
| `move_single_char_left_right` | `h l` (narrower horizontal sibling of hjkl) | S→K | 60 | — |
| `move_single_char_up_down` | `j k` (narrower vertical sibling of hjkl) | S→K | 60 | — |
| `move_to_line_edges_all` | Line start / first-non-blank / end (`0`, `^`, `$`, `g_`) | S→K | 50 | `move_to_line_edges_beginning_end`, `move_to_line_edges_non_white_space` |
| `move_to_line_edges_beginning_end` | 2-cell: `0` (line start) vs `$` (line end). No whitespace axis. | S→K | 55 | — |
| `move_to_line_edges_non_white_space` | 2-cell: `^` (first non-blank) vs `g_` (last non-blank). Whitespace-edge sibling. | S→K | 55 | — |
| `move_to_word_start_forward_backward` | `w b` | S→K | 45 | — |
| `move_to_word_end_forward_backward` | `e ge` | S→K | 40 | — |
| `move_to_char_forward_backward` | `f{c} F{c}` | S→K | 50 | `move_single_char_up_down_left_right` |
| `move_till_char_forward_backward` | `t{c} T{c}` | S→K | 45 | `move_to_char_forward_backward` |
| `move_repeat_last_find_forward_backward` | Repeat last find (`;`, `,`) | S→K | 40 | `move_to_char_forward_backward`, `move_till_char_forward_backward` |
| `move_to_till_forward` | 2-cell: `f{c}` (lands ON next c) vs `t{c}` (lands ONE BEFORE next c) | S→K | 50 | — |
| `move_to_till_backward` | 2-cell: `F{c}` (lands ON previous c) vs `T{c}` (lands ONE AFTER previous c) | S→K | 50 | — |
| `move_to_till_forward_in_words` | 2-cell: `f{c}` vs `t{c}` over word-shaped content (varying skim span) | S→K | 40 | `move_to_till_forward` |
| `move_to_till_backward_in_words` | 2-cell: `F{c}` vs `T{c}` over word-shaped content (varying skim span) | S→K | 40 | `move_to_till_backward` |
| `move_to_till_forward_backward` | 4-way composite over `f`, `F`, `t`, `T` | Disc | 35 | `move_to_char_forward_backward`, `move_till_char_forward_backward`, `move_to_till_forward`, `move_to_till_backward` |

## Visual family

Charwise visual-mode selection behaviors (`v` + motion). Cursor-only
in effect — the buffer doesn't change; credit requires being in the
right visual sub-mode with the expected anchor + endpoint.

| id (slug) | Behavior | Format | Aim | Prereqs |
|---|---|---|---|---|
| `visual_select_single_char_up_down_left_right` | `vh vj vk vl` — extend selection one cell (4-direction) | S→K | 50 | `visual_select_single_char_left_right`, `visual_select_single_char_up_down` |
| `visual_select_single_char_left_right` | `vh vl` (narrower horizontal sibling) | S→K | 50 | `switch_mode_to_visual`, `move_single_char_left_right` |
| `visual_select_single_char_up_down` | `vj vk` (narrower vertical sibling) | S→K | 50 | `switch_mode_to_visual`, `move_single_char_up_down` |

## Delete family

Buffer-changing behaviors using the `d` operator. Slice-01 is the
foundational layer; more cells (`de/dge`, the composite-discrimination
broader drills) are designed but not yet built — see
`.strategy/catalog-v2/slice-01-char-motions-and-simple-deletes.md`.

| id (slug) | Behavior | Format | Aim | Prereqs |
|---|---|---|---|---|
| `delete_char_vs_line` | `x` vs `dd` (navigate then operate) | Disc | 35 | — |
| `delete_to_word_start_forward_backward` | `dw db` (delete to word start, both directions) | Disc | 60 | `move_to_word_start_forward_backward` |
| `delete_to_line_edges_beginning_end` | `d0 d$` (delete to line edge, both directions) | Disc | 35 | `move_to_line_edges_beginning_end` |
| `delete_single_char_left_right` | `dl dh` (delete one char via motion) | Disc | 40 | `move_single_char_left_right` |
| `delete_two_lines_down_up` | `dj dk` (linewise, two-line extent) | Disc | 30 | `move_single_char_up_down` |

## Indent family

| id (slug) | Behavior | Format | Aim | Prereqs |
|---|---|---|---|---|
| `indent_vs_dedent` | `>>` vs `<<` | Disc | 35 | — |

## Text-object recall (legacy)

These two are the May 14 recall-discrimination variants for inner
quote text objects. The runner's `visual_motion` kind now exists;
these will be **replaced** when slice-02 ships the proper `vi"`-style
behaviors. See
`.strategy/catalog-v2/slice-02-quote-text-objects.md` for the
post-pivot spec.

| id (slug) | Behavior | Format | Aim | Prereqs |
|---|---|---|---|---|
| `recall_inner_quote_pair` | Recall `i"` vs `i'` from buffer cue | Recall | 40 | — |
| `recall_inner_quote_triple` | Adds `` i` `` (backtick) | Recall | 35 | `recall_inner_quote_pair` |

## Forward-looking work

Active design (under exhaustive-hierarchy framework):

- `.strategy/catalog-v2/verb-families.md` — names verb families (`v`,
  `d`, `c`, `y`, `p`) as the catalog's organizing principle.
- `.strategy/catalog-v2/slice-01-char-motions-and-simple-deletes.md`
  — the d-family foundational layer (this catalog ships the trained
  subset).
- `.strategy/catalog-v2/slice-02-quote-text-objects.md` — multi-family
  text-object cells across `v/d/c/y`.

Planned families (per `verb-families.md`):
- `V` — linewise visual extension (`V/Vj/Vk`, mixed; the charwise
  `vh/vl/vj/vk` foundation is shipped — see Visual family above)
- `c` — change family (mirrors `d` shape + insert-mode exit)
- `y` — yank family (mirrors `d` shape, buffer unchanged)
- `p` — paste family (`p/P`, `gp/gP`, `]p/]P`, count-prefix)
- register cross-cutting axis (`"a`, `"_`, `"+` prefixes on d/y/p)

Each drill's `prereqs` list defines what unlocks what; `:VfList`
surfaces unmet prereqs per row.
