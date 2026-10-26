# Batch 071 build — S-130/S-131 maximum-HP effects on monsters

Done means (verbatim): "Monster maximum-HP effects (S-130/S-131): overlapping sources, removal order, clamps and zero-maximum consequences, through real combat."

Slice row (vocabulary-slices.md:321): "Extend `MaxHpSourceRules` and actual combat effect dispatch to Dictionary targets using the existing formula, clamp, periodic/cure and zero-maximum policies. Carry source ownership through removal and the encounter record's existing capture path where that record persists. Prove stacked changes/removal orders and zero-maximum remains on a real monster target; do not build a separate monster rules interpreter or general monster-save framework."

Base: `batch-070-attack-ac-upgrades` @ 26c8f3a. Godot 4.7.2 headless.

## What changed
- `MaxHpSourceRules` accepts Character or monster Dictionary (same formula/clamp/floor/zero-limit; no monster interpreter, no per-ID branches, no engine defaults).
- Optional rule key `combine` (`highest` | `sum`; absent = legacy sum). `highest`: same rule id + kind do not stack, largest applies, earliest on ties (SRD 5.2.1 p.106). Inactive entries stay owned (applied 0) and take over on removal.
- Unknown rule fields now refused by `validate_rule`.
- Shared-spell effect `max_hp_source` (validation, `manages`, timed-record, dispatch). Cast `source_id` owns the entry; spell record links `max_hp_source`, so `SpellEffects.remove` (concentration end, expiry, encounter end) removes exactly it. Concentration targets gain the monster record.
- Zero maximum (SRD 5.2.1 p.17): death once, `zero_hp_aftermath` with declared remains/cause and `cause_source`; link not written after death so spell end never revives.
- Pre-cost refusal `MaxHpSourceRules.cast_error` in both `SpellCastValidation` (HUD) and `SpellResolver` (before slot deduction): dead/settled target or protected maximum.
- Persistence: `saved_link_error` (owned source, same rule id, spell declares rule) via `SpellEffectPersistence`.
- Bug found by the live scenario and fixed: real goblin records have no `spell_effects` key; the link write now persists into the record (logic check added).

## Evidence
- Import ×2: no SCRIPT/Parse/Compile errors.
- Logic: **6104 passed, 0 failed** (baseline ~6074 + reviewer additions; 071 adds its group).
- Scenarios (all exit 0, 0 failed): batch_071_monster_max_hp_flow (13 ok), batch_071_monster_max_hp_reload (2 ok, fresh process), batch_031_linked_damage_flow, batch_035_profile_max_hp_flow, batch_036_end_and_charge_flow, batch_037_mode_upgrade_flow, batch_038_switch_option_flow, batch_039_created_actor_flow, batch_044_parts_magic_flow, batch_045_active_tether_flow, batch_047_form_equipment_chooser_flow, batch_070_attack_ac_upgrades_flow, batch_070_attack_ac_upgrades_reload.
- Live flow covers: Cancel at slot prompt spends nothing; HUD cast on goblin 20→14 with clamp; no-Action recast refused before paying; second caster same-named no stack; concentration switch removes exact source, different spell adds (10); concentration end restores 6 without raising current; 6-max husk dies once with dust; recast at dead husk refused before paying, no duplicate remains; spell end does not revive; character vigor survives JSON DTO round trip, real save/load and fresh-process reload; removal restores base.

## PARTIAL
- Monster `turn_started` periodic/cure events not dispatched to monster records.
- Monster-attack `max_hp_source` still targets characters only.
- Monster records do not persist mid-encounter (no capture path exists); persistence proved on a character recipient of the same effect.
- No item-granted maximum-HP sources exist for monsters; merged/suppressed copy gate not applicable.

## Open questions
- Should `combine` become required (no default) for new content, with legacy sum only for already-loaded data?
