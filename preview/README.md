# Feature previews

Re-renderable GIF + MP4 previews of every Vim Fluency feature, for docs and
social. Lives in the plugin repo so it stays in lockstep with the features
it captures — change a feature, re-render its preview.

Two kinds of previews, both themed to match the editor (cyberdream) via
`_setup.tape`:

1. **Per-drill training** — auto-played `:VfDemo`, generated from the drill
   registry (one per drill, so adding a drill auto-produces its preview).
2. **Feature scenes** — hand-authored views and flows in `scenes/*.tape`
   (dashboard, list, chart, history, nav loop, end screen, lesson).

Needs `vhs` (`brew install vhs`, pulls `ttyd`) and `ffmpeg`. Run `make`
targets from this dir.

## Per-drill training previews

`:VfDemo <id>` plays the optimal motion for each generated item — the
cursor jumps to target and the `correct` / `rate` counters climb on their
own, then it auto-stops onto the end screen. No human typing, and demo
sessions never write the session log.

```sh
make verify              # render-free: assert :VfDemo plays EVERY drill
make verify DRILL=<id>   # ...just one
make preview DRILL=<id>  # generate + render one -> renders/<id>-train.{gif,mp4}
make previews            # generate + render all
make tapes               # generate the per-drill tapes only (no render)
```

## Feature scenes

```sh
make scene-list          # list available scenes
make scene NAME=<name>   # render one -> renders/scene-<name>.{gif,mp4}
make scenes              # render all scenes
```

Scenes that show data (`dashboard`, `list`, `chart`, `history`, `nav-loop`,
`end-screen`, `lesson`) seed a populated "learner mid-journey" history into
the sandbox first via **`seed-history.sh`** (an honest spread across
families — some drills at aim, some climbing, some new; the rest read as
not-yet-started). It writes ONLY to the sandbox `XDG_DATA_HOME`
(`/tmp/vf-preview`), never your real data.

The **lesson** scene auto-plays a whole `:VfLearn` lesson with
`:VfLearnDemo` (a dev-only command, like `:VfDemo`): it reads the rule
frames, performs each try-frame motion, applies the rule through the test
phase to graduation, and lands on the end screen.

## How it fits together

- **`_setup.tape`** — shared `Set`/`Env` (theme = cyberdream, dims, sandbox
  `XDG_DATA_HOME`). Source it FIRST; it launches nothing, so a scene can
  seed history before vim starts.
- **`_launch.tape`** — off-camera vim launch (plugin from `..`). Source it
  after `_setup` (and any seed step).
- **`_train.template.tape`** + **`gen-previews.sh`** — the per-drill
  generator; reads `discover_drills()` so the set always matches the
  shipped drills.
- **`verify-demo.sh`** + **`verify-demo.vim`** — render-free check that
  `:VfDemo` plays each drill (asserts the `correct` counter climbs). Catches
  a new drill whose kind the demo can't auto-play, without rendering.
- **`scenes/*.tape`** — one tape per feature/flow.
- **`render-scene.sh`** — renders scenes (reaps orphaned `ttyd` between).

`build/` (generated tapes) and `renders/` (GIFs/MP4s) are gitignored —
regenerate them; commit only curated hero assets.

## Notes

- Targets/items are randomly generated per render (vim's `rand()` isn't
  seeded), so re-renders differ in detail but tell the same story.
- VHS resolves `Source`/`Output` relative to the cwd, so always render from
  this dir (the `make` targets and scripts do).
- `vim -u NONE` is used (no colorscheme), so the cyberdream theme maps
  through the 16 ANSI colors — background, foreground, and the green target
  accent land exactly; full highlight groups don't apply.
- The flagship ≤30s **launch** demo (`demo.tape` + `seed-demo-sessions.sh`)
  is a separate marketing asset in the website repo, not here.
