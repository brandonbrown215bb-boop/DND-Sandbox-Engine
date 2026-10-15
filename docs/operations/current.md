# Current development checkpoint

## S-026 accepted as VS-36; Batch D review is next (2026-10-14)

S-026 passed separate production validation through the real Character Sheet
willingness choices, CombatHUD spell picker and target click, loaded neutral and
renamed consumers, exact-giver removal, safe save/load and fresh-process recovery.
The [validation report](../../.artifacts/planning/vocabulary-reports/S-026-validation.md)
records the routes, receipts, costs, artifacts and limits. The focused integration
scenario passed with 0 failures; bootstrap, 186-script parse and production boot
also passed. The fresh Godot child process restored the saved Unknown/Unwilling
values. Malformed willingness was refused before the live campaign was replaced.

S-026 is **VS-36**. The registry now has **36/226 accepted, 190 not yet accepted**;
P1 has 14 verified slices. S-027 is eligible as the next dependent BUILD. Keep the
S-026 card in REVIEW for Batch D's independent shared-boundary review after the
S-027 and S-029 validations. V-002 remains partial: this acceptance covers
represented player/monster relations, explicit willingness and exact source-owned
records. Missing/ambiguous membership has no selectable combat target, so its
unavailable result was checked through the production fact reader. Native Hunter's
Mark, general factions, social AI and free-text consent remain outside the evidence.

The existing DataLoader warning about 25 unsupported effectless feature records
remains unrelated. The S-025 actual binding/Portent continuation scenario was
reused from its unchanged source and passed at
`.artifacts/tests/1ced11dfc1704b63acbaecf7c54c53c6/`.

## Retained P3 validation — roll mode and explicit outcomes (2026-10-14)

The earlier VS-30 validation covered S-092's source-owned explicit hit/miss and save success/failure
overrides at the supported rolled-result windows. Separate production routes
passed through the actual CombatState normal player Attack, shared-spell attack
and shared-spell save controls. Natural d20, mode, modifiers, total and AC/DC
remain numeric facts; final receipts retain the separate outcome and exact
source. Natural 1 forced hit is not a critical by itself; a forced natural-20
miss suppresses critical damage. Saves keep their natural/total/DC comparison
facts while the selected override controls success/failure consequences.
Damage/riders wait for the final outcome, costs and earlier ordered results
settle once, and the later ordered damage choice retains its attack receipt.
No-roll outcomes, canceled Death Saves, concentration/non-shared saves, other
attack hosts, cross-actor intervention and general token replacement remain
outside S-092. V-013 remains partial.

`post_roll_die_bonus_flow`, `shared_spell_attack_bonus_flow` and
`failed_save_numeric_bonus_flow` passed with bootstrap, 185-script parse and
boot gates at `.artifacts/tests/e221b42086ca47538621a9bd94764124/`,
`.artifacts/tests/791d3bad8fa547fd8d2bdf68a0fa68aa/` and
`.artifacts/tests/a4c8372b8cf14f68933893e4b4eb943a/`. Focused spells logic passed
1,033/0 at `.artifacts/tests/995db1031b034800bcda7c69ed3c6129/`. The validation
details and exact routes are in the [S-092 report](../../.artifacts/planning/vocabulary-reports/S-092-validation.md).

VS-29 accepts S-091's pre-roll mode policy for loaded EventDialog event and
choice-owned ability checks. Exact bound check context and source provenance
control eligibility. Duplicate grants retain each contribution but produce one
two-face test; surviving opposite modes cancel to one d20. Exact-context
cancel/prohibit policies retain exempt sources and record suppressing sources.
The pure query does not roll/spend, and commitment rereads live ownership. The
closed receipt retains effective mode, natural result and exact contributors.
Neutral and renamed data select different policies without ID branches. Its
actual Roll/choice/Close route, required gates and focused logic passed; details
are in the [S-091 report](../../.artifacts/planning/vocabulary-reports/S-091-validation.md).
S-105's captured-mode provenance and pre-roll Portent replacement remain
distinct; replacement is `replaced`, with existing token cost/zero-d20 behavior.

Those original validation results preceded the completed review repairs above.
S-091 and S-092 remain accepted; Batch B is complete with S-095 accepted as VS-32.
S-034 is reconciled as VS-33 from its retained separate production validation;
S-043 and S-098 are now validated and Batch C review is complete. The only warning in successful focused
control runs is DataLoader's existing rejection of 25 unsupported effectless
feature records.

## Accepted P1 slice — actor/action/item/source fact bindings (2026-10-14)

VS-28 accepts S-025's combat shared-spell identity binding boundary. The real
CombatHUD picker, target click and Portent save choice carry the captured caster,
target, Magic action and invocation, exact material-copy ID, spell definition and
invocation, and owned source definition/owner/generated instance into the
existing continuation. Loaded neutral and renamed definitions select different
actors, targets, amounts and sources. Two same-definition material copies prove
only the selected copy is consumed on each cast; each cast pays one slot/action,
settles its effect once and preserves both generated source receipts.

Actual controls passed ten assertions with bootstrap, 185-script parse and boot
at `.artifacts/tests/8aba2a55df174f94ac708b5f2741b3f5/`. Current focused spells
development passed 1,017/0 at
`.artifacts/tests/ff3da86e36e14e0880de43264b33d92e/`. Replay refusal checks emit
the expected already-settled warning; DataLoader continues to report 25
unsupported effectless features unavailable. There were no parse/runtime errors
or test-owned leaks. Direct host resolution still lacks action/invocation/item
facts; this does not close broader V-001 or add other hosts. The exact field
syntax and limits are in the [S-025 report](../../.artifacts/planning/vocabulary-reports/S-025-validation.md).

