# Architecture Overview: Top Down Party Game

This document details the high-level architecture and design of the Top Down Party Game's engines, singletons, models, and state loops.

---

## 1. Global Managers (Autoload Singletons)

These persistent systems manage cross-scene states and global services.

### [GameManager](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/autoload/game_manager.gd)
- **Role**: Coordinates the primary state machine (`GameState` enum) and orchestrates fades and scene transitions between menus, overworld, dungeons, and combat.
- **Victory Condition Check**: Evaluates active campaign victory goals (`check_campaign_victory()`), tallying quest items across party inventories and verifying boss defeats.
- **Milestones**: Resolves campaign triggers to apply party level-ups dynamically.

### [PlayerManager](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/autoload/player_manager.gd)
- **Role**: Tracks active player indices, colors, names, coordinates, and alive states for hot-seat local multiplayer.
- **Serialization**: Provides `serialize()` and `deserialize()` to flatten player slots and character sheets.

### [DataLoader](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/autoload/data_loader.gd)
- **Role**: Recursively scans and registers all JSON file data from `res://data/core/` and overrides them with any assets loaded from `res://data/mods/` with identical IDs.
- **Registries**: Manages registries for classes, races, items, spells, monsters, event tables, and campaigns.

### [SaveManager](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/autoload/save_manager.gd)
- **Role**: Handles persistence. Serializes campaign metadata, active dungeon crawl states, round counters, player coordinates, and character lists to `user://saves/` as JSON-formatted files.
- **Slots**: `get_available_saves()` lists all `*.sav` slots; `save_game(slot)` and `load_game(slot)` read/write named slots. The overworld "Save Game" button writes a `quicksave` slot; the main menu "Load Game" picker reads any slot.

### [Settings](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/autoload/settings.gd)
- **Role**: Persistent player options + the save/load-anywhere API used by the settings overlay. Writes player settings (master/sfx/music volume, screen shake, high contrast, damage numbers, tooltip delay) to `user://settings.cfg` as JSON.
- **Save/Load delegation**: `save_game(slot)` / `load_game(slot)` / `get_saves()` wrap `SaveManager` so saving and loading work from anywhere a game is in progress (overworld, combat, or the main menu).
- **Pause overlay**: `open_settings()` pauses the tree (`get_tree().paused = true`) and mounts `scenes/ui/settings_overlay.tscn` on a high `CanvasLayer` (`process_mode = ALWAYS`). `close_settings()` resumes the tree. The gear button (`Settings ⚙`) in the overworld and combat HUDs opens it.

### [CharacterSheet](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/autoload/character_sheet.gd)
- **Role**: Read-only overlay rendering a character's full stats/variables — ability scores + modifiers, HP/AC/speed/proficiency, saving throws, all 18 skills, equipment + backpack, active conditions, spell slots/known spells, and class features with remaining uses.
- **Access**: A "Character Sheet" button is wired into the **overworld**, **dungeon** (`OverworldHUD`), and **combat** (`CombatHUD`) HUDs. Overworld/dungeon open the active player (`show_active()`); combat opens the turn's active character (`show_sheet(active_character)`). The overlay (CanvasLayer drawn above scene HUD, dismiss with the close button or Esc) does not pause the game.

### [Dice](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/autoload/dice.gd)
- **Role**: Evaluates advantage/disadvantage rolls and parses mathematical dice string formulas (e.g. `2d6 + STR`).

---

## 2. Grids and Math

Coordinate-based modules manage spatial pathfinding and rendering on the overworld map and dungeon layouts.

- **[HexGrid](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/hex/hex_grid.gd)**: Manages a collection of tiles mapped by axial coordinates (`Vector2i`), generating highlight overlays and calculating A* paths.
- **[HexTile](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/hex/hex_tile.gd)**: Encapsulates individual cell parameters, such as terrain type (move cost and terrain color representation), Fog of War visibility, location names, and custom properties.
- **[HexUtils](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/hex/hex_utils.gd)**: Axial coordinate arithmetic mapping directions, neighbors, and distances.

---

## 3. Characters and Statistics

The statistics models handle character sheets and progression rules.

