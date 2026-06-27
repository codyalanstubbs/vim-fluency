# Wider/taller terminal for the data-dense views (dashboard's two chart
# panels + table, the full celeration chart, the list's many columns).
# Source it AFTER _setup.tape (which sets the default training dims) and
# BEFORE _launch.tape — VHS lets a later Set override an earlier one, and
# the views size their charts/tables to the terminal, so a bigger terminal
# shows them in full. FontSize stays readable.
Set FontSize 16
Set Width 1200
Set Height 1040
