# Batch 070 build: S-084/S-085 Extra Attack and base-AC upgrades

Done-means: "Extra Attack and base AC upgrades (S-084/S-085): switching preserves spent attacks; removal and reload restore values."

Slice row (vocabulary-slices.md:320): extend source-owned upgrades to the actual Extra Attack count and base-AC alternatives using existing stat alternatives and attack-unit budgets; define the data fields and consumers explicitly; prove exclusive alternatives, removal/reversion, reload, and that switching cannot supply a fresh parent action or undo spent attack units.

Contract: [docs/mechanics/attack-and-ac-upgrades.md](../mechanics/attack-and-ac-upgrades.md) — **PARTIAL**.

## Evidence (Godot 4.7.2, headless, imported twice)
- Logic suite: **6074 passed, 0 failed** (baseline ≈6041; +33 Batch070Checks). No SCRIPT/Parse/Compile errors in logs.
- `batch_070_attack_ac_upgrades_flow`: 14/14 ok — real Attack click (3 swings, 1 spent killing a 1-HP target), HUD rule popup Cancel no-op, switch 3→2 leaves 1 swing, switch back no refund/no new action, stale answer refused, Sturdy Frame AC 15, last swing on new target, refused attack with nothing left, removal restores 1 extra/AC 13, re-wear restores option, real save/load.
- `batch_070_attack_ac_upgrades_reload` (fresh process): 2/2 ok.
- Related scenarios vs base 075abfd: identical results (batch_037/052/057/062/064/067×2/069×2, weapon_attack_numeric_bonus, monk_action, fighter_second_wind, barbarian_action pass on both; shared_spell_attack_bonus_flow, attack_result_adjustment_flow, fighter_progression, barbarian_choice_flow fail identically on base).

## Refusals (before any change)
Ungrouped / out-of-range / `add` attack_count; base_ac missing allows_shield, duplicate or unknown abilities; mixed consumer+mode changes; options owned by another copy; forged saved / record-state options; stale popup tokens.

## Open question for Brandon
Mid-action switch policy implemented as "no refund, no gain": remaining = min(remaining, new total − spent). Removing the item mid-action reclamps on the next attack click. Confirm.
