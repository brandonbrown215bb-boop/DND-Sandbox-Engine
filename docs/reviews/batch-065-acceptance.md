# Batch 065 acceptance: data reaction triggers (PR #37)

Reviewer: Runtime Reviewer. Card Q-20261021-172804-829a (claimed until 2026-10-22 12:35 CDT). Reviewed head 944679a, stacked on aca5a70.

Finish line (verbatim): Brandon: "If something costs a reaction like 'Hellish Rebuke', then it should be able to happen on a defined trigger from the data." Plus: no engine default trigger; include the costed on-hit mode switch.

## Verdict: ACCEPT after R1

## R1 (fixed in 909e8c3)
- A spell record that declared `_reaction_trigger_paid: true` itself skipped validate_spell_target's "resolves only through its reaction boundary" guard: payment rows copy catalog fields, so an ordinary cast was allowed. Fixed twice: the loader refuses the key on spells, and the guard ignores the flag when the catalog record carries it. Test added.

## Builder's asks
1. `_reaction_trigger_paid`: set only by ReactionTriggers.confirm on the transient payment row after the slot and the Reaction are paid. The catalog record and fresh payment rows stay unflagged (tested), so it can't persist past one resolve. Refusals return before it is set. It is never saved. The data hole above was the only way to pre-set it.
2. shared_spell accepting reaction_trigger instead of a cancellation rule: only for casting_time reaction (spell_trigger_error refuses it otherwise). Other spells' validation is unchanged.
3. Timing: SRD 5.2.1 (checked from memory; no PDF on the box) has Shield fire when you're hit, and its +5 AC applies to the triggering attack, so it can turn the hit into a miss. Hellish Rebuke fires after you take damage. on_damaged_by_creature after the attack settles is correct. on_hit_by_attack after it settles **can't** change the outcome, so it can't express Shield. Shield keeps its own pre-roll path, so nothing is broken today, but the event is misleading for authors. Either fire it before damage with an AC/outcome hook, or rename and document it as "after being hit". Brandon's call.
4. hellish_rebuke: only the trigger was added. It is still not a supported SpellSupport slice, so it gets no permission and no offer. That's harmless, but the real spell doesn't meet the finish line until it's castable (PARTIAL for real content; the fixture proves the path).

## Verified
- Refuse before cost: no Reaction, out of range, unseen, Incapacitated, a cancelled prompt or payment, and a stale or closed event spend no slot and no Reaction. A reactor dropped mid-chain (is_alive false) gets no offer and a pending answer spends nothing (review test). The reactor can't be the attacker: the only sources are a monster attacking a player, and a player's own hit for on_hit_with_attack.
- The slot and the Reaction are paid once, on confirmation only. A second answer is stale. resolve uses deduct_slot false.
- Several reactors: only the target is a reactor, and the first confirmed offer closes the event.
- ADR-0018: no per-ID branches. Legacy: no saved field, and 057 Rush still validates.
- Note: on_damaged_by_creature checks raw result.damage > 0, not the resolved damage (immunity or temp HP). Minor.

## Counts
- Logic: 5652 passed, 0 failed (5649 claimed + 3 review), 0 SCRIPT ERROR. Scenarios 031-065 one at a time: 35/35, 0 SCRIPT ERROR.

## Open decisions (Brandon)
- on_hit_by_attack: make it outcome-changing (Shield-style) or rename it to after-hit?
- Make Hellish Rebuke a supported cast slice so real warlocks are offered it?
- Should spell attacks, Extra Attack swings, opportunity attacks and area damage fire triggers?
