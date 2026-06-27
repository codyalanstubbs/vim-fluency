# :VfChart — the Standard Celeration Chart for one drill: correct-rate and
# error-rate over sessions, on the log-scaled y the SCC convention uses, so
# improvement reads as a straight climbing line. Z toggles the zoom view.
#
# Render from preview/:  vhs scenes/chart.tape
Output renders/scene-chart.gif
Output renders/scene-chart.mp4

Set FontSize 20
Set Width 1200
Set Height 900

Source "_dims-wide.tape"
Source "_setup.tape"

Hide

Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

# The flagship has the most sessions -> the clearest celeration line.
Type ":VfChart move_to_word_start_forward_backward"
Sleep 400ms
Enter
Sleep 4s

# Zoom in, then back to standard.
Type "Z"
Sleep 3s
Type "Z"
Sleep 2500ms
Sleep 1200ms
