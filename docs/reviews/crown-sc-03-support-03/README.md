# SC-03 support 03: shared `projectiles` payload (multi-target split)

Stacked on #87 (`codex/crown-spells-sc-03-support-02`).

## What changed
- **New shared field `projectiles`** (`SharedSpell.FIELDS`), strictly validated by `SpellProjectileResolver.block_error`:
  `noun`, `delivery` (`automatic` | `spell_attack`, must match `attack_type`), `damage`, `count` (1-20),
  `extra_per_slot_level`, `count_by_character_level` (attack cantrips only), `shield_negates` (bool).
  Top-level `damage`/`save`/`steps`/`scaling`/`upcast`/`effects` beside it are rejected.
- **One generic path**: `SpellProjectileResolver.view()` translates the block for the existing dart/ray resolvers;
  `spell_resolver` dispatches shared projectile spells there (cast settlement kept).
- **ID lists removed**: the `["magic_missile","scorching_ray","eldritch_blast"]` checks in targeting, selection,
  validation, results and combat_state now use `SpellProjectileResolver.is_projectile()`; projectile naming uses the
  authored `noun`; the Shield reaction offer and the resolver's Shield negation use `shield_negates` (legacy native
  dart records keep their old Shield rule). Per-target allocation uses a generic `_projectile_count_for_target` key
  (legacy keys still read).
- Damage-presence checks (AI, selection, reactions, ready, sorcerer, combat_action, warlock damage-cantrip
  invocation eligibility, class_progression invocation validation) accept projectile spells.
- **Loader**: when a shared-execution winner replaces a native record, `_merge_missing_fields` no longer backfills
  fields outside `SharedSpell.FIELDS`, and never backfills `damage/scaling/upcast/save/steps` into a projectiles
  winner (otherwise the replaced native `max_targets`/`dart_count`/`upcast` leaked in and failed validation).
- Also fixed two True Strike ID checks missed in #87 (`spell_cast_results` target range, `inventory` weapon-as-material) to use the `weapon_attack` effect.
- Data: `data/core/spells/crown_sc_03_support_03.json` (magic_missile, scorching_ray, eldritch_blast) + manifest overrides.

## SRD 5.2.1
- Magic Missile: 3 darts, 1d4+1 Force each, creatures you can see within 120 ft, +1 dart per slot level above 1; Shield negates.
- Scorching Ray: 3 rays, separate ranged spell attacks, 2d6 Fire, +1 ray per slot level above 2.
- Eldritch Blast: 1d10 Force beam, separate attacks, 2/3/4 beams at levels 5/11/17, 120 ft.

## Queue
- `magic_missile`, `scorching_ray`: **converted**.
- `eldritch_blast`: **partial** (not converted): object targets are still not reached.

## Proof
- Contract checks: all three are shared and validate; nine malformed blocks rejected; count scaling (MM 3→5 at slot 3, SR 3→5 at slot 4, EB 1/1/2/2/3/3/4 at levels 1/4/5/10/11/16/17).
- Renamed neutral definitions (`neutral_darts` "shard", cold, 2 + 2/slot; `neutral_rays` "bolt") through the
  production loader and `CombatAction.resolve_spell` (exact damage 4×2, per-target allocation of 1, 2 attacks).
- Player controls (picker + hex clicks): Magic Missile split 2 + 1 with damage bounds and one slot spent;
  Scorching Ray split 1 + 2 from a 2nd-level slot; level-5 warlock Eldritch Blast split 1 + 1.
- Logic suite: 6935 passed, 0 failed (baseline 6935). Scenarios passing: crown_sc_03_support_03_flow,
  spell_cast_stage_flow, wand_magic_missiles_flow, ready_action_flow, crown_condition_finish_flow,
  crown_sc_03_support_02_flow, crown_sc_03_flow, crown_sc_01_support_01_flow.
- `sorcerer_twinned_spell` fails 4 checks here and 5 on the #87 base (log included). It already failed before this PR and isn't caused by it.
- No saved data shape changed (allocation keys are transient), so no old-.sav round trip was needed.

## Limits
- Eldritch Blast object targeting not implemented. Twinned/Empowered interaction covered only by the existing logic checks.

## Run (Windows)
```
powershell -ExecutionPolicy Bypass -File .\run_tests.ps1 <path-to-godot.exe> -Suite logic
powershell -ExecutionPolicy Bypass -File .\run_tests.ps1 <path-to-godot.exe> -Suite integration -Scenario crown_sc_03_support_03_flow
```
