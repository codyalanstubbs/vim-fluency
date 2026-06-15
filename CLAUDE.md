# CLAUDE.md

Context for future Claude sessions on **Vim Fluency** (plugin id `vimfluency`, repo dir `vim-fluency`, project home vimfluency.com). Skim before editing.

## What this is

A vim plugin that runs timed fluency training sessions (`:VfTrain`) and DI-style lessons
(`:VfLearn`) on vim behaviors. The goal is to give aspiring and current vim
users an explicit behavioral hierarchy they can drill, measure their real
per-behavior rates against, and improve those rates over time.

Built on Direct Instruction (Engelmann/Carnine) for lesson design and
Precision Teaching (Lindsley/Morningside) for measurement. The framework's
job here is to ship a useful fluency-building tool — not to validate an
experimental claim. See `.strategy/learnings/2026-05-20-experiment-to-tool.md`
for the framing pivot.

## Vim version

Vim 8.1+. Uses `rand()`, `json_encode()`, `timer_start()`, `keepalt file`. No
Neovim-specific or Lua features — keep to a conservative, dependency-free
baseline that runs on a stock vim install and on Neovim alike.

## File layout

```
plugin/vimfluency.vim                          commands + load guard
autoload/vimfluency.vim                        runner (training + lesson + history + summary)
autoload/vimfluency/drills/<slug>.vim       one file per drill
doc/vimfluency.txt                             :help docs
tests/                                  vim-headless test runner
```

## Drill contract

Each `autoload/vimfluency/drills/<slug>.vim` must export:

- `vimfluency#drills#<slug>#meta()` → `{id, name, aim, allowed_keys, keys, prereqs}`
  (`allowed_keys` is advisory documentation of the intended key set —
  the runner never reads or enforces it, and encodings vary across
  drills; don't build logic on it without normalizing first.
  `keys` is the slash-separated display string of the drilled
  keystrokes, e.g. `'dl/dh'` — the runner reads it for the dashboard
  commands column and command sorting)
- `vimfluency#drills#<slug>#generate()` → `{lines, start, target, expected_motion, optimal_motions}`
- `vimfluency#drills#<slug>#lesson()` → list of show/try frames (optional)

`<slug>` is a descriptive snake_case id (e.g. `move_single_char_left_right`,
`save_vs_quit`). The slug is the filename minus `.vim` and is the
identifier the user types into `:VfTrain <id>`. Slug starts with a letter —
no `p` prefix needed anymore (the old `p<ID>` tier-code names are gone).

**Terminology note:** "drill" is the name everywhere now — directory,
function namespace (`vimfluency#drills#`), JSONL `drill_id`/`drill_name`
fields, UI, and docs. The Precision Teaching term for the behavior a
drill measures is a *pinpoint*; this project used it internally until
it was renamed to "drill" project-wide. The only surviving trace is
the legacy `pinpoint_id`/`pinpoint_name` log fields and the old slugs
in `s:LEGACY_IDS`, both read for back-compat (see `s:rec_id` /
`s:rec_name` and the "Renaming a drill slug" section). Never rewrite
the on-disk log; the field/slug remap happens at read time.

