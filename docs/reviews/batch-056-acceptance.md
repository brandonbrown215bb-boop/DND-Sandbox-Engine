# Batch 056 acceptance (S-157/S-158) — Runtime Reviewer

Verdict: **accept** after review fix R1. Card Q-20261021-053147-dc76.

## Runs (fresh worktree, imported twice)
- Logic at ef29753: 5540 passed, 0 failed (matches builder). After R1: **5541 passed, 0 failed**, 0 SCRIPT ERROR.
- Scenarios 031-056, one at a time: **26/26 passed**, 0 SCRIPT ERROR in any log; 056 shows 10 [ok].

## Defects
- **R1 (82cea4b)**: `join_initiative` anchored an `after_owner` actor behind *any* earlier actor of the same owner, including an `own`-initiative actor rolled far down the order, so a hound could act after the goblin instead of right after its owner. Now it only extends through a contiguous `after_owner` run. New check fails on ef29753 (order `owner, Goblin, Sprite 1, Hound 1, Hound 2`) and passes after.

## Break attempts (pass)
- Multiple summons from one owner: stable order (insertion after the contiguous run).
- Mid-round creation: `after_owner` inserted after the active owner acts next; `own` sorted with the active combatant preserved, acting this round only if its roll is still ahead.
- Removal during own/owner turn: `reconcile` runs before `next_turn`; tracker index correction verified for removal before/at/after the active entry.
- Dead owner then revived: `behaviour` is read from the owner's current state each turn, so control returns on revival/stabilization (and stabilized-but-0-HP still counts as incapacitated).
- Refusal before cost: unconscious/dead owner's command refused, nothing spent.
- No per-ID branches; legacy saves: record shape unchanged, `saved_record_error` passes; orders transient.

## SRD 5.2.1
- Summon spells (e.g. Giant Insect): "shares your Initiative count, but it takes its turn immediately after yours ... If you don't issue any, it takes the Dodge action" — matches `after_owner` + default dodge.
- The SRD has no general owner-incapacitated rule for summons; behaviour is spell-declared, as built. Incapacitated ends Concentration, so concentration summons leave (build doc's limit is SRD-correct).
- No page citations in this batch to verify.

## Limits / decisions for Brandon
- Mid-round save/load: combat tracker is not persisted (pre-existing), so mid-round order is rebuilt on load, not resumed.
- Default `initiative` is `owner_turn` (055 behaviour). SRD summons use "immediately after yours"; should authored SRD summons default to `after_owner`?
- An `after_owner` actor whose owner is no longer on the tracker never gets a turn.
- Concentration end supports only `end`.
- Finish line: not quoted in the PR body or card; judged against the S-157/S-158 rows.
