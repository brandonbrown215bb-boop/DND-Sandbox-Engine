# SC-05 support 02: Blindness/Deafness, Blur, Charm Person, Faerie Fire

This PR is stacked on `codex/crown-spells-sc-05-support-01` (#94). The rules come from SRD 5.2.1.

## Generic pieces
All of these are data-driven, with no spell-ID branches.
- `shared_spell.gd`:
  - New conditions `charmed`, `blurred` and `outlined`.
  - `condition_options` / `chosen_condition` / `condition_choices`: the caster picks the condition for each cast, used here for Blinded or Deafened.
  - `save_advantage_if_fighting_target`.
  - `repeat_save` for end-of-turn repeat saves.
- `spell_cast_choices.gd` / `spell_effect_application.gd` / `spell_effect_persistence.gd`: the chosen condition is applied and survives a save and reload.
- `combat_action.gd`, plus the attack and projectile resolvers:
  - `is_blurred_against`: attackers have Disadvantage unless they have Blindsight or Truesight.
  - `is_outlined_for`: attackers have Advantage unless they are Blinded.
  - An Outlined creature gets no benefit from being Invisible.
- `combat_perception.gd`: a condition can make a creature shed light (`CONDITION_DIM_LIGHT_HEXES`, outlined = 2 hexes / 10 ft). This feeds `illumination_level_at` for both player and monster grid entities.
- `spell_cast_validation.gd`: the per-creature multi-target check is skipped for spells that use `area_selection`. Before this change, every area spell that also managed targets was wrongly rejected.

## Proof
- `crown_sc_05_support_02_flow`:
  - Renamed neutral definitions (`data/core/spells/crown_sc_05_support_02.json`) go through the production loader and `CombatAction.resolve_spell`.
  - Then the real spells are cast through player controls:
    - Charm Person, from a Sorcerer that levels up from 1 to 3 to learn Blur and Blindness/Deafness.
    - Faerie Fire, from a Bard in its own encounter.
  - In a dark ambient, the outlined creature sheds Dim Light out to 2 hexes and no farther.
  - Checkpoint and recover: Deafened and Blurred both survive a save and reload in a fresh process, and the repeat save then ends Deafened (`logs/crown_sc_05_support_02_recover.log`).
- Old-.sav round trip: a checkpoint written by the base branch loads on this branch and prints `FRESH_PROCESS_PASSED` (`logs/old_save_round_trip.log`).
- Logic suite: 6935 passed, 0 failed.
- These scenarios pass:
  - faerie_fire, blur, see_invisibility, combat_light_visibility and crown_sc_04_support_01. Logs are in `logs/`.
  - Earlier in the same branch run: blindness_deafness, charm_person, charm_monster, conversion_batch_002, crown_sc_01/02/03, all sc_03 supports, crown_condition_finish and crown_smoke.

## Other changes
- Legacy logic tests that asserted the old per-spell shape (8 tests) now assert the shared shape. For Countercharm, the test checks `has_condition("charmed")`.
- `crown_sc_01_support_01_flow`: the Ray of Frost miss loop is now deterministic. It resets the target after a natural-20 hit, which fixes the flake.

## Limits
- **Charm Person:** "fighting" the target is approximated as the target being a monster.
- **Faerie Fire stays `partial`:**
  - Objects in the Cube are not outlined.
  - "If the attacker can see it" is approximated as "the attacker is not Blinded".
- **Pre-existing failures:** both are identical on the base branch, and neither comes from this PR.
  - `invisibility_spell_flow` has 2 failures.
  - `conversion_batch_001_flow` has the known Bless failure.
- **`ranger_natures_veil_blindsight_flow`:** this scenario runs 0 tests on both base and this branch, which looks like a harness name issue. It is not counted as proof.

## Queue
- blindness/deafness, blur and charm_person: converted.
- faerie_fire: partial, for the reasons above.
