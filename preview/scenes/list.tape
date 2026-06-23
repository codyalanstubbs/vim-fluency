# :VfList — the drill catalog grouped by family, with each drill's current
# rate vs its aim. Seeded history fills the rate column; the rest read as
# not-yet-started, like a real learner mid-journey.
#
# Render from preview/:  vhs scenes/list.tape
Output renders/scene-list.gif
Output renders/scene-list.mp4

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

# Walk down through the families.
Type "jjjj"
Sleep 2s
Type "jjjj"
Sleep 2s

# Toggle the per-command breakdown column.
Type "B"
Sleep 3s
Sleep 1200ms
