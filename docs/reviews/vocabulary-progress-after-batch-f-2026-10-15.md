# Vocabulary progress after Batch F

Review date: 2026-10-15. Scope: the current working tree, accepted Batch E/F
behavior, the remaining slice plan, and delivery overhead. This is an assessment
and a set of recommendations, not a replacement execution queue or new acceptance.

The direction is working. There is real reuse across the new mechanics, and
independent review has found consequential bugs. The delivery plan now needs
less fragmentation and repeated status text. Keep the behavioral checks; combine
work that only makes sense when its whole lifecycle works.

## Findings

**No new gameplay defect was confirmed within the accepted E/F boundaries.**
Rook inspected the plan, current source and retained production evidence; one
independent reviewer inspected shared combat and persistence. This is not full
game certification. E/F remain accepted with their documented limitations.

**The prompt pack had contradictory readiness and arithmetic.** Its introduction
still said S-041 BUILD was next, while the checkpoint and board correctly said
S-038 after Batch F. Its arithmetic also counted an already accepted pack entry
again. Corrected the introduction, historical prerequisite pointer and forecast:
17 of the pack's 26 slices are accepted, nine remain, and accepting those nine
would reach 53/226. Corrected the roadmap's leftover 41/226 sentence to 44/226.
The existing numbered prompts remain; their completed instructions are historical.

**The plan is structurally consistent, but its units are not independent tasks.**
A read-only Python reconciliation found 226 unique S-IDs, 44 accepted and 182
remaining, with no missing prerequisite IDs or prerequisite cycles. Fifteen
remaining rows have their listed prerequisites accepted; the selected queue still
chooses S-038. These checks establish document consistency, not gameplay.
Neither 44/226 nor phase totals measure percentage of the game completed or
remaining effort. Later forms/world behavior is substantially different work from
adding a formula leaf. Existing native damage/casting behavior also does not
disappear because its shared-runtime phase has zero accepted rows.

## What is going as intended

- Spell parameters and source-pool capacity/die progression use the same
  [actor formula evaluator](../../src/combat/shared_step_executor.gd) and
  [pool rules](../../src/characters/resource_pool_rules.gd). Batch F did not
  introduce another class progression interpreter for these formulas.
- Reducers and grouped hit/save gates read the existing ordered step receipts.
  They retain the existing cast/continuation owners. The group barrier waits for
  final children rather than treating a suspended provisional result as settled.
- Damage history records settled quantities through the damage owner. Campaign
  history and encounter history have different lifetimes; separate storage is
  justified. Combining those stores would make save/turn semantics less clear.
- Class allocations and recent history extend existing player/party load
  preflight. Fresh-process recovery checks cover exact spent pools and history
  expiry rather than relying on serializing a dictionary in one process.
- Review is paying for itself. E fixed repeated cast-source identity, valid
  zero-damage outcomes rejected by reducers, invented owner-turn boundaries and
  monster intent recorded before execution. F fixed declaration-order-dependent
  capture and unavailable live parameters spending a slot/action before refusal.
  Those are observable defects, not style cleanup.

## Consolidate these deliveries

Keep the S-IDs and their individual acceptance clauses for traceability. The
following pairs are candidates for one coherent implementation/validation task,
not permission to silently close both after proving only one. Reconcile the
denominator explicitly only if the owner later chooses actual registry merges.

| Existing slices | Suggested delivery | Checks that must remain distinct |
|---|---|---|
| S-049 + S-050 | Exact source carriers through their real acquisition/removal controls. Deliver each selected carrier end to end. | Item/cast/progression ownership, independent duplicate sources, removal and allowed reload. Controls should be part of proving the carrier. |
| S-074 + S-075 | Source-specific suppression, including overlap. | Suppression retains the original clock; removing one suppressor cannot expose a condition another still masks. |
| S-106 + S-225 | Chosen old/new rerolls with their weapon/shared-spell consumers in one coordinated batch. | Domain-specific critical/miss rules, old/new choice, retained mode/bonuses and each host's once-only consequence. Keep per-host proof. |
| S-150 + S-151 | Store and release one exact spell entry. | Original caster snapshot, holder targeting, entry consumption and no second original-slot charge. Storage alone does not prove a useful lifecycle. |
| S-152 + S-153 | Temporary spell theft with expiry/removal. | Exact enemy prohibition, recipient permission, deadline, reload and cleanup without touching another source. |
| S-222 + S-223 | Capability availability through the actual offer/refusal route. | Unsupported referenced children refuse before cost; an explicitly partial option remains distinguishable from full support. |

Do not force every pair into one small task when the selected hosts make it large.
The useful change is sharing one setup, implementation context and review while
preserving the separate observable requirements.

Other apparent overlaps need narrower remaining scope rather than a merge:

- **S-051:** per-class capacity and die-size tables now exist through S-037.
  Reuse them. The missing work is retained individual dice, identities even for
  equal faces, their upgrade/snapshot policy and durable recovery. A captured
  bonus receipt is not yet a transferable inventory of dice.
- **S-038:** EventResolver already separates raw natural, natural floor and
  final-total floor and preserves floor stages across accepted rerolls. Extend
  authoring/source provenance and the selected real roll domains from that
  boundary; do not build another roll calculator.
