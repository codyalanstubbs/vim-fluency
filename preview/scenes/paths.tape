# Paths — focus your effort on a curated subset of the catalog. General is
# every shipped drill; Foundational is the survive-and-edit basics. A
# :VfSetPath switches the active path and the views re-filter to it.
# (Specialized workflow paths are coming soon.)
#
# Render from preview/:  vhs scenes/paths.tape
Output renders/scene-paths.gif
Output renders/scene-paths.mp4

Source "_dims-wide.tape"
Source "_setup.tape"

Hide

Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

# Default General path: the whole catalog.
Type ":Vf"
Sleep 500ms
Enter
Sleep 1000ms

# Switch to the Foundational path — the basics only.
Type "P"
Sleep 500ms
Type "foundational"
Sleep 600ms
Enter
Sleep 1500ms

# Back to General
Type "P"
Sleep 500ms
Type "general"
Enter
Sleep 1500ms

Type ":q"
