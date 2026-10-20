# Batch 041 build: S-161 then S-164

Branch `batch-041-s161-s164`, stacked on `batch-040-s120-s163` at 54968f1 (PR #8).
Quest card Q-20261020-172337-e250. This is build evidence and has not been reviewed yet.
Slice counts and the checkpoint are unchanged.

## Selection
The registry was checked at 54968f1. No quest card claims any candidate.

| Candidate | Dependencies | Decision |
|---|---|---|
| **S-161** Exclusive exact-copy/actor bond | S-049 (**Verified**), S-026 (**Verified**) | **Chosen.** Unblocks S-162, S-165, S-202 and S-210. |
| **S-164** Equipment in forms | S-163 (open **040**, PR #8), S-049 (**Verified**) | **Chosen.** Completes V-062 with S-163 and, together with S-161, makes S-165 ready. |
| S-165 | Needs S-161 | Not ready at selection |
| S-173 | Needs S-156 (unbuilt) | Not ready |
| S-127 | Ready | Deferred: needs a reach/mastery host |
| S-196 | Ready | Deferred: a larger container subsystem; S-161 has more consumers |
| S-061 | S-060 (open 036) | Deferred: next to the item charge/wand area |

- **Exclusions:**
  - No code in `AftermathSuccessorRules` or any other S-120 successor code is touched.
  - Nothing in `DruidRules` or Wild Shape is touched.
  - Nothing in `tools/content_editor/` or the wand charge path is touched.
- **F1:** no `mode_choice` or `rule_alternatives` content is added. The bond fixture is a class feature of a neutral fixture class.

## S-161: `BondRules` (src/characters/bond_rules.gd)
- **Rule:** a source-owned class feature `exclusive_bond` declares:
  - `bond_id`
  - `target` (`item` with `item_types`, or `actor` with `creature_types`)
  - `capacity` 1–3
  - `replacement` (`refuse` or `release_oldest`)
  - `unique`

  It is validated at load (DataLoader feature branch) and refuses unknown fields.
- **Bonding:** `bond(owner, bond_id, target, others)` checks eligibility first:
  - an exact copy the owner actually holds, of an eligible type, or
  - an S-154 created actor the owner actually owns, of an eligible type.

  It also refuses repeats and refuses a target bonded to another owner when the bond is unique. At capacity it either refuses, changing nothing, or releases **only** the oldest bond. Other bonds, sources and AC are untouched.
- **State:** `Character.exclusive_bonds = {bond_id: {serial, targets: [{target_id, serial}]}}`.
- **Ending:** `prune` ends a bond when its exact target is no longer owned: a copy given away, dropped or destroyed, or an actor whose source ended. The new holder of a copy may bond it.
- **Saves:** `BondRules.saved_error` is wired into both SaveManager validation paths. The bond must be declared by the DTO's class features at its level, within capacity, with ordered serials, naming a copy present in the DTO inventory of an eligible type, or a created actor in the DTO's created-actor records. Legacy saves without bonds load.

## S-164: equipment policy for `actor_projection`
- **Effect:** the S-163 effect gains an optional `equipment` list of legal policies from `merged`, `worn` and `dropped`.
  - The cast decision `_projection_equipment` selects one. A single policy is automatic.
  - With several policies and no choice, the cast is refused. Choosing a policy for a projection that declares none is refused.
- **merged:** equipped copies keep their slots. Only **those exact copies'** effects are suppressed:
  - `SourceBenefitRules.query` skips merged copies.
  - `Inventory.has_equipped_attuned_item` skips them, which covers the ring of protection bonus.
  - Other actors' copies are unaffected.
- **worn:** copies keep working. The projected AC adds the item bonuses.
- **dropped:** copies leave their slots and stay owned and unequipped. Cursed copies that cannot be removed stay.
- **Donning:** a merged or dropped form cannot equip another copy (`equip_instance`).
- **Reversion** (the exact source ending):
  - Merged suppression ends, so only copies still owned regain their effects. The receipt reports `merged_restored` and `merged_lost`.
  - Dropped copies are **not** re-equipped.
  - Projections without `equipment` keep 040 behavior.
- **Saves:** the projection record's `equipment = {policy, merged, dropped}` is validated as legal for the effect and consistent with its policy, with dropped copies no longer worn and present only when the effect declares equipment. Reload keeps the suppression.

## Neutral consumers changed
- `actor_projection_rules.gd`
- `shared_spell.gd`: allowed field, and the equipment decision passed through.
- `source_benefit_rules.gd`
- `inventory.gd`: `has_equipped_attuned_item`, `equip_instance`
- `character.gd`: bonds field, save, restore and prune.
- `save_manager.gd`: both validation paths.
- `data_loader.gd`: feature branch.

There are no ID branches.

## Fixtures, checks and scenario
- **Fixtures:**
  - `data/fixtures/batch_041/classes/bonded.json`: blade bond (item, capacity 1, release_oldest) and ward bond (construct actor, capacity 1, refuse).
  - `spells/guise.json`: a self projection with all three policies.
  - `items/charm.json`: a ring with AC +2 as a source benefit.
- **Checks:** `Batch041Checks` adds 33 assertions:
  - **S-161:** validation; class features; item bond; ineligible, unheld and repeat refusals; legal replacement; transfer ends the bond and the new holder may bond; no feature means no bond; actor bond; refusal at capacity preserving everything else; another owner's actor; the actor bond ending with its source; saves, reload, five tamper refusals, and legacy saves.
  - **S-164:** validation; refusal without a choice; worn; merged suppression; no donning; bystander unaffected; reversion with a lost copy; dropped; no re-equip; 040 compatibility; saves, reload, revert after reload, and four tamper refusals.
- **Scenario:** `batch_041_bond_equipment_flow` gives 9 ok, one of which is the shared cast helper's line:
  - An actual HUD cast with three policies and no choice changes nothing.
  - The production resolver with `merged` keeps the charm worn but suppressed, and an actual monster attack reads AC 12.
  - An actual equipped weapon copy bonds, a replacement releases only it, and an actual `drop_equipped_instance` ends the bond.
  - A real in-session `SaveManager` save and load (no cache clear) keeps the merged suppression. Concentration ending after the load restores the charm's effect.
  - The hit may break Concentration, in which case the scenario recasts before saving.

## Validation
- Import, then the translation revert.
- **Logic:** 5139 passed, 0 failed. A fresh run of 54968f1 in a temporary worktree gives a baseline of 5106, so the delta is **+33**, equal to the new checks.
- **Log grep:** clean.
- **Scenarios (all 0 FAIL, 0 errors):**

  | Scenario | ok |
  |---|---|
  | 031 | 25 |
  | 032 | 33 |
  | 033 | 70 |
  | 034 | 10 |
  | 035 | 9 |
  | 036 | 7 |
  | 037 | 11 |
  | 038 | 7 |
  | 039 | 10 |
  | 040 | 13 |
  | 041 | 9 |
  | shared_spell_flow | 67 |

- No code changed after the full run.

## Limits
- **Bond consumers:** bonds are exposed as queries and receipts only. No benefit, summon or recall consumer exists yet; those are for S-162, S-165 and S-202.
- **Bond sources:** declared only by class features. Item-, cast- and progression-granted bond rules are not wired.
- **Uniqueness:** checked against the `others` passed in, not a global registry.
- **Scenario bond:** it uses an in-session appended feature and is cleared before the save, because party classes do not declare bonds. Bond persistence is covered in logic with the fixture class.
- **Equipment:**
  - There is no HUD equipment-policy chooser, so a HUD cast with several policies refuses.
  - `dropped` means unequipped and carried. Copies are not placed on the ground.
  - Donning is refused through `equip_instance` only; the legacy `equip(slot, id)` is not hooked.
  - Merged suppression covers source benefits and attuned-item queries, not every bespoke magic-item code path.
- **Stack dependency:** S-164 depends on S-163 (040, PR #8), which is not yet Verified.
