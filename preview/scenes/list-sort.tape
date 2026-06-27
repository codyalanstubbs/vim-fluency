# :VfList sorting — the catalog re-orders live on s+column: by current
# rate, by family, by aim, by drill name, and reset. The header echoes the
# sort keys (sr/sf/sa/sd ... s<Space> resets).
#
# Render from preview/:  vhs scenes/list-sort.tape
Output renders/scene-list-sort.gif
Output renders/scene-list-sort.mp4

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
Sleep 2500ms

# Sort by current rate — the drills you've practiced rise to the top.
Type "sr"
Sleep 2800ms

# By family.
Type "sf"
Sleep 2800ms

# By aim.
Type "sa"
Sleep 2800ms

# By drill name (alphabetical).
Type "sd"
Sleep 2800ms

# Reset to the default grouping.
Type "s "
Sleep 2500ms
Sleep 1200ms