- **S-042 and S-086:** source-end reason/origin should have one producer.
  S-042 also includes cast-completion facts; S-086 adds end-event consumers and
  final-state behavior. Reuse the earlier event contract for the later delta.
  A blind merge would tangle their existing prerequisite chain through S-072.
- **S-109/S-110:** share damage-stage plumbing, but incoming reduction and bypass
  of selected mitigation layers remain different rules. Test their interaction
  without pretending one implements the other.

## What genuinely remains

The remaining plan contains much more than additional arithmetic. Source grants,
choice replacement, progression and casting permissions must connect through
real controls. Resource transfers/recovery and effect termination/suppression
need their own exact-source behavior. Cross-actor intervention and extra actions
need correct recipients and budgets. Forms, created actors, containment, geometry,
per-observer knowledge, containers and body state need represented world behavior;
existing formula/result composition cannot manufacture those facts.

Preserve those distinctions. In particular, do not collapse natural-result
replacement with forced outcomes, Temporary HP with other absorption, suppression
with removal, or an extra Action with an inserted turn.

Recheck prerequisites against the actual selected consumer. For example, S-219's
knowledge/attitude row currently waits through communication, borrowed senses and
remote-origin rows (S-218/S-193/S-192). A local authored knowledge fact need not
necessarily wait for all that. Its communication-dependent consumers may. The
current plan already permits matching prerequisites to selected behavior; apply
that rule instead of turning every listed edge into a universal capability gate.
No dependency edge was changed by this review.

## Small code consolidation opportunities

Do these when the next relevant feature touches them, not as a separate rewrite:

1. `ResourcePoolRules._actor_formula_error` and
   `SharedStepExecutor._actor_formula_has_cast_only_reference` maintain similar
   actor-only formula exclusions. One shared policy check would avoid updating
   two exclusion lists for every new formula kind.
2. `_result_component`, `_result_component_sum`, `_result_reduce`,
   `_child_group_state` and `SpellFormulaInputs.source_die` repeat receipt
   selection. Share exact step/target lookup where it removes real duplication.
   Keep their different semantics: the older sum deduplicates targets, the newer
   reducer rejects duplicates, and groups require explicit completed outcomes.
   Older numeric readers also retain an actor-ID fallback while newer readers
   use exact object identity. This is a seam to handle deliberately, not a
   demonstrated defect through the current canonical execution route.

There is no reason here for a new service, universal event framework, another
interpreter or a wholesale CombatState extraction.

## Process recommendation

Keep one implementation owner and independent review of shared combat/state
boundaries. Combine BUILD and focused production validation in the working chat
when practical, then give the independent reviewer the code, receipts and exact
limits. E/F already used owner-authorized combined development/validation and
separate review. Independence of the review is what caught the bugs; an extra
fresh chat between every development and validation step is not itself evidence.
This is a proposed workflow change, not a rewrite of the existing prompt contract.

Group by the behavior and shared boundary, not a compulsory number of three cards.
Keep the existing hard controls: renamed data, real input/command paths, refusal
before cost, settled results across choices, exact cleanup and fresh-process
recovery for new durable state. Use one composition control for the affected seam,
building on the mixed/Empowered/override controls already present, rather than
rerunning every previously green group.

Reduce repeated live status. The current checkpoint is 870 lines and the prompt
pack exceeds 1,500 lines; copied progress narratives already
disagree. Keep the live next action on the board, current acceptance in its
registry/checkpoint, authoring rules in the mechanics contract and historical
detail in the acceptance report. Link between them. No wholesale documentation
cleanup or removal was performed here.

Continue with **S-038**. Treat S-039/S-040 as one coherent protection-selection
delivery while retaining both finish lines. Refresh later prompts against actual
missing behavior before executing them. Nothing in this review starts Batch G.

## Evidence and limits

Read the [E review](../../.artifacts/planning/vocabulary-reports/batch-E-review.md),
[F review](../../.artifacts/planning/vocabulary-reports/batch-F-review.md), current
source, fixture contracts, plan/checklist and relevant ADRs. Agent Ground was not
callable. Read-only CodeGraph inspection found 32 Python files and one Liquid
file, no GDScript; source lookup used `rg` after checking coverage.

Retained logs inspected include class-table/number controls and 190-script
parse/boot at `.artifacts/tests/cba950a9a99b41b6b80be713053392e0/`, and distinct
process recovery under
`.artifacts/tests/s037-class-levels-relaunch-9f300cfab84d4205a79debbc85ac3991/`
and `.artifacts/tests/s031-damage-history-relaunch-a4de2f85c31a4bcc955ba0e3352b141c/`.

The independent reviewer started one focused spells run. Its logs at
`.artifacts/tests/c4e754d8181144e5a6dad89c874dc394/` show bootstrap, 190-script
parse, boot and **1203 passed / 0 failed** with the selected-logic success marker.
The overall runner exit was not captured, so this is corroborating log evidence,
not a newly certified exit-0 acceptance. No engine processes remained. No runtime
files, acceptance entries, dependency edges or slice counts changed in this review.

Still outside acceptance: broad native history hosts, arbitrary history intervals,
general collections/child actions, an independently exercised save-to-formula
consumer, full multiclass acquisition/slots/UI, and mid-choice saves. Existing
bounded acceptance does not imply those capabilities.
