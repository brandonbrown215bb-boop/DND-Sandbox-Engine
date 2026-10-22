# Batch 061 acceptance: S-157 summon turn timing (PR #33)

Reviewer: Runtime Reviewer. Card Q-20261021-151048-b151 (claimed). Reviewed head b2d4c9f, stacked on 3aef650.

Finish line (verbatim): "When a summon acts in initiative should be definable in the data (for example, right after its owner)."

## Verdict: ACCEPT after R1

## Defects
- **R1 (231acbd): an after_owner summon could lose its slot behind its owner.** join_initiative placed it with the owner's roll and DEX minus 0.01. Any later re-sort, such as an `own` summon joining or a second owner entering, fell back to roll, then DEX, then id. A combatant that tied the owner on roll and DEX, with an id sorting after the owner's, then landed between the owner and its summons. Repro: owner and a goblin both at 15/14 plus a second owner gave `[a_owner, b_owner, TieGoblin, Spider, Spider, Wasp, Wasp, Goblin]`. Fix: entries carry `follows`, and `InitiativeTracker.regroup_followers()` runs after both sorts, keeping each owner's after_owner run directly behind it. The tracker isn't saved mid-combat, so the save format is unchanged. Test: "061 review R1" in batch_061_checks. The bug dates from 056 code but blocks this finish line.

## Verified
- Timing modes: owner_turn adds no turn, after_owner sits directly behind its owner, own rolls d20+DEX. The loader refuses unknown values. Timing comes from template JSON, with no per-ID branches (ADR-0018).
- shared_policy only normalises free to none and a missing initiative to owner_turn. Each template is validated before mix_error, so an invalid command can't slip through as the default. Real cost or timing differences are still refused.
- A mid-round after_owner insert gets has_acted false and moves active_index, so it can't act twice. A mid-round own summon goes through sort_initiative_preserving_active.
- Refusal before payment: a cancelled mixed cast spends no slot (scenario). A mixed cast with mismatched timing can't load.
- Save/load: no new field. A reloaded owner rebuilds the same order, and the legacy 055 pack keeps owner_turn.
- Owner removed or dead: covered by the 056 reconcile and behaviour policies, unchanged here and not re-stressed.

## Counts
- Branch head as delivered (imported twice): logic 5595 passed, 0 failed (matches the claim).
- After R1: logic 5596 passed, 0 failed, 0 SCRIPT ERROR. Scenarios 031-061 run one at a time: 31/31 passed, no SCRIPT ERROR.

## Open decisions (Brandon)
- Should core SRD summons (Giant Insect, Summon Dragon, Animate Objects) be authored as after_owner? Today they default to owner_turn.
- Mid-round save of the live tracker: card 0ca9, still out of scope.
