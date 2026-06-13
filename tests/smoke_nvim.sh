#!/usr/bin/env bash
# Interactive smoke test under Neovim. Unlike run.sh (vim -Es, no event
# loop), this drives a LIVE headless nvim over RPC with real keystrokes,
# so timers fire, ModeChanged/CursorMoved autocmds run, and the
# dashboard/list/chart buffers actually open and close. Exits non-zero
# on any failure.
#
# Covers: plugin load, :Vf arg validation, mode_switch training
# (ModeChanged credit + the :VfQuit cnoremap escape hatch), motion
# training (CursorMoved credit + timer-expiry stop + JSONL write +
# dashboard handoff), visual_motion training, lesson open/teardown,
# :VfList and :VfChart open/close, and an E-number scan of :messages.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"

command -v nvim >/dev/null 2>&1 || { echo "SKIP: nvim not installed"; exit 0; }

SOCK="$(mktemp -u /tmp/vf-smoke-XXXXXX.sock)"
XDG="$(mktemp -d /tmp/vf-smoke-xdg-XXXXXX)"

XDG_DATA_HOME="$XDG" nvim --headless --listen "$SOCK" --clean \
  --cmd "set rtp^=$ROOT" >/dev/null 2>&1 &
NVPID=$!
cleanup() {
  nvim --server "$SOCK" --remote-send ':qa!<CR>' >/dev/null 2>&1
  kill "$NVPID" >/dev/null 2>&1
  rm -rf "$XDG" "$SOCK"
}
trap cleanup EXIT

NV() { nvim --server "$SOCK" --remote-expr "$1" 2>/dev/null; }
NS() { nvim --server "$SOCK" --remote-send "$1" >/dev/null 2>&1; }
# wait() runs nvim's event loop, so this both sleeps and lets pending
# input/timers/autocmds process — the settling primitive between keys.
settle() { NV 'wait(200, {-> 0}, 50)' >/dev/null; }
nap() { perl -e 'select(undef,undef,undef,$ARGV[0])' "$1"; }

up=0
for _ in $(seq 1 100); do
  if [ "$(NV 1)" = "1" ]; then up=1; break; fi
  nap 0.1
done
[ "$up" = "1" ] || { echo "FATAL: nvim RPC server did not come up"; exit 1; }

fail=0
chk() {  # name want got
  if [ "$3" = "$2" ]; then echo "ok   $1"
  else echo "FAIL $1: want [$2] got [$3]"; fail=1; fi
}
chkge() {  # name min got
  if [ -n "${3:-}" ] && [ "$3" -ge "$2" ] 2>/dev/null; then echo "ok   $1 ($3)"
  else echo "FAIL $1: want >=$2 got [${3:-}]"; fail=1; fi
}
correct() { NV 'matchstr(vimfluency#statusline(), "correct \\zs\\d\\+")'; }
log_lines() { NV 'filereadable(vimfluency#log_dir() . "/sessions.jsonl") ? len(readfile(vimfluency#log_dir() . "/sessions.jsonl")) : 0'; }

