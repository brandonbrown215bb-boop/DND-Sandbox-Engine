# SC-03 support 05: shared damage-type choice + exploding dice (Sorcerous Burst)

Base: `codex/crown-spells-sc-03-support-04` (#89).

## What changed
- `SharedSpell`: new shared fields `damage_type_options` and `exploding_dice`, checked by `damage_choice_error`.
  - `damage_type_options`: at least 2 distinct valid damage types (not `none`), and `damage_type` (the default) has to be one of them. The choice itself comes from the existing generic `SpellCastChoices` → `hud.request_damage_type_choice` popup, which writes `damage_type` into the cast.
  - `exploding_dice`: `{sides, max_extra}`. `sides` must be a standard die that appears in `damage`. `max_extra` is `"spellcasting_modifier"` (uses the caster's `get_spellcasting_ability()`) or an integer from 0 to 20.
  - Both fields need a single ranged or melee spell attack with `damage` and no steps or projectiles.
- `SpellDamageRolls`: the `id == "sorcerous_burst"` branch in `SpellAttackResolver` is gone. The new `exploding_policy(caster, spell)` reads data only: shared `exploding_dice`, or the legacy `explode_on_max` keys if any old record still has them. `_roll_exploding_damage` and `_resolve_exploding_dice` now take any die size; they used to be hard-wired to d8. The detail keys are renamed from `_sorcerous_burst_*` to `_explode_*`. The old function names stay as thin wrappers.
- Data: `data/core/spells/crown_sc_03_support_05.json` holds the shared `sorcerous_burst`, with SRD 5.2.1 text. Range 120 ft, 1d8 damage, 7 damage types, d8s explode up to the spellcasting modifier, cantrip scaling 2d8/3d8/4d8. A manifest override replaces `srd_additional_spells.json#1`.
- CSV: the `sorcerous_burst` row is now `converted`.

## Also in this PR (requested)
- **mixed_mechanics Shocking Grasp opportunity-attack failure: #86 caused it.** It passes on true base 6a47efa and on d2f22ac (SC-03), and fails from 0b6361a (support-01, #86) onward. Cause: the shared Shocking Grasp validation enforces touch range 1, but the harness fixture cast from (-3,-1) at a monster on (0,4). The native path never checked range. Fix: `test_mixed_mechanics_encounter` moves the shocked monster to a free, passable hex next to the wizard before casting. The game rule is unchanged. `mixed_mechanics_encounter` now passes.
- **crown_sc_02 cold-burst upcast check is now deterministic.** A natural 20 hits even AC 1000 and adds damage. The check now recasts up to 5 times (resetting each time) and keeps the first true miss. It passed 3 of 3 runs.

## Proof
- Contract: the production loader returns shared Sorcerous Burst with no native keys. Seven bad payloads are rejected, and so is choice/exploding damage on a save spell. A CHA 16 sorcerer gets a cap of 3 extra dice.
- Renamed neutral spell (`crown_sc_03_support_05:neutral_spark`: 1d6 fire/cold, 6s explode, max 2 extra) cast through `CombatAction.resolve_spell` with damage type cold. Explosions showed up (max seen > 6), damage never went above 18, and the type was cold. With `max_extra: 0`, damage never went above 6.
- Player controls: a level-1 Sorcerer learns the cantrip through ordinary class selection, then levels to 5. Each cast goes through the spell picker, the damage-type popup (`id_pressed` → Psychic) and a hex click. Hits deal 2d8 (+ explosions), the log shows psychic, and no slot is spent. The check loops until a hit above 16 shows an explosion. It passed 4 of 4 runs.
- Logic suite: 6935 passed. Scenarios: crown_sc_03_support_05_flow, mixed_mechanics_encounter, crown_sc_02_flow, crown_sc_03_support_04_flow and crown_sc_01_support_01_flow all pass.
- No saved-data or schema change: this is spell content only, so there is no .sav round trip.

## Limits / known
- `sorcerer_twinned_spell` fails 4 checks at true base 6a47efa, on #89 and here. It was not introduced by this stack and is left alone.
- The Bless-on-downed error (#86) is untouched.
- The SRD says you "can" add the extra d8. The engine always adds it, up to the cap, the same as the native version did; adding damage is never worse for the caster. Monster/AI casters get the default type (the first option) because the popup is player-only.
- The native record had `requires_target_sight`, but the SRD text has no sight requirement, so the shared record leaves it out.

## Run
Linux:
```
TEST_SUITE=logic bash run_tests.sh <godot>
<godot> --headless --path . res://scenes/viewport_harness.tscn --scenario=crown_sc_03_support_05_flow
<godot> --headless --path . res://scenes/viewport_harness.tscn --scenario=mixed_mechanics_encounter
```
Windows:
```
.\run_tests.ps1 -Suite logic
.\run_tests.ps1 -Scenario crown_sc_03_support_05_flow
.\run_tests.ps1 -Scenario mixed_mechanics_encounter
```
