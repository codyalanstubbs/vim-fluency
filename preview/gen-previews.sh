#!/usr/bin/env bash
# Generate per-drill :VfTrain preview tapes from _train.template.tape, and
# optionally render them. The drill registry is the source of truth: every
# drill in the plugin gets a tape, so adding a drill auto-produces its
# preview with no hand-editing.
#
#   ./gen-previews.sh                 # emit tapes for every drill -> build/
#   ./gen-previews.sh move_to_char_forward_backward   # just these ids
#   ./gen-previews.sh --render [ids]  # emit AND render to renders/*.gif
#
# Generated tapes (build/) and renders (renders/) are gitignored; commit
# only curated hero assets. VfLearn previews need lesson auto-play (which
# doesn't exist yet — see CONTRIBUTING) so only train tapes are generated.
set -euo pipefail

cd "$(dirname "$0")"
DEMO_DIR="$(pwd)"
PLUGIN="$(cd .. && pwd)"
BUILD="$DEMO_DIR/build"
RENDERS="$DEMO_DIR/renders"
TEMPLATE="$DEMO_DIR/_train.template.tape"

DURATION=10          # seconds the demo auto-plays
HOLD="13s"           # camera hold: DURATION + dashboard-landing buffer

RENDER=0
if [ "${1:-}" = "--render" ]; then RENDER=1; shift; fi

mkdir -p "$BUILD"
[ "$RENDER" = 1 ] && mkdir -p "$RENDERS"

# Drill id<TAB>name lines straight from the registry (single source of
# truth). Falls back to nothing on failure, which surfaces as "no drills".
list_drills() {
  vim -u NONE -N --cmd "set rtp^=$PLUGIN" \
    -c 'runtime plugin/vimfluency.vim' -es \
    -c 'redir! > /dev/stdout | silent for k in sort(keys(vimfluency#discover_drills())) | echo k . "\t" . vimfluency#discover_drills()[k].name | endfor | redir END' \
    -c 'qa!' 2>/dev/null | tr -d '\r' | grep -E '.\t'
}

# Select requested ids (default: all). Kept bash-3.2 friendly (macOS) —
# no mapfile / associative arrays. ROWS holds tab-separated "id<TAB>name".
ROWS=()
want=" $* "
while IFS= read -r row; do
  [ -n "$row" ] || continue
  if [ "$#" -gt 0 ]; then
    id="${row%%$'\t'*}"
    case "$want" in *" $id "*) ROWS+=("$row");; esac
  else
    ROWS+=("$row")
  fi
done < <(list_drills)

if [ "${#ROWS[@]}" -eq 0 ]; then
  echo "gen-previews: no matching drills" >&2; exit 1
fi

gen_one() {
  local id="$1" name="$2"
  local tape="$BUILD/$id-train.tape"
  local out="$RENDERS/$id-train.gif"
  sed -e "s|{{DRILL_ID}}|$id|g" \
      -e "s|{{DRILL_NAME}}|$name|g" \
      -e "s|{{DURATION}}|$DURATION|g" \
      -e "s|{{HOLD}}|$HOLD|g" \
      -e "s|{{OUTPUT}}|$out|g" \
      "$TEMPLATE" > "$tape"
  echo "  wrote $tape"
  if [ "$RENDER" = 1 ]; then
    # VHS resolves Source relative to cwd, so render from the demo dir.
    # Reap orphaned ttyd from a failed prior render first (it makes the
    # next render fail with ERR_CONNECTION_REFUSED).
    pkill -f ttyd 2>/dev/null || true
    ( cd "$DEMO_DIR" && vhs "$tape" ) && echo "  rendered $out"
  fi
}

for row in "${ROWS[@]}"; do
  gen_one "${row%%$'\t'*}" "${row#*$'\t'}"
done
echo "done: ${#ROWS[@]} drill(s)"
