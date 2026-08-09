# Changelog — Top Down Party Game

## Gate 0 baseline note — 2026-08-09

The historical “full suite green” entries below describe earlier snapshots and
are not current completion claims. The initial Godot 4.7 inventory is recorded
in [Gate 0 evidence](gate0_evidence.md); its failures are retained as baseline
history. [Gate 1 evidence](gate1_evidence.md) records the later repaired,
isolated 263-assertion run. See the [defect register](defect_register.md) for
which baseline defects closed and which remain open.

The Windows gate begins with a recovery-mode editor scan so a clean checkout
does not depend on a pre-existing ignored `.godot` class cache.

## 2026-07-07

### UX / systems — three gaps closed

**1. Save / Load anywhere + persistent settings (gear menu)**
- New `Settings` autoload (`src/autoload/settings.gd`, registered in `project.godot`).
  - Persists player options to `user://settings.cfg`: master / SFX / music volume, screen shake, high contrast, damage numbers, tooltip delay.
  - `save_game(slot)` / `load_game(slot)` / `get_saves()` wrap `SaveManager` so saving and loading work from anywhere a game is in progress.
  - `open_settings()` pauses the tree and mounts `scenes/ui/settings_overlay.tscn` (volumes, toggles, save-slot list, Save/Load/Delete/Resume/Quit). `close_settings()` resumes.
- Gear button (`Settings ⚙`) wired into the **overworld** and **combat** HUDs.

**2. Main-menu Load Game picker**
- `main_menu.tscn` gained a Load button + save-slot `ItemList`.
- `main_menu.gd` populates the slot list on `_ready` (`_refresh_save_slots`) and `_on_load_pressed()` calls `SaveManager.load_game(slot)` (loads the first slot if none selected).
- Previously `SaveManager.load_game` existed and was test-verified but unreachable from the UI.

**3. Ambush is now a Stealth check (was a flat 40% roll)**
- `OverworldState._on_rest_pressed` (wilderness rest) now rolls the best party Stealth bonus (DEX modifier + proficiency if Stealth-trained) vs a DC of `12 + (party_size − 1)`.
- Pass → peaceful night. Fail → surprise encounter.
- Helpers added: `_compute_ambush_dc()`, `_party_best_stealth_mod()`.

### 2026-07-07 (later) — Combat: equipped weapon + range enforcement

**Attack range is now enforced on execution**
- The root cause of "attack from anywhere": `_on_hex_clicked`'s attack branch only checked range when *highlighting* targets, never when *resolving* the click. Now it enforces weapon range on execution (mirrors the highlight) and logs an "out of range" rejection instead of attacking.
- Melee weapons (`range <= 1`) require the target adjacent; ranged weapons use their `range` field in hexes. The tactical grid already supports moving to close distance.

**Equipped weapon + range shown in the combat HUD**
- New `WeaponInfo` label in the combat sidebar shows `Weapon: <name> (melee/reach 1)` or `Weapon: <name> (range N hexes)`, pulled from the active character's equipped weapon `range` field.
- `CombatHUD._update_weapon_info()` populates it on every `update_hud`.

### 2026-07-07 (later) — Character Sheet (view all stats anywhere)

**A character sheet now exists and is reachable from every mode.**
- New `CharacterSheet` autoload (`src/autoload/character_sheet.gd`, registered in `project.godot`). It renders a read-only CanvasLayer overlay (above scene HUD, close button or Esc) showing: identity, ability scores + modifiers, HP/AC/speed/proficiency, saving throws, all 18 skills (with proficiency marks), equipment + backpack, active conditions, spell slots / known spells, and class features with remaining uses.
- The overlay does **not** pause the tree (avoids the paused-timer stall risk and lets the player read freely).
- A **"Character Sheet"** button is wired into the **overworld** (`OverworldHUD`), **dungeon** (`DungeonHUD`, same HUD class), and **combat** (`CombatHUD`) HUDs.
  - Overworld/dungeon call `CharacterSheet.show_active()` → shows the active PlayerManager character.
  - Combat calls `CharacterSheet.show_sheet(active_character)` → shows the character whose turn it is.
- `viewport_harness.gd` gained a beat verifying the sheet opens for the active player, renders Ability Scores / Saving Throws / Skills / Equipment sections, and closes.

### Tests
- Full suite green (`RUN_TESTS_EXIT 0`): logic suite 227/0, viewport harness 0 failed.
- `viewport_harness.gd` gained beats covering: settings overlay open/pause/close/persist, ambush Stealth DC + best-mod, and main-menu Load UI wiring.

### Notes / known limitations
- No in-combat save button (save works from overworld HUD + settings overlay only).
- Settings overlay Save writes a `quicksave` slot; slot selection in the overlay list is for Load/Delete.
- Ambush always uses the wilderness monster pool (`goblin`, `wolf`, `bandit`, `giant_spider`, `skeleton`) regardless of terrain.

### 2026-07-07 (later) — P0: combat feel + demo payoff

