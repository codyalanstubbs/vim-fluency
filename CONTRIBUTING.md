# Contributing

Right now the contribution that helps most is a **good bug report**.
Vim Fluency is early, driven by one maintainer, and the priority is
making the existing drills and runner solid rather than growing the
catalog. Bug fixes and doc improvements are welcome as PRs; new drills
are not open for outside contribution at this time (see
[Drills](#drills) below).

## Reporting bugs

Open an issue. A report I can act on quickly includes:

- **Vim or Neovim, and the version** (`:version` / `nvim --version`).
  The plugin targets a Vim 8.1 baseline and runs on Neovim too, so which
  one you hit it on matters.
- **What you ran** — the exact `:VfTrain` / `:VfLearn` / `:Vf…` command,
  including any `only=…` arguments.
- **What happened vs. what you expected**, with the on-screen text or a
  screenshot. For a stuck lesson or training, the frame it stuck on.
- **Whether it reproduces from a clean state** — ideally with a minimal
  `vimrc` (`vim -u NONE` plus just this plugin), so we can rule out a
  conflict with your config.

A wrong-but-honest measurement is a real bug here: if a drill credits a
motion it shouldn't (or won't credit one it should), that corrupts the
data the whole tool is built on. Those reports are especially valuable.

## Bug fixes and docs

Normal PRs, no proposal needed. For runner changes, note that
`tests/test_runner.vim` drives the state machine via `cursor()` +
`doautocmd` because `-Es` batch mode has no event loop — new runner
behavior should come with coverage there or in `smoke_nvim.sh`. Run
`make test` (the full CI equivalent) before opening the PR; `make help`
lists the narrower targets.

Keep to the **Vim 8.1 baseline** — no Neovim-only features, no Lua, no
vimscript9. Match the surrounding code's style and comment density.

## Drills

External drill contributions aren't open at this time. A drill carries a
strict cheat-analysis review gate — the intended motion must be the
*strictly shortest path* to the target on every generated item — and
staffing that review for outside PRs isn't something I can do right now.

If you're curious what the bar looks like, it's all written up in
[`DRILL.md`](DRILL.md): the drill contract, the cheat-analysis gate, the
buffer-shape gotchas, and the add/rename checklists. If this changes,
this page will say so.

## Licensing

MIT. By submitting a contribution you agree it's licensed under the
project's MIT license (inbound = outbound). No CLA.
