# Batch 050 build: playtest fixes for 047-049 (card Q-20261021-004820-e92f)

## Base
- #16-#18 are still open, so this stacks on `batch-049-owned-feature-sources` @ **1daa946** (Runtime Reviewer's head, after R1/R2 3ced4d1). PR base: `batch-049-owned-feature-sources`.

## Bugs (each has a logic regression and a step in the 050 scenario)
1. **Dropping an equipped item recharged it.** `Inventory.drop_equipped_instance` removed the record before any sync could stamp it. A new hook, `OwnedFeatureSources.stamp_copy`, runs first, so the leaving record carries `state.feature_uses` (exact remaining uses) and `state.rule_alternatives` (the chosen option). The new holder's acquisition restores the option first, then clamps the stamped pool to the copy's own maximum.
2. **Suppression kept a power that should have ended.** End predicates now read `FeatureModeRules.owned_rule` (the owned, upgraded rule even while the copy is suppressed or merged). `Character.add_condition` refreshes modes as soon as an incapacitating condition lands. Unconscious, Paralyzed, Petrified and Stunned count as Incapacitated.
3. **A second identical equipped copy was ignored.** The per-definition skip is gone. Each copy owns its namespaced rules and its own pool, and both are saved and reloaded. `FeatureModeRules.carriers` grants the same item's same power once (bonuses don't stack, as allowed).
4. **A missing feat id silently granted nothing.** A species naming an unknown feat is a load error: `Species '<id>' in <file>#<n> references missing feat '<id>'`. The species is not registered. This is checked after a full load (all layers present) and on single-file loads.

## Brandon's decisions
- **The copy remembers its option.** Unequipping, dropping, giving or saving stamps the chosen option on the exact copy (`record.state.rule_alternatives`). `OwnedFeatureSources.record_error` (inside `InventoryCopies.record_state_error`) accepts only that copy's own rule/group/option ids.
- **Recovery follows the source rule.** SRD 5.2.1 p.206, "The Next Dawn": "Magic items often have charges or properties that recharge at the next dawn or some other specified time."
  - Item powers may declare `"uses_per": "dawn"` in JSON. Only item features are allowed to; species and feats are refused.
  - `OwnedFeatureSources.recover_dawn` runs at each campaign day boundary from `GameManager.advance_campaign_time`, the same boundary existing daily item recharge uses. It refills every carried copy, worn or not.
  - Rest-recovered item powers keep their declared rest rule. There are no per-ID branches.
  - The wand charge path (`recover_daily_charges`) is untouched.
- **Suppression explicitly covers item powers.** A `suppress_item_magic` that lists `features` mutes that copy's modes **and** now its rule upgrades (`RuleUpgradeRules.upgrades_for`). It also refuses activation before cost. A suppression that does not list `features` leaves them alone; this is asserted.
- **Containers are PARTIAL.** Containers enforce weight only. The SRD 5.2.1 Backpack (p.96) holds "up to 30 pounds within 1 cubic foot", and the volume half is not enforced because no SRD item volumes exist. Follow-up card **Q-20261021-004820-65fc**.

## Checklist
- **(a) Refuse before cost.** Activation on a suppressed copy is refused with the pool unchanged (logic). The 049 refusals still hold.
- **(b) Records.** The new nested `record.state.rule_alternatives` and the existing `feature_uses` go through `InventoryCopies.record_state_error` → `OwnedFeatureSources.record_error`. A forged option naming another copy is refused. Legacy saves (no stamps) load unchanged, and the legacy fixtures pass.
- **(c) Production callers.**
  - `stamp_copy` ← `Inventory.drop_equipped_instance`.
  - `_stamp` ← `sync`/`stamp_copy`.
  - `recover_dawn` ← `GameManager.advance_campaign_time`.
  - `owned_rule` ← `FeatureModeRules.end`.
  - `missing_feat_error` ← `DataLoader.load_all_data` and `_validate_content`.
- **(d) Real persistence.** The 050 scenario runs all four playtest steps with real `SaveManager.save_game`/`load_game` (no cache clearing) and real campaign time to dawn.
- **Merged/suppressed/destroyed copy gate.** Item modes go through `copy_active` (merged, suppressed, destroyed); item upgrades now do too. End conditions fire regardless.

## Validation (Godot strictly one at a time)
- Fresh 1daa946 baseline: **5411 passed, 0 failed**.
- Branch: **5427 passed, 0 failed** (+16 = 16 `check.call` in batch_050_checks.gd; the 049 identical-copy check was rewritten to the new semantics).
- Scenarios (ok, 0 FAIL, 0 script errors):

  | Scenario | ok | Scenario | ok |
  |---|---|---|---|
  | 031 | 25 | 041 | 10 |
  | 032 | 33 | 042 | 10 |
  | 033 | 70 | 043 | 11 |
  | 034 | 10 | 044 | 12 |
  | 035 | 9 | 045 | 16 |
  | 036 | 7 | 046 | 16 |
  | 037 | 11 | 047 | 10 |
  | 038 | 7 | 048 | 8 |
  | 039 | 10 | 049 | 9 |
  | 040 | 12 | **050** | **8** |
  | shared_spell_flow | 67 | | |

## Limits and follow-ups
- Dawn is the campaign day boundary, as for existing daily item recharge. There is no separate sunrise clock.
- The scenario drives drop/pick-up through `drop_equipped_instance` (the combat "drop" command) and `receive_instance` (the room "take" path), not the room UI.
- No SRD spell content lists `features` yet (fixture suppression only).
- Follow-ups filed (ready, unclaimed): 051 feat acquisition **Q-20261021-004820-aaf1**, 052 HUD mode/upgrade controls **Q-20261021-004820-732c**, container volume **Q-20261021-004820-65fc**. Earlier: Q-20261020-230919-ac39 (unknown dropped room weight). The 047 chooser-before-validate_actor note is still open.

## Fix commit after acceptance (Brandon's decisions, parent steering 8:00 PM CT)
- (a) Identical copies keep separate pools: already true at d2636c4 (bug 3 checks).
- (b) "Regains at dawn" now applies wherever the copy is: held, stowed in a container (nested `state.contents`, any depth) or lying in a saved local room (`GameManager.saved_local_room_states()` objects). Unheld copies are refilled on their own record stamp at the copy's own maximum (`OwnedFeatureSources.copy_max`, honouring the remembered option), and the stamp wins on the next acquisition.
- An item power may declare `"recharge_while": "equipped" | "attuned"` (dawn powers only, loader-validated); then dawn recharge happens only while that holds. Fixture `fixture:b050_bound_blade` uses `attuned`.
- Logic: fresh d2636c4 baseline 5431/0 -> 5437/0 (+6 checks in `_dawn_anywhere`). Scenarios 031-050 and shared_spell_flow pass with the same ok counts.
- Remaining limit: items dropped mid-combat (`dropped_combat_items`) are not visited until they return to a room or inventory.
