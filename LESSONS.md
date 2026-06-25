# Lesson style guide

How every `:VfLearn` lesson must read, so that all lessons feel like one
coherent course. This is the spec the lessons are being conformed to; when you
add or edit a `lesson()`, follow it.

The *why* behind these rules is Direct Instruction (Engelmann/Carnine):
faultless communication — parallel rule statements, one discriminator
per lesson, the learner performs the motion rather than reading about
it. This doc is the *how*: the concrete wording and structure rules
that keep that intent uniform across drills.

Decisions locked with the project owner are marked **[locked]**.
Calls made in this draft that are open to a quick veto are marked
**[proposed]**.

---

## 1. The shape of every lesson

A lesson is a list of frames. Two phases the learner sees:

```
intro show frame   →   try frames   →   (runner appends the test phase + end screen)
   (the rule)            (apply it)
```

- **[locked] Every lesson opens with exactly one rule-stating `show`
  frame.** No lesson opens cold on a `try`; no lesson buries the rule
  in the middle or saves it for last. The discrimination drills that
  currently put the rule last (`delete_char_vs_line`, `indent_vs_dedent`)
  and the word drills that put it in frame 3 (`move_to_word_*`) get the
  rule moved to the front.
- After the intro, **try frames** introduce each motion/operation once,
  then practice it.
- **No closing / recap / "complete" frame.** The runner appends the
  test phase and the shared end screen. A lesson's last frame is always
  a `try`.

---

## 2. The intro frame (one template for all kinds)

```
{One-line title: what this lesson covers}:

    {key}   →   {rule — see §3 for the verb}
    {key}   →   {rule}

{Optional: ONE line of discriminating context (when to pick which).}

Press <Space> to continue.
```

Rules:

- **[locked]** Ends with exactly `Press <Space> to continue.` (not
  "to begin", not absent).
- Title line ends with a colon. Keys are left-aligned in a column;
  `→` (U+2192), padded so the arrows line up.
- The rule column uses the §3 verb for motions; for other kinds it
  states the behavior (mode entered, goal, etc.) — see §6.
- At most **one** optional context line. No multi-paragraph essays, no
  coaching asides, no measurement notes. (The old per-drill asides —
  "Watch the cursor jump.", "The summary tracks each key…", etc. — are
  removed.)
- `'lines'` is `[]` for mode/command/empty-buffer intros, or the drill
  buffer when the rule references on-screen content. `cursor` is
  required on every show frame.

---

## 3. Rule-statement wording

- **[locked] Verb: "moves the cursor to …".** One verb, everywhere a
  motion is described. Not "sends the cursor to", not "lands on", not
  "jumps to".
  - `Press h — moves the cursor one column left.`
  - `Press w — moves the cursor to the start of the next word.`
  - `Press 0 — moves the cursor to column 1.`
- **[locked] "Press", never "Use".** Every action frame starts with
  `Press {keys}`. The old "Use X to reach Y" / "Use X twice" forms are
  gone.
- **Connective: em-dash ` — `** (spaces around it) between the keystroke
  and its result. Never a colon, never a bare hyphen.
- **Key-first word order.** `Press gg — moves the cursor to the first
  line.` Not "Target is the first line — press gg." (`move_to_file_edges`
  is the current offender.)
- Capitalize the first word; end every prompt with a period.
- Keystrokes are written bare and unquoted in prose: `h`, `dw`, `fp`,
  `g_`, `>>`. No backticks inside prompt strings.

### Practice / repeat frames **[proposed]**

After the introduce-the-motion try frames, a lesson may add practice
frames. They are **terse and uniform** — the rule was already stated:

- Repeat the same motion: `Press w twice.` (no trailing gloss).
- A later, different start: `Press gg — still moves to the first line.`
  (only when demonstrating position-independence is the point).

No "— motions repeat." / "to skip a word" / "Use X twice" variants.

---

## 4. Notation **[locked]**

Vim notation everywhere learner-facing, matching the internal
`expected_motion` fields:

| Concept | Write it | NOT |
|---|---|---|
| Control keys | `<C-[>`, `<C-r>` | `Ctrl+[`, `Ctrl-r`, `^[` |
| Escape | `<Esc>` | `Esc` |
| Enter / return | `<CR>` | `<Enter>`, `Enter` |
| Space (advance key) | `<Space>` | `Space` |
| Tab | `<Tab>` | `Tab` |

> The `<C-x>` form is not self-evident to a beginner. A **foundational
> drill that teaches how to read `<C-x>` ("hold Ctrl, press x")** is a
> tracked follow-up (its own slug + generate + cheat-analysis + tests);
> until it lands, lessons still use `<C-x>` so we only standardize once.

### Mode names **[locked]**

ALL-CAPS, everywhere learner-facing, in intros, try prompts, and prose:
`NORMAL`, `INSERT`, `VISUAL`, `REPLACE`, `COMMAND`. Fixes the
mixed-case "Normal/non-Normal" in `switch_between_many_modes` and the
lowercase "normal-mode" in the save/quit prose.

---

## 5. Cue glyphs **[proposed]**

One glyph per concept, used consistently; documented here so no lesson
invents a new one:

| Glyph | Means | Used by |
|---|---|---|
| `▼` | the cell directly above is the affected char | delete-single-char |
| `▶◀` | the insertion gap between two columns | insert i/a/I/A, start/end |
| `⏵` | a whole row marker (line-level target) | open-line o/O |
| `→` | "implies / maps to" in rule tables | all intros |
| `·` | a literal trailing space (via `listchars`) | whitespace-sensitive motions |

`hide_target` is set **consistently within a family** (currently it's
on all `insert_line_above_below` tries but only the first try of
`insert_before_after_char_start_end_line`). Rule: hide the target only
on the *first* introduce frame of a drill if at all; be the same across
sibling drills.

