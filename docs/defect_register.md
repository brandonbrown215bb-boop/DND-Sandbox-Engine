# Gate 0 confirmed defect register

These are confirmed from source inspection or the Godot 4.7 validation run. `Pending` means the follow-up owner or implementation work is not yet assigned; it is not a claim that the defect is harmless.

| ID | Priority | Defect | Evidence | Owner | Status |
|---|---|---|---|---|---|
| G0-DATA-01 | P0 | Core item, spell, and monster IDs collide. | 112 item collision IDs, 14 spell collision IDs, and 7 monster collision IDs; the ID-keyed loader silently overwrites one record. | Data | Confirmed; pending collision manifest and policy |
| G0-DATA-02 | P0 | Class feature records contain no executable effects. | 193/193 class feature records have empty `effects`; all 14 classes are affected. | Rules/content | Confirmed; pending feature effect contract |
| G0-DATA-03 | P0 | Class spell lists are empty. | `spells_known_by_level` contains zero spell entries across all 14 class files. | Rules/content | Confirmed; pending spell-list mapping |
| G0-DATA-04 | P1 | The 5etools importer contains a developer-specific absolute source path. | `src/convert_all_5etools.py` references `/run/media/pigeon/...`; it is not portable from a clean checkout. | Data/import | Confirmed; pending portable path rewrite |
| G0-SAVE-01 | P0 | Main-menu Load is disabled even when a quicksave exists. | `main_menu_load` failed `load button enabled when saves exist` after writing `user://saves/quicksave.sav`. | Save/UI | Closed; full Gate 1 `main_menu_load` scenario passed |
| G0-SAVE-02 | P0 | The save/load harness saves from `MAIN_MENU`, then expects a resumable load. | `SaveManager.load_game` correctly rejected the slot with `has no in-progress game (MAIN_MENU state)`; the scenario's precondition is invalid. | Test/save | Closed; scenario now establishes an `OVERWORLD` save and passed Gate 1 |
| G0-CAMPAIGN-01 | P0 | Milestones are repeatable because no completed-milestone ledger is checked. | `GameManager.check_milestone()` applies matching effects and returns without recording the trigger. | Campaign | Confirmed; pending idempotent campaign ledger |
| G0-CAMPAIGN-02 | P0 | `GAME_OVER` has no destination scene in the state map. | `GameManager.end_game()` enters `GAME_OVER`, but `STATE_SCENES` has no `GAME_OVER` entry; no terminal scene is mapped. | Campaign/UI | Confirmed; pending provisional victory/defeat scenes |
| G0-CAMPAIGN-03 | P0 | The live combat-victory scenario did not settle. | Baseline run reached the overworld bootstrap and timed out before its first result marker. Gate 1 focused rerun now completes with 3 passing assertions and exit 0 after suppressing the harness-destructive test-mode scene transition. | Combat/harness | Closed; focused and full Gate 1 runs passed |
| G0-UI-01 | P1 | Character-sheet creation races the scene tree. | `character_sheet` passed assertions but emitted `Parent node is busy setting up children, add_child() failed` at `src/autoload/character_sheet.gd:43`; leaked text/font/canvas RIDs followed. | UI | Closed; isolated Gate 1 scenario passed without engine errors or leaks |
| G0-HARNESS-01 | P1 | The logic suite exits with leaked resources. | Godot reported `124 ObjectDB instances`, `3 CanvasItem RIDs`, and `2 resources still in use` after 242 passing assertions. | Test/harness | Closed; 263-assertion Gate 1 logic run exited cleanly |
| G0-RUNTIME-01 | P0 | Beckett runtime is enabled in the default project configuration. | `project.godot` enables the Beckett plugin/autoload; the roadmap requires development control surfaces to be disabled for friend-facing play. | Runtime | Confirmed; pending explicit development flag |

## Validation interpretation

The defects above are Gate 0 inventory results. They are not silently converted into green claims by a test count. Gate 0 is recorded as `done`; closed rows name their verification, and the remaining open P0/P1 work is carried into later roadmap gates.
