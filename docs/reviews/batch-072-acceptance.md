# Batch 072 acceptance review (S-060/S-203 last-charge property loss)

Reviewer: Runtime Reviewer. PR #44, reviewed head 804de08. Card Q-20261025-113734-469f claimed.

Finish line (verbatim): "Last-charge property loss (S-060/S-203): keep_properties controls actual behavior, across independent copies and reload."

## Verdict
ACCEPT after one fix (1abd648). Finish line met for the declared scope; PARTIAL items as stated by the builder.

## Fixture finding (b036_spent_rod keep ["light"] -> [])
Not a weakening. "light" was never a tracked property, so 036 only proved a string echoed into the receipt. The non-empty keep path is now proven with real behavior in 072 (ember keeps source_benefits and loses spell_permissions; keeper keeps both; loader refuses 'light'). 036 still proves degrade, same copy, nonmagical, no recovery. No restore needed. Nit: the 036 check label still says "with declared properties".

## Defect fixed
- R1 (1abd648): a copy whose last charge ended all magic (degraded, magical=false) could still be attuned and take an attunement slot. Inventory.attune_instance now refuses it. Checks: refused on the degraded copy; a sibling copy of the same id still attunes; a second spend on the empty copy never rolls or re-settles.

## Verified
- Order: settle runs only after a real spend takes charges >0 to 0; refused spends do not roll/degrade (072 + 072R checks).
- Loss is read per exact copy via MagicPropertyRules.active/_affected; other copies unaffected; save/load (both forms) keeps the loss; forged magical flag refused; recovery skipped.
- record_state_error: LastChargeRules.saved_state_error is called per record; nested/contained records go through the same function.
- Legacy: the 036-shape degraded state validates. Caveat: a legacy save with magical=false for an item whose data now keeps a property would be refused; no shipped content declares last_charge_aftermath, so no real save is affected.
- No per-ID branches added (the pre-existing ring_of_protection branch in attune_instance is not from this PR).
- SRD 5.2.1 (from memory, no PDF): wands such as Wand of Magic Missiles roll a d20 when the last charge is spent; on a 1 the wand crumbles to ash. The data-driven roll+destroy/degrade fits.

## Tests
Imports x2 clean. Logic 6136 passed / 0 failed (builder 6133 + 3 review checks). Scenarios one at a time: batch_072_last_charge_flow, _reload, batch_036_end_and_charge_flow, batch_044_parts_magic_flow, batch_048_item_types_measurements_flow, batch_063_magic_action_cost_flow all pass, 0 SCRIPT ERROR. No regressions against the batch-066 main failure list.

## Open decisions for Brandon
1. Should an existing attunement end when the last charge removes all magic? Today it stays (it grants nothing), occupying a slot until the player ends it.
2. Weapon +N loss on depletion, regain-on-20, projection and the native wand path: cards?
3. Legacy caveat above: accept, or migrate magical=false to match data on load?
