#!/usr/bin/env bash
# Publish the curated documentation asset set to the website repo, served at
# vimfluency.com/assets/. Single source of truth is preview/renders/ (the
# regenerable build artifacts); this re-renders the curated scenes fresh, then
# derives each surface's format:
#
#   <name>.gif         — for the README (GitHub auto-loops inline GIFs)
#   <name>.mp4         — for the site (<video>, faststart for streaming)
#   <name>.webm        — for the site (VP9, smaller + crisper than GIF)
#   <name>.poster.png  — a representative held frame, so <video> paints
#                        something real before it loads
#   hero.png           — static dashboard shot for the hero (from the
#                        dashboard scene)
#
# It writes ONLY asset files into the website repo — never tooling — so the
# whole preview pipeline stays in the plugin repo (the website repo just
# carries the rendered output, which you commit + push there yourself).
#
#   usage: ./publish.sh [--scene <name>] [--site <dir>]
#     --scene  publish just one scene (by scene name, e.g. chart-struggle,
#              or by its asset name, e.g. chart). Default: all curated scenes.
#     --site   website repo path. Default: ../.vimfluency.com (sibling repo).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RENDERS="$HERE/renders"

# The curated scenes, in doc order. scene-<scene>.{gif,mp4} -> asset <name>.
ALL_SCENES="dashboard list lesson train paths chart-struggle end-screen"
asset_for() {
  case "$1" in
    dashboard)      echo dashboard ;;
    list)           echo list ;;
    lesson)         echo learn ;;
    train)          echo train ;;
    paths)          echo paths ;;
    chart-struggle) echo chart ;;
    end-screen)     echo end ;;
  esac
}

# Map a user-supplied name (scene name OR asset name) to a scene name.
resolve_scene() {
  for s in $ALL_SCENES; do [ "$s" = "$1" ] && { echo "$s"; return 0; }; done
  for s in $ALL_SCENES; do [ "$(asset_for "$s")" = "$1" ] && { echo "$s"; return 0; }; done
  return 1
}

SITE="$HERE/../.vimfluency.com"
ONE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --scene) ONE="${2:-}"; shift 2 ;;
    --site)  SITE="${2:-}"; shift 2 ;;
    -h|--help) sed -n '/^#   usage:/,/^#     --site/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

ASSETS="$SITE/assets"
[ -d "$SITE" ] || { echo "website repo not found: $SITE" >&2; exit 2; }
command -v ffmpeg >/dev/null || { echo "ffmpeg required" >&2; exit 2; }

# Resolve which scenes to publish.
if [ -n "$ONE" ]; then
  SCENES="$(resolve_scene "$ONE")" || {
    echo "unknown scene: $ONE" >&2
    echo "available: $ALL_SCENES" >&2
    exit 2
  }
else
  SCENES="$ALL_SCENES"
fi

mkdir -p "$ASSETS"

# 1. Render each requested scene fresh, so it picks up the current seed + drill
#    registry. ttyd lingers between renders and blocks the next one — kill it.
for s in $SCENES; do
  pkill -f ttyd 2>/dev/null || true; sleep 0.3
  echo ">> rendering scene-$s ..."
  ( cd "$HERE" && vhs "scenes/$s.tape" >/dev/null 2>&1 )
done

# 2. Derive each surface's format and copy into the site.
for s in $SCENES; do
  name="$(asset_for "$s")"
  mp4="$RENDERS/scene-$s.mp4"
  gif="$RENDERS/scene-$s.gif"
  echo ">> publishing $name ..."
  cp "$gif" "$ASSETS/$name.gif"
  ffmpeg -loglevel error -y -i "$mp4" -movflags +faststart -c copy "$ASSETS/$name.mp4"
  ffmpeg -loglevel error -y -i "$mp4" -c:v libvpx-vp9 -b:v 0 -crf 34 -an "$ASSETS/$name.webm"
  # Poster = a representative held frame, NOT frame 0 (that's vim's splash).
  # Most scenes end on content; paths ends on an off-camera path reset, so
  # pin it to the Foundational dashboard instead of the final frame.
  if [ "$s" = paths ]; then
    ffmpeg -loglevel error -y -ss 12 -i "$mp4" -frames:v 1 "$ASSETS/$name.poster.png"
  else
    ffmpeg -loglevel error -y -sseof -1 -i "$mp4" -frames:v 1 "$ASSETS/$name.poster.png"
  fi
done

# 3. Static hero: a dashboard frame once it's fully open and the panels (chart
#    + last-session breakdown) have populated. The scene types a long
#    ':Vf <drill>' command first (~3s at the set typing speed), so sample well
#    past that — too early catches vim's splash screen mid-command. Only when
#    the dashboard scene was (re-)rendered this run.
case " $SCENES " in
  *" dashboard "*)
    echo ">> extracting hero.png ..."
    ffmpeg -loglevel error -y -ss 5.5 -i "$RENDERS/scene-dashboard.mp4" -frames:v 1 "$ASSETS/hero.png"
    ;;
esac

echo
echo "published to $ASSETS:"
for s in $SCENES; do
  name="$(asset_for "$s")"
  echo "  $name.{gif,mp4,webm,poster.png}"
done
case " $SCENES " in *" dashboard "*) echo "  hero.png" ;; esac
echo
echo "referenced as: https://vimfluency.com/assets/<name>.{gif,mp4,webm,poster.png}"
