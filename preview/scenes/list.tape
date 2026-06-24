# :VfList — the drill catalog grouped by family: commands, prereqs, and
# each drill's current rate vs aim. B toggles the per-command breakdown.
# Seeded history fills the rate column; the rest read as not-yet-started.
#
# Render from preview/:  vhs scenes/list.tape
Output renders/scene-list.gif
Output renders/scene-list.mp4

Source "_dims-wide.tape"
Source "_setup.tape"
Hide
Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

Type ":VfList"
Sleep 400ms
Enter
Sleep 3s

# Per-command breakdown on (each command's own rate).
Type "B"
Sleep 3s

# Walk down through the families — the prereqs column shows drills that
# gate on others (e.g. delete-to-word needs move-to-word) and drills with
# none.
Type "jjjjj"
Sleep 2s
Type "jjjjj"
Sleep 2s

# Group the drills that HAVE prerequisites by sorting on the prereqs column.
Type "sp"
Sleep 3s
Sleep 1500ms
