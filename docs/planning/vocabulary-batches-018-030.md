# Proposed vocabulary batches 018-030

Prepared 2026-10-17 at the owner's request. Continue with numeric batch IDs
after historical A-Q; do not rename historical reports or S-/VS-series IDs.
This is a batch outline, not a prompt pack or implementation dispatch.

## Baseline and order

The original proposal baseline was **67/226 slices; 159 remain**, through independent
[Batch Q review](../../.artifacts/planning/vocabulary-reports/batch-Q-review.md).
Actual K-Q work differs from the earlier conversational proposal: K acquired
and replaced choices, L connected fixed stat carriers, M retained dice, N added
combat recovery, and P/Q delivered captured grants, shared bonuses, a helper
modifier and allocations. Effect endings, suppression/auras and casting
permissions were not accepted by those batches.

The [slice registry](vocabulary-slices.md) retains each exact finish line and
prerequisite. Rows below list execution order within each batch. Every listed
prerequisite is accepted already or appears earlier in this proposal. This
checks planning dependencies, not whether all production wiring exists.

| Batch | Slices in order | Observable delivery | Earlier proposed batch needed |
|---|---|---|---|
| **018 - Acquisition and permanent progression** | S-047, S-048 | Distinguish starting-class grants from multiclass entry. Apply declared proficiency, equipment, ability and maximum-HP progression once at the proper class/character level; reload does not grant it again. | None |
| **019 - Effect endings and causal exceptions** | S-042, S-072, S-073 | Publish actual completed-cast facts and exact source-end reasons. End only matching effects on declared actions, status, gear or range events; exempt only damage from the specified causal source. | None |
| **020 - Suppression and moving auras** | S-074, S-075, S-080 | Suppress a condition while preserving its source and original clock. Overlapping suppressors and moving aura recipients remain independent; leaving removes only membership-dependent benefits. | 019 |
| **021 - Casting permissions, payment and preparation** | S-134, S-135, S-137 | Offer spells through the actual owning class, book, item or innate permission. Select that permission's allowed slot/free/point payment and retain its ability, preparation list, limit and replacement boundary. | None |
| **022 - Slots, limited uses and ritual access** | S-138, S-139, S-136 | Keep combined ordinary slots, Pact slots and fixed-level source uses separate. Apply source-specific ritual timing/components without turning ritual-only access into ordinary casting permission. | 021 |
| **023 - Resource conversion and exchange** | S-052, S-053 | Exchange exact eligible slots, pool quantities or dice, including eligible recipients. Validate both sides before changing either; refusal leaves both intact. | 021 |
| **024 - Budgeted and timed recovery** | S-054, S-055, S-063 | Choose recoveries within a formula budget or actual paid-slot/result restriction. Recover at declared dawn/dusk/cooldown events once, including late observation and large clock jumps. | 021 |
| **025 - Damage/healing dice and substituted payment** | S-123, S-124, S-125, S-059 | Remove/maximize eligible dice, reroll selected dice, and multiply at the declared critical/result stage. Permit an authored replacement payment or free die while preserving sibling costs and the original roll. | None |
| **026 - Repeated saves and staged outcomes** | S-068, S-069, S-090 | Schedule actual turn/time-based repeat saves, count qualifying outcomes and transition linked stages. Escalating DC/risk follows exact attempt history and the declared reset event. | None |
| **027 - Temporary HP and lingering protections** | S-078, S-079, S-081 | Let recipients retain or replace actual Temporary HP without resetting its supplier/deadline. Tie cross-actor benefits to the surviving qualifying HP; support chosen aura protections and explicitly lingering entry benefits. | 020 |
| **028 - Attack substitutions and child actions** | S-146, S-148, S-149 | Replace declared remaining attack/strike units with an eligible child. Preserve the parent action cost, classification and remaining siblings through choices, refusal and interruption. | 021 |
| **029 - Cast interruption, negation and settlement** | S-142, S-115, S-143, S-116 | Reserve/commit/refund the exact interrupted or failed cast payment. Cancel one eligible pending cast or negate one recipient's effect; stopping success/failure settles its own costs without repaying the original cast. | 019, 021 |
| **030 - Physical facts, space and movement** | S-032, S-033, S-179 | Query actual size, mass, material, equipment, plane and available space. Apply represented movement modes, terrain and hand/surface requirements; refusal spends no movement. Unknown facts cannot make an action eligible. | None |

