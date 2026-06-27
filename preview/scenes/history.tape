# :VfHistory — the raw session log: every training session with its
# frequency, errors, and efficiency, newest first. The audit trail behind
# the dashboard and chart.
#
# Render from preview/:  vhs scenes/history.tape
Output renders/scene-history.gif
Output renders/scene-history.mp4

Source "_dims-wide.tape"
Source "_setup.tape"

Hide

Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

Type ":VfHistory"
Sleep 400ms
Enter
Sleep 4s

# Scroll through the log.
Type "jjjjjj"
Sleep 2500ms
Type "G"
Sleep 2500ms
Sleep 1200ms
