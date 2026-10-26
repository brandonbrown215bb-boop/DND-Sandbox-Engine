# Linked-item removal causes (S-162)

Status: **PARTIAL** (batch 075).

Done-means: "Linked-item removal causes (S-162): give, stow, drop, sale, destruction and projection pass through exact-copy removal. Only authored causes dispose of linked mates."

## Data (ADR-0018)
- An `exclusive_bond` rule with `on_loss: "dispose_group"` may add
  `loss_causes`. This is a non-empty list with no repeats, drawn from
  `Inventory.REMOVAL_CAUSES` = `give, stow, drop, sale, destruction, projection`.
  `BondRules.rule_error` refuses unknown causes, repeats, an empty list, or
  `loss_causes` on a rule that does not dispose.
- If a rule has no `loss_causes`, it keeps its existing authored behavior: any
  loss disposes the group (batch 042). Nothing defaults a cause, and there are
  no per-ID branches. No universal D&D transfer rule is invented.
- No new saved fields. Bond state is unchanged and still validated by
  `BondRules.saved_error`. Legacy saves load unchanged.

## Rules
- `Inventory.remove_exact(instance_id, cause)` is the shared exact-copy
  removal. It refuses an unknown cause or a missing copy before anything moves.
  Destruction goes through `destroy_instance`. Every other cause goes through
  `take_instance(id, cause)`, which keeps the existing curse and leave checks.
  Then `BondRules.on_copy_removed(actor, ids, cause)` runs.
- `BondRules._settle_cause` disposes the lost copy's non-projected mates only
  when the rule lists that cause. The `last_disposal` receipt records the
  cause, the lost copies, the disposed copies and the kept copies. `prune`
  then releases bonds on copies that are no longer held. It skips legacy
  disposal for rules that have `loss_causes`.
- Callers and their causes:
  - `transfer_instance`: give
  - shop Sell: sale
  - room Place: drop
  - `drop_equipped_instances`: drop
  - room-container Put: stow
  - `ContainerRules.put`: stow
  - `ItemProjectionRules.project`: projection
  - `destroy_instance`: destruction
  - consumables, fuel, components, resource payments: destruction (no dedicated `consume` cause yet; deferred until content needs it)

## PARTIAL
- A bonded copy still cannot be stowed in a carried container (the 068 refusal
  is unchanged). Stow is proven through the room-container Put.
- Consumption (consumables, fuel, spell components and resource payments)
  currently passes cause `destruction` (review commit eee958b). Brandon:
  "treating consumption as destruction is fine for now; don't add a consume
  cause until content needs it." A dedicated `consume` cause is deferred until
  content needs it (Batch 083).
- Attach still removes copies with no cause (bonded copies are refused). With
  `loss_causes` authored, it never disposes mates. Legacy rules still dispose
  on any loss.
- Give, Place and Sell have no confirm step. The only way to cancel is to
  dismiss the menu, and a stale choice is refused when it is pressed.
- Real content must pin its intended trigger clauses before it is converted.
  Only fixtures author `loss_causes` today.
