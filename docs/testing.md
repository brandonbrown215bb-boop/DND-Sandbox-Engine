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
| `logic` | Data loading, character creation, dice, combat actions, spellcasting, AI, inventory, conditions, serialization, players, events, fog, hex math, saves, and UI widget contracts |

The current integration scenario manifest is:

| Scenario | Player-facing contract |
|---|---|
| `combat` | Combat boot, party/monster spawn, initiative, HUD, and turn progression |
| `combat_ai_loop` | Live monster AI intent and action through the combat loop |
| `combat_victory` | Live player actions reach victory and register defeated monsters |
| `overworld` | Overworld, fog, rest, save, settings overlay, and ambush path |
| `main_menu_load` | Main-menu save-slot loading UI |
| `dungeon` | Dungeon scene, rooms, HUD, and traversal wiring |
| `event_dialog` | Event dialog presentation and resolver wiring |
| `character_creation` | Character-creation scene boot and legal choices |
| `shop` | Shop scene, inventory, purchase, and sell wiring |
| `save_load` | Save/load round trip and cleanup of the test slot |
| `combat_resolution` | Combat result resolution through the live scene |
| `event_choice_resolution` | Event choices resolve through campaign state |
| `event_dialog_choice_click` | UI choice click reaches the event resolver |
| `character_sheet` | Character sheet opens, renders sections, and closes |

The viewport harness also supports `--scenario=all` for local debugging. The
repository runners deliberately invoke individual scenarios so each one owns
its process lifetime, timeout, log, and result marker.