The plan was 28/226 accepted at VS-28. S-041 was subsequently validated before
S-091 BUILD; subsequent independent review and repairs accepted S-041 as VS-31
and closed the scalar-healing parser defect. See the final batch above.

## Accepted P1 slice — nested shared fact predicates (2026-10-14)

VS-27 accepts S-024's bounded shared-spell eligibility predicate boundary.
`SharedStepExecutor` keeps the existing fact allowlist, validates typed scalar
comparisons and nested `all`/`any`/`not`, and preserves unavailable facts as
unknown through negation and mixed branches. Present false and numeric zero
remain distinct. Malformed/unknown facts and wrong comparison types refuse
before costs or effects. Predicate reads use the captured caster, current target
and spell/source context; they do not acquire, spend or reset a source pool or
timed grant.

Production controls used the real CombatHUD spell list, cast command, target
click and ordered step/effect settlement with loaded neutral and renamed
definitions. The 11-assertion `shared_fact_predicate_flow` and bootstrap,
185-script parse and boot gates passed at
`.artifacts/tests/0a100c3d32f940e0963733ee0068fb4f/`. Retained focused development
passed 1008/0 at `.artifacts/tests/518f20b7b66f4fac89e05da449f01a91/`. The later
review repair batch above reran the actual predicate controls and full logic
and closed the integral-JSON-number scalar-healing parser mismatch. This proves only
ordered shared-spell step/effect eligibility through that combat host; broader
fact bindings, other hosts and V-001 remain open. S-025 is accepted as VS-28;
S-041 is now accepted as VS-31 after the reviewed consumer repair.

## Accepted check context, modifiers and mandatory-new rerolls (2026-10-13)

VS-24 accepts explicit task/purpose/optional-tool context in loaded EventDialog
event and choice-owned checks. The real Roll/choice/Close controls preserve the
actor, original roll/DC, loaded context and exact carried-tool copy/effect/location
in `event_resolved.check_result`. A matching authored tool bonus modifies only
its qualifying check; unrelated tasks, unknown purposes, wrong/missing tools
and another actor's inventory do not qualify. Removing one copy preserves the
other; an independent renamed tool survives removal of both original copies.
No-tool/no-bonus and undeclared checks retain ordinary behavior. Unknown or
ambiguous authored sources refuse before rolling or consequences; copied popup
fields cannot replace loaded check/consequence records. The host's ordinary
resource/action cost is zero and its gold consequence settles once.

Final actual controls passed 37/0 with bootstrap, 185-script parse and boot at
`.artifacts/tests/cb2fd72d5f044643a138bd11ad15f6e7/`. Unchanged focused development
passed 18/0 at `.artifacts/tests/e4b85fd4e79b45f59da411597d342ba5/`. No runtime
correction or unrelated gameplay group rerun was needed during acceptance.
This context evidence is the loaded event host only; local-room checks,
sensory/save purposes, free-text interpretation and the broader V-003 remain open.

VS-25 separately accepts one owned fixed/die bonus on a failed loaded EventDialog
skilled or ability-only check, including a choice-owned check. The original
natural/modifier/DC/context and native Inspiration remain captured before the
bonus; no new d20 is rolled. Both payment policies require upfront funds, charge
their exact source as declared and preserve the unselected pool. One accepted
die rolls once. Query, decline, stale/empty/removed/forged sources and completed
replay cannot roll or spend. Consequences wait for settlement and Close retains
the same final receipt. Re-popup and teardown cancel only that host's request,
and old answers cannot settle a replacement event/actor.

Final actual controls passed 69 assertions with clean bootstrap, 185-script parse
and boot at `.artifacts/tests/136995fdd7b64e9d884b127a223518c5/`. Root inspected
the loaded choice-owned modifier and completed replay dice/pool/gold/receipt
snapshots before acceptance. Retained development is 898/0 check_context/classes
at `.artifacts/tests/f7ecaba2888642798e141138b10870b3/`; no runtime change or broad
green rerun was needed during acceptance. This does not certify other roll hosts,
rerolls, concentration, Death Saves or broader V-014/035.

VS-26 accepts an owned mandatory-new natural or whole-test reroll in that same
loaded EventDialog, including choice-owned checks. One menu offers eligible
numeric bonuses and rerolls as alternatives. The selected reroll retains the
declared Normal/Advantage/Disadvantage and bonus-dice policy, keeps the new result
even when worse, and preserves original/new receipts, captured DC/context and
floor stages. Native Inspiration is paid once; preflight and current-source
validation precede replacement dice/payment. A negative check without a floor
stays negative. Consequences and Close settle once; stale/refused/replayed
answers do not roll or spend, and host replacement/teardown stays isolated.

Final actual controls passed 107 assertions with direct Godot exit code 0 at
`.artifacts/tests/a74c2363968243108dacc86f68a9ff5b/check_context_flow_final/`.
Bootstrap, 185-script parse and boot passed in its parent directory. Root
inspected source, final receipts and logs and completed the combined trio review.
The only stderr warning is the existing 25 unsupported effectless features.
Other roll hosts, automatic/no-roll checks, old/new selection and another
modifier pass remain open; V-089 is partial.

At VS-28 the [slice plan](../planning/vocabulary-slices.md) had 28 accepted of
226. S-024 and S-025 were verified. S-041 was validated before S-091 BUILD;
the subsequent repair batch closed its authored-consumer and integral JSON
scalar-healing defects and accepted S-041 as VS-31. The Quest Board owns the exact stage.

## Accepted P3 attack/die batch (2026-10-13)

