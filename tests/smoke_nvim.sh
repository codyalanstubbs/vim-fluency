#!/usr/bin/env bash
# Interactive smoke test under Neovim. Unlike run.sh (vim -Es, no event
# loop), this drives a LIVE headless nvim over RPC with real keystrokes,
# so timers fire, ModeChanged/CursorMoved autocmds run, and the
# dashboard/list/chart buffers actually open and close. Exits non-zero
# on any failure.
#
# Covers: plugin load, :VfTrain arg validation, mode_switch training
# (ModeChanged credit + the :VfQuit cnoremap escape hatch), motion
# training (CursorMoved credit + timer-expiry stop + JSONL write +
# shared end-screen handoff), visual_motion training, lesson
# open/teardown, :VfList and :VfChart open/close, the chart nav keys
# (V to the dashboard), and an E-number scan of
# :messages.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"

command -v nvim >/dev/null 2>&1 || { echo "SKIP: nvim not installed"; exit 0; }

# NOTE: keep the XXXXXX at the very END of each template, with no
# extension after it. BSD/macOS mktemp only substitutes trailing X's —
# `...-XXXXXX.sock` is left LITERAL there, so every run would reuse the
# same fixed path. Once an interrupted run leaves that socket behind,
# the next server can't bind it (but stays alive headless), and the RPC
# probe connects to a dead socket forever. Trailing X's = a unique path
# per run on both BSD and GNU mktemp.
SOCK="$(mktemp -u /tmp/vf-smoke-sock-XXXXXX)"
XDG="$(mktemp -d /tmp/vf-smoke-xdg-XXXXXX)"
# Capture the server's own stdout/stderr so a startup crash is
# diagnosable instead of a bare "did not come up".
SRVLOG="$(mktemp /tmp/vf-smoke-srv-XXXXXX)"

# mktemp -u only prints the name; make sure nothing stale sits there so
# nvim's --listen can bind cleanly.
rm -f "$SOCK"
XDG_DATA_HOME="$XDG" nvim --headless --listen "$SOCK" --clean \
  --cmd "set rtp^=$ROOT" >"$SRVLOG" 2>&1 &
NVPID=$!
cleanup() {
  nvim --server "$SOCK" --remote-send ':qa!<CR>' </dev/null >/dev/null 2>&1
  kill "$NVPID" >/dev/null 2>&1
  rm -rf "$XDG" "$SOCK" "$SRVLOG"
}
trap cleanup EXIT

# `</dev/null` is load-bearing: a `--remote-expr`/`--remote-send` client
# with a TTY on stdin (i.e. run from an interactive shell or inside
# tmux) ATTACHES A FULL UI instead of acting as a thin remote client.
# That wraps the result in alt-screen escape codes (so `= "1"` never
# matches → "did not come up") and can deadlock when many spawn into
# the same pane. Redirecting stdin makes isatty() false → no UI.
NV() { nvim --server "$SOCK" --remote-expr "$1" </dev/null 2>/dev/null; }
NS() { nvim --server "$SOCK" --remote-send "$1" </dev/null >/dev/null 2>&1; }
# wait() runs nvim's event loop, so this both sleeps and lets pending
# input/timers/autocmds process — the settling primitive between keys.
settle() { NV 'wait(200, {-> 0}, 50)' >/dev/null; }
# Sub-second sleep. perl is the precise path; fall back to sleep(1) so
# a missing/erroring perl can't turn the readiness loop into a busy
# spin that blows through the window before the server binds.
nap() { perl -e 'select(undef,undef,undef,$ARGV[0])' "$1" 2>/dev/null || sleep "$1"; }

