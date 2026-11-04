# SC-07 support 01: Ray of Enfeeblement

Stacked on `codex/crown-spells-sc-06` (#97). Rules: SRD 5.2.1 Ray of Enfeeblement.

## What changed
- `data/core/spells/crown_sc_07.json`: Ray of Enfeeblement as shared data. It has a Con save, a 60 ft range and concentration for 1 minute. The target repeats the Con save at the end of each of its turns (`target_turn_end`).
  - On a failed save it gets `enfeebled`.
  - On a successful save it gets `next_attack_disadvantage`, which expires at the start of the caster's next turn.
  - The manifest winner now replaces `imported_spells.json#147`.
- Generic `MARKER_RULES` in `CombatAction`: `enfeebled` (plus a legacy `ray_of_enfeeblement` alias for old saves) carries the `str_d20_disadvantage` and `damage_roll_penalty_d8` consequences. Strength saves, Strength attacks, event Strength checks, the Barbarian Brutal Strike save and damage-source penalties now read these consequences. Nothing checks the spell ID any more.
- Removed the Ray spell-ID branches in `spell_effect_application.gd`, `spell_cast_reactions.gd` and `spell_effects.gd` (MANAGED_SPELLS).
- `event_resolver.gd`: a Strength disadvantage contributor is added only when a Strength marker exists. This also fixes a lightly-obscured case that was credited to the wrong source.
- Test updates:
  - `mixed_mechanics_encounter` now checks `enfeebled`.
  - It advances the turn serial before the second repeat save, because shared repeat saves are claimed once per target turn.
  - It checks success as "next_attack_disadvantage only".
  - The `test_runner` assert now checks the condition instead of the old field.

## Proof (`crown_sc_07_support_01_flow`)
- Contract and bad-data checks: an unknown condition and an incomplete outcome map are both rejected.
- A renamed neutral copy, `crown_sc_07_support_01:neutral_wilt`, goes through `CombatAction.resolve_spell`:
  - A failed save gives enfeebled, with Disadvantage on Strength saves and attacks but not on Dexterity ones.
  - A Character's damage of 20 resolves to 12–19.
  - A failed repeat save keeps the effect; a successful one ends it.
  - On a successful initial save, the rider survives the caster's turn end and expires at the caster's turn start.
- A level 3 Warlock selects Ray through ordinary class selection and casts it with the picker and a hex click. It spends a level 2 slot and concentrates. A live 20-damage monster attack loses 1d8. A live repeat save ends the effect. A second cast against a target that succeeds leaves only next-attack Disadvantage.
- Checkpoint, then a fresh-process recovery (`CROWN_SC_07_SUPPORT_01_RECOVER=1`):
  - enfeebled, the Strength Disadvantage and the 1d8 penalty survive.
  - A repeat save still ends the effect.
  - A legacy `ray_of_enfeeblement` marker keeps its Strength Disadvantage.
- Old-save round trip: the base branch (e899572) wrote the SC-06 checkpoint, and this branch loaded it in a fresh process (logs below).

## Results
- crown_sc_07_support_01_flow: 0 failed, and the recovery run 0 failed. The flow was run 3 more times; all passed.
- Regressions with 0 failed: mixed_mechanics_encounter, sleep_spell_flow, crown_sc_06_flow, crown_smoke, charm_person_spell_flow, conversion_batch_002_flow.
- conversion_batch_001_flow: the same 2 Bless failures as the base (known, no Bless PR).
- Logic suite: ALL TESTS PASSED.

## Limits
- Combat Strength ability checks outside event checks (for example grapple or shove contests) do not yet read `str_d20_disadvantage`, unless they already go through the consequence helpers.
- The live monster-attack proof loops until a hit lands. Natural 1s can miss, and the harness turn loop can skip an attempt.
- The success rider also lasts until the target's next attack. That attack's consumption uses the existing `next_attack_disadvantage` behavior.
