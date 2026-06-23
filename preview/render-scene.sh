#!/usr/bin/env bash
# Render hand-authored feature scenes (scenes/*.tape) to renders/scene-*.{gif,mp4}.
# Each scene Sources _setup.tape + _launch.tape and seeds its own sandbox
# history, so they only need a clean ttyd and to run from this dir (VHS
# resolves Source/Output relative to cwd).
#
#   ./render-scene.sh            # render every scene
#   ./render-scene.sh dashboard chart   # ...just these
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p renders

scenes=()
if [ "$#" -gt 0 ]; then
  scenes=("$@")
else
  for f in scenes/*.tape; do
    scenes+=("$(basename "$f" .tape)")
  done
fi

fail=0
for s in "${scenes[@]}"; do
  tape="scenes/$s.tape"
  if [ ! -f "$tape" ]; then
    echo "render-scene: no such scene '$s' ($tape)" >&2; fail=1; continue
  fi
  # Orphaned ttyd from a failed prior render fails the next with
  # ERR_CONNECTION_REFUSED — reap it first.
  pkill -f ttyd 2>/dev/null || true
  sleep 1
  echo "rendering $s ..."
  if vhs "$tape"; then
    echo "  -> renders/scene-$s.{gif,mp4}"
  else
    echo "  FAILED: $s" >&2; fail=1
  fi
done
exit "$fail"