# Wait for the server to answer RPC. The RPC probe itself is the only
# reliable readiness signal: a successful remote-expr means the server
# is up and listening. (Do NOT gate on `test -S "$SOCK"` — on macOS
# that can read "absent" for a beat after nvim is already serving RPC,
# which spuriously fails the whole check.) We spawn a fresh client each
# poll, so give it a generous window (~30s) — a loaded machine (e.g.
# right after the nvim suite in `make test`) can be slow to start this
# second nvim. Bail early, with the server's log, if it died outright.
up=0
for _ in $(seq 1 150); do
  if ! kill -0 "$NVPID" 2>/dev/null; then
    echo "FATAL: server nvim exited during startup"
    [ -s "$SRVLOG" ] && sed 's/^/  /' "$SRVLOG"
    exit 1
  fi
  if [ "$(NV 1)" = "1" ]; then up=1; break; fi
  nap 0.2
done
if [ "$up" != "1" ]; then
  echo "FATAL: nvim RPC server did not come up within ~30s"
  echo "  socket present: $([ -S "$SOCK" ] && echo yes || echo no)"
  echo "  server alive:   $(kill -0 "$NVPID" 2>/dev/null && echo yes || echo no)"
  [ -s "$SRVLOG" ] && { echo "  server log:"; sed 's/^/    /' "$SRVLOG"; }
  exit 1
