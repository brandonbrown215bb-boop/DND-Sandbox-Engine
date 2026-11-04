# SC-03 support 04: shared `delayed_damage` (Melf's Acid Arrow)

Stacked on #88 (`codex/crown-spells-sc-03-support-03`).

## What changed
- `SharedSpell` accepts a validated `delayed_damage` field: `{damage: plain dice, damage_type: valid type, trigger: "end_of_target_next_turn"}`. It is only allowed on a single spell attack with a top-level `damage` and no `steps` or `projectiles`. Unknown keys, bad dice, bad types and other triggers are rejected. The field was removed from the "needs a dedicated handler" deny list.
- `SpellEffectApplication`: the native delayed-damage scheduling was pulled out into `_schedule_delayed_damage` and is now also called on the shared branch. Only hits schedule. Upcasting uses the spell's `upcast.damage_per_level`, so per SRD 5.2.1 both the initial and the later damage gain 1d4 per slot level above 2. The existing end-of-turn hook (`SpellEncounterLifecycle._resolve_delayed_spell_damage`) settles it unchanged.
- Data: `data/core/spells/crown_sc_03_support_04.json` holds a shared `melfs_acid_arrow` (4d4 acid ranged spell attack, `damage_scale_by_outcome {hit: 1.0, miss: 0.5}` replacing the native `miss_damage_scale`, delayed 2d4 acid, upcast 1d4). A manifest override replaces `imported_spells.json#126`.
- CSV: `melfs_acid_arrow` is marked converted.

## Proof
- `crown_sc_03_support_04_flow`:
  - Contract and validator rejections.
  - A renamed neutral definition (4 cold, 1d6 fire later, 1d4 upcast) loads through the production loader. `CombatAction.resolve_spell` handles hit and miss: a hit schedules `1d6 + 1d4`, and a miss deals half and schedules nothing.
  - The real spell through player controls: a Wizard records it in its spellbook and prepares it by ordinary class selection. Picker plus hex click with a 3rd-level slot deals 5d4 now, queues `2d4 + 1d4`, and the end-of-turn hook deals it once and clears it. A miss deals 2-8 with nothing queued.
  - Passed in 6 of 6 local runs.
- Logic suite: 6935 passed, 0 failed.
- Scenarios (logs in this folder):
  - Pass: crown_sc_03_support_03_flow, crown_sc_01_support_01_flow, crown_sc_02_flow, conversion_batch_002_flow.
  - mixed_mechanics_encounter: its Acid Arrow delayed-damage check passes. One Shocking Grasp opportunity-attack check fails the same way on the #88 base, so it was already failing.
  - conversion_batch_001_flow: only the known Bless-on-downed error from #86, which this PR does not touch.
  - crown_sc_02_flow failed once on a random roll ("level-3 slot raises the Cold burst"). It passed when rerun here and passed on the base.

## Limits
- The display name stays "Melf's Acid Arrow" (SRD calls it "Acid Arrow") so existing references keep working.
- The only trigger is `end_of_target_next_turn`, the one this queue needs.
- Saved data is unchanged: `delayed_spell_damage` keeps its existing shape, so no .sav round trip was needed.
- No class-membership changes.

## Windows
```
.\run_tests.ps1 -Suite logic
& $godot --headless --path . res://scenes/viewport_harness.tscn --scenario=crown_sc_03_support_04_flow
```
