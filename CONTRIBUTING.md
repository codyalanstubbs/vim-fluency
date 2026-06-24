# Contributing

Vim Fluency accepts drill contributions, bug fixes, and doc
improvements. Drills are the interesting one — they have a review
gate that most projects don't, so read this before writing code.

(A drill targets one precisely specified behavior — what Precision
Teaching calls a *pinpoint*. This project used that term internally
before standardizing on "drill"; it survives only in the legacy
`pinpoint_id` / `pinpoint_name` fields of old session-log lines, still
read for back-compat.)

## The cheat-analysis gate

Every training item a drill generates must make the **intended
motion the strictly shortest path** to the target. Not "a reasonable
path" — the strictly shortest one. If a learner can reach the target
with fewer or equally many keystrokes using a *different* motion, the
drill silently trains the wrong behavior and its measurements lie.

So every drill starts with a **cheat analysis**: enumerate what a
learner could press *instead* of the intended motion, then constrain
the generated content (alphabet, line layout, target distance, start
position) until every alternative is strictly longer. The analysis is
documented as a comment block at the top of the drill file.

**This is a merge gate, not a suggestion.** A drill whose intended
motion isn't strictly shortest doesn't get merged — the content gets
revised until it is, or the drill is rejected. Reviewers will probe
your generated items with alternative motions. Visual aesthetics are
negotiable (some defended alphabets look like soup — intentionally);
drill integrity is not.

Worked examples to study before writing your own:

- `autoload/vimfluency/drills/move_single_char_up_down_left_right.vim`
- `autoload/vimfluency/drills/move_to_word_start_forward_backward.vim`
- `autoload/vimfluency/drills/visual_select_single_char_left_right.vim`

## Drill contribution flow

1. **Proposal issue first.** Open a "Drill proposal" issue (there's
   a template). It captures the proposed slug, the behavior trained,
   prereqs, why it isn't redundant with the existing catalog, and a
   draft cheat analysis. Settle the design in the issue before writing
   code — cheap to revise there, expensive in a PR.
2. **Cheat-analysis review** happens in the issue. Expect concrete
   counterexamples ("from this start position, `fx` beats your
   intended `3w`").
3. **Implementation PR** once the analysis holds. See the checklist
   below (it's also the PR template).

## Implementation requirements

A drill is one file: `autoload/vimfluency/drills/<slug>.vim`.
The slug is descriptive snake_case starting with a letter
(`move_single_char_left_right`, `save_vs_quit`) — it's both the
filename minus `.vim` and what users type after `:VfTrain`.

- `meta()` returns `id` (= the slug), `name`, `aim`, `family`,
  `keys` (slash-separated display string of the drilled keystrokes,
  e.g. `'dl/dh'`), `prereqs`, `allowed_keys` (advisory documentation
  only — the runner doesn't enforce it), `test_sequence`, and `kind`
  for non-motion drills (`editing`, `recall`, `mode`, `mode_switch`,
  `command`, `visual_motion` — see `:help vf-kinds`; omit for the
  default cursor-only `motion` kind). See `:help vf-drills`.
- `generate()` returns one item including `expected_motion` (the
  canonical answer) and `optimal_motions` (expert keystroke count) —
  per-motion measurement depends on both being right.
- `lesson()` if the motion needs teaching (most do). Every motion
  introduction gets a `try` frame — learners must perform the motion,
  not read about it.
- **Aim is a starting guess.** Don't agonize over the number and don't
  claim calibration; aims get revised from community data, not
  intuition.
- Property tests in `tests/test_generators.vim` covering the
  `optimal_motions` formula and the `expected_motion` set.
- `make test` passes — it runs the full CI equivalent (vim suite +
  CATALOG freshness + nvim suite + live-nvim smoke). `make help` lists
  the narrower targets (`test-vim`, `test-nvim`, `smoke`, `catalog`).
  The live `smoke_nvim.sh` auto-skips without Neovim, so run it (or
  `make test`) where nvim is installed before pushing UI changes.

## Code constraints

- **Vim 8.1 baseline** (with `rand()`, patch 8.1.2342). No
  Neovim-only features, no Lua, no vimscript9 — the plugin must run on
  a stock vim install with no dependencies, and the same legacy-vimscript
  baseline is what makes Neovim support free.
- Watch for functions newer than 8.1 sneaking in (`reduce()`,
  `matchfuzzy()`, Floats in `min()`/`max()` — that last one needs 9.1
  and has bitten this codebase before).
- Match the surrounding code's style and comment density.

## Gotcha: drills that delete whole lines

`dd` and other line-removing operators (`dG`, multi-line visual delete)
behave differently in the standalone training buffer (no header rows) vs.
the lesson buffer (header rows above the content). In the training buffer,
vim's "buffer can't be empty" rule preserves a deleted-only-line as `''`,
so `target_lines: ['']` works. In the lesson buffer the same operation
removes the line entirely — the header rows above it already satisfy vim's
minimum-one-line rule — leaving zero content rows, so the target check
never matches and the frame never advances.

Work around it the way `delete_char_vs_line.vim` does: use a 2-line buffer
so any `dd` leaves a survivor line that satisfies the target check in
either context. Any new drill that deletes entire lines should follow the
same pattern.

## Renaming a drill slug

Slugs are user data — they're typed into `:VfTrain` and stored as
`drill_id` in every session-log record. To rename one:

1. `git mv` the file to the new slug.
2. Update the three `vimfluency#drills#<slug>#` function names and the
   `id` in `meta()`.
3. Update every in-repo reference: `prereqs` / `parallel_to` /
   `narrower_of` in sibling drills, any paths files, and tests.
4. Add an old → new entry to `s:LEGACY_IDS` in `autoload/vimfluency.vim`.
   The alias map canonicalizes old ids at every read path (commands,
   session log, aim overrides) so user history survives. **Never rewrite
   the JSONL log itself.** Aliasing tests live at the bottom of
   `tests/test_settings.vim`.
5. Regenerate the catalog: `./scripts/gen-catalog.sh` (it's generated from
   drill metadata — see below).

## The catalog is generated

`CATALOG.md` is produced from each drill's `meta()` by
`./scripts/gen-catalog.sh` — don't edit it by hand. Run that script after
adding, removing, or changing a drill; CI fails if the committed copy is
stale. The live, always-current index is `:VfList`.

## Bug fixes and docs

Normal PRs, no proposal needed. For runner changes, note that
`tests/test_runner.vim` drives the state machine via `cursor()` +
`doautocmd` because `-Es` batch mode has no event loop — new runner
behavior should come with coverage there or in `smoke_nvim.sh`.

## What contributors get

Attribution in the drill file header, your drill's rate
distributions on the public dashboard once community data exists, and
credit on the vimfluency.com contributors page. Not money — honestly,
from day one. If that ever changes, the structure will be designed
with contributors, not surprised on them.

## Licensing

MIT. By submitting a contribution you agree it's licensed under the
project's MIT license (inbound = outbound). No CLA.
