# Batch 048 acceptance review (card Q-20261020-175109-7d43, PR #17)

**Verdict: ACCEPT after R1 (citation fix only). No runtime defects found.**

Reviewed head 1832305 (stacked on batch-047-hud-chooser 2342264) in my own worktree /tmp/rev_wt048.

## Evidence (Godot 4.7.2, runs strictly one at a time)
- `--headless --import` clean. Logic suite: **5385 passed, 0 failed**. The baseline was 5367, so the +18 matches the 18 `check.call` lines in batch_048_checks.gd. 0 SCRIPT ERROR in boot_gate, parse_gate and logic logs.
- Scenarios 031-048 all print SCENARIO PASSED with 0 SCRIPT ERROR. [ok] counts: 031 25, 032 33, 033 70, 034 10, 035 9, 036 7, 037 11, 038 7, 039 10, 040 12, 041 10, 042 10, 043 11, 044 12, 045 16, 046 16, 047 10, 048 8. 031-047 are unchanged from the 047 acceptance.
- The catalog loads 289 items with 0 load errors, unchanged.

## SRD 5.2.1 verification (checked against the SRD 5.2.1 PDF; printed page numbers equal PDF page numbers)
- Every weight figure is correct: all 19 Adventuring Gear items, the 5 arcane foci, the wooden staff, and the 10 instrument variants. The waterskin's 5 lb. is the table's "(full)" value. The Bell, Antitoxin and Basic Poison show "—" in the table and correctly stay unknown. The backpack text reads "holds up to 30 pounds within 1 cubic foot".
- **R1 (ff63f91): every page citation was off by one.** The correct pages are: Adventuring Gear table p.95 (cited p.94), Arcane Focuses p.96 (cited p.95), Druidic Focuses p.97 (cited p.96), Musical Instrument variants p.94 (cited p.93), and the Backpack entry p.96 (cited p.95). I corrected the comment and message in batch_048_checks.gd and the table in batch-048-build.md. No values changed.

## Rule checks
- **ADR-0018:** no per-ID branches. Behaviour is keyed on type (`HELD_TYPES`) and on the data field `worn_slot`.
- **Loader stress** (probe run against `_validate_content`):
  - Refused: weights of -1, "5", true or 1e9; volume -0.1; type "Wondrous" (wrong case); a staff with a worn_slot; a wondrous item with a null worn_slot; an item with no type.
  - Accepted: weight 0 (a known zero), and a wondrous item that needs attunement but has no slot (carried).
- **Legacy:** existing items with no weight still load and stay unknown. A legacy backpack record without `state.contents` validates (logic check). A real save/load round trip is in scenario 048.
- **Containers:** an unknown-weight child is refused before it can enter a weight-limited compartment, both in `put` and in saved validation (`saved_error`, then `record_state_error` per child, then `_fits`). The `existing` loop's default of 0.0 therefore can't be hit by real data. An over-limit or unmeasurable stow is refused with no `seconds` and nothing moved; the scenario asserts the clock didn't advance.
- **041-044 rules:** attunement and source_benefits use the existing equipped-copy paths, and the boots apply only while worn and attuned. Bond and attachment `item_types` filters are generic string checks, so they need no change. Suppression and spell permissions aren't type-gated.
- **Encumbrance:** the engine has no carrying-capacity system, so weight gates only container compartments. Nothing else needs a refusal-before-cost check.

## Known limits / decisions for Brandon
1. **Backpack volume (1 cu ft) is not enforced.** The SRD gives no item volumes, so enforcing it would refuse everything. The builder documented this; I agree.
2. **Staff, rod and wand all take one hand from `available_spellcasting_hands`.** This matches the existing wand behaviour, but the SRD lets a focus hand perform Somatic components. That's a pre-existing simplification, not a regression.
3. **Core magic staffs stay `weapon`, SRD foci stay `tool`, and the 042 figurines stay `tool`,** as the card scopes. They need a later migration slice.
4. **`local_room_rules.gd:1221` still defaults an unknown weight to 1 lb.** for dropped loose objects. This is pre-existing and inconsistent with "unknown stays unknown"; it's worth a card.
5. **Worn slots are only head and feet.** SRD wondrous items worn at the neck, shoulders, waist and so on can't be worn yet.

## Proposed updates on accept
- Card 7d43 to done.
- Registry/checklist: mark F3 (042 review) resolved.
- Checkpoint/roadmap: logic total 5385; scenario list + `batch_048_item_types_measurements_flow`.
