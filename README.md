# Vim Fluency

A vim plugin for behavioral-fluency training sessions on vim drills. Runs inside vim itself — no simulator divergence, you're using real vim. Project home: vimfluency.com.

## What is behavioral fluency?

Fluency is accuracy *plus* speed: a behavior you perform correctly, quickly, and without deliberation — available while your attention is on the code, not on the keystroke. It's a different axis from knowing. You can know exactly what `dw` does and still reach for it slowly; the motion isn't fluent until it's automatic under time pressure.

That distinction comes from Precision Teaching (Lindsley / Morningside Academy), which measures learning as a *rate* — correct responses per minute — instead of whether you can do something once. A fluency *aim* is the rate above which a skill turns durable and stays available under distraction. A Vim Fluency drill mixes a small set of closely related behaviors — each generated scenario isolates and measures exactly one, so you train in a realistic but tightly controlled environment rather than rehearsing a single key in isolation. It tracks your real per-motion rate and charts it against an aim, so you can tell the motions you've genuinely made automatic from the ones you only think you have.

## Install

Plugin manager (vim-plug):
```vim
Plug 'codyalanstubbs/vim-fluency'
```

lazy.nvim:
```lua
{ 'codyalanstubbs/vim-fluency' }
```

Without a plugin manager, clone into a pack dir:
```sh
git clone https://github.com/codyalanstubbs/vim-fluency \
  ~/.vim/pack/vimfluency/start/vimfluency
```

## Use

`:Vf` opens the dashboard (home — browse drills, launch from a row); `:VfTrain {id}` runs a timed session directly.

```
:Vf                                     " home view: drill table, charts, last session
:VfList                                 " flat table (path-filtered, like :Vf)
:VfLearn move_to_char_forward_backward  " DI-style lesson, ends on the shared end screen
:VfTrain move_single_char_up_down_left_right     " 60-second training
:VfTrain move_single_char_up_down_left_right 30  " 30 seconds
:VfTrain move_to_line_edges_all only=g_,^        " train only the listed motions
:VfQuit                                 " end early; session logged
:VfHistory                              " prior sessions with rate bars
:VfChart {id}                           " progress chart (a Standard Celeration Chart)
```

Settings commands: `:VfSetAim` / `:VfResetAim` (per-drill aim override),
`:VfSetDuration` / `:VfResetDuration` (global default duration),
`:VfSetPath` / `:VfResetPath` / `:VfPaths` (curated learning paths).
`:help vimfluency` documents all of them.

Tab skips the current item. Both `:VfTrain` and `:VfLearn` open their own
tab page and finish on the same end screen — the drill's last-session
rate and per-command breakdown, plus a one-key menu to anywhere else
(`T`rain, `L`earn, `C`hart, `I`=list, `V`=dashboard, `Q`=quit). Every
read-only view links to every other with those same keys, so once you've
typed `:Vf` or `:VfList` you can loop through trainings, lessons, and
charts without retyping a command.

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
motions (the progress chart's errors line). End-of-session stats show on
the shared end screen and in the dashboard's LAST SESSION pane; `:VfChart`
plots corrects and errors per session against the aim.

## Logs

JSONL appended to `$XDG_DATA_HOME/vimfluency/sessions.jsonl` (or `~/.local/share/vimfluency/sessions.jsonl`). One line per session, including per-motion stats and the full item log. `:VfHistory` and `:VfChart` read from it; so can `jq`.

## Adding a drill

A drill targets one precisely specified behavior — what Precision Teaching calls a *pinpoint* (the term this project used internally before standardizing on "drill"). See `:help vf-drills` or copy `autoload/vimfluency/drills/move_single_char_up_down_left_right.vim` as a template. `meta()` returns the drill metadata; `generate()` returns one item; an optional `lesson()` defines the `:VfLearn` walkthrough. Drills ship across the survival, motion, visual, delete, and indent families — `CATALOG.md` is the shipped index (generated from drill metadata), and `:VfList` shows them live in-editor.

## Limits

- **No raw keystroke counting.** Vim's autocmds fire post-aggregate (`5w` is one event), so the motion counts measure commands, not individual key presses. Stroke counts shown in breakdowns are derived from the command string.
- **No input restriction.** A drill declares `allowed_keys` in its metadata, but the plugin doesn't remap forbidden keys. Honest measurement of what the user does. Can be added as opt-in later.
- **Vim 8.1+** (with `rand()`, patch 8.1.2342) or **Neovim** required. The plugin is deliberately written in conservative legacy vimscript with no dependencies, so it runs on a stock vim install and on Neovim unmodified (test suite and interactive use verified on nvim 0.11).
