# CLAUDE.md

Context for future Claude sessions on **Vim Fluency** (plugin id `vimfluency`, repo dir `vim-fluency`, project home vimfluency.com). Skim before editing.

## What this is

A vim plugin that runs timed fluency probes (`:Vf`) and DI-style lessons
(`:VfLearn`) on vim motion pinpoints. Built on the component → composite →
adduction pipeline from precision teaching and behavioral fluency.

**The thesis being tested:** drilling fluent components (hjkl, line motions,
word motions) to aim should generate composite editing skills *without direct
training*. v1 establishes measurement infrastructure; **adduction is not yet
validated here** — that requires a Tier 4 probe which doesn't exist yet.

## Vim version

Vim 8.1+. Uses `rand()`, `json_encode()`, `timer_start()`, `keepalt file`. No
Neovim-specific or Lua features — must run on every server you ssh into.

## File layout

```
plugin/vimfluency.vim                          commands + load guard
autoload/vimfluency.vim                        runner (probe + lesson + history + summary)
autoload/vimfluency/pinpoints/p<ID>.vim        one file per pinpoint
doc/vimfluency.txt                             :help docs
tests/                                  vim-headless test runner
```

## Pinpoint contract

Each `autoload/vimfluency/pinpoints/p<ID>.vim` must export:

- `vimfluency#pinpoints#p<ID>#meta()` → `{id, name, aim, allowed_keys}`
- `vimfluency#pinpoints#p<ID>#generate()` → `{lines, start, target, expected_motion, optimal_motions}`
- `vimfluency#pinpoints#p<ID>#lesson()` → list of show/try frames (optional)

The leading `p` is required — vim autoload segments can't start with a digit.
`{id}` is a free-form string (e.g. `"1A.2"`).

## Cheat-analysis discipline

For every new pinpoint, work through what the learner could use *instead* of
the intended motion to reach the target. Adjust content (alphabet, line
layout, target distance, start position) until the intended motion is
**strictly the shortest path**. Document the analysis as comments at the top
of the pinpoint file. See `autoload/vimfluency/pinpoints/p1A_1.vim` and `p1B_1.vim`
for worked examples.

Visual aesthetics are negotiable; pinpoint integrity is not. The 1B.1
vowel-heavy alphabet looks like soup — that's intentional.

## Per-motion tracking

Every generator labels items with `expected_motion` (the canonical answer)
and `optimal_motions` (keystroke count an expert would use). The runner
accumulates per-motion rate, average actual motions, and total wasted motions
(the SCC "errors" line). Summary shows per-motion breakdown with `← slow` and
`← noisy` markers.

`optimal_motions` formulas in current pinpoints:
- 1A.1: manhattan distance
- 1A.2: constant 1
- 1B.1: `dist` for w/b/ge, `dist + 1` for e (because `e` from start-of-word
  first lands at end of *current* word)

## Lesson DI principles

- **Parallel rule statements**: "X sends cursor to Y" — same shape across all
  motions in the set
- **One concept per show frame**; separate juxtaposition frames where pairs
  collapse (e.g. "no leading whitespace → 0 and ^ are the same column")
- **Try frames** cover each motion at least once; targets designed so the
  intended motion is the canonical answer
- For whitespace-sensitive motions (`$` vs `g_`), set
  `listchars=trail:·` in the lesson buffer so the difference is observable

See `autoload/vimfluency/pinpoints/p1A_2.vim` for a fully worked example.

## Buffer naming

- Probe: `vf-<id>`
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
