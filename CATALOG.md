# Base Vim Pinpoint Catalog

Scope: vim ≥ 7 with no plugins, no LSP, no fuzzy finder. The subset present on every Linux server.

Conventions:
- **Probe format** — what the learner sees and what they produce.
  - `S→K` = show before/after buffer state, learner types minimal keystrokes
  - `K→S` = show keystrokes, learner predicts buffer state
  - `Disc` = discrimination: pick the more efficient of two equivalent sequences
  - `Recall` = name the keystroke that does X
- **Aim** — starting guess for fluency frequency (correct/min). All aims are placeholders to be revised by data. Bias: tool-level pinpoints high (40–60/min), text-object combos mid (20–30/min), composites low (3–8/min).
- **Prereqs** — pinpoint IDs that must reach aim first.

---

## Tier 0 — Survival (must be automatic before anything else)

| ID | Pinpoint | Probe | Aim | Prereqs |
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

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 1A.1 | `hjkl` (4-cell, all directions) | S→K | 60 | T0 |
| 1A.2 | Line start/first-non-blank/end (`0`, `^`, `$`, `g_`) | S→K | 50 | T0 |
| 1A.3 | `h l` (narrower horizontal-direction sibling of 1A.1) | S→K | 60 | T0 |
| 1A.4 | `j k` (narrower vertical-direction sibling of 1A.1) | S→K | 60 | T0 |
| 1A.5 | `0 $` (narrower line-edge sibling of 1A.2; drops the whitespace axis) | S→K | 55 | T0 |

### 1B — Word

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 1B.1 | Forward/back word start (`w`, `b`) | S→K | 45 | 1A |
| 1B.2 | Forward/back word end (`e`, `ge`) | S→K | 40 | 1A |
| 1B.3 | WORD variants (`W`, `B`, `E`) | S→K | 45 | 1B.1, 1B.2 |
| 1B.4 | Discriminate `w` vs `W` on punctuated text | Disc | 30 | 1B.1, 1B.2, 1B.3 |

### 1C — Char-find on line

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 1C.1 | `f{c}`, `F{c}` | S→K | 50 | 1A |
| 1C.2 | `t{c}`, `T{c}` | S→K | 45 | 1C.1 |
| 1C.3 | Repeat last find (`;`, `,`) | S→K | 40 | 1C.1, 1C.2 |
| 1C.4 | Discriminate `f` vs `t` (which lands ON vs BEFORE the char) | Disc | 35 | 1C.1, 1C.2 |

### 1D — Buffer/screen jumps

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 1D.1 | Top/bottom (`gg`, `G`) | S→K | 50 | T0 |
| 1D.2 | Line number (`{n}G`, `:{n}`) | S→K | 40 | 1D.1 |
| 1D.3 | Screen position (`H`, `M`, `L`) | S→K | 40 | T0 |
| 1D.4 | Screen scroll (`Ctrl-d`, `Ctrl-u`, `Ctrl-f`, `Ctrl-b`, `zz`, `zt`, `zb`) | S→K | 35 | T0 |

### 1E — Block / paragraph / sentence

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 1E.1 | Sentence (`(`, `)`) | S→K | 40 | 1A |
| 1E.2 | Paragraph (`{`, `}`) | S→K | 40 | 1A |
| 1E.3 | Match brace (`%`) | S→K | 40 | 1A |

### 1F — Search

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 1F.1 | `/pat`, `?pat`, `n`, `N` | S→K | 35 | 1A |
| 1F.2 | Word-under-cursor (`*`, `#`) | S→K | 40 | 1A |
| 1F.3 | History recall (`/` then `↑`) | Recall | 25 | 1F.1 |

---

## Tier 2 — Operators (no motion yet, just the operator + linewise form)

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 2.1 | Discriminate `x` vs `dd` (single-char delete vs linewise; navigate then operate) | Disc | 35 | T0 |
| 2.2 | Discriminate `>>` vs `<<` (indent vs dedent direction) | Disc | 35 | T0 |
| 2.3 | Change line (`cc`/`S`) — under review, aliases not a minimal pair | S→K | 45 | T0 |
| 2.4 | Yank line (`yy`/`Y`) — under review, aliases not a minimal pair | S→K | 45 | T0 |
| 2.5 | Filter line (`==`, `!!`) — under review, different concepts not a minimal pair | S→K | 30 | T0 |
| 2.6 | Recall the operator family (`d`, `c`, `y`, `>`, `<`, `=`, `gu`, `gU`, `~`, `!`) | Recall | 30 | — |

