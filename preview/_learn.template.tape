# Template for a per-drill :VfLearn preview. gen-previews.sh substitutes
# {{DRILL_ID}} / {{DRILL_NAME}} / {{HOLD}} / {{OUTPUT}} and writes
# build/<id>-learn.tape (only for drills that define a lesson).
#
# The beat: :VfLearnDemo auto-plays a whole Direct-Instruction lesson —
# it reads the rule frames, performs each try frame's canonical motion
# (the cursor jumps from the played keystroke), then applies the rule
# through the test phase to graduation, landing on the shared end screen
# (the T/L/C/I/V/Q menu). No duration arg: the lesson plays to graduation
# and the tail Sleep holds across the whole walkthrough plus the landing.
#
# Targets in the test phase are randomly generated per render (vim's
# rand() isn't seeded), so re-renders differ in detail but tell the same
# story. Kept parallel to _train.template.tape (no seeded history) — the
# lesson walkthrough is the subject, not the end screen.

Output "{{OUTPUT}}.gif"
Output "{{OUTPUT}}.mp4"

Source "_dims-default.tape"
Source "_setup.tape"
Source "_launch.tape"

Type ":VfLearnDemo {{DRILL_ID}}"
Sleep 400ms
Enter

# Auto-played lesson for {{DRILL_ID}} ({{DRILL_NAME}}): rule frames, try
# frames, then the test phase to graduation. Hold across the walkthrough.
Sleep {{HOLD}}
