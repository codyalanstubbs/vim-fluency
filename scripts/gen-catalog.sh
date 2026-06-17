#!/usr/bin/env bash
# Regenerate CATALOG.md from every drill's meta(). Run after adding or
# changing a drill. CI verifies the committed copy matches this output.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."
exec vim -Nu NONE -Es -S scripts/gen_catalog.vim
