# Batch 044 acceptance review: S-210 / S-203

Reviewer: Runtime Reviewer. Reviewed head f694646 on 043 @ 512945a.

## Verdict
**Accept with review fixes R1 to R3.** These fixes are committed on top of the builder head.

## Findings and fixes
- **R1 (defect): refusal came after cost.** `suppress_item_magic` refused with "No equipped copy has those magical properties" only after `SpellResolver` had spent the slot. This is the same class as 040 R1.
  - Fix: `MagicPropertyRules.cast_error` now runs inside `ActorProjectionRules.cast_error`. That covers both the resolver's pre-cost check and the HUD validation.
  - The builder check now also asserts the slot is kept. Covered by RS1.
- **R2 (defect, weak spot 2): Ring of Protection couldn't be suppressed.** The SRD 5.2.1 Ring of Protection carries its +1 AC and +1 saving throws as an authored `effects` list. That list is read through the bespoke `magic_item_saving_bonus` / `has_equipped_attuned_item` path. Neither the AC nor the save bonus was nameable or suppressible.
  - The finish line says "Suppress or destroy only specified magical properties … unsuppression restores still-owned eligible effects". A real catalog magic item that can't be specified at all misses it. The builder's partial-suppression picture came from the fixture ring.
  - Fix: a new property `item_effects` names a magical item's `effects` list. `has_equipped_attuned_item` now skips suppressed or destroyed copies, so the ring's AC and save bonus drop and return together. Covered by RS2.
  - The ring's `effects` list has no other consumer: `vision_bonus` is racial, and `skill_bonus` belongs to mundane tools.
- **R3 (defect): per-copy state wasn't validated for parts.** This is the same class as 043 R1.
  - `AttachmentRules.saved_error` didn't run per-copy state validation on attached parts, so a part with charges -5 loaded.
  - `destroyed_magic` was validated only on top-level records, so bogus destroyed magic on a contained or attached copy loaded.
  - Fix: `MagicPropertyRules.record_error` is now part of `InventoryCopies.record_state_error`, which runs for carried, contained and (now) attached copies. Covered by RS3 and RS4.

## Weak spots
1. **Self-cast on own worn copies only, no Dispel: known limit.** The S-203 finish line covers what is suppressed and destroyed, and how restoration works. It doesn't require a targeted, area or antimagic host. Dispel Magic interaction belongs to the spell side, not to this slice.
2. **Ring of Protection:** a defect, fixed as R2.
3. **Detach while carried: no defect.**
   - Core `detach` accepts carried or worn hosts. Only the HUD button targets carried hosts. RS7 detaches from a worn host and only that set is disabled.
   - A host with parts can't be stowed. Attuned parts can't be attached, and saves refuse `attuned_to` on parts, so 043 R2 attunement counting can't be bypassed.
   - Stowed copies are not worn and are never suppressed. RS5 shows the stowed attuned copy still counts toward the limit.
4. **Fixture-only values: confirmed clean.** No `attachments`, `suppress_item_magic` or `destroyed_magic` appears in `data/core`. The diff adds only loader validation.

## Interaction checks
- **041 merged form (RS6):** a live suppression and a merged form layer correctly. When the form ends, the suppressed benefit stays off. When the suppression ends, it comes back.
- **043 containers (RS4, RS5):** contained copies validate their destroyed magic, and stowed attunement counting is unchanged.
- **Legacy saves (RS8):** a save without parts or suppression validates.

## N1
- Baseline at the builder head: 5252 / 0, which is 5223 + 29.
- After review: 5261 / 0, which is 5252 plus the 9 RS1–RS8 checks (RS3 has two).
