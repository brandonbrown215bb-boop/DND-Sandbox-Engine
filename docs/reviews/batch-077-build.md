# Batch 077 build: S-127 per-swing damage-type choice (#39 follow-up)

Card Q-20261025-213314-2114. Stacked on `batch-076-footprint-terrain` d9a27f4 (PR #49, which includes reviewer commit d9a27f4).

## Done means (Brandon's ruling, verbatim)
"ask on every swing for a choice that applies to one attack. Carry it across the Attack action only when the feature says it lasts that long. Fix the bug where the choice is made on the first swing and later swings silently fall back to normal damage."

## Design
- **Data (ADR-0018):** `attack_profile` rules with `damage_type_choices` may declare `choice_duration`: `attack` | `attack_action`. `validate_rule` refuses any other value and a duration without choices. No per-ID branch.
- **Existing data:** a rule that omits the key is read as `attack`: it lasts one attack and never carries. That is the ruling's base case, so nothing is carried unless a feature says so. The existing fixtures (`fixture:b035_channel`, `fixture:b067_*`) are unchanged and still validate.
- **`AttackProfileRules`:**
  - `damage_type_choice` now reports `duration`.
  - New `carry_record(actor, weapon, chosen)` returns the record to keep, or `{}` for `attack` rules.
  - New `carried_choice(actor, weapon, record)` returns a carried pick only when the record has the same source, the rule is still `attack_action`, and the pick is still an option.
- **`CombatState` (production caller):**
  - `attack_action_damage_choice` is held in memory only. It is cleared when a new Attack action is spent and at turn start.
  - `_remember_attack_action_choice` runs after the first swing and after each Extra Attack swing, for both the activation and hit windows.
  - New `_extra_swing_damage_choice` runs before every Extra Attack swing. It reuses a carried pick when one applies, rechecking it. Otherwise it asks the real `request_damage_type_choice` menu for activation rules.
  - Hit-window rules already ask per swing. A carried `attack_action` pick is injected as `attack_profile_damage_type`, so no new request opens.
  - A later click in the same Attack action also reuses an `attack_action` pick instead of asking again.
- **No silent fallback:**
  - Dismissing a later swing's activation menu, or giving a stale answer (source left, option gone, target gone), **holds** that swing. The swing is not spent, `remaining_attack_swings` keeps it, and the log says so. The next click asks again.
  - A dismissed hit-window menu now logs that the weapon's own type is used. Before this, that only happened silently.
- **Saves:** there is no new saved field. The carry is in memory only and class rules rebuild from data, so legacy saves load unchanged; `batch_067_weapon_damage_choice_reload` still passes.
- **Review 076 nit (`ignore_occupants`):** I added a doc note instead of renaming. The flag only skips the `grid.entities` scan, and explicit `players`/`monsters` lists are still honoured. The comments are in `physical_facts_rules.gd` and `placement_rules.gd`. The name is kept so the reviewer's 076 stress check and its callers stay unchanged.

## Validation (Godot 4.7.2, imported twice, sequential, no concurrent Godot)
- Logic: **6236 passed, 0 failed**. That is +11 from `Batch077Checks` over 076's 6225. There were no SCRIPT/Parse/Compile errors in the import or logic logs.
- Scenarios:

  | Scenario | Result |
  |---|---|
  | `batch_077_per_swing_choice_flow` (new) | 9 ok / 0 FAIL, PASSED |
  | `batch_067_weapon_damage_choice_flow` | PASSED, 0 FAIL |
  | `batch_067_weapon_damage_choice_reload` | PASSED, 0 FAIL |
  | `barbarian_action_flow` | PASSED, 0 FAIL |
  | `monk_action_flow` | PASSED, 0 FAIL |

- The new scenario uses the real Attack click with `test_mode` off and the fighter's Extra Attack. It checks:
  - **Per attack:** the menu is asked on swing 1 and on swing 2. Swing 1 picks Radiant, and the radiant-immune target takes 0 at the second menu. Swing 2 picks Force and deals damage (300 -> 289).
  - **Per Attack action:** the activation menu is asked once and the pick carries. The log shows "Force carries to this swing".
  - **Per Attack action, hit window:** the menu is asked once and the pick carries.
  - **Refusal:** dismissing swing 2 holds it. The swing stays at 1, the hold is logged, and there is no slashing fallback. The next click asks again and lands.

## PARTIAL (still open)
- Opportunity, Light off-hand, Cleave and created-creature attacks still don't host the choice.
- Item-granted attack profiles are unsupported.
- Reach and mastery choices aren't built.
- No production content declares `choice_duration: attack_action` yet. Only fixtures do.
- The S-127 status is unchanged (Planned).
