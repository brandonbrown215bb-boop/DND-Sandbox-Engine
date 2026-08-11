# Architecture Overview: Top Down Party Game

This document details the high-level architecture and design of the Top Down Party Game's engines, singletons, models, and state loops.

The current implementation baseline is recorded in [Gate 0 evidence](gate0_evidence.md), [the feature matrix](feature_matrix.md), and [the defect register](defect_register.md). The paths below describe reachable code, not completed campaign contracts.

---

## 1. Global Managers (Autoload Singletons)

These persistent systems manage cross-scene states and global services.

### [GameManager](../src/autoload/game_manager.gd)
- **Role**: Coordinates the primary state machine (`GameState` enum) and orchestrates fades and scene transitions between menus, overworld, dungeons, and combat.
- **Victory Condition Check**: Evaluates active campaign victory goals (`check_campaign_victory()`), tallying quest items across party inventories and verifying boss defeats. Completion and defeat route to explicit terminal scenes; legacy `GAME_OVER` maps to defeat.
- **Milestones**: Resolves campaign triggers to apply party level-ups dynamically.

### [PlayerManager](../src/autoload/player_manager.gd)
- **Role**: Tracks active player indices, colors, names, coordinates, and alive states for hot-seat local multiplayer.
- **Serialization**: Provides `serialize()` and `deserialize()` to flatten player slots and character sheets.

### [PartyManager](../src/autoload/party_manager.gd)
- **Role**: Owns four stable party slots, character identity, companion lifecycle, leadership, and the bridge between local player seats and party membership.
- **Serialization**: Stores party slots, companions, leader identity, and character DTOs without device bindings or live engine objects.

### [DataLoader](../src/autoload/data_loader.gd)
- **Role**: Loads core content before mods, validates every duplicate against `data/content_manifest.json`, and applies only declared precedence and merge rules. Enumeration order is not a content contract.
- **Registries**: Manages registries for classes, races, items, spells, monsters, event tables, and campaigns, then validates cross-record references before exposing the loaded state.
- **Quarantine boundary**: Unsupported effectless feature records are removed from player-facing data until a resolver and player-facing contract exist; curated spell access and other approved fields are applied after registration.

### [SaveManager](../src/autoload/save_manager.gd)
- **Role**: Handles transactional persistence. It serializes campaign ledgers, dungeon room state, round counters, player coordinates, party slots, companion state, and character DTOs to `user://saves/` as versioned JSON.
- **Safe boundary**: `save_game(slot)` rejects active combat, events, transitions, and active dungeon rooms; supported saves are the overworld and explicit dungeon-entry checkpoints. `load_game(slot)` validates the complete DTO before changing active managers.
- **Slots**: `get_available_saves()` lists named save slots; save and load preserve stable IDs and arrays rather than live Godot objects.

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
- **[CombatState](../src/combat/combat_state.gd)**: Coordinates the tactical scene, initiative, owner-labelled turns, monster AI, pending input, and win/lose evaluation. It is the scene coordinator, not the sole domain boundary.
- **[CombatCommand](../src/combat/combat_command.gd), [AICommand](../src/combat/ai_command.gd), and [PlayerCommand](../src/player_command.gd)**: Normalize UI and AI intent before scene-state dispatch.
- **[CombatTurnBudget](../src/combat/combat_turn_budget.gd)**: Per-turn action, bonus-action, and reaction budget with extra-action restoration, consumed by CombatState.
- **[CombatAction](../src/combat/combat_action.gd)**: Shared attack rolls, movement steps, spell effects, concentration checks, saves, and reactions for player and monster paths.
- **[CombatResultPresenter](../src/combat/combat_result_presenter.gd)**: Owns terminal combat result presentation and routing data, separate from rule resolution.

---

## 5. Campaign, terminal, and test boundaries

`GameManager` owns the campaign state machine and stable campaign ledgers. It
maps `GAME_OVER` and `DEFEAT` to `scenes/defeat.tscn`, and `COMPLETION` to
`scenes/completion.tscn`; both terminal scenes use the shared
`src/ui/terminal_screen.gd` presentation boundary. Dungeon clear and reward
claims are ID-based and idempotent, while `SaveManager` persists the ledgers
and plain dungeon DTO at supported safe boundaries.

`CombatState` remains a scene coordinator with a deliberately incomplete
extraction boundary. It still owns tactical presentation, target highlighting,
pending input, turn sequencing, AI dispatch, and the calls that apply resolved
results. `CombatCommand`, `AICommand`, `CombatAction`, `CombatTurnBudget`, and
`CombatResultPresenter` provide narrow seams for further extraction; their
existence is not evidence that all combat responsibility has left
`CombatState`.

The supported Windows runner in [`run_tests.ps1`](../run_tests.ps1) creates a
fresh Godot process for parse, boot, logic, and every named integration case.
Each case gets a disposable log directory plus redirected `APPDATA` and
`LOCALAPPDATA`; `scripts/invoke_godot_case.ps1` supervises the exact process,
timeout, marker, and captured output. The project-context parse and boot gates
run before the logic and isolated viewport cases. `src/viewport_harness.gd`
uses real production scenes in test-owned `SubViewport` trees, while
`GameManager.test_mode` prevents a test-mode transition from replacing the
harness supervisor. Fresh-process save probes under `scripts/` are separate
from the viewport harness and prove only the persistence boundary named by
each probe.

---

## 6. Testing & Verification

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
