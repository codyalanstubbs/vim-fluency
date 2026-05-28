# CLAUDE.md

Context for future Claude sessions on **Vim Fluency** (plugin id `vimfluency`, repo dir `vim-fluency`, project home vimfluency.com). Skim before editing.

## What this is

A vim plugin that runs timed fluency training sessions (`:Vf`) and DI-style lessons
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
Neovim-specific or Lua features — must run on every server you ssh into.

## File layout

```
plugin/vimfluency.vim                          commands + load guard
autoload/vimfluency.vim                        runner (training + lesson + history + summary)
autoload/vimfluency/pinpoints/p<ID>.vim        one file per pinpoint
doc/vimfluency.txt                             :help docs
tests/                                  vim-headless test runner
```

## Pinpoint contract

Each `autoload/vimfluency/pinpoints/p<ID>.vim` must export:

- `vimfluency#pinpoints#p<ID>#meta()` → `{id, name, aim, allowed_keys, prereqs}`
- `vimfluency#pinpoints#p<ID>#generate()` → `{lines, start, target, expected_motion, optimal_motions}`
- `vimfluency#pinpoints#p<ID>#lesson()` → list of show/try frames (optional)

`{id}` is a descriptive snake_case slug (e.g. `move_single_char_left_right`,
`save_vs_quit`). The slug is the filename minus `.vim` and is the
identifier the user types into `:Vf <id>`. Slug starts with a letter —
no `p` prefix needed anymore.

`prereqs` is a list of specific pinpoint slugs that must be at aim before
drilling this one. No group/tier prefix matching — every entry names a
real pinpoint by slug. Under the exhaustive-hierarchy framework, prereqs
are *diagnostic, not gating* — `:VfList` surfaces them as suggestions
("your `delete_to_word_start_forward_backward` rate plateaued; drop back
to `move_to_word_start_forward_backward`") rather than locking the
learner out. A prereq that names a pinpoint not yet in the registry
counts as satisfied (vacuous).

Required `family` field: short identifier (`survival`, `motion`,
`delete`, `change`, `yank`, `paste`, `v`, `indent`, `text-object-recall`,
…) used by `:VfList` to group pinpoints visually. See
[`.strategy/catalog-v2/verb-families.md`](.strategy/catalog-v2/verb-families.md)
for the family taxonomy.

Two optional structural-annotation fields formalize relationships across
pinpoints (used by lessons for cross-reference; no impact on training
behavior):

- `narrower_of: '<id>'` — this pinpoint is a narrower sub-component of
  the named broader pinpoint. Example: `move_single_char_left_right` has
  `narrower_of: 'move_single_char_up_down_left_right'`. The broader form
  is the typical default drill; the narrower form is the fallback for
  learners who plateau on one axis specifically.
- `parallel_to: ['<id>', ...]` — this pinpoint shares rule-statement
  shape and matched lesson structure with the listed peers. Example:
  `move_to_word_start_forward_backward` is parallel-by-design with
  `move_to_word_end_forward_backward`. Used to group related pinpoints
  visually and to let lessons reference their kin.

Both fields default to absent / `[]`. Adding them to a pinpoint is
schema-additive — no runner work required to land them.

## Cheat-analysis discipline

For every new pinpoint, work through what the learner could use *instead* of
the intended motion to reach the target. Adjust content (alphabet, line
layout, target distance, start position) until the intended motion is
**strictly the shortest path**. Document the analysis as comments at the top
of the pinpoint file. See
`autoload/vimfluency/pinpoints/move_single_char_up_down_left_right.vim`
and `move_to_word_start_forward_backward.vim` for worked examples.

Visual aesthetics are negotiable; pinpoint integrity is not. The
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
frame never advances. See `discriminate_delete_char_vs_line.vim` for a worked-around example: items
use a 2-line buffer so any `dd` leaves a survivor line that satisfies the
target check in either context. Future pinpoints that delete entire lines
should follow the same pattern.

## Per-motion tracking

Every generator labels items with `expected_motion` (the canonical answer)
and `optimal_motions` (keystroke count an expert would use). The runner
accumulates per-motion rate, average actual motions, and total wasted motions
(the SCC "errors" line). Summary shows per-motion breakdown with `← slow` and
`← noisy` markers.

`optimal_motions` formulas in current pinpoints:
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
  needed in the pinpoint — the runner does this for every lesson).
  In the test phase the runner calls the pinpoint's `generate()` to
  produce novel items and shows them with a generic prompt ("Reach
  the target — figure out the motion"). The learner must apply the
  rule without being told the answer. Streak counter advances on
  first-try-correct (motion count ≤ optimal); resets on inefficient
  reach. On 3 in a row the runner enters a `complete` phase and
  shows a celebration screen with explicit options: **p** starts
  `:Vf <id>` (60 s training), **q** exits. Space/Enter and CursorMoved
  are no-ops on this screen — the handoff is deliberate. On either
  failure condition — 3 wrong in a row (symmetric with the success
  criterion) or the 20-item safety cap — the runner **restarts the
  lesson from frame 0 in place**, echoing the reason; the tab and
  autocmds stay put so the learner just keeps going. Because test
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

See `autoload/vimfluency/pinpoints/move_to_char_forward_backward.vim`
for the active-introduction pattern; `move_to_line_edges_all.vim` for
the whitespace-listchars pattern.

## Buffer naming

- Training: `vf-<id>`
- Lesson: `vf-lesson-<id>`
- Summary: `vf-summary-<id>`

**Avoid slashes** — vim's `pathshorten()` truncates path-like names when the
tabline is cramped (`vimfluency://summary/1A.1` → `t//s/1A.1`).

## Session logs

JSONL at `$XDG_DATA_HOME/vimfluency/sessions.jsonl` (or
`~/.local/share/vimfluency/sessions.jsonl`). One record per session, including
per-motion stats, errors_per_min, total_motions, total_optimal_motions, and
the full items_log. View with `:VfHistory` or `jq` from the shell.

## Testing

`tests/run.sh` runs assertions vim-headless. Exits non-zero on failure.

When adding a pinpoint, add property tests in `tests/test_generators.vim`
covering its `optimal_motions` formula and `expected_motion` set.

**Note:** current tests cover generators (unit-level). The 2026-04-30
motion-count regression (vim's deferred autocmd fire after in-handler
`cursor()` inflated motion counts on every item transition) was a *runner*
bug — generator tests wouldn't have caught it. A `feedkeys`-based runner
integration test is the natural extension.

## Adding a new pinpoint (checklist)

1. Create `autoload/vimfluency/pinpoints/p<ID>.vim`
2. Define `meta()` with `id`, `name`, `aim` (starting guess), `allowed_keys`
3. **Cheat analysis first** — document at top of file, then write `generate()`
4. Include `expected_motion` and `optimal_motions` in the returned item
5. Define `lesson()` if the motion needs teaching (most do)
6. Add property tests in `tests/test_generators.vim`
7. Run `tests/run.sh`
8. Commit (no `Co-Authored-By: Claude` trailer; see auto-memory for this project)

## Conventions to remember

- All aim numbers are starting guesses. Calibration against real data is
  part of the actual research, not premature
- Don't pre-create sub-pinpoints for "drill just this motion" — `:Vf <id> only=motion[,motion...]` exists for that
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
