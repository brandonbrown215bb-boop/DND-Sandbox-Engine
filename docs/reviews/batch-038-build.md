# Batch 038 build: S-104 then S-085

Branch `batch-038-s104-s085`, stacked on `batch-037-s103-s084` (26c2ad6, PR #4, accepted by Runtime Reviewer). It was originally built on e22215d and rebased cleanly onto the reviewer's test-only commits and acceptance doc.
Quest card Q-20261020-153201-fc66. This is build evidence and has not been reviewed yet.
Slice counts and the checkpoint are unchanged.

## Selection
Registry checked at e22215d (before the rebase). No quest card claims any candidate.

| Candidate | Status | Dependencies | Decision |
|---|---|---|---|
| **S-104** Per-hit/turn-start mode switches | Planned | S-103 (037, PR #4 accepted, not yet merged or registry-Verified), S-056 (Verified, VS-54) | **Chosen** |
| **S-085** Rule options and exclusive replacements | Planned | S-084 and S-103 (037, PR #4 accepted, not yet merged or registry-Verified) | **Chosen** |
| S-127 Reach/mastery and damage-type choice | Planned | S-126 (open 035), S-103 (open 037) | Ready, deferred |
| S-163 Reversible retained-stat actor projection | Planned | S-154 (still Planned, unbuilt) | **Not ready** |

S-104 and S-085 are the direct follow-on to 037's mode and upgrade runtime. Building them now proves that runtime before any converted content relies on it. S-127 is ready too but needs a weapon reach/mastery host, so it is left for later.
None of these touch `tools/content_editor/` or the wand charge path.

## S-104: switch windows (`FeatureModeRules.on_event/switch`)
An activation `mode_choice` may declare `switch_events` from `["hit", "turn_start"]`. Rest-boundary rules cannot declare them.

**How a window opens and closes**
- **Opening events** come from two one-line hooks:
  - `CombatAction.advance_combat_turn(actor)` is the actor's own turn start.
  - `_settle_weapon_attack_context` fires after a weapon hit by that actor is fully settled and published.
- **The window:** each opening event gives the actor's matching active activations one window: `{event, serial}`.
- **Closing:** any later own event closes older windows. A window also closes after one switch and when the activation ends.
- **Other creatures:** another creature's turn start opens nothing for this actor.

**What a switch changes**
- `switch(actor, rule, mode, event)` changes only the active mode, which means only its grants.
- Uses, the remaining deadline, the activation serial and the roll stay fixed.
- The hit that opened the window has already settled, so its damage is never recomputed.
- Free reselection still needs 037's `allow_reselect`.

## S-085: options and exclusive alternatives (`RuleUpgradeRules`)
**New upgrade parameters**
- `modes.add` takes one to four valid modes. `modes.remove` takes mode ids, and removals run after every addition, so upgrade order cannot change the result. A rule never drops below two legal modes.
- `switch_events.add/remove` acts as a permission.
- The catalog is still never mutated.

**Exclusive alternatives**
- **Grouping:** upgrades with the same `exclusive_group` on the same rule are alternatives. Exactly one applies: the chosen one, or by default the first by id. They never stack, the way two Extra Attack or base-AC policies don't.
- **Choosing:** `choose_alternative` accepts only owned members of the group. It is refused while the upgraded activation is active.
- **Storage:** the choice is stored in `Character.rule_alternatives` and validated by `RuleUpgradeRules.saved_error` in both SaveManager validators.

**Saves**
- Saved modes are validated against the catalog modes plus any modes added by upgrades at or below the saved level.
- Legacy saves without `rule_alternatives`, `window` or `event_serial` load.

## Neutral consumers changed
- `combat_action.gd`: the two event hooks.
- `character.gd`: the field, to_dict and restore.
- `save_manager.gd`: two validator calls.

There are no ID branches.

## Fixtures, checks and scenario
- **Fixture:** `data/fixtures/batch_038/classes/switches.json`. All upgrades are reached through `level_up()`.
  - level 1: a turn-start-switch stance
  - level 2: add-mode and remove-mode/add-hit-permission upgrades
  - level 3: two exclusive `focus` alternatives
- **Checks:** `Batch038Checks` adds 29 assertions:
  - validation refusals
  - windows: own turn only, one switch per window, undeclared events refused, ended activation, parent cost/deadline/serial fixed
  - options: added and removed modes, added hit permission, the two-mode floor, reload
  - exclusive alternatives: one applies, a choice replaces rather than adds, non-members refused, refused while active, two reloads
  - five saved-state refusals and the legacy load
- **Scenario:** `batch_038_switch_option_flow` (7 ok):
  - An actual player longsword hit opens the upgraded hit window, and switching leaves the settled damage, uses and deadline unchanged.
  - An actual monster attack reads the switched AC.
  - The window is spent after one switch.
  - The own turn start switches back, and the next monster attack reads guard AC.

## Validation
- Import, then the translation revert.
- **Logic, after the rebase onto 26c2ad6:** 4987 passed, 0 failed. A fresh run of 26c2ad6 in a temporary worktree gives a baseline of 4958, so the delta is **+29**, equal to the new checks. Before the rebase it was 4966 against 4937.
- **Log grep:** no SCRIPT ERROR, Parse Error or Compile Error in the logic or scenario logs.
- **Scenarios (all 0 FAIL):**

  | Scenario | ok |
  |---|---|
  | 031 | 25 |
  | 032 | 33 |
  | 033 | 70 |
  | 034 | 10 |
  | 035 | 9 |
  | 036 | 7 |
  | 037 | 11 (reviewer added the SaveManager mid-activation case) |
  | 038 | 7 |
  | shared_spell_flow | 67 |

## Limits
- **Events:** only `hit` (own settled weapon hits) and `turn_start` (own turn) exist.
- **Monster actors:** they don't carry mode rules.
- **Hit window lifetime:** a hit window stays open until the actor's next own event or the end of the activation, not just for the rest of the attack.
- **Exclusive alternatives:** demonstrated on the mode rule's parameters (targets vs. uses). Native Extra Attack and base-AC formulas are not converted to this path.
- **UI:** there are no HUD controls for switching or choosing alternatives.
- **Scenario coverage:** the scenario's fighter carries fixture features as add-ons, so reload is covered in logic only.
- **Dependencies:** PR #4 is accepted but not merged.
- **Reviewer F1 (class-only saved lookup):** inherited, not fixed. The 037 saved-state validator accepts mode state only for rules in the character's own class list. 038's added-mode lookup (`_declared_modes`) and `RuleUpgradeRules.saved_error` use the same class-only lookup. The fix belongs in a shared owned-feature resolver, not here.

## Manifest (diff against 26c2ad6)
- A	.questboard/quests/Q-20261020-153201-fc66.md
- A	data/fixtures/batch_038/classes/switches.json
- M	run_tests.ps1
- M	src/autoload/save_manager.gd
- A	src/batch_038_checks.gd
- A	src/batch_038_checks.gd.uid
- A	src/batch_038_controls.gd
- A	src/batch_038_controls.gd.uid
- M	src/characters/character.gd
- M	src/characters/feature_mode_rules.gd
- M	src/characters/rule_upgrade_rules.gd
- M	src/combat/combat_action.gd
- M	src/test_runner.gd
- M	src/viewport_harness.gd
- A	docs/reviews/batch-038-build.md