**Floating damage numbers + screen shake (previously toggles with no wiring).**
- `combat.tscn` gained a `Camera2D` (for shake) and an `FxLayer` `Node2D` (for floating text). `combat_state.gd` `@onready`s both.
- `_spawn_floating_text(coord, text, color)`: pops a Label at a hex, floats up + fades (tween, fire-and-forget). Gated by `Settings.show_damage_numbers`.
- `_shake_camera(intensity)`: brief offset shake on the Camera2D. Gated by `Settings.screen_shake`.
- `_flash_hex(coord, color)`: brief highlight pulse on impact.
- Wired into: player weapon attacks (incl. crit color + CRIT label), monster attacks, and poison ticks (green).

**Health bars over every unit.**
- `hex_grid._draw()` now renders an HP bar above each token (reads `current_hp`/`max_hp` from the Character or monster dict), color-coded green → yellow → red by fraction. HP at a glance, no more sidebar-only guessing.

**Victory / Defeat payoff screen (was a silent 2s wait + snap to menu).**
- New `BattleResultOverlay` (`src/combat/battle_result_overlay.gd`, code-built CanvasLayer, `PROCESS_MODE_ALWAYS`): shows VICTORY/DEFEAT with flavor, plus **Continue** (resolves combat) and **Main Menu** (abort) buttons.
- `CombatState._end_battle` now presents the overlay and awaits the player's choice instead of the silent timer. Under `GameManager.test_mode` it auto-resolves (so the headless harness never hangs on a button).

**Demo arc: visible objective tracker.**
- `OverworldHUD` gained an `ObjectiveLabel`; `_update_objective()` reads `GameManager.get_win_condition()` and renders the active goals (e.g. "Defeat Goblin King"), so the player knows what they're working toward. Null-guarded for the dungeon HUD (shared script, no such node there yet).

### Tests
- `GameManager.test_mode` flag added (set by `viewport_harness._setup_world`) so end-of-battle flows resolve instantly.
- `viewport_harness.gd` combat beat extended: asserts `FxLayer`/`Camera2D` resolve, floating text spawns (and is suppressed when the setting is off), and the battle-result overlay presents + emits resolution without hanging.

### 2026-07-07 (later) — P1: combat readability

**Enemy intent preview.** At the start of a monster turn, the planned action is computed via `AIController.get_monster_action` and stored on the monster as `intent`; `hex_grid._draw()` renders a badge above the token — *Move*, *Attack X*, *Move + Attack X*, or *Hold* — so the player can read the threat before it resolves.

**Move-path preview.** Hovering a reachable hex draws the A* route (yellow PATH color) before committing; cleared on action select / turn change. No blind moves.

**Attack-range ring.** Selecting Attack now highlights the weapon's reach as a subtle red ring (plus brighter in-range target highlights). Melee reads as a tight cluster; ranged as a wide field.

**First-turn hint.** A dismissible `HintLabel` in the combat HUD shows once on the opening player turn (moves / paths / attack range / intent) and hides on the first action.

**HexGrid API:** added `clear_highlight(hex)` and `get_highlight_count()` to support per-hex path teardown and test assertions.

### Tests
- Full suite green (`RUN_TESTS_EXIT 0`): logic suite 229/0, viewport harness 0 failed.
- `viewport_harness.gd` combat beat extended with P1 assertions: intent descriptions correct (move+attack / attack / move / hold), hover populates a movement path, attack select highlights weapon range hexes, hint text configured + show/hide mechanism works.

---

### 2026-07-07 — Honesty addendum (verified by booting the engine, not by the changelog alone)

The "green" claims above are technically true — the viewport harness reports
`0 failed (12 tests run)` and the logic suite reports `ALL TESTS PASSED`. But two
facts the changelog omits:

**1. A real runtime error fired 10× during the viewport harness and the harness
did not catch it.** *(FIXED 2026-07-07, see below.)*
`src/ui/widgets/stat_bar.gd:19` called `Label.add_theme_font_features_override("tnum")`.
That method does not exist in Godot 4.7 stable. *Fix applied:* `StatBar` now applies
tabular numerals via a `FontVariation` (opentype feature `tnum`) in `_ready` instead
of the nonexistent API. Verified: full boot + harness now report zero
`SCRIPT ERROR` / `Nonexistent function`.

**2. The "DungeonHUD split" was cosmetic, not a split.** *(FIXED 2026-07-07, see below.)*
`DungeonHUD extends OverworldHUD` and hid `btn_end_turn`. *Fix applied:* real `BaseHUD`
extraction (research doc Pattern H) — `src/ui/base_hud.gd` now owns the shared system-row
signals (rest/save/menu/settings/sheet) and `log_text`/`clear_logs()`/`add_log()`.
`CombatHUD`, `OverworldHUD`, and `DungeonHUD` all `extends BaseHUD`. The dungeon's
`BtnEndTurn` node was **removed from `dungeon.tscn`** (not hidden); `dungeon_state.gd`
wires the real signals to Rest/Save/Menu/Settings/Sheet handlers. Harness assertion
changed from `btn_end_turn != null` to `get("btn_end_turn") == null`.