fi

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
drill_count=$(ls "$ROOT"/autoload/vimfluency/drills/*.vim | wc -l | tr -d ' ')
chk "registry has $drill_count drills (one per file)" "$drill_count" "$(NV 'len(vimfluency#discover_drills())')"
chk "16 Vf* commands" 16 "$(NV 'len(getcompletion("Vf", "command"))')"

echo "== arg validation =="
NS ':VfTrain save_vs_quit abc<CR>'; settle
chk "bad duration rejected, no session" "" "$(NV 'vimfluency#statusline()')"

echo "== mode_switch training: ModeChanged credit + VfQuit escape =="
NS ':VfTrain switch_mode_to_insert 30<CR>'; settle
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
chk "end screen opened after stop" 1 "$(NV 'bufexists("vf-complete")')"
NS 'Q'; settle
chk "end screen Q closes it" 0 "$(NV 'bufexists("vf-complete")')"

echo "== motion training: CursorMoved credit + timer expiry =="
NS ':VfTrain move_to_line_edges_start_end 5<CR>'; settle
chk "session started" 1 "$(NV '!empty(vimfluency#statusline())')"
for _ in 1 2 3 4 5; do NS '0'; settle; NS '$'; settle; done
chk "timer expired the session" 0 "$(NV 'wait(8000, {-> empty(vimfluency#statusline())}, 200)')"
chk "second JSONL record" 2 "$(log_lines)"
chkge "motion items credited" 1 "$(NV 'json_decode(readfile(vimfluency#log_dir() . "/sessions.jsonl")[-1])["items_correct"]')"
chk "end screen reopened" 1 "$(NV 'bufexists("vf-complete")')"
NS 'Q'; settle

echo "== visual_motion training =="
NS ':VfTrain visual_select_single_char_left_right 30<CR>'; settle
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

echo "== change_inside_around_tag training: cit/cat credit_on_text_typed =="
# The change-kind tag drill deletes the text object AND enters insert,
# then credits via TextChangedI when the typed buffer matches — a path
# run.sh (no event loop) can't exercise. Read each item's expected
# motion (cit/cat), press it, type the fixed replacement; the c-delete
# fires before InsertEnter, so the first_text_change_pending guard must
# absorb the removed state for credit to land.
NS ':VfTrain change_inside_around_tag 30<CR>'; settle
chk "session started" 1 "$(NV '!empty(vimfluency#statusline())')"
# NO trailing <Esc>: the TextChangedI credit fires on the typed payload
# and the runner Escs itself. A manual Esc races InsertLeave (which
# resets insert_entered for credit_on_text_typed drills) ahead of the
# deferred credit and would kill it.
for _ in 1 2 3; do
  exp="$(NV 'vimfluency#_test_state().current_item.expected_motion')"
  NS "${exp}foo"; settle
done
chkge "cit/cat credited via TextChangedI" 3 "$(NV 'vimfluency#_test_state().items_correct')"
NS ':VfQuit<CR>'; settle; nap 0.5; settle
chk "VfQuit ended session" "" "$(NV 'vimfluency#statusline()')"
NS 'Q'; settle

echo "== copy_line_to_target: yy->nav->P + show_target green =="
# First yank/paste drill: editing kind that opts back into the green
# target cell (show_target) because the destination is the cue, not a
# red range. Drives the real combo and checks buffer-state credit.
NS ':VfTrain copy_line_to_target 60<CR>'; settle
chk "session started" 1 "$(NV '!empty(vimfluency#statusline())')"
chkge "green destination cue shown (show_target)" 1 "$(NV 'len(filter(getmatches(), "v:val.group==#\"VfTarget\""))')"
chk "no red range (paste has nothing to delete)" 0 "$(NV 'len(filter(getmatches(), "v:val.group==#\"VfDeletion\""))')"
for _ in 1 2 3; do
  s="$(NV 'vimfluency#_test_state().current_item.start[0]')"
  d="$(NV 'vimfluency#_test_state().current_item.target[0]')"
  NS 'yy'; settle
  if [ "$d" -gt "$s" ]; then NS "$((d-s))j"; else NS "$((s-d))k"; fi; settle
  NS 'P'; settle
done
chkge "yy->nav->P credited (buffer-state)" 3 "$(NV 'vimfluency#_test_state().items_correct')"
NS ':VfQuit<CR>'; settle; nap 0.5; settle
chk "VfQuit ended session" "" "$(NV 'vimfluency#statusline()')"
NS 'Q'; settle

echo "== lesson open + teardown =="
NS ':VfLearn move_single_char_up_down_left_right<CR>'; settle
chk "lesson buffer name" "vf-lesson-move_single_char_up_down_left_right" "$(NV 'bufname("%")')"
chkge "lesson frame rendered" 3 "$(NV 'line("$")')"
NS ':VfQuit<CR>'; settle; nap 0.3; settle
chk "lesson torn down" 0 "$(NV 'bufexists("vf-lesson-move_single_char_up_down_left_right")')"

echo "== bare :Vf opens the dashboard =="
NS ':Vf<CR>'; settle
chk ":Vf opens dashboard" 1 "$(NV 'bufexists("vf-dashboard-table")')"
NS 'q'; settle
chk "dashboard q closes it" 0 "$(NV 'bufexists("vf-dashboard-table")')"

echo "== list + chart open/close =="
NS ':VfList<CR>'; settle
chk "list opens" 1 "$(NV 'bufexists("vf-list")')"
NV 'win_gotoid(win_findbuf(bufnr("vf-list"))[0])' >/dev/null
NS 'q'; settle
chk "list q closes it" 0 "$(NV 'bufexists("vf-list")')"
NS ':VfChart move_to_line_edges_start_end<CR>'; settle
chk "chart opens" 1 "$(NV 'bufexists("vf-chart-move_to_line_edges_start_end")')"
# V navigates from the chart straight to the dashboard (loop).
NS 'V'; settle
chk "chart V opens dashboard" 1 "$(NV 'bufexists("vf-dashboard-table")')"
# I navigates from the dashboard to the flat list (loop).
NS 'I'; settle
chk "dashboard I opens list" 1 "$(NV 'bufexists("vf-list")')"
NV 'win_gotoid(win_findbuf(bufnr("vf-list"))[0])' >/dev/null
NS 'q'; settle
chk "list q closes it" 0 "$(NV 'bufexists("vf-list")')"

echo "== error scan =="
errs="$(NV 'execute("messages")' | grep -cE 'E[0-9]+:' || true)"
chk "no E-number errors in :messages" 0 "$errs"
if [ "$errs" != "0" ]; then NV 'execute("messages")' | grep -E 'E[0-9]+:'; fi

echo
if [ "$fail" = "0" ]; then echo "SMOKE PASS (nvim $(nvim --version | head -1 | cut -d' ' -f2))"
else echo "SMOKE FAIL"; fi
exit "$fail"
