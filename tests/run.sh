#!/usr/bin/env bash
# Run all vimfluency vim-headless tests. Exits non-zero on any failure.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."
exec vim -Nu NONE -es -S tests/run.vim
