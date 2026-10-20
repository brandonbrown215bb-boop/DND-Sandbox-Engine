# Batch 037 build: S-103 then S-084

Branch `batch-037-s103-s084`, stacked on `batch-036-s086-s060` (651e032, PR #3).
Quest card Q-20261020-152049-95b2. This is build evidence and has not been reviewed yet.
Slice counts and the checkpoint are unchanged.

## Selection
The Runtime Builder chose the batch under delegation, after checking the registry at 651e032:
- S-103 (Rest/per-activation mode choices, V-037/V-025) and S-084 (Rule parameter
  upgrades, V-055) are both **Planned**.
- Their dependencies S-045 (VS-57), S-049 (VS-59) and S-036 (VS-43) are **Verified**.
- No quest card claims either slice.
- Neither slice touches `tools/content_editor/` or the native wand charge path.
- Together they unblock S-085 (needs both), S-104, S-127 (needs S-103) and S-163 (needs S-084).

## S-103: `FeatureModeRules` (src/characters/feature_mode_rules.gd)
A class feature with `type: "mode_choice"` declares between two and six `modes`. Each mode has an `id` and
`benefits`, using the same bounded AC/speed payload as S-049's `SourceBenefitRules`.

- **`boundary: "rest"` + `rest`**
  - The choice is open until the first selection.
  - It reopens only when the declared rest completes (`Character.short_rest/long_rest`, which is also reached through `RestRules`).
  - Choosing again replaces the prior mode. Until then the prior mode keeps its grants.
  - A different rest kind does not reopen it.
- **`boundary: "activation"`**
  - Declares `uses`, `uses_per`, `duration_seconds` and an optional `die`, `targets`, `end_on` and `allow_reselect`.
  - `activate()` spends exactly one parent use through `use_feature`.
  - It starts a new exact activation serial and rolls the die once, as Temporary HP for up to `targets` recipients. Temporary HP takes the higher value, per SRD 5.2.1.
  - Reselecting during the activation (if declared) replaces only the mode's grants. Uses, remaining time and the roll stay unchanged.
  - The parent ends on duration (via `SpellEffects.advance_time`) and on the declared `end_on` reasons: long/short rest, `zero_hp` and `incapacitated`.
- **Grant projection:** the selected mode's grants project as a `kind: "mode"` carrier in `SourceBenefitRules.query`. The identity is `mode:[actor, feature, mode, serial]`. Nothing is written into base stats.
- **Separate state:** state lives in `Character.feature_modes`, never in `feature_choices`. Permanent progression choices remain distinct.
- **Saves:**
  - `FeatureModeRules.saved_error` runs in both SaveManager character validators. It refuses unknown or unowned rules, undeclared modes, unknown fields, overlong lifetimes, invalid rolls, and active state without a mode.
  - Legacy saves without `feature_modes` load as empty.

## S-084: `RuleUpgradeRules` (src/characters/rule_upgrade_rules.gd)
A feature with `type: "rule_upgrade"` names another `rule` declared in the same class data and gives `changes`:
- `uses.add` (count)
- `targets.add`
- `die.set`
- `end_on.add/remove` (end predicates)

The loader refuses undeclared targets, self-targets, unknown parameters, out-of-range amounts and illegal dice.

`effective(actor, feature)` returns an upgraded **copy** derived from the actor's owned upgrade features:
- Each upgrade id is deduplicated and applied once, in sorted order.
- The catalog record and the owned base record are never mutated.
- Reloads rebuild features from class data, so a change cannot stack.

`Character.get_feature_max_uses` and `FeatureModeRules.rule` consume the effective rule. Raising the use count does not refill uses; they recover at the declared rest.

## Neutral consumers changed
- `character.gd`:
  - adds the `feature_modes` field, to_dict and restore
  - adds rest hooks
  - treats `mode_choice` as a use-pool type
  - applies upgrades in `get_feature_max_uses`
- `source_benefit_rules.gd`: one carrier loop.
- `spell_effects.gd`: advance_time ages mode activations.
- `save_manager.gd`: two validator calls.
- `data_loader.gd`: one validation branch for the two feature types.

There are no ID branches.

## Fixtures, checks and scenario
- **Fixture:** `data/fixtures/batch_037/classes/modes.json`, a neutral class:
  - level 1: activation stance and rest attunement
  - level 2: an upgrade gained through `level_up()`
- **Checks:** `Batch037Checks` adds 39 assertions in the combat group:
  - validation refusals
  - rest boundary, replacement and permanent-choice separation
  - activation spend, reselect without restart, lifetime and end predicates, use bounds and target limits
  - upgrades of count/die/targets/end predicates, no catalog mutation, applied once, two reloads
  - save refusals and the legacy save
- **Scenario:** `batch_037_mode_upgrade_flow` (6 ok):
  - A real party member in a real combat activates a mode, and an actual monster attack reads AC +2.
  - Reselect swaps the grant, and the next attack sees the new AC.
  - An actual `RestRules.complete_long_rest` ends the activation, restores uses and keeps the rest mode until it is replaced.

## Validation
- Import, then `git checkout -- docs/reviews/*.translation`.
- **Logic:** 4937 passed, 0 failed. The 036 baseline is 4898, so the delta is **+39**, equal to the new checks. No group was dropped.
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
  | 037 | 6 |
  | shared_spell_flow | 67 |

## Limits
- Mode payloads are limited to S-049's AC/speed additions.
- Mode grants are self-only; `targets` scopes only the activation die's Temporary HP.
- Activation and reselection are rule-level calls; there are no HUD buttons yet.
- The scenario's party member is a fighter carrying appended fixture features, so it does not cover reload. Reload is covered in logic with a fixture-class actor.
- Per-hit/turn-start switches (S-104) and option/exclusive upgrades (S-085) remain open.
- No catalog content was converted.
