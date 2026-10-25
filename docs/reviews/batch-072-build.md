# Batch 072 build — S-060/S-203 last-charge property loss

Done means (verbatim): "Last-charge property loss (S-060/S-203): keep_properties controls actual behavior, across independent copies and reload."

Slice row (vocabulary-slices.md:322): "`LastChargeRules` currently records `keep_properties` in a receipt; enforce the declaration in supported property consumers. Reuse per-copy `MagicPropertyRules` queries where appropriate, retaining declared mundane weapon/armor properties while ending lost magic. Audit actual item spell permissions, benefits, effects, attachment sets and recovery consumers. Spend the last charge through normal action/reaction casting, prove independent copies and reload, and preserve the native wand path until its deliberate conversion. Unsupported properties must be rejected explicitly."

Base: `batch-071-monster-max-hp` @ 65382cf (includes reviewer commit). Godot 4.7.2 headless. Card: Q-20261025-113734-469f.

## What changed
- `keep_properties` now names `MagicPropertyRules.PROPERTIES` entries. `LastChargeRules.definition_error` (called by `DataLoader` item validation) refuses unknown names, properties the item lacks, and `keep_properties` on `destroy`. No engine default: absent = nothing magical kept.
- `LastChargeRules.lost(record, property)` is read by `MagicPropertyRules.active` and `_affected`. Audited consumers that therefore obey it per exact copy: `SpellPermissionRules` (both permission loops), `SourceBenefitRules` (benefits + attachment sets), `CastInterruptionRules` (incoming negation), `Inventory.has_equipped_attuned_item` (item effects), `OwnedFeatureSources` (features; inventory resyncs owned features on degrade). Recovery: `recover_daily_charges` already skips degraded copies.
- Settle receipt adds `lost_properties`; `kept_properties` is the declared list filtered to properties the item has. `state.magical` = any kept magical property.
- `saved_state_error` checks `magical` matches the declaration. No new saved fields → legacy 036-shape degraded records load.
- Fixture change: `fixture:b036_spent_rod` kept `"light"`, which names no supported property and is now refused; it now declares `[]` (036 check updated accordingly).
- Native wand path, merged-copy gate and S-203 suppression untouched; kept properties are still suppressible.

## Evidence
- Import ×2: no SCRIPT/Parse/Compile errors (logs /workspace/b072_logs).
- Logic: **6133 passed, 0 failed** (baseline 6111; +22 from `Batch072Checks`).
- Scenarios (all PASSED, exit 0): batch_072_last_charge_flow (9 ok), batch_072_last_charge_reload (2 ok, fresh process), batch_036_end_and_charge_flow, batch_021_spell_permissions_flow, batch_041_bond_equipment_flow, batch_044_parts_magic_flow, batch_049_owned_feature_sources_flow, batch_068_exact_contents_flow, batch_068_exact_contents_reload, batch_071_monster_max_hp_flow, batch_071_monster_max_hp_reload.
- Live flow: two identical ember rings each offered in the real HUD picker and each +1 AC; Cancel spends no charge/action; two real HUD casts from copy A spend its last charge and degrade it once (kept `source_benefits`, lost `spell_permissions`); copy B keeps 2 charges and its spell; the stale picker row for A is refused by `CombatCommand` and `commit_spell_resource` with action, slots and charges unchanged; JSON-text DTO, real save/load and fresh process keep A's loss and AC; dawn recovery does not revive A.
- Logic: loader refusals; three keep variants (some / none / all); non-last spend changes nothing; re-equip does not restore; lost property not a suppression/destroy target while kept one still is; all-lost copy makes Unmake-style cast refuse before slot; dict and JSON reload; forged `magical` refused; legacy state validates.

## PARTIAL
- Non-`PROPERTIES` magic (weapon +N attack/damage, "becomes a nonmagical Quarterstaff" type change, SRD p.246 staffs, e.g. Staff of Power) cannot be kept or lost yet.
- Roll-on-20 regain outcomes are not modelled.
- Projection with last-charge aftermath stays refused; native wand path not converted.
- Reaction-cast last-charge payment covered by existing 036 RS1 check only (no new live reaction scenario).

## Open questions
- Should depleted weapons/staves get a `keep_properties` vocabulary for attack/damage bonuses (needs an attack-profile consumer), or stay PARTIAL until a Staff of Power content pass?
