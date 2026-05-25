# Base Vim Pinpoint Catalog

Scope: vim ≥ 7 with no plugins, no LSP, no fuzzy finder. The subset present on every Linux server.

Conventions:
- **Training format** — what the learner sees and what they produce.
  - `S→K` = show before/after buffer state, learner types minimal keystrokes
  - `K→S` = show keystrokes, learner predicts buffer state
  - `Disc` = discrimination: pick the more efficient of two equivalent sequences
  - `Recall` = name the keystroke that does X
- **Aim** — starting guess for fluency frequency (correct/min). All aims are placeholders; the long-term plan is community-aggregated rates (see `.strategy/data-contribution.md`). Bias for starting guesses: simple-motion behaviors 40–60/min, mid-discrimination 30–40/min, multi-keystroke or multi-axis 20–30/min.
- **Prereqs** — pinpoint IDs that must reach aim before drilling this one. **Diagnostic, not gating** under the exhaustive-hierarchy framework — `:VfList` surfaces blocked prereqs as suggested fallbacks if a rate plateaus, but doesn't lock a learner out of any pinpoint.
- **Status** — rows below are a mix of:
  - **Shipped** — has a `p<ID>.vim` file in `autoload/vimfluency/pinpoints/`; appears in `:VfList`.
  - **Specced (pre-pivot)** — written before the May 2026 framework pivot from grammatical to behavioral decomposition. Many wide-grid spec rows (e.g., `2.6` Recall over 10 operators, `8.x` single-cell recalls) need re-spec under the exhaustive non-gaming floor before they can be built. Flagged where applicable.
  - **Specced (post-pivot)** — written in slice-01 or slice-02; consistent with the framework but not yet built.

---

