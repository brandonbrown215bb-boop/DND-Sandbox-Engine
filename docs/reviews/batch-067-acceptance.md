# Batch 067 acceptance: S-127 weapon damage-type choice (PR #39)

Reviewer: Runtime Reviewer. Card Q-20261025-090845-b620 (claimed until 2026-10-26 04:10 CDT). Reviewed head e55fd81 (build a087bcb), stacked on batch-066-travel-placement 8313a0b.

Finish line (verbatim): "Add authored weapon damage-type choices (S-127). Offer eligible types at the declared activation or hit window. Change only that attack's profile; cancellation must spend nothing."

## Verdict: ACCEPT, no defects. S-127 PARTIAL as the builder declared.

S-127 is a damage-type choice, not versatile one- vs two-handed grips; versatile was not in scope and was not reviewed.

## Verified
- Loader: no window, unknown window, window without choices, and fixed type alongside choices are all refused in validate_rule; bad_window.json is refused at load. No engine default.
- Activation: asked before resolving_player_action/budget spend. Cancel returns before any spend. After the popup it rechecks the source, the option, the target (alive, same hex, still present) and the action budget.
- Hit window: the pause comes after the final hit and every pre-damage payment, and before damage. resume_hit_choice erases the request, so a second answer is refused and deals nothing (review test). A miss never asks (60-attack review test). weapon_data is duplicated per attack (combat_action.gd:1135), so the choice changes only that attack.
- Crit: doubling comes from the damage formula and doesn't depend on the type. Review test: a forced crit plus cold deals 2d6+mod as cold.
- Extra Attack: each swing builds fresh extra_decisions, so a hit-window choice is asked again each swing with a new request id (review test), and no stale reuse is possible. An activation-window choice is NOT carried to later swings: they silently use the weapon's own type (the declared PARTIAL).
- Save/load: no new saved fields. Pending requests live only inside one await. The _reload scenario passes in a fresh process.
- ADR-0018: no per-ID branches in src/combat.

## Weak spots (not defects)
- Dismissing the hit-window menu keeps the weapon's own type even when that type isn't in the authored list. This fits SRD "you can choose" wording, but data can't make the choice mandatory.
- The builder's "a miss offers no hit-window choice" check uses AC 1000, and a natural 20 still hits, so it flakes about 5% of the time. The review test uses crit_range 21 to avoid that.
- Callers that don't host the choice (OA, off-hand/Light, Cleave, monsters, summons) settle with the inherited type without saying so.

## Counts
- Logic: 5984 passed, 0 failed (5980 builder + 4 review), 0 SCRIPT ERROR. Imported twice after clearing .godot.
- Scenarios, one at a time: batch_067_weapon_damage_choice_flow, batch_067_weapon_damage_choice_reload, batch_066_travel_placement_flow, barbarian_action_flow, combat and combat_resolution pass. attack_result_adjustment_flow, fighter_progression, cleric_strike_flow, ranger_action_flow and post_roll_die_bonus_flow fail, and all five are on the 066 main-failure list. **No regressions.**

## Open decisions (Brandon)
- Should an activation-window choice carry across all Extra Attack swings of the same Attack action, or be asked on every swing? Today later swings fall back to the weapon's type.
- Should data be able to mark a hit-window choice as mandatory, with no "keep the weapon's type" option?
- OA, off-hand, Cleave and summon hosts, plus item-granted profiles: should each get a card?
- Main is still red (70/229), as in 066.
