#!/usr/bin/env bash
# Seed honest, climbing-rate session history for MANY drills into a SANDBOX
# XDG_DATA_HOME, so the dashboard / list / chart / history previews show a
# populated "learner mid-journey" instead of empty state. Writes ONLY to
# the sandbox (default /tmp/vf-preview) — never your real data. Truncates
# on each run, so it's safe to re-run before every render.
#
#   usage: ./seed-history.sh [XDG_DATA_HOME]
#
# Generalizes the website repo's single-drill seed-demo-sessions.sh: a
# curated spread across families, each drill at a different stage (some
# already at aim, some mid-climb, some just started). Per-command
# breakdowns come from each drill's real `keys`, with the last command a
# few /min behind so the dashboard's `← slow` marker shows. The remaining
# drills (no history) correctly render as not-yet-started.
set -euo pipefail

XDG="${1:-/tmp/vf-preview}"
DIR="$XDG/vimfluency"
LOG="$DIR/sessions.jsonl"
PLUGIN="$(cd "$(dirname "$0")/.." && pwd)"
REG="$(mktemp -t vf-reg.XXXXXX.json)"
trap 'rm -f "$REG"' EXIT
mkdir -p "$DIR"

# Current id/name/aim/keys straight from the registry, so the seeded
# records join to real drills and survive renames.
vim -u NONE -N --cmd "set rtp^=$PLUGIN" -c 'runtime plugin/vimfluency.vim' -es \
  -c "call writefile([json_encode(map(values(vimfluency#discover_drills()), {_,v -> {'id':v.id,'name':v.name,'aim':v.aim,'keys':get(v,'keys','')}}))], '$REG')" \
  -c 'qa!' >/dev/null 2>&1

python3 - "$LOG" "$REG" <<'PY'
import json, sys
from datetime import datetime, timedelta

log_path, reg_path = sys.argv[1], sys.argv[2]
reg = {d["id"]: d for d in json.load(open(reg_path))}

# Curated learner journey: (drill_id, n_sessions, end_rate_as_fraction_of_aim).
# >1.0 = past aim (fluent), ~1.0 = at aim, <1.0 = still climbing.
PLAN = [
    ("move_single_char_left_right",                 8, 1.15),
    ("move_single_char_up_down_left_right",         9, 1.10),
    ("move_to_word_start_forward_backward",        11, 1.05),  # flagship chart drill
    ("move_to_line_edges_start_end",                6, 1.00),
    ("move_to_char_forward_backward",               7, 0.90),
    ("move_to_word_end_forward_backward",           6, 0.80),
    ("save_vs_quit",                                7, 1.10),
    ("switch_mode_to_insert",                       6, 1.00),
    ("insert_before_after_char",                    6, 0.90),
    ("delete_single_char_left_right",               7, 0.95),
    ("delete_to_word_start_forward_backward",       8, 0.85),
    ("indent_vs_dedent",                            5, 0.80),
    ("visual_select_single_char_left_right",        5, 0.85),
]

now = datetime.now().replace(microsecond=0)
out = []

for di, (drill_id, n, end_frac) in enumerate(PLAN):
    d = reg.get(drill_id)
    if not d:
        continue  # drill renamed/retired — skip rather than seed a dangling id
    aim = d["aim"]
    motions = [m for m in d["keys"].split("/") if m] or ["?"]
    end_rate = max(1, round(aim * end_frac))
    start_rate = max(1, round(end_rate * 0.55))
    # Each drill's sessions land on distinct days, newest a few days back so
    # the live preview (if any) is "today"; older drills started further out.
    span_days = 4 + n * 2
    base_offset = 2 + di  # stagger start dates a little per drill
    for i in range(n):
        frac = i / (n - 1) if n > 1 else 1.0
        # smooth climb with a gentle S so it doesn't look ruler-straight
        eased = frac * frac * (3 - 2 * frac)
        rate = round(start_rate + (end_rate - start_rate) * eased)
        rate = max(1, rate)
        day = base_offset + round((1 - frac) * span_days)
        ts = (now - timedelta(days=day, minutes=di * 7)).strftime("%Y-%m-%dT%H:%M:%S")

        correct = rate  # 60s session => items ~= rate
        # errors fall as fluency rises
        err = max(0, round((aim * 0.22) * (1 - eased)))
        total_m = correct + err
        opt_m = correct
        eff = round(opt_m * 100.0 / total_m, 1) if total_m else 100.0

        # split the correct count across the drill's commands; last command
        # runs a few /min slower (the `← slow` discriminant).
        pm = {}
        k = len(motions)
        for mi, mk in enumerate(motions):
            mc = correct // k + (1 if mi < correct % k else 0)
            if mi == k - 1:
                mrate = max(1, rate - 6)      # slow one
                avg = 1.4
            else:
                mrate = rate + (3 if mi == 0 else 1)
                avg = 1.0
            mtime = round(mc * 60.0 / mrate, 1) if mrate else 0.0
            pm[mk] = {"correct": mc, "time_seconds": mtime,
                      "rate_per_min": float(mrate), "avg_motions": avg,
                      "avg_optimal": 1.0}

        out.append({
            "timestamp": ts, "drill_id": drill_id, "drill_name": d["name"],
            "aim": aim, "duration_seconds": 60, "elapsed_seconds": 60.0,
            "items_correct": correct, "items_skipped": 0, "items_hit": correct,
            "frequency_per_min": float(rate), "hits_per_min": float(rate),
            "miss_per_min": float(err), "errors_per_min": float(err),
            "total_motions": total_m, "total_optimal_motions": opt_m,
            "efficiency_pct": eff, "end_reason": "time", "only_filter": [],
            "per_motion": pm, "items": [],
        })

# oldest-first, like a real append-only log
out.sort(key=lambda r: r["timestamp"])
with open(log_path, "w") as f:
    for r in out:
        f.write(json.dumps(r) + "\n")
print(f"seeded {len(out)} sessions across "
      f"{len({r['drill_id'] for r in out})} drills -> {log_path}")
PY
