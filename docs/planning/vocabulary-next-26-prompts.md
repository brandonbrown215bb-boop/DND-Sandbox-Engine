# Next 26 vocabulary slices: copyable prompts

Prepared by Rook on 2026-10-13 at the owner's request. This is static planning:
**26 existing slices, 52 BUILD/VALIDATE prompts, one prerequisite review and nine
batch reviews.** No gameplay was run and no accepted counts changed to prepare it.

Copy one fenced prompt into a fresh Luna chat. Each prompt explicitly loads
[the shared workflow](vocabulary-prompt-workflow.md), so you do not have to paste
the boilerplate separately. Complete BUILD, then use a separate fresh chat for
VALIDATE. After each batch, use its REVIEW prompt in another fresh chat. There
is no supervising worker to keep polling or feeding itself more tasks.

These prompts are prepared in advance; later ones become ready only when their
listed prerequisites and the preceding batch review are actually accepted. The
current runtime may need less code than a planned row implies. Inspect and reuse
what works. Do not treat 26 planned pairs as 26 promised acceptances.

S-024 is not one of these 26. Its separate validation and bounded review are
complete as VS-27. S-025's separate BUILD and VALIDATE are accepted as VS-28.
S-041 BUILD is now next, after which its own VALIDATE and the trio's batch review
remain. The other eight batches have three slices each.

## Queue

