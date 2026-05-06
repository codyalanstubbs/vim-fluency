# Vim Fluency

A vim plugin for behavioral-fluency probes on vim motion pinpoints. Runs inside vim itself — no simulator divergence, you're using real vim. Project home: vimfluency.com.

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
:VfList                  " show installed pinpoints
:Vf 1A.1                 " 60-second probe on hjkl
:Vf 1A.1 30              " 30 seconds
:VfQuit                  " end early; log + summary printed
```

Tab key skips the current item. The session opens its own tab page; ending closes it.

## How it works

A session opens a new tab with a single buffer. The target cell is highlighted in green directly in that buffer; your cursor moves through it normally. Autocommands on `CursorMoved`/`TextChanged` watch the buffer; when (line content, cursor position) matches the target, the item is logged correct and the next item loads.

Because it's real vim, every keystroke is interpreted natively — no need to maintain a parallel command dispatcher.

For motion-only pinpoints (Tier 0/1), the target cell is enough — the buffer content doesn't change. For editing pinpoints (Tier 2+), where the target lines differ from the start lines, this single-pane display will need a "before" reference somewhere (popup, virtual text, or split). Address that when the first editing pinpoint lands.

## Logs

JSONL appended to `$XDG_DATA_HOME/vimfluency/sessions.jsonl` (or `~/.local/share/vimfluency/sessions.jsonl`). One line per session. Substrate for the (not-yet-built) celeration chart.

## Adding a pinpoint

See `:help vf-pinpoints` or copy `autoload/vimfluency/pinpoints/p1A_1.vim` as a template. Two functions: `meta()` returns the pinpoint metadata; `generate()` returns one item.

## v1 limits

- **No keystroke counting.** Vim's autocmds fire post-aggregate (`5w` is one event), so individual keys aren't observable without taking over the input loop with `getchar()`. Rate is what's measured. A `getchar()` mode for keystroke-efficiency analysis can come later.
- **No input restriction.** A pinpoint declares `allowed_keys` in its metadata, but the plugin doesn't currently remap forbidden keys. Honest measurement of what the user does. Can be added as opt-in later.
- **Eight pinpoints shipped** (1A.1 hjkl, 1A.2 line start/end, 1B.1 word motions, 1C.1 find char, 1C.2 till char, 1C.3 repeat last find, 1C.4 discriminate f/t, 4.1 delete with word motion). See `CATALOG.md` for the planned ~80.
- **Vim 8.1+** required.
