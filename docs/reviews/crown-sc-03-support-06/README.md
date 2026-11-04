# SC-03 support 06: shared creature-type save Disadvantage + area object damage (Shatter)

Base: `codex/crown-spells-sc-03-support-05` (#90).

## What changed
- `SharedSpell`: `save_disadvantage_creature_types` is now an allowed shared field. It must be a nonempty list of distinct types from `CreatedActorRules.CREATURE_TYPES`, and the spell needs a `save`. The save resolver already read this field generically, so the work here was validating it and letting shared data use it.
- Shared area spells with `targets_objects: true` use the existing generic area-object consumer, `CombatObjectRules.resolve_area_object_damage`. That consumer only damages objects that are unattended (not worn or carried) and nonmagical. No spell-ID logic was added.
- Data: `data/core/spells/crown_sc_03_support_06.json` holds the shared `shatter`, using the SRD 5.2.1 text. It is a CON save for 3d8 thunder, half on a success, in a 10-ft Sphere (radius 2) at range 60 ft. Constructs make the save at Disadvantage, objects in the area take the damage, and upcasting adds 1d8 per slot level. A manifest override replaces `imported_spells.json#160` and `srd_additional_spells.json#159`.
- CSV: the `shatter` row is now `converted`.

## Proof
- Contract: the production loader returns shared Shatter. 4 bad lists are rejected, and so is a spell that has no save. Upcast is 3d8 + 1d8 at slot level 3.
- Renamed neutral spell (`crown_sc_03_support_06:neutral_peal`): 2d6 cold, WIS save, Disadvantage for undead. Cast through `CombatAction.resolve_spell`, the undead target saves at Disadvantage and a beast does not. An unattended nonmagical object takes the authored 2d6.
- Player controls: a level-5 Wizard puts Shatter in its spellbook and prepares it the normal way, then casts it through the spell picker and a center-hex click with a 3rd-level slot. A Construct in the area takes 4d8 thunder (half on a success). An unattended crate takes 4d8 thunder. A magical relic and a carried satchel take nothing. One 3rd-level slot is spent.
- Logic suite: 6935 passed. These scenarios pass: crown_sc_03_support_06_flow, crown_sc_03_support_05_flow, mixed_mechanics_encounter, crown_sc_02_flow, conversion_batch_002_flow.
- Content only, with no saved-data change, so no .sav round trip was needed.

## Limits / known
- Objects take the full rolled damage with no save. This matches the SRD sentence "also takes the damage" and the engine's existing area-object consumer.
- Disadvantage for the Construct in the player-controls cast is proven on the renamed path (`save_disadvantage` in the result). The combat log does not show advantage state.
- Possible existing bug, not changed here: in the default combat scene, clicking a center hex that appears to have no tile ((5,0)) spent the slot with no effect. The flow uses (3,0).
- `sorcerer_twinned_spell` was already failing at base 6a47efa, and the Bless-on-downed error (#86) is still there. Neither is touched.

## Run
Linux:
```
TEST_SUITE=logic bash run_tests.sh <godot>
<godot> --headless --path . res://scenes/viewport_harness.tscn --scenario=crown_sc_03_support_06_flow
```
Windows:
```
.\run_tests.ps1 -Suite logic
.\run_tests.ps1 -Scenario crown_sc_03_support_06_flow
```