**Lesson for future runs:** "0 failed" in this project means *no assertion tripped*,
not *no errors occurred*. Boot the project headless (`godot --headless --path .`)
and grep for `SCRIPT ERROR` to see what the harness hides.

---

### 2026-07-07 (final) — both honesty-addendum defects fixed

- `src/ui/widgets/stat_bar.gd`: replaced `add_theme_font_features_override("tnum")`
  with a `FontVariation` + opentype `tnum` feature override. Tabular HP numbers work,
  no runtime error.
- `src/ui/base_hud.gd` (new): shared `CanvasLayer` base for all gameplay HUDs.
  Declares `rest_pressed`/`save_pressed`/`menu_pressed`/`settings_pressed`/`sheet_pressed`
  signals + `var log_text` + `clear_logs()`/`add_log()`.
- `combat_hud.gd`, `overworld_hud.gd`, `dungeon_hud.gd`: `extends BaseHUD`; removed
  duplicated signal/log declarations; assign inherited `log_text` in `_ready`.
- `dungeon_hud.gd`: no longer `extends OverworldHUD`; no `end_turn_pressed`; real
  system-row wiring in `dungeon_state.gd` (`_on_rest_pressed` etc., incl. a
  `_rest_party()` that mirrors `OverworldState`).
- `scenes/dungeon.tscn`: `BtnEndTurn` node removed.
- `src/viewport_harness.gd`: dungeon assertions now verify the End Turn button is
  *absent* and the system-row signals *exist*.

**Verified (engine-booted, not changelog-trust):** full project boot = 0 script errors;
logic suite = 244/0; viewport harness = 12/0 (0 `SCRIPT ERROR`, 0 `Nonexistent function`).
Note: the `.godot` global-class cache must be regenerated (`godot --headless --editor --quit`)
after adding `BaseHUD` or dependent HUDs fail to resolve the base class.

### 2026-07-08 — UI widget library, test hardening, doc reconciliation

**Test infrastructure:**
- `run_tests.sh`: added a **boot-error gate** — boots `res://scenes/main.tscn`
  headless (wrapped in `timeout 30`) and fails the run if the engine logs any
  `SCRIPT ERROR` / `Nonexistent function` / `Parse Error` / `Cannot infer`. This
  closes the gap called out in the 2026-07-07 honesty addendum ("0 failed ≠ no
  errors"). Same gate also fixed a latent bug where a headless `main.tscn` boot
  never exits and would hang the run (now bounded).
- `src/test_runner.gd`: added `_test_widgets()` group (UI Widgets) covering
  `LogPanel` and `ActionBar`. Logic suite total is now **244 passed, 0 failed**.

**UI widgets delivered:**
- `src/ui/widgets/log_panel.gd` (`class_name LogPanel extends RichTextLabel`):
  severity-aware log (`log_info` / `log_danger` / `add_log` shim, `clear_logs()`).
  Wired into all four HUD scenes (`combat`/`dungeon`/`dungeon_hud`/`overworld`)
  by changing the `LogText` node `type` from `RichTextLabel` to `LogPanel`
  (backwards-compatible — `.text` still resolves, harness assertions survive).
- `src/ui/widgets/action_bar.gd` (`class_name ActionBar extends HBoxContainer`):
  consistent icon+label action row. `add_action(id,label,icon?,cb?)`,
  `push_right()`, `trigger(id)`, `clear_actions()`. **Icon-optional** — works
  with no art assets, ready for icons once an icon source is chosen.

**Docs reconciled (were stale vs. live code):**
- `roadmap.md`: Phase 2 (overworld resting / town shops / campaign save-load)
  marked **COMPLETE** — the code and `save_manager.gd` were already landed; the
  table just never got checked off.
- `docs/UI_OVERHAUL_RESEARCH.md`: §0 corrected — `BaseHUD` extraction and the
  `stat_bar.gd` font defect (`add_theme_font_features_override`) were both
  actually DONE on 2026-07-07 (the research writeup predated those fixes). Added
  a "Corrections (2026-07-08)" subsection; resolved stale §0.1.

**Still open (needs sign-off / assets):** Phase 3 VFX/audio (no art or audio
files in `assets/` yet), Phase 5 Mod Manager UI + visual editors (no art), and
mounting `ActionBar` into HUD scenes (blocked on icon-art direction — see
UI_OVERHAUL_RESEARCH.md §6 open question 2).

**Verified:** `run_tests.sh` → OVERALL: ALL TESTS PASSED (49 scripts parse clean,
boot-error gate clean, 244 logic / 12 viewport).

### Data verified at boot (2026-07-07)
`[DataLoader] Loaded: 14 classes, 9 races, 232 items, 198 spells, 453 monsters, 4 event tables, 1 campaigns`
