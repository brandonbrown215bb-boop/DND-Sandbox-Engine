# Windowed Playtest Report — Top Down Party Game

> Historical Linux/Xvfb playtest artifact. It is not current supported-host or
> Gate 1 completion evidence; current validation is Windows-based.

**Date:** 2026-07-06
**Method:** Real *windowed* Godot 4.7 (x11 display driver) running under a virtual X server, with synthetic input. This is a genuine rendered playthrough — not the headless harness.

---

## 1. Environment

| Component | Value |
|---|---|
| Godot binary | Godot 4.7 stable Linux x86_64 (historical machine-specific path omitted) |
| Display | `Xvfb :99`, 1280×720×24, `+extension GLX +render`, llvmpipe (LLVM 22.1.5, 256 bits) software GL |
| Launch flags | `DISPLAY=:99 Godot --display-driver x11 --rendering-driver opengl3 --path . --resolution 1280x720 --windowed` |
| Input | `xdotool` — `mousemove` → `mousedown` → dwell (0.6s) → `mouseup`. A fast `xdotool click` is **dropped** under the slow software-GL frame rate; the press and release land in different frames and Godot misses it. |
| Evidence | ImageMagick `import -window root` screenshots at each beat, vision-read to confirm state. |

> No live display existed on the box (X0/X1 sockets were stale). Mesa `swrast` + Xvfb provided a real rendering context. `xdotool` was installed via `pacman -S xdotool`.

---

## 2. What passed — live, in a rendered window

| Beat | Result |
|---|---|
| Boot → main menu | Clean. Green log: *"All core and mod assets loaded successfully!"* — matches the headless harness's load report (14 classes, 9 races, 232 items, 198 spells, 453 monsters, 4 event tables, 1 campaign). |
| Start Game | Transitioned to character creation. |
| 2-player character creation | Player 1 → Sariel Stonebender (Dragonborn Rogue); Player 2 → Alustriel Fireheart (Human Sorcerer). `Randomize All` + `Confirm` advanced the multi-player loop correctly. |
| Overworld hex map | Rendered. Party token, turn HUD, both characters' stat panels visible. |
| Movement | Sariel moved to `(-1,-1)` (R1, 2 MP) then `(1,-2)` (R2, 4 MP). Movement points consumed correctly. |
| Turn cycling | Round 1 (Sariel → Alustriel) → Round 2 (Sariel). Works. |
| Event popup — choice type | *Mysterious Shrine* opened live. "Leave it alone" resolved, applied its effect, and **closed via the Close button**. Verified end-to-end. |
| Event popup — skill-check type | *Rockslide!* opened live with a real `Roll DEX Check (DC 13) [+4]` button. |

These are exactly the paths the headless harness could never exercise: the real scene tree, real `InputEvent`s, real `_gui_input`, real rendering.

---

## 3. Divergences from the headless harness

### 3.1 `BtnRoll` does not receive synthetic clicks (OPEN — under investigation)
Choice-container buttons (`ChoiceContainer` VBox) respond to dwell-clicks at screen ~`(640, 407)`. The Roll button (`BtnRoll`, inside `RollSection` HBox, 250px wide, left-aligned) did **not** register at any X scanned (460–620) at its expected Y (~400–409). The Shrine's Close button (same local Y row as the choices) *did* work once its real Y was found (~407), so Close is fine — the Roll button specifically is the unverified seam.

The harness tested `EventResolver.resolve_skill_check` directly, so the *logic* is covered. But the **live button wiring** for the skill-check roll is not confirmed by this run. Hypothesis: either (a) the click reaches but `_perform_roll` throws a script error (handler aborts, no visible result), or (b) the button's screen position differs from the reverse-engineered estimate due to HBox alignment. See §5.

### 3.2 Coordinate targeting is fragile
`Control.get_global_rect()` returns *local* rects when the dialog is added to a bare `Node2D` probe (choice center X=0, roll center X=-100). Screen coords had to be reverse-engineered by trial-and-error. Not a game bug — a test-harness limitation. Mitigation: a probe scene that reads each button's `get_global_rect()` after `popup_event` gives exact relative layout; the dialog is centered on screen (anchor 0.5) so screen = center + local offset.

---

## 4. Techniques established (for reuse)

1. **Virtual display:** `Xvfb :99 -screen 0 1280x720x24 -ac +extension GLX +render -noreset` + Godot `--display-driver x11`.
2. **Dwell-click:** `mousemove` → `mousedown` → sleep 0.6 → `mouseup`. Never bare `xdotool click`.
3. **Rect probe:** a throwaway scene that `instantiate()`s the UI, calls `popup_event(...)`, then prints each button's `get_global_rect()` — gives exact click targets without guessing.
4. **Right-side footer buttons** (Start Game, Randomize All, Confirm, End Turn) sit at X≈900–1150, Y≈685 and are easy to hit. **Centered dialog buttons** need the rect-probe.

---

## 5. Open items

- **Roll button live input** — being investigated (see separate dive).
- **Dungeon entry / combat (live)** — not reached; blind hex-grid navigation to a `dungeon_entrance` tile is impractical by coordinate guessing. The dungeon scene itself boots and generates rooms (proven by headless harness + live scene compile).
- **Victory/defeat chain** — Horizon 1 from the roadmap; the `combat → defeated_monsters → check_campaign_victory → end_game` path is wired but not yet driven end-to-end in either harness.

---

*No game source was modified during this playtest. Probe files (`src/event_probe.gd`, `scenes/event_probe.tscn`) were removed after use.*
