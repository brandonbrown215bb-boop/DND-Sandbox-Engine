# Batch 084 acceptance review (PR #57)

**Verdict: ACCEPT (partial, as declared)** with one bounded reviewer fix. Reviewer: Runtime Reviewer. Base `b27e2a0` (main), builder head `1ed5712`.

Finish line (builder-quoted, not seen first-hand by the reviewer): "Fix the remaining two-monster assumptions; prove the component/focus and casting-permission diagnoses using representative failures, then repair affected fixtures. Run the supported Windows checks. Don't weaken game rules to make tests green." The **Windows checks were not run**, so that part of the finish line is still open.

## Findings
1. **Scope:** `git diff b27e2a0..1ed5712 --stat` touches only `src/viewport_harness.gd`, `docs/reviews/batch-084-build.md` and the card. No rule, data or engine change. No assertion removed or loosened. The only removed lines are raw `DataLoader.get_spell(...)` cast payloads and the relabelled-Fighter `alice`.
2. **`_menu_spell` fallback:** this is not a bypass. `CombatCommand.from_hud_for_character` (combat_command.gd:53-82) rebuilds the spell from data and returns null unless `_source_permission_id` matches a live `SpellPermissionRules.for_spell` permission and `selection_valid` holds. `_on_hud_action` then returns without casting, and slot, component and action gates still run downstream. The fallback could still make a scenario fail only indirectly, through a print. **Fixed** (see below): a miss now fails the scenario with an explicit assertion and returns `{}`, so no cast happens.
3. **`_ready_spell_components`:** it is called in 17 scenarios. All of them intend a successful cast, and none tests a hands-full or no-component refusal. Unequipping goes through `Inventory.unequip`, which moves the item to the backpack, refuses cursed attuned items and refuses when the backpack is full. Nothing is dropped or destroyed. It stops once one hand is free (off-hand, then shield, then weapon). Barkskin and Mage Armor read their baseline AC after the call, so the AC assertions are honest.
4. **Class spell choices:** `_own_class_spells` records every `known_spells` id as the class feature choice. The engine still requires the spell to be on the class list, within the class maximum level and slot level, and allowed by components, and wizards also need it in the spellbook (spell_permission_rules.gd:39-48). An illegal fixture spell still refuses. Example: the Ranger `charm_person` in `ranger_natures_veil_blindsight` now fails loudly. Choice-count limits are not enforced at cast time, which is fixture-only and accepted.
5. **Two goblins:** added to 7 scenarios. Each indexes the second monster (`[1]`). No asserted outcome depends on the number of monsters beyond that indexing.
6. **28 flips:** each was rerun alone at the builder head, and all 28 PASS with 0 SCRIPT ERROR and 0 MENU_SPELL_MISS. Every flip comes from setup (index 1, permission row, pouch or free hand, real Wizard owner). **No flip was judged weakened.** `barbarian_choice_flow` and `fighter_progression` have no edits in this PR, so they flip from the base, not from this batch.

Sweep-only regressions, each rerun alone twice: `shared_spell_normal_controls_flow`, `wave_three_foundations_flow` and `final_encounter_round_trip` passed 2/2 each, so they are treated as flaky under the sweep.

## Reviewer fix
- `_menu_spell` no longer falls back to the raw catalog record. A miss fails the scenario and returns `{}`. Rerun: `true_strike_spell_flow` and `mass_cure_wounds_flow` PASS. `fire_area_object_ignition_flow` (fireball), `ranger_natures_veil_blindsight` (charm_person) and `sorcerer_twinned_spell` were already failing and now fail at the menu miss or at their own assertions.

## Evidence
Two headless imports, rc 0, with 0 SCRIPT/Parse/Compile lines. Logic suite: 6355 passed, 0 failed. The full sweep was not rerun. The builder reported 197/47/3 of 247.

## Proposed count update
Known #47-stack failures: from 74 FAIL / 6 TIMEOUT to 47 FAIL / 3 TIMEOUT (builder sweep), with the 28 flips verified individually.

## Open for Brandon
- Windows `run_tests.ps1` still needs to be run on a Windows host.
- Fixture content issues are now visible: `fireball` has no menu row in `fire_area_object_ignition_flow`, and the Ranger `charm_person` is not on the Ranger list. Should these get cards?
