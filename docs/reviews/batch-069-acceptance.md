# Batch 069 acceptance: S-032/S-196 unknown item measurements (PR #41)

Reviewer: Runtime Reviewer. Card Q-20261020-230919-ac39 (claimed until 2026-10-26 05:18 CDT). Reviewed head 685392c, stacked on #40 (6696880).

Finish line (verbatim): "Unknown-weight room placement (S-032/S-196): stop treating missing measurements as known. Volume stays partial."

## Verdict: ACCEPT, no defects. S-032/S-196 PARTIAL as declared (volume, room container count default 20, no carry totals).

## Verified
- Stamp clearing can't erase real data: it fires only on a `placed:` copy carrying the exact mixed/Tiny/item-weight-else-1 triple, and only drops keys absent from the current item data. Data weight 0 or 1 (e.g. tinderbox) is kept; data matching the stamp exactly (030_iron_pebble) keeps all three; authored objects are untouched; migration is idempotent. Review tests added.
- Data changed between versions: if the saved weight no longer matches current data, nothing is cleared (conservative; the old mixed/Tiny text stays). Acceptable.
- Legacy saves in weight-limited compartments: `_fits` reads item data, not room stamps, so stamp migration can't break a stored compartment. An occupant with no data weight could only exist if data dropped `weight` after it was stowed; that save was already refused before this PR (the item's own check). Not a regression; the message "exceed their compartment" is misleading in that case.
- Take out never calls `_fits`, so unknown-weight items can always come out.
- Unknown never reads 0: Inspect/describe show "unknown weight/material/size"; PhysicalFactsRules returns null/"" for unknowns; combat projection uses known_fields. No carry totals exist yet, so nothing to show 0.
- Refusal before cost: container refusals return before any move; Inspect costs 0 s.
- record_state_error: physical facts validated (non-negative finite weight or absent; non-empty text or absent).
- No per-ID branches.

## Tests
- Import x2 clean. Logic: 6041 passed, 0 failed (6033 builder + 8 review), 0 SCRIPT ERROR.
- Scenarios run alone, pass, 0 SCRIPT ERROR: batch_069_unknown_weight_flow/_reload, batch_043_container_curse_flow, batch_044_parts_magic_flow, batch_048_item_types_measurements_flow, batch_068_exact_contents_flow/_reload, projected_vessel_flow, save_load.
- Failing: failed_save_numeric_bonus_flow, s029_save_context_flow; both on the main failure list in batch-066-acceptance.md. No regressions.

## Open
- Mismatched legacy stamps (data changed since save) keep mixed/Tiny text.
- Volume, room container default 20, encumbrance stay PARTIAL.
