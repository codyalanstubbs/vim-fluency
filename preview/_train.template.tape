# Template for a per-drill :VfTrain preview. gen-previews.sh substitutes
# {{DRILL_ID}} / {{DRILL_NAME}} / {{DURATION}} and writes tapes/<id>-train.tape.
#
# The beat: :VfDemo plays the optimal motion for each generated item, so
# the cursor leaps to target and the `correct` / `rate` counters climb on
# their own — a self-driving preview of a live training session. The demo
# auto-stops at its duration and lands on the dashboard (per-motion
# breakdown), which the tail Sleep holds on screen.
#
# Targets are randomly generated per render (vim's rand() isn't seeded),
# so re-renders differ in detail but always tell the same story.

Output "{{OUTPUT}}"

Source "_setup.tape"

Type ":VfDemo {{DRILL_ID}} {{DURATION}}"
Sleep 400ms
Enter

# Auto-play runs for {{DRILL_ID}} ({{DRILL_NAME}}); hold for the session
# plus the dashboard landing. Slightly longer than DURATION so the
# auto-stop -> dashboard transition is captured.
Sleep {{HOLD}}