The original outline has **39 slices**, with no duplicates. Independent
[Batch 018 review](../../.artifacts/planning/vocabulary-reports/batch-018-review.md)
now accepts S-047/S-048 as VS-68/69; Batch 019 accepts S-042/S-072/S-073 as
VS-70/71/72; and independent Batch 020 review accepts S-074/S-075/S-080 as
VS-73/74/75. Independent [Batches 021–023 acceptance](../../.artifacts/planning/vocabulary-reports/batch-021-023-acceptance-review.md)
accepts S-134/S-135/S-137, S-138/S-139/S-136 and S-052/S-053 as VS-76–83.
Independent [Batch 027 review](../../.artifacts/planning/vocabulary-reports/batch-027-review.md)
accepts S-078/S-079/S-081 as VS-84/85/86 after combat-exit membership cleanup.
Batch 029 retains S-142/S-115/S-143/S-116 as VS-87–90. Independent
[024/026 verification](../../.artifacts/planning/vocabulary-reports/batch-024-026-verification.md)
accepts S-054/S-055/S-063 and S-068/S-069/S-090 as VS-91–96.
[028 completion review](../../.artifacts/planning/vocabulary-reports/batch-028-completion-review.md)
accepts S-146/S-148/S-149 as VS-97–99. The
[029/030 review](../../.artifacts/planning/vocabulary-reports/batch-029-030-review.md)
retains repaired Batch 029 and accepts S-032/S-033/S-179 as VS-100–102.
The registry is now **106/226 accepted, 120 remain**. Independent
[Batch 025 completion review](../../.artifacts/planning/vocabulary-reports/batch-025-completion-review.md)
accepts S-123/S-124/S-125/S-059 as VS-103–106, closing that batch's four outlined
slices. The forecast above described the full 39-slice plan from its original
67/226 Q baseline; later work selection still follows the current roadmap and
Quest Board.

## Boundaries that matter

- **018 does not start with slot accounting.** S-138 requires S-137, which in
  turn requires S-134. Casting permissions/preparation in 021 must precede 022.
  Existing class-level formula inputs are reused; they do not establish actual
  multiclass acquisition or permanent progression.
- **019 supplies one source-end producer.** Later S-086/S-087 can reuse its
  reason/origin facts for aftermath. Do not build a general subscription engine
  or silently count those later consumer slices here.
- **020 keeps suppression distinct from removal.** An expired condition cannot
  return when suppression ends; removing one suppressor cannot expose a
  condition still masked by another. Preserve each participant's identity and
  giver/bearer/recipient values.
- **021 extends the selected real carriers.** L accepted fixed additive stats
  and self-casts, while P/Q accepted bounded gifts and combat consumers. Neither
  proves casting permissions, broader grant payloads or another roll host.
  Necessary wiring belongs to the selected slice, rather than an assumed
  already-supported carrier.
- **023 and 024 have different transactions.** Conversion spends one source
  to change another; recovery restores an eligible source under its own policy.
  Retained dice from S-051 and captured gifts from S-082 are reuse points, not
  interchangeable inventories.
- **025 and 029 have four slices for behavioral reasons.** Keep each slice's
  checks distinct. Reuse existing damage dice/critical owners in 025, and keep
  pending-cast cancellation with its payment settlement in 029. A helper passing
  alone does not prove the complete route.
- **030 supplies represented facts and movement, not summons or forms.** Actor
  creation, commands/initiative, legal arrival, containment, observer knowledge
  and general flying/climbing AI remain their own later work. An Animate Objects
  allowlist entry still does not prove its cast or lifecycle.

## Build and review practice

**018–023 are independently accepted on their documented hosts.** Later batches are
prepared recommendations, conditional on accepted prerequisites and review
findings. Independent ready work can be selected if one branch encounters an
actual blocker; no phase must be completed wholesale.

For each selected batch, reuse the existing execution owners and neutral/renamed
loaded fixtures. Exercise the real supported controls, exact source/recipient
identity, declared timing, once-only costs/results, stale choices, cancellation,
refusal and cleanup. New durable state needs allowed-checkpoint recovery in a
fresh process and malformed-load refusal before live replacement. Reuse unchanged
accepted proof; do not repeat broad green suites without new evidence.

Build plus bounded production validation may share an owner-authorized builder
chat. Independent batch review remains separate and reconciles every selected
slice against its original finish line and explicit host limits. This outline
does not authorize workers, gameplay implementation, catalog conversion,
installation, publication or destructive cleanup. No Godot checks ran during
preparation; structural checks only verified IDs, counts and prerequisite order.
