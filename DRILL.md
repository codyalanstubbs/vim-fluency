# Drill authoring guide

How every `:VfTrain` drill is built and defended, so that all drills
measure what they claim to. This is the canonical spec for the drill
craft — the peer of [`LESSONS.md`](LESSONS.md), which governs the
`:VfLearn` lessons. When you add or edit a drill, follow this; CLAUDE.md
defers here for the details.

A drill targets one precisely specified behavior — what Precision
Teaching calls a *pinpoint*. This project used that term internally
before standardizing on "drill"; it survives only in the legacy
`pinpoint_id` / `pinpoint_name` fields of old session-log lines, still
read for back-compat (see "Renaming a drill slug" below). "Drill" is the
name everywhere else now — directory, the `vimfluency#drills#` function
namespace, the JSONL `drill_id` / `drill_name` fields, the UI, and the
docs.

---

## 1. The drill contract

A drill is one file: `autoload/vimfluency/drills/<slug>.vim`. The slug
is descriptive snake_case starting with a letter
(`move_single_char_left_right`, `save_vs_quit`) — it's both the filename
minus `.vim` and what the user types after `:VfTrain`. (No `p<ID>` tier
prefix — those are gone.)

Each file must export:

- `vimfluency#drills#<slug>#meta()` → `{id, name, aim, allowed_keys, keys, prereqs, family, test_sequence, kind}`
- `vimfluency#drills#<slug>#generate()` → `{lines, start, target, expected_motion, optimal_motions}`
- `vimfluency#drills#<slug>#lesson()` → list of show/try frames (optional; most motions need it)

### meta() fields

- `id` — the slug. Same string as the filename.
- `name` — human-readable display name.
- `aim` — the target rate, a **starting guess**. Don't agonize over it
  and don't claim calibration; aims get revised from real data, not
  intuition.
- `allowed_keys` — advisory documentation of the intended key set. The
  runner never reads or enforces it, and encodings vary across drills;
  don't build logic on it without normalizing first.
- `keys` — the slash-separated display string of the drilled keystrokes,
  e.g. `'dl/dh'`. The runner reads it for the dashboard commands column
  and command sorting.