Discrimination probe **2.D**: given a goal, pick `d` vs `c` (composite emergence — does the learner know `c` enters insert mode, `d` doesn't?). Aim 35.

---

## Tier 3 — Text Objects (taught isolated, used only with operators in Tier 4)

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 3.1 | Word objects (`iw`, `aw`, `iW`, `aW`) — describe what they cover | Recall | 40 | 1B |
| 3.2a | Inner quote — `i"` vs `i'` | Recall | 40 | T0 |
| 3.2b | Inner quote — introduce `` i` `` (backtick) | Recall | 35 | 3.2a |
| 3.3 | Bracket objects (`i(`, `a(`, `i[`, `a[`, `i{`, `a{`, `i<`, `a<`) | Recall | 40 | T0 |
| 3.4 | Sentence/paragraph (`is`/`as`, `ip`/`ap`) | Recall | 35 | 1E |
| 3.5 | Tag (`it`, `at`) | Recall | 30 | 3.3 |
| 3.6 | Discriminate `i` vs `a` (inner vs around — does it include the delimiter / trailing space?) | Disc | 35 | 3.1–3.5 |

---

## Tier 4 — Operator × {motion, text object}

Composite behaviors composing a Tier 2 operator with a motion or text object. Each row drills canonical exemplars; prereqs are the relevant operator and motion/text-object groups at aim.

Rows below are the narrower 2-cell direction discriminations under the exhaustive-hierarchy framework. The earlier wide-grid spec rows (`4.2-4.6` covering line motions, char-find, text objects, search, match) have been repurposed slice-by-slice; remaining rows are explicit pinpoints with their own files.

| ID | Pinpoint | Probe | Aim | Prereqs |
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

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 5.1 | Counted motion (`5w`, `3j`, `2}`) | S→K | 40 | 1 |
| 5.2 | Counted operator (`3dd`, `2yy`) | S→K | 35 | 2 |
| 5.3 | Count between operator and motion (`d3w`, `c2f,`) | S→K | 30 | 4 |
| 5.4 | Dot repeat (`.`) — predict effect | K→S | 35 | 2 |
| 5.5 | Discriminate when `.` is enough vs when macro is needed | Disc | 20 | 5.4, 12 |

---

## Tier 6 — Insert-mode editing & small fixes

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 6.1 | Enter insert at variants (`i`, `a`, `I`, `A`) | S→K | 50 | T0 |
| 6.2 | Open above/below (`o`, `O`) — already in T0; combined with indent | S→K | 40 | T0 |
| 6.3 | Replace one char (`r{c}`), enter replace mode (`R`) | S→K | 40 | T0 |
| 6.4 | Delete char (`x`, `X`) | S→K | 50 | T0 |
| 6.5 | Substitute char/line (`s`, `S`) | S→K | 35 | T0 |
| 6.6 | Change-to-end (`C`, `D`, `Y`) | S→K | 40 | 2, 1A |
| 6.7 | Join lines (`J`, `gJ`) | S→K | 35 | T0 |
| 6.8 | In-insert: backspace word (`Ctrl-w`), kill line (`Ctrl-u`) | S→K | 30 | T0 |
| 6.9 | In-insert: literal char (`Ctrl-v{c}`), digraph (`Ctrl-k`) | Recall | 20 | T0 |

---

## Tier 7 — Visual mode

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 7.1 | Enter visual (`v`, `V`, `Ctrl-v`) | S→K | 45 | T0 |
| 7.2 | Extend selection by motion | S→K | 35 | 7.1, 1 |
| 7.3 | Operate on selection (`d`, `c`, `y`, `>`, `<`, `~`) | S→K | 35 | 7.1, 2 |
| 7.4 | Swap anchor (`o`, `O` in visual) | S→K | 30 | 7.1 |
| 7.5 | Reselect last (`gv`) | S→K | 30 | 7.1 |
| 7.6 | Block insert/append on selection (`I`, `A` after `Ctrl-v`) | S→K | 25 | 7.1 |
| 7.7 | Discriminate visual+operator vs operator+motion (when each wins) | Disc | 20 | 4, 7.3 |

---

## Tier 8 — Yank, paste, registers

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 8.1 | Paste (`p`, `P`) — predict where it lands for charwise vs linewise | K→S | 40 | 2.3 |
| 8.2 | Named register (`"ay`, `"ap`) | S→K | 30 | 8.1 |
| 8.3 | Last-yank register (`"0p`) | Recall | 25 | 8.1 |
| 8.4 | Black hole (`"_d`) | Recall | 25 | 8.1 |
| 8.5 | Inspect registers (`:reg`) | Recall | 20 | 8.1 |
| 8.6 | System clipboard when available (`"+y`, `"+p`) | Recall | 25 | 8.1 |
| 8.7 | Discriminate `p` vs `P` placement after charwise vs linewise yank | Disc | 25 | 8.1 |

---

## Tier 9 — Marks and jumps

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 9.1 | Set/jump local mark (`ma`, `'a`, `` `a ``) | S→K | 35 | T0 |
| 9.2 | Discriminate `'a` (line) vs `` `a `` (exact pos) | Disc | 30 | 9.1 |
| 9.3 | Auto marks (`''`, `` `` ``, `'.`, `` `. ``, `'^`) | Recall | 25 | 9.1 |
| 9.4 | Jump list (`Ctrl-o`, `Ctrl-i`) | S→K | 30 | T0 |
| 9.5 | Change list (`g;`, `g,`) | Recall | 20 | T0 |

---

## Tier 10 — Search & substitute

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 10.1 | Basic substitute (`:s/a/b/`, `:s/a/b/g`) | S→K | 25 | 1F |
| 10.2 | Whole file (`:%s/a/b/g`) | S→K | 30 | 10.1 |
| 10.3 | Confirm flag (`:%s/a/b/gc`) | Recall | 25 | 10.1 |
| 10.4 | Range forms (`:.,+5s`, `:'a,'bs`, `:'<,'>s`) | S→K | 20 | 10.1, 9 |
| 10.5 | Backref (`:s/\(foo\)_\(bar\)/\2_\1/`) | S→K | 15 | 10.1 |
| 10.6 | `\v` very-magic mode | Recall | 20 | 10.1 |
| 10.7 | Magic-char awareness (`.` `*` `\+` `\?` `\(\)` in default magic) | Disc | 20 | 10.1 |
| 10.8 | `:g/pat/d`, `:v/pat/d` | S→K | 25 | 10.1 |
| 10.9 | `:g/pat/cmd` with arbitrary cmd | S→K | 15 | 10.8 |

---

## Tier 11 — Ex commands & buffers

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 11.1 | Range delete/yank (`:.,+5d`, `:1,$y`) | S→K | 25 | T0 |
| 11.2 | Shell out (`:!cmd`) | S→K | 30 | T0 |
| 11.3 | Read shell into buffer (`:r !cmd`, `:r file`) | S→K | 25 | T0 |
| 11.4 | Filter selection through shell (`:'<,'>!sort`) | S→K | 20 | 7, 11.2 |
| 11.5 | Edit/list/switch buffers (`:e`, `:ls`, `:b{n}`, `:bn`, `:bp`, `:bd`) | Recall | 25 | T0 |
| 11.6 | Window splits (`:sp`, `:vsp`, `Ctrl-w {hjkl}`, `Ctrl-w {HJKL}`, `Ctrl-w =`) | S→K | 30 | T0 |
| 11.7 | Tabs (`:tabnew`, `gt`, `gT`) | S→K | 25 | T0 |

---

## Tier 12 — Macros

| ID | Pinpoint | Probe | Aim | Prereqs |
|---|---|---|---|---|
| 12.1 | Record/replay (`qa`...`q`, `@a`, `@@`) | S→K | 20 | 5.4 |
| 12.2 | Counted replay (`5@a`) | S→K | 18 | 12.1 |
| 12.3 | Append to register (`qA`) | Recall | 15 | 12.1 |
| 12.4 | Discriminate when `.` suffices vs when `q` is needed | Disc | 15 | 12.1, 5.4 |

---

## Tier 13 — Composite editing tasks

Real-world editing tasks that compose many lower-tier behaviors. Useful for spotting curriculum gaps — a composite that should be easy but feels hard points at a component that isn't fluent enough. Probe = task description + starting buffer; measure time-to-completion and keystroke efficiency vs an expert reference.

| ID | Composite | Components exercised |
|---|---|---|
| C.1 | Rename a variable inside the current function | 1F.2, 9.1, 10.4 |
| C.2 | Wrap a block in `try:`/`except:` (or `if (…) { }`) | 7, 6.6, 5.4 |
| C.3 | Sort a contiguous block of imports alphabetically | 11.4 |
| C.4 | Delete every line containing `TODO` | 10.8 |
| C.5 | Reflow a paragraph to 80 cols (`gqap`) | 2, 3.4 |
| C.6 | Swap two arguments in `foo(a, b)` | 4.4, 8.1 |
| C.7 | Indent a function body one level | 7, 2.4 |
| C.8 | Convert `snake_case` → `camelCase` for one identifier | 12 |
| C.9 | Comment out a contiguous block | 7.6 (block insert) |
| C.10 | Move the current line below the next 3 lines | 2.1, 5.1, 8.1 |

Pass criterion: keystroke count within ~120% of expert reference, completed without consulting docs.

---

## Aim derivation note

All aim numbers above are **starting guesses**, not empirically derived. Long-term plan: aggregate per-behavior rate distributions across the user community and let learners compare their rates to the population (see `.strategy/data-contribution.md`). Until that data exists, aims serve as guidance; the published distribution will replace them.

## Component DAG summary

```
T0 (survival)
 ├─ Tier 1 (motions: 1A → 1B → 1C → 1D, 1E, 1F)
 ├─ Tier 2 (operators, linewise)
 ├─ Tier 3 (text objects, isolated)
 │
 ├─ Tier 4 (op × motion, op × text-object)
 ├─ Tier 5 (counts, dot)
 ├─ Tier 6 (insert-mode editing)
 ├─ Tier 7 (visual)
 ├─ Tier 8 (registers/paste)
 ├─ Tier 9 (marks/jumps)
 ├─ Tier 10 (search/substitute)
 ├─ Tier 11 (ex/buffers/windows)
 └─ Tier 12 (macros)
       │
       └─ Tier 13 (composite editing tasks)
```
