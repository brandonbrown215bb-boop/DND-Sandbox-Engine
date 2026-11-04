# SC-06: Sleep + Hypnotic Pattern (shared staged repeat saves, area creature choice, sight-gated area saves)

Stacked on `codex/crown-spells-sc-05-support-03` (#96).

## What this adds (generic, data-driven, no spell-ID branches)
- `repeat_save` stages may set `final` and an `on_success` value (`advance`/`end`). These are handled in SpellEffects/CombatAction. The legacy hard-coded Sleep repeat path was removed from spell_resolver, spell_control_resolver, combat_action and SpellEffects.MANAGED_SPELLS.
- New conditions: `unconscious` and `speed_zero` (is_speed_zero honors it).
- `save_auto_success_traits`: any creature with a listed trait (currently `magical_sleep_immunity`) succeeds the save automatically, and the log says so.
- `area_creature_choice`: the caster picks which creatures in the area are affected through a generic "<Spell> Targets" dialog.
- `area_save_requires_sight`: a creature that can't see the effect is unaffected (CombatPerception.can_see_target).
- `end_on_shake_action`: a creature uses an action to shake an affected creature, which ends the effect.
- Square area shape using `size_feet`.
- Persistence fix: staged records on monsters now validate (the recipient id falls back to `id`).
- Data: `data/core/spells/crown_sc_06.json` (#1 Sleep, #2 Hypnotic Pattern). Manifest winners replace core_spells#8 / imported#167 and imported#101.

## Proof
- `crown_sc_06_flow`:
  - The renamed neutral definitions (`neutral_doze`, `neutral_swirl`) go through the production loader and CombatAction.resolve_spell. Checked: stage advance, final stage, damage end, on_success end, elf auto-save, triple grant.
  - Sorcerer player casts through the controls:
    - Sleep, with a choice dialog where one creature is declined.
    - Hypnotic Pattern, where a Blinded creature is unaffected.
    - A shake action ends the effect.
  - Logs: `logs/crown_sc_06_flow.log`.
- Recovery (`CROWN_SC_06_RECOVER=1`, fresh process): Sleep's final Unconscious stage survives the reload and damage then ends it. Hypnotic Pattern is cast, saved, passes preflight and reloads. Log: `logs/crown_sc_06_recover.log`.
- Old save: a checkpoint written by the SC-05 support-02 base was recovered on this branch with FRESH_PROCESS_PASSED (`logs/old_save_round_trip.log`).
- Logic suite: 6936 passed, 0 failed (`logs/logic_suite.log`).
- Regressions pass: sleep_spell_flow, crown_sc_05_support_01/02, crown_sc_01_support_01, charm_person, blindness_deafness, crown_smoke.
- `conversion_batch_001_flow` has 2 known Bless failures. The same 2 failures happen on the base branch.

## Limits
- The shake requires adjacency.
- The 30-ft Cube is approximated as a square hex footprint (radius 3).
- Sight to the pattern is measured to the anchor point.
- "Creatures that don't sleep" uses the existing `magical_sleep_immunity` trait.
- No legacy in-flight Sleep record from an old save was specifically round-tripped, because the legacy format had no stages. The standard old-save round trip passes.

CSV: `sleep` and `hypnotic_pattern` → converted.
