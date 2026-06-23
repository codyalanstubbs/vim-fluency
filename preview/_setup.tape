# Shared VHS setup — Source'd by every generated preview tape so they all
# look like a set (same theme/font/dims) and launch vim the same way.
#
# Do NOT render this file directly; it has no Output and no on-camera
# beats. The generator (gen-previews.sh) emits per-drill tapes that
# `Source "_setup.tape"` and then add Output + the drill-specific beats.
#
# This dir (preview/) sits at the plugin repo root, so the plugin is one
# dir up (..). vim --clean does NOT source plugin/*.vim from a prepended
# runtimepath, so launch with -u NONE + explicit `runtime`.

Set Shell "bash"
Set FontSize 20
Set Width 1100
Set Height 680
Set Padding 20
# cyberdream (scottmckendry/cyberdream.nvim, dark) as an inline palette —
# VHS doesn't bundle it. Matches the editor: near-black bg, white fg, and
# the drill's green target cell becomes cyberdream's signature green.
Set Theme { "name": "cyberdream", "background": "#16181a", "foreground": "#ffffff", "cursor": "#ffffff", "selection": "#3c4048", "black": "#16181a", "red": "#ff6e5e", "green": "#5eff6c", "yellow": "#f1ff5e", "blue": "#5ea1ff", "purple": "#ff5ef1", "cyan": "#5ef1ff", "white": "#ffffff", "brightBlack": "#7b8496", "brightRed": "#ff6e5e", "brightGreen": "#5eff6c", "brightYellow": "#f1ff5e", "brightBlue": "#5ea1ff", "brightPurple": "#ff5ef1", "brightCyan": "#5ef1ff", "brightWhite": "#ffffff" }
Set TypingSpeed 80ms

# Demo/preview sessions auto-play at superhuman speed and MUST never touch
# real data — vimfluency#stop skips the log write for demo sessions, and
# we point XDG at a throwaway dir as belt-and-suspenders.
Env XDG_DATA_HOME "/tmp/vf-preview"

Hide
Type "vim -u NONE -N --cmd 'set rtp^=..' -c 'runtime plugin/vimfluency.vim'"
Enter
Sleep 1500ms
Show
