# Batch 051 build: feat acquisition through the normal player path

Card Q-20261021-004820-aaf1. Stacked on harness-fail-unparseable-checks (70ba454).

## What changed
- `FeatRules` (src/characters/feat_rules.gd): category (origin/general/fighting_style/epic_boon), `repeatable`, `prerequisite {level, abilities_any}` validated at load; eligibility, options, `choose_origin`, `choose_level_feat`, `saved_error`.
  - SRD 5.2.1 p.83: a background grants an Origin feat. Class "Ability Score Improvement" features let you take a feat you qualify for instead. p.87 "Parts of a Feat" says a feat has a category and may have a prerequisite, and you can't take a feat more than once unless it says it's repeatable.
- The chosen feats join `OwnedFeatureSources` as owners: `declared(..., chosen_feats)`. A feat's rules, uses, modes and upgrades go through the existing 049/050 pipeline and the copy gate.
- Creation: the OriginFeatPicker sits on the equipment step and is applied at Confirm; a refusal stops before the character joins the party.
- Level-up: the sheet's LevelFeatRow / "Take feat instead" answers the pending ASI entitlement with `["feat:<id>"]`.
- Saves: `origin_feat` is persisted. `ClassProgression.saved_choices_error` refuses a feat that is unknown, unearned, under-level, duplicate or not an origin feat.

## Checklist
- (a) Refusals for wrong category, unmet ability or level, duplicate, unknown, or no pending ASI spend nothing (choices, asi_spent and pending are unchanged).
- (b) Loaded state goes through `record_state_error` / `saved_error` paths. Tampered saves are refused.
- (c) Production callers: creation Confirm, class_training, DataLoader, OwnedFeatureSources.sync, Character.from_dict.
- (d) Real save/load in scenario 051. A legacy save without `origin_feat` loads.
- Merged/suppressed gate: feat features are owned once per feat. The reload checks confirm there are no duplicates.

## Counts
- Base 70ba454: 5440/0 (measured on the harness PR). Branch: 5455/0, gate 46 scripts, 0 failed.
- Scenarios 031-051 all pass. 051: 6 ok.

## Limits
- Fixture feats only. No SRD feat content is added.
- Fighting Style and Epic Boon categories are validated but have no special grant path beyond the ASI entitlement and level prerequisites.
- The ASI-or-feat choice is fixed once taken (no respec).
- Prerequisites support only level and "any of these abilities".