| Order | Batch | Slice | Observable change | Plan prerequisites |
|---|---|---|---|---|
| 01 | A | [S-025](#01--s-025-actoractionitemsource-fact-bindings) | Read the right actor, action, item copy, spell and source. | S-024 |
| 02 | A | [S-041](#02--s-041-authored-rolldamage-window-context) | Expose the actual roll and damage stage. | S-023, S-025 |
| 03 | B | [S-091](#03--s-091-declared-advantagedisadvantage-policy) | Author roll modes, cancellation and exemptions. | S-024, S-041 |
| 04 | B | [S-092](#04--s-092-explicit-attacksave-success-and-failure) | Force an authorized outcome while retaining the roll. | S-020, S-041 |
| 05 | B | [S-095](#05--s-095-subtract-total-or-change-defending-ac) | Turn a provisional hit into a miss before damage. | S-023, S-041 |
| 06 | C | [S-034](#06--s-034-prior-result-identity-and-additional-measures) | Read exact prevented, absorbed and healed results. | S-003, S-017 |
| 07 | C | [S-043](#07--s-043-margin-and-post-settlement-hp-gates) | Branch on margins and HP at settlement. | S-005, S-034 |
| 08 | C | [S-098](#08--s-098-independent-savemiss-damage-and-riders) | Separate damage scaling from rider eligibility. | S-022, S-043 |
| 09 | D | [S-026](#09--s-026-allyenemywillingness-and-giver-relations) | Read live allegiance, willingness and exact giver. | S-002, S-025 |
| 10 | D | [S-027](#10--s-027-distance-to-another-actor-or-source) | Measure range to the actual related entity. | S-026 |
| 11 | D | [S-029](#11--s-029-required-senses-and-causal-save-purpose) | Distinguish senses and causes of otherwise similar saves. | S-028 |
| 12 | E | [S-030](#12--s-030-round-and-actor-action-history) | Query first turns and actual action history. | S-008 |
| 13 | E | [S-031](#13--s-031-damage-since-boundary-history) | Track actual damage within the declared interval. | S-030, S-003 |
| 14 | E | [S-035](#14--s-035-declared-multi-result-reducers) | Sum/min/max an explicit result selection. | S-034 |
| 15 | F | [S-044](#15--s-044-allanycount-child-result-gates) | Wait for grouped outcomes before applying aftermath. | S-043, S-035 |
| 16 | F | [S-036](#16--s-036-source-diechoice-inputs-and-capture-policy) | Use one source die or choice in formulas. | S-016, S-023 |
| 17 | F | [S-037](#17--s-037-class-level-inputs-and-progression-tables) | Use class-specific progression and die-size tables. | S-036 |
| 18 | G | [S-038](#18--s-038-natural-d20-and-final-total-floors) | Keep natural-roll and total floors distinct. | S-023 |
| 19 | G | [S-039](#19--s-039-ac-alternatives-and-score-setting) | Resolve base AC, score setting, floors and caps. | S-024, S-004 |
| 20 | G | [S-040](#20--s-040-recipient-choice-and-overlapping-modifiers) | Choose between incompatible owned protections. | S-039 |
| 21 | H | [S-106](#21--s-106-chosen-oldnew-reroll-with-modebonus) | Choose old/new with declared new-test mode and bonus. | S-105, S-091, S-037 |
| 22 | H | [S-225](#22--s-225-weapon-and-shared-spell-reroll-consumers) | Reuse rerolls in weapon and shared-spell controls. | S-105, S-106, S-022 |
| 23 | H | [S-099](#23--s-099-evasion-and-chosen-recipient-exemptions) | Remap only the qualifying recipient's consequences. | S-098, S-026 |
| 24 | I | [S-100](#24--s-100-other-declared-result-payment-predicates) | Settle one selected payment against the final outcome. | S-019, S-094, S-043 |
| 25 | I | [S-109](#25--s-109-component-versus-whole-occurrence-damage-edits) | Reduce a component or whole incoming damage occurrence. | S-034, S-041 |
| 26 | I | [S-110](#26--s-110-precisely-scoped-mitigation-bypass) | Bypass exactly the declared mitigation layers. | S-109 |

This order preserves the roadmap's next two candidate trios, then fills in
relationships, results and formulas needed for broader reroll and damage consumers.
Off-turn creature choices and other-actor interventions are left for their actual
budget/creature prerequisites; forms, world geometry and catalog conversion are
not smuggled into this queue. At preparation time, if all 26 received acceptance,
the 27/226 baseline (including S-024) plus these slices would be 53/226. The
current baseline is 28/226 after S-025; accepting all 26 remaining prepared
slices would make 54/226. This is arithmetic, not a support claim or effort
forecast.

## Completed prerequisite review: S-024

S-024's separate production evidence was reviewed and accepted as VS-27. Its
integral-JSON-number scalar-healing parser mismatch is explicitly carried into
batch A review; the prompt below records that required follow-up. S-025 has since
completed separate BUILD and VALIDATE as VS-28. Continue with S-041 BUILD as its
separate stage; keep the following retained prompt as a historical instruction.

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Review S-024 only before beginning this next-26 queue. The current card is
Q-20261014-000538-3d5c. BUILD passed 1008/0 at
.artifacts/tests/518f20b7b66f4fac89e05da449f01a91/; separate real-control validation
passed 11/0 at .artifacts/tests/0a100c3d32f940e0963733ee0068fb4f/.

Inspect current SharedStepExecutor, loaded fixtures, actual CombatHUD/cast/target
scenario and retained gates/exits. Verify nested all/any/not, strict comparisons,
missing versus false versus zero, missing under not, mixed known/unknown branches,
source/pool/timed-grant query purity and refusal before cost. Check that the proof
and documented supported host match the planned slice; no broader fact binding
or V-001 completion is implied. Do not rebuild or repeat green suites by default.

If current source and evidence agree, reconcile the precise new VS boundary and
S-024 slice state/counts/current checkpoint and finish its card. Carry the known
integral-JSON-number healing parser finding into batch A review explicitly. If a
specific mismatch requires correction, reproduce only that concern and recheck
affected behavior. If evidence is insufficient, leave an exact next action and
do not accept by assumption. STOP. The next prompt is S-025 BUILD, not automatic
dispatch from this review.
```

## 01 — S-025: Actor/action/item/source fact bindings

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-025 (V-001) only, after accepted S-024. Bind authored selectors to the
actual actor, target, action invocation, item copy, spell definition/invocation
and exact source instance. Keep definition IDs distinct from runtime identities.
The same field name must not accidentally read another entity. Missing or
wrong-kind bindings remain unavailable under S-024's missing-fact policy.

Inspect existing SharedStepExecutor/SpellAdapter/SpellResolutionContext and the
owned action/inventory/source routes. Add only the selectors and production wiring
needed to demonstrate every listed entity kind, using contrasting neutral and
renamed loaded definitions. Document which bindings are present in each selected
host; do not fabricate an item in a spell-only context. Treat caller values as
requests, not authority. Capture invocation identity through an existing choice
continuation while explicitly declaring which fact values are live queries.

Focused development must distinguish owners/targets and two copies or sources
of one definition, plus unavailable bindings and stale continuation substitution.
Do not build a universal object model or broaden the world-fact inventory. Record
syntax, routes, changed files and checks; hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-025 only after its BUILD report. Drive the selected real action/check/
spell and inventory/source routes for actor, target, action, item copy, spell and
source selectors. Use both loaded definitions and contrasting entities so each
selector's effect is observable; same-definition actors/copies must remain distinct.

Change only the referenced entity, then an unrelated one. Qualification must
change only where declared. Missing/wrong-kind entities and copied caller metadata
cannot provide an authoritative actor/action/source or spend/grant anything.
Pause at a real existing choice, change a live fact and attempt stale identity
substitution: captured invocation bindings remain fixed, and live values follow
the documented policy. Retain original costs and consequences once.

Inspect source IDs for actual instances rather than definition-name aliases.
Run focused current-source Godot evidence and gates. Report exact selector/host
coverage and remaining gaps; do not accept the full row if a listed binding was
never exercised. Leave the card for REVIEW and STOP. S-041 BUILD follows only
after this prerequisite's exact validation boundary is accepted under the shared workflow.
```

## 02 — S-041: Authored roll/damage window context

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-041 (V-010) only after S-023/S-025 acceptance. Expose authored before-roll,
after-natural, provisional-outcome, pre-damage and post-damage windows through
existing actual action stages. Carry exact occurrence, kind, actor, target and
source bindings. Declare available receipt fields per window; future damage or
unsettled outcomes cannot appear as final facts.

Use existing bounded choice/eligibility consumers with neutral and renamed loaded
definitions to make all five windows observable in order. Reuse existing roll,
choice and damage owners, not action replay or a universal subscription engine.
Answer one occurrence/window once; pause before its consequences and preserve
canonical bindings and original costs. A final miss cannot offer or charge a
damage-only consumer. Post-damage reads existing raw/resolved/HP-loss receipts;
additional measures belong to S-034.

Cover stale host/occurrence answers and source removal. Do not implement new roll
modes, forced outcomes or defensive edits reserved for S-091/092/095. Cast/source
end windows remain S-042. Document supported routes, fields and ordering, run
focused development checks, then hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-041 only using real supported action and choice controls with both
loaded definitions. Prove all five windows occur in order with exact occurrence,
roll kind, actor, target and source. A before-roll consumer cannot read a future
d20; after-natural cannot read settled damage; provisional outcome remains
provisional; post-damage selects the actual retained receipt.

Exercise hit and miss, decline, source loss, wrong actor/window, repeated answer,
old answer against a fresh occurrence, and host replacement/teardown. Damage-only
spending must be absent on a final miss. A paused answer resumes one original
action, its declared dice/payment and one set of consequences. Check a later
existing damage/step choice retains the same occurrence instead of overwriting it.

Run the affected scenario/groups and gates, inspect receipts and exits, and record
the precise host/window boundary. Leave the card for REVIEW and STOP for batch A
review of S-024/S-025/S-041. Do not introduce S-042 or start batch B here.
```

## 03 — S-091: Declared Advantage/Disadvantage policy

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-091 (V-012) only after S-024/S-041 acceptance and batch A review. Author
eligible Advantage/Disadvantage addition, cancellation and prohibition, with
explicit source exemptions, before the original roll. Reuse the engine's normal
mode resolution; don't treat a natural-result replacement as a mode change.

Use exact source provenance and bound roll context to distinguish exempt and
nonexempt contributions. Define/document how multiple grants, opposite grants
and selective prohibitions resolve. Renamed data must change policy or eligibility
without ID branches. Choose a represented supported roll route and make the mode
and its contributors visible in the captured receipt; don't promise every host.
Querying eligibility must neither roll nor spend. Source loss before commitment
must be revalidated, and a post-roll answer cannot retroactively add dice.

Focused checks cover duplicate same-mode sources, ordinary cancellation, exempt
sources and a nonqualifying roll. Preserve existing pre-roll token replacement
and S-105 mode provenance. No reroll or new token generation in this slice.
Document authoring/order and hand off to separate VALIDATE; STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-091 through the actual selected pre-roll controls using neutral and
renamed loaded sources. Observe Normal, Advantage and Disadvantage, multiple
same-mode sources, opposite-mode cancellation, selective cancellation/prohibition
and an exempt source that survives only the declared restriction.

Count actual d20 faces/events correctly and inspect selected natural, effective
mode and source provenance. Qualification must use the canonical actor/kind/task;
wrong source/domain, missing context, stale selection and refusal add no rolls
or payments. Change a source before rolling and verify revalidation. After the
roll, repeated answers cannot recalculate its mode or reroll it. Where the route
already supports a pre-roll token, replacing a natural result must remain distinct
from mode selection and retain the original token payment semantics.

Check ordinary unmodified rolls and final consequences, affected Godot evidence
and gates. Report exact modes/policies/host and remaining domains. Leave REVIEW
and STOP; do not close all V-012 or implement S-106 during validation.
```

## 04 — S-092: Explicit attack/save success and failure

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-092 (V-013) only after S-020/S-041 acceptance. Extend the accepted explicit
save override into authored hit/miss and save-success/save-failure outcomes at
authorized windows for actually rolled attacks/saves. Keep natural d20, effective
mode, modifiers, total and captured DC/AC as numeric facts; record the separate
override and its provenance rather than inventing a natural 20 or a numeric bonus.

Use owned neutral/renamed sources and existing attack/save choice owners. Validate
domain, stage and source before payment; suspend consequences until final outcome.
Specify actual natural-1/20 and critical interaction for the selected override,
without silently changing ordinary roll rules or assuming forced hit means crit.
Earlier ordered outcomes and original cast/action costs remain settled once.

Cover both directions of change and retained receipts through later choices.
No no-roll action, canceled Death Save or general token replacement here; those
are later slices. Document supported attack/save routes and override precedence,
run focused development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-092 through actual supported attack and shared-save controls using
both authored definitions. Prove explicit hit, miss, save success and save failure
with original natural/modifier/total/DC-or-AC unchanged and an exact-source override
receipt. Exercise natural 1/20 and critical boundaries under the documented policy;
a forced result cannot silently manufacture a critical or replay a d20.

Observe final damage/riders only after override settlement and preserve earlier
ordered outcomes, one action/slot cost and one source payment. Include a following
existing damage choice to prove the override receipt survives continuation.
Wrong domain/window/owner, source depletion/removal, decline and stale/replayed
answers cannot mutate the new occurrence, roll or spend. Unsupported no-roll or
Death Save cases must not be offered as if covered by this slice.

Run focused Godot acceptance and gates, inspect actual receipts/costs, report exact
routes and limits, leave REVIEW and STOP. Retain VS-20 proof rather than rerunning
unchanged broad groups solely because the parent remains partial.
```

## 05 — S-095: Subtract total or change defending AC

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-095 (V-014) only after S-023/S-041 acceptance. Author a qualifying downward
attack-total adjustment and a defending-AC adjustment for one triggering provisional
hit. Reuse captured post-roll source requests and final settlement. Define the
selected actor/source ownership and scope clearly; this is not S-097's general
cross-actor intervention or permission to spend another actor's budget.

Use loaded neutral fixed-total subtraction and renamed AC-change consumers with
distinct amounts. Retain original natural/modifier/total/profile/AC, adjustment
receipt and final result. Reevaluate before damage or hit-only rider consumption.
The AC change applies only to this occurrence unless separate supported source
data explicitly owns a duration; do not permanently mutate the defender's AC.
Preserve existing natural/critical boundaries and original attack/action payment.

Show conversion to miss and a remaining hit, plus source/refusal/replay behavior
and a following ordered choice. Document ownership, eligible windows and payment
policy, run focused development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-095 with real attack/defensive-source controls for both subtraction
and AC adjustment. Prove a converted miss and a remaining hit for each supported
policy, including exact equality boundaries. Inspect original/new totals and AC,
natural/critical facts and the retained adjustment-source receipt.

A final miss causes no damage, hit-only rider or next-hit grant consumption and
no damage-side source spending. A remaining hit settles those once. Subsequent
attacks use ordinary AC unless separately authored duration exists. Original
Attack/Extra Attack or spell cost follows the actual supported route once.
Check decline, insufficient funds, removed source, wrong actor/occurrence/window,
completed replay and an old answer while another attack is pending. Preserve
existing natural-1/20 policy and later-choice continuation.

Run affected Godot scenarios/groups and gates, inspect state/exits, record exact
ownership/routes and limitations, leave REVIEW and STOP for batch B review of
S-091/S-092/S-095. Do not add a counterattack or another actor's intervention.
```

## 06 — S-034: Prior-result identity and additional measures

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-034 (V-006) only after S-003/S-017 acceptance and batch B review. Extend
existing prior-result selectors to exact step, runtime target and typed component
identities, with prevented, absorbed and actual healed quantities alongside accepted
raw/resolved/HP-loss values. Define each measure from the authoritative settlement
receipt; don't infer it by rereading current HP after another effect.

Use neutral/renamed ordered consumers whose aftermath makes different measures
observable, including Temporary HP absorption, mitigation and capped healing.
Two actors of one definition and repeated same-type components must not alias;
if a component selection is ambiguous, reject it rather than taking the first.
Retain settled results across an existing pause and later target/source changes.
Missing/future/wrong-step references are unavailable or invalid as documented,
not fabricated zero. Existing VS-03/17 selector and sum behavior stays supported.

No general reducer or new mitigation operation in this slice. Document measure
semantics, identity selectors and hosts, add focused development evidence, hand
off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-034 through real loaded ordered spell/action controls. Produce and read
distinct prevented, absorbed and actual healed receipts, with raw/resolved/HP-loss
as comparison values. Include Resistance/Immunity or existing ward prevention,
partial/full Temporary HP absorption, overkill and healing capped at max HP so
the quantities cannot accidentally agree.

Use multiple actual targets, repeated component types and renamed data. Prove
selection by step/target/component, ambiguity refusal, absent/future-reference
handling and explicit real zero. Pause at a later choice, change live HP or another
source, then show the selected settled result stays unchanged. No original roll,
cost, damage or healing replays on resume or repeated answer.

Inspect numeric receipts and the actual aftermath consumer, run affected Godot
acceptance/gates, and report implemented measures/identity routes and gaps. Leave
REVIEW and STOP; all measures in the planned row need evidence before full slice
acceptance. Do not build S-035 reducers during this validation.
```

## 07 — S-043: Margin and post-settlement HP gates

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-043 (V-011) only after S-005/S-034 acceptance. Author gates on success/
failure margin and HP captured at the declared completed settlement. Bind the
specific roll or damage occurrence, target and step. Document signed margin,
equality and whether an overridden outcome has an available numeric margin;
never fabricate one to make the gate qualify.

Use loaded neutral and renamed ordered consumers with threshold differences.
One branches on failed-save margin; another branches on target HP after actual
damage. Numeric margin and final outcome remain distinct after S-092/S-095 edits.
Pre-damage HP and later unrelated healing/damage cannot replace the captured
post-settlement value. Suspend aftermath until its selected result is final,
retain the gate input across an existing later choice, and settle the effect once.

Unknown/malformed/future references refuse before unintended payment/effects.
Grouped all/any/count belongs to S-044. Record syntax, selected hosts and precise
stage semantics, run focused development checks, hand off to VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-043 through actual attack/save/damage and ordered aftermath controls.
For each authored threshold test below, exactly at and above it, covering success
and failure margins and HP at settlement. Include zero damage, Temporary HP and
overkill where they distinguish HP or result measures. Use both loaded definitions.

Apply a supported post-roll adjustment or explicit outcome override: gates must
read the declared final numeric receipt/outcome, not the provisional result or an
invented margin. During a later pause change current HP with another effect and
verify the earlier post-settlement gate still uses its captured value. Earlier
step costs/results and the gated aftermath settle once on resume.

Missing/wrong-target/future references, decline/refusal and stale/replayed answers
cannot execute the gate's effect. Inspect final receipts, run targeted Godot proof
and gates, record exact domains/margins/HP semantics and remaining scope, leave
REVIEW and STOP. Do not certify grouped child gates here.
```

## 08 — S-098: Independent save/miss damage and riders

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-098 (V-015) only after S-022/S-043 acceptance. Let authored data select
damage scaling and rider eligibility independently for final attack hit/miss and
save success/failure. Reuse flat/ordered shared spell delivery and typed damage;
don't convert a miss into a hit just to apply partial damage.

Use a neutral attack consumer with declared half damage on miss and a hit-only
rider, plus a renamed save consumer whose damage and condition mappings differ.
Define explicit rounding and absent-map validation. Use the final result after
bonus/override/defensive choice, retain one original roll/cost and make per-target
damage and rider decisions observable. A missing or unsupported mapping cannot
silently default to a different authored outcome.

Preserve existing ordinary shared payloads and continuation through a following
damage choice/ordered step. Recipient-specific Evasion/exemptions belong to S-099,
not this slice. Document maps, stages and supported routes, run focused development
checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-098 using actual flat and ordered shared-spell attack/save controls.
Show each authored hit/miss/success/failure damage map independently of its rider:
half-damage miss retains miss and grants no hit-only rider; saved/failed targets
receive precisely the configured scale and condition. Include odd damage for
rounding and Resistance/Temporary HP to expose the chosen stage.

Use a supported post-roll adjustment that changes the provisional outcome and
confirm consequences follow the final receipt. Multiple targets retain distinct
maps; a following damage/step choice cannot prematurely apply a rider or repeat
damage, slot, action or source cost. Query/decline/refusal and stale/replayed
answers mutate no unrelated occurrence. Malformed maps fail before cast payment.

Inspect receipts and actual HP/conditions, run focused current-source Godot proof
and gates, record route/map limits, leave REVIEW and STOP for batch C review of
S-034/S-043/S-098. Chosen target exemptions and Evasion remain the next slice.
```

## 09 — S-026: Ally/enemy/willingness and giver relations

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-026 (V-002) only after S-002/S-025 acceptance and batch C review. Add
authored queries for current ally/enemy relationship, explicit willingness, and
the exact giver of a source-owned charm/mark. A condition label or shared content
definition cannot identify who applied it; unknown willingness is not consent.

Use existing allegiance/control and source/condition owners. Supply actual
represented willingness through the selected supported choice/data route, not
an assumption that every ally agrees. Demonstrate all relation types with loaded
neutral/renamed eligibility consumers and two independent givers of the same
effect kind. Declare live versus captured query policy and keep authoritative
entity bindings through continuation. Source removal changes only its relation.

Persist any newly durable provenance under the shared workflow; no general social
AI, faction simulation, charm implementation or free-text consent interpreter.
Document represented facts/routes and unavailable cases, run focused development
checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-026 through actual selected grant/condition and eligibility controls.
Contrast ally, enemy and unavailable relation, explicit willing/unwilling/unknown,
and two actual givers of identical charm/mark definitions. A target affected by
another giver cannot qualify as this source's target merely by condition name.

Change current allegiance and explicit willingness; live queries update only
where declared and captured occurrence bindings remain fixed. Remove one giver's
exact source while retaining the other's eligibility. Wrong actor/source/caller
metadata, missing giver and stale answers cannot grant or pay. Qualification
queries never reacquire/reset a source pool or lifetime. Renamed definitions
must use the same runtime with visibly different relation predicates.

If provenance adds durable state, test allowed checkpoint and fresh-process
recovery plus malformed-load refusal before session replacement. Run affected
Godot controls/gates, report exact relationship facts and limits, leave REVIEW
and STOP. Do not claim that willingness or charm supports an entire social engine.
```

## 10 — S-027: Distance to another actor or source

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-027 (V-002) only after S-026 acceptance. Let a predicate measure distance
between actual related actors or a represented located source, with explicit
units, geometry and range boundary. Reuse current battlefield/room position
owners. Do not read distance to a definition ID, a stale actor projection or an
unrelated source sharing the name.

Use neutral actor-relative and renamed source-relative loaded consumers. Distinguish
moving a bearer from moving a located source, and document which relationships
or origins are supported. Missing/unlocated/removed participants yield unavailable
facts, not zero range. Live queries reflect movement; a captured range decision
stays captured only where its declared window requires it. No movement, creation,
aura membership or new line-of-sight operation is implied by a distance query.

Focused checks cover exact range equality, movement of either endpoint, source
removal and two sources/actors of one definition. Document host, metric and
capture policy, then hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-027 with real supported movement and eligibility controls for both
loaded definitions. Test just inside, exactly at and just outside the declared
range. Move the querying actor, related actor and located source independently;
only predicates tied to that actual endpoint update.

Use two actors/sources with identical definitions at different positions. Remove
one related source, move another, and show identities cannot alias. Missing or
unlocated endpoints and unsupported geometry cannot qualify as distance zero.
At an existing paused choice, verify the documented captured/live range policy
and reject stale source/actor replacement. Queries and refused actions move no
one and pay nothing; accepted actions settle once.

Inspect authoritative positions and numeric range receipts, run affected Godot
scenarios/gates, report actual metric/units/host and limits, leave REVIEW and STOP.
This proves distance queries, not auras, teleportation, barrier movement or LOS.
```

## 11 — S-029: Required senses and causal save purpose

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-029 (V-003) only after S-028 acceptance. Carry declared sensory requirements
and actual originating cause/purpose through supported checks/saves: avoiding,
ending and maintaining are distinct reasons even when ability and DC match.
Reuse represented sense/perception queries and exact originating effect/context;
do not add S-190's full observer-specific perception system.

Use neutral and renamed loaded eligibility consumers that differ by required
sense and save cause, with an otherwise identical ordinary Constitution save
as a negative case. Check required see/hear or other actually represented sense
through the production owner; unknown sensory capability stays unavailable.
Do not infer cause from UI prose or grant a bonus to every save of one ability.
Capture purpose/source identity through the existing choice continuation, while
documenting when sensory availability is evaluated or revalidated.

Leave Death Save/concentration roll-choice operations and general interpretation
outside this task. Document exact cause/sense fields and supported hosts, run
focused development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-029 through real supported check/save and source-choice controls using
both loaded definitions. Give checks the same ability/DC but different actual
avoid/end/maintain or unrelated causes. Only the declared originating effect and
purpose qualify; copied purpose text and another source's save cannot substitute.

Make the required represented sense available, blocked/unavailable and unknown,
then verify the eligibility and documented evaluation window. Include a changed
sense/source during a pause, original cause/DC retained through closure, a missing
context ordinary check, and wrong-owner/stale/replayed answers. Refused or declined
choices add no dice/payment/effects and accepted consequences settle once.

Inspect actual context/sense receipts, run affected Godot proof and gates, report
which sensory facts and hosts were represented and which remain unsupported,
leave REVIEW and STOP for batch D review of S-026/S-027/S-029. Do not claim broader
perception, free-text causal inference or a new roll host.
```

## 12 — S-030: Round and actor action history

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-030 (V-004) only after S-008 acceptance and batch D review. Expose first
combat round, first own turn, and whether an actual target acted or was attacked
since a declared combat-turn/owner-turn boundary. Use authoritative initiative,
action commitment and attack occurrences. A combat round, another actor's turn
and the interval since this owner's previous turn are not interchangeable.

Use neutral and renamed loaded eligibility consumers with different history
subjects/boundaries. Define whether a qualifying event is an attempted command,
committed action or resolved attack; canceled targeting/refusal cannot fabricate
the accepted-action event. Misses still count as actual attacks if that is the
declared history query; hits and damage remain separate. Reset on the named event,
not a menu refresh or location change. Include actors added after initiative starts.

Keep encounter history transient unless the selected field genuinely crosses an
allowed checkpoint. Do not create an unbounded event log. Preserve accepted rider
locks independently from these queries. Document event semantics, focused checks,
hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-030 through actual initiative progression, committed action/attack
controls and the loaded history consumers. Contrast first round with each actor's
first turn, a later participant's first turn, and current-turn versus owner-turn
interval history. Advance other actors' turns and the owner's next turn to prove
only the named reset fires.

Exercise an accepted action, hit, miss, canceled target selection, refused command
and a supported off-turn attack where relevant. Inspect history subject/event
identity; one target's history cannot affect another sharing its definition.
Queries/reopened menus do not set or clear history, spend pools or unlock S-008's
existing rider lock. A fresh encounter gets fresh transient history without
changing durable source quantities. Renamed boundary data uses the same runtime.

Run affected combat/classes Godot proof and gates, record exact events/intervals
and limits, leave REVIEW and STOP. Do not infer action history from current HP or
add general campaign achievement tracking.
```

## 13 — S-031: Damage-since-boundary history

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-031 (V-004/V-006/V-057) only after S-030/S-003 acceptance. Track actual
settled damage for an actor and exact causal source within a declared time or
turn interval. Keep raw attempted amount, prevention/absorption, resolved damage
and actual HP loss distinct using retained settlement receipts. No increment
from damage previews, refused commands or replayed completion.

Use neutral turn-boundary and renamed campaign-time-boundary consumers with an
observable history predicate. Reuse current turn serials and campaign clock;
define equality/expiry and reset policy explicitly. Keep only needed aggregates/
bounded entries rather than an unlimited journal. Two sources or targets sharing
definitions must remain independent. A time jump expires precisely the declared
history without generating damage or restarting a deadline.

Encounter-only histories stay transient. Any history that must survive allowed
checkpoints retains identities, quantities and its time boundary, with fresh-process
recovery and preflight validation. Document measurement/reset semantics, run
focused development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-031 through actual damage and turn/time controls plus both loaded
consumers. Use normal damage, prevention/Immunity, Temporary HP, overkill and
miss/refusal to distinguish raw, prevented/absorbed, resolved and HP-loss history.
Repeated completion cannot increment again. Two actual targets and independent
sources of one definition must accumulate only their selected causal receipts.

Advance unrelated turns, the declared owner/turn reset, exact campaign deadline
and a large time jump. Query/menu/scene changes cannot reset or fabricate history;
expiry must follow documented equality and retention policy. Pause across a real
choice and show only finalized damage enters the selected interval once.

For durable time history, use allowed checkpoint plus fresh-process recovery
without replay/deadline restart, and reject malformed source/quantity/boundary
before live-session replacement. Run affected Godot proof/gates, report exact
measure and boundary coverage, leave REVIEW and STOP. Preserve unrelated histories.
```

## 14 — S-035: Declared multi-result reducers

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-035 (V-006) only after S-034 acceptance. Extend the existing accepted
typed sum into authored sum/min/max over explicitly selected settled steps,
runtime targets and components/measures. Keep each result's identity and rounding;
do not automatically aggregate every outcome or multiply a shared receipt by
the number of targets. Reuse VS-17 for its already accepted sum case.

Use neutral and renamed ordered consumers whose declared selection and reducer
produce different aftermath values. Specify empty-set semantics for each reducer;
missing, malformed or unfinished input is distinct from a known empty selection
and an actual zero-valued result. Reject ambiguous component and future-step
selectors before expenditure where structurally knowable. Keep selected results
through an existing continuation and apply the aggregate consumer only once.

No new damage measure, grouped all/any/count predicate or general collection
language here. Document selection syntax, each reducer and rounding order, run
focused development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-035 via real loaded ordered casts with multiple targets, steps and
typed components. Give values that distinguish sum, minimum and maximum, plus
an unrelated high value excluded by the selector. Verify declared target/component
selection, rounding order, actual zero, empty set, missing and unfinished input.
Same-definition actors and repeated components must not alias or double-count.

Suspend a selected child at an existing choice, resume and inspect retained
receipts; no aggregate consumer runs prematurely or repeats on old/replayed answers.
Use both loaded definitions and the actual aftermath amount/receipt, not an
independent Python formula. Invalid/future/ambiguous selectors refuse before
ordinary cast/source costs where structural validation applies.

Run affected Godot proof/gates, report exact reducers/empty semantics/selection
scope and remaining limits, leave REVIEW and STOP for batch E review of
S-030/S-031/S-035. Reuse retained VS-17 evidence for unchanged accepted sum behavior.
```

## 15 — S-044: All/any/count child-result gates

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-044 (V-011) only after S-043/S-035 acceptance and batch E review. Author
all/any/count gates over explicitly selected child attacks/saves, steps and actual
targets. Define the selected group and completion barrier: an unfinished or
suspended child cannot be treated as failure, success or absence to settle the
parent early. Empty-group and skipped-child policies must be explicit.

Use a neutral count-threshold consumer and renamed all/any consumers with
contrasting child outcomes. Reuse ordered result storage and existing choice
continuation. Apply gates to final outcomes after supported overrides/rerolls,
not provisional natural totals. Preserve multiple attempts against one target
as distinct children and same-definition targets as distinct identities.

No new attack-count/action composition or universal workflow engine. Gate
evaluation stays pure; parent aftermath and costs happen once after the declared
completion boundary. Document selector/policy syntax, run focused development
checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-044 using actual loaded multi-child attack/save and ordered aftermath
controls. Show all, any and count below/at/above threshold with mixed final results,
repeated children for one target, distinct same-definition actors, skipped children
and a known empty group under the documented policy.

Pause a selected child in a real result/damage choice. Inspect the incomplete
group and prove no premature parent effect/payment; resume, change a provisional
outcome with a supported operation and verify the gate uses the final child result.
Parent aftermath, original cast/action cost and child source spending settle once.
Missing/unknown groups, wrong occurrence/target and old/replayed answers cannot
qualify or mutate a newer parent. Renamed predicates use the same runtime.

Run affected Godot proof/gates, report exact completion/empty/skipped semantics
and host limits, leave REVIEW and STOP. Do not add arbitrary child actions merely
to manufacture another group case.
```

## 16 — S-036: Source die/choice inputs and capture policy

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-036 (V-007) only after S-016/S-023 acceptance. Expose an exact owned source
die receipt and an actual chosen numeric value as formula inputs. Author capture
versus reevaluation at a declared window. Reading a captured die never rolls again;
reevaluating live parameters must not silently reroll an already committed value.

Use neutral source-die and renamed bounded-number-choice consumers with observable
formula effects. Reuse existing captured bonus-die and owned choice routes, numeric
validation and source identities. Keep chosen range/type and source provenance
authoritative. Distinguish selecting a source from committing its die/payment,
then retain the input through later choice continuation and source/actor changes.

Scope is formula access and timing, not transferable/pre-rolled pool inventory,
new token generation or a dice allocator. Persist captured inputs only when their
actual implementing state is durable under allowed checkpoints. Document syntax
and policies, run focused development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-036 through actual source/die and numeric-choice controls with both
loaded definitions. Count one committed die and inspect its exact source/face;
repeated formula queries, menu previews and continuation do not roll again. Test
numeric choice at range edges plus wrong type/out-of-range/caller substitution.

Pause after capture, change actor stats, source parameters or an unrelated source,
and verify captured versus declared live input behavior. Removing the original
source follows the documented use/revalidation policy without borrowing another
copy's value or replaying cost. Unknown input, decline/refusal and stale/repeated
answers cannot produce a free value, extra RNG or duplicate effect.

Inspect the actual formula consumer receipt and amount. If this adds durable
captured input, check fresh-process allowed recovery and malformed-load refusal;
otherwise document its transient scope. Run affected Godot proof/gates, report
input/timing/host limits, leave REVIEW and STOP. No dice transfer inventory claim.
```

## 17 — S-037: Class-level inputs and progression tables

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-037 (V-007) only after S-036 acceptance. Extend accepted level leaves and
numeric breakpoint lookup for explicit per-class progression and declared bounded
numeric/die-size tables. Character level, each owned class level, proficiency
and selected slot remain separate inputs. Never guess an absent class row from
total level or a hard-coded named-class table.

Use loaded neutral and renamed definitions with different class keys/thresholds
and die-size values; probe a represented multiclass actor through production
formula/pool or choice consumers. Missing class levels, below-first-row policy,
invalid thresholds and unsupported dice sizes have explicit validated behavior.
S-036's capture policy governs whether a later level change updates an uncommitted
query or an already captured value. Capacity growth must not refill spent uses.

Do not add a new leveling/progression UI, catalog conversion or full multiclass
rules engine. Document input/table types, selected route and failure semantics,
run focused development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-037 through real loaded consumers using actual represented class-level
state. Contrast equal total levels with different class allocations, an absent
class and character-level scaling. Test below-first, exactly-on and between table
thresholds, numeric and die-size results, and distinct renamed progression data.

Inspect the formula/captured source value and its actual effect or rolled die,
not copied Python math. Change level before selection and after capture to prove
S-036's declared timing; independent class/source values stay separate. For any
capacity consumer, growth preserves spent quantity and shrink clamps without
reacquisition. Malformed tables/unsupported sizes/wrong input types refuse before
costs or dice. Query, decline and replay neither roll nor refill.

Check allowed recovery if new durable fields exist, run affected Godot proof/gates,
record exact tables/class inputs/routes and limitations, leave REVIEW and STOP
for batch F review of S-044/S-036/S-037. This does not certify all multiclass rules.
```

## 18 — S-038: Natural-d20 and final-total floors

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-038 (V-008) only after S-023 acceptance and batch F review. Make natural-d20
floors and final-total floors separate authored operations with exact source and
domain eligibility. Reuse accepted native floor stages/receipts from VS-26 where
they already work. Retain raw natural, effective natural, ordinary modifiers,
bonus dice, pre-floor subtotal and final total with provenance.

Use neutral natural-floor and renamed total-floor definitions with different
thresholds and a captured numeric formula where supported. Declare stage order
and which natural value governs attack critical/miss rules for the actual domain;
do not silently turn a floor into a natural 20 or success override. Preserve
Advantage/Disadvantage selection and reroll reapplication/keep policy.

Show below/equal/above boundaries, negative totals without a floor and independent
owned sources. Source removal changes later queries, not old settled receipts.
Document syntax/domain/order, run focused development checks, hand off to separate
VALIDATE and STOP. No new chosen-reroll UI in this slice.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-038 via actual supported roll controls using both loaded floor sources.
Test below/equal/above for natural and total floors, positive/negative modifiers,
captured bonus dice, a no-floor negative total, and mode-selected natural values.
Inspect every stage/provenance field and the user-visible result so a total floor
cannot masquerade as a changed raw d20.

Exercise natural 1/20 and ordinary critical/miss policy where the host supports
attacks; retain unsupported domains explicitly. In accepted mandatory-new rerolls,
prove the documented floor stage reapplies without replaying prior Inspiration/
source payment or inventing dice. Remove one source among equivalents and verify
only future eligibility changes. Wrong domain, malformed floor, missing source,
decline and stale/replayed answers cannot roll/spend or change settled receipts.

Run affected Godot proof/gates, report exact floor/domain/order limits, leave
REVIEW and STOP. Reuse prior native-floor evidence when relevant source is unchanged.
```

## 19 — S-039: AC alternatives and score setting

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-039 (V-009) only after S-024/S-004 acceptance. Author legal alternative
base-AC formulas and source-owned ability score setting/floors/caps separately
from permanent increases and conditional additive modifiers. Reuse Character,
inventory-copy and exact-source stat ownership. Do not sum mutually exclusive
base formulas or overwrite the underlying score when a temporary source applies.

Use neutral/renamed loaded definitions with distinct formulas/score values and
explicit equipment/fact eligibility. Declare selection/precedence among eligible
bases and the order of score setting/floor/cap/additive operations. Recipient
choice among incompatible equal protections belongs to S-040; use a deterministic
documented supported policy here. Missing facts cannot make equipment eligible.

Removal/expiry recalculates from still-owned sources and original stats without
reacquisition, refill or catalog mutation. Validate any new durable modifier state
under allowed checkpoints. Document source/equipment/order semantics, run focused
development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-039 through real selected feature/equipment/source and ordinary attack
controls. With both loaded definitions, contrast eligible/ineligible base-AC
formulas, equipment changes, additive bonus, score setting, floor, cap and a real
permanent increase. Observe derived AC/modifiers and actual attack outcome;
temporary setting cannot rewrite the underlying permanent score.

Acquire two independent sources, remove/expire one and verify the still-owned
formula/modifier and original stat restore correctly. Queries/eligibility changes
cannot restart grant deadline or refill a pool. Same-definition copies, missing
facts and malformed formula/policy data cannot alias or partially mutate/pay.
If a continuation captures an attack profile, later equipment cannot rewrite its
already settled AC facts contrary to the documented policy.

Check any new durable state through allowed fresh-process recovery and malformed
preflight. Run affected Godot proof/gates, record exact supported operations/order,
leave REVIEW and STOP. Do not implement recipient-choice stacking in this validation.
```

## 20 — S-040: Recipient choice and overlapping modifiers

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-040 (V-009) only after S-039 acceptance. Author stacking/exclusivity policy
and a real recipient choice among incompatible equivalent owned protections.
Equivalent numeric values still have distinct source identities and lifetimes.
Reuse existing source grants and choice ownership; do not stack an excluded
benefit just because it came from a different definition.

Use neutral/renamed protection sources with different declared compatibility
groups or values. Store the selected exact source while retaining unselected
still-owned alternatives, their original deadlines and provenance. Define what
happens when selection is removed/expired and an alternative remains; reacquisition
or a restarted clock is not fallback. Revalidate recipient/source/menu generation
before selection. Query, decline and stale answers cannot partly replace modifiers.

Any lasting selection needed at allowed checkpoints follows shared durable-state
rules; the pending menu stays transient. This is not aura membership, Temporary HP
replacement or mode acquisition. Document policy, focused development evidence,
hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-040 through actual recipient/source-choice controls with both loaded
definitions. Prove compatible bonuses combine only as declared, incompatible
protections do not, and equal-value independent sources remain selectable by
identity. Observe the selected actual stat/protection and its downstream effect.

Remove/expire the selected source with an unselected alternative still alive,
then remove the unselected source first in another case. Verify documented
fallback/choice behavior preserves original lifetimes and does not duplicate
grants or refill pools. Source/recipient loss during a pending choice, wrong actor,
decline, re-popup and completed/old-answer replay cannot replace a newer selection.
Malformed compatibility/choice data refuses before effects/payment.

Check allowed fresh-process recovery for lasting selection plus malformed-load
preflight; pending requests must not survive. Run affected Godot proof/gates,
report exact policy/route limits, leave REVIEW and STOP for batch G review of
S-038/S-039/S-040. No cross-actor aura or THP replacement claim.
```

## 21 — S-106: Chosen old/new reroll with mode/bonus

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-106 (V-089/V-012) only after S-105/S-091/S-037 acceptance and batch G review.
Extend the accepted EventDialog reroll route with an authored old/new picker only
where declared, plus declared mode and level/formula bonus for the new test.
Mandatory-new sources remain mandatory-new. Preserve original and new complete
receipts, floor stages, DC/context and provenance; keeping old doesn't reroll it.

Use neutral choose-old/new and renamed mandatory-new/mode/bonus definitions with
meaningful policy differences. Reuse exact-source preflight, canonical request
and generation protection. Declare natural-only versus whole-test and bonus-dice
keep/reroll policy, capture timing of the level input, payment when new dice are
accepted, and cancellation after new dice without allowing a free repeat roll.
Prior native/token payments and consequences cannot replay.

Do not extend to weapon/spell hosts yet (S-225) or another actor's intervention.
Document choice/bonus policy, run focused development checks, hand off to separate
VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-106 using actual loaded EventDialog event/choice, Roll, source picker,
old/new picker and Close controls. Keep old and keep new with both better and worse
replacement results, while mandatory-new has no illegal old option. Prove declared
new-test Advantage/Disadvantage and class/character-level bonus plus captured
input timing; inspect raw dice, mode, floor stages and original/new receipts.

Count replacement dice and exact payment once. Prior native Inspiration/token
cost, original check consequence and Close receipt remain correct regardless of
kept result. Test decline before dice, documented cancellation after dice, source
depletion/removal, wrong actor, re-popup/teardown and replay against a newer pending
choice. None permits free rerolls or settlement of another event.

Run affected check-context Godot proof/gates, report exact policies/host and limits,
leave REVIEW and STOP. Do not expand S-225 consumers during this validation or
assert that fresh dice must produce different faces.
```

## 22 — S-225: Weapon and shared-spell reroll consumers

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-225 (V-089/V-012/V-014) only after S-105/S-106/S-022 acceptance. Reuse
mandatory-new and declared old/new rerolls through normal weapon Attack/Extra
Attack and flat/ordered shared-spell attack/save controls. Keep one operation's
policy/receipt owner; don't copy the reroll arithmetic into each host or branch
on feature IDs. Use neutral/renamed loaded sources with distinct supported policies.

Carry captured attack profile, target, DC/AC, raw/effective natural, mode, bonus
and floor provenance through settlement. Preserve domain-specific natural/critical
rules, pre-roll token/native costs and one action/cast/source payment. Earlier
settled swings/steps remain settled; next-hit grant and damage/riders wait for
the kept final outcome. Resume a following damage/ordered choice without dropping
the selected reroll receipt.

Source refusal must finish or cancel the original captured action under documented
host policy instead of stranding it. Off-turn creatures, exploration, Death Saves
and concentration remain separate slices. Document all required consumer routes,
run focused development checks, hand off to VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-225 using actual Attack/Extra Attack, flat/ordered shared-spell picker,
target and save controls. Exercise mandatory-new and old/new policies in supported
weapon, spell attack and spell save consumers, with both loaded definitions.
Inspect captured target/profile/DC/AC, mode/bonus/floor, selected result and original/
new receipts. Include natural 1/20 and critical-to-noncritical changes.

An earlier swing/step stays settled; final miss consumes no hit-only grant/rider.
Follow a reroll with an existing damage choice and later ordered step to prove
continuation. One Attack action, cast slot/native token and selected reroll-source
payment settle as declared once. Decline, insufficient/removed source, cancel,
wrong occurrence, teardown and completed/old-answer replay add no dice/payment
and cannot strand the captured action or settle a new one.

Run targeted Godot evidence/gates for all listed routes, report missing coverage
honestly, leave REVIEW and STOP. A weapon-only pass does not accept this whole row;
off-turn, exploration, Death Save and concentration remain outside its evidence.
```

## 23 — S-099: Evasion and chosen recipient exemptions

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-099 (V-015) only after S-098/S-026 acceptance. Author qualifying Evasion-like
per-recipient damage maps and chosen target exemptions for an actual occurrence.
Eligibility uses bound actor, cause, save kind and source facts; not every
successful save or every ally is automatically exempt. Preserve the actual rolled
outcome and S-098's independent rider policy.

Use neutral data-owned recipient success/failure scaling and renamed chosen
exemption consumers with a real supported recipient-selection route. Declare
selection count/eligibility and timing before or at the authorized result window.
One recipient's exception cannot alter another's save/damage mapping or reroll
the parent cast. This task does not add S-097's general helping-actor intervention
or a shared aura; use already owned/self or caster-authorized occurrence choices.

Keep chosen runtime target identities through continuation, revalidate stale
choices before mutation and pay original cast once. Document conditions/maps/
timing, run focused development checks, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-099 through actual multi-target shared-spell and recipient-choice
controls with both loaded definitions. Contrast eligible/ineligible saves, final
success/failure and chosen/unchosen targets. Demonstrate the declared no/half/full
damage mappings, rounding and rider policy while retaining original roll receipts.

Use two same-definition targets and independent recipient protections so an
exception cannot spill into another actor. Test wrong save/cause, missing relation,
too many/duplicate/invalid targets, canceled selection and source loss during
choice. A later supported save modification/reroll must use final recipient
mapping at the documented window. Earlier targets, original slot/action/source
costs and later damage choices settle once without changing another outcome.

Inspect per-target receipts/HP/conditions; run affected Godot proof/gates, report
eligibility/selection/host limits, leave REVIEW and STOP for batch H review of
S-106/S-225/S-099. Do not claim group Evasion or general cross-actor budgets.
```

## 24 — S-100: Other declared result-payment predicates

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-100 (V-035) only after S-019/S-094/S-043 acceptance and batch H review.
Extend accepted pay-on-choice/converted-success semantics with explicit supported
final success/failure payment predicates. Reserve/commit/refund only the selected
exact owned resource according to declared policy; required upfront availability
remains a separate condition. No parent action/cast or sibling-source refund.

Use neutral pay-on-final-failure and renamed pay-on-final-success consumers with
distinct amounts, making reservation and final quantity observable. Define whether
reservation locks quantity or pre-spends it, and cancellation/refusal after a
pending choice. Preserve one original roll and final outcome across bonus/reroll
and later continuation; predicate evaluation is not permission to roll again.
Revalidate source state without charging another equivalent source.

Requests/reservations stay transient at existing checkpoint boundaries. No generic
currency/slot exchange, allocator or cross-actor budget in this slice. Document
policy/state transitions, run focused development checks, hand off to separate
VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-100 through actual already-supported source/roll-choice controls using
both loaded payment policies. Prove final success and failure, conversion and
remaining outcome, exact selected quantity at reservation/commit/refund, and
insufficient upfront funds. Original action/slot/native payment and unselected
pools stay correct and are never refunded as the selected resource.

Pause through a supported bonus/reroll and later choice, then inspect one final
predicate settlement. Decline/cancellation follow authored policy; source depletion/
removal, wrong actor/source, host replacement and old/completed replay cannot
double-charge, refund twice or release another request's reservation. A settled
request leaves no hidden lock; a later valid use remains possible. Malformed
payment predicates refuse before dice/cost/effects.

Run affected Godot proof/gates, report exact supported predicates/resources/hosts
and state transitions, leave REVIEW and STOP. Reuse existing accepted payment
proof rather than broad reruns; do not generalize all resources from one pool.
```

## 25 — S-109: Component versus whole-occurrence damage edits

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-109 (V-016) only after S-034/S-041 acceptance. Author fixed/formula reduction
of one selected incoming typed component versus a whole damage occurrence at a
named supported stage. Reuse CombatAction/WardRules settlement and canonical
receipts. Document order relative to mitigation, wards, Temporary HP and HP,
plus integer rounding, floor at zero and whole-occurrence allocation/overflow.

Use neutral component-only and renamed whole-occurrence consumers with mixed
damage types and different reductions. Preserve component identities and exact
causal occurrence; reducing Fire cannot erase an unrelated Cold component unless
the whole-occurrence policy explicitly assigns reduction there. Record prevention
before HP and aftermath. A zeroed incoming amount cannot still consume later
damage-only resources contrary to existing declared rules.

If optional, reuse the supported source-choice boundary and once-only payment;
don't create S-097's general intervention or S-111's split damage. No full combat
refactor. Document stages/amounts/overflow, run focused development checks, hand
off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-109 through actual supported incoming damage/source controls using
both loaded definitions. Use mixed typed components and reductions smaller than,
equal to and larger than the selected component/whole occurrence. Prove stated
allocation, zero floor, overflow and stage order with Resistance/Immunity, an
existing ward and Temporary HP where those distinguish receipts.

Inspect raw, prevented, resolved, absorbed and HP-loss fields plus actual HP,
ward/THP state and downstream aftermath. Formula amounts must read the declared
captured/live input. A final attack miss cannot trigger damage spending. For a
pending choice, decline, unavailable/removed source, wrong component/occurrence,
teardown and replay add no payment or repeated prevention/damage. Mixed targets
and exact-source copies remain independent; original action/cast cost stays once.

Run affected combat/effects/spells Godot proof and gates, report supported stages/
policies/routes and limits, leave REVIEW and STOP. Do not claim bypass, redirection
or every incoming-damage host from a single checked consumer.
```

## 26 — S-110: Precisely scoped mitigation bypass

### BUILD

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its BUILD contract.
Build S-110 (V-016) only after S-109 acceptance. Author bypass of specifically
selected Resistance, Immunity, ward or prevention layers for an eligible typed
component/occurrence. Carry policy on the actual source/profile and bind the
qualifying component. 'Ignore Resistance' is not 'ignore all protection'; unrelated
layers/components continue through normal settlement.

Use neutral Resistance-only and renamed independently scoped Immunity/ward/
prevention consumers to exercise the listed layer kinds without identity branches.
Validate layer enums, stage and eligibility before cast/action payment; don't
silently treat an unsupported named layer as implemented. Reuse S-109 stage
receipts so bypassed versus actually prevented amount stays observable. Temporary
HP remains absorption unless the selected explicit operation supports otherwise.

Preserve critical/component scaling, causal identities, once-only source costs
and later aftermath. No reflection, damage splitting or universal mitigation
rewrite. Document exact bypass syntax/layers/order and targeted development
evidence, hand off to separate VALIDATE and STOP.
```

### VALIDATE

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its VALIDATE contract.
Validate S-110 using actual supported attacks/shared-spell damage and the loaded
bypass sources. Build combinations that distinguish Resistance-only, Immunity-only,
ward-only and prevention-only bypass. Show the unselected layers still operate,
unrelated typed components still mitigate normally, and another source's action
does not inherit this bypass. Include unchanged ordinary damage as a comparison.

Inspect raw/prevented/resolved/absorbed/HP-loss receipts, actual ward/THP/HP state,
critical/fixed-component policy and final aftermath. Wrong source/type/domain,
unsupported layer/invalid stage and stale/replayed answers cannot pay, disable
protection globally or repeat damage. Through an existing pending damage choice,
the canonical profile/bypass policy survives without replacing another occurrence.

Run affected Godot proof/gates, record precisely which layers/stages/hosts were
demonstrated and any missing required layer, leave REVIEW and STOP for batch I
review of S-100/S-109/S-110. A Resistance-only result is not full S-110 acceptance.
```

## Batch REVIEW prompts

Copy the matching review prompt after that batch's separate BUILD/VALIDATE pairs.
Per-slice acceptances permit dependencies inside a batch; the batch review checks
interactions and finishes its cards. Reuse accepted evidence, don't count it again.
These are fresh-chat reviews, not requests to spawn or keep a reviewer running.

### A — S-024 / S-025 / S-041

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-024/S-025/S-041 source and separate production
evidence. Question: can a missing fact, wrong entity or stale window cause an
otherwise ineligible effect, roll or payment? Inspect missing-under-not and mixed
branches, runtime source versus definition identity, canonical actor/item/action
bindings through continuation, five-window ordering and no damage spending on miss.

Use the original S-024 card/evidence plus S-025/S-041 reports under
.artifacts/planning/vocabulary-reports/. Inspect actual receipts/costs and current
affected source. Reproduce the recorded integral-JSON-number scalar-healing parser
mismatch; fix and target-check a confirmed bounded parser defect, or explicitly
retain a concrete unresolved limitation/card. Fixture string syntax must not hide
it. Do not turn that finding into a catalog rewrite or global schema migration.

Reuse green evidence and run only demonstrated affected reproductions/corrections.
Reconcile existing exact acceptances or pending ones without double-counting,
finish valid batch cards and leave any gap honest. Record review findings/evidence
in .artifacts/planning/vocabulary-reports/batch-A-review.md. Replace stale current
queue text, leave S-091 BUILD as the next action if ready, and STOP. No dispatch.
```

### B — S-091 / S-092 / S-095

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-091/S-092/S-095 source and separate production
evidence. Question: do pre-roll mode policies and post-roll outcome/defensive edits
respect distinct stages, then settle one final result before damage? Inspect mode
source exemptions/cancellation, raw natural versus effective total/explicit outcome,
natural-1/20/critical rules, captured AC/profile and decline/stale-source fallback.

Check a converted hit-to-miss consumes no hit-only grant or damage-side resource,
while original action/cast payment and earlier swings/steps remain settled once.
Inspect canonical receipt/source/window ownership through a following choice and
old answers against new occurrences. Use each slice's validation report and actual
logs; don't manufacture a universal host matrix or rerun unchanged broad groups.

Fix only reproduced shared-boundary defects with affected current-source proof.
Reconcile precise slice/VS states, counts, contracts and cards without double-counting.
Record .artifacts/planning/vocabulary-reports/batch-B-review.md. Leave S-034 BUILD
as the next action if ready, and STOP. Other-actor interventions and no-roll/Death
Save cancellation remain outside this batch; no automatic worker dispatch.
```

### C — S-034 / S-043 / S-098

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-034/S-043/S-098 source and separate production
evidence. Question: do selected settled receipts, margin/HP gates and independent
damage/rider mappings all refer to the same final occurrence without reading
later live HP or a different component/target? Inspect prevented/absorbed/healed
semantics, component ambiguity, same-definition actors, missing versus real zero,
override margins, rounding, half-damage misses and hit-only riders.

Trace one retained earlier result through a later actual choice and supported
outcome modification. No original cost, damage, aftermath or rider may settle
twice or prematurely. Verify flat/ordered supported routes from actual logs and
state, not total assertion counts. Reuse reports/evidence; only reproduce concrete
gaps and target-check corrections. Missing planned measures/routes remain partial.

Reconcile exact slice/VS entries, counts, contracts/checkpoint and batch cards.
Record .artifacts/planning/vocabulary-reports/batch-C-review.md. Leave S-026 BUILD
as next action if ready and STOP. No content conversion or general reducer work
belongs to this review, and no worker is dispatched.
```

### D — S-026 / S-027 / S-029

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-026/S-027/S-029 source and separate production
evidence. Question: can eligibility accidentally borrow another giver, consent,
location, sense or save cause? Inspect live allegiance and explicit willingness,
two same-kind charm/mark givers, exact-source removal, range endpoint identity/
units/equality, and purpose/source distinctions for otherwise identical saves.

Trace capture/revalidation across actual choices, unavailable entities/senses,
and wrong caller metadata. Unknown willingness or unlocated source cannot qualify
as consent or zero distance. Check any newly durable relation state with the
retained fresh-process/malformed-load proof. Queries must not reset pools/deadlines.
Use per-slice reports and actual control receipts; do not expand into perception,
auras, social AI or free-text interpretation.

Fix only demonstrated defects and run affected checks. Reconcile exact accepted
scope/counts/docs and finish valid cards. Record
.artifacts/planning/vocabulary-reports/batch-D-review.md. Leave S-030 BUILD as the
next ready action and STOP; no dispatch or new independent reviewers.
```

### E — S-030 / S-031 / S-035

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-030/S-031/S-035 source and separate production
evidence. Question: do histories count actual events within the right interval,
and reducers select each settled result exactly once? Inspect first round versus
first own turn, refused/canceled actions, hit/miss history, owner-turn resets,
time equality/jumps, causal source identity and raw/prevented/absorbed/HP-loss.

Inspect sum/min/max selection, repeated components/targets, empty versus missing
or unfinished inputs and rounding. Paused child completion cannot add history or
aggregate twice; menu/scene changes cannot fabricate reset. Check durable time
history through retained fresh-process state/load-preflight evidence and transient
encounter cleanup. Reuse logs/reports and run only a concrete missing reproduction
or affected correction, not an all-groups repeat.

Reconcile exact accepted boundaries, counts, contracts and cards. Record
.artifacts/planning/vocabulary-reports/batch-E-review.md. Leave S-044 BUILD as next
action if ready and STOP. No unbounded campaign journal or worker dispatch.
```

### F — S-044 / S-036 / S-037

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-044/S-036/S-037 source and separate production
evidence. Question: does a consumer wait for final children and use the correct
captured die/choice/class-level value without a new roll, guessed class level or
pool refill? Inspect all/any/count completion barriers, skipped/empty/missing
groups, exact captured source/face, numeric-choice validation, live versus captured
inputs and class/character-level versus selected-slot/proficiency distinction.

Check threshold/row and die-size validation, changes before/after capture, two
independent class/source inputs and any capacity growth/shrink. Use real control
receipts and actual RNG/cost evidence from reports, plus durable recovery only
where new lasting fields exist. Reuse accepted VS-16/17/23 proof; investigate only
specific source/evidence gaps, then target-check corrections.

Reconcile exact acceptances/counts/contracts/cards and record
.artifacts/planning/vocabulary-reports/batch-F-review.md. Leave S-038 BUILD as next
action if ready and STOP. No leveling UI, transferable dice inventory or automatic
next worker is part of this review.
```

### G — S-038 / S-039 / S-040

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-038/S-039/S-040 source and separate production
evidence. Question: do authored floors/stat alternatives/protection choices retain
distinct stages and exact source ownership instead of rewriting base stats or
stacking incompatible benefits? Inspect raw/effective natural, pre-floor/final
total and critical/miss policy, legal base AC versus additive modifiers, score
setting/floor/cap versus permanent increases and equal-value source identities.

Trace removal/expiry/fallback to still-owned alternatives with original deadlines,
recipient choice invalidation and no grant reacquisition/pool refill. Inspect
lasting selection/stat provenance through fresh-process checkpoints and malformed
load refusal; pending menus stay transient. Reuse native-floor and unchanged
source-state evidence. Reproduce only specific defects and run affected checks.

Reconcile exact scope, counts, authoring/checkpoint docs and cards. Record
.artifacts/planning/vocabulary-reports/batch-G-review.md. Leave S-106 BUILD as next
action if ready and STOP. This is not aura or THP-replacement acceptance and does
not authorize dispatching a worker.
```

### H — S-106 / S-225 / S-099

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-106/S-225/S-099 source and separate production
evidence. Question: after a reroll and any recipient exemption, does each actual
host settle the kept final outcome once with unchanged original costs and correct
per-target consequences? Inspect mandatory-new versus legal old/new, new-test
mode/level bonus/floors, raw natural/critical policy and retained original/new
receipts in EventDialog, weapon/Extra Attack and flat/ordered spell attack/save.

Trace pre-roll token/native payments, canceled/new-choice generations, depleted
source fallback, earlier swing/step retention, following damage choices and
next-hit/rider consumption only at final hit. Chosen exemptions cannot alter
unselected targets or reroll their save. Inspect actual UI/commands, dice event/
face counts and per-target receipts from all required routes; a missing route
cannot become full acceptance by a large helper assertion count.

Fix reproduced boundary defects, run affected current-source checks and reconcile
scope/counts/docs/cards. Record
.artifacts/planning/vocabulary-reports/batch-H-review.md. Leave S-100 BUILD as next
action if ready and STOP. Other actors, off-turn creatures, exploration, Death
Saves and concentration remain outside this batch; no dispatch.
```

### I — S-100 / S-109 / S-110

```text
Read docs/planning/vocabulary-prompt-workflow.md and follow its REVIEW contract.
Independently review completed S-100/S-109/S-110 source and separate production
evidence. Question: do final-outcome payment, component/whole reduction and scoped
bypass settle one causal occurrence in the declared order without double refund,
cross-component leakage or disabling unrelated protection? Inspect selected
resource reservation/commit/refund and upfront funds, original parent payments,
canonical occurrence/component identity, prevention/overflow/rounding and each
named Resistance/Immunity/ward/prevention layer independently.

Trace a pending result/damage choice to one final receipt, source refusal and old
answer against a new occurrence. Retained layers and unselected components must
still mitigate; THP absorption and HP-loss remain distinct. Use actual state/
receipts/exits, not copied formulas. Reuse prior proof and run only reproduced
gaps or affected corrections; missing layer/route evidence stays partial.

Reconcile exact slice/VS entries and derive current totals rather than writing
the pack's 53/226 projection blindly. Finish valid cards and record
.artifacts/planning/vocabulary-reports/batch-I-review.md. Summarize remaining
parents/hosts and leave selection of the next roadmap slice as the next action.
STOP at the end of this requested pack. Do not start a new batch or dispatch work.
```
