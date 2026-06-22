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
Set Theme "Catppuccin Mocha"
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
