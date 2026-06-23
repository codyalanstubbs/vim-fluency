# :VfLearn — a Direct-Instruction lesson, auto-played: the rule frames
# ("w sends the cursor to the next word start"), the try frames where the
# cursor jumps from the performed motion, then the test phase applying the
# rule to fresh items until it graduates onto the shared end screen.
# Seeded history gives that end screen a populated last-session panel.
#
# Render from preview/:  vhs scenes/lesson.tape
Output renders/scene-lesson.gif
Output renders/scene-lesson.mp4

Source "_setup.tape"
Hide
Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

Type ":VfLearnDemo move_to_word_start_forward_backward"
Sleep 400ms
Enter

# The auto-played lesson walks the rule + try frames and the test phase,
# then lands on the end screen. Hold across the whole walkthrough.
Sleep 30s
