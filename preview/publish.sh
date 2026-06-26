#!/usr/bin/env bash
# Publish the curated documentation asset set to the website repo, served at
# vimfluency.com/assets/. Single source of truth is preview/renders/ (the
# regenerable build artifacts); this re-renders the curated scenes fresh, then
# derives each surface's format:
#
#   <name>.gif         — for the README (GitHub auto-loops inline GIFs)
#   <name>.mp4         — for the site (<video>, faststart for streaming)
#   <name>.webm        — for the site (VP9, smaller + crisper than GIF)
#   <name>.poster.png  — first frame, so <video> paints before it loads
#   hero.png           — static dashboard shot for the hero
#
# It writes ONLY asset files into the website repo — never tooling — so the
# whole preview pipeline stays in the plugin repo (the website repo just
# carries the rendered output, which you commit + push there yourself).
#
#   usage: ./publish.sh [WEBSITE_REPO]
#   default WEBSITE_REPO: ../.vimfluency.com  (the sibling nested repo)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="${1:-$HERE/../.vimfluency.com}"
ASSETS="$SITE/assets"
RENDERS="$HERE/renders"

[ -d "$SITE" ] || { echo "website repo not found: $SITE" >&2; exit 2; }
command -v ffmpeg >/dev/null || { echo "ffmpeg required" >&2; exit 2; }

# The curated scenes, in doc order. scene-<scene>.{gif,mp4} -> asset <name>.
SCENES="dashboard list lesson train paths chart-struggle end-screen"
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

mkdir -p "$ASSETS"

# 1. Render each curated scene fresh, so they pick up the current seed + drill
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

# 3. Static hero: a dashboard frame once it's fully open and the panels
#    (chart + last-session breakdown) have populated. The scene types a long
#    ':Vf <drill>' command first (~3s at the set typing speed), so sample well
#    past that — too early catches vim's splash screen mid-command.
echo ">> extracting hero.png ..."
ffmpeg -loglevel error -y -ss 5.5 -i "$RENDERS/scene-dashboard.mp4" -frames:v 1 "$ASSETS/hero.png"

echo
echo "published $(ls -1 "$ASSETS" | wc -l | tr -d ' ') files -> $ASSETS"
ls -1 "$ASSETS"
echo
echo "referenced as: https://vimfluency.com/assets/<name>.{gif,mp4,webm,poster.png}"
