<!-- For drill PRs, fill the checklist. For bug fixes / docs, delete it and describe the change. -->

## What

<!-- One paragraph: what this adds or fixes. Link the proposal issue for drills. -->

Proposal issue: #

## Drill checklist

- [ ] Proposal issue exists and the cheat analysis was settled there
- [ ] Cheat analysis documented as a comment block at the top of the drill file
- [ ] `meta()` has `id` (= filename slug), `name`, `aim`, `family`, `prereqs`, `allowed_keys`, `test_sequence`
- [ ] `generate()` items carry `expected_motion` and `optimal_motions`
- [ ] `lesson()` included (or a reason it isn't) — every motion introduction is a `try` frame
- [ ] Property tests in `tests/test_generators.vim` cover the `optimal_motions` formula and the `expected_motion` set
- [ ] `./tests/run.sh` passes
- [ ] `./tests/smoke_nvim.sh` passes (if you have Neovim installed)
- [ ] Vim 8.1 baseline respected — no Neovim-only features, no Lua, nothing newer than 8.1 (`:help vf-reqs`)
- [ ] Aim is a starting guess, not a calibration claim
