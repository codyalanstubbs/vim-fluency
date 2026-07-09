#!/usr/bin/env bash
# Generate per-drill :VfTrain and :VfLearn preview tapes from the templates,
# and optionally render them. The drill registry is the source of truth:
# every drill gets a train tape, and every drill that defines a lesson also
# gets a learn tape — so adding a drill auto-produces its previews with no
# hand-editing.
#
#   ./gen-previews.sh                 # emit tapes for every drill -> build/
#   ./gen-previews.sh move_to_word_start_forward_backward   # just these ids
#   ./gen-previews.sh --render [ids]  # emit AND render to renders/*.gif
#
# Generated tapes (build/) and renders (renders/) are gitignored; commit
# only curated hero assets.
set -euo pipefail

cd "$(dirname "$0")"
DEMO_DIR="$(pwd)"
PLUGIN="$(cd .. && pwd)"
BUILD="$DEMO_DIR/build"
RENDERS="$DEMO_DIR/renders"
TRAIN_TEMPLATE="$DEMO_DIR/_train.template.tape"
LEARN_TEMPLATE="$DEMO_DIR/_learn.template.tape"

DURATION=10          # seconds the :VfDemo (train) auto-plays
HOLD="13s"           # train camera hold: DURATION + end-screen landing
LEARN_HOLD="42s"     # learn camera hold: 10s intro dwell + try + test phase +
                     # end-screen landing (the slowest lessons run ~30s of
                     # play on top of the intro)

RENDER=0
if [ "${1:-}" = "--render" ]; then RENDER=1; shift; fi

mkdir -p "$BUILD"
[ "$RENDER" = 1 ] && mkdir -p "$RENDERS"

# Drill id<TAB>name<TAB>haslesson lines straight from the registry (single
# source of truth). haslesson is 1 when the drill defines #lesson(), else 0.
# Falls back to nothing on failure, which surfaces as "no drills".
list_drills() {
  vim -u NONE -N --cmd "set rtp^=$PLUGIN" \
    -c 'runtime plugin/vimfluency.vim' -es \
    -c 'redir! > /dev/stdout | silent for k in sort(keys(vimfluency#discover_drills())) | echo k . "\t" . vimfluency#discover_drills()[k].name . "\t" . (exists("*vimfluency#drills#" . k . "#lesson") ? 1 : 0) | endfor | redir END' \
    -c 'qa!' 2>/dev/null | tr -d '\r' | grep -E '.\t'
}

# Select requested ids (default: all). Kept bash-3.2 friendly (macOS) —
# no mapfile / associative arrays. ROWS holds "id<TAB>name<TAB>haslesson".
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

render_tape() {
  local tape="$1" out="$2"
  # VHS resolves Source relative to cwd, so render from the preview dir.
  # Reap orphaned ttyd from a failed prior render first (it makes the next
  # render fail with ERR_CONNECTION_REFUSED).
  pkill -f ttyd 2>/dev/null || true
  ( cd "$DEMO_DIR" && vhs "$tape" ) && echo "  rendered $out.{gif,mp4}"
}

gen_train() {
  local id="$1" name="$2"
  local tape="$BUILD/$id-train.tape"
  local out="$RENDERS/$id-train"        # base path; template appends .gif/.mp4
  sed -e "s|{{DRILL_ID}}|$id|g" \
      -e "s|{{DRILL_NAME}}|$name|g" \
      -e "s|{{DURATION}}|$DURATION|g" \
      -e "s|{{HOLD}}|$HOLD|g" \
      -e "s|{{OUTPUT}}|$out|g" \
      "$TRAIN_TEMPLATE" > "$tape"
  echo "  wrote $tape"
  if [ "$RENDER" = 1 ]; then render_tape "$tape" "$out"; fi
}

gen_learn() {
  local id="$1" name="$2"
  local tape="$BUILD/$id-learn.tape"
  local out="$RENDERS/$id-learn"
  sed -e "s|{{DRILL_ID}}|$id|g" \
      -e "s|{{DRILL_NAME}}|$name|g" \
      -e "s|{{HOLD}}|$LEARN_HOLD|g" \
      -e "s|{{OUTPUT}}|$out|g" \
      "$LEARN_TEMPLATE" > "$tape"
  echo "  wrote $tape"
  if [ "$RENDER" = 1 ]; then render_tape "$tape" "$out"; fi
}

learn_count=0
for row in "${ROWS[@]}"; do
  id="${row%%$'\t'*}"
  rest="${row#*$'\t'}"                   # name<TAB>haslesson
  name="${rest%$'\t'*}"
  haslesson="${rest##*$'\t'}"
  gen_train "$id" "$name"
  if [ "$haslesson" = 1 ]; then
    gen_learn "$id" "$name"
    learn_count=$((learn_count + 1))
  fi
done
echo "done: ${#ROWS[@]} drill(s), ${learn_count} with a lesson"
