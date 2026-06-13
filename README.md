# Vim Fluency

A vim plugin for behavioral-fluency training sessions on vim drills. Runs inside vim itself — no simulator divergence, you're using real vim. Project home: vimfluency.com.

## Install

Manual:
```vim
" in your vimrc
set runtimepath+=/path/to/vim-fluency
```

Plugin manager (vim-plug example):
```vim
Plug '/path/to/vim-fluency'
```

For the "every server" use case: `scp -r vim-fluency/ user@host:~/.vim/pack/vimfluency/start/vimfluency/` and it's installed.

## Use

```
:VfDashboard                            " home view: drill table, charts, last session
:VfList                                 " flat table of installed drills
:VfLearn move_to_char_forward_backward  " DI-style lesson, hands off to training
:Vf move_single_char_up_down_left_right       " 60-second training
:Vf move_single_char_up_down_left_right 30    " 30 seconds
:Vf move_to_line_edges_all only=g_,^    " drill only the listed motions
:VfQuit                                 " end early; session logged
:VfHistory                              " prior sessions with rate bars
:VfChart {id}                           " progress chart (a Standard Celeration Chart)
:VfChartZoom {id}                       " same, zoomed to one decade
```

Settings commands: `:VfSetAim` / `:VfResetAim` (per-drill aim override),
`:VfSetDuration` / `:VfResetDuration` (global default duration),
`:VfSetPath` / `:VfResetPath` / `:VfPaths` (curated learning paths).
`:help vimfluency` documents all of them.

Tab skips the current item. Sessions open their own tab page and end by
landing on the just-trained drill in `:VfDashboard`.

## How it works

A training opens a new tab with a single buffer. The target cell is highlighted in green directly in that buffer; your cursor moves through it normally. Autocommands on `CursorMoved`/`TextChanged` watch the buffer; when (line content, cursor position) matches the target, the item is logged correct and the next item loads.

Because it's real vim, every keystroke is interpreted natively — no need to maintain a parallel command dispatcher.

Beyond cursor-only motion drills, drills declare a `kind` for other
behaviors: `editing` (operators like `x`, `dd`, `dw` — credit when the buffer
matches the post-edit state), `mode` (round-trip through insert),
`mode_switch` (mode changes), `command` (Ex/normal commands like `:wq` vs
`ZZ`, captured without executing), `recall` (type the answer), and
`visual_motion` (visual selections like `vh`/`vj`). See `:help vf-kinds`.

## Measurement

Every item is labeled with its canonical motion and an optimal motion count.
The runner tracks per-motion rates, total vs. optimal motions, and wasted
motions (the progress chart's errors line). End-of-session stats land in
the dashboard's LAST SESSION pane; `:VfChart` plots corrects and errors per
session against the aim.

## Logs

JSONL appended to `$XDG_DATA_HOME/vimfluency/sessions.jsonl` (or `~/.local/share/vimfluency/sessions.jsonl`). One line per session, including per-motion stats and the full item log. `:VfHistory` and `:VfChart` read from it; so can `jq`.

## Adding a drill

A drill targets one precisely specified behavior — what Precision Teaching calls a *pinpoint* (the term this project used internally before standardizing on "drill"). See `:help vf-drills` or copy `autoload/vimfluency/drills/move_single_char_up_down_left_right.vim` as a template. `meta()` returns the drill metadata; `generate()` returns one item; an optional `lesson()` defines the `:VfLearn` walkthrough. 41 drills shipped across the survival, motion, visual, delete, indent, and recall families — `CATALOG.md` is the shipped index.

## Limits

- **No raw keystroke counting.** Vim's autocmds fire post-aggregate (`5w` is one event), so the motion counts measure commands, not individual key presses. Stroke counts shown in breakdowns are derived from the command string.
- **No input restriction.** A drill declares `allowed_keys` in its metadata, but the plugin doesn't remap forbidden keys. Honest measurement of what the user does. Can be added as opt-in later.
- **Vim 8.1+** (with `rand()`, patch 8.1.2342) or **Neovim** required. The plugin is deliberately written in conservative legacy vimscript so it runs on every server you ssh into; the same baseline runs on Neovim unmodified (test suite and interactive use verified on nvim 0.11).
