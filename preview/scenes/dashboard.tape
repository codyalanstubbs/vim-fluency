# :Vf dashboard — the multi-panel view: drill table + the hovered drill's
# celeration chart and last-session per-command breakdown, which refresh as
# you move between rows. Seeded history makes it a populated learner view.
#
# Render from preview/:  vhs scenes/dashboard.tape   (cwd-relative paths)
Output renders/scene-dashboard.gif
Output renders/scene-dashboard.mp4

Source "_setup.tape"
Hide
Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

# Open on the flagship drill; the hover panels show its chart + breakdown.
Type ":Vf move_to_word_start_forward_backward"
Sleep 400ms
Enter
Sleep 3s

# Move between rows — the chart + last-session panels track the cursor.
Type "j"
Sleep 1800ms
Type "j"
Sleep 1800ms
Type "k"
Sleep 1800ms

# Inspect the selected drill's last session in full.
Type "B"
Sleep 3500ms
Sleep 1500ms
