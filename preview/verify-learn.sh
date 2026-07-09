#!/usr/bin/env bash
# Render-free verification that :VfLearnDemo auto-plays a whole lesson to
# graduation for each drill — runs the plugin headless and asserts each
# lesson reaches the shared end screen. The learn twin of verify-demo.sh;
# use it in the "Adding a drill" checklist instead of eyeballing learn GIFs.
#
#   usage: ./verify-learn.sh [drill_id ...]     # default: every drill with a lesson
#
# Exit 0 iff every checked lesson graduated; non-zero (and a list of the
# failures) otherwise. A full sweep is slow (~15-20s per drill, since a
# lesson has to walk its frames + test streak on a live timer) — pass one
# id when adding a drill.
#
# Runs vim under `script` to give it a real pty (timers/feedkeys need an
# event loop) and writes the typescript to a real file — discarding it to
# /dev/null makes the pty misbehave and timers fire unreliably.
set -euo pipefail

cd "$(dirname "$0")"
PLUGIN="$(cd .. && pwd)"
OUT="$(mktemp -t vf-verify-learn.XXXXXX)"
LOG="$(mktemp -t vf-verify-learn-log.XXXXXX)"
trap 'rm -f "$OUT" "$LOG"' EXIT

# Reap any orphaned headless vims from a previous interrupted run.
pkill -f 'vim -u NONE -N --cmd .*vimfluency' 2>/dev/null || true

# Pipe script's output to cat (do NOT redirect to a file/ /dev/null — that
# detaches the pty and the event loop stalls, so timers never fire).
VF_DRILLS="$*" VF_OUT="$OUT" \
  script -q "$LOG" vim -u NONE -N \
    --cmd "set rtp^=$PLUGIN" \
    -c 'runtime plugin/vimfluency.vim' \
    -S verify-learn.vim 2>&1 | cat >/dev/null || true

if [ ! -s "$OUT" ]; then
  echo "verify-learn: no results (vim failed to run) — log:" >&2
  tr -cd '[:print:]\n' < "$LOG" | tail -5 >&2
  exit 2
fi

fails="$(grep -c ' FAIL ' "$OUT" || true)"
total="$(wc -l < "$OUT" | tr -d ' ')"
column -t < "$OUT"
echo "---"
if [ "$fails" -gt 0 ]; then
  echo "FAIL: $fails/$total lesson(s) did not graduate under :VfLearnDemo" >&2
  exit 1
fi
echo "OK: all $total lesson(s) graduate under :VfLearnDemo"
