# SC-03 support 07: shared push + unsecured-object push + pre-payment off-map refusal (Thunderwave)

Base: `codex/crown-spells-sc-03-support-06`.

## What changed
- `SharedSpell`: a shared `push` effect (`distance` 1..24 hexes, used with `on_failed_save`) and a new `area_object_push` field (`{distance, scope:"unsecured"}`, area spells only) are now validated. The shared effect path now calls the existing `_apply_push`.
- `CombatObjectRules.is_unsecured_single_hex` and `push_area_objects`: these generic helpers push objects in the area away from the area origin along `Targeting.get_pushed_position`. They skip objects that are removed, fixed, secured, worn or carried. They update both the object position and the grid entity.
- `_resolve_spell_cast_targets`: each creature is resolved once per area cast. Before this, a creature pushed onto a later area hex was hit twice.
- `SpellCastValidation`: an area spell whose center is not a map tile is now refused **before payment**. This fixes the (5,0) bug where the slot was spent with no effect. The fix was in generic spell code, not in an outside consumer.
- Data: `data/core/spells/crown_sc_03_support_07.json` holds shared `thunderwave` from SRD 5.2.1. It has V and S components, a 15-ft Cube from self, a CON save, 2d8 thunder (half on a success), a 10-ft push on a failed save, a 10-ft push for unsecured objects, a loud boom audible at 300 ft, and +1d8 per slot level above 1. A manifest override replaces `imported_spells.json#185` and `core_spells.json#9`. CSV: the `thunderwave` row is now `converted`.
- `ordinary_action_flow` fixture updates, with the intent unchanged:
  - The "paid empty-area spell" cast now clicks an empty **on-map** hex. It used to click (0,5), which has no tile and is now correctly refused before payment.
  - The native-host sound check now uses a native-shaped copy of Thunderwave, because Thunderwave itself is shared now.

## Proof (`crown_sc_03_support_07_flow`, passes 3/3)
- Contract: the production loader returns shared Thunderwave. Bad `push` and bad `area_object_push` values are rejected. The upcast is 2d8 + 1d8 at slot level 2. The unsecured-object predicate is checked.
- Renamed neutral spell (`crown_sc_03_support_07:neutral_gust`, 2d6 cold, STR save) goes through `CombatAction.resolve_spell`.
- Player controls: a Wizard prepares and casts Thunderwave with the picker and a hex click. The test checks:
  - one CON save and one slot spent;
  - a failed save pushes the foe 10 ft, and a success gives half damage with no push;
  - a crate in the cube moves 2 hexes away and stays on a tile;
  - a fixed bolted object does not move.
- Off-map refusal: Shatter centered at (5,0) is refused and the slot is not spent.
- Sound: the existing `ordinary_action_flow` check "Thunderwave's 300-foot effect sound reaches a Ready listener 65 feet away" passes with the shared data.
- Logic suite: 6935 passed, the same as base. These scenarios pass: ordinary_action_flow, ready_action_flow, crown_sc_03_support_06_flow, mixed_mechanics_encounter. Logs are in `logs/`.
- Saved data: the saved shape is unchanged. Pushed objects reuse the existing `position` field, so no .sav round trip was needed.

## Limits / known
- "Entirely within the Cube" counts only single-hex objects: Tiny, Small or Medium, or an object with no size.
- Objects are pushed after the creatures. A creature or a blocked hex stops an object's push.
- The boom uses the existing S-218 noise consumer. It needs a represented cast host, so a bare resolver call without a grid refuses the sound.
- Still failing and not touched here: `sorcerer_twinned_spell`, and the Bless-on-downed error from #86.
