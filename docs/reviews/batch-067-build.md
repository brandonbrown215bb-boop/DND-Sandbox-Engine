# Batch 067 build: S-127 authored weapon damage-type choice

Card Q-20261025-090845-b620. Based on `batch-066-travel-placement` 8313a0b, because PR #38 is still open.

## Finish line (verbatim)
"Add authored weapon damage-type choices (S-127). Offer eligible types at the declared activation or hit window. Change only that attack's profile; cancellation must spend nothing."

## Design
- **Data (ADR-0018):** a weapon-scoped `attack_profile` rule declares `replace.damage_type_choices` and a required `choice_window` (`activation` | `hit`). There's no engine default and no per-ID branch. `AttackProfileRules.validate_rule` refuses:
  - choices without a window
  - an unknown window
  - a window without choices
  - a fixed `damage_type` alongside choices

  The loader keeps only valid rules. The existing fixture `fixture:b035_channel` now declares `choice_window: activation`.
- **Eligibility:** `damage_type_choice(actor, weapon)` returns the first qualifying source's options. If a fixed-type source wins first, nothing is offered.
- **Activation window** (`CombatState._on_hex_clicked`, Attack):
  - The menu opens after the target click and before the action or swing is committed, so dismissing it spends nothing.
  - After the answer, `activation_choice_error` rechecks the source and the option. The host also rechecks the target (alive, same hex, still listed) and that an action remains. A stale answer is refused and nothing is spent.
  - The chosen type goes in as `attack_profile_damage_type` for that attack only.
- **Hit window:**
  - `_settle_weapon_attack_context` is split into the roll stage and `_settle_weapon_attack_hit`, the unchanged damage tail.
  - When the caller sets `allow_attack_profile_choice`, a hit that qualifies returns `attack_profile_choice_request`. This happens after the final hit and every pre-damage payment, and before damage.
  - `resume_hit_choice` settles the request once; a replay is refused. A dismissed or stale choice keeps the weapon's own type, and the choice costs nothing.
  - Hosts: the main player Attack, the Stroke of Luck re-resolve, and Extra Attack swings (all through `_settle_attack_profile_hit_choice`).
- **Durability:** there is no new saved record or field. The pending request is in memory only and the chosen type is per attack. Class-owned rules are rebuilt from data on load, so `InventoryCopies.record_state_error` has nothing new to save. Legacy saves are unchanged. No item grants were added, because items can't grant `attack_profile`, so the MagicPropertyRules copy gate isn't involved.

## PARTIAL
- An activation-window choice is asked only for the first swing of a click. Extra Attack swings inherit the weapon type, although they do host hit-window choices.
- Opportunity, Light off-hand, Cleave and created-creature attacks don't host the choice. They settle with the inherited type.
- Item-granted attack profiles aren't supported (`OwnedFeatureSources.TYPES`).
- Reach and mastery choices (the rest of S-127) aren't built.
- The save check covers the current slot format plus a fresh-process reload. No legacy-directory save was written, because there is no new field to migrate.

## Checklist
- Real controls: the Attack HUD action, a hex click and the real `request_damage_type_choice` PopupMenu, with `test_mode` off.
- Cancellation: dismissing the activation menu spends no action and deals no damage. Dismissing the hit-window menu keeps the inherited type.
- Stale choices:
  - Activation: the source is removed while the menu is open, and nothing is spent (scenario).
  - Hit window: the source is removed before settlement, and the inherited type is used (logic).
- Once-only: a replay of a hit request deals nothing (logic). The action is spent once per attack (scenario).
- Refusal before paying: the scenario asserts the action is still available after a cancel or a stale answer.
- Only that attack changes: the next attack inherits slashing, and the catalog longsword is unchanged (logic).
- Every new function has a production caller:
  - `damage_type_choice` and `activation_choice_error` are called by CombatState.
  - `hit_window_request` and `_settle_weapon_attack_hit` are called by CombatAction.
  - `resume_hit_choice` is called by `CombatState._settle_attack_profile_hit_choice`.
- Docs: `docs/mechanics/attack-profiles.md` (new, linked from the README) and the `docs/planning/vocabulary-slices.md` boundary text. The S-127 status is unchanged.

## Validation (Godot 4.7.2, imported twice)
- Logic: 5980 passed, 0 failed. Batch 066's documented count was 5958; this batch adds 18 checks in `Batch067Checks`. No SCRIPT/Parse/Compile errors.
- New scenarios, all passing:
  - `batch_067_weapon_damage_choice_flow`: 10 ok, 0 FAIL. It does a real `SaveManager` save/load.
  - `batch_067_weapon_damage_choice_reload`: 1 ok, 0 FAIL. It runs in a fresh process, reloads that slot, then deletes it.
- Attack regressions, branch vs base 8313a0b (ok/FAIL):

  | Scenario | Branch | Base |
  |---|---|---|
  | weapon_attack_numeric_bonus_flow | 41/0 | not run on base; passes on the branch |
  | monk_action_flow | 61/0 | not run on base; passes on the branch |
  | barbarian_action_flow | 18/0 | not run on base; passes on the branch |
  | rogue_devious_strikes | 8/0 | not run on base; passes on the branch |
  | shared_spell_attack_bonus_flow | 14/40 | 14/40 |
  | attack_result_adjustment_flow | 31/28 | 31/29 |
  | barbarian_choice_flow | 0/1 | 0/1 |
  | cleric_strike_flow | 0/1 | 0/1 |
  | magic_weapon_spell_flow | 1/2 | 1/2 |
  | true_strike_spell_flow | 0/4 | 0/4 |

  No new failures.

## Open questions
- Should an activation-window choice be asked again for each Extra Attack swing, or once per Attack action? The SRD wording depends on the feature. Right now it's first swing only.