VS-21 accepts one owned fixed post-roll bonus through normal player weapon
Attack/Extra Attack. The actual controls retain one action payment and one
d20 per swing; final settlement owns damage and next-hit consumption. Clean
production acceptance with bootstrap/184-script parse/boot is retained at
`.artifacts/tests/258a67b64044400b9405460eebfa2cd9/`. Canonical Stroke request
validation was repaired before acceptance; latest focused classes passed
841/0 at `.artifacts/tests/8545cd6719474f4bb5d1347b933a8299/`.

VS-22 accepts flat/ordered shared-spell attack reuse through actual spell
picker/target/source controls, including prior Portent and following Empowered
damage choices, conditional hit/miss payment, natural 1/20 boundaries, an earlier
settled step and old-answer/new-choice protection. Clean required-gate acceptance
is `.artifacts/tests/41ebf1088d3f45608d4db6798ec5fd4c/`; latest affected spells
passed 991/0 at `.artifacts/tests/631f2a31408c41ecbaae002be6161fba/`.

VS-23 accepts one captured d6/d8 bonus in the checked save, normal weapon and
flat/ordered shared-spell attack choosers. Real controls prove conversion and
remaining failure, both payment policies, exact source costs, no bonus dice on
query/decline/refusal/replay, and a retained source receipt through a following
damage choice. Final controls/gates are at
`.artifacts/tests/ad3f0ddaaa89478881f5ea2fdee90721/`; current affected spells
passed 1001/0 at `.artifacts/tests/0a0afca82e60469a944f05278b6dc281/` and retained
affected classes passed 849/0 at `.artifacts/tests/0948178dfbd84aefaa58c1d1fe0f6343/`.

Combined review closed canonical target/Stroke validation, a stale selected
spell source stranding its original roll, and weapon-only Stroke accepting a
spell request. Source depletion now finishes the captured spell miss without
rolling/spending the invalid bonus; a subsequent cast remains usable. The final
weapon checks prove conversion under each policy and no state change on replay.

The accepted attack/die trio is retained evidence. Wider parents and other hosts
remain open; the current counted scope and selected check trio are stated above.
Static planning added no gameplay evidence or catalog conversion.

## Latest accepted batch — post-roll shared-spell save choices (2026-10-13)

VS-18–20 add one optional owned fixed bonus after a rolled failed save,
pay-on-choice or pay-only-on-converted-success settlement, and an explicit
success override that preserves the natural d20, total, modifier and DC. The
real combat chooser selects one exact source; original cast costs and earlier
outcomes settle once. Neutral and renamed definitions use different abilities,
amounts and costs through the same runtime.

Combined review closed Inspiration snapshot loss, dropped ordered choices,
premature advancement before a following damage choice, early flat failure
riders and live DC recalculation. Focused development passed 978/0 with
parse/boot at `.artifacts/tests/7e616a3d05634cafb29e9cae10a3f05b/`. The clean
production scenario proved ordered/flat consequences, distinct sources,
cancel/refusal, old completion against a new pending choice, and cleanup at
`.artifacts/tests/10c21f9d43cd48a0b7016eda80955c6e/`. Earlier VS-18/19 evidence
is retained in the checklist; no unchanged broad groups were repeated.

This boundary covers the owner's matching rolled saves against shared spells
in the interactive combat host. Other rolls/hosts, automatic no-roll outcomes,
cross-actor help, dice bonuses and reaction budgets remain open. Decisions stay
transient. Attack-result choices are the next selected batch in the roadmap.

## Accepted slice — source-owned timed numeric modifier (2026-10-12)

The first P2 effect-lifetime build adds an exact-source self grant: a shared
class-feature activation spends one numeric pool use and grants +2 AC for 60
campaign seconds. The active grant stores owner, source instance, grant
instance, captured modifier and absolute deadline. One active grant per source
is enforced before payment; separate sources add under the existing numeric
modifier behavior. Campaign-time advancement expires it, combat turn ticks do
not, and the existing exact-source pool removal clears only its contribution.
Allowed Character checkpoints now preserve and validate the grant data.

The production validation loaded neutral and renamed definitions through
`DataLoader`, activated through the combat feature menu, and proved payment,
the +2 AC contribution, pre-payment duplicate refusal, staggered exact-source
expiry/removal, turn-tick independence, real combat and exploration clock
progression, and scene-change persistence. A fresh process recovered the exact
owner/source/grant serial/payload/deadline through an allowed checkpoint without
replay or deadline restart. Production `SaveManager` preflight refused a
malformed full save before replacing the live session. Evidence:
[scenario](../../.artifacts/tests/87fcf43330404d1cae293993aa8e7595/) and
[fresh-process probe](../../.artifacts/tests/timed-numeric-grant-relaunch-0f1cceb0b6ac4904b444f1e2482cadb4/).
This checks only the timed numeric self-grant subset recorded as VS-12; broader
V-027/V-049/V-057 requirements remain open.

## Accepted slice — next-matching melee-hit grant (2026-10-12)

The accepted boundary is one source-owned, next qualifying melee weapon-hit
grant. The neutral feature spends one numeric pool use and schedules fixed +2
Fire for 60 campaign seconds. Fixed typed damage accepts amounts 1–100 and
existing damage types; production acceptance also loaded a renamed +3 Cold
definition. The grant captures owner, exact source, unique grant ID, acquisition
order, matcher, payload and absolute deadline. It is consumed at final hit
resolution before damage settlement, and fixed damage does not double on a
critical. Misses, ranged hits, canceled targeting and another actor's attacks
do not consume it. Exact-source removal and campaign expiry clear only that
source's unspent grant. Character checkpoints preserve and validate pending
grant identity, order, payload and deadline.

