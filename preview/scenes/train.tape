# :VfTrain — a timed fluency session (auto-played here via :VfDemo): each
# generated item drops a green target, the cursor reaches it, and the
# correct / rate counters climb against the aim. At time it auto-stops onto
# the end screen, which logs the session so your rate is tracked over time.
#
# Render from preview/:  vhs scenes/train.tape
Output renders/scene-train.gif
Output renders/scene-train.mp4

Source "_dims-default.tape"
Source "_setup.tape"
Hide
Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

# A 12s self-driving session on the flagship drill.
Type ":VfDemo move_to_word_start_forward_backward 12"
Sleep 400ms
Enter

# Hold through the live session, then the auto-stop -> end-screen landing.
Sleep 16s
Sleep 1500ms
