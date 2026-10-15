# D&D code-vocabulary gap checklist

Static discovery and consolidation for roadmap planning, with retained production
evidence reconciled 2026-10-13. This turns the existing
[data-to-runtime review](dnd-data-runtime-gap-review.md) and
[wiring map](dnd-runtime-wiring-map.md) into one capability checklist. It is
not a content ledger or a claim that every example record has been checked.

The [counted delivery plan](../planning/vocabulary-slices.md) divides these
requirements into build/validation slices, maps every V-ID, and records the
denominator and prerequisites. This checklist still owns capability scope,
source gaps and accepted VS evidence; mapping a parent to slices does not close it.

The separate discovery pass reads previously unexamined 2024 reference descriptions,
not just the earlier audit findings. The original 31 IDs below remain **navigation
families**. The V-series checklist further below supplies concrete, independently
checkable capabilities. A family such as “damage and healing” is not a completion
checkbox. See the discovery scope and source keys at the end for what was actually read.

The target is the current 2024 shared-runtime direction in [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md): rules data selects reusable behavior; code supplies generic operations and world access. Scope is the staged core 12 and current 2024 rules target, with existing shared foundations retained. Parent statuses describe the remaining code vocabulary; checked VS items certify only their stated production boundaries, not particular catalog records or whole capabilities.

**Status terms:** *shared/data-expressible* means the behavior is available as ordinary shared data within the described boundary; *partial* means some reusable execution exists but the listed generality or behavior is absent; *hard-coded only* means behavior exists through identity-specific/native policy; *missing* means no adequate current operation/state path was identified; *uncertain* means static evidence does not establish support. Discovery did not probe uncertain items. The checked subsets below cite later production evidence; this reconciliation ran no new gameplay checks.

<a id="verified-subsets-to-mark-off"></a>

## Checked subsets and bounded implementation

VS-01–36 are accepted subsets from the selected P1/P2/P3 batches. The
[2026-10-14 review and repairs](slice-acceptance-2026-10-14.md) reconfirmed
S-025, restored VS-30 and accepted repaired S-041 as VS-31.
[Batch B review](../../.artifacts/planning/vocabulary-reports/batch-B-review.md)
retains VS-29/30 and accepts S-095 as VS-32. None is a
completed broad V-series requirement or a percentage of
the whole project. The 97 parent rows retain their full requirements and stay
open where work remains. Do not repeat accepted proof just because a parent row
is still open.

- [x] **VS-01 — Boolean fact eligibility (`V-001`).** Ordered effects combine
  `target.is_source_owner` and `target.is_wounded` with `all`; a full-HP owner
  receives no healing. Other boolean forms and broader fact domains remain
  outside this production proof. [Evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log).

- [x] **VS-02 — Current source-owner relationship (`V-002`).** The aftermath
  selects and heals the wounded owner of the current spell source. Ally/enemy,
  willingness, charm/mark provenance and distance relations remain open.
  [Evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log).

- [x] **VS-03 — Earlier typed damage component (`V-006`).** An ordered spell
  exposes one selected Fire component's raw, resolved and actual HP-loss values;
  normal, Resistance, Immunity, Temporary HP and overkill cases are checked.
  Arbitrary target/component combinations, prevented/healed amount selectors
  and aggregation remain open. [Evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log).

- [x] **VS-04 — Bounded arithmetic and caster/cast inputs (`V-001`, `V-007`).**
  Half of the selected resolved component uses positive-divisor `floor_divide`.
  Five formula leaf kinds read caster character level, named own-class level,
  proficiency, Intelligence modifier and selected slot level. Renamed and free
  casts work; live caster values update after a pause while the selected slot
  stays captured. Multiclass progression, other class/ability combinations,
  tables, choices, source dice and broader timing policies remain open.
  [Arithmetic evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log),
  [input/timing evidence](../../.artifacts/tests/e9a7a89073ea49ed96694834ce587c58/shared_spell_p1_flow.stdout.log).

- [x] **VS-05 — Positive earlier-result gate across continuation (`V-011`).**
  The authored aftermath reads the earlier target's positive resolved Fire
  component, including after genuine pending-damage resumption. Damage, healing,
  slot and Empowered cost settle once; callback replay refuses. Margins, grouped
  child outcomes and other result gates remain open.
  [Evidence](../../.artifacts/tests/873b0c000b234f1a9c52e42ce764df83/shared_spell_p1_flow.stdout.log).

- [x] **VS-06 — Exact-source numeric pools (`V-027`, `V-038`).** Shared class
  features acquire/query/spend independent owner/source-instance pools, use
  formula capacity, retain quantity on growth, clamp on shrink and remove only
  the selected source. The combat feature menu carries the exact source through
  activation; neutral and renamed definitions work. The bounded dice-pool
  extension is checked at its limited VS-10 boundary. Source-acquisition UI,
  broader grant domains and exchanges remain open.
  [Evidence](../../.artifacts/tests/f53f61526df641ba82bcda1f553010ec/shared_numeric_pool_flow.stdout.log),
  [later combined regression](../../.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/shared_numeric_pool_flow.stdout.log).

- [x] **VS-07 — Completed-rest numeric-pool recovery (`V-044`, `V-048`).**
  Actual Overworld Short Rest restores a fixed quantity with a capacity cap;
  Dungeon Long Rest fills eligible exact-source pools without running the Short
  policy. Start/cancel/refusal, ordinary elapsed time, downed and unrelated pools,
  renamed data and checkpoint reload are checked. Other rest/eligibility
  policies, Hit Dice, rest-start expiry, Initiative/dawn/dusk and cooldowns remain
  open. [Evidence](../../.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/numeric_pool_rest_recovery_normal_controls_flow.stdout.log).

- [x] **VS-08 — Weapon-rider combat-turn and owner-turn-interval limits (`V-041`).**
  Once per combat turn and once per target per combat turn retain their
  independent actor/source/option locks and real initiative progression. The
  bounded `once_per_owner_turn_interval` form adds a separately reset owner
  lock: the pre-first-turn interval starts clear; an off-turn use blocks repeats
  through other actors' turns; only the owner's next turn start resets it.
  Same-source removal/reacquisition retains the lock, while source and option
  identities remain independent. Misses, failed eligibility, empty pools and
  locked options preserve the base attack and spend no additional use. UI target
  selection, an own-turn-only eligibility restriction, round/roll/active-instance
  scopes and general subscriptions
  remain open. Earlier combat-turn evidence:
  [rider scenario](../../.artifacts/tests/31bbd8579b194f46b3589b20a6b96517/shared_combat_use_limits_flow.stdout.log).
  Owner-interval production evidence:
  [focused scenario](../../.artifacts/tests/9973f2cacd994a55872977a7977104af/shared_combat_use_limits_flow.stdout.log);
  [727 class checks](../../.artifacts/tests/2cc5aa83b6564b30bfce4e9f36765413/).
  These checked slices do not close V-041.

- [x] **VS-09 — Numeric-pool checkpoints (`V-057`).** Production SaveManager
  preserves exact owner, source, definition, capacity and remaining quantity at
  existing allowed checkpoints without reacquisition or replayed rest recovery.
  This is same-process save/load; fresh-process recovery and other rule-state
  payloads remain open. Combat locks stay transient and combat remains unsaveable.
  [Pool evidence](../../.artifacts/tests/f53f61526df641ba82bcda1f553010ec/shared_numeric_pool_flow.stdout.log),
  [post-rest evidence](../../.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/numeric_pool_rest_recovery_normal_controls_flow.stdout.log).