Production acceptance used the real DataLoader, feature menu and weapon resolver.
It proved one payment and duplicate refusal; cancellation, ranged hit, miss and
another-owner retention; critical +2 Fire through resistance, Fire immunity,
and renamed +3 Cold through resistance; rearming after an old hit completion;
source order, downing consumption, exact-source removal, and staggered exact
expiry with a large clock jump. A fresh prepare/recover pair preserved ordered
owner/source/grant/payload/deadline state without payment replay or timer reset;
malformed full-save preflight refused before replacing the recovered session.
Evidence: [production scenario](../../.artifacts/tests/4370e8a4ce7d4d1291bbdda17786aa86/),
[fresh-process probe](../../.artifacts/tests/next-melee-hit-grant-relaunch-286d5a6bdb03400eb9acdfab1481088b/),
and [focused class checks](../../.artifacts/tests/d5c63ce1d7e042f7b27ca3f73b5e7bad/).
The bounded checked subset is VS-13 (`V-051`, the final-hit portion of `V-010`,
and this allowed-checkpoint state); broader event facts and matching rules remain
open.

## Accepted slice — optional cooldown after timed-grant end (2026-10-13)

An optional `cooldown_seconds` value now works on the bounded timed AC grant.
The authored duration is captured with the active grant. Expiry starts the
cooldown at the scheduled expiry deadline; the exact-source combat feature menu
also exposes free voluntary dismissal, which starts it at the current campaign
time. Pool refill does not clear a cooldown, and campaign-time advancement
settles both deadlines from absolute times. The optional field can be omitted or
set to zero to retain the accepted VS-12 behavior.

Production acceptance loaded neutral +2 AC/60/3600 and renamed +3 AC/120/7200
definitions, plus omitted and zero-cooldown VS-12 forms. Real combat-menu use
and free exact-source dismissal proved one pool payment, pre-payment blocking,
unchanged action budget, scheduled-expiry vs actual-dismissal cooldown origin,
independent deadlines and exact readiness. A completed Short Rest refilled a
pool but did not bypass the other source's cooldown; a single clock jump past
both deadlines left both sources ready. A fresh prepare/recover pair preserved
an active grant and a cooldown-only record in distinct processes without replay
or deadline restart. Malformed full-save preflight refused before replacing the
live session. Evidence: [production scenario](../../.artifacts/tests/2b29a42808f848dcb577f74d69d88500/)
and [fresh-process probe](../../.artifacts/tests/timed-numeric-cooldown-relaunch-1bd96120f7504b64a3e1933fbe653946/).
The accepted subset is VS-14 (`V-045`/`V-056`, with `V-027`/`V-049`/`V-057`). Expiry and
voluntary dismissal are the only cooldown-starting end reasons certified.
Exact-source permanent removal clears its active grant without starting a
cooldown and removes only its retained cooldown; other end reasons remain unsupported.

Combined review closed two defects: tagged timed/cooldown state now requires
its owned saved source pool and deadline, and duplicate same-kind grant
operations refuse during content loading before costs. Genuine untimed modifiers
remain valid. Focused correction evidence passed 779 class checks with no failures
at `.artifacts/tests/14659d0b264d4be5ba3eab380d51663c/`; the extended fresh-process
probe above refused orphaned active/cooldown sources and missing deadlines
before replacing live state. No unchanged production scenarios were repeated.

## Accepted slice — source-owned timed Temporary HP (2026-10-13)

The bounded V-052 slice supports one expiring Temporary HP grant per exact
source. Activation captures its amount, owner, source, grant identity and
absolute campaign deadline. Only a strictly larger offer replaces current
Temporary HP; lower/equal offers keep both the current amount and provenance.
Damage absorption retains provenance while any amount remains, clears current
ownership at zero, and never restores a spent buffer on query, load or expiry.
Expiry/removal clears the amount only when that exact grant still owns it, so a
later timed or ordinary replacement survives an older source ending. Existing
ordinary class Temporary HP expressions now receive their declared ability
modifiers, including Ranger Tireless.

Production acceptance loaded neutral 10/60 and renamed 16/120 definitions
through DataLoader, activated through the actual feature menu, and proved one
pool payment plus pre-payment duplicate refusal. False Life and lower/equal
offers preserved the current grant; actual partial/full damage, exact deadlines,
source removal and a large time jump preserved or cleared only the right state.
The real Ranger Tireless feature replaced the grant after a partial hit. Checks
also covered zero-HP damage/death-save failure and Death Ward settlement. A
distinct-process prepare/recover probe preserved remaining amount, provenance,
serial and deadlines; production SaveManager refused missing grant fields,
deadlines and source pools before replacing the live session. Keep-higher is the
selected rule: no replacement-choice UI, cross-actor grant or linked benefit is
certified. Evidence: [production scenario](../../.artifacts/tests/6cca603c5a014e8d99288d0843682c46/),
[fresh-process probe](../../.artifacts/tests/timed-temporary-hp-relaunch-5fd6758079e74199b7c9812a74449492/),
and [focused class checks](../../.artifacts/tests/3882353fdd354207a6b9407d99d84424/).
The checked subset is VS-15 (`V-027`, `V-052`, `V-057`); broader grant domains
and linked Temporary HP effects remain open.

Numeric breakpoint lookup (V-007) is now production checked as VS-16. Neutral
and renamed tables passed through DataLoader, real feature-menu pool payment,
capacity growth/shrink, malformed-table rejection, and an ordinary shared spell
consumer. The accepted operation selects the greatest integer threshold not
above its deterministic numeric input; below-first and failed nested inputs
propagate failure. Dice tables, choices, source dice, multiclass progression,
and broader capture policies remain open. Evidence: [focused production
scenario](../../.artifacts/tests/8b686402e0fb4369b57cd6c75d0e91ca/). Existing
class/spell groups were reused because runtime code did not change: [816 class
checks](../../.artifacts/tests/02e9173943834cadba4ef367b20415c0/) and [912
spell checks](../../.artifacts/tests/7ff975f2e48a4466a8bfd348834a5487/).

