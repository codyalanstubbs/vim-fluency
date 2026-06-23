# The navigation loop — every read-only view reaches every other with the
# same uppercase keys (T/L/C/I/V, Q to close), so you type :Vf once and
# then loop through chart, list, and back without retyping a command.
#
# Render from preview/:  vhs scenes/nav-loop.tape
Output renders/scene-nav-loop.gif
Output renders/scene-nav-loop.mp4

Source "_setup.tape"
Hide
Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

# Start at the dashboard, hovered on the flagship (which has history)...
Type ":Vf move_to_word_start_forward_backward"
Sleep 400ms
Enter
Sleep 2800ms

# ...C -> that drill's chart...
Type "C"
Sleep 2800ms

# ...I -> the drill list...
Type "I"
Sleep 2800ms

# ...V -> back to the dashboard. One loop, no commands retyped.
Type "V"
Sleep 2800ms
Sleep 1200ms
