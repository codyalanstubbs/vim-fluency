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
Sleep 400ms
Enter
Sleep 3500ms

# Close, switch to the Foundational path — the basics only.
Type "q"
Sleep 500ms
Type ":VfSetPath foundational"
Sleep 600ms
Enter
Sleep 1500ms

# Reopen: the table is now scoped to Foundational, and the header tracks
# per-path fluency progress.
Type ":Vf"
Sleep 400ms
Enter
Sleep 4s

# Back to General.
Type "q"
Sleep 400ms
Type ":VfResetPath"
Enter
Sleep 1000ms
