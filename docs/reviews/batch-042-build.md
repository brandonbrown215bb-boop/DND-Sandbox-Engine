# Batch 042 build: S-162 / S-165

Stacks on Batch 041 (PR #9, `batch-041-s161-s164` @ 780c538, after the reviewer's R1-R4 fixes).

## Selection
- **S-162 linked-copy / group replacement.** Deps S-161 (041) and S-119 (034) are built in the open stack. It extends the S-161 bond rules directly.
- **S-165 exact item copy projects into an actor.** Deps S-163 (040) and S-161 (041) are built. It unblocks S-166.
- Rejected: S-210 needs S-196, which isn't built. Deferred: S-202 touches existing cursed-attunement code and only unblocks S-203.
- None of the excluded areas were touched: S-120 successor code, tools/content_editor/, the wand charge path, non-class mode_choice/rule_alternatives, DruidRules and Wild Shape.

## Design
- `BondRules` gains `on_replace` (`release`/`destroy`) and `on_loss` (`keep_survivors`/`dispose_group`), both validated. Actor targets can't dispose, and `destroy` requires `release_oldest`.
  - `held()` counts inventory copies plus projected copies.
  - When one copy in a `dispose_group` bond is lost, the remaining linked copies are destroyed once, and the result is recorded in `last_disposal`.
  - Inventory destroy, drop and take now call `BondRules.on_copy_removed`.
- New `ItemProjectionRules`. An item declares `actor_projection {template}`, which must be an S-154 template with count 1.
  - The exact carried, unequipped, uncursed copy moves into `character.item_projections` and becomes a cached actor (`<id>:projected`). That actor can be attached to combat.
  - At 0 HP, or on `revert`, the same copy returns to the inventory.
  - Saves keep the copy record and the actor's HP. `saved_error` rejects duplicates, foreign ids, missing policies and bad HP. DataLoader validates the policy.

## Rebase onto 780c538 (041 review R1-R4)
- There was one conflict, in `BondRules.prune`. The resolution keeps R3: if the rule is missing because the source feature is suppressed, the bond stays live. Otherwise item targets use the 042 `held()` check, which also counts projected copies. A suppressed rule also never triggers `dispose_group`.
- R1/R4 interplay: `ItemProjectionRules.project` now refuses while the owner is in a form that blocks equipment (`ActorProjectionRules.equip_error`). It refuses before any copy moves. Item projection itself has no cost, and every refusal happens before anything changes.
- R2: only carried, unequipped copies can be projected, so merged copies can't be projected.
- New checks: refusal from a `dropped` form leaves the copy and `item_projections` unchanged (R1/R4); a projected bonded copy keeps its bond while a projection suppresses the feature and after reversion (R3).

## Validation
- Logic: **5174 passed / 0 failed**, against a fresh baseline at 780c538 of 5147/0. That is +27, equal to the 27 checks in `batch_042_checks.gd`.
- Scenarios: 031 25, 032 33, 033 70, 034 10, 035 9, 036 7, 037 11, 038 7, 039 10, 040 13, 041 11, **042 6**, shared_spell_flow 67. All with 0 FAIL.
- No SCRIPT ERROR or Parse Error in any log.
- `batch_042_linked_projection_flow` covers:
  - projecting the figurine in combat
  - a real monster attack on the hound (AC 14, HP 22→19)
  - a real drop of one linked weapon, which disposes exactly its mate
  - a real SaveManager save/load with the projection live and no cache or state clearing; the damaged hound is rebuilt
  - revert after the load returns the copy exactly once

## Limits
- Group disposal applies to items only. Projected survivors aren't disposed.
- Item projection has no timed expiry, no HUD command and no HUD display.
- The scenario's S-162 bond uses a feature appended for the session, so it isn't part of the real save. Bond persistence is covered by the logic checks.
- S-166 overflow is out of scope.
- The fixture items use type `tool`, because DataLoader has no wondrous type.
