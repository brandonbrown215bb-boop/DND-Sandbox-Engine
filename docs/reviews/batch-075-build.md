# Batch 075 build: S-162 linked-item removal causes

Done-means: "Linked-item removal causes (S-162): give, stow, drop, sale, destruction and projection pass through exact-copy removal. Only authored causes dispose of linked mates."

Status: PARTIAL. See [contract](../mechanics/linked-removal-causes.md).

## Changes
- `Inventory.REMOVAL_CAUSES` and `Inventory.remove_exact(instance_id, cause)`.
  This is the shared exact-copy removal. It refuses an unknown cause or a
  missing copy before anything moves. `take_instance` carries an optional
  cause. `destroy_instance` reports `destruction`, and
  `drop_equipped_instances` reports `drop`.
- Callers:
  - `transfer_instance`: give
  - shop Sell: sale
  - room Place: drop
  - room-container Put: stow
  - `ContainerRules.put`: stow
  - `ItemProjectionRules.project`: projection
- `BondRules`:
  - Rules can author `loss_causes` (validated: requires dispose_group, a known
    non-empty list, no repeats).
  - `on_copy_removed(actor, ids, cause)` passes the cause to `_settle_cause`.
    Only authored causes dispose the lost copy's non-projected mates. The
    receipt names the cause.
  - `prune` keeps the legacy any-loss disposal only for rules without
    `loss_causes`, which retains the existing authored behavior.
- Fixture: data/fixtures/batch_075. It has two dispose_group pairs that author
  `sale`, `destruction` and `projection`.

## Evidence (Godot 4.7.2, headless)
- Import ×2: no SCRIPT, Parse or Compile errors.
- Logic suite: 6206 passed, 0 failed (batch 074 baseline 6177). Batch075Checks covers:
  - 5 invalid `loss_causes` mutations refused; 042 rules still validate.
  - All 6 causes, authored and not authored, each removing exactly one copy of
    two identical linked pairs plus an unlinked copy. The other pair and the
    unlinked copy are never touched. The receipt names the cause.
  - An internal removal with no cause disposes nothing. A legacy 042 give
    still disposes.
  - Refusals with nothing moved or disposed: unknown cause, missing copy, a
    copy that cannot leave (a cursed sale), and the unchanged 068 refusal to
    stow a bonded copy in a carried container.
  - Dict and JSON round-trips (give keeps the mate; destruction disposes
    exactly its own mate).
- Scenarios (real controls):
  - `batch_075_linked_removal_flow` PASS:
    - Give to Alice after walking adjacent, Place, and Put into an open room
      container. Each moves only the exact copy and keeps its mate.
    - Real save/load.
    - Shop Sell pays once (0 → 1) and disposes exactly the authored mate.
    - A stale Sell (the copy was given away first) pays nothing and disposes
      nothing. A replayed Sell pays once.
  - `batch_075_linked_removal_reload` PASS: in a fresh process, the pairs load,
    a give keeps the mate, and destruction disposes exactly its own mate.
- Regression scenarios PASS, all with no failures and no script errors:
  - batch_041_bond_equipment_flow
  - batch_042_linked_projection_flow
  - batch_043_container_curse_flow
  - batch_044_parts_magic_flow
  - batch_068_exact_contents_flow and its reload
  - batch_072_last_charge_flow and its reload
  - projected_vessel_flow
  - shop
- Projection is proven in logic with the 042 figurine, authored and not
  authored.

## Notes / open questions
- Cancellation: Give, Place and Sell have no confirm step. The only way to
  cancel is to dismiss the menu. A stale choice is refused at the press, with
  no payment and no disposal.
- PARTIAL:
  - Carried-container stow of a bonded copy is still refused (068).
  - Attach, component consumption and fuel use carry no cause. With
    `loss_causes` authored they never dispose mates; legacy rules still
    dispose on any loss.
  - Real content must pin its trigger clauses before conversion.
- Test hygiene: features share the loaded class records, so the checks author
  private copies.
