# Vim Fluency

A vim plugin for developing fluency using vim.

![The Vim Fluency dashboard — the drill table, the hovered drill's celeration chart, and its last-session per-command breakdown](https://vimfluency.com/assets/hero.png)

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

Open vim in a terminal and type `:Vf` to open the dashboard. Use `j/w` to move
the cursor up and down the table. Place the cursor over a drill and type `L` to
Learn a drill for the first time, `T` to Train (and measure your fluency of)
that drill for a fixed duration, and `C` to chart your progress over time.

Core commands:
```
:Vf           - home view: drill table, charts, last session
:VfList       - flat table (path-filtered, like :Vf)
:VfLearn {id} - DI-style lesson, ends on the shared end screen
:VfTrain {id} - Default-timed training session
:VfChart {id} - progress chart (a Standard Celeration Chart)
:VfQuit       - end early; session logged
```

Settings /help: 
```
:VfPaths          - List the currently available learning paths
:VfSetPath {name} - Set the currently available learning paths
:VfSetDuration 15 - Set the VfTrain session duration to 15s; default is 60s
:help vimfluency  - Documentation for previously listed (and other stuff like VfResetDuration)
```
If you want to try to speed through a learning path or just train a bunch of
drills everyday, then you may want to set a short `VfTrain` duration with
`VfSetDuration`. You can also set the duration by pressing `D` when on `VfList`
or on the `Vf` dashboard.

## A guided tour

### The dashboard (`:Vf`) — your home base

Use the dashboard to  **discover drills**, monitor **consistent overall
effort** , watch a **specific drill's fluency progress** (the hovered drill's
celeration chart), and read a **summary of its last session** (the per-command
breakdown). Whichver drill the cursor is currently gets show in the celeration
chart and in the last session breakdown. The table can be sorted by column by
typing `s{char}` (i.e: `sd` = sort drills).

![The dashboard, panels tracking the selected drill](https://vimfluency.com/assets/dashboard.gif)

### `:VfList` — the quieter catalog

`:VfList` is a simpler version of the dashboard. A flat table of every drill
with its commands, prerequisites, and current rate against aim. Press `B` on a
drill to expand its breakdown — its prereqs and per-command rates — while the
header tracks your progress along the active path. `VfList` is also sortable
like the table on the `Vf` dashboard.

![:VfList with a drill's breakdown expanded](https://vimfluency.com/assets/list.gif)

### `:VfLearn` and `:VfTrain` — learn it, then train it to fluency

**`:VfLearn`** *introduces* a drill: a lesson that introduces at least two vim
behaviors, has you perform them prompted, then tests you on fresh items until
you can apply them unprompted. It can also be a great warmup before doing
`VfTrain` sessions.

![A :VfLearn lesson](https://vimfluency.com/assets/learn.gif)

**`:VfTrain`** is where fluency is *built and measured*: a timed session
against the clock, scored as a rate and logged so you can watch that rate
climb over time.

![A :VfTrain session](https://vimfluency.com/assets/train.gif)

### Paths — focus your effort

A path scopes the catalog to what matters now. **Foundational** is the
survive-and-edit basics every learner starts with; **General** is
everything. `:VfSetPath` switches the active path and every view re-filters
to it, with the header tracking per-path fluency progress. **Specialized
workflow paths are coming soon.**

![Switching from the General path to Foundational](https://vimfluency.com/assets/paths.gif)

### `:VfChart` — the full picture, and a diagnosis

The dashboard's inline chart is squeezed by column spacing; `:VfChart` opens
the same Standard Celeration Chart full-screen, with room to read every
session. It's also a diagnostic. When the `×` error line sits **above** the
`●` correct line — as it does for the stuck drill below — the chart is
telling you you're going too fast: slow down until corrects climb back over
errors. Accuracy first, then speed.

![A :VfChart showing errors above corrects](https://vimfluency.com/assets/chart.gif)

### The end-of-session breakdown

Every training and lesson finishes on the same screen: the session's rate
against aim, its efficiency (the optimal keystroke count versus what you
actually spent), and a per-command table so you can see *which* motion is
holding you back — the slow one is marked. A one-key menu
(`T`/`L`/`C`/`I`/`V`/`Q`) jumps you straight to whatever's next.

![The shared end-of-session breakdown](https://vimfluency.com/assets/end.gif)

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