## Accepted slice — earlier-step typed damage totals (`V-006`, minimal V-011)

VS-17 accepts one explicit sum over each actual target outcome from a named
earlier damage-bearing step, selecting one typed component and one existing
`raw`, `resolved`, or `hp_loss` measure. Neutral Fire/12 and renamed Cold/10
area spells loaded through DataLoader and settled through the shared ordered
resolver. The checks distinguished raw, resolved and actual HP loss across
overkill, resistance, Temporary HP and immunity; two runtime actors sharing a
definition ID remained separate. A positive `hp_loss` predicate gates one
caster heal after the full damage step, rounded down from half the total. Empty
and all-skipped outcomes sum to zero; missing/malformed results fail, and
invalid stage or component references refuse before slot payment.

The continuation check paid a real owned spell slot once, resumed across three
per-target save choices while retaining outcomes, applied the aggregate heal
once, and refused a replay without changing HP or cost. Parse (184 scripts),
boot, and the focused Spellcasting group (929/0) passed at
[evidence](../../.artifacts/tests/191cf0f3ff60489ba179bd87b546381b/). VS-17
certifies only typed per-target sum and its positive result predicate; general
reducers, other measures such as prevented/healing totals, broad result
predicates, and durable continuation saving remain open.

Combined VS-15–17 review retained the THP/lookup/aggregate evidence and closed
two authoring defects: deterministic constant expressions such as `3+2` now
work in lookup input while dice stay rejected, and the shipped spell schema
describes the implemented lookup and sum formula/predicate forms. Actor formula
evaluation safely refuses nested cast-only references without a cast. Focused
Spellcasting passed 932/0 with parse/boot at
`.artifacts/tests/49f742187a0f49f78de80e7212a91d3c/`. Schema JSON syntax and a
targeted fragment/fixture inventory passed; a full JSON Schema validator is
unavailable. Production Godot remains the gameplay evidence.

Reconciled 2026-10-13. This page records the latest accepted runtime evidence
and open work. [Roadmap](../../roadmap.md) chooses priority; the Quest Board
owns the exact next action. The checked vocabulary subsets are recorded as
VS-01–26 in the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off).
Their broader parent requirements remain open. Numeric pool/use-limit sections
reuse earlier retained logs; the bounded dice-pool section records the focused
production run from this reconciliation.

## Direction and current implementation

[ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) establishes
one shared data-driven rules runtime as the target. The broader interpreter,
class/creature language, generic continuation persistence and GM adjudication
workflow are not implemented. Named class/spell helpers remain migration code.

Ordinary spells currently opt into `execution: "shared"`. Valid operations,
rather than spell identity, enable new namespaced definitions. Existing cast
stages own resources, reactions and selection; `SharedSpell` applies ordinary
payloads once. Timed grants retain source ownership, Concentration, repeat
saves, campaign expiry and schema-2 validation.

Twelve winning definitions were converted: Fire Bolt, Burning Hands, Fireball,
Acid Splash, Cure Wounds, Healing Word, Hold Person, Inflict Wounds, Poison Spray,
Sacred Flame, Shield of Faith and Cone of Cold. Their rules limits remain.
Exploration controls support single/self party effects and single-object
attacks. Area/multi-target exploration and ongoing hazards remain separate paths.

## Bounded shared numeric resource pools — production validated (2026-10-12)

Added exact owner/source-instance numeric pool state, capacity evaluation through
the shared formula evaluator, explicit initial/current quantities, availability,
spending, capacity recalculation and exact-source removal. Shared
`ClassFeature` activation can spend the declared pool amount before applying its
supported self effects. A neutral JSON fixture uses proficiency bonus for
capacity and spends one use on a small condition effect. Character checkpoints
include this optional state; save preflight validates it, and loading restores
stored quantities without replaying acquisition.

Pool growth preserves the current quantity; pool shrink clamps it to the new
capacity. Queries and loads never refill. Two source instances of one definition
retain independent quantities. The production combat feature menu lists each
exact source instance, and the shared command path preserves that identity into
availability and execution. The focused Godot scenario loaded the neutral
proficiency-scaled definition, registered and activated a renamed equivalent,
checked cancellation, depletion and invalid activation, changed capacity in
both directions, removed one source while retaining the other, and saved/reloaded
through an allowed `SaveManager` checkpoint. Reload preserved owner, source,
capacity and remaining quantity without reacquisition.

Windows Godot 4.7 passed bootstrap, the **180-script parse gate**, production
boot, **697 selected class logic checks** and the 17-assertion
`shared_numeric_pool_flow` scenario, all with zero failures. Reproduce with
`run_tests.ps1 -GodotPath <Godot-console-path> -Suite all -LogicGroup classes
-Scenario shared_numeric_pool_flow`. Evidence: `.artifacts/tests/f53f61526df641ba82bcda1f553010ec/`.

The later combined pool/rest/rider run also passed the pool scenario:
`.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/shared_numeric_pool_flow.stdout.log`.
The bounded dice-pool extension now has focused production Godot evidence for
the authored die size and spend range, exact-source count payment, production
one/two-d6 self-healing choice, refusal and cancellation boundaries, existing
rest recovery, and allowed same-process checkpoint state. The combined
Windows Godot 4.7 run passed bootstrap, the 180-script parse gate, production
boot, 712 selected class checks, `shared_dice_pool_flow`,
`shared_numeric_pool_flow`, and
`numeric_pool_rest_recovery_normal_controls_flow`:
`.artifacts/tests/59351e0151bc4045a0af82b9fe5f073b/`.