## Tier 0 — Survival (must be automatic before anything else)

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| T0.1 | Enter/leave insert mode (`i`, `a`, `Esc`) | S→K | 50 | — |
| T0.2 | Open new line (`o`, `O`) | S→K | 40 | T0.1 |
| T0.3a | Discriminate `:w` vs `:q` | Disc | 40 | — |
| T0.3b | Discriminate `:wq` vs `:q!` | Disc | 35 | T0.3a |
| T0.3c | Discriminate `:wq` vs `ZZ` (Ex vs normal-mode) | Disc | 35 | T0.3b |
| T0.3d | Discriminate `:q!` vs `ZQ` (Ex vs normal-mode) | Disc | 35 | T0.3b |
| T0.4 | Undo / redo (`u`, `Ctrl-r`) | S→K | 50 | — |
| T0.5 | Mode awareness (given a screen, press the mode's key — n/i/v/r/:) | Recall | 120 | — |



Composite emergence test: "open a file, change one word, save, quit" cold, ≤ 5 s.

---

## Tier 1 — Motions (cursor movement only, no operator)

### 1A — Char & line

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 1A.1 | `hjkl` (4-cell, all directions) | S→K | 60 | T0 |
| 1A.2 | Line start/first-non-blank/end (`0`, `^`, `$`, `g_`) | S→K | 50 | T0 |
| 1A.3 | `h l` (narrower horizontal-direction sibling of 1A.1) | S→K | 60 | T0 |
| 1A.4 | `j k` (narrower vertical-direction sibling of 1A.1) | S→K | 60 | T0 |
| 1A.5 | `0 $` (narrower line-edge sibling of 1A.2; drops the whitespace axis) | S→K | 55 | T0 |

### 1B — Word

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 1B.1 | Forward/back word start (`w`, `b`) | S→K | 45 | 1A |
| 1B.2 | Forward/back word end (`e`, `ge`) | S→K | 40 | 1A |
| 1B.3 | WORD variants (`W`, `B`, `E`) — *needs re-spec*: split into atomic-behavior pinpoints (`W` discriminated against `w`, `B` against `b`, `E` against `e`) per slice-01's 1B stress test. | S→K | 45 | 1B.1, 1B.2 |
| 1B.4 | `w/W` discrimination on punctuated text — *under exhaustive*: this is a composite-discrimination drill prereq'd on the 1B.3 splits. | Disc | 30 | 1B.1, 1B.2, 1B.3 |

### 1C — Char-find on line

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 1C.1 | `f{c}`, `F{c}` | S→K | 50 | 1A |
| 1C.2 | `t{c}`, `T{c}` | S→K | 45 | 1C.1 |
| 1C.3 | Repeat last find (`;`, `,`) | S→K | 40 | 1C.1, 1C.2 |
| 1C.4 | Discriminate `f` vs `t` (which lands ON vs BEFORE the char) | Disc | 35 | 1C.1, 1C.2 |

### 1D — Buffer/screen jumps

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 1D.1 | Top/bottom (`gg`, `G`) — clean 2-cell direction discrimination. | S→K | 50 | T0 |
| 1D.2 | Line number (`{n}G`, `:{n}`) — *needs re-spec*: two paths to same outcome; pair-with-`gg/G` or pair-with-each-other? | S→K | 40 | 1D.1 |
| 1D.3 | Screen position (`H`, `M`, `L`) — 3-cell screen-vertical-thirds. | S→K | 40 | T0 |
| 1D.4 | Screen scroll (`Ctrl-d`, `Ctrl-u`, `Ctrl-f`, `Ctrl-b`, `zz`, `zt`, `zb`) — *needs re-spec*: 7 cells across multiple axes (half-page vs full-page vs cursor-position). Split. | S→K | 35 | T0 |

### 1E — Block / paragraph / sentence

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 1E.1 | Sentence (`(`, `)`) | S→K | 40 | 1A |
| 1E.2 | Paragraph (`{`, `}`) | S→K | 40 | 1A |
| 1E.3 | Match brace (`%`) | S→K | 40 | 1A |

### 1F — Search

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 1F.1 | `/pat`, `?pat`, `n`, `N` — *needs re-spec*: 4 cells across two axes (direction × forward-or-reverse + first-match-or-next). Split into `/?` and `n/N` pairs. | S→K | 35 | 1A |
| 1F.2 | Word-under-cursor (`*`, `#`) — clean 2-cell direction discrimination. | S→K | 40 | 1A |
| 1F.3 | History recall (`/` then `↑`) — *single-cell*; needs a partner (e.g., re-issue last search vs. recall earlier search) or environment variation per the non-gaming floor. | Recall | 25 | 1F.1 |

---

## Tier 2 — Linewise operator behaviors

Under the exhaustive framework, "operators alone" isn't a behavioral category — pressing `d` does nothing observable. What lives at this tier is the *linewise* forms (`dd`, `yy`, `cc`, `>>`, `==`) where doubling the operator IS a complete behavior with an observable outcome.

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 2.1 | Discriminate `x` vs `dd` (single-char delete vs linewise; navigate then operate) | Disc | 35 | T0 |
| 2.2 | Discriminate `>>` vs `<<` (indent vs dedent direction) | Disc | 35 | T0 |
| 2.3 | Change line (`cc`/`S`) — *needs re-spec*: aliases for the same behavior, not a discrimination axis. Pair with `dd` (delete vs change linewise) or kill the row. | S→K | 45 | T0 |
| 2.4 | Yank line (`yy`/`Y`) — *needs re-spec*: aliases, not a minimal pair. Pair with `dd` (delete vs yank linewise) or kill. | S→K | 45 | T0 |
| 2.5 | Filter line (`==`, `!!`) — *needs re-spec*: two different operators sharing only linewise-ness; not a clean discrimination axis. | S→K | 30 | T0 |
| 2.6 | Recall the operator family (`d`, `c`, `y`, `>`, `<`, `=`, `gu`, `gU`, `~`, `!`) — *needs re-spec*: 10-cell Recall is the recall-is-discrimination antipattern. Break into binary discriminations per `[[2026-05-14-recall-is-discrimination]]`. Probably absorbed into Tier 4 composite drills anyway. | Recall | 30 | — |

---

## Tier 3 — Text objects (drilled with a verb)

The original "text objects taught isolated" framing doesn't work under the exhaustive framework: a bare text object (`i"`, `iw`, `a{`) isn't a behavior — typing it in normal mode produces nothing observable. See [`grammar-isnt-curriculum`](.strategy/learnings/2026-05-19-grammar-isnt-curriculum.md). The replacement framing: pair every text-object pinpoint with the smallest containing verb (visual mode `v` is the cheapest — `vi"` selects, the selection IS observable). The shipped 3.2a/3.2b are recall-style placeholders and will be replaced by visual-mode pinpoints when the runner grows a `visual` kind. See `.strategy/catalog-v2/slice-02-quote-text-objects.md` for the post-pivot spec of this tier.

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 3.1 | Word objects (`iw`, `aw`, `iW`, `aW`) — *needs re-spec*: see slice-03 (planned) for word-object behaviors paired with verbs. | Recall | 40 | 1B |
| 3.2a | Inner quote recall: `i"` vs `i'` — *to be replaced* by a `vi"` visual-mode pinpoint (slice-02 design). Shipped as a placeholder. | Recall | 40 | T0 |
| 3.2b | Inner quote recall + backtick — *to be replaced* alongside 3.2a. | Recall | 35 | 3.2a |
| 3.3 | Bracket objects (`i(`, `a(`, `i[`, `a[`, `i{`, `a{`, `i<`, `a<`) — *needs re-spec*: 8 cells across two axes. Apply the slice-02 framework. | Recall | 40 | T0 |
| 3.4 | Sentence/paragraph (`is`/`as`, `ip`/`ap`) — *needs re-spec*. | Recall | 35 | 1E |
| 3.5 | Tag (`it`, `at`) — *needs re-spec* per slice-02 framework. | Recall | 30 | 3.3 |
| 3.6 | Discriminate `i` vs `a` (inner vs around) — *under exhaustive*: this is the containment-axis discrimination that lives inside each text-object family (see slice-02's containment-axis pinpoint), not a separate cross-family row. Likely dissolves. | Disc | 35 | 3.1–3.5 |

---

## Tier 4 — Operator × {motion, text object}

Composite behaviors composing a Tier 2 operator with a motion or text object. Each row drills canonical exemplars; prereqs are the relevant operator and motion/text-object groups at aim.

Rows below are the narrower 2-cell direction discriminations under the exhaustive-hierarchy framework. The earlier wide-grid spec rows (`4.2-4.6` covering line motions, char-find, text objects, search, match) have been repurposed slice-by-slice; remaining rows are explicit pinpoints with their own files.

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 4.1 | `dw db` (delete + word-start motion, direction discrimination) | S→K | 60 | 2.1, 1B.1 |
| 4.3 | `d0 d$` (delete + line-edge motion, direction discrimination) | S→K | 35 | 1A.5 |
| 4.4 | `dl dh` (delete + char motion, direction discrimination) | S→K | 40 | 1A.3 |
| 4.5 | `dj dk` (delete + line-extend, direction discrimination, linewise) | S→K | 30 | 1A.4 |

Deferred / not yet built (placeholders for future slice work):
- 4.2 — `de dge` (delete + word-end motion). Defers on whitespace edge-cases (`de` from start-of-word leaves a double space; needs design).
- 4.6 — composite-discrimination drill mixing 4.1–4.5 once those are at aim.
- Operator + char-find, text object, search, match — slice-02 onward will spec these as narrower pinpoints under the same framework.

---

## Tier 5 — Counts and repetition

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 5.1 | Counted motion (`5w`, `3j`, `2}`) — varies count and motion; design with environment variation so the count is genuinely chosen, not memorized. | S→K | 40 | 1 |
| 5.2 | Counted operator (`3dd`, `2yy`) — similar; design pass needed. | S→K | 35 | 2 |
| 5.3 | Count between operator and motion (`d3w`, `c2f,`) | S→K | 30 | 4 |
| 5.4 | Dot repeat (`.`) — predict effect | K→S | 35 | 2 |
| 5.5 | Discriminate when `.` is enough vs when macro is needed — *under review*: meta-discrimination is hard to operationalize as a per-item probe; may need to live as a Tier-13-style composite task instead. | Disc | 20 | 5.4, 12 |

---

## Tier 6 — Insert-mode editing & small fixes

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 6.1 | Enter insert at variants (`i`, `a`, `I`, `A`) — *overlaps with T0.1* (which currently covers `i/a/Esc`); the 4-cell positional discrimination is a natural broader sibling of T0.1. Consolidate. | S→K | 50 | T0 |
| 6.2 | Open above/below (`o`, `O`) — *duplicate of T0.2*. Delete this row. | S→K | 40 | T0 |
| 6.3 | Replace one char (`r{c}`), enter replace mode (`R`) — *needs re-spec*: two different actions sharing only the letter R. Split into `r{c}` (alone or with a paired single-char-edit) and `R` (mode entry, pairs with `i`/`a`/etc. positional class). | S→K | 40 | T0 |
| 6.4 | Delete char (`x`, `X`) — clean 2-cell direction discrimination; slice-01 enumerated this as an atomic-edit pinpoint not yet shipped. | S→K | 50 | T0 |
| 6.5 | Substitute char/line (`s`, `S`) — 2-cell on scope (char vs line). Reasonable as one pinpoint. | S→K | 35 | T0 |
| 6.6 | Change-to-end (`C`, `D`, `Y`) — 3-cell with shared "to-end" and varying operator (change/delete/yank). | S→K | 40 | 2, 1A |
| 6.7 | Join lines (`J`, `gJ`) — clean 2-cell on whitespace handling. | S→K | 35 | T0 |
| 6.8 | In-insert: backspace word (`Ctrl-w`), kill line (`Ctrl-u`) — *needs re-spec*: two unrelated keys; not a discrimination axis. Split or pair each with a more natural sibling. | S→K | 30 | T0 |
| 6.9 | In-insert: literal char (`Ctrl-v{c}`), digraph (`Ctrl-k`) — *needs re-spec*: same problem as 6.8. | Recall | 20 | T0 |

---

## Tier 7 — Visual mode

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 7.1 | Enter visual (`v`, `V`, `Ctrl-v`) — *needs re-spec*: `v` alone isn't a behavior (no selection → no observable outcome). Per the exhaustive framework, the smallest v-class behavior pairs visual entry with a 1-cell extension (`vh`/`vl`/`vj`/`vk`). Slice-02 lists v-class as an unbuilt prereq. | S→K | 45 | T0 |
| 7.2 | Extend selection by motion | S→K | 35 | 7.1, 1 |
| 7.3 | Operate on selection (`d`, `c`, `y`, `>`, `<`, `~`) — *needs re-spec*: 6-cell operator discrimination on top of an active selection. Apply the slice-02 verb-axis framework. | S→K | 35 | 7.1, 2 |
| 7.4 | Swap anchor (`o`, `O` in visual) — clean 2-cell (head vs tail of selection). | S→K | 30 | 7.1 |
| 7.5 | Reselect last (`gv`) — *single-cell*; needs partner (e.g., pair with `gv` after different visual modes, or env-vary the starting state). | S→K | 30 | 7.1 |
| 7.6 | Block insert/append on selection (`I`, `A` after `Ctrl-v`) — clean 2-cell on insert position (before/after block). | S→K | 25 | 7.1 |
| 7.7 | Discriminate visual+operator vs operator+motion — *under review*: meta-discrimination about strategy choice. Closer to a Tier-13-style task than a fluency drill. | Disc | 20 | 4, 7.3 |

---

## Tier 8 — Yank, paste, registers

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 8.1 | Paste (`p`, `P`) — predict where it lands for charwise vs linewise. Clean 2-cell direction discrimination. | K→S | 40 | 2.3 |
| 8.2 | Named register (`"ay`, `"ap`) — 2-cell yank vs paste with same register. Reasonable as one pinpoint. | S→K | 30 | 8.1 |
| 8.3 | Last-yank register (`"0p`) — *single-cell*; pair with `"_d` or env-vary the buffer state. | Recall | 25 | 8.1 |
| 8.4 | Black hole (`"_d`) — *single-cell*; pair with regular `d` (with/without polluting register) or `"0p` (yank register vs black hole). | Recall | 25 | 8.1 |
| 8.5 | Inspect registers (`:reg`) — *single-cell*; environment variation (different register contents per item) required. | Recall | 20 | 8.1 |
| 8.6 | System clipboard when available (`"+y`, `"+p`) — clean 2-cell yank vs paste with `+` register. | Recall | 25 | 8.1 |
| 8.7 | Discriminate `p` vs `P` placement after charwise vs linewise yank — 4-cell across two axes (paste direction × yank-kind). Solid composite-discrimination row. | Disc | 25 | 8.1 |

---

## Tier 9 — Marks and jumps

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 9.1 | Set/jump local mark (`ma`, `'a`, `` `a ``) — 3-cell set/jump-line/jump-exact. Reasonable. | S→K | 35 | T0 |
| 9.2 | Discriminate `'a` (line) vs `` `a `` (exact pos) — clean 2-cell on jump precision. | Disc | 30 | 9.1 |
| 9.3 | Auto marks (`''`, `` `` ``, `'.`, `` `. ``, `'^`) — *needs re-spec*: 5-cell recall across two axes (which auto-mark × line/exact). Split per recall-is-discrimination. | Recall | 25 | 9.1 |
| 9.4 | Jump list (`Ctrl-o`, `Ctrl-i`) — clean 2-cell direction discrimination. | S→K | 30 | T0 |
| 9.5 | Change list (`g;`, `g,`) — clean 2-cell direction discrimination. Probably S→K, not Recall (the buffer state changes the cursor jumps to). | S→K | 20 | T0 |

---

## Tier 10 — Search & substitute

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 10.1 | Basic substitute (`:s/a/b/`, `:s/a/b/g`) — 2-cell on single-vs-global flag. | S→K | 25 | 1F |
| 10.2 | Whole file (`:%s/a/b/g`) — *single-cell*; pair with `:s/.../g` (one line vs whole file). | S→K | 30 | 10.1 |
| 10.3 | Confirm flag (`:%s/a/b/gc`) — *single-cell*; pair with non-confirm `:%s/a/b/g`. | Recall | 25 | 10.1 |
| 10.4 | Range forms (`:.,+5s`, `:'a,'bs`, `:'<,'>s`) — 3-cell across range-spec types. Reasonable. | S→K | 20 | 10.1, 9 |
| 10.5 | Backref (`:s/\(foo\)_\(bar\)/\2_\1/`) — *needs re-spec*: very specific, not obviously paired with another behavior. May belong as a Tier-13 composite. | S→K | 15 | 10.1 |
| 10.6 | `\v` very-magic mode — *single-cell*; pair with default magic or `\V` no-magic for the discrimination axis. | Recall | 20 | 10.1 |
| 10.7 | Magic-char awareness (`.` `*` `\+` `\?` `\(\)` in default magic) — multi-cell discrimination on regex metachars. Reasonable. | Disc | 20 | 10.1 |
| 10.8 | `:g/pat/d`, `:v/pat/d` — clean 2-cell on inverted-pattern. | S→K | 25 | 10.1 |
| 10.9 | `:g/pat/cmd` with arbitrary cmd — *needs re-spec*: open-ended cmd is hard to drill as a closed-set discrimination; environment variation across cmd types would work. | S→K | 15 | 10.8 |

---

## Tier 11 — Ex commands & buffers

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 11.1 | Range delete/yank (`:.,+5d`, `:1,$y`) | S→K | 25 | T0 |
| 11.2 | Shell out (`:!cmd`) | S→K | 30 | T0 |
| 11.3 | Read shell into buffer (`:r !cmd`, `:r file`) | S→K | 25 | T0 |
| 11.4 | Filter selection through shell (`:'<,'>!sort`) | S→K | 20 | 7, 11.2 |
| 11.5 | Edit/list/switch buffers (`:e`, `:ls`, `:b{n}`, `:bn`, `:bp`, `:bd`) — *needs re-spec*: 6 unrelated commands; split into discrimination pairs (e.g., `:bn/:bp` direction, `:e/:b{n}` open-by-path-vs-id). | Recall | 25 | T0 |
| 11.6 | Window splits (`:sp`, `:vsp`, `Ctrl-w {hjkl}`, `Ctrl-w {HJKL}`, `Ctrl-w =`) — *needs re-spec*: 3+ unrelated families (create-split, move-cursor, move-window) bundled. Split. | S→K | 30 | T0 |
| 11.7 | Tabs (`:tabnew`, `gt`, `gT`) — 3-cell where the discrimination is create-vs-navigate-direction. Reasonable; could split `:tabnew` from `gt/gT`. | S→K | 25 | T0 |

---

## Tier 12 — Macros

| ID | Pinpoint | Training | Aim | Prereqs |
|---|---|---|---|---|
| 12.1 | Record/replay (`qa`...`q`, `@a`, `@@`) — 3-cell across record-vs-replay-vs-replay-last. Reasonable. | S→K | 20 | 5.4 |
| 12.2 | Counted replay (`5@a`) — *single-cell*; pair with uncounted `@a` (drill the count axis). | S→K | 18 | 12.1 |
| 12.3 | Append to register (`qA`) — *single-cell*; pair with overwrite `qa` (case axis). | Recall | 15 | 12.1 |
| 12.4 | Discriminate when `.` suffices vs when `q` is needed — *under review*: same meta-discrimination concern as 5.5 and 7.7. May belong as Tier-13 task. | Disc | 15 | 12.1, 5.4 |

---

## Tier 13 — Composite editing tasks

Real-world editing tasks that compose many lower-tier behaviors. Useful for spotting curriculum gaps — a composite that should be easy but feels hard points at a component that isn't fluent enough. Training = task description + starting buffer; measure time-to-completion and keystroke efficiency vs an expert reference.

The "Components exercised" column lists the rough pinpoint regions the task touches. The references were written under the pre-pivot framework; some IDs (especially Tier 4) have since been re-specced (e.g., the old `4.4` "op + text object" is now several narrower pinpoints). Treat the column as a *region hint*, not a strict ID list, until the composites are actually built.

| ID | Composite | Components (region hints) |
|---|---|---|
| C.1 | Rename a variable inside the current function | 1F.2 (word search), 9.1 (marks), 10.4 (range substitute) |
| C.2 | Wrap a block in `try:`/`except:` (or `if (…) { }`) | Tier 7 (visual), 6.6 (change-to-end), 5.4 (dot) |
| C.3 | Sort a contiguous block of imports alphabetically | 11.4 (filter through shell) |
| C.4 | Delete every line containing `TODO` | 10.8 (`:g/pat/d`) |
| C.5 | Reflow a paragraph to 80 cols (`gqap`) | Tier 2 (operators), 3.4 (paragraph object) |
| C.6 | Swap two arguments in `foo(a, b)` | Tier 4 (op + text object — note: new framework splits this), 8.1 (paste) |
| C.7 | Indent a function body one level | Tier 7 (visual), Tier 2 (`>>`) |
| C.8 | Convert `snake_case` → `camelCase` for one identifier | Tier 12 (macros) |
| C.9 | Comment out a contiguous block | 7.6 (block insert) |
| C.10 | Move the current line below the next 3 lines | 2.1 (`dd`), 5.1 (counted motion), 8.1 (paste) |

Pass criterion: keystroke count within ~120% of expert reference, completed without consulting docs.

---

## Aim derivation note

All aim numbers above are **starting guesses**, not empirically derived. Long-term plan: aggregate per-behavior rate distributions across the user community and let learners compare their rates to the population (see `.strategy/data-contribution.md`). Until that data exists, aims serve as guidance; the published distribution will replace them.

## Component DAG summary

```
T0 (survival)
 ├─ Tier 1 (motions: 1A → 1B → 1C → 1D, 1E, 1F)
 ├─ Tier 2 (linewise operator behaviors — dd, yy, cc, >>, ==)
 ├─ Tier 3 (text objects, drilled with a verb — see slice-02)
 │
 ├─ Tier 4 (operator × motion / operator × text-object)
 ├─ Tier 5 (counts, dot)
 ├─ Tier 6 (insert-mode editing)
 ├─ Tier 7 (visual)
 ├─ Tier 8 (registers/paste)
 ├─ Tier 9 (marks/jumps)
 ├─ Tier 10 (search/substitute)
 ├─ Tier 11 (ex/buffers/windows)
 └─ Tier 12 (macros)
       │
       └─ Tier 13 (composite editing tasks — validation tasks, not training)
```

The DAG above describes the *grammatical* tier structure preserved from the original catalog spec. Under the exhaustive-hierarchy framework, the actual behavioral DAG is non-linear and lives in two places:

- **`:VfHierarchy`** — generated at runtime from each pinpoint's `prereqs` and `parallel_to` metadata; shows what's currently shipped.
- **`.strategy/catalog-v2/slice-*.md`** — design docs for the post-pivot pinpoint layout, slice by slice.
