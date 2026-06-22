#!/usr/bin/env bash
# Render-free verification that :VfDemo auto-plays drills — runs the plugin
# headless and asserts the `correct` counter climbs for each drill. Use
# this in the "Adding a drill" checklist instead of eyeballing GIFs.
#
#   usage: ./verify-demo.sh [drill_id ...]      # default: every drill
#
# Exit 0 iff every checked drill credited at least one item; non-zero
# (and a list of the failures) otherwise.
#
# Runs vim under `script` to give it a real pty (timers/feedkeys need an
# event loop) and writes the typescript to a real file — discarding it to
# /dev/null makes the pty misbehave and timers fire unreliably.
set -euo pipefail

cd "$(dirname "$0")"
PLUGIN="$(cd .. && pwd)"
OUT="$(mktemp -t vf-verify.XXXXXX)"
LOG="$(mktemp -t vf-verify-log.XXXXXX)"
trap 'rm -f "$OUT" "$LOG"' EXIT

# Reap any orphaned headless vims from a previous interrupted run.
pkill -f 'vim -u NONE -N --cmd .*vimfluency' 2>/dev/null || true

# Pipe script's output to cat (do NOT redirect to a file/ /dev/null — that
# detaches the pty and the event loop stalls, so timers never fire).
VF_DRILLS="$*" VF_OUT="$OUT" \
  script -q "$LOG" vim -u NONE -N \
    --cmd "set rtp^=$PLUGIN" \
    -c 'runtime plugin/vimfluency.vim' \
    -S verify-demo.vim 2>&1 | cat >/dev/null || true

if [ ! -s "$OUT" ]; then
  echo "verify-demo: no results (vim failed to run) — log:" >&2
  tr -cd '[:print:]\n' < "$LOG" | tail -5 >&2
  exit 2
fi

fails="$(grep -c ' FAIL ' "$OUT" || true)"
total="$(wc -l < "$OUT" | tr -d ' ')"
column -t < "$OUT"
echo "---"
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails/$total drill(s) did not credit under :VfDemo" >&2
  exit 1
fi
echo "OK: all $total drill(s) credit under :VfDemo"