This records the implemented bounded subset as verified at the stated
boundary, not the whole V-038 requirement. Its path has no activation
continuation to persist. Source discovery/acquisition UI, exchanges,
transferable/pre-rolled dice, class dice tables, payment-after-success,
catalog conversion, other definitions, fresh-process recovery and manual
campaign acceptance remain outside this validation.

## Bounded numeric-pool rest recovery — production validated (2026-10-12)

Numeric pool definitions declare fixed-quantity or fill-to-capacity recovery
on `short_rest_completed`/`long_rest_completed`. `RestRules` applies only the
matching completed-rest policy, once, to eligible living/conscious party actors'
exact source pools. Fixed recovery caps at stored capacity; Long Rest does not
also run the Short policy. Start/cancel/refusal, loading and ordinary elapsed
time do not recover these pools. Existing durations and checkpoint fields remain.
Overworld and Dungeon Long Rest controls route through `complete_long_rest`.

The retained production controls scenario loaded neutral and renamed data and
checked actual Overworld Short Rest and Dungeon entrance Long Rest, durations,
capping, actor/source ownership, downed/unrelated pool exclusion, cancellation,
refusal, ordinary time and checkpoint reload without recovery replay.
Bootstrap, the 180-script parse gate, production boot and all three combined
pool/rest/rider scenarios passed at
`.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/`.
Rest evidence: `numeric_pool_rest_recovery_normal_controls_flow.stdout.log`.
Earlier development evidence: 705 selected class checks at
`.artifacts/tests/a7cef44e54b4437e860afe7c176015e6/`.

This completes VS-07's bounded acceptance; no additional acceptance run is
pending. Other recovery events, rest/eligibility policies, Hit Dice, benefit-only
recovery and rest-start expiry remain open under V-044/V-048.

## Bounded fixed numeric-pool exchange — production validated (2026-10-12)

The accepted slice adds an authored fixed exchange through shared class-feature
activation. The neutral example spends two uses from an exact source of pool A
and restores one use to an exact source of pool B owned by that same actor.
The chooser offers existing eligible source pairs; the command binds the two
source IDs while taking pool definitions and quantities only from the owned
feature. Payment sufficiency and room for the complete restoration are checked
before either pool changes. Cancellation, stale/mismatched sources, same-source
selection, insufficient payment and a full destination preserve both pools.

The production Godot scenario loaded the neutral fixture and a renamed
equivalent, selected exact payment/restoration sources through both real combat
popups, and committed each authored 2-for-1 once. It checked payment and
destination cancellation, insufficient payment, full destination, same-source
selection, another actor's source, removal after selection, replay and forged
exchange metadata. Each refusal preserved both quantities; unselected sources
and the other actor stayed unchanged. An allowed SaveManager checkpoint
preserved both actors' exchanged source counts on reload without reacquisition
or replay. No save schema changed.

Evidence: `.artifacts/tests/b35a6f698e8f48fb807b4bc82aa808d7/` — bootstrap,
180-script parse, production boot, 722 selected class checks and the numeric
pool, dice-pool, exchange and normal-controls rest-recovery scenarios all passed.
The exchange scenario is also retained at
`.artifacts/tests/e0621b7db58a4165b1386dd90ff0380a/`.