- `prereqs` — a list of specific drill slugs that should be at aim before
  drilling this one. No group/tier prefix matching — every entry names a
  real drill by slug. Prereqs are **diagnostic, not gating**: `:VfList`
  surfaces them as suggestions ("your `delete_to_word_start_forward_backward`
  rate plateaued; drop back to `move_to_word_start_forward_backward`")
  rather than locking the learner out. A prereq that names a drill not
  yet in the registry counts as satisfied (vacuous).
- `family` — short grouping identifier (`survival`, `motion`, `delete`,
  `change`, `yank`, `paste`, `v`, `indent`, `text-object-recall`, …) used
  by `:VfList` to group drills visually. See
  [`.strategy/catalog-v2/verb-families.md`](.strategy/catalog-v2/verb-families.md)
  for the family taxonomy.
- `test_sequence` — the cycle of `expected_motion` values the lesson's
  test phase walks (see [`LESSONS.md`](LESSONS.md)). Required for any
  drill with a `lesson()`.
- `kind` — the non-motion drill type: `editing`, `recall`, `mode`,
  `mode_switch`, `command`, or `visual_motion` (see `:help vf-kinds`).
  Omit for the default cursor-only `motion` kind.

### Optional structural-annotation fields

Two fields formalize relationships across drills (used by lessons for
cross-reference; no impact on training behavior). Both default to absent
/ `[]`; adding them is schema-additive, no runner work required.

- `narrower_of: '<id>'` — this drill is a narrower sub-component of the
  named broader drill. Example: `move_single_char_left_right` has
  `narrower_of: 'move_single_char_up_down_left_right'`. The broader form
  is the typical default drill; the narrower form is the fallback for
  learners who plateau on one axis specifically.
- `parallel_to: ['<id>', ...]` — this drill shares rule-statement shape
  and matched lesson structure with the listed peers. Example:
  `move_to_word_start_forward_backward` is parallel-by-design with
  `move_to_word_end_forward_backward`. Used to group related drills
  visually and to let lessons reference their kin.

---

## 2. The cheat-analysis gate

Every training item a drill generates must make the **intended motion the
strictly shortest path** to the target. Not "a reasonable path" — the
strictly shortest one. If a learner can reach the target with fewer or
equally many keystrokes using a *different* motion, the drill silently
trains the wrong behavior and its measurements lie.

So every drill starts with a **cheat analysis**: enumerate what a learner
could press *instead* of the intended motion, then constrain the
generated content (alphabet, line layout, target distance, start
position) until every alternative is strictly longer. Document the
analysis as a comment block at the top of the drill file.

**This is a merge gate, not a suggestion.** A drill whose intended motion
isn't strictly shortest doesn't get merged — the content gets revised
until it is, or the drill is rejected. Probe your generated items with
alternative motions ("from this start position, `fx` beats the intended
`3w`"). Visual aesthetics are negotiable; drill integrity is not. The
`move_to_word_start_forward_backward` vowel-heavy alphabet looks like
soup — that's intentional.

Worked examples to study before writing your own:

- `autoload/vimfluency/drills/move_single_char_up_down_left_right.vim`
- `autoload/vimfluency/drills/move_to_word_start_forward_backward.vim`
- `autoload/vimfluency/drills/visual_select_single_char_left_right.vim`

---

## 3. Per-motion measurement

Every item `generate()` returns must label itself with two fields, and
per-motion measurement depends on both being right:

- `expected_motion` — the canonical answer (the intended motion's name).
- `optimal_motions` — the keystroke count an expert would use to reach
  the target.

The runner accumulates per-motion rate, average actual motions, and total
wasted motions (the SCC "errors" line). The summary shows a per-motion
breakdown with `← slow` and `← noisy` markers.

`optimal_motions` formulas in current drills, as worked examples:

- `move_single_char_up_down_left_right`: manhattan distance.
- `move_to_line_edges_all`: constant 1.
- `move_to_word_start_forward_backward`, `move_to_word_end_forward_backward`:
  `dist` for `w`/`b`/`ge`, `dist + 1` for `e` (because `e` from
  start-of-word first lands at the end of the *current* word).

---

## 4. Buffer-shape gotcha: drills that remove whole lines

`dd` and other line-removing operators (`dG`, multi-line visual delete,
etc.) behave differently in the standalone training buffer (no header
rows) vs. the lesson buffer (header rows above the content). In the
training buffer, vim's "buffer can't be empty" rule preserves a
deleted-only-line as `''`, so `target_lines: ['']` works. In the lesson
buffer the same operation removes the line entirely — the header rows
above it already satisfy vim's minimum-one-line rule — leaving zero
content rows. The runner's `getline(header_offset+1, '$')` returns `[]`,
no match against `['']`, and the frame never advances.

Work around it the way `delete_char_vs_line.vim` does: use a 2-line
buffer so any `dd` leaves a survivor line that satisfies the target check
in either context. Any new drill that deletes entire lines should follow
the same pattern.

---

## 5. Buffer-shape gotcha: whole-buffer motions

Same root cause, mirror image. A *whole-buffer* motion (`gg`/`G`, and
file-relative jumps generally) targets the buffer's first/last line — but
the lesson buffer renders the prompt as header rows *above* the content,
so the content's first line is at `header_offset+1`, not buffer line 1.
In the training buffer (`header_offset` 0) `gg`/`G` work; in the lesson
buffer a real `gg` lands on the prompt chrome and the item can never
credit (`G` survives only because the content is the last thing in the
buffer).

The fix is the `fills_buffer` meta flag: when set, the lesson runner
(`s:learn_setup_window`) installs a buffer-local `<expr>` remap of
`gg` → `(header_offset+1)G` — a *real* counted jump so `CursorMoved`
fires through the normal credit path (a `:call cursor()` map moves the
cursor but doesn't trigger the autocmd). `G` needs no remap. See
`move_to_file_edges.vim` (`fills_buffer: 1`) for the worked example; any
future file-level motion drill should set the flag and keep edge content
lines non-indented so the column-1 target matches.

---

## 6. Code constraints

- **Vim 8.1 baseline** (with `rand()`, patch 8.1.2342). No Neovim-only
  features, no Lua, no vimscript9 — the plugin must run on a stock vim
  install with no dependencies, and that same legacy-vimscript baseline
  is what makes Neovim support free.
- Watch for functions newer than 8.1 sneaking in (`reduce()`,
  `matchfuzzy()`, Floats in `min()`/`max()` — that last one needs 9.1 and
  has bitten this codebase before).
- Match the surrounding code's style and comment density.

---

## 7. Adding a new drill (checklist)

1. Create `autoload/vimfluency/drills/<slug>.vim`.
2. Define `meta()` with `id`, `name`, `aim` (starting guess),
   `allowed_keys`, `keys`, `family`, `test_sequence`, and `kind` (§1).
3. **Cheat analysis first** (§2) — document it at the top of the file,
   *then* write `generate()`.
4. Include `expected_motion` and `optimal_motions` in the returned item
   (§3).
5. Define `lesson()` if the motion needs teaching — most do. Follow
   [`LESSONS.md`](LESSONS.md).
6. Add property tests in `tests/test_generators.vim` covering the
   `optimal_motions` formula and the `expected_motion` set.
7. Regenerate the catalog: `./scripts/gen-catalog.sh`. `CATALOG.md` is
   machine-generated from drill `meta()` — never hand-edit it; CI fails
   on a stale copy. The live, always-current index is `:VfList`.
8. Run `tests/run.sh` (or `make test` for the full CI equivalent).
9. Commit (no `Co-Authored-By: Claude` trailer in this project).

---

## 8. Renaming a drill slug

Slugs are user data — they're typed into `:VfTrain` and stored as
`drill_id` in every JSONL session record. To rename one:

1. `git mv` the file to the new slug.
2. Update the three `vimfluency#drills#<slug>#` function names and the
   `id` in `meta()`.
3. Update every in-repo reference: `prereqs` / `parallel_to` /
   `narrower_of` in sibling drills, any paths files, and tests.
4. Add an old → new entry to `s:LEGACY_IDS` in
   `autoload/vimfluency.vim`. The alias map canonicalizes old ids at every
   read path (commands, session log, aim overrides) so user history
   survives. **Never rewrite the JSONL log itself** — the field/slug
   remap happens at read time. Aliasing tests live at the bottom of
   `tests/test_settings.vim`.
5. Regenerate the catalog: `./scripts/gen-catalog.sh`.

---

## 9. Conformance checklist (per drill)

- [ ] Cheat-analysis comment block at the top of the file; intended
      motion is the strictly shortest path on every generated item.
- [ ] `meta()` returns `id` (= slug), `name`, `aim`, `keys`, `family`,
      `test_sequence`, plus `kind` for non-motion drills.
- [ ] Each item carries correct `expected_motion` and `optimal_motions`.
- [ ] `lesson()` present if the motion needs teaching, conforming to
      [`LESSONS.md`](LESSONS.md).
- [ ] Property tests in `tests/test_generators.vim` cover the
      `optimal_motions` formula and `expected_motion` set.
- [ ] Line-removing / whole-buffer drills use the §4 / §5 workarounds.
- [ ] Vim 8.1 baseline — no newer functions snuck in.
- [ ] Catalog regenerated; `tests/run.sh` (or `make test`) green.
