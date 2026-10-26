# Last-charge property loss (S-060/S-203; PARTIAL)

Done means: "Last-charge property loss (S-060/S-203): keep_properties controls actual behavior, across independent copies and reload."

SRD 5.2.1 authority: Ring of Three Wishes (p.239, "becomes nonmagical when you use the last charge"); Staff of Power (p.246, on a 1 it "retains its +2 bonus ... but loses all other properties").

## Data
`last_charge_aftermath: {"outcome": "degrade", "keep_properties": [...]}` on an item with `maximum_charges`.
- `keep_properties` names `MagicPropertyRules.PROPERTIES` entries (`source_benefits`, `spell_permissions`, `incoming_negation_rule`, `attachment_sets`, `item_effects`, `features`). The loader refuses any other name, a property the definition lacks, and `keep_properties` on a `destroy` outcome.
- No engine default chooses what survives: absent `keep_properties` means nothing magical survives, exactly as authored `[]`.
- Mundane fields (type, damage, armor, weight, value, identity) are never touched by degrade.

## Runtime
- `LastChargeRules.settle` (called by `Inventory.spend_instance_charges`, the shared item-charge payment boundary) degrades only the exact copy that went from >0 to 0 charges, once. Receipt lists `kept_properties` and `lost_properties`; `state.magical` is true only if a kept magical property remains.
- `LastChargeRules.lost(record, property)` is read by `MagicPropertyRules.active` and `_affected`, so every existing property consumer obeys it with no per-ID branch: spell permissions (`SpellPermissionRules`), source benefits and attachment sets (`SourceBenefitRules`), incoming negation (`CastInterruptionRules`), item effects (`Inventory.has_equipped_attuned_item`), owned features (`OwnedFeatureSources`).
- Kept properties remain subject to merged-copy and S-203 suppression gates; lost properties are not suppression/destruction targets (an all-lost copy refuses Unmake-style casts before the slot is spent).
- Degraded copies do not recover charges at dawn.

## Persistence
No new saved fields: loss is derived from `state.degraded` plus the definition. `InventoryCopies.record_state_error` → `LastChargeRules.saved_state_error` requires `degraded == true`, `charges == 0`, and `magical` equal to "any kept property". Legacy 036-shape degraded records keep loading. Proven in dict and JSON-text DTOs, real save/load, and a fresh process (`batch_072_last_charge_reload`).

## PARTIAL
- `keep_properties` cannot name non-`PROPERTIES` magic such as a weapon's +N attack/damage bonus (Staff of Power) or a "becomes a nonmagical Quarterstaff" type change; those still need their own consumers.
- Roll-on-20 regains (Staff of Power) and non-`degrade` multi-outcome tables are not modelled.
- Projection with last-charge aftermath remains refused (unchanged).
- The native wand cast path is preserved unchanged; it is not yet converted.
