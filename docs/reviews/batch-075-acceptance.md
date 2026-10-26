# Batch 075 acceptance review (S-162 linked removal) — Runtime Reviewer

Done-means (verbatim): "Linked-item removal causes (S-162): give, stow, drop, sale, destruction and projection pass through exact-copy removal. Only authored causes dispose of linked mates."

Verdict: ACCEPT after R1 (PARTIAL as declared). Reviewed 36fc7d8 on base 3155f1d.

## Defect
- R1 (eee958b): consumption paths still called `take_instance(id)` with no cause: drinking/using a consumable, ration emptied, light-source fuel, consumed spell material components (cast, reaction, room shared spell) and inventory pool payment. With `loss_causes` authored, an empty cause skips both `_settle_cause` and the legacy prune disposal, so a bond listing "destruction" kept the mate when its copy was consumed. Those sites now pass "destruction". New check `_consumption` (bonded potions, ["destruction"] disposes, ["sale"] keeps) fails without the fix.

## Verified (code + checks)
- Sale pays once: gold is paid only after `remove_exact(id, "sale")` succeeds; a double-click or replayed sell finds no copy and pays nothing. Selling a copy whose mate was disposed by that sale: the mate is gone, so its sell is a no-op. No sale state is saved, so save/load can't replay it.
- The mate is disposed once (`_settling` guard, targets filtered) and only for listed causes; an unlisted cause just releases the lost copy, and the mate record is untouched.
- Attach refuses bonded copies (`A bonded copy cannot be attached.`), so attach then detach can't strip a bond. Carried-container stow refuses bonded copies before removal; the item stays in hand.
- record_state_error: nothing new is saved (`last_disposal` is static and not persisted, `loss_causes` is rule data), so nested-record validation is unchanged.
- Legacy: absent `loss_causes` keeps dispose-on-any-loss (042 passes). Loader rejects unknown/duplicate/empty causes and causes without dispose_group. No per-ID branches.

## Tests
Logic 6210/0 (builder 6206/0, +4 review checks). Scenarios run one at a time, all PASS, no SCRIPT ERROR: batch_075_linked_removal_flow, _reload, 041, 042, 043, 044, 068 flow/reload, 072 flow/reload, projected_vessel_flow, shop, shared_spell_flow.

## Open decisions
- Remaining causeless removals: attach (bonded refused) and test/flow harness helpers. Should consumption get its own cause ("consume") instead of reusing "destruction"?
- Carried-container stow of bonded copies is refused, not supported. Card?
- Projection disposal is proven in logic only. Card a live scenario?

## Queue close (066-075)
All ten batches reviewed, all ACCEPT, six after a reviewer fix (066 push legality, 070 Extra Attack stacking, 072 drained-ring attunement, 073 temp HP on death, 074 incapacitated helpers, 075 consumption cause); 067, 068, 069, 071 clean. Every item is PARTIAL as declared. Main still carries ~70 pre-existing scenario failures, which remain the largest risk to this stack.