- [x] **VS-10 — Bounded dice-pool extension (`V-038`).** Production Godot
  checks loaded neutral and renamed definitions, offered and cancelled the real
  one/two-d6 quantity choice, and matched healing to individual results after
  the selected count was paid at activation. Invalid and insufficient choices
  refused before payment, rolling or action cost; owner/source pools remained
  independent. Existing rest controls recovered counts without rolls, and
  allowed checkpoint reload retained owner/source/definition/die/count/serial
  without reacquisition or recovery replay. This path has no continuation to
  persist. Evidence: [combined Godot run](../../.artifacts/tests/59351e0151bc4045a0af82b9fe5f073b/shared_dice_pool_flow.stdout.log).
  Source acquisition UI, exchanges, transferable/pre-rolled dice, class dice
  tables, payment-after-success, catalog conversion, fresh-process recovery and
  broader V-038 coverage remain open. See the [pool contract](../mechanics/shared-resource-pools.md#bounded-dice-pool-extension--production-validated-2026-10-12).

- [x] **VS-11 — Fixed numeric-pool exchange (`V-039`).** Production combat
  menus selected exact owned payment/restoration sources for neutral and renamed
  data; the authored 2-for-1 committed once and changed no unselected source.
  Cancellation at either choice, insufficient payment, full destination,
  same-source, another actor's source, removal after selection, replay and forged
  exchange parameters all refused without changing payment/restoration counts.
  Allowed checkpoint reload preserved exchanged counts without reacquisition or
  replay. Other resource types and policies remain open. [Combined evidence](../../.artifacts/tests/b35a6f698e8f48fb807b4bc82aa808d7/shared_numeric_pool_exchange_flow.stdout.log).

- [x] **VS-12 — Source-owned timed numeric self-grant (`V-027`, `V-049`,
  `V-057`).** Neutral and renamed definitions loaded through production
  DataLoader and activated through the real combat feature menu. One numeric
  use paid for +2 AC; a duplicate source refused before extra payment. Separate
  sources retained additive modifiers across staggered deadlines, exact-source
  removal and unrelated modifiers. Checks covered just-before/exact/after
  minute and hour deadlines, turn ticks, real combat/exploration clock
  advancement, scene changes and a large jump past expiry. Distinct prepare and
  recover processes preserved owner/source/grant serial/payload/absolute
  deadline through an allowed checkpoint without replay or lifetime restart;
  malformed full-save preflight refused before session replacement. This proves
  only this numeric self-grant shape, not general condition/effect semantics or
  arbitrary durable state. [Production scenario](../../.artifacts/tests/dda2fafb854345deb66c201809c18779/);
  [fresh-process recovery and malformed-save probe](../../.artifacts/tests/timed-numeric-grant-relaunch-0f1cceb0b6ac4904b444f1e2482cadb4/).

- [x] **VS-13 — Source-owned next-matching melee-hit grant (`V-051`, the final-hit
  portion of `V-010`, bounded `V-057`).** Neutral +2 Fire and renamed +3 Cold
  definitions loaded through production DataLoader and activated through the
  real feature menu, each charging one exact source pool use. Actual weapon
  resolution proved canceled targeting, misses, ranged hits and another actor
  preserve the grant; the oldest qualifying grant is consumed once before
  damage settlement, including a critical and a base hit that downs its target.
  Fixed +2 Fire is not doubled and passes through Fire resistance/immunity;
  renamed +3 Cold passes through Cold resistance. Replaying the old result's
  completion after rearming left the new grant pending and target HP unchanged.
  Two pending grants retained source order, payload and absolute deadline over
  an allowed checkpoint in distinct prepare/recover processes without payment
  or activation replay. Malformed full-save preflight refused before replacing
  the live session. Production also checked repeat-hit, exact-source removal,
  staggered expiry and large clock jump. This does not certify general event
  subscriptions, other matchers, generic result facts or arbitrary save state.
  [Production scenario](../../.artifacts/tests/4370e8a4ce7d4d1291bbdda17786aa86/);
  [fresh-process probe](../../.artifacts/tests/next-melee-hit-grant-relaunch-286d5a6bdb03400eb9acdfab1481088b/);
  [focused class checks](../../.artifacts/tests/662ae1319efa45d790cdebb865ab8861/).

- [x] **VS-14 — Optional timed-grant end cooldown (`V-045`, `V-056`, with
  `V-027`/`V-049`/`V-057`).** Neutral +2 AC/60/3600 and renamed +3 AC/120/7200 definitions loaded
  through production DataLoader and activated through the actual combat feature
  menu. Each paid one exact-source pool use; duplicate, cooldown-blocked and
  wrong-owner dismissal commands refused without extra pool/action cost. Free
  exact-source dismissal started its cooldown at current campaign time, while
  scheduled expiry used the grant's absolute deadline. The production check
  covered just-before/exact/after timing, independent sources, one source's
  Short Rest refill while its longer cooldown remained active, and a single jump
  past both deadlines. Repeated end and replay of an old end after reactivation
  did not extend a deadline or consume the fresh grant. Omitted/zero cooldown
  retained VS-12 behavior. Distinct prepare/recover processes preserved an
  active grant and a cooldown-only record with owner/source/grant IDs, captured
  payload, serial, pool counts and absolute times; recovery did not replay
  activation. Malformed full-save preflight refused before replacing the live
  session. Only expiry and voluntary dismissal start a cooldown. Exact-source
  removal clears the active grant without a cooldown; other end reasons are
  unsupported, and this does not establish arbitrary cooldown/event semantics.
  [Production scenario](../../.artifacts/tests/2b29a42808f848dcb577f74d69d88500/);
  [fresh-process and malformed-save probe](../../.artifacts/tests/timed-numeric-cooldown-relaunch-1bd96120f7504b64a3e1933fbe653946/).

- [x] **VS-15 — Exact-source expiring Temporary HP (`V-027`, `V-052`, bounded
  `V-057`).** Neutral 10/60 and renamed 16/120 definitions loaded through
  production DataLoader and the real feature menu; one pool use paid once and
  duplicate activation refused before cost. Lower/equal timed offers and real
  False Life kept the current amount and provenance. Actual partial damage kept
  the owner tag, full absorption cleared it without regeneration, and staggered
  exact expiry/removal could not erase a newer timed or ordinary replacement.
  Real Ranger Tireless also replaced the timed buffer after partial damage;
  ordinary ability-scaled Temporary HP now uses the declared ability modifier
  and retains a larger active grant. Zero-HP damage retained existing death-save
  behavior, and Death Ward absorbed Temporary HP before its one-time replacement.
  Distinct prepare/recover processes retained remaining amount, owner/source/grant
  IDs, serial and absolute deadlines without replay; missing fields/deadlines and
  orphan sources were refused by full-save preflight before live replacement.
  Keep-higher is the only replacement policy checked. Replacement-choice UI,
  cross-actor grants, linked effects and broader spell/class domains remain open.
  [Production scenario](../../.artifacts/tests/6cca603c5a014e8d99288d0843682c46/);
  [fresh-process probe](../../.artifacts/tests/timed-temporary-hp-relaunch-5fd6758079e74199b7c9812a74449492/);
  [focused class checks](../../.artifacts/tests/3882353fdd354207a6b9407d99d84424/).

- [x] **VS-16 — Deterministic numeric breakpoint lookup (`V-007`).** Neutral
  and renamed tables with different integer thresholds and outputs passed
  production DataLoader and actual feature-menu activation. Capacity selected
  greatest-threshold-at-or-below values for exact, between, and above-last
  inputs; below-first and failed nested inputs failed explicitly. Growth did
  not refill, shrink clamped after rest, and repeated queries did not roll or
  spend. Empty, duplicate, unsorted, nonnumeric, and dice-input definitions were
  rejected by production loading before cost. An ordinary shared spell used the
  same lookup plus arithmetic evaluator. Dice/source-die tables, choices,
  multiclass progression, and broader capture policies remain open. [Focused
  production scenario](../../.artifacts/tests/8b686402e0fb4369b57cd6c75d0e91ca/).

- [x] **VS-17 — Explicit earlier-step typed damage sum (`V-006`, minimal
  `V-011`).** Neutral Fire/12 and renamed Cold/10 loaded through production
  DataLoader and shared ordered casting. Exact per-target raw/resolved/HP-loss
  measures stayed separate across overkill, resistance, Temporary HP and
  immunity; distinct runtime actors with one definition ID each counted once.
  Empty/all-skipped outcomes sum to zero, while absent/malformed outcomes fail.
  Invalid stage/component references refuse before slot payment. A positive
  HP-loss predicate gated one caster heal after all target outcomes. The real
  spell-slot cast resumed across three target-save choices, paid once, retained
  outcomes, healed once and refused replay without mutation. Other reducers,
  prevented/healing measures, broad result predicates and durable continuation
  saving remain open. [Focused production evidence](../../.artifacts/tests/191cf0f3ff60489ba179bd87b546381b/).

- [x] **VS-18 — Optional post-roll failed-save bonus (`V-014`, minimal
  `V-010`).** Production DataLoader loaded the neutral DEX/+5 and renamed
  CON/+7 features and their shared spells. The normal spell picker opened the
  actual post-roll source chooser; the original natural d20, existing modifier
  and DC were preserved. Two instances of one DEX definition were both offered,
  and selecting the second charged only its exact pool. The +5 and +7 bonuses
  each converted failure to success before damage; +5 also stayed failed when
  the original total plus bonus was below DC and still paid once. Decline,
  cancellation, natural success, wrong actor/target, forged selection, empty or
  removed source, and replay refused or left pools/outcomes unchanged. A pre-roll
  Portent choice resumed once through a multi-target cast; spell-slot payment
  and settled target damage did not repeat. Production CombatState teardown
  released settled chooser/HUD references. This covers one fixed bonus on the
  owner's rolled failed save against a shared spell in the combat HUD host.
  Automatic failures, other roll domains/hosts, cross-actor help, dice bonuses,
  reaction budgets and general post-roll editing remain open. [Focused production
  scenario with required bootstrap/parse/boot gates](../../.artifacts/tests/272bc7e14f9d4b3492985d1972f77d19/);
  [focused development checks and clean shutdown](../../.artifacts/tests/64095b1874a54775b27e8d5a19990340/).

- [x] **VS-19 — Conditional payment on converted save success (`V-035`, only
  the payment-policy subset).** Production DataLoader loaded the explicit
  pay-on-choice and renamed pay-on-converted-success definitions into the real
  combat chooser. An empty conditional source was omitted; changing its balance
  to zero while the chooser was open refused settlement, and restoring the same
  source allowed the same live answer to complete. A +7 that still failed kept
  full damage and spent zero uses; a later roll converted by that source paid
  once and used half damage. The visible chooser named the conditional policy.
  Explicit pay-on-choice also charged on an accepted failure; omitted policy
  keeps the VS-18 default path. Distinct exact sources, stale/removed/forged
  refusal, decline/cancel, one cast-slot settlement, earlier target/Portent
  continuation, replay refusal and combat cleanup reuse VS-18's production
  scenario. Other policy conditions, roll domains/hosts, cross-actor choices,
  dice bonuses and general post-roll edits remain open; this does not check V-035
  as a whole. [Focused production scenario with required gates](../../.artifacts/tests/3c966e9690ae4d388a3eed5322347d26/);
  [development checks](../../.artifacts/tests/1c2d0c5bf36f48eba701714fd518d58c/).

- [x] **VS-20 — Explicit success override for an owner's failed shared-spell
  save (`V-013`, narrow outcome subset).** Neutral DEX/cost-1 and renamed
  CON/cost-2 features loaded through production DataLoader and the combat spell
  picker. Accepting the real chooser made the save successful while preserving
  its natural d20, modifier, numeric total and captured DC. The explicit result
  drove half-damage mitigation and success/failure rider gates in ordered casts;
  a flat shared spell also waited for the chooser before applying its failed-save
  condition. Decline/cancel retained failure consequences without payment;
  already-successful legacy success-only, no-roll paralyzed, nonmatching,
  other-owner, empty, stale, removed and forged choices did not alter the result
  or spend a source. Numeric
  bonuses and both payment policies remain available as separate alternatives.
  A previous settled completion replayed while a fresh CON choice was pending
  left that request, both pools and target HP unchanged; the new choice then
  completed normally. Existing multi-target/Portent continuation settled the
  spell slot, earlier outcomes and damage once. Source selection remains one
  payment of the authored cost from one exact source and one modification per result. Forced failure, automatic
  outcomes without a roll, other roll domains/hosts, cross-actor help, general
  conflict precedence and catalog-wide support remain open; this does not check
  V-013 as a whole. Forced failure and general rolled outcomes are checked in VS-30, including
  its independently reviewed native-use and source-option conflict repairs. [Focused production scenario with bootstrap/parse/boot
  gates](../../.artifacts/tests/10c21f9d43cd48a0b7016eda80955c6e/);
  [focused development checks, 978/0](../../.artifacts/tests/7e616a3d05634cafb29e9cae10a3f05b/).

- [x] **VS-21 — Optional post-roll weapon-attack bonus (`V-014`, minimal
  `V-010`, payment-policy slice of `V-035`).** Production DataLoader loaded
  neutral +5/cost-1 and renamed +8/cost-2 definitions. The actual player Attack
  control and Extra Attack each opened a chooser for a separately captured
  missed roll; selecting each exact source converted its swing once, charged
  only that source, and preserved a single Attack action payment and one d20
  per swing. The first hit consumed its armed next-hit grant only after final
  resolution; an old settled answer was refused while the Extra Attack choice
  remained usable. A stale unaffordable source answer was refused while its
  visible menu remained pending, then closing that menu settled the unchanged
  miss without damage or payment and retained the separately armed grant. The
  renamed converted-success source paid once on a final hit; the neutral
  pay-on-choice source paid once when chosen. A separate real Rogue Attack
  offered Stroke before any optional source, used the captured roll and native
  use once, and left the optional pool untouched. Focused development checks
  additionally cover Shield-adjusted final hit/payment, natural 1 and natural
  20 boundaries, forged/wrong-owner/replayed answers, and canonical target
  identity. This checks the normal player Attack/Extra Attack combat host and
  fixed numeric bonus only. Still-failed conditional payment, decline/cancel
  (beyond the production miss cancellation), other hosts, Opportunity Attacks,
  monster-owned bonuses, and shared-spell attack domains remain open; this does
  not check V-014/035 as a whole. [Focused production scenario with required
  gates](../../.artifacts/tests/258a67b64044400b9405460eebfa2cd9/);
  [retained Shield/natural-result development checks, 838/0](../../.artifacts/tests/746d768aa31a42a6944ae8b88a66e613/);
  [latest development checks after canonical Stroke repair, 841/0](../../.artifacts/tests/8545cd6719474f4bb5d1347b933a8299/).

- [x] **VS-22 — Optional post-roll bonus on shared-spell attacks (`V-014`,
  minimal `V-010`, payment-policy slice of `V-035`).** Production DataLoader
  loaded the neutral fixed +5/pay-on-choice and renamed +8/pay-on-converted-
  success definitions through the real spell picker, targeting controls and
  source chooser. A Portent-selected natural 9 converted a flat miss once with
  one spell-slot payment and one exact-source payment; a renamed +8 that still
  missed retained the result without payment. Natural 1 remained a miss and
  natural 20 remained an already-hit result without a chooser. The ordered
  renamed spell resumed both a pre-roll token and a later Empowered damage-dice
  chooser; its conditional source paid only for a final hit, while an ordered
  miss applied only its miss rider. The hit rider and damage waited for final
  settlement, the earlier ordered step remained recorded once, and replaying a
  completed flat answer did not settle or charge a newer ordered choice. Six
  casts spent six slots, and the four non-token attacks rolled one d20 apiece.
  This checks the real combat host for flat/ordered shared-spell attacks and
  fixed numeric bonuses; noninteractive callers retain ordinary resolution.
  Other spell hosts, other attack windows, die bonuses, and catalog-wide
  support remain open; this does not check V-014/035 as a whole. [Focused
  production scenario with bootstrap/parse/boot gates](../../.artifacts/tests/41ebf1088d3f45608d4db6798ec5fd4c/);
  [focused spell development checks](../../.artifacts/tests/631f2a31408c41ecbaae002be6161fba/).

- [x] **VS-23 — One captured owned die bonus across checked roll choices
  (`V-014`, minimal `V-010`, payment-policy slice of `V-035`, source-die
  slice of `V-038`).** Production DataLoader loaded neutral d6/cost 1 and
  renamed d8/cost 2 sources. Real combat controls accepted the d6 on a failed
  DEX save and flat shared-spell attack; a renamed d8 remained a failed CON
  save without payment, converted a later CON save and an ordered shared-spell
  attack with conditional payment, and was offered for normal Attack/Extra
  Attack. Pay-on-choice still charged an accepted attack that missed;
  pay-on-converted-success charged only when the save or attack converted.
  The captured natural roll, save DC and attack AC remained unchanged. Query,
  Decline, stale metadata and replay did not roll or spend; a natural-1 weapon
  attack did not offer a die. An old completion left a newer chooser and its
  earlier step untouched. The ordered die receipt matched the actual source
  roll before and after the real damage choice, while ordinary damage dice
  were counted separately. A weapon-only Stroke helper refused a live shared-
  spell attack request before using the native feature or consuming the request;
  the actual Decline menu then settled the miss normally. A separate visible
  renamed spell chooser selected its offered d8 after that source was depleted;
  it paid/rolled nothing, finished only the captured miss and rider, cleared
  the pending request, and allowed the following valid cast. Real normal weapon
  Attack controls converted a captured miss to a hit with both d6/cost1
  pay-on-choice and d8/cost2 pay-on-converted-success. Each preserved its one
  d20, rolled only the selected die, paid its exact source, applied damage once,
  and refused replay. This certifies only
  the rolled-save, normal player weapon Attack/Extra Attack, and real combat
  flat/ordered shared-spell attack chooser paths. Other save/attack hosts,
  noninteractive callers, other roll windows and broader pool/payment behavior
  remain open; this does not close V-014/035/038. [Final focused production
  scenario with bootstrap/parse/boot gates](../../.artifacts/tests/ad3f0ddaaa89478881f5ea2fdee90721/);
  [current spells logic group, 1001/0](../../.artifacts/tests/0a0afca82e60469a944f05278b6dc281/);
  [affected classes group, 849/0](../../.artifacts/tests/0948178dfbd84aefaa58c1d1fe0f6343/).

- [x] **VS-24 — Purpose-aware owned-tool eligibility in loaded event checks
  (`V-003`).** Production DataLoader loaded neutral Surveyor's Tools and renamed
  Field Guide requirements. The real EventDialog Roll button and PlayerCommand
  path carried loaded event/check context for both an event-level skill check
  and a choice-owned check. The exact actor, task, purpose, originating event
  and check, item copy, effect, and backpack location survived into the closed
  `event_resolved.check_result`. Each enabled control executed one ordinary
  d20; an unloaded or ambiguous source executed none. A same-ability unrelated
  task, unknown purpose, different or missing tool, and another actor received
  no benefit. Removing one exact copy left the other copy eligible; removing
  both did not remove the Field Guide source. A no-tool context and an
  undeclared legacy check retained ordinary modifiers/DCs and consequences.
  Copied event/check/consequence fields did not replace loaded records. The
  selected check host charges no action/resource cost; each loaded outcome
  applied its authored gold consequence once. This checks only the loaded
  EventDialog host and its explicit task/purpose/tool/source fields. Local-room
  checks, sensory requirements, save purposes, post-roll choices, broader
  free-text interpretation and catalog-wide support remain open; V-003 remains
  partial. [Focused production scenario with bootstrap/parse/boot gates,
  37 assertions](../../.artifacts/tests/cb2fd72d5f044643a138bd11ad15f6e7/);
  [focused development checks, 18/0](../../.artifacts/tests/e4b85fd4e79b45f59da411597d342ba5/).

- [x] **VS-25 — Optional post-roll ability-check bonus in the loaded EventDialog
  (`V-014`, payment-policy slice of `V-035`).** Production DataLoader loaded
  neutral fixed +5/cost1 and renamed d8/cost2 sources, plus ability-only fixed
  +4 and d6 alternatives. Real `BtnRoll`, native Inspiration confirmation,
  source PopupMenu and Close controls proved one original d20, captured natural,
  modifier, DC and context, no reroll for a fixed bonus, and exactly one die
  only after an accepted die choice. Converted success and remaining failure
  obeyed both pay-on-choice and pay-on-converted-success; upfront affordability
  blocked an underfunded source. The selected and unselected pools were checked
  around answers. Query, decline, empty, stale/depleted, removed, forged and
  replayed answers did not roll or spend; completed accepted-request replay was
  checked against dice, both pools, gold and receipt snapshots. A loaded
  choice-owned ability-only check used its real choice button, Roll, source menu
  and Close with one exact cost and one consequence. Pending consequences waited for the
  final result and Close carried the same receipt as the settled check. An
  underfunded source was unavailable under each payment policy. Native
  Inspiration was spent once and remained in the total before the optional
  bonus. Same-actor and other-actor re-popup and freeing a pending host canceled
  only that host's request; a newer/replacement chooser remained answerable.
  This certifies only the loaded EventDialog skill-check/choice-check host,
  including explicit ability-only checks. Death Saves, concentration,
  local-room and other check hosts, natural/test rerolls, other outcome edits
  and broader payment policies remain open; V-014/035 stay partial. [Focused
  production scenario with bootstrap/parse/boot gates, 69 assertions](../../.artifacts/tests/136995fdd7b64e9d884b127a223518c5/).

- [x] **VS-26 — Mandatory-new natural/test reroll in loaded EventDialog
  (`V-089` bounded subset).** Loaded neutral natural-only/keep and renamed
  whole-test/reroll sources use one implementation and share the post-roll menu
  with eligible numeric bonuses. Real choice, Roll, source menu, native
  Inspiration confirmation and Close controls proved failure-to-success and
  success-to-failure, keeping the new result even when worse. Normal,
  Advantage and Disadvantage preserve their declared replacement mode; the
  latter two emit one aggregate test containing two d20 faces. Original/new
  raw natural, bonus dice, DC/context, mode and floor stages remain explicit.
  A deliberately sub-floor replacement applies the captured floor before
  native Inspiration; rerolled native faces, scalar fields and visible total
  agree, with the original receipt and one prior native payment preserved.
  An accepted negative/no-floor reroll stays below zero. Natural-only retains
  nonrerolled bonus dice. One selected exact-source cost and one consequence
  settle, with no second modifier menu. Query, decline, underfunded,
  emptied/removed/stale, forged, unoffered and replayed answers cannot spend
  or roll replacement dice; completed replay preserves dice, both pools, gold
  and closed receipt. Host re-popup/teardown cancels only its own request.
  This accepts the represented loaded event/choice ability-check host only;
  weapon/save/other check hosts, automatic/no-roll results, old/new selection
  and further modifier passes remain open. V-089 stays partial. [Final actual
  controls, 107 assertions and direct Godot exit 0](../../.artifacts/tests/a74c2363968243108dacc86f68a9ff5b/check_context_flow_final/);
  [bootstrap, 185-script parse and boot gates](../../.artifacts/tests/a74c2363968243108dacc86f68a9ff5b/).

Combined VS-24–26 review closed loaded-record authority, independent no-tool
context, stale-host awaits, pure reroll preflight, floor/native-bonus ordering,
negative/no-floor arithmetic and result-presentation findings. Required actual
controls and clean current-source evidence are retained above. All broader
V-series parents retain their uncovered boundaries.

- [x] **VS-27 — Nested typed shared fact predicates with missing-safe evaluation
  (`S-024`, bounded `V-001`).** Current-source review matched the retained BUILD
  and separate production validation. `SharedStepExecutor` supports nested
  `all`/`any`/`not` and one strict typed comparison against the existing fact
  allowlist. Missing values remain unknown through `not`; `all` and `any`
  preserve three-valued outcomes, so an unknown branch cannot grant eligibility
  by itself. Numeric zero, false and unavailable facts remain distinct.
  Malformed/unknown facts and wrong types fail definition validation before
  mutation. Loaded neutral and renamed spell fixtures exercise this through the
  real CombatHUD spell picker, cast command, target click and ordered
  step/effect settlement. The 11-assertion production scenario confirms live HP
  and source-owner changes, exact one-slot/Magic-action costs, effect receipts,
  pool/timed-modifier query purity, and menu/command refusal before cost or
  effect. This proves only ordered shared-spell step/effect eligibility in that
  combat host; broader bindings, other hosts and V-001 remain open. The known
  integral-JSON-number scalar-healing parser mismatch was reproduced and fixed
  during batch review; numeric-input regressions now protect this boundary. [Production
  scenario and required gates](../../.artifacts/tests/0a100c3d32f940e0963733ee0068fb4f/);
  [focused development checks, 1008/0](../../.artifacts/tests/518f20b7b66f4fac89e05da449f01a91/).

- [x] **VS-28 — Actor/action/item/source fact bindings (`S-025`, bounded
  `V-001`).** The separate production route passes loaded neutral and renamed
  shared-spell definitions through the CombatHUD picker, target click, real
  Portent chooser and resumed resolution. It checks caster and target IDs,
  action kind/invocation, spell definition/invocation, source definition/owner/
  instance, and two exact same-definition consumed material copies. Each cast
  spends one slot and Magic Action, consumes only its captured copy and retains
  its own generated source receipt. Focused checks cover missing/wrong-kind
  identities, caller metadata spoofing, distinct source/copy IDs and a resumed
  call whose substituted caller actor/target cannot replace the captured host.
  This accepts the combat shared-spell host only; direct resolution lacks
  action/invocation/item-copy bindings, and broader V-001 remains open.
  [Actual-control scenario and gates](../../.artifacts/tests/8aba2a55df174f94ac708b5f2741b3f5/);
  [focused spells logic, 1017/0](../../.artifacts/tests/ff3da86e36e14e0880de43264b33d92e/).

- [x] **VS-29 — Declared Advantage/Disadvantage policy (`S-091`, bounded
  `V-012`).** Loaded EventDialog event- and choice-owned ability checks apply
  authored Advantage/Disadvantage before the original d20. Duplicate grants of
  one mode retain separate source-instance provenance but use one two-face test;
  surviving opposite modes use the ordinary engine cancellation to one d20.
  Exact-context cancellation/prohibition suppresses only nonexempt contributions,
  recording both grant and policy sources. Pure eligibility reads do not roll or
  spend, and the actual Roll commitment rereads live sources, so removing a
  queried source returns the roll to Normal. The real loaded route retained the
  effective mode, exact contributors, natural result and closed receipt; a
  nonqualifying same-skill task remained Normal. Neutral and renamed definitions
  selected different modes/context without ID branches. Focused development
  covered duplicate/opposite/exempt/nonmatching cases and query purity. Existing
  S-105 mode provenance and pre-roll Portent natural replacement remained
  distinct: replacement reports `replaced` and does not rewrite the original
  mode. This accepts only the represented EventDialog ability-check route;
  attacks, saves, other hosts and broader V-012/S-106 remain open. [Direct
  actual-control run and required gates](../../.artifacts/tests/s091-check-context-direct/);
  [runner token-replacement scenario](../../.artifacts/tests/e7aa7b8b9d2e46fa87bd9cf7d17a2a7b/);
  [focused logic checks, 76/0](../../.artifacts/tests/70b543eec7d9482c8e07fe69dc743dee/).

- [x] **VS-30 — Explicit attack/save outcome overrides (`S-092`, bounded
  `V-013`).** Neutral cost-1 and renamed cost-2 source-owned definitions passed
  the real normal player Attack, single-target shared-spell attack, and rolled
  Character-target shared-spell save controls. Both hit/miss and save
  success/failure directions were selected. Natural 1/20, critical suppression
  on a forced natural-20 miss, unchanged numeric roll facts, exact source and
  payment receipts, stale/wrong-source refusals, once-only costs, and suspended
  ordered damage continuation were checked. Original action/slot cost and earlier
  ordered results settled once. The combat receipt retained the separate outcome
  and source provenance; the natural 1/20 remained numeric facts. Automatic/no-roll
  outcomes, canceled Death Saves, other save/attack hosts, cross-actor intervention,
  token replacement and catalog-wide support remain open; V-013 is partial.
  [Actual-control scenarios and required gates](../../.artifacts/planning/vocabulary-reports/S-092-validation.md);
  [focused spells logic, 1,033/0](../../.artifacts/tests/995db1031b034800bcda7c69ed3c6129/).

  The later review repaired native-use ordering and rejects same-source,
  same-domain numeric/die/outcome conflicts in either declaration order. Actual
  weapon and spell forced-miss controls preserve unused Peerless Aim, while
  source cost and final consequences settle once. Acceptance is restored.
  [Full logic 3,332/0 and five actual-control scenarios with required gates](../../.artifacts/tests/bf854bf713dc498ab789ec6bb1a6cfe0/).

- [x] **VS-31 — Authored shared-spell attack window context (`S-041`, bounded
  `V-010`).** The real attack and damage owners emit exact occurrence/kind,
  actor/target, action/spell/source bindings and the five ordered windows:
  before-roll, after-natural, provisional outcome, pre-damage and post-damage.
  Each exposes only its available facts. Authored ordered attack effects and
  following riders now consume the current child receipt through the parent
  adapter, including after actual attack and Empowered damage choices. A fresh
  missed occurrence cannot reuse an earlier damage window; another recipient
  cannot inherit its facts. Save and standalone damage steps clear the attack
  context. Costs, earlier steps and effects settle once; stale/wrong-host/source
  answers refuse through the existing owners. This accepts single-target shared
  spell attacks and ordered attack steps only, with the existing primary damage
  component's raw/resolved/HP-loss fields. Other hosts, general subscriptions,
  cast/source-end windows and wider damage measures remain open. The same
  review repaired integral numeric healing/Temporary HP without changing dice,
  dictionary formulas or fractional refusal.
  [Independent review and fixes](slice-acceptance-2026-10-14.md);
  [full logic and actual-control evidence](../../.artifacts/tests/bf854bf713dc498ab789ec6bb1a6cfe0/).

- [x] **VS-32 — Owned post-roll attack-total subtraction and local defending-AC
  adjustment (`S-095`, bounded `V-014`).** Loaded neutral amount-6/cost-1
  subtraction and renamed AC+2/cost-2 sources use the actual normal weapon
  Attack and interactive single-target flat/ordered shared-spell choosers.
  Final misses prevent damage; final hits settle damage after selection.
  The exact attacker/source/feature/pool/domain receipt preserves original
  natural, modifier, total, profile and AC alongside the final comparison.
  Defender AC stays unchanged. Pay-on-choice charges once; conditional payment
  charges only a final hit. Decline and removed/depleted sources finish the
  captured attack without adjustment payment. Wrong actor/window, stale answer
  and replay refuse; eleven attack occurrences roll eleven d20s, and each cast
  pays one slot. Natural 1/20 do not offer adjustments. Ordered prior results
  settle once and the receipt survives a following actual Empowered damage
  choice. A converted shared-spell miss retains its receipt in the pre-damage
  window. Review confirms miss exits precede next-hit grant consumption and
  damage-side resource use; no new runtime repair was required. Other hosts,
  cross-actor intervention, no-roll outcomes and Death Saves remain open.
  [Separate validation](../../.artifacts/planning/vocabulary-reports/S-095-validation.md);
  [actual controls and required gates](../../.artifacts/tests/e91a49d53fde44b78c95abc6ed5e21b6/);
  [focused spells logic, 1,055/0](../../.artifacts/tests/39c9271a2365442fb58681279caeb6e8/).

- [x] **VS-33 — Exact prior-result identities and additional measures
  (`S-034`, bounded `V-006`).** Fresh-chat review reconciled the retained
  separate production validation before dependent S-043 BUILD. Loaded neutral
  and renamed ordered spells select the exact runtime target, step and typed
  component; repeated component types require an ID. Receipts distinguish raw,
  resolved, prevented, absorbed, HP loss and actual capped healing. Same-type
  actors remain separate, missing/malformed/future/wrong-step references refuse,
  and a settled receipt survives a later roll choice and live HP/source changes.
  Production validation used the real HUD picker and area target control and
  observed one slot/action per cast; the focused spells logic passed 1,064/0.
  `result_sum` remains the VS-17 raw/resolved/HP-loss sum. Cast-target selectors
  and malformed/unavailable cases are covered by focused checks; the real
  control exercised `target: same`. This accepts only the loaded ordered
  shared-spell boundary; broader hosts and reducers remain open.
  [Acceptance reconciliation](../../.artifacts/planning/vocabulary-reports/S-034-acceptance-review.md);
  [separate validation](../../.artifacts/planning/vocabulary-reports/S-034-validation.md);
  [retained production run](../../.artifacts/tests/bc96a70df880495695952b3b803bb8b9/).

  [Batch C review](../../.artifacts/planning/vocabulary-reports/batch-C-review.md)
  retains VS-33 after repairing single-entry list component identities. Explicit
  IDs and type ordinals now survive mapped damage into later authored consumers;
  scalar step-derived identities are unchanged.

- [x] **VS-34 — Numeric margin and settled-HP gates (`S-043`, bounded
  `V-011`).** Loaded neutral failed-save margin and renamed ordered HP-after-
  damage consumers use signed numeric margin and the exact HP snapshot at the
  selected completed settlement. Actual picker/save/target controls verified
  below/equal/above thresholds, S-092 forced outcomes with retained rolled
  margin, no-roll margin unavailability, and a later Empowered damage choice
  that pauses aftermath until settlement. HP probes distinguish the captured
  post-damage value from pre-damage HP, temporary-HP absorption, overkill,
  later healing/unrelated damage, a settled zero-damage receipt and missing or
  malformed/future selectors. Costs and ordered aftermath settle once.
  S-095 adjusted attack total/AC compatibility assertions passed; its recheck
  runner had an unrelated post-scenario monster-AI engine error, documented in
  the validation report. Only these loaded ordered shared-spell hosts are
  accepted; grouped gates and wider V-011 remain open.
  [Separate validation](../../.artifacts/planning/vocabulary-reports/S-043-validation.md);
  [production and focused evidence](../../.artifacts/tests/41ae6ec7c22a45ee88af9e499e2c4bf0/).

  Batch C retains VS-34. Its combined real-control regression reads the selected
  mapped component only after that target's HP/margin gate qualifies. The clean
  later S-095 control run is retained in the Batch C report.

- [x] **VS-35 — Independent save/miss damage and riders (`S-098`, bounded
  `V-015`).** Actual flat and ordered shared-spell attack/save controls used
  independent complete damage-scale and rider maps. A post-roll AC choice
  changed provisional hit to final miss without changing the roll; odd half
  damage retained the miss, then Resistance and Temporary HP settled in order
  with no hit-only rider. Flat and ordered two-target saves produced distinct
  success/failure damage, condition and HP results, and ordered continuation
  survived a following damage choice/step without early or duplicate effects
  or costs. Malformed maps refused before cast payment. Adjustment query,
  decline, wrong-owner/window, stale and replay behavior passed its actual
  control. Only loaded flat/ordered shared-spell attack/save routes are
  accepted; other hosts, standalone damage/effect steps and S-099 Evasion or
  recipient exemptions remain open.
  [Separate validation](../../.artifacts/planning/vocabulary-reports/S-098-validation.md);
  [actual controls and focused checks](../../.artifacts/tests/b0903136f9434f71bc1a18f37082547f/).

  Batch C retains VS-35 after rejecting maps without an owning attack/save host
  before payment and repairing Uncanny Dodge's composition with zero/half hit
  scales. Focused spells passed 1,091/0 and the affected actual controls passed;
  the report distinguishes a repaired fixture initiative race from clean cases.

- [x] **VS-36 — Ally/enemy/willingness and exact-giver relations (`S-026`, bounded
  `V-002`).** Actual Character Sheet choices for Unknown, Unwilling and Willing
  were consumed by loaded neutral/renamed shared-spell definitions through the
  CombatHUD picker and target click. Unknown stayed unavailable beneath `not`;
  represented ally and enemy cases selected distinct effects. Two givers' same-kind
  source records remained independent, and removing one exact source changed only
  its own query and consumer. Missing/ambiguous relationship membership returned
  unavailable at the production fact reader; no such membership is selectable as a
  combat target in the current UI. Save/load recovered willingness in a fresh process,
  and malformed values were refused before live-state replacement. The renamed mark
  consumer uses a generic exact source-owned record; native Hunter's Mark is not
  certified as a per-target source. General factions, social AI, free-text consent and
  broader V-002 remain open. [Separate validation](../../.artifacts/planning/vocabulary-reports/S-026-validation.md);
  [actual controls and gates](../../.artifacts/tests/0d5e70835a3d452f865c05e32d30a079/).

Combined VS-18–20 review closed five stage/snapshot defects: spent Inspiration
is retained in the paused total, ordered save choices reach the chooser, a
following deferred damage choice retains the original continuation, flat
failure effects wait for the final save, and resume keeps the captured DC.
The development checks above cover Inspiration/changed-DC/deferred-damage
regressions; VS-20's clean production scenario covers real ordered/flat controls
and once-only payment/effects. Transient choices add no checkpoint permission.

Combined review verified the focused corrections: duplicate same-kind grant
operations refuse at content loading; tagged timed/cooldown state requires its
owned saved pool and deadline; exact-source removal clears only its own cooldown.
The extended full-save probe above refused orphaned sources/missing deadlines
before session replacement. [Focused class evidence: 779/0](../../.artifacts/tests/14659d0b264d4be5ba3eab380d51663c/).

Combined VS-15–17 review also closed deterministic constant-expression lookup
rejection and schema omissions for lookup/sum forms. Nested cast-only actor
formulas now fail safely without a cast context. [Focused spells: 932/0 and
schema inventory](../../.artifacts/tests/49f742187a0f49f78de80e7212a91d3c/).
The schema check covers syntax and targeted fragments/fixtures; a full JSON
Schema validator is unavailable. Production behavior is proved by Godot.

## Existing capability families

### Queries and predicates

| ID — capability | Meaning and examples | Current code status | Existing hook | Depends on |
|---|---|---|---|---|
| QRY-01 — Actor and rule context | Inspect actor identity/ownership, allegiance, creature type and size, class level, conditions, proficiency, turn state, and source eligibility. Examples: Magic Resistance eligibility; Sneak Attack ally/advantage conditions; Countercharm's eligible observers. | **partial** — ordered allowlisted facts/predicates and caster/cast numeric leaves exist (VS-01/02/04); other domains and broad rule-context queries remain incomplete. | `Character` getters and `CombatAction` condition/attack queries; `CombatState` choice collectors. | STA-01, EVT-01 |
| QRY-02 — Roll modifiers before rolling | Add/remove advantage, disadvantage, bonuses, floors, or replace the natural result before the ordinary roll; defines ordering and whether another d20 is rolled. Examples: Lucky; Justice cancelling advantage; Portent replacement. | **partial** — Portent/roll tokens are shared for bounded d20 boundaries; other feature modifiers use native callers. | `RollTokenRules.resolve_d20_test`; `CombatAction` attack/save/check resolution; `Character` check modifiers. | QRY-01, CHO-02, STA-02 |
| QRY-03 — Result changes after rolling | Inspect a completed roll/result and then replace or alter it, without pretending it was a pre-roll choice. Examples: Deck of Oracles replaces after a roll; post-roll reroll/adjustment clauses. | **partial** — VS-18/20/30 check owned bonuses and explicit outcome overrides for supported rolled shared-spell saves; VS-30 also checks weapon/shared-spell attack outcomes after its reviewed native-use and source-option repairs; VS-25 checks fixed/die bonuses for failed loaded EventDialog ability checks. General post-roll windows, rerolls and other roll domains remain open. V-013/014/035/089/090 separate the required semantics. | `SpellSaveResolver`; `SpellDamageRolls`; native roll consumers. | EVT-01, CHO-02, STA-02 |
| QRY-04 — Formulas and modifier combination | Evaluate declared level/ability/proficiency/slot/dice formulas and apply bonuses, floors, caps, resistance, vulnerability, immunity, and stacking policy. Examples: proficiency-scaled uses; Shield of Faith AC; typed damage resistance. | **partial** — arithmetic/caster inputs/component references (VS-03/04), numeric breakpoint lookup (VS-16) and typed prior-step sums (VS-17) are checked. Dice/source tables and generic modifier/stacking policy remain open. | `Character` modifier/stat methods; `CombatAction.resolve_damage`; `SharedSpell` scaling. | QRY-01, OPS-02, STA-01 |
| QRY-05 — Targeting, range, geometry, and visibility | Query legal targets using distance, shape, line of sight, obstruction, visibility, size and target category at the moment required. Examples: sphere/cone spell targeting; Abjure Foes sight/target limits; remote-sensor perception. | **partial** — bounded combat geometry, LOS and shared spell shapes exist; exact volumes, cover and broad exploration queries do not. | `CombatPerception`; `CombatState` targeting; `SharedSpell`; `LocalRoomRules`. | WRL-04, WRL-05, WRL-06 |
| QRY-06 — Owned item and equipment predicates | Inspect exact item copy, ownership, equipped slot, attunement, charges, held/free hands, weapon properties and component value. Examples: Ring of Protection bonuses; spell focus eligibility; Missile Snaring free-hand requirement. | **partial** — copy identity, equipment, attunement and component checks exist, but many bonuses/compatibility rules remain identity lists or are not consumed generically. | `Inventory` instance/equip/attunement and component queries; `Character.get_modifier`. | STA-01, WRL-03 |

### Events and timing

| ID — capability | Meaning and examples | Current code status | Existing hook | Depends on |
|---|---|---|---|---|
| EVT-01 — Reusable event subscriptions and timing | Run a rule at named events with actor/target/source facts and declared priority: before/after attack, hit, damage, save, turn start/end, rest, movement, defeat, or cast. Examples: Rage expiry; Regeneration; Multiattack and on-hit riders. | **partial** — bounded zero-HP/token/ward/cast paths and authored numeric-pool rest/weapon-hit paths exist (VS-07/08); general subscriptions/order remain incomplete. | `SharedStepExecutor` event rules; `CombatState`; `SpellEffects`; `RestRules`; `WardRules`. | QRY-01, STA-01 |
| EVT-02 — Ordered steps and per-target results | Compose operations in sequence, gate later steps on a particular earlier target's hit/save/result, and retain independent target outcomes and shared rolls. Examples: attack then save rider; breath save/damage; attack plus secondary save. | **partial** — shared spell steps and zero-HP replacement are data-driven, but this is not yet a general cross-domain event vocabulary. | `SharedStepExecutor`; `SharedSpell`; ADR-0019. | OPS-01, OPS-02, CHO-03 |
| EVT-03 — Movement, entry, and spatial triggers | Fire once or repeatedly when an actor/object enters, crosses, leaves, moves within, or ends a turn in an area; specify path and trigger timing. Examples: Spike Growth; Moonbeam; moving light or barrier interactions. | **partial** — native spell zones handle selected combat cases; not a general data-declared world event. | `CombatSpellZones`; `CombatState` zone movement/turn hooks; `LocalRoomRules` area entries. | WRL-04, WRL-05, EVT-01 |
| EVT-04 — Deferred and clock-based events | Schedule an event by campaign time, actor turn, round, or elapsed duration, including source termination and delayed follow-up. Examples: Draakhorn aftermath; delayed spell damage; next-turn transformation. | **partial** — campaign clock and selected turn/round timers exist; many timers are named helpers and clocks lack general authored scheduling. | `GameManager` campaign clock; `SpellEffects`; `CombatState` turn/zone ticking. | STA-03, EVT-01 |

### Operations

| ID — capability | Meaning and examples | Current code status | Existing hook | Depends on |
|---|---|---|---|---|
| OPS-01 — Attack, save, damage, and healing operations | Roll attack/save/check, resolve damage or healing and attach typed damage components as parameters; use one settlement path. Damage type is a parameter, not a separate operation. Examples: Fire Bolt; monster bonus damage; Poison's save and damage sequence. | **partial** — bounded shared spell payloads and ordered attack/save/damage exist; creature, class, item and arbitrary combinations still need native paths or vocabulary. | `SharedStepExecutor`; `SharedSpell`; `CombatAction`; `EventResolver`. | QRY-02, QRY-04, EVT-02 |
| OPS-02 — Damage mitigation and prevention | Apply resistance/vulnerability/immunity, ward interception, temporary HP, HP, prevention reactions and concentration consequences in defined order, preserving each damage occurrence/component. Examples: ward interception; Absorbing Tattoo; typed multi-component attacks. | **partial** — ordinary typed damage order and ward path exist; data cannot declare all mitigation layers or prevention choices. | `CombatAction.resolve_damage`; `WardRules`; `CombatState` concentration handling. | OPS-01, CHO-02, STA-01 |
| OPS-03 — Conditions, grants, and modifiers | Grant/remove source-owned conditions and passive effects, define numeric modifiers and query behavior, and combine or suppress them without deleting underlying state. Examples: Frightened; item-based AC; Ear Horn suppressing Deafened while held. | **partial** — shared spell condition effects and owned timed grants exist; arbitrary condition semantics/modifier payloads are incomplete. | `SharedSpell`; `Character` effect/condition queries; `SpellEffects`; `CombatAction`. | QRY-04, STA-01, STA-03 |
| OPS-04 — Resource and recovery operations | Spend/recover a declared resource, including slot, charge, use, Hit Die, or pool; specify amount, eligibility, reset boundary and whether a choice is required. Examples: Arcane Recovery; item charges; Hit Dice during rests. | **partial** — exact-source numeric pool spending/rest recovery are checked (VS-06/07), alongside existing budgets/slots/charges/Arcane Recovery; dice pools, exchanges, Hit Dice and broader recovery remain incomplete. | `CombatTurnBudget`; `Character`; `Inventory`; `RestRules`; `ClassProgression`; `ResourcePoolRules`. | CHO-03, STA-02, EVT-01 |
| OPS-05 — Action availability and AI commands | Expose a declared action to players and AI with legal targets, costs, and command shape; include reactions and multi-step actions rather than just resolving a manually supplied action. Examples: monster Multiattack; recharge breath; Wand activation. | **partial** — player controls and bounded AI command types exist; actions and AI choices still depend on native identity/profile logic. | `AICommand`; `AIController`; `CombatState` command/action collection; `ClassFeature`. | CHO-01, CHO-03, EVT-01 |
| OPS-06 — Generic creation, removal, and transition | Create or remove an actor/object/effect, transfer or transform it, and carry exact source/owner identity through the world transition. Examples: Find Familiar; created Zombie; Animate Objects. | **partial** — familiar/steed/created-undead ledgers and bounded transforms exist; templates, commands and policies are not generally data-driven; Animate Objects path is unfinished. | `CreatedCreatureRules`; familiar/steed owners; `DruidRules`; partial Animated Object hooks. | WRL-01, WRL-02, STA-01, STA-03 |

### Choices, costs, and resolution order

| ID — capability | Meaning and examples | Current code status | Existing hook | Depends on |
|---|---|---|---|---|
| CHO-01 — Data-defined choices and target selection | Present eligible targets/options/modes, validate the selected option against current state, and preserve it for resolution. Examples: spell targets; Wild Shape attack choice; selected weapon mastery. | **partial** — spell and progression selection flows exist; a broad action/feature/item choice vocabulary and consistent saved validation do not. | `ClassProgression`; `CombatState` choice collectors; spell targeting; `EventResolver`. | QRY-01, QRY-05, OPS-05 |
| CHO-02 — Reactions and replacement windows | Offer optional decisions at a precise window before/after a roll, hit, damage, or other event; define eligible responders, order, refusal, one-reaction budget and continuation. Pre-roll and post-roll windows are separate behaviors (QRY-02/QRY-03). Examples: Portent; Projected Ward; Countercharm. | **partial** — bounded token, ward, and reaction continuations exist; no common authored reaction ordering/eligibility vocabulary. | `RollTokenRules`; `WardRules`; `CombatState` reaction/continuation handling; `CombatTurnBudget`. | EVT-01, QRY-01, STA-02, CHO-03 |
| CHO-03 — Atomic and conditional costs | Declare when costs are checked and committed relative to choices/effects; support conditional payment, cancellation/refusal, suspension/resume and exactly-once commitment. Examples: metamagic points; slot-paid Ward creation; optional damage riders. | **partial** — ordered continuations preserve cast-wide costs; VS-19 checks pay-on-choice versus converted-success payment for the bounded failed-save bonus. Other commit conditions, currencies and domains remain open. | `CombatState` cast pipeline; `CombatTurnBudget`; `SpellCast*`; `SharedStepExecutor`. | CHO-01, CHO-02, EVT-02, OPS-04 |
| CHO-04 — Resolution precedence and conflict policy | State which replacement/modifier/trigger runs first when several rules apply and how equal-priority or incompatible operations are refused. Examples: advantage cancellation before Portent; ward then temporary HP; multiple reactions to one occurrence. | **partial** — several settlement orders are explicit in current focused paths; no general cross-rule priority/conflict vocabulary. | `RollTokenRules`; `CombatAction.resolve_damage`; `SharedStepExecutor`; ADR-0019. | EVT-01, QRY-02, OPS-02, CHO-02 |

### Owned state, counters, duration, and cleanup

| ID — capability | Meaning and examples | Current code status | Existing hook | Depends on |
|---|---|---|---|---|
| STA-01 — Definition grants and owned instances | Acquire effects/actions from class, subclass, species, item, spell, monster, or other source and retain owner/source/copy identity so querying/removal affects only the right grant. Examples: species traits; attuned item benefits; spell-created condition. | **partial** — exact-source class-feature numeric pools are checked (VS-06), alongside existing inventory/spell sources; broader acquisition and grant domains remain incomplete. | `ClassProgression`; `Character` feature/effect methods; `Inventory` instances; `SpellEffects`; `ResourcePoolRules`. | QRY-01, OPS-03 |
| STA-02 — Counters, pools, and reset scopes | Store uses/charges/tokens/points with capacity and spend rules; scope reset to turn, round, short rest, long rest, or another authored event. Examples: Portent tokens; Arcane Recovery use; separate Figurine copies. | **partial** — source-owned numeric pools, completed-rest reset and independent combat-turn rider locks are checked (VS-06–08); dice/counter/other reset contracts remain incomplete. | `RollTokenRules`; `WardRules`; `RestRules`; `Character` resources; `Inventory` charges; `ResourcePoolRules`. | OPS-04, EVT-01, STA-01 |
| STA-03 — Duration, recurrence, expiry, and cleanup | Attach duration and termination predicates to the source-owned effect; tick against the correct campaign/round/actor clock and clean only its grants, zones, or created actors. Examples: Rage; concentration effects; Wild Shape reversion. | **partial** — shared timed spell effects and selected clocks work; many feature/item/form timers are separate named fields/helpers. | `SpellEffects`; `SpellEncounterLifecycle`; `GameManager` clock; `DruidRules`; `CombatSpellZones`. | EVT-04, STA-01, OPS-06 |
| STA-04 — Durable state validation and recovery | Serialize mutable rule instances, choices, counters and ownership with validation, missing-definition behavior and no replayed grants; preserve schema-2 boundaries. Examples: ward state; token pools; owned timed spell grants. | **partial** — save preflight and selected schema-2 state families exist; VS-13 adds one next-hit grant fresh-process recovery. Generic interpreter-state envelopes and arbitrary pending workflow saves do not. | `SaveManager`; `Character` serialization; `SpellEffectPersistence`; `WardRules`; `RollTokenRules`. | STA-01, STA-02, STA-03, CHO-03 |

### World interaction: actors, objects, movement, perception, and forms

| ID — capability | Meaning and examples | Current code status | Existing hook | Depends on |
|---|---|---|---|---|
| WRL-01 — Actor identity, lifecycle, control, and initiative | Represent actors with stable identities, owner/controller, allegiance, initiative, commands, defeat/death and return/despawn behavior. Examples: familiar/steed ownership; Zombie control versus existence; summoned actor initiative. | **partial** — party, owned creature, corpse and created-undead identities exist; generic actor templates/control/actions are absent. | `PartyManager`; owned-creature records; `CorpseRules`; `CreatedCreatureRules`; combat encounter projection. | OPS-05, OPS-06, STA-01 |
| WRL-02 — Forms and reversible projections | Apply a form/template projection while retaining base actor identity/state, selected attacks and movement modes; define duration, incapacity/end predicates and reversion damage transfer. Examples: Wild Shape; Polymorph; Animate Objects. | **partial** — bounded Druid and animated-object projection hooks exist; projection fields, selected actions and cleanup remain native/unfinished. | `DruidRules`; `Character` movement queries; partial `AnimatedObjectRules`; `SharedStepExecutor` replacement. | WRL-01, OPS-06, STA-03 |
| WRL-03 — Objects and exact-copy interaction | Query/create/transfer/equip/use/damage/destroy object copies, preserving copy identity, contents, charges, fuel, material and linked actor/object effects. Examples: charged wand; pack contents; Folding Boat. | **partial** — inventory-copy transactions, item charges and room object state exist; generic activation/material/container/vehicle interactions are not modeled. | `Inventory` instance operations; `LocalRoomRules`; `CombatObjectRules`. | QRY-06, STA-01, OPS-06 |
| WRL-04 — Movement modes and spatial transitions | Query legal path, speed, difficult terrain, occupancy, altitude, falling, forced movement and consent; support bounded walking/flying/climbing/swimming plus selected new modes. Examples: forced push into a fall; Roving climb/swim speed; Ghost Step through solid objects. | **partial** — room/combat movement and bounded elevation/fall paths exist; many movement modes, joint transport, phasing and burrowing do not. | `Character.get_speed`; `CombatState`/room path queries; `LocalRoomRules`; fall settlement. | QRY-05, WRL-01, WRL-06 |
| WRL-05 — Areas, barriers, and persistent room changes | Create, move, filter crossings through, and expire areas/barriers; persist relevant terrain/object changes and resolve entry/turn effects. Examples: Spike Growth; Cube of Force; Earthquake fissures. | **partial** — selected spell zones and room objects persist; general authored zones, barrier filters and terrain-changing operations are missing. | `CombatSpellZones`; `LocalRoomRules`; `DungeonPersistence`; `GameManager` clock. | EVT-03, WRL-03, WRL-04, STA-03 |
| WRL-06 — Perception and senses | Determine visibility, LOS, illumination, senses, observer-specific detection and perception origin, with range/obstruction/material facts. Examples: Darkvision; invisible/hidden targets; Crystal Ball sensor perception. | **partial** — modeled lighting/senses/wall LOS exist in bounded contexts; exact cover/volume, remote origins and some physical facts do not. | `CombatPerception`; `Character` senses; room/combat visibility. | QRY-05, WRL-04 |
| WRL-07 — Communication and adjudicated world facts | Query language/telepathy/listeners or store a human-decided outcome when a rule depends on open-ended truth, intent, history, social response, or unmodeled locations. Examples: telepathy; broad Divination/Wish; erased-history or business/property outcomes. | **missing** as a general world/adjudication capability. A human GM path is not implemented. | No general hook identified; existing event outcomes are bounded authored choices/checks. | QRY-01, WRL-01, STA-04 |

## Concrete vocabulary checklist

These are building blocks, not 97 new modules or a demand to implement every
example. Each box covers the boundary stated in its row. Different damage types,
die sizes, distances and reset counts are parameters unless they change execution
semantics. Examples identify local source descriptions, not certified gameplay.

All 97 parent boxes remain open where their full boundary is unfinished. The
checked VS items above record accepted smaller boundaries from retained logs.
**Partial** includes those proved subsets as well as older paths established only
by source inspection; only the cited subset is verified. **Uncertain** means a suitable generic path
has not been established; a likely hook is a place to start, not proof of support.
**Missing** is used only for the previously documented absent general capability.
Dependencies are prerequisite vocabulary, not mandatory up-front scaffolding.
Source keys such as C-Rogue and I are linked in the discovery scope below.

### Facts, expressions and settled results

Refines QRY-01/04/05/06 and EVT-02. “Query context” must identify which facts a
rule can ask for; “formula” must identify which values it can calculate with.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-001 — Typed predicates and combinations | Read declared facts and combine comparisons with AND/OR/NOT and explicit missing-fact behavior. Distinguish actor, target, action, item, spell and source facts. | C-Barbarian: Brutal Strike requires Reckless Attack and no Disadvantage; C-Monk: Martial Arts equipment eligibility. | Partial: VS-27 checks nested typed predicates and missing-safe evaluation; VS-28 binds actor/target/action/item-copy/spell/source identities through the combat shared-spell host. Other hosts, fact domains and broader combinations remain open. | — |
| [ ] V-002 — Actor/source relationships | Query ally/enemy/willingness, who charmed or marked a target, and distance to another actor or source. A condition name alone cannot identify its giver. | C-Bard: Mantle of Majesty auto-failure only when charmed by that Bard; C-Ranger: companion attacking its owner's marked target. | Partial: current source-owner relation is checked in VS-02; ally/enemy/willingness, charm/mark provenance and distance relations remain open. | V-001 |
| [ ] V-003 — Check purpose and required sense | Carry the actual task, tool, sensory requirement and originating effect into a check/save. “Avoid or end Poisoned” differs from any Constitution save. | I: Perfume influences an Indifferent Humanoid nearby; R: Dwarven Resilience; C-Bard: Dance Virtuoso. | Partial: VS-24 checks loaded EventDialog task/purpose/optional-tool context and exact carried-tool eligibility/source receipt through closure. Other hosts, sensory requirements, causal save purposes and broader interpretation remain open (`EventResolver`, `Inventory`). | V-001 |
| [ ] V-004 — Scoped action and damage history | Query first round, first own turn, whether a target acted/was attacked, and damage since a named boundary. Current turn and since owner's previous turn are different intervals. | C-Rogue: Assassinate; C-Ranger: Horde Breaker; M: Hydra head/regrowth histories. | Partial: existing active-turn serial supplies VS-08 locks, not arbitrary authored action/damage history. First-round/own-turn and since-boundary queries remain open (`CombatState`). | V-001 |
| [ ] V-005 — Physical eligibility facts | Query actual size, mass, worn/carried/fixed status, material, plane and available space rather than infer them from content names. | C-Psi Warrior: Telekinetic Movement's loose-object limit; R: Goliath Large Form needs space; I: Horn of Blasting glass/crystal damage. | Partial: room/object fields, `CombatObjectRules`, `LocalRoomRules`; many facts unmodeled. | V-001 |
| [ ] V-006 — Numeric references to prior results | Bind an exact step/target/component result: raw damage, mitigated damage, prevented amount, actual HP loss or healing. Aggregate only the declared results; preserve rounding. | I: Rod of Lordly Might heals half its extra Necrotic damage; C-Warlock: Beguiling Defenses reflects damage taken; C-Sorcerer: surge heals sum of Necrotic damage. | Partial: explicit earlier step/target/type/measure selectors and one explicit cross-target sum are checked in VS-03/17. Other component/result combinations, prevented/healed amounts and general reducers remain open. | V-001 |
| [ ] V-007 — Runtime formulas and tables | Calculate from declared class/character level, selected slot, ability, proficiency, source die or a choice; support min/max, rounding and table lookup. Freeze or reevaluate at the declared boundary. | C-Zealot: Rage Damage bonus determines dice count; C-Soulknife: rolled teleport distance; R: character-level breath scaling. | Partial: shared arithmetic, caster/cast leaves, and one deterministic numeric breakpoint table exist (VS-04/16). Dice/source-die tables, choices, multiclass progression and broader capture policies remain open. | V-001, V-006 |
| [ ] V-008 — Natural-roll versus final-total floors | Alter the natural d20 separately from the modified total; neither operation changes the other's meaning. | C-Rogue: Reliable Talent floors d20; C-Barbarian: Indomitable Might replaces a low final total with Strength score. | Partial: native floor methods in `Character`; authorable selectors/order uncertain. | V-007 |
| [ ] V-009 — Modifier and base-stat combination | Select among base AC formulas, apply conditional bonuses/score floors/caps, and use declared stacking or recipient choice. Keep a score-setting effect separate from a permanent increase. | I: Gauntlets of Ogre Power; C-Druid: Moon's higher AC; C-Paladin: recipient chooses one overlapping protection aura. | Partial: `Character`/inventory stat paths; broad combination policy uncertain. | V-001, V-007 |
| [ ] V-010 — Resolution event facts and windows | Expose before-roll, after-natural-roll, provisional hit/failure, pre-damage, settled damage, cast completion and source end as distinct windows. Carry attack kind, school, paid slot, source and targets. | C-Lore: Cutting Words after success; C-Glamour: Beguiling Magic after a slot-paid cast; I: Gloves of Missile Snaring after a ranged hit. | Partial: named hooks and verified rest/weapon-hit paths (VS-07/08/13), plus the rolled-failed-save pre-consequence choice and subsequent damage-choice handoff (VS-18–20). VS-31 also checks exact shared-spell attack window receipts and ordered effect consumers across deferred damage; general subscriptions, cast/source-end windows and other hosts remain open. | V-001 |
| [ ] V-011 — Result predicates and cross-step gates | Branch on margin, post-damage HP, all/any child outcomes and earlier result references, not just hit/miss or save success. | I: Lolth's Sting fails by 5; I: Tentacle Rod hits same target three times; I: Mace of Disruption checks HP after damage. | Partial: `when` predicates and explicit earlier-result comparisons now supplement simple gates; VS-05 checks a positive component across continuation and VS-17 checks positive aggregate HP loss after a settled area step. Margins/grouped outcomes/other gates remain open. | V-006, V-010 |

### Rolls, outcomes, interception and damage

Refines QRY-02/03, OPS-01/02 and CHO-02/04. A reroll, a changed total and an
automatic outcome are three different operations.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-012 — Pre-roll Advantage/Disadvantage policy | Add/cancel/forbid Advantage or Disadvantage before rolling; resolve multiple sources and exemptions without confusing a roll-mode change with replacing a natural result. | C-Clockwork: Restore Balance; C-Rogue: Elusive; C-Barbarian: Brutal Strike gives up Advantage. | Partial: VS-29 authors exact-context owned add/cancel/prohibit policies with source exemptions for loaded EventDialog ability checks; other roll hosts, native feature coverage and S-106 rerolls remain open. | V-001, V-010 |
| [ ] V-013 — Natural result or automatic outcome replacement | Replace natural d20, force hit/miss/save success/failure, or cancel an upcoming Death Save. A forced success is not a numeric bonus or a newly rolled 20. | I: Ring of Evasion; C-Paladin: Unerring Strike; C-Glamour: Command auto-failure; C-Celestial: Searing Vengeance before Death Save. | Partial: VS-20/30 check explicit save outcomes and VS-30 checks supported weapon/shared-spell attack outcomes after its reviewed native-use and source-option repairs; no-roll outcomes, canceled Death Saves, other hosts and general token replacement remain open. | V-010, V-011 |
| [ ] V-014 — Reevaluate a provisional result | Add/subtract a post-roll total or change AC for one triggering attack, then recalculate its result before consequences; expose that new result to a follow-up. | C-Paladin: Glorious Defense counterattack only if changed hit misses; C-War: Guided Strike; C-Soulknife: Homing Strikes. | Partial: VS-18 checks a fixed failed shared-spell save bonus; VS-21/22 add normal player Attack/Extra Attack and flat/ordered shared-spell attacks; VS-23 adds one captured d6/d8 through these checked combat choices; VS-25 adds fixed/die bonuses to failed loaded EventDialog ability checks. Other rolls, hosts, defensive edits and broader reevaluation remain open. | V-010, V-011 |
| [ ] V-015 — Save and miss consequence remapping | Independently select damage and riders on success/failure/miss; support evasion and chosen target exemptions without changing other targets' outcomes. | C-Evoker: Potent Cantrip damage after miss without rider; Sculpt Spells; C-Dance: share Evasion for same save. | Partial: shared save gates/half damage; native Evasion; generic per-recipient remapping uncertain. | V-011, V-013 |
| [ ] V-016 — Damage stages and scoped bypass | Modify one incoming component or whole occurrence at a declared stage, retain overflow, and declare exactly which mitigation layers are bypassed. | C-Monk: reduce entire eligible attack; I: Sword of Answering ignores Resistance/Immunity; C-Evoker: Overchannel harm. | Partial: damage/ward settlement is shared in bounded paths; generic stage/bypass policy uncertain (`CombatAction`, `WardRules`). | V-006, V-010 |
| [ ] V-017 — Split or transfer damage to another actor | Split a specific incoming occurrence using declared rounding and eligibility; create the other recipient's linked settlement without replaying the original attack. | M: Animated Rug of Smothering linked victim damage; earlier wiring map: guardian partner damage. | Uncertain: likely typed damage settlement and actor-pair state. | V-002, V-006, V-016 |
| [ ] V-018 — Damage absorption and feedback control | Bind a replacement/healing/counter-damage to the qualifying incoming or settled amount, and preserve causal identity so feedback follows its declared limits. | M: Iron Golem Fire absorption despite immunity; C-Great Old One: Thought Shield; I: absorption/prevention examples in prior map. | Partial: ordinary healing/damage; absorption and feedback policies uncertain (`CombatAction`). | V-006, V-010, V-016 |
| [ ] V-019 — Cancel a cast or negate a recipient | Cancel all qualifying pending spell effects or exclude only a named recipient, with declared level/target/school predicates and already-spent costs retained. Reflection is separately V-097. | I: Ioun Stone Absorption; C-Arcane Trickster: Spell Thief negates only its own effect. | Partial: native reaction pipeline; generic negation scope uncertain (`SpellCast*`). | V-010, V-011, V-014 |
| [ ] V-020 — Replace a proposed zero-HP outcome | Intercept before unconsciousness/death, distinguish outright death and declared damage/critical exclusions, and allow a save with escalating DC or replacement HP formula. | R: Orc Relentless Endurance; C-Barbarian: Relentless Rage; C-Zealot: ally revival Reaction; typed Zombie rule. | Partial: shared `replace_hp` and zero-HP rule fields; actor/form-specific extensions uncertain. | V-007, V-010, V-011 |
| [ ] V-021 — Destruction, death and aftermath | Apply instant destruction or death distinctly from ordinary HP loss; retain or destroy gear/remains, create a successor actor/hazard, and pass facts to revival eligibility. | I: Mace of Smiting destroys weak Construct; Sphere of Annihilation leaves gear; Eye/Hand combined creates slime. | Partial: `CorpseRules`, created-creature/object paths; generic aftermath uncertain. | V-005, V-011, V-020 |
| [ ] V-022 — Outcome contingent on legal placement | Resolve required exit/arrival space before finalizing a result when no legal space changes that result; ordinary successful-save settlement cannot commit early. | M: Gelatinous Cube save can fail if no legal exit; I: Titan summoning wastes scroll on insufficient space. | Uncertain: likely spatial validation and pending step decisions. | V-005, V-011 |
| [ ] V-023 — Dice-level edits and result multipliers | Remove damage dice before rolling, reroll/maximize selected dice, then apply declared critical or post-result multipliers to the correct component. | C-Rogue: Cunning Strike pays Sneak dice; C-Assassin: Death Strike doubles attack damage; C-Life: maximum healing dice. | Partial: native metamagic/Sneak paths; generic dice/result transforms uncertain (`Dice`, `CombatAction`). | V-006, V-007, V-010 |
| [ ] V-024 — Scoped attack/damage parameter replacement | Select ability, damage die/type, reach, mastery or fixed attack/DC for the actual qualifying attack/cast; distinguish replace, add and inherit-original-type. | C-Elements: choose type after hit; C-World Tree: extra mastery; I: fixed +7 Ring of the Ram; C-Dance: nonconsuming class-die damage. | Partial: native attack profiles/shared spell fields; cross-domain authoring uncertain. | V-001, V-007, V-010 |

### Choices, grants, casting and costs

Refines CHO-01/03, STA-01 and OPS-04/05. Casting permission, the resource paid
and the resulting spell parameters must remain separate facts.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-025 — Choice acquisition, replacement and prerequisites | Define option count/filter, selection boundary, duplication allowance and dependent prerequisites. Replacing a choice must preserve dependent grants or refuse. | C-Warlock: invocation dependencies; C-Hunter: rest-swapped tactics; R: lineage and spellcasting ability choices. | Partial: `ClassProgression` choice methods; reusable lifecycle uncertain. | V-001 |
| [ ] V-026 — Permanent progression grants | Apply proficiencies, expertise, ability/max-HP changes and equipment exactly once at creation/class/character-level boundaries; distinguish starting from multiclass grants. | R: Dwarven Toughness; C-Draconic: per-Sorcerer-level HP; raw class multiclass proficiency fields. | Partial: `ClassProgression`, `Character`; data-wide acquisition policy uncertain. | V-007, V-025 |
| [ ] V-027 — Grants owned by exact source instances | Acquire/query/remove a benefit from the correct class, item copy, spell or actor source; one source ending must not revoke another equivalent grant. | I: Hat of Disguise removal ends its spell; R: lineage spell entitlement; C-Warlock: pact versus other-class grants. | Partial: numeric pools (VS-06), timed AC (VS-12), next-melee-hit grants (VS-13), optional cooldowns (VS-14) and expiring Temporary HP provenance (VS-15) are checked. Broader grant domains, cross-actor grants and acquisition UI remain open. | V-002, V-025 |
| [ ] V-028 — Casting permissions and alternative payment | Offer a spell via prepared, book ritual, item, innate, limited-free, point-paid or slot-paid permission. Retain source ability, allowed level, list and components. | C-Aberrant: Psionic Sorcery; C-Wizard: Ritual Adept; I: scroll; C-Barbarian: ritual-only Animal Speaker. | Partial: named casting paths; generic permission objects uncertain (`ClassProgression`, `SpellCast*`). | V-025, V-027 |
| [ ] V-029 — Per-source repertoire and slot progression | Keep each class's preparation limit/list/ability distinct from combined payable slots, Pact slots and fixed Arcanum uses. Apply declared rounding and replacement boundary. | C-Eldritch Knight/Arcane Trickster one-third casting; C-Warlock: Arcanum; class design multiclass examples. | Partial: native spell-access/slot tables; generic profiles uncertain (`DataLoader`, `ClassProgression`). | V-007, V-025, V-028 |
| [ ] V-030 — Cast-local parameter transformations | Alter school, range, origin, action timing, components, concentration, duration or summon HP only for the qualifying invocation; never mutate its catalog definition. | C-Illusionist: Phantasmal Creatures; C-Fey Wanderer: non-Concentration short summon; C-Great Old One: Psychic Spells. | Partial: native benefits/metamagic; shared transform contract uncertain (`SpellCast*`, `SpellEffects`). | V-001, V-028 |
| [ ] V-031 — Cast costs based on exact outcome | Reserve/commit/refund the correct slot/use for interruption, failed activation or failed spell stopping. Costs can remain spent even when no payload happens. | C-Abjurer: Spell Breaker refunds failed stopping; I: scroll preserves on interruption but disappears on failed check; Hat of Many Spells spends before check. | Partial: ordered casts preserve cost once; generic outcome payment/refund uncertain. | V-010, V-011, V-028 |
| [ ] V-032 — Extend targets or redirect origin for one invocation | Add allowed targets or change a selected origin while preserving one cast, the originating senses and independent target outcomes. | C-Beast Master: Share Spells; C-Bard: Words of Creation second target; C-Trickery: Duplicity origin uses caster senses. | Partial: shared targets and native targeting; generic extension/origin bindings uncertain. | V-002, V-028, V-030 |
| [ ] V-033 — Replace attack/strike units | Treat an Attack/Flurry as a declared set of units; substitute one or multiple units with a permitted spell, item use, heal or companion command. | C-Eldritch Knight: spell replaces two attacks; C-Mercy: healing replaces Flurry strikes; R: breath replaces one attack; I: Net. | Partial: native budgets/actions; generic unit replacements uncertain (`CombatTurnBudget`, `CombatState`). | V-025, V-028 |
| [ ] V-034 — Nested actions and local cost overrides | Invoke permitted child actions inside a parent action/Bonus/Reaction with explicit waived costs and classifications; preserve remaining budgets and actual causal source. | C-Dance: strike when Inspiration spent; C-Archfey: child Misty Step in same action; C-Wild Heart: Dash plus Disengage. | Partial: named composites; general action composition uncertain. | V-010, V-031, V-033 |
| [ ] V-035 — Optional payment after success or failure | Reserve a chosen resource during a modification, reevaluate, and charge only the declared outcome. The modifier may still require a resource available upfront. | C-Soulknife: Knack/Homing spend only if converted to success; C-Lore: Peerless Skill; C-Fighter: Tactical Mind. | Partial: VS-19/21/22 check pay-on-choice and converted-success on owned failed saves and weapon/shared-spell attacks; VS-23 adds one captured die with upfront availability and final-outcome payment; VS-25 checks both policies for loaded EventDialog ability-check fixed/die bonuses. Other policies, roll domains and hosts remain open alongside named helpers. | V-011, V-014 |
| [ ] V-036 — Allocate one numeric pool across recipients | Choose eligible recipients and distribute an integer total without exceeding pool, per-target cap or declared recipient count. Unspent remainder and refusal follow explicit cost policy. | C-Life: Preserve Life caps at half max HP; C-Glory: split rolled Temporary HP; C-Clockwork: Cavalcade healing. | Partial: native Lay on Hands; generic multi-recipient allocator uncertain. | V-005, V-007, V-025, V-035 |
| [ ] V-037 — Choose modes at declared boundaries | Separate permanent choice, rest choice, per-activation choice, per-hit choice and turn-start switch. Replace prior mode grants without resetting the parent lifetime/use. | C-Wild Heart: choice each Rage; C-Stars: constellation switch at turn start; C-Elements: resistance switch; C-Land: rest land choice. | Partial: progression/native feature choices; common mode lifecycle uncertain. | V-010, V-025, V-027 |

### Resources, limits, time and recovery

Refines OPS-04, STA-02/03 and EVT-04. Pool capacity, uses consumed and a
procedure's current position are not interchangeable counters.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-038 — Source-owned numeric and dice pools | Define capacity/die size, spend selected quantity, retain captured die identity where needed, and keep class/copy pools separate even if they share names. | C-Psi Warrior and Soulknife have separate Psionic dice; C-Zealot/C-Celestial healing dice pools. | Partial: exact-source numeric capacity/current/query/spend and formula capacity are checked in VS-06; bounded die-size/count activation in VS-10; one captured post-roll die paid from a numeric source in VS-23. Transferable/pre-rolled dice, wider acquisition/progression and source examples remain open (`ResourcePoolRules`). | V-007, V-027 |
| [ ] V-039 — Restore one resource by spending another | Validate which depleted use can be restored, select payment/amount and atomically exchange resources; do not grant extra uses when at capacity. | C-Moon: slot restores Moonlight Step uses; C-Barbarian: Rage restores intimidation; C-Warlock: Pact slot restores Hurl use. | Partial: the fixed 2-for-1 numeric-pool subset is production checked in VS-11; `ClassProgression.restore_resource_from_spell_slot` remains separate code. Spell-slot/dice payments, arbitrary currency, conditional/post-roll costs, cross-actor transfer, catalog conversion and other selectors/policies remain unverified. | V-031, V-038 |
| [ ] V-040 — Budgeted and filtered recovery | Select expended slots/pools within a formula budget, exclude levels, or recover lowest eligible/lower-than-paid slot; retain source pool distinction. | Arcane/Natural Recovery; C-Diviner: Expert Divination; C-Sorcerer: surge lowest expended slot. | Partial: `RestRules` budgeted slot recovery; additional selectors uncertain. | V-007, V-029, V-038 |
| [ ] V-041 — Use locks with explicit scope and subject | Scope limit to each turn, own turn, target per turn, roll, active effect instance, first round, or owner-turn interval. Pool availability and per-option lock are independent. | C-Fey Wanderer: target once per turn; C-Zealot: once per Rage; M: dragon legendary pool and option lock. | Partial: independent actor/source/option combat-turn and target-per-turn rider locks are checked in VS-08. Own-turn/round/roll/active-instance/first-round scopes and general history remain open. | V-004, V-027, V-038 |
| [ ] V-042 — Conditional free uses and cost replacement | Waive a qualifying payment while keeping other limits; replace one pool's payment without spending a different option's use. A free die roll needn't consume a die. | C-Battle Master: Relentless substitute d8; C-Mercy: free Hand within Flurry; I: Thief charge waiver; C-Sorcerer: one free Metamagic per own turn. | Partial: native waivers; generic cost proposal uncertain. | V-023, V-031, V-038, V-041 |
| [ ] V-043 — Depletion and overflow consequences | After spending/gaining, branch on last charge, cumulative capacity or failed roll; destroy/degrade/recharge the exact copy while preserving declared residual properties. | I: Staff of Power depletion; Staff of the Magi absorption overflow; Rod of Absorption lifetime capacity separate from current stored energy. | Partial: `Inventory.spend_instance_charges/destroy_instance`; generic aftermath/overflow uncertain. | V-011, V-027, V-038 |
| [ ] V-044 — Recovery event and amount policy | Restore one/all/up-to-floor/random quantity at turn start, Initiative, rest completion, dawn/dusk or elapsed cooldown. Changing capacity or location must not imply refill. | C-Bard: Initiative floor two; I: Robe of Stars dusk recovery; M: in-lair capacity; C-Monk: mutually exclusive Initiative recovery choices. | Partial: fixed/capacity recovery on matching numeric-pool rest completion is checked in VS-07; growth does not refill (VS-06). Initiative/floor/random/dawn/dusk/cooldown policies remain open. | V-007, V-010, V-038, V-041 |
| [ ] V-045 — Active-use budget versus wall-clock duration | Retain cumulative on-time or distance and pause/resume it without restarting allowance; begin cooldown at the declared end rather than activation. | I: Oil fuel can burn nonconsecutively; Wings of Flying cooldown starts when wings disappear; prior Figurine time budgets. | Partial: VS-14 checks cooldown from scheduled expiry or actual dismissal, including late observation and a jump past both deadlines. Cumulative on-time/distance and pause/resume budgets remain open. | V-027, V-038, V-044 |
| [ ] V-046 — Work progress with deadlines and interruption | Accumulate qualified study/work, require proximity/concentration/participants, constrain daily rest and time window, and distinguish lost progress from lost paid material. | I: Manuals 48 hours within six days; Golem manuals; Hag Eye coven rite; Nolzur's Pigments. | Uncertain: likely campaign clock, inventory, source-owned procedure state. | V-005, V-031, V-045 |
| [ ] V-047 — Repeat saves, counts and staged outcomes | Repeat at target-turn or elapsed-time boundaries, count qualifying successes, branch on margin or transition to next condition stage. Dependent conditions end only by specified routes. | I: Pale Tincture seven successful saves; Wand of Wonder staged petrification; Lolth's Sting linked sleep. | Partial: `SpellEncounterLifecycle` repeat saves; arbitrary counters/stages uncertain. | V-010, V-011, V-038, V-041 |
| [ ] V-048 — Rest start, completion and benefit-only recovery | Distinguish rest-start expiry, successful completion, elapsed time, actor eligibility and immediate rest-like benefits; spell/item policy can alter duration or spend Hit Dice. | R: Elf Trance; C-Diviner: Third Eye ends at rest start; I: Rod of Security hourly Hit-Die-equivalent healing. | Partial: current rest completion/control/eligibility boundaries for numeric pools are checked in VS-07 (`RestRules`). Rest-start expiry, benefit-only recovery, alternate durations and Hit Dice remain open. | V-007, V-010, V-038 |

### Effects, auras and durable relations

Refines OPS-03, STA-01/03/04 and WRL-05/06. Grant owner, beneficiary, controller,
bearing actor and the actor whose clock expires it can be different identities.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-049 — Source-linked termination predicates | End a grant on declared damage, attack roll, spell cast, movement, equipment removal, Incapacitated/Unconscious/death, range or replacement. Exempt damage from an explicitly identified causal source. | C-Cleric: Sear damage does not end Turn Undead; C-Barbarian: Persistent Rage changes termination; I: invisibility differs by potion. | Partial: VS-12/13 check campaign expiry and exact-source removal; VS-14 adds owned voluntary dismissal. Declared action/status/range predicates and causal damage exemptions remain unverified. | V-002, V-010, V-027 |
| [ ] V-050 — Suppress a condition without removing it | Query a condition as ineffective for eligible recipients while its original source/duration remains, then restore its effect when suppression ends. | C-Paladin: Courage/Devotion aura suppresses existing Fear/Charm; earlier map Ear Horn. | Partial: native immunity/aura paths; general suppression uncertain (`Character`). | V-001, V-027, V-049 |
| [ ] V-051 — Consume the next matching grant | Store eligibility/source/target and spend a one-shot benefit only on the next qualifying event before expiry; ignore nonmatching events. | C-Eldritch Knight: next save against own spell; C-Fighter: next attack against missed target; C-Moon: next attack after teleport. | Partial: VS-13 checks one source-owned melee-weapon-hit matcher with bounded fixed typed damage, ordered consumption, expiry/removal and allowed-checkpoint state. Other matchers, target predicates, general event authoring and cross-domain grants remain unverified. | V-002, V-010, V-027, V-041 |
| [ ] V-052 — Expiring Temporary HP and linked benefits | Track which source supplied remaining Temporary HP and remove only that source's surviving amount/benefits at expiry; don't treat all Temporary HP as permanent. | C-World Tree: recipient Temporary HP vanish when Rage ends; I: Potion of Heroism timed Temporary HP. | Partial: exact-source timed Temporary HP, keep-higher replacement and current owner cleanup are checked by VS-15; replacement-choice UI, cross-actor ownership and linked benefits remain open. | V-027, V-049 |
| [ ] V-053 — Dynamic aura membership and chosen beneficiary | Recompute moving emanation recipients and suppression; preserve transient entry benefits beyond leaving when declared. Separate owner's formula/DC from bearer and recipient. | C-Sea: Oceanic Gift aura uses giver's values; C-Glory: entry Speed lasts through next turn; C-Paladin: aura selection. | Partial: native combat auras/zones; generic bearer/membership lifecycle uncertain. | V-002, V-007, V-009, V-049, V-050 |
| [ ] V-054 — Transfer a captured grant to another actor | Give a recipient an owned token/die/permission with captured generation values, independent expiry and spender budget. Granting actor leveling later must follow declared snapshot policy. | Bardic Inspiration and Valor recipient Reaction; C-Dance: shared single rolled Initiative bonus. | Partial: `RollTokenRules` saved tokens/native Inspiration; generic transferable grants uncertain. | V-027, V-038, V-049 |
| [ ] V-055 — Modify another rule's parameters or options | A feature extends/replaces an existing rule's count, die, targets, options, permissions or end predicates. Apply once and avoid stacking mutually exclusive Extra Attack/base AC policies. | C-Mercy: Flurry upgrades; C-World Tree: extra mastery; C-Barbarian: Persistent Rage; C-Ranger: Foe Slayer die replacement. | Partial: named upgrades; general data-defined feature modification uncertain. | V-009, V-024, V-025, V-037 |
| [ ] V-056 — Aftermath on source end | Emit one source-end event with final state/origin, then start follow-up timer or effect; distinguish dismissal, expiry, destruction and death when required. | C-Trickery: Duplicity heals near illusion on end; I: Wings cooldown; prior Draakhorn aftermath. | Partial: VS-14 checks one captured cooldown aftermath for expiry/dismissal without replay. Source removal starts no cooldown. Destruction/death reasons, arbitrary aftermath and general source-end subscriptions remain open. | V-006, V-010, V-027, V-049 |
| [ ] V-057 — Durable rule state at allowed checkpoints | Save exact instances, relations, choices, counters and deadlines; restore without replaying acquisition or generating new rolls. Validate before session replacement. Active decisions remain transient. | Stored spell contents; Quivering Palm target; item study/use histories; existing ward/token recovery. | Partial: numeric pools (VS-09), fresh-process timed AC/next-hit/cooldown state (VS-12–14), Temporary HP provenance (VS-15) and malformed source/deadline refusal are checked. Lookup/sum add no durable state. Other payloads and generic envelopes remain open; decisions/turn locks stay transient. | V-027, V-038, V-045, V-049 |

### Actors, action control, forms and spaces

Refines OPS-05/06 and WRL-01/02/04/05. These rows are distinct world capabilities,
not permission to create separate monster and class engines.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-058 — Parameterized actor factory | Instantiate template with owner-linked AC/HP/attack/DC/count, selected options and exclusions. Separate current/max HP and prevent copied forbidden creation features. | M: Summon Dragon; animated Treant trees; C-Beast Master: chosen companion template. | Partial: owned/created creature ledgers; generic factory uncertain (`CreatedCreatureRules`). | V-005, V-007, V-024, V-027 |
| [ ] V-059 — Command authority and initiative relationship | Define independent, owner-turn, immediately-after-owner or shared-count action scheduling; command cost/range/default and autonomy on owner incapacity. Control expiry need not destroy actor. | C-Beast Master; I: Staff of the Python; Iron Flask timed obedience; creature designs. | Partial: familiar/steed/undead paths; arbitrary authored scheduling/control uncertain (`CombatState`, `AICommand`). | V-002, V-033, V-038, V-058 |
| [ ] V-060 — Extra turns and off-turn action budgets | Insert a full turn or permitted child action at a declared position while preserving interrupted work. Distinguish extra Action, own-turn-only use and additional Opportunity-only Reactions. | C-Thief: second first-round turn at Initiative minus ten; M: Hydra limited extra Reactions; dragon legendary actions. | Partial: `CombatTurnBudget` Action grants; general turn insertion/type-limited Reaction pools uncertain. | V-010, V-033, V-034, V-041, V-059 |
| [ ] V-061 — Exclusive bonds and linked replacements | Bind exact actor/item to owner, enforce uniqueness/capacity and refusal, replace old source deliberately, and carry group-related disposal. | C-Eldritch Knight: weapon bonds; C-Stars: replace map destroys previous; I: linked Sending Stones. | Partial: creature/copy identity; generic bond contract uncertain. | V-002, V-027, V-057 |
| [ ] V-062 — Reversible actor statistics and equipment policy | Project declared form fields; retain original HP/resources/type/mental stats/features as specified; choose dropped/merged/worn equipment and disable only merged effects. | C-Druid: 2024 Wild Shape retains HP; Moon parameter modifications; M: possession mixed stats. | Partial: `DruidRules` bounded forms; general retained-field/equipment policy uncertain. | V-005, V-009, V-027, V-055, V-058 |
| [ ] V-063 — Item-to-actor/object form lifecycle | Preserve original exact copy across temporary actor/vessel projection; define reversion location, HP reset/overflow, destruction and retained contents. | I: Staff of Python differs from Animate Objects; Folding Boat cargo retention; Staff of Adder damageable head. | Partial: Animated Object hooks and room objects; generic item-form contract uncertain. | V-005, V-021, V-057, V-058, V-062 |
| [ ] V-064 — Grapple, restraint and physical anchor relation | Bind creature to creature/object/anchor with range and escape/rescue/damage routes; attach explicit action restrictions and remove effect when tether object is destroyed. | I: Net, Hunting Trap, Manacles/Rope; Tentacle Rod; M: smothering relation. | Partial: restraint conditions/room escape; general actor-object relations uncertain. | V-002, V-005, V-021, V-027, V-049 |
| [ ] V-065 — Containment, capacity and occupant movement | Hold creatures/gear inside creature/object/space; model eligible capacity, internal damage/air, rescue/escape, owner motion and release placement. | M: Cube/Tarrasque containment; I: Mirror cells, Portable Hole, Iron Flask. | Uncertain: no adequate general containment path established; likely world ledgers and room placement. | V-005, V-022, V-057, V-064 |
| [ ] V-066 — Possession and controller/host routing | Keep controller and host identities, mixed statistics, awareness, attack/effect target routing and return of control separate. | M: Ghost possession; I: sentient-item domination; source-specific 24-hour immunity. | Uncertain: current actor ownership is a starting point, not possession support. | V-002, V-057, V-059, V-062 |
| [ ] V-067 — Corpse eligibility and distinct revival policies | Query elapsed death/preservation, remains, soul willingness/freedom, and restrictions; choose revival HP, condition/body repairs and aftereffects without replacing original identity. | C-Mercy: Ultimate Mercy; I: Rod of Resurrection; earlier Revivify/Gentle Repose/created Undead paths. | Partial: `CorpseRules`; broader revival policies uncertain. | V-005, V-021, V-057 |
| [ ] V-068 — Destinations, planes and return-space policy | Represent actual destination knowledge/plane, arrivals, passengers, saved previous point and nearest-legal fallback; distinguish travel from temporary removal. | C-Fiend: Hurl Through Hell; I: Robe of Stars; Rod of Security; Well of Many Worlds. | Partial: native room teleports/campaign transitions; general planar locations uncertain. | V-005, V-022, V-057, V-059 |
| [ ] V-069 — Movement modes, surfaces and end placement | Declare speed/mode, terrain costs, occupancy, climbing hands, hover, phasing/burrowing and legal end location; expire flight into fall/descent/shunt as specified. | C-Shadow: occupied-space shunt; R: Halfling pass-through; I: Winged Boots controlled descent; Spider Slippers slippery exclusion. | Partial: `LocalRoomRules`, `Character`, native fall paths; general modes/end policies uncertain. | V-005, V-022, V-024, V-049 |
| [ ] V-070 — Linked passenger and Reaction movement | Move selected willing passengers with a source, or offer each beneficiary their own Reaction movement, with separate destinations/budgets and declared opportunity suppression. | C-Moon/Fey Wanderer passenger teleport; C-Monk: passenger Step; C-Dance/Glamour: allies spend their own Reactions. | Partial: native movement; shared passenger/multi-actor continuation uncertain. | V-002, V-034, V-059, V-069 |
| [ ] V-071 — Spatial triggers and selective barriers | Trigger entry/crossing/start/end/first-approach at declared scope; block selected actors/effects and handle moving barrier over occupants rather than just rejecting movement. | I: Shooting Stars first approach; Scroll of Protection ends on moving over excluded creature; Shield of Cavalier displaces partial occupants. | Partial: `CombatSpellZones`; generic barrier filters/placement uncertain. | V-005, V-010, V-022, V-041, V-053, V-069 |
| [ ] V-072 — Nonoccupying illusions and constrained realization | Represent image/sound/duplicate with identity, location, observer discovery and no creature occupancy. Realize eligible temporary objects with explicit harm/condition prohibition through child effects. | C-Trickery: Duplicity; C-Illusionist: real temporary bridge; R: clockwork effect devices. | Missing as a general authored illusion/realization path in current world notes; room objects are a reuse point. | V-005, V-027, V-056, V-071 |

### Perception, physical items and information

Refines WRL-03/06/07. A perception result can be direction-only, location-only,
identity or full visibility; those must not all reveal the same information.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-073 — Observer-relative senses and concealment | Evaluate actual observer sense, light, obstruction and source-specific exceptions; seeing a location does not necessarily see a creature. | C-Gloom Stalker: unseen by Darkvision observer only; C-Shadow: sees own Darkness; R: stone-contact Tremorsense. | Partial: `CombatPerception`; source/observer-specific exceptions uncertain. | V-003, V-005, V-053 |
| [ ] V-074 — Separate perception, cast and effect origins | Use a remote sensor/illusion/object for only the origins permitted, while retaining the actor's real senses or communication limitations. | C-Trickery: cast from illusion using own senses; I: Hag Eye multiple observers; familiar borrowed senses. | Partial: bounded familiar senses/touch delivery; common origin binding uncertain. | V-002, V-027, V-032, V-073 |
| [ ] V-075 — Filtered detection and information permissions | Return specified facts/direction/nearest source; enforce masked type/thought permission/material thickness and knowledge-grant limits. Do not reveal full actor sheet accidentally. | C-Battle Master/Hunter: reveal defenses; I: Wand of Enemy Detection direction only; Ring Mind Shielding; X-ray thickness. | Partial: `CombatPerception`, named detection; generalized filtered disclosure uncertain. | V-001, V-005, V-073, V-074 |
| [ ] V-076 — Container quantities and capacity | Store exact contents and mass/volume/liquid/portion limits, including compartment/type constraints and overflow behavior. Fuel on-time uses V-045; attached parts use V-094. | I: Haversack compartments; Quiver of Ehlonna item-category capacities; Waterskin portions. | Partial: inventory copies/room contents/water; general capacity policy uncertain. | V-005, V-027, V-038 |
| [ ] V-077 — Crafting and work completion transaction | Consume declared materials/time and required recipe inputs, then create exact output copies or invoke a specified world change. Retain interruption policy and acquisition identity. | I: Golem manuals; tools' Craft lists; Nolzur real doors/pits. | Partial: `LocalRoomRules` changes/inventory; generic recipe completion uncertain. | V-003, V-005, V-031, V-046, V-076 |
| [ ] V-078 — Cause-specific survival exemptions | Track food/water/travel/environment exposure and query exemptions to a particular consequence. A foodless Exhaustion exemption does not cancel combat Exhaustion or every hazard. | C-Monk: Self-Restoration; I: horseshoes extended travel; Ring of Warmth temperature protection. | Partial: campaign survival/Exhaustion; generalized cause/eligibility adapter uncertain. | V-003, V-005, V-045, V-049 |
| [ ] V-079 — Curses, attunement and magic-property lifecycle | Keep curse after unequipping where specified; constrain voluntary unattunement, suppress/restore properties, and apply exact breaking/destruction requirements. Mundane residual properties can survive magic loss. | I: Shield Missile Attraction; Orb of Dragonkind; Staff Power depletion; Artifact destruction requirements. | Partial: `Inventory` cursed attunement and exact-copy destruction; general authored lifecycle uncertain. | V-005, V-027, V-043, V-061 |

### Procedures, campaigns and additional result state

Refines EVT-02/04, OPS-04/06, STA-02/04 and WRL-07. These requirements came from
unloaded descriptions as well as the authored Crown adapters.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-080 — Weighted/random procedures and controlled selection | Execute a rolled table outcome as a procedure, preserving nested rolls, reroll-and-choose, forbidden choices and recurrence/no-recursion policy. Resolve referenced templates and random eligible targets. | C-Wild Magic: Surge, Controlled Chaos, Tamed Surge; I: Wand Wonder/Hat Many Spells; L: nested loot tables. | Partial: `EventResolver`, native random tables; reusable procedure vocabulary uncertain. | V-007, V-011, V-025, V-034, V-058 |
| [ ] V-081 — Sequence position and remaining membership | Store ordered procedure position or exact remaining faces separately from use pool; preserve removal/replacement and deferred choice/deadline. | M: Sphinx ordered Roars; prior wiring map: deck draw procedures. | Partial: native counters; generic sequence/deck state uncertain. | V-038, V-045, V-057, V-080 |
| [ ] V-082 — Campaign objectives and delayed rewards | Query real collection/defeat/exploration facts, apply milestone/reward once after actual qualifying outcome, and retain child event/encounter completion relation. | E: Quest Board bounty reward after combat; mountain map revelation; Crown entry/clear milestones and win goals. | Partial: `GameManager.check_milestone/are_win_conditions_met`, `EventResolver`; shared reward continuations uncertain. | V-004, V-010, V-027, V-057, V-080 |
| [ ] V-083 — Communication, knowledge and adjudicated facts | Model sender/listener/language, authored knowledge/attitude and bounded requested outcome. Request/store human judgment for unmodeled intent, lie, social response or invented destination. Unknown is an explicit result. | C-Druid: Druidic hidden messages; C-Aberrant: language-qualified telepathy; I: Truth Serum; S: knowledge/foraging checks. | Missing as a general GM/knowledge workflow; bounded event choices/messages are reuse points. | V-003, V-057, V-074, V-075 |
| [ ] V-084 — Store and release a spell with caster snapshot | Store exact spell, paid level and original caster DC/attack/ability in an exact copy with capacity; charging suppresses ordinary effect and can waste a slot if full. Release once using the new caster's ownership but retained numbers. | I: Ring of Spell Storing/Ioun Stone Reserve. | Uncertain: inventory-copy state and cast context are likely hooks; generic spell storage not established. | V-027, V-028, V-031, V-038, V-057 |
| [ ] V-085 — Source-specific unrecoverable damage | Track damage that cannot be healed separately from other missing HP, and lift that restriction only when its source policy permits. Ordinary healing, rest and revival must honor it. Max-HP loss is separately V-095. | I: Pale Tincture blocks healing its poison damage, not every injury. | Partial: general healing suppression; injury-specific provenance uncertain (`Character`, recovery paths). | V-006, V-016, V-048, V-049, V-067 |
| [ ] V-086 — Capability requirements for complete procedures | Derive required operations, facts, choice routes and referenced children before offering/charging. Refuse or declare precise partial support for missing capability, not identity allowlisting or silent skipped child. | E: narration reveals information without modeled fact; I: scroll may invoke unavailable spell; raw maneuver references lack bodies. | Partial: `SharedSpell` field validation, native availability; generic dependency closure uncertain (`DataLoader`, `SpellSupport`). | V-001, V-025, V-028, V-080 |

### Further splits that preserve distinct semantics

These retain separate boxes where a single broad word would conceal different
state or execution requirements. They are grouped here to keep V-001–086 stable.

| Open ID — capability | Boundary to implement and mark off | Description examples | Current support / likely hook | Depends on |
|---|---|---|---|---|
| [ ] V-087 — Steal temporary casting permission | On the qualifying failed enemy save, grant the thief preparation and forbid that enemy's casting of the exact spell for a deadline; remove only those restrictions/grants afterward. This does not store a cast. | C-Arcane Trickster: Spell Thief's eight-hour knowledge theft. | Uncertain: `ClassProgression`, casting eligibility and owned timed grants are likely hooks. | V-019, V-027, V-028, V-049, V-057 |
| [ ] V-088 — Escalating DC or cumulative risk | Store the count/history used to calculate current DC/chance, reset only at the declared boundary, and choose when attempts increment it. | C-Barbarian: Relentless Rage DC rises; I: Wind Fan and Potion of Longevity cumulative failure chances. | Partial: native Relentless counter; generic authored risk uncertain. | V-007, V-038, V-044, V-057, V-080 |
| [ ] V-089 — Reroll with declared kept-result policy | Reroll a qualifying natural die or entire test at the stated window; choose old/new only where allowed, apply declared bonuses/mode and settle once. | R: Halfling must use new result; C-Bard: Countercharm adds Advantage; C-Fighter: Indomitable adds level to reroll. | Partial: VS-26 checks owned mandatory-new natural/whole-test rerolls in loaded EventDialog event/choice checks, declared mode/bonus policy, floor stages, original/new receipts and one cost/settlement. Old/new selection, other roll hosts and broader bonus/mode edits remain open alongside native rerolls and `RollTokenRules`. | V-010, V-012, V-023 |
| [ ] V-090 — Natural-result replacement tokens | Generate/capture distinct result tokens with owner, visibility and reset; replace before rolling or at a separately authorized post-roll window. Equal values remain different tokens; don't roll another d20 unless required. | C-Diviner: Portent; C-Rogue: Stroke of Luck sets failed roll to 20. | Partial: shared pre-roll `RollTokenRules`; post-roll natural replacement uncertain. | V-010, V-027, V-038, V-041, V-057 |
| [ ] V-091 — Air supply and breathing eligibility | Model available air shared by actual breathing occupants, environment adaptation and suffocation progression; an exemption changes consumption as well as consequence. | I: Portable Hole/Haversack air budgets; Necklace of Adaptation; Potion of Water Breathing. | Uncertain: world/survival adapters are likely hooks; general breathing model not established. | V-005, V-045, V-065, V-078 |
| [ ] V-092 — Body-part loss and restoration | Store lost/attached parts, functional effects and eligible restoration progress; interrupt regrowth when required living-HP condition ceases. | I: Ring of Regeneration; Prosthetic Limb; M: Troll/Hydra part lifecycle. | Uncertain: original actor identity/corpse/form ledgers are likely hooks. | V-005, V-021, V-046, V-057, V-067 |
| [ ] V-093 — Physical age and age-rate changes | Track biological age separately from elapsed campaign time; apply decrease/floor, aging immunity/rate and stored repeat-use history. | I: Potion of Longevity; C-Druid: Archdruid age rate; C-Ancients: no magical aging. | Uncertain: campaign clock/actor state; no general age query established. | V-007, V-045, V-057, V-088 |
| [ ] V-094 — Attached parts and child-copy identities | Represent attached gem/bead/shoe/weapon/adhesive relationship; require specified set, keep each component's use state, and route removal or damage to affected properties. | I: Prayer Beads each reset separately; Helm gems destroyed by casting; four horseshoes; Ruby of War Mage; Sovereign Glue. | Partial: inventory exact copies; generic attachment/part identities uncertain. | V-005, V-027, V-038, V-061, V-076 |
| [ ] V-095 — Owned maximum-HP changes | Apply/remove max-HP delta or periodic reduction with source provenance, cure boundary, floor and zero-limit death/remains policy; distinguish reducing max HP from marking damage unhealable. | M: Vampire typed damage reduces max HP; prior map: Mummy rot reductions and cure. | Partial: native max-HP attack riders; general source-owned policy uncertain (`Character`, `CombatAction`). | V-006, V-016, V-021, V-049, V-057 |
| [ ] V-096 — Repair actual object state | Restore HP/function or join retained pieces of an existing exact object, subject to material/piece/location eligibility, without generating a fresh copy or recovering missing pieces automatically. | C-Clockwork: Cavalcade repairs damaged objects; I: Rope of Mending loses missing sections. | Partial: room object HP/state; generic repair operation uncertain (`LocalRoomRules`, `CombatObjectRules`). | V-005, V-027, V-076, V-094 |
| [ ] V-097 — Redirect or reflect the original spell | Propose a new target for only the permitted incoming spell/step, retain original parameters or declared reflected-caster policy, and avoid new slot payment/recasting. | I: Ring of Spell Turning versus Staff of Charming; M: Tarrasque reflection. | Partial: native cast pipeline; generic causal target replacement uncertain (`SpellCast*`, `SharedStepExecutor`). | V-002, V-010, V-019, V-028, V-032 |

## Proposed implementation order

The [roadmap](../../roadmap.md#capability-workstreams) now assigns every V-series
entry to one workstream and owns its priority. The selected P1 facts/results and
caster/cast inputs, followed by P2 numeric pools, rest recovery, combat-turn
limits, timed/next-hit grants, temporary HP and deterministic numeric breakpoint
lookup now have bounded evidence recorded in VS-01–17. Do not reschedule
those slices from the unchecked parent boxes. P2's bounded dice-pool extension
(`V-038`) has focused production evidence recorded in VS-10; its fixed numeric
exchange subset (`V-039`) is checked in VS-11. The owner's-turn-interval
extension is checked within VS-08. The source-owned timed numeric grant is
checked in VS-12, the bounded next-matching melee-hit grant in VS-13, and
optional expiry/dismissal cooldown in VS-14. Temporary HP provenance, numeric
tables and earlier-step result aggregation are checked in VS-15–17. The first
P3 save-decision subsets are VS-18–20: one post-roll bonus, its conditional
payment option and a separate explicit save-success outcome. VS-21–23 check
normal player weapon and shared-spell attack choices, followed by one authored
die alternative across the accepted save and attack chooser paths. Dependency IDs
help keep each batch small without requiring entire families to be completed
first.

Discovery, building vocabulary, checking it and translating content remain
separate steps. V-057 covers state at existing allowed checkpoints; current
compatibility priorities follow ADR-0023. This checklist does not authorize
destructive file work or introduce mid-decision saving.

## Resolved direction and deferred details

The owner resolved these planning questions in
[ADR-0023](../decisions/0023-vocabulary-first-delivery-and-bounded-world-judgment.md).
They are no longer requests for another permission or a prerequisite design pass.

- Aim to express the intended rules by chaining shared facts, comparisons,
  arithmetic and operations. Distinguish missing operations from missing world
  facts/actions and interpretive outcomes. Add concrete world capabilities as
  needed. Actual authoring syntax is chosen with the selected implementation.
- Use proper resolution stages so a canceled hit never spends damage prevention.
  Resolve detailed precedence when actual selected rules interact; don't front-load
  hypothetical conflicts across the whole catalog.
- There are no existing player campaigns to preserve. Compatibility/migration
  planning does not gate ordinary vocabulary work. Keep owner/target/use state and
  Short/Long Rest, minute/hour and campaign clock behavior connected. Existing
  checkpoint limits and non-destructive file boundaries remain.
- Illusions use suspicion/context and Intelligence-influenced investigation
  behavior, followed by the spell's own discovery rule and per-observer knowledge.
  High Intelligence is not automatic detection. Wish uses supported ordinary
  functions plus executable campaign-authored special outcomes. A universal GM
  interface is not required for those bounded behaviors.
- Missing intended 2024 bodies remain a separate later source-discovery task.
  Investigate added requirements, including exceptions to illusion/Wish handling;
  do not turn it into content correctness testing.

Deferred details are concrete source gaps listed below and implementation choices
for a selected batch, not unresolved owner direction. The
[roadmap](../../roadmap.md) now owns build order and the next facts/result batch.

## Parked, judgment-dependent, and unexamined scope

**Parked or outside the current target:** Artificer and Mystic; later supplements;
legacy editions, controllers/networking/publication and a new high-level campaign.
The reference reads deliberately select XPHB/XDMG and the accepted revised-rules
requirements. Staging and unloaded catalogs are useful discovery sources; being
unloaded does **not** exclude their in-scope mechanical requirements. Reading them
does not authorize promotion or make the broader PHB scope the current SRD milestone.

**Needs additional represented facts/actions or bounded authored outcomes:**
language/telepathy, open-ended divination/Wish, body/age, crops/planes, vehicles,
contained occupants, sensors/materials and history/property/social outcomes.
Some can be implemented mechanically once their world facts exist; others need
a campaign-authored decision/outcome. This is not an automatic classification of
every such rule as requiring a human GM. Follow ADR-0023's illusion/Wish policy,
and keep truly unrepresented outcomes unavailable until chosen.

**Remaining discovery scope:**

- Raw class references name optional features and feats whose complete bodies were
  not found as standalone local JSON: Battle Master maneuvers, parts of Metamagic,
  invocation catalogs, Fighting Styles, Origin/Epic Boons and other feat choices.
  The existing core audit/design supplies some requirements, but a reference name
  does not establish the rest. Locate the intended bodies before declaring these
  domains exhausted. Missing bodies stay missing; no memory-derived rules added.
- Some 2024 item entries point to shared `{#itemEntry ...}` text that is not
  supplied by their itemGroup. This includes common Ioun Stone, Dragon Scale Mail,
  Enspelled and grenade text. Bodies already present elsewhere were read; unresolved
  common mechanics remain a source gap. Hazard/Artifact-property/book references
  likewise need their actual intended bodies. Flavor trinkets are not automatically
  new engine operations.
- This pass reuses the earlier core spell/monster description audit. It does not
  reread every core spell/monster or establish a complete source-reconciled XPHB/XMM
  corpus. Revised monster discriminators come from the existing design's documented
  requirements; their linked external texts were not fetched. Unrepresented revised
  spells/stat blocks can add vocabulary when their local corpus is supplied.
- Detailed spell-list/slot tables and duplicated extracts are not individually
  certified. Shared grant shapes and exceptions were read for vocabulary. A complete
  rules-clause/source-fidelity review remains a separate task.

Existing wrong numbers, malformed/truncated/conflicting source data and reproduced
gameplay defects remain content repairs or bugs, not discovery investigations.
No uncertain support was tested. This is a **completed static discovery pass over
the domains listed below**, with the source gaps above; it is not a claim that
the complete intended rules vocabulary has been exhausted.

## Discovery findings and inspected domains

The earlier document had 31 broad families. It now retains those IDs and adds
**97 concrete V-series entries** with examples, static support, likely hooks and
dependencies. Most entries refine an existing family; 97 does not mean 97 wholly
absent functions or 97 rules newly discovered in the repository. Several had
already appeared in the wiring map/design and now become explicit checkboxes.

Requirements made explicit by fresh description reads include:

- **Result provenance:** original caster snapshots in stored spells (V-084),
  temporary stolen permission versus storage (V-087), and source-specific
  unrecoverable damage versus max-HP loss (V-085/095).
- **Outcome timing:** provisional-hit reevaluation before a counterattack
  (V-014), outcome-dependent cost/refund (V-031/035), placement before committing
  a save outcome (V-022), and a reflected original cast versus recipient negation
  (V-019/097).
- **Scope and ownership:** once per target/turn versus once per active Rage
  (V-041), giver/bearer/beneficiary aura values (V-053), source-end aftermath
  (V-056), and independent component/linked-copy state (V-061/094).
- **Control:** Attack-unit substitutions (V-033), recipient-paid Reaction
  movement (V-070), a second complete first-round turn (V-060), and observer-relative
  concealment plus independent spell/perception origins (V-073/074).
- **Procedure state:** sequence position versus pool quantity (V-081), cumulative
  risk (V-088), and interrupted/deadlined work (V-046).

Family refinements are grouped above each concrete table. All six original
organizing areas were expanded. Numeric result references, casting profiles,
stored spell state, procedure sequencing and recovery-blocked injury state were
particularly underspecified in the consolidated checklist.

| Source key / domain | Static discovery performed | Limit |
|---|---|---|
| **C-…** — [raw core-twelve class files](../../5etools%20raw/class/) | Read XPHB mechanical class/subclass feature bodies across all twelve files and their 48 subclass names, nested references/tables where exposed, spell-grant exceptions and class multiclass/profile fields. Repeated advancement wrappers, flavor and ordinary always-prepared tables were treated as repeated shapes. C-… may name a class or its subclass. | Linked optional-feature/feat bodies remain unresolved. This is vocabulary reading, not per-feature correctness or complete table reconciliation. |
| **I** — [items.json](../../items.json) | Read XPHB/XDMG entries/additional text in the previously unfinished `/item/788` through end range: **480 in-scope records** selected, including records with no new prose or only common-text references. Inspected the 34 XPHB/XDMG itemGroup shapes/text; combined Eye/Hand properties separately. Earlier item-range findings were reused. | Count is selection scope, not 480 full independent mechanical bodies or behavior proofs. No-text trade goods/variants add parameters, not automatic operations. Missing common-text/hazard/book bodies remain unresolved. |
| **R** — [races.json](../../races.json) | Read descriptions of all ten XPHB species, including lineage/ancestry choices, character-level grants, rest, body/sense/movement and once-per-turn clauses. | Legacy/setting species were excluded. Derived copies are not independent certified rules. |
| **S** — [skills.json](../../skills.json) | Read all eighteen XPHB task descriptions for check-context, knowledge/social and world-outcome requirements. | A successful check alone does not model its fictional outcome. |
| **L** — [loot.json](../../loot.json) | Inspected XDMG individual/hoard, gem/art and magic-item table shapes with representative rows and nested item/quantity selection. | No row-by-row loot correctness review or value balancing. |
| **E** — [event tables](../../data/core/events/) and [Crown](../../data/core/campaigns/the_lost_crown.json) | Read authored choice/check/combat/chain/shop/rest/reward descriptions and payloads, campaign goals/milestones and relevant tactical object facts. Used these to identify world transactions and delayed reward/fact needs. | Custom campaign content is an adapter example, not 2024 rules authority. Narration is not proof a world fact is implemented. |
| **M** — [creature design discriminators](../architecture/data-driven-2024-monster-execution-plan.md#source-discriminators-that-must-not-be-lost) | Read documented revised monster requirements: legendary budgets, absorption, Hydra/Troll histories, containment, possession, lifecycle, information filtering, factories, Roar sequence and reflection. | Reused documented source requirements; did not fetch external corpus or certify current monster behavior. |
| Design/core audit cross-check | [Class mappings](../architecture/data-driven-2024-class-execution-plan.md#6-the-hardest-mappings-and-adversarial-acceptance-cases), [world foundations](../mechanics/spell-foundations.md), earlier wiring/core findings. | These support scope and dependencies; proposed syntax is not an implemented vocabulary. |

Read-only discovery helpers filtered local JSON by source tag and printed text;
they did not execute rules, generate a correctness ledger, run tests/probes or
change content. CodeGraph was attempted through its existing read-only database:
it indexes Python/Liquid, not GDScript. Agent Ground had no callable tool. Narrow
source reads therefore used `rg`: current step/effect vocabularies, resource/rest
constants and likely progression, inventory, room, corpse and campaign hooks.

The static inventory itself is not runtime evidence. Checked VS entries cite
only their specific production evidence; parent capabilities remain open unless
their full rows are separately implemented and tested.

## Basis

Consolidated from [current checkpoint](../operations/current.md), [architecture map](../architecture/README.md), [roadmap](../../roadmap.md), [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md), [ADR-0019](../decisions/0019-shared-ordered-execution-and-zero-hp-replacement.md), [data-to-runtime review](dnd-data-runtime-gap-review.md), and [runtime wiring map](dnd-runtime-wiring-map.md), then extended through the separate source reads listed above. Source references in the earlier reviews identify existing hooks; static partial/uncertain labels are not new behavior proof. No Godot launch, tests, probes or definition mutation occurred.