---

## 6. Per-kind specifics

The §2 intro template and §3 wording apply to all kinds. The
kind-specific bits:

### motion (`kind: 'motion'`)
Intro lists each motion with the §3 verb. Try frames introduce each
motion once (key-first rule), then optional terse practice frames.
Symmetric pairs end their intro context line with **"They differ only
by direction."** when literally true.

### discrimination (to-vs-till, find-vs-till, char-vs-line, indent)
Intro carries the **canonical contrast block** (already consistent for
to/till — keep it verbatim):

```
    f{c}  →  lands ON the next c
    t{c}  →  lands ONE CELL BEFORE the next c
    F{c}  →  lands ON the previous c
    T{c}  →  lands ONE CELL AFTER the previous c
```

(Exception to §3's verb: this contrast block is a fixed idiom; "lands
ON / ONE CELL BEFORE" is the discriminator and stays.)

**Try-frame structure (not a rigid opener).** Every discrimination try
follows the same shape: *name the target → say which candidate char
repeats (so that motion stops early) → press the unique one*. The
lead-in may vary with the drill's geometry, and that variation is
fine — it tracks a real difference, not drift:
- constant-geometry single-direction drills name the target char
  ("Target is the b. …");
- directional composites lead with the direction ("Ahead, …" /
  "Behind, …");
- in-words drills name the word ("Target is the n in \"spend\". …").

What must stay uniform: the repeat/unique reasoning, em-dash before the
`press {key}` clause, and the parenthetical naming the rejected
alternative. Never leak a drill slug into a prompt — say "as before",
not the snake_case id.

### mode_switch (`kind: 'mode_switch'`)
Intro template (already shared by the 4 atomics — keep, with notation +
"continue" fixes):
```
Two keys, two modes:

    i        →  INSERT  (from NORMAL)
    <C-[>    →  NORMAL  (from INSERT; <Esc> also works)

The next four frames practice the round trip.

Press <Space> to continue.
```
**Try prompts:** `Switch to INSERT mode.` / `Back to NORMAL mode.`
— **[locked-by-consistency] always keep "mode"** (fix the atomics that
drop it on the 2nd "Back to NORMAL."). `switch_between_many_modes`
reuses this exact phrasing.

### mode (insert entry, `kind: 'mode'`)
Intro + the "type foo to confirm; no `<Esc>` needed" mechanic line
(this is the one allowed mechanic note, since it's load-bearing).
**[proposed] Reprise form is uniform:** first occurrence of a key is
the full rule frame (`{key} opens insert {where} — {cue}. Press {key},
then type foo.`); a reprise is `{key} again — {cue}. Type foo.` Applied
identically across all four insert drills.

### visual_motion (`kind: 'visual_motion'`)
Intro: `v` rule line(s) + the `v{motion} → {what it covers}` table.
**Try prompts uniform:** `Press v then l — extends the selection one
column right.` Fix the 4-way drill that drops the clause
(`Press v then h.` → add the clause).

### editing (`kind: 'editing'`)
Intro states the operator + motion rule. **[locked] No bespoke undo
frame** — the runner's `[u=undo if wrong]` header covers recovery for
every editing drill. Remove the two hand-written undo show frames
(`delete_to_word_*`, `delete_to_line_edges_*`).

### command (save/quit, `kind: 'command'`)
Intro: `X vs Y.` title, behavior lines, then the goal table
`Goal: {word}  →  :{cmd}<CR>`. **[locked] Destructive actions use one
templated phrase: "discards unsaved changes".**
- `:q!  →  quits and discards unsaved changes`
- `ZQ   →  quits and discards unsaved changes`
Non-destructive pairs carry no safety language. Try frames stay
prompt-less (`goal` + `snippet` drive them).

---

## 7. Waypoint annotation (repeat-find drills) **[proposed]**

The 9 `move_repeat_last_*` drills currently use three annotation styles
(bare `(1)/(2)`, `col N = 1`, and real-word landmarks). **Standardize on
bare numbered stops** matching the on-screen waypoint glyphs:

```
Press fs (lands on the first s, 1), then ; (jumps forward to the second s, 2).
```

- No column numbers (`col 10 = 1` → just `1`).
- A short landmark ("the t in cat") is allowed **only** when the buffer
  is real words; never invent one for the noise buffers.
- Both forward and backward siblings of a family use the identical
  annotation (today `find_forward` and `find_backward` disagree).

---

## 8. Conformance checklist (per lesson)

- [ ] Opens with one rule-stating `show` frame using the §2 template.
- [ ] Intro ends `Press <Space> to continue.`
- [ ] All motion rules use "moves the cursor to …", key-first, em-dash.
- [ ] "Press" everywhere; no "Use".
- [ ] `<C-[> <C-r> <Esc> <CR> <Space>` notation; mode names ALL-CAPS.
- [ ] No one-off coaching asides; no bespoke undo frame; ≤1 intro
      context line.
- [ ] Destructive save/quit uses "discards unsaved changes".
- [ ] Cue glyph from §5 registry; `hide_target` consistent with siblings.
- [ ] Repeat drills: bare `(1)/(2)` waypoint annotation.
- [ ] Last frame is a `try`.
- [ ] `tests/run.sh` green; lesson renders in the nvim smoke.

---

## 9. Tracked follow-up (out of scope for the conform pass)

- **Foundational `<C-x>` notation drill** — teaches the learner to read
  `<C-[>` / `<C-r>` ("hold Ctrl, press the key"). New drill: slug,
  `meta()`, `generate()`, cheat-analysis, `lesson()` (itself following
  this guide), property tests, catalog regen.
