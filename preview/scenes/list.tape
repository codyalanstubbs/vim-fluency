# :VfList — the drill catalog: commands, prereqs, and each drill's current
# rate vs aim. B expands the hovered drill's breakdown (its prereqs and its
# per-command rates). Seeded history fills the rate column; the rest read
# as not-yet-started.
#
# Render from preview/:  vhs scenes/list.tape
Output renders/scene-list.gif
Output renders/scene-list.mp4

Source "_dims-wide.tape"
Source "_setup.tape"

Hide

Type "bash seed-history.sh /tmp/vf-preview"
Enter
Sleep 2500ms
Source "_launch.tape"

# Default view: drills grouped by family.
Type ":VfList"
Sleep 400ms
Enter
Sleep 3s

# Sort by drill name -> one flat A-Z list, so we can land on specific
# drills. (delete_* sort to the top.)
Type "sd"
Sleep 2500ms

# Land on delete_to_word_start_forward_backward (4th: delete_char_vs_line,
# delete_single_char, delete_to_line_edges, delete_to_word_start). It has
# BOTH a prerequisite (move_to_word_start) and history, so its breakdown
# shows the prereq AND the dw/db per-command rates.
Type "gg"
Sleep 800ms
Type "jjj"
Sleep 1200ms
Type "B"
Sleep 4s
Type "B"
Sleep 800ms

# Now a drill with history but NO prereq: indent_vs_dedent (3 further down:
# delete_two_lines, force_quit, indent_vs_dedent) — its breakdown is just
# the >>/<< per-command rates.
Type "jjj"
Sleep 1200ms
Type "B"
Sleep 4s
Sleep 1200ms