- **[Character](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/characters/character.gd)**: Core stats container managing level, XP, hit point thresholds, spell slot structures, passive features list, and status conditions.
- **[AbilityScores](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/characters/ability_scores.gd)**: Holds raw scores for the six core attributes (STR, DEX, CON, INT, WIS, CHA) and manages point-buy costs and modifiers.
- **[Inventory](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/characters/inventory.gd)**: Manages gold balance, backpack slots, and equipment slots.

---

## 4. Local States (Game Loops)

- **[OverworldState](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/overworld/overworld_state.gd)**: Implements overworld navigation, Fog of War, camera tracking, and destination resolution (dungeons, event cards, and towns).
  - **Wilderness rest + ambush**: The overworld HUD "Rest" button heals the whole party and restores spell slots / per-rest feature uses for free, then rolls a **Stealth check** to avoid an ambush. The best party Stealth bonus (DEX modifier + proficiency if Stealth-trained) is rolled against a DC of `12 + (party_size − 1)`. Success = peaceful night; failure = a surprise encounter (`enter_combat(..., surprise=true)`). This replaced the earlier flat 40% ambush roll.
  - **HUD buttons** (sidebar): End Turn, Rest, Save Game (`quicksave` slot), Quit to Menu, and Settings (`Settings.open_settings`).
- **[DungeonState](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/dungeon/dungeon_state.gd)**: Drives room-based dungeon crawls, handling traps, loot chests, and spawning dungeon monster lists.
- **[CombatState](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/combat/combat_state.gd)**: Manages the tactical grid, initiative turn order queue, monster AI execution, and win/lose evaluations.
  - **Equipped weapon + range**: The combat HUD sidebar shows the active character's equipped weapon and its range (`Weapon: <name> (melee/reach 1)` or `range N hexes`), read from the weapon item's `range` field. Attacks are range-gated: clicking a monster outside the weapon's range is rejected with an "out of range" log (the attack highlight already only marks in-range targets; execution now enforces it too).
- **[CombatAction](file:///run/media/pigeon/890dd7cb-9753-4f6b-b8e6-58c98e531754/Projects/Top Down Party Game/src/combat/combat_action.gd)**: Handles attack rolls, spell effects, constitution checks for concentration, evasion saves, and reaction spell queries (Shield, Counterspell, and Uncanny Dodge).

---

## 5. Testing & Verification

Two harnesses gate every change:

### Logic suite — `test_runner.tscn` (GUT)
Standard GUT test scene. Pure-logic tests (resolvers, AI decisions, data integrity, save/load round-trips). Runs headless, fast (~30s), exits cleanly. This is the first gate in `run_tests.sh`.

### Viewport harness — `src/viewport_harness.gd`
Instantiates the **real** combat / overworld / dungeon / event / shop / character-creation scenes inside a headless `SubViewport` and asserts `_ready` wiring actually executed (grid build, HUD signal connect, spawn, initiative, fog update, event plumbing). It is a single ~650-line `Node` whose entire flow lives in one `_ready()` coroutine: ~15 sequential "beats" inline, each `await`ing a Godot timer (`get_tree().create_timer`) to let a scene settle before poking it.

**Where it costs time (known friction):**
- *Parse errors don't fail fast.* A typo in any touched script isn't caught by the suite until the engine loads that script — and a broken script reference makes the harness scene itself fail to parse, which then **hangs** (the process idles at ~0.6% CPU) rather than erroring out. Diagnosis requires killing the run and launching the scene directly to read the buffered error. (Mitigation in practice: run `godot --check-only --script res://<file>` per changed file before the full suite.)
- *No isolation between beats.* Every beat is inline in one coroutine. A late failure can't be attributed without reading the whole chain, and a stall in one beat blocks everything after it.
- *Timing-dependent.* Beats rely on fixed `await` durations; a turn that doesn't resolve within the window silently desyncs the assertions that follow.
- *No result until the end.* `ALL TESTS PASSED` only prints after the logic suite *and* the full viewport chain, so a single late parse error forces re-running the entire ~3.5-min logic pass first.

**Candidate restructure (not yet adopted):** split the monolithic `_ready()` into discrete, individually-named test methods (`test_combat_boot`, `test_weapon_range`, `test_p1_intent`, …), each self-contained with its own SubViewport + teardown, so a failure reports a named test instead of stalling the chain; add a pre-flight parse pass over all `src/**/*.gd` (the `--check-only` loop) as a first, fast gate before booting any scene; and prefer direct method calls + state inspection over `await`-based settling wherever possible to remove timing flakiness.
