# Batch 049 build: species/feat/item modes and upgrades (card Q-20261020-154337-209c)

## Base
- Stacked on `batch-048-item-types-measurements` @ e3869bb (PR #17, accepted).
- Reason: this batch changes `src/autoload/data_loader.gd` and `src/characters/inventory.gd` (both changed by #17) and registers its checks/scenario in `src/test_runner.gd`, `src/viewport_harness.gd` and `run_tests.ps1` (changed by #16 and #17). PR base is `batch-048-item-types-measurements`.

## Finish line
"Acquire and restore these benefits from their actual source, including exact equipped/attuned copies. Prove reload preserves choices, uses and deadlines without duplicating benefits. Class/subclass ownership is already repaired (verify where on main/stack before building)."

## Where class/subclass ownership was repaired (verified before building)
- Commit **9c63252** "Fix ownership and interruption failures across runtime batches 034-046", which is on `origin/main` (merged with PRs #1-#15) and therefore under #16/#17.
- `FeatureModeRules.declared_features(data)` (src/characters/feature_mode_rules.gd) rebuilds class + subclass features up to the saved level; it is shared by `FeatureModeRules.saved_error` and `RuleUpgradeRules.saved_error`, which SaveManager calls on both the player and party-checkpoint routes (save_manager.gd ~354 and ~540).
- Regression: `StackRepairChecks._subclass_modes` (src/stack_repair_checks.gd) — subclass mode, alternative and hit window survive reload; features above the saved level stay unowned.
- Card 209c's own handoff (Rook, 21:19Z) narrowed it to the remaining species/feat/item host. That remaining host is this batch.

## Changes
### `OwnedFeatureSources` (new, src/characters/owned_feature_sources.gd)
One resolver for non-class owners of `mode_choice` / `rule_upgrade` features, used for live actors and for save DTOs:
- **Species:** `race.features` (only these two types are acquired; other race feature records are untouched).
- **Feats granted by the species:** `race.feats` lists feat ids; each feat's `features` are acquired.
- **Exact item copies:** an item's `features` belong to one equipped copy, and to an attuned one when the item requires attunement. Ids are namespaced `<feature>@<instance_id>`, `source_instance_id` is set, and the item's own upgrades are re-targeted to that namespace. A second equipped copy of the same definition never stacks.
- `sync(actor, restoring)` rebuilds the acquired set idempotently: features whose source left are removed, and their saved mode state and alternatives end. Use pools stay keyed by source, so taking a copy off and putting it back cannot refill uses. A new acquisition at runtime starts full; a restore only clamps saved uses.
- `declared_in(dto)` gives the same set from a save; `FeatureModeRules.declared_features` now appends it, so modes and alternatives saved for an unattuned, unequipped, forged copy or a different species are refused on both save routes.

### Loader
- New content type `feat` (`data/<layer>/feats/`, required `id`, `name`, `features`) and `DataLoader.get_feat`.
- `OwnedFeatureSources.definition_error` for race/feat/item: unique ids without `@`, at most four mode/upgrade features, normal `validate_rule` checks; item features must be mode/upgrade only and item upgrades must target a rule on the same item; no authored `source_instance_id`; species `feats` must be unique ids.

### Hosts (production callers)
- `Character.initialize` → `sync` (species and its feats).
- `Character.from_dict` → `sync(self, true)` right after the inventory is restored.
- `Inventory._publish_equipment_change` (equip/unequip/drop/destroy), `unequip` (after settling the ledger), `attune_instance`, `unattune_instance`, `break_cursed_item_attunements` → `sync`.

## Mandatory checklist
- **(a) Refuse before cost.** Activation refusals happen before `use_feature`. Logic and scenario both assert the pool is unchanged after: activating a worn but unattuned copy (it owns nothing), and an over-target activation. Choosing an alternative while the mode is active is refused (existing rule) and the test relies on it.
- **(b) Records.** No new nested inventory or save record. Item uses live in `feature_uses`, mode state in `feature_modes`, choices in `rule_alternatives` — all existing, validated records. The attuned copy record is asserted to still pass `InventoryCopies.record_state_error`.
- **(c) Production callers.** `definition_error` ← `DataLoader._validate_content`; `declared_in` ← `FeatureModeRules.declared_features` (← SaveManager both routes, `RuleUpgradeRules.saved_error`); `declared`/`item_features` ← `sync`/`declared_in`; `sync` ← initialize, from_dict and the inventory hooks; `get_feat` ← `declared`.
- **(d) Real persistence.** The scenario uses `SaveManager.save_game`/`load_game` with no cache clearing: choices, uses, deadlines and alternatives match; each rule appears once; AC totals match; the feat deadline then expires on schedule after load while the item keeps running.
- **Legacy saves:** a save without copies, modes or alternatives loads and acquires nothing; the full suite's legacy save fixtures pass.

## Validation (Godot runs strictly one at a time)
- Fresh e3869bb baseline, run alone: **5385 passed, 0 failed**.
- Branch logic suite: **5405 passed, 0 failed** (+20 = the 20 `check.call` lines in batch_049_checks.gd).
- Catalog: 289 items, 0 validation failures (unchanged).
- Scenarios (ok count, 0 FAIL, 0 script/parse errors): 031 25, 032 33, 033 70, 034 10, 035 9, 036 7, 037 11, 038 7, 039 10, 040 12, 041 10, 042 10, 043 11, 044 12, 045 16, 046 16, 047 10, 048 8, **049 9**, shared_spell_flow 67.
- Note: a first wiring that re-synced the copy ledger inside every equipment event broke 041/043 (dropped copies were resurrected). The final wiring resyncs the ledger only after `unequip` completes.

## Limits and follow-ups
- No HUD control activates modes or picks alternatives for any source (class included); that is unchanged and still a UI follow-up.
- Feats come only from the species (`race.feats`). There is no feat chooser/ASI feat path, and no SRD feat content was authored; all content is neutral fixtures.
- Changing species after creation has no production path; the scenario sets the fixture species and calls `sync`.
- Rest refills reach only currently owned rules, so an unequipped copy's spent pool refills only after it is worn again and rested.
- Spent pools of copies that left the inventory are kept (keyed by instance id) to block refills; they are not pruned.
- 047 reviewer note still open (not changed): the form/equipment chooser opens before `validate_actor`.
- New card **Q-20261020-230919-ac39** (ready, unclaimed): `local_room_rules.gd:1221` treats a dropped item of unknown weight as 1 lb.
