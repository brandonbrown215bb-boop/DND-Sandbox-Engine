# Batch 070 acceptance: S-084/S-085 Extra Attack count and base-AC upgrades (PR #42)

Reviewer: Runtime Reviewer. Card Q-20261025-102842-b171: claim failed ("Quest not found"; the card file is untracked in the builder checkout and absent from this branch). Reviewed head a12d5b3, stacked on #41 (075abfd).

Finish line (verbatim): "Extra Attack and base AC upgrades (S-084/S-085): switching preserves spent attacks; removal and reload restore values."

## Verdict: ACCEPT after one fix (R1, 4791916). S-084/S-085 PARTIAL as declared.

## Defect
- **R1 Extra Attack stacked across rules.** `RuleUpgradeRules.extra_attacks` returned `actor.extra_attacks + sum(set - count)` over every upgraded extra_attack rule. With a second Extra Attack source (e.g. Fighter 11 count 2) and an item upgrade set 2 on another class's Extra Attack, the actor got 3 extra attacks; two upgraded rules could reach 5. SRD 5.2.1: Extra Attack from several features doesn't stack. Fixed: the result is the highest single source (each rule's count, or its chosen upgrade's set); a non-feature count folded into the stat still competes; with no upgrade the stat is returned unchanged. Review test `_review_stacking` (3 checks) fails before the fix (got 3), passes after.

## Verified
- Mid-action switching: `reclamp_attack_units` only ever lowers remaining (min(remaining, total − spent)); activate → attack → swap item → swap back never refills; reclamp runs on the next attack click after removal. Loading weapons stay at 1.
- Base AC: only the first unarmored_defense rule with a chosen alternative applies (no stacking between formulas), only when no armor; `allows_shield: false` + shield falls back to 10 + DEX. Exclusive group required by the validator.
- Merged/suppressed/unattuned copies grant neither attacks nor AC (`copy_active` / upgrades gate; covered by 070 checks).
- Save/load and legacy saves (no rule_alternatives → first option per group); forged options refused. No per-ID branches.
- Incapacitated: choosing an upgrade spends nothing and grants no action; attacks are still gated by the existing attack path.

## Tests (Godot 4.7.2, imported twice)
- Logic: 6077 passed, 0 failed (builder 6074 + 3 review checks). No SCRIPT ERROR.
- Scenarios run alone: batch_070_attack_ac_upgrades_flow, _reload, fighter_second_wind, monk_action_flow, barbarian_action_flow, weapon_attack_numeric_bonus_flow, batch_067_weapon_damage_choice_flow pass. fighter_progression and barbarian_choice_flow fail with SCRIPT ERRORs, both on the batch-066 main failure list. **No regressions.**

## Open for Brandon
- Mid-action switch policy "no refund, no gain" (builder's question): recommend confirm.
- Remaining swings aren't saved mid-turn: a save/load mid-Attack drops the unspent swings (no exploit, a loss). Card?
- Only the first unarmored_defense rule is a consumer, and Mage Armor vs a base_ac formula isn't a player choice yet. Card?
- No shipped content uses base_ac (Barbarian/Monk Unarmored Defense data has empty effects).
