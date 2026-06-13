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
filename minus `.vim` and what users type after `:Vf`.

- `meta()` returns `id` (= the slug), `name`, `aim`, `family`,
  `prereqs`, `allowed_keys` (advisory documentation only — the runner
  doesn't enforce it), and `test_sequence`. See `:help vf-drills`.
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
- `./tests/run.sh` passes. If you have Neovim, `./tests/smoke_nvim.sh`
  too.

## Code constraints

- **Vim 8.1 baseline** (with `rand()`, patch 8.1.2342). No
  Neovim-only features, no Lua, no vimscript9 — the plugin must run on
  every server you ssh into, and the same legacy-vimscript baseline is
  what makes Neovim support free.
- Watch for functions newer than 8.1 sneaking in (`reduce()`,
  `matchfuzzy()`, Floats in `min()`/`max()` — that last one needs 9.1
  and has bitten this codebase before).
- Match the surrounding code's style and comment density.

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
