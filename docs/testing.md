# Testing

The supported engine baseline is Godot 4.7.x on Windows. Provide a portable
executable through `GODOT_BIN` or pass its path to the PowerShell runner.

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7-stable_win64.exe'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1
```

`run_tests.sh` remains available as compatibility tooling, but native Linux
execution is not part of Gate 1 completion evidence.

The first case runs a headless recovery-mode editor scan. This creates the
ignored `.godot` class-name and import caches required by a clean checkout
without activating editor plugins. The parse gate then evaluates the project
with the same class registry a normal first editor launch would create.

The gate stops on a non-zero process exit, timeout, missing result marker, or
unexpected Godot error. Each scenario receives a disposable `user://` root;
the PowerShell runner redirects Windows profile roots. Logs are written to a
temporary directory and its path is printed at the end. Set `TEST_LOG_DIR` to
retain them at a chosen location.
The Windows Godot build may emit `Failed to read the root certificate store`
under this host profile; the runner allows that exact platform warning. Leak,
resource, and other generic `ERROR:` lines remain failures.

The gate-case manifest is:

| Case | Contract |
|---|---|
| `project_bootstrap` | A cache-free checkout can build Godot's generated class/import state |
| `parse_gate` | Every project script loads with autoload and `class_name` dependencies available |
| `boot_gate` | The production main scene settles without an unexpected engine error |
| `logic` | Data loading, character creation, dice, validated combat/player commands, spellcasting, action economy, AI, inventory, conditions, serialization, players, events, fog, hex math, saves, and UI widget contracts |

The current integration scenario manifest is:

| Scenario | Player-facing contract |
|---|---|
| `combat` | Combat boot, party/monster spawn, initiative, HUD, and turn progression |
| `party_combat` | Four-member supported save/load, leadership and logical ownership persistence, active-character spell isolation, and distinct combat formation |
| `crown_smoke` | Bounded Crown path through overworld, dungeon, event, finale encounter, objectives, and completion screen |
| `combat_ai_loop` | Live monster AI intent and action through the combat loop |
| `combat_victory` | Live player actions reach victory and register defeated monsters |
| `combat_defeat` | Live combat detects a party wipe and the defeat screen exposes safe-save recovery and menu exit |
| `final_encounter_round_trip` | Production Lich King defeat, pre-finale safe reload, victory, idempotent reward claim, and completion screen |
| `mixed_mechanics_encounter` | Bounded production-data encounter composes martial attack, bonus action, owned reaction, concentration, healing, save spell, and area selection |
| `overworld` | Overworld, fog, rest, save, settings overlay, and ambush path |
| `companion_lifecycle` | Production Camp Roster UI fills a solo party, declines/reconsiders candidates, replaces and dismisses companions, and reassigns ownership in two-player play |
| `crown_composition_solo_two` | Solo plus three companions and two-player plus two companions through Camp Roster ownership, safe save/load, Crown objective, combat ownership, and formation |
| `crown_composition_three_four` | Three players plus one companion and four local characters through Camp Roster/party setup, safe save/load, Crown objective, combat ownership, and formation |
| `main_menu_load` | Main-menu save-slot loading UI |
| `dungeon` | Dungeon scene, rooms, HUD, and traversal wiring |
| `event_dialog` | Event dialog presentation and resolver wiring |
| `crown_event_fairy_ring` | Production Fairy Ring chain, three legal Fairy Court choices, DEX success/failure branches, and UI follow-up |
| `dungeon_reentry_round_trip` | Production Crown dungeon clear, plain Room DTO checkpoint, supported reload, cleared-room rebuild, and idempotent boss/reward revisit |
| `character_creation` | Character-creation scene boot and legal choices |
| `normal_creation_matrix` | Production main-menu player-count controls and character creation for one through four local players, including stable seat ownership and empty companion slots |
| `shop` | Shop scene, inventory, purchase, and sell wiring |
| `save_load` | Save/load round trip and cleanup of the test slot |
| `scripts/validate_crown_fresh_relaunch.ps1` | Separate-process Crown overworld safe-save recovery for party ownership, objective, cleared dungeon, reward ledger, and available state |
| `scripts/validate_crown_two_player_relaunch.ps1` | Separate-process progressed two-player Crown recovery for seat ownership, leadership, objectives, two dungeon clears, rewards, and quest fragments |
| `action_resource_round_trip` | Spends a production Fighter feature and Wizard spell slot, reloads at the overworld safe point, and boots the next combat from the restored state |
| `combat_resolution` | Combat result resolution through the live scene |
| `event_choice_resolution` | Event choices resolve through campaign state |
| `event_dialog_choice_click` | UI choice click reaches the event resolver |
| `character_sheet` | Character sheet opens, renders sections, and closes |
| `character_sheet_contexts` | The real Character Sheet button opens the correct character from overworld, dungeon, and combat HUDs |
| `character_value_audit` | Representative race/class values survive initialization, level-up, save/load, runtime HP mutation, and Character Sheet rendering |

The viewport harness also supports `--scenario=all` for local debugging. The
repository runner accepts `-Scenario <name>` for a single integration case;
otherwise it invokes each scenario separately so each one owns its process
lifetime, timeout, log, and result marker.
