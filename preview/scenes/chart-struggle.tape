# :VfChart as a diagnostic — a drill the learner is stuck on. The × error
# line sits ABOVE the ● correct line: the textbook "going too fast" signature.
# The full-screen chart shows it far more clearly than the dashboard's inline
# chart, which is squeezed by column spacing. The fix the chart prescribes:
# slow down until corrects climb back above errors.
#
# Render from preview/:  vhs scenes/chart-struggle.tape
Output renders/scene-chart-struggle.gif
Output renders/scene-chart-struggle.mp4

Source "_dims-wide.tape"
Source "_setup.tape"

Hide

Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

Type ":VfChart move_to_vs_till_forward_backward"
Sleep 400ms
Enter
Sleep 5s
Sleep 1200ms
