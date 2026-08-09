# Architecture Overview: Top Down Party Game

This document details the high-level architecture and design of the Top Down Party Game's engines, singletons, models, and state loops.

The current implementation baseline is recorded in [Gate 0 evidence](gate0_evidence.md), [the feature matrix](feature_matrix.md), and [the defect register](defect_register.md). The paths below describe reachable code, not completed campaign contracts.

---

## 1. Global Managers (Autoload Singletons)

These persistent systems manage cross-scene states and global services.

### [GameManager](../src/autoload/game_manager.gd)
- **Role**: Coordinates the primary state machine (`GameState` enum) and orchestrates fades and scene transitions between menus, overworld, dungeons, and combat.
- **Victory Condition Check**: Evaluates active campaign victory goals (`check_campaign_victory()`), tallying quest items across party inventories and verifying boss defeats. The terminal `GAME_OVER` scene is not yet mapped.
- **Milestones**: Resolves campaign triggers to apply party level-ups dynamically.

### [PlayerManager](../src/autoload/player_manager.gd)
- **Role**: Tracks active player indices, colors, names, coordinates, and alive states for hot-seat local multiplayer.
- **Serialization**: Provides `serialize()` and `deserialize()` to flatten player slots and character sheets.

### [DataLoader](../src/autoload/data_loader.gd)
- **Role**: Recursively scans and registers all JSON file data from `res://data/core/` and overrides them with any assets loaded from `res://data/mods/` with identical IDs.
- **Registries**: Manages registries for classes, races, items, spells, monsters, event tables, and campaigns.

### [SaveManager](../src/autoload/save_manager.gd)
- **Role**: Handles persistence. Serializes campaign metadata, active dungeon crawl states, round counters, player coordinates, and character lists to `user://saves/` as JSON-formatted files.
- **Slots**: `get_available_saves()` lists all `*.sav` slots; `save_game(slot)` and `load_game(slot)` read/write named slots.

### [Settings](../src/autoload/settings.gd)
- **Role**: Persistent player options and the settings overlay.
- **Pause overlay**: `open_settings()` pauses the tree and mounts `scenes/ui/settings_overlay.tscn` on a high `CanvasLayer`; `close_settings()` resumes it.

### [CharacterSheet](../src/autoload/character_sheet.gd)
- **Role**: Read-only overlay rendering a character's stats, inventory, conditions, spells, and features.
- **Access**: The overworld, dungeon, and combat HUDs open it for the active or current-turn character.

### [Dice](../src/autoload/dice.gd)
- **Role**: Evaluates advantage/disadvantage rolls and parses mathematical dice string formulas (e.g. `2d6 + STR`).

---

## 2. Grids and Math

Coordinate-based modules manage spatial pathfinding and rendering on the overworld map and dungeon layouts.

- **[HexGrid](../src/hex/hex_grid.gd)**: Manages tiles, highlight overlays, and paths.
- **[HexTile](../src/hex/hex_tile.gd)**: Encapsulates terrain, fog-of-war visibility, and tile properties.
- **[HexUtils](../src/hex/hex_utils.gd)**: Provides axial coordinate arithmetic, neighbors, and distances.

---

## 3. Characters and Statistics

- **[Character](../src/characters/character.gd)**: Core stats, hit points, spell slots, features, and conditions.
- **[AbilityScores](../src/characters/ability_scores.gd)**: Raw ability scores, point-buy costs, and modifiers.
- **[Inventory](../src/characters/inventory.gd)**: Gold, backpack slots, and equipment slots.

---

## 4. Local States (Game Loops)

- **[OverworldState](../src/overworld/overworld_state.gd)**: Overworld navigation, fog of war, rest, and destination resolution.
- **[DungeonState](../src/dungeon/dungeon_state.gd)**: Room-based dungeon traversal, traps, loot, and encounters.
- **[CombatState](../src/combat/combat_state.gd)**: Tactical grid, initiative, monster AI, and win/lose evaluation.
- **[CombatAction](../src/combat/combat_action.gd)**: Attack rolls, spell effects, concentration checks, saves, and reactions.

---

## 5. Testing & Verification

`run_tests.ps1` is the supported Windows test gate. `run_tests.sh` retains the
same case structure as compatibility tooling. Both resolve Godot from an
explicit argument, `GODOT_BIN`, or `godot`/`godot4` on `PATH`; neither contains
a developer-specific executable path. Each stage has its own bounded process,
result marker, captured log, and exit code. On Windows,
`scripts/invoke_godot_case.ps1` isolates raw native stream capture and returns
the real Godot exit code to the timeout supervisor.

The gate runs, in order:

1. A headless recovery-mode editor scan creates ignored first-run class and
   import caches without activating editor plugins.
2. `parse_gate.tscn` loads every `.gd` under `src/` and `scenes/` from a live
   project scene, keeping autoloads and project `class_name` declarations in
   scope.
3. `boot_gate.tscn` instantiates production `main.tscn`, waits for a short
   settle period, and exits with `BOOT GATE PASSED`. A timeout is a failure.
4. `test_runner.tscn` runs the logic suite and must print `ALL TESTS PASSED`.
5. `viewport_harness.tscn` runs each named integration scenario in a fresh
   Godot process using `--scenario=<name>`. A failed or hung scenario cannot
   hide the result of later scenarios. The harness retains `all` mode for local
   debugging, but the repository gate uses isolated mode.

The runners fail on non-zero exits, missing markers, timeouts, and unexpected
Godot error lines. The exact Windows certificate-store warning is the only
current allowlist; teardown leaks and resource errors fail their owning case.
See [Testing](testing.md) for the command and scenario manifest.
