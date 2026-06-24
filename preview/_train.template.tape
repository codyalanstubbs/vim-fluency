# Template for a per-drill :VfTrain preview. gen-previews.sh substitutes
# {{DRILL_ID}} / {{DRILL_NAME}} / {{DURATION}} / {{HOLD}} / {{OUTPUT}} and
# writes build/<id>-train.tape.
#
# The beat: :VfDemo plays the optimal motion for each generated item, so
# the cursor jumps to target and the `correct` / `rate` counters climb on
# their own — a self-driving preview of a live training session. The demo
# auto-stops at its duration and lands on the shared end screen (the
# T/L/C/I/V/Q menu), which the tail Sleep holds on screen.
#
# Targets are randomly generated per render (vim's rand() isn't seeded),
# so re-renders differ in detail but always tell the same story.

Output "{{OUTPUT}}.gif"
Output "{{OUTPUT}}.mp4"

Source "_dims-default.tape"
Source "_setup.tape"
Source "_launch.tape"

Type ":VfDemo {{DRILL_ID}} {{DURATION}}"
Sleep 400ms
Enter

# Auto-play runs for {{DRILL_ID}} ({{DRILL_NAME}}); hold for the session
# plus the end-screen landing. Slightly longer than DURATION so the
# auto-stop -> end-screen transition is captured.
Sleep {{HOLD}}