echo "== load =="
chk "plugin loaded" 1 "$(NV 'exists("g:loaded_vimfluency")')"
pinpoint_count=$(ls "$ROOT"/autoload/vimfluency/pinpoints/*.vim | wc -l | tr -d ' ')
chk "registry has $pinpoint_count pinpoints (one per file)" "$pinpoint_count" "$(NV 'len(vimfluency#discover_pinpoints())')"
chk "15 :Vf* commands" 15 "$(NV 'len(getcompletion("Vf", "command"))')"

echo "== arg validation =="
NS ':Vf save_vs_quit abc<CR>'; settle
chk "bad duration rejected, no session" "" "$(NV 'vimfluency#statusline()')"

echo "== mode_switch training: ModeChanged credit + VfQuit escape =="
NS ':Vf switch_mode_to_insert 30<CR>'; settle
chk "session started" 1 "$(NV '!empty(vimfluency#statusline())')"
chk "training buffer name" "vf-switch_mode_to_insert" "$(NV 'bufname("%")')"
# First target must be insert (no-repeat constraint: current mode is n).
NS 'i'; settle
chk "i credited via ModeChanged" 1 "$(correct)"
NS '<Esc>'; settle
chk "Esc back to normal credited" 2 "$(correct)"
# :VfQuit must pass through the <CR>-defang cnoremap (escape hatch).
NS ':VfQuit<CR>'; settle; nap 0.5; settle
chk "VfQuit escape hatch ended session" "" "$(NV 'vimfluency#statusline()')"
chk "JSONL record written" 1 "$(log_lines)"
chk "dashboard opened after stop" 1 "$(NV 'bufexists("vf-dashboard-table")')"
NS 'q'; settle
chk "dashboard q closes it" 0 "$(NV 'bufexists("vf-dashboard-table")')"

echo "== motion training: CursorMoved credit + timer expiry =="
NS ':Vf move_to_line_edges_start_end 5<CR>'; settle
chk "session started" 1 "$(NV '!empty(vimfluency#statusline())')"
for _ in 1 2 3 4 5; do NS '0'; settle; NS '$'; settle; done
chk "timer expired the session" 0 "$(NV 'wait(8000, {-> empty(vimfluency#statusline())}, 200)')"
chk "second JSONL record" 2 "$(log_lines)"
chkge "motion items credited" 1 "$(NV 'json_decode(readfile(vimfluency#log_dir() . "/sessions.jsonl")[-1])["items_correct"]')"
chk "dashboard reopened" 1 "$(NV 'bufexists("vf-dashboard-table")')"
NS 'q'; settle

echo "== visual_motion training =="
NS ':Vf visual_select_single_char_left_right 30<CR>'; settle
chk "session started" 1 "$(NV '!empty(vimfluency#statusline())')"
# Free-operant: a wrong-direction guess leaves the cursor displaced and
# the learner must recover, so blind vh/vl alternation never credits.
# Read each item's expected motion and press exactly that.
for _ in 1 2 3; do
  exp="$(NV 'vimfluency#_test_state().current_item.expected_motion')"
  NS "$exp"; settle
done
chkge "visual selections credited" 3 "$(correct)"
NS '<Esc>'; NS ':VfQuit<CR>'; settle; nap 0.5; settle
chk "VfQuit ended session" "" "$(NV 'vimfluency#statusline()')"
NS 'q'; settle

echo "== lesson open + teardown =="
NS ':VfLearn move_single_char_up_down_left_right<CR>'; settle
chk "lesson buffer name" "vf-lesson-move_single_char_up_down_left_right" "$(NV 'bufname("%")')"
chkge "lesson frame rendered" 3 "$(NV 'line("$")')"
NS ':VfQuit<CR>'; settle; nap 0.3; settle
chk "lesson torn down" 0 "$(NV 'bufexists("vf-lesson-move_single_char_up_down_left_right")')"

echo "== list + chart open/close =="
NS ':VfList<CR>'; settle
chk "list opens" 1 "$(NV 'bufexists("vf-list")')"
NV 'win_gotoid(win_findbuf(bufnr("vf-list"))[0])' >/dev/null
NS 'q'; settle
chk "list q closes it" 0 "$(NV 'bufexists("vf-list")')"
NS ':VfChart move_to_line_edges_start_end<CR>'; settle
chk "chart opens" 1 "$(NV 'bufexists("vf-chart-move_to_line_edges_start_end")')"
NS 'q'; settle
chk "chart q closes it" 0 "$(NV 'bufexists("vf-chart-move_to_line_edges_start_end")')"

echo "== error scan =="
errs="$(NV 'execute("messages")' | grep -cE 'E[0-9]+:' || true)"
chk "no E-number errors in :messages" 0 "$errs"
if [ "$errs" != "0" ]; then NV 'execute("messages")' | grep -E 'E[0-9]+:'; fi

echo
if [ "$fail" = "0" ]; then echo "SMOKE PASS (nvim $(nvim --version | head -1 | cut -d' ' -f2))"
else echo "SMOKE FAIL"; fi
exit "$fail"
