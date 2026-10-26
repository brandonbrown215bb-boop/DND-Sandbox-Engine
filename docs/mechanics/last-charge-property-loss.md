# Last-charge property loss (S-060/S-203; PARTIAL)

Done means: "Last-charge property loss (S-060/S-203): keep_properties controls actual behavior, across independent copies and reload."

SRD 5.2.1 authority: Ring of Three Wishes (p.239, "becomes nonmagical when you use the last charge"); Staff of Power (p.246, on a 1 it "retains its +2 bonus ... but loses all other properties").

## Data
`last_charge_aftermath: {"outcome": "degrade", "keep_properties": [...]}` on an item with `maximum_charges`.
- `keep_properties` names `MagicPropertyRules.PROPERTIES` entries (`source_benefits`, `spell_permissions`, `incoming_negation_rule`, `attachment_sets`, `item_effects`, `features`, `weapon_bonus`). The loader refuses any other name, a property the definition lacks, and `keep_properties` on a `destroy` outcome.
- No engine default chooses what survives. Batch 080: `degrade` must state `keep_properties` (absent is refused at load).
- Batch 080 outcomes: `destroy`, `degrade` (with `keep_properties`), `nonmagical` (every magical property ends and the copy is no longer magical; same copy, same mundane definition; `keep_properties` refused). Any other outcome, unknown keys, or a conversion key (`becomes`, `convert_to`, `becomes_item`, `transform`) is refused with a reason naming it.
- Batch 080: `weapon_bonus: {"attack": N, "damage": N}` (0..3, magic weapons only) is a `MagicPropertyRules.PROPERTIES` entry read by `CombatAction.resolve_weapon_attack` from the exact equipped copy through `MagicPropertyRules.active` (last-charge loss, S-203 suppression/destruction) and attunement.
- Zero charges alone never remove anything: loss is read only from a settled aftermath (`state.degraded`).
- Mundane fields (type, damage, armor, weight, value, identity) are never touched by degrade.

## Runtime
- `LastChargeRules.settle` (called by `Inventory.spend_instance_charges`, the shared item-charge payment boundary) degrades only the exact copy that went from >0 to 0 charges, once. Receipt lists `kept_properties` and `lost_properties`; `state.magical` is true only if a kept magical property remains.
- `LastChargeRules.lost(record, property)` is read by `MagicPropertyRules.active` and `_affected`, so every existing property consumer obeys it with no per-ID branch: spell permissions (`SpellPermissionRules`), source benefits and attachment sets (`SourceBenefitRules`), incoming negation (`CastInterruptionRules`), item effects (`Inventory.has_equipped_attuned_item`), owned features (`OwnedFeatureSources`).
- Kept properties remain subject to merged-copy and S-203 suppression gates; lost properties are not suppression/destruction targets (an all-lost copy refuses Unmake-style casts before the slot is spent).
- Degraded copies do not recover charges at dawn.

## Persistence
No new saved fields: loss is derived from `state.degraded` plus the definition. `InventoryCopies.record_state_error` → `LastChargeRules.saved_state_error` requires `degraded == true`, `charges == 0`, and `magical` equal to "any kept property". Legacy 036-shape degraded records keep loading. Proven in dict and JSON-text DTOs, real save/load, and a fresh process (`batch_072_last_charge_reload`).

## Items (SRD 5.2.1 p.246)
- Staff of Power: +2 weapon bonus, +2 AC (source_benefits), 20 charges; last charge d20 on 1 → `degrade` keeping `["weapon_bonus"]` ("retains its +2 bonus to attack rolls and damage rolls but loses all other properties").
- Staff of Striking: +3 weapon bonus, 10 charges; last charge d20 on 1 → `nonmagical` ("becomes a nonmagical Quarterstaff").
- Both declare `legacy_charge_state: "full"`: a copy saved before they had charges loads with full charges; items without the declaration still refuse a missing charge state. This initialization also reaches contained/attached copies and room pickups. Existing charge values, including zero, are never replaced.

## PARTIAL
- Staff of Power's +2 to saving throws and spell attack rolls, its spells, Retributive Strike and the roll-on-20 regain are not modelled; Staff of Striking's per-hit charge spend (1d6 Force per charge) is not modelled, so in play their charges are spent only through the shared payment boundary.
- Dawn recovery is a uniform roll between the declared minimum and maximum (6–20, 5–10), not 2d8+4 / 1d6+4.
- With two equipped copies of the same weapon definition, the attack reads the main-hand copy first.
- An existing attunement on a copy that becomes nonmagical is not ended (new attunement is refused).
- Roll-on-20 regains (Staff of Power) and non-`degrade` multi-outcome tables are not modelled.
- Projection with last-charge aftermath remains refused (unchanged).
- The native wand cast path is preserved unchanged; it is not yet converted.