This verifies only the fixed numeric-pool subset of V-039 (VS-11). Spell-slot
or dice payments, arbitrary currencies, conditional/post-roll costs,
cross-actor transfers, catalog conversion, and other exchange selectors or
policies remain unverified. See the [pool contract](../mechanics/shared-resource-pools.md#bounded-numeric-pool-exchange--production-validated-2026-10-12).

## Bounded data-authored combat use limits — production validated (2026-10-12)

Shared weapon-hit damage riders may declare once_per_combat_turn or
once_per_target_per_combat_turn. The exact owner, source instance, option,
existing active-turn serial and target (for the per-target form) identify the
transient lock. A qualifying rider spends one verified use from that exact
source pool and applies the supported damage aftermath; misses, ineligible
targets, empty pools and used limits leave the original attack alone. Locks
clear at the existing combat turn start and are not saved. Source removal
removes the exact pool and stops supplying the rider; reusing that source ID
does not unlock an option until the next turn, while a new source ID is
independent. The production Godot combat scenario passed with the neutral
definition and a renamed once-per-turn definition. It drove the real weapon
resolver and rider aftermath hook, the actual combat start/end-turn initiative
path, repeated completion, two targets, two actors, distinct source instances,
miss, failed melee eligibility and an exhausted pool. Each failure case kept
the base attack intact and spent no extra use. Bootstrap, the 180-script parse
gate, production boot, existing numeric-pool activation/checkpoint scenario and
the normal-controls Short/Long Rest recovery scenario all passed in the same
development run; the combat scenario also passed after switching to real
initiative progression. These checks do not certify UI target selection or
manual campaign play. A later qualifying hit in the same turn also confirmed
that misses and failed eligibility leave the option unlocked. This earlier
evidence covers only the two combat-turn forms; separate owner-turn-interval
acceptance is recorded below.

Final rider evidence:
`.artifacts/tests/31bbd8579b194f46b3589b20a6b96517/shared_combat_use_limits_flow.stdout.log`
with 180-script parse and production boot. Combined pool/controls recovery
evidence remains at `.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/`.
VS-08 records the checked rider boundary; V-041's broader scopes remain open.

### Owner-turn-interval rider limit — production validated (2026-10-12)

The new `once_per_owner_turn_interval` limit reuses exact owner/source/option
identity, checks the exact numeric pool, pays one use and applies a qualifying
weapon-hit rider once. Its transient lock survives other actors' turns, starts
locked clear in the combat-entry pre-first-turn interval, and resets only when
that owner starts a turn. A qualifying off-turn use therefore counts. Removing
and reacquiring the same source ID preserves its lock until that reset; a new
source ID remains independent. Existing once-per-combat-turn and per-target
combat-turn locks retain their behavior.

Production acceptance used the neutral and renamed definitions, actual
Opportunity Attacks, the real initiative path, and the weapon aftermath hook.
It verified the clear initial pre-first-turn interval; an off-turn use blocking
repeats; reset at that owner's first and successive turn starts; no reset from
another actor's turn; exact source and option independence; and a lock surviving
source removal/reacquisition. Misses, failed eligibility, empty pools, and an
already-locked option each skipped only this rider and preserved the attack.
The existing combat-turn and per-target-turn checks remain in place.

Godot 4.7 passed bootstrap, the 180-script parse gate, production boot and the
focused production scenario at
`.artifacts/tests/9973f2cacd994a55872977a7977104af/shared_combat_use_limits_flow.stdout.log`.
The 727 selected class checks passed at
`.artifacts/tests/2cc5aa83b6564b30bfce4e9f36765413/`. No save state was added,
and combat remains unsaveable. Syntax and the checked boundary are in the
[shared pool contract](../mechanics/shared-resource-pools.md#owner-turn-interval-hit-rider-limit--production-validated-2026-10-12).

## Bounded P1 facts, result references and formulas — production validated (2026-10-12)

Ordered spell steps/effects have allowlisted facts, predicates, arithmetic and
explicit earlier step/target/component selectors. The neutral `ember_echo`
and renamed equivalent checked owner/wounded eligibility, half of resolved Fire
rounded down and raw/resolved/actual-HP-loss distinctions. Normal Fire was
9/9/9, Resistance 10/5/5, Immunity 5/0/0, Temporary HP 8/8/5 and overkill 7/7/1.
Genuine pending-damage resume preserved the component reference and settled
damage, healing, slot and Empowered cost once; replay refused.

Evidence: `.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/` — bootstrap,
179-script parse, production boot, 1,270 selected spells/combat/conditions checks
and `shared_spell_p1_flow` passed. The preceding correction run at
`.artifacts/tests/176d3e1dda104438af8ca591c2e43adf/` checks overkill-safe HP loss,
missing/failed formula suppression including caster bonuses, valid-zero bonuses,
literal zero divisors and spell-level expression refusal before costs. Put
formula objects and predicates inside ordered effects, not spell-level effects.

The later five-reference `formula_reference_probe` checked a renamed definition
through production loading/casting. A free cast selected at slot level 2 read
character/class level, proficiency, INT modifier and selected slot as 1/1/2/3/2.
An unknown class reference refused before mutation. Pausing at selected slot 3
then changing live caster values produced 5/5/3/5/3 on resume: caster values are
live, while the selected slot stays captured and does not imply payment.
Evidence: `.artifacts/tests/e9a7a89073ea49ed96694834ce587c58/` — bootstrap,
179-script parse, boot and `shared_spell_p1_flow` passed.

VS-01–05 record these completed subsets. Broader predicates/relations,
target/component combinations, prevented/healed amount selectors, aggregation,
other class/ability combinations, multiclass progression, tables, choices,
source dice and other timing policies remain open. Neither this reconciliation
nor those fixtures certify the whole V-001/002/006/007/011 requirements.

## Accepted evidence — shared-runtime slices, 2026-10-11

Windows Godot 4.7 stable: bootstrap, **179-script parse gate**, production boot,
and **2,930 logic checks passed, zero failed**. The normal-control scenarios
`shared_spell_normal_controls_flow`, `ward_normal_controls_flow`,
`roll_token_normal_controls_flow`,
`short_rest_arcane_recovery_normal_controls_flow`, `crown_smoke` and
`combat_defeat` passed. The Portent and ordered-spell scenarios were rerun after
fixing consecutive exclusive-dialog handoff; that final batch had no engine
errors. All four save/reload probes passed in distinct prepare/recover processes.

Reproduce with `run_tests.ps1 -GodotPath <Godot-console-path> -Suite logic`,
then `-Suite integration -Scenario` with the six scenario names above.
Run `scripts/validate_ordered_grant_fresh_relaunch.ps1`,
`validate_roll_token_fresh_relaunch.ps1`, `validate_ward_fresh_relaunch.ps1` and
`validate_short_rest_fresh_relaunch.ps1`, each with `-GodotPath`.
See [testing](../testing.md) for the runner contract.

Local ignored evidence:

- Logic: `.artifacts/tests/33671b91de94471b866b8eba63ef048e/`.
- Gameplay: `.artifacts/tests/1bf53d3bcd9a420baa5c3c8527e2cca2/`; its Portent engine error is superseded by the clean final Portent/ordered-spell batch at `.artifacts/tests/323be74ab4614959b04e6b54126739b1/`.
- Ordered grants relaunch: `.artifacts/tests/ordered-grant-relaunch-04f61b57545a4c428a6f3fd5cf6d2b0b/`.
- Roll tokens relaunch: `.artifacts/tests/roll-token-relaunch-ddc9872d4bcd468eb974edfb6bf7d764/`.
- Wards relaunch: `.artifacts/tests/ward-relaunch-127d963aa9774ed9822daf1906d8a09d/`.
- Short Rest relaunch: `.artifacts/tests/short-rest-relaunch-50bf66638b59427d982cfd3486dbd82d/`.

These logs are evidence from this host, not a guarantee for another checkout.
No Linux execution, manual visual acceptance or full rules/campaign certification
is claimed. Broader interpreters, generic continuation persistence and unmigrated
class/monster catalogs remain unfinished.

## Verified behavior and bounded scope

**Ordered execution and zero-HP replacement**
([ADR-0019](../decisions/0019-shared-ordered-execution-and-zero-hp-replacement.md)):
`SharedStepExecutor` runs explicit spell steps and creature event rules through
one engine. Per-target gates retain attack damage when a later save succeeds;
area saves retain one shared raw damage roll and filter obstructed targets.
Empowered Spell and concentration reaction chains resume at the pending actor
and step, retain settled effects, and spend cast-wide costs once. Natural and
created Zombies and the JSON-only Dread Husk use data-driven zero-HP replacement.
Source-owned timed grants survive fresh-process reload, reject invalid content
before session replacement and expire independently. Multi-step exploration
remains single-target; active combat continuations are transient.

**Roll tokens and Portent**
([ADR-0020](../decisions/0020-roll-tokens-and-pre-roll-replacement.md)):
Diviner and the JSON-only Oracle fixture share `RollTokenRules`. Token identity,
visibility, once-per-turn use and schema-2 persistence are verified across attack,
save, ability/skill, Initiative and Death Saving Throw boundaries. Ordered casts
now offer pre-roll choices for each attack, target save and concentration save.
Declining the first attack preserves the later save choice without replaying
attack damage or slot expenditure. Stale, copied, wrong-kind and replayed request
callbacks refuse before resumption. Consecutive Portent dialogs release modal
focus before the next opens. Acquisition generates initial tokens and capacity
upgrades generate the additional tokens immediately; replacement uses the stored
natural result without another Advantage/Disadvantage d20. Those existing game
policies are documented rules limitations, not full PHB certification. Divination
Savant, Expert Divination and The Third Eye remain disabled/partial.

**Wards and damage interception**
([ADR-0021](../decisions/0021-damage-interception-and-wards.md)):
Abjurer and the JSON-only Runeguard fixture share `WardRules`. Slot-paid qualifying
casts create/recharge wards; free, ritual, item and at-will casts do not. Damage
applies Resistance/Vulnerability, ward interception, Immunity on overflow,
Temporary HP, then real HP. Immunity no longer preserves ward HP incorrectly.
Projected Ward spends one Reaction on one occurrence, including its typed damage
components, and cannot absorb a later hit or ordered step using the same decision.
Concentration uses creature damage after ward interception; fully absorbed damage
requires no save. Active zero-HP wards can recharge, and their state survives
fresh-process reload with malformed-save refusal. Abjuration Savant, Spell Breaker
and Spell Resistance remain disabled/partial.

**Short Rest and Arcane Recovery**
([ADR-0022](../decisions/0022-rest-completion-and-slot-recovery.md)):
Overworld and Dungeon entrance controls offer Short Rest (1 hour), Long Rest
(8 hours), or Cancel. Cancellation/refusal changes no time or resources; Short
Rest advances the clock once and affects living party members once. The shared
`rest_slot_recovery` effect offers a player-selected combination within
`ceil(wizard_class_level / 2)` slot levels and excludes level 6+ slots. A valid
choice consumes the once-per-Long-Rest use; declining/full slots preserve it.
The combat recovery helper is retired. Invalid, stale, wrong-actor and replayed
choices refuse without corrupting the live opportunity. Wizard and JSON-only
Leyline Savant fixture behavior, clock, slot state, spent uses, second-rest
suppression and Long Rest reset survive fresh-process reload.

## Open implementation — Animate Objects and world gaps

`src/characters/animated_object_rules.gd` and partial created-creature,
damage/perception, clock/Concentration and save hooks exist. The intended path
separates original object identity/HP from temporary Construct HP, uses a
one-minute Concentration lifetime, and carries excess damage into reversion.
These behaviors have not passed dedicated production acceptance.

`src/spells/animated_object_casting.gd` is absent. Normal selection/refusal
before cost, cast-stage integration, owner-following initiative, Bonus Action
attack/Dodge commands, and room cast/end controls are unfinished. Check optional
or null party data in save preflight and missing-record cleanup when resuming.
`SpellSupport.AVAILABLE_SLICES` includes `animate_objects`; that entry is not
proof of a working cast. Do not promote status from the allowlist alone.

Before acceptance, prove weighted object selection, orders/initiative, defenses,
expiry, zero-HP reversion/excess damage and checkpoint identity/HP through actual
controls. Use an explicit higher-level fixture: the level-5 spell is beyond
Crown's natural character level 1–5 band. Integrate the unfinished mechanics
under the roadmap's shared-runtime direction when scheduled.

Bounded Find Familiar, party corpse/recovery and Animate Dead paths have
earlier production evidence and explicit limits in their
[mechanics contracts](../mechanics/README.md). Animate Dead's latest recorded batch used
166-script parse, boot, 2,446 passing logic checks and six live regressions;
consolidated log: `.artifacts/wave4-foundations/created-accepted-validation.log`.
Finger of Death's Zombie, curated reversible forms and authored NPC/illusion
interaction remain open. Both [Wave 4 completion boundaries](../mechanics/wave4-acceptance.md)
are incomplete; they are not the active priority sequence.

## Other evidence and limits

The startup blank-window repair and normal visible start/creation/overworld
sampling are recorded in [the dated playtest](../../PLAYTEST_REPORT.md).
Phase-one Smite, Escape cancellation, object label placement and species
Darkvision repairs have a recorded 2,533-check logic pass; this precedes the
shared-spell batch above and adds no whole-class certification.

Class audits describe partial behavior and gaps, not future architecture.
[Visual acceptance](../ui/VISUAL_ACCEPTANCE.md) records the approved grimoire
presentation and its validation limits. Linux, controllers, broad manual
campaign traversal and published fresh-clone acceptance are not certified here.
