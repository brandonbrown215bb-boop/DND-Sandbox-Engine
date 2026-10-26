# Batch 068 build: S-196/S-210 exact container contents and attached parts

Card Q-20261025-093505-d15c. Based on `batch-067-weapon-damage-choice` (includes 7487c73), because PR #39 is still open.

## Finish line (verbatim)
"Exact container contents and attached parts (S-196/S-210): explicit selection, demonstrated with two eligible copies."

Slice row (docs/planning/vocabulary-slices.md): "Remaining small UI change: choose an exact compartment/content/attached part instead of first-fit/last-out. Reuse `AttackProfileRules`, `ContainerRules` and `AttachmentRules`. Demonstrate two eligible options and affect only the selected identity."

## Cleanup commit
29c5f8d: the batch 067 check "a miss offers no hit-window choice" now sets `crit_range` to 21 for that check, so a natural 20 can't crit or auto-hit against AC 1000. The miss is now deterministic.

## Design
See [exact contents and parts](../mechanics/exact-contents-and-parts.md).
- **Rules** (production callers are the room and vessel buttons):
  - `ContainerRules`: `stow_options`, `compartment_options`, `content_options`, `stow_into`, `take_out` (stale-refusing), `ordinal`.
  - `AttachmentRules`: `socket_options`, `part_options`, `attach_into`, `detach_part` (stale-refusing).
  - Every move revalidates through the existing `put`/`remove`/`attach`/`detach`.
- **UI:**
  - `LocalRoomView.choose_exact` is used by Stow / Take out / Attach / Detach and by vessel Stow cargo / Take out cargo.
  - The old first-fit/last-out functions remain the zero-option path, which reports the refusal reason.
- **Costs:**
  - Dismissing spends nothing.
  - A stale pick refuses before the clock advances.
  - A replayed pick is ignored (serial check), so the 6-second cost is paid once.
- **Durability:** there are no new saved fields. Contents and attachments were already saved and validated by `saved_error` in both save formats, so `InventoryCopies.record_state_error` has nothing new to save. No item effects change, so the merged/suppressed copy gate isn't involved. Legacy saves are unchanged.
- **Changed existing scenario:** `projected_vessel_flow` used to rely on last-out for Take out cargo. With two held copies the exact menu now opens, so the scenario picks the loaded copy from it.

## Validation (Godot 4.7.2, import run twice)
- Logic: **6008 passed, 0 failed**. The baseline is about 5984; the new checks are in `Batch068Checks`. No SCRIPT/Parse/Compile errors.
- Scenarios:
  - `batch_068_exact_contents_flow`: PASSED (14 assertions). It covers cancel, a stale container, a choice of the second satchel's sleeve, a replay, an exact take-out, an exact socket choice, a swapped-part stale refusal, an exact detach, and a real save/load.
  - `batch_068_exact_contents_reload` (fresh process): PASSED.
  - Related scenarios: `batch_043_container_curse_flow`, `batch_044_parts_magic_flow`, `batch_048_item_types_measurements_flow`, `projected_vessel_flow` (after the update; it passes on the base commit too) and `batch_067_weapon_damage_choice_flow`: all PASSED.

## PARTIAL
- Worn or equipped hosts and containers aren't in the room item selector, so they can't be chosen from the HUD.
- Combat-turn hosts aren't wired.
- Nested containers stay unsupported.

## Open questions
- Should worn hosts (for example an equipped circlet) be added to the room selector in a follow-up?
