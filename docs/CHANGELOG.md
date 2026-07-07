# Changelog — Top Down Party Game

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
