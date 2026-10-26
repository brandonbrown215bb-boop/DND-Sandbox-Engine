# Batch 080 build — S-060/S-203 per-item last-charge outcomes (#44 follow-up)

Card: `Q-20261025-224316-c882`. Stacked on `batch-079-max-hp-stacking` (PR #52, incl. reviewer commit 33b5a41).

Brandon's ruling (verbatim): "follow each item's text; there's no universal keep/lose rule. Staff of Power keeps its +2 weapon bonus after its last-charge failure; Staff of Striking can become nonmagical (SRD p.246). Reaching zero charges doesn't universally erase bonuses. Keep unsupported item conversions blocked until those distinctions work."

Done means: each depleting item follows its own authored text from data (ADR-0018: no per-ID branches, no engine defaults); Staff of Power keeps +2 after its failure, Staff of Striking becomes nonmagical; zero charges alone removes nothing; conversions are refused; legacy saves load.

## What changed
- `MagicPropertyRules.PROPERTIES` gains `weapon_bonus` (`{"attack","damage"}`, 0..3, magic weapons only). `weapon_copy_bonus` reads the exact equipped copy through the shared `active()` gate (S-203 suppression/destruction + last-charge loss) and the attunement gate. `CombatAction.resolve_weapon_attack` adds a "Weapon bonus" attack and damage modifier; a nonmagical copy attacks as nonmagical (unless Magic Weapon applies).
- `LastChargeRules`: outcomes `destroy` / `degrade` / `nonmagical`. `degrade` must state `keep_properties` (no default). `nonmagical` loses every property, marks the copy `magical: false`, refuses `keep_properties`. Unknown outcomes, unknown keys and conversion keys (`becomes`, `convert_to`, `becomes_item`, `transform`) are refused with named reasons.
- Data (SRD 5.2.1 p.246): Staff of Power (+2, AC +2, 20 charges, d20=1 → degrade keeping `weapon_bonus`); Staff of Striking (+3, 10 charges, d20=1 → nonmagical).
- Legacy saves: items declare `legacy_charge_state: "full"`; a saved copy without charges restores full. Items without the declaration still refuse (per-copy state via `InventoryCopies.record_state_error`).

## Verification (Godot 4.7.2, imported twice, sequential runs)
- Logic suite: 6295 passed, 0 failed. 0 SCRIPT/Parse/Compile errors in any log.
- Scenarios (exit 0): batch_080_last_charge_text_flow, batch_080_last_charge_text_reload (fresh process), batch_072_last_charge_flow, batch_072_last_charge_reload, wand_last_charge_destruction_flow.

## PARTIAL
- Staff of Power: +2 saves/spell attacks, spells, Retributive Strike, roll-on-20 regain not modelled. Staff of Striking: per-hit charge spend not modelled. Charges are spent only through the shared payment boundary in tests.
- Dawn recovery uniform between min/max, not 2d8+4 / 1d6+4.
- Existing attunement is not ended when a copy becomes nonmagical (new attunement refused).
- Two equipped copies of one definition: main-hand copy read first.
- Projection of items with an aftermath remains refused.