`prereqs` is a list of specific drill slugs that must be at aim before
drilling this one. No group/tier prefix matching — every entry names a
real drill by slug. Under the exhaustive-hierarchy framework, prereqs
are *diagnostic, not gating* — `:VfList` surfaces them as suggestions
("your `delete_to_word_start_forward_backward` rate plateaued; drop back
to `move_to_word_start_forward_backward`") rather than locking the
learner out. A prereq that names a drill not yet in the registry
counts as satisfied (vacuous).

Required `family` field: short identifier (`survival`, `motion`,
`delete`, `change`, `yank`, `paste`, `v`, `indent`, `text-object-recall`,
…) used by `:VfList` to group drills visually. See
[`.strategy/catalog-v2/verb-families.md`](.strategy/catalog-v2/verb-families.md)
for the family taxonomy.

Two optional structural-annotation fields formalize relationships across
drills (used by lessons for cross-reference; no impact on training
behavior):

- `narrower_of: '<id>'` — this drill is a narrower sub-component of
  the named broader drill. Example: `move_single_char_left_right` has
  `narrower_of: 'move_single_char_up_down_left_right'`. The broader form
  is the typical default drill; the narrower form is the fallback for
  learners who plateau on one axis specifically.
- `parallel_to: ['<id>', ...]` — this drill shares rule-statement
  shape and matched lesson structure with the listed peers. Example:
  `move_to_word_start_forward_backward` is parallel-by-design with
  `move_to_word_end_forward_backward`. Used to group related drills
  visually and to let lessons reference their kin.

Both fields default to absent / `[]`. Adding them to a drill is
schema-additive — no runner work required to land them.

## Cheat-analysis discipline

For every new drill, work through what the learner could use *instead* of
the intended motion to reach the target. Adjust content (alphabet, line
layout, target distance, start position) until the intended motion is
**strictly the shortest path**. Document the analysis as comments at the top
of the drill file. See
`autoload/vimfluency/drills/move_single_char_up_down_left_right.vim`
and `move_to_word_start_forward_backward.vim` for worked examples.

Visual aesthetics are negotiable; drill integrity is not. The
`move_to_word_start_forward_backward` vowel-heavy alphabet looks like
soup — that's intentional.

## Buffer-shape gotcha for line-removing operators

`dd` and other line-removing operators (`dG`, multi-line visual delete, etc.)
behave differently in the standalone training buffer (no header rows) vs. the
lesson buffer (header rows above the content). In the training buffer, vim's
"buffer can't be empty" rule preserves a deleted-only-line as `''` — so
`target_lines: ['']` works. In the lesson buffer, the same operation
removes the line entirely because the header rows above it satisfy vim's
minimum-1-line rule, leaving zero content rows. The runner's
`getline(header_offset+1, '$')` returns `[]`, no match against `['']`, the
frame never advances. See `delete_char_vs_line.vim` for a worked-around example: items
use a 2-line buffer so any `dd` leaves a survivor line that satisfies the
target check in either context. Future drills that delete entire lines
should follow the same pattern.

## Per-motion tracking

Every generator labels items with `expected_motion` (the canonical answer)
and `optimal_motions` (keystroke count an expert would use). The runner
accumulates per-motion rate, average actual motions, and total wasted motions
(the SCC "errors" line). Summary shows per-motion breakdown with `← slow` and
`← noisy` markers.

`optimal_motions` formulas in current drills:
- `move_single_char_up_down_left_right`: manhattan distance
- `move_to_line_edges_all`: constant 1
- `move_to_word_start_forward_backward`, `move_to_word_end_forward_backward`:
  `dist` for w/b/ge, `dist + 1` for e (because `e` from start-of-word
  first lands at end of *current* word)

## Lesson DI principles

- **Parallel rule statements**: "X sends cursor to Y" — same shape across all
  motions in the set
- **If there's a motion to demo, use a `try` frame.** Every motion
  introduction — including discrimination/juxtaposition rules like
  "f lands on the first match, not later ones" — gets a try frame so
  the learner sees the cursor jump from their own keystroke. Static
  show frames let the learner read the prompt and skip past without
  ever performing the motion. Reserve `show` only for purely static
  observations where typing nothing genuinely makes the point (e.g.
  "no leading whitespace → 0 and ^ are the same column" — the rule is
  about positions being equal, not about a motion).

- **Show frame schema: `cursor` is required, `highlight` is optional.**
  The cursor block is the default position indicator. If the prompt
  is calling attention to a buffer cell *different* from where the
  cursor sits ("look at column 8 — that's where dd lands the cursor
  on the next line"), add a `highlight: [row, col]` field and the
  runner draws a `VfLearnShow` cell there. Don't put `highlight` at
  the same cell as `cursor` — same-cell highlights are hidden under
  the cursor block and convey no extra information (the runner now
  ignores cursor-coincident highlights by design).

- **Faultless-communication structure (Engelmann/Carnine).** A lesson
  has two phases: **setup** (the static frames returned from
  `lesson()`, where each motion is introduced and named in the
  prompt) followed by an automatic **test phase** (no code change
  needed in the drill — the runner does this for every lesson).
  In the test phase the runner calls the drill's `generate()` to
  produce novel items and shows them with a generic prompt ("Reach
  the target — figure out the motion"). The learner must apply the
  rule without being told the answer. Streak counter advances on
  first-try-correct (motion count ≤ optimal); resets on inefficient
  reach. Each drill declares `test_sequence` in meta — the cycle
  of `expected_motion` values the test phase walks; required streak
  is 3 × len(test_sequence) (3 complete sequences). On reaching the
  streak the runner enters a `complete` phase and shows a
  celebration screen with explicit options: **t** starts `:VfTrain <id>`
  (uses the configured default duration), **q** exits. Space/Enter
  and CursorMoved are no-ops on this screen — the handoff is
  deliberate. On either failure condition — 3 wrong in a row or the
  max_test_items safety cap (scales with sequence length) — the
  runner **restarts the lesson from frame 0 in place**, echoing the
  reason; the tab and autocmds stay put so the learner just keeps
  going. Because test
  items come from the same `generate()` the training uses, their
  cheat-defense is identical — the intended motion is the canonical
  answer.
- **Confirmation step**: when the learner reaches a try frame's target,
  the runner pauses and shows `✓ Press <Space>` in the header instead of
  auto-advancing. This lets them see their motion took effect before the
  next frame loads. (Trainings still auto-advance — the free-operant speed
  loop wants no friction.)
- **Editing kinds get an undo hint**: when meta declares
  `kind: 'editing'`, try-frame headers include `[u=undo if wrong]` so the
  learner knows how to recover from a wrong operator without quitting.
- **Try frames** cover each motion at least once; targets designed so the
  intended motion is the canonical answer
- For whitespace-sensitive motions (`$` vs `g_`), set
  `listchars=trail:·` in the lesson buffer so the difference is observable

See `autoload/vimfluency/drills/move_to_char_forward_backward.vim`
for the active-introduction pattern; `move_to_line_edges_all.vim` for
the whitespace-listchars pattern.

## Buffer naming

- Training: `vf-<id>`
- Lesson: `vf-lesson-<id>`
- List: `vf-list` (data) + `vf-list-header` (sticky header)
- Chart: `vf-chart-<id>` / `vf-chart-zoom-<id>`
- Dashboard: `vf-dashboard-table`, `vf-dashboard-banner`,
  `vf-dashboard-hover`, `vf-dashboard-last-session`

(No standalone summary buffer anymore — sessions end by landing on the
trained drill's row in `:Vf`.)

**Avoid slashes** — vim's `pathshorten()` truncates path-like names when the
tabline is cramped (`vimfluency://summary/1A.1` → `t//s/1A.1`).

## Session logs

JSONL at `$XDG_DATA_HOME/vimfluency/sessions.jsonl` (or
`~/.local/share/vimfluency/sessions.jsonl`). One record per session, including
per-motion stats, errors_per_min, total_motions, total_optimal_motions, and
the full items_log. View with `:VfHistory` or `jq` from the shell.

## Testing

`tests/run.sh` runs assertions vim-headless. Exits non-zero on failure.

When adding a drill, add property tests in `tests/test_generators.vim`
covering its `optimal_motions` formula and `expected_motion` set.

**Note:** `tests/test_runner.vim` is a 9-test runner integration suite.
Because `-Es` batch mode has no event loop, it drives the state machine
via explicit `cursor()` + `doautocmd CursorMoved` rather than `feedkeys`.
Coverage: the 2026-04-30 motion-count regression (deferred autocmd fire
after in-handler `cursor()` inflated counts on every item transition —
a *runner* bug generator tests couldn't catch), free-operant behavior
(wrong motion records but doesn't auto-advance), Tab skip, per-motion
accounting, editing-kind credit, JSONL record shape, per-item event
streams, and the visual_motion mode gate. Caveat: vim's real
deferred-autocmd timing is *simulated* (a manual CursorMoved fire at
item-start position), not exercised natively.

## Adding a new drill (checklist)

1. Create `autoload/vimfluency/drills/<slug>.vim`
2. Define `meta()` with `id`, `name`, `aim` (starting guess), `allowed_keys`
   (advisory only — see the drill contract note), `keys`, `family`,
   `test_sequence`, and `kind`
3. **Cheat analysis first** — document at top of file, then write `generate()`
4. Include `expected_motion` and `optimal_motions` in the returned item
5. Define `lesson()` if the motion needs teaching (most do)
6. Add property tests in `tests/test_generators.vim`
7. Add a row to `CATALOG.md` (it is the shipped index — keep it exhaustive)
8. Run `tests/run.sh`
9. Commit (no `Co-Authored-By: Claude` trailer; see auto-memory for this project)

## Renaming a drill slug

Slugs are user data: they're typed into `:VfTrain` and stored as
`drill_id` in every JSONL session record. To rename one: `git mv`
the file, update the three `vimfluency#drills#<slug>#` function
names and the meta `id`, update every in-repo reference (prereqs /
`parallel_to` / `narrower_of` in sibling drills, paths files,
tests, CATALOG.md), and add an old → new entry to `s:LEGACY_IDS` in
`autoload/vimfluency.vim`. The alias map canonicalizes old ids at
every read path (commands, session log, aim overrides) so user
history survives; never rewrite the JSONL log itself. Tests for the
aliasing live at the bottom of `tests/test_settings.vim`.

## Conventions to remember

- All aim numbers are starting guesses. Calibration against real data is
  part of the actual research, not premature
- Don't pre-create sub-drills for "drill just this motion" — `:VfTrain <id> only=motion[,motion...]` exists for that
- Don't add `Co-Authored-By: Claude` trailers to commits in this project

## Capturing learnings (marketing pipeline)

`.strategy/learnings/` is an append-only log of insights surfaced while
building. The point is to feed the marketing funnel without retroactive
archaeology on `git log` — write the post material at the moment it's
fresh, not months later.

When you spot a content-worthy moment during dev, **propose a draft to
the user before writing it**. Name the pillars and pitch the hook in
plain English. If they agree, copy `.strategy/learnings/TEMPLATE.md`
to `YYYY-MM-DD-slug.md`, fill it in, and add a one-line entry to
`INDEX.md`.

Strong signals worth capturing:
- A training or lesson redesign that exposed a Direct Instruction principle
  (faultless communication, juxtaposition, the discriminant the learner
  actually used vs. the one you intended).
- A user complaint that revealed a wrong mental model in the design.
- A cheat-defense that forced a clever constraint.
- A "we removed feature X because…" decision with a real reason.
- A non-obvious vim observation that working developers would find
  surprising.

Skip routine bug fixes, refactors, and plain feature merges. Bar is
~70% odds the entry yields publishable content within a few months.

Pillars and the funnel position each one feeds are documented in
`.strategy/learnings/PILLARS.md`.
