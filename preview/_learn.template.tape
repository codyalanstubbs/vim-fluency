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
# Make the lesson demo dwell on the intro rule frame (ms) so a viewer can
# read it before it auto-advances; the runner reads this env at play time.
# Only set here (the preview), so verify-learn advances the intro instantly.
Env VF_LEARN_INTRO_DWELL "10000"
Source "_launch.tape"

# ~2s command beat: the ~80ms/char typing plays the command out, then a
# short settle holds the fully-typed command before it runs.
Type ":VfLearnDemo {{DRILL_ID}}"
Sleep 800ms
Enter

# Auto-played lesson for {{DRILL_ID}} ({{DRILL_NAME}}): a 10s hold on the
# intro rule frame, then the try frames and the test phase to graduation.
# Wait for the end screen to appear (rather than a fixed hold), so the
# recording ends ~3s after graduation instead of sitting on the end screen
# for the fixed remainder. @{{WAIT}} is the safety timeout — the slowest
# lesson graduates well under it; on timeout the Sleep still lands a tail.
Wait+Screen@{{WAIT}} /LESSON COMPLETE/
Sleep 3s
