## What

<!-- One paragraph: what this fixes or changes. Link the bug issue if there is one. -->

Fixes #

## Checklist

- [ ] `make test` passes (or `./tests/run.sh` if you don't have Neovim — the
      live nvim smoke auto-skips without it)
- [ ] For runner changes: new behavior is covered in `tests/test_runner.vim`
      or `tests/smoke_nvim.sh`
- [ ] Vim 8.1 baseline respected — no Neovim-only features, no Lua, nothing
      newer than 8.1 (`:help vf-reqs`)

<!--
New drills aren't open for outside contribution right now — see CONTRIBUTING.md.
If that's changed by the time you read this, the drill authoring spec and its
checklist are in DRILL.md.
-->
