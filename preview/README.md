# Per-drill preview generator

One `:VfTrain` preview GIF per drill, produced from a template so adding a
drill auto-produces its preview. Lives in the plugin repo (not the website
repo) so it stays in lockstep with the drills and the `:VfDemo` runner.

Every drill gets a self-driving training preview: `:VfDemo <id>` plays the
optimal motion for each generated item, so the cursor jumps to target and
the `correct` / `rate` counters climb on their own — no human typing, and
demo sessions never write to the session log or the contributed dataset.

## Use

```sh
make verify              # render-free: assert :VfDemo plays EVERY drill
make verify DRILL=<id>   # ...just one
make preview DRILL=<id>  # generate + render one drill's train GIF -> renders/
make previews            # generate + render all
make tapes               # generate tapes only (build/), no render
```

Needs `vhs` (`brew install vhs`, pulls `ttyd`) and `ffmpeg`.

## How it's put together

- **`gen-previews.sh`** reads the drill registry (`discover_drills()`), so
  the set of previews always matches the shipped drills — no hand-edited
  list. It fills `_train.template.tape` (which `Source`s `_setup.tape`, the
  shared theme/font/dims/launch) per drill into `build/<id>-train.tape`.
- **`_setup.tape`** is the shared VHS config + off-camera vim launch,
  `Source`d by every generated tape so the previews look like a set. The
  plugin is loaded from `..` (this dir is the repo root's `preview/`).
- **`verify-demo.sh`** (+ `verify-demo.vim`) is the render-free check: it
  runs the plugin headless and asserts the `correct` counter climbs for
  each drill. Use it instead of eyeballing GIFs — it catches a drill whose
  kind `:VfDemo` can't auto-play. It does NOT OCR rendered frames. (Runs
  vim under a real pty with a real typescript file; a `/dev/null`
  typescript stalls the event loop and timers never fire.)
- `build/` (tapes) and `renders/` (GIFs) are gitignored — regenerate them;
  commit only curated hero assets.

## Notes

- Targets are randomly generated per render (vim's `rand()` isn't seeded),
  so re-renders differ in detail but always tell the same story.
- **VfLearn previews are not generated yet** — lessons have `try` frames
  whose motions a generic template can't perform; that needs lesson
  auto-play (a `:VfDemo`-style extension to `:VfLearn`).
- The flagship ≤30s **launch** demo (`demo.tape` + `seed-demo-sessions.sh`)
  is a separate, marketing asset and lives in the website repo, not here.
