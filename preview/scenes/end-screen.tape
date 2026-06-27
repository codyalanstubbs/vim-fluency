# The shared end screen — where both :VfTrain and :VfLearn finish: the
# drill's last-session frequency + per-command breakdown, and a single-key
# menu (T/L/C/I/V/Q) to jump straight to any other view. Here a short
# :VfDemo auto-stops onto it; seeded history gives it a populated panel.
#
# Render from preview/:  vhs scenes/end-screen.tape
Output renders/scene-end-screen.gif
Output renders/scene-end-screen.mp4

Source "_dims-default.tape"
Source "_setup.tape"

Hide

Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

# A brief self-driving session that auto-stops onto the end screen.
Type ":VfDemo move_to_word_start_forward_backward 4"
Sleep 400ms
Enter
Sleep 6s

# Hold on the end screen + its T/L/C/I/V/Q menu.
Sleep 3s
