# Shared numeric resource pools

## Numeric breakpoint formulas — production checked

The existing shared numeric formula evaluator accepts a deterministic
`breakpoint_lookup` object. Its `input` uses existing numeric formula leaves
and arithmetic; `breakpoints` contains 1–20 rows with strictly increasing
integer `threshold` values and bounded integer `value` outputs:

```json
{
  "op": "breakpoint_lookup",
  "input": { "caster_level": true },
  "breakpoints": [
    { "threshold": 1, "value": 2 },
    { "threshold": 5, "value": 3 },
    { "threshold": 9, "value": 4 }
  ]
}
```

Evaluation selects the value on the greatest threshold at or below the input;
above-last inputs keep the final value. Below-first inputs fail explicitly and
propagate failure through formulas instead of becoming zero. The lookup input
cannot contain dice/random formulas. Tables are limited to 20 rows, integer
thresholds from -999 to 999, integer values from 0 to 999, and formula nesting
depth 12. The neutral pool fixture is
`data/fixtures/shared_numeric_breakpoint_pool.json`. Numeric pool capacity uses
the actor-only version of the shared formula evaluator; growth preserves
remaining uses and shrink clamps them. The same lookup operation is available
inside ordinary ordered shared spell effect formulas. Production acceptance
covered neutral and renamed tables, below-first failure, growth/shrink behavior,
malformed-data refusal, and an ordinary shared spell consumer. See VS-16 in the
[vocabulary checklist](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off).
This is not a dice/source-die table, multiclass progression table or general
table engine.

## Bounded source-owned next-matching melee-hit grant — production validated (2026-10-12)

The current source supports one bounded next-hit effect for shared class
features:

```json
{ "type": "next_matching_melee_hit", "amount": 2, "damage_type": "fire", "duration_seconds": 60 }
```

The payload is fixed typed damage with an integer amount from 1 to 100, one of
the existing damage types, and a 1–86400 campaign-second duration. The feature
must own a numeric resource pool. Activation pays once and records the owner,
exact source, unique grant ID, acquisition order, payload and absolute expiry
deadline on the Character. One unspent grant per source is allowed. The oldest
unexpired grant is consumed by the owner's next qualifying melee weapon hit,
after final hit/miss resolution and before damage settlement. It enters the
existing typed damage path as fixed damage, so critical hits do not double it
and resistance/immunity still apply. Misses, ranged attacks, canceled attack
targeting and other actors leave the grant pending; exact-source removal and
campaign-time expiry clear only that source's grant. Pending state is included
in allowed Character checkpoints.

The neutral example is
`data/fixtures/shared_next_melee_hit_grant.json`. Production and focused
development checks are recorded in the [current checkpoint](../operations/current.md#accepted-slice--next-matching-melee-hit-grant-2026-10-12).
Production acceptance also loaded a renamed +3 Cold variant, proved Fire
resistance and immunity plus Cold resistance, actual attack/menu outcomes,
source order/removal/expiry and fresh-process checkpoint recovery with malformed
save refusal before replacement. The checked boundary is VS-13; general event
facts/subscriptions and other matchers remain open. Evidence is under
`.artifacts/tests/4370e8a4ce7d4d1291bbdda17786aa86/` and
`.artifacts/tests/next-melee-hit-grant-relaunch-286d5a6bdb03400eb9acdfab1481088b/`.

## Optional timed-grant cooldown — production validated (2026-10-13)

The existing `timed_numeric_modifier` operation can optionally include a
`cooldown_seconds` campaign-time value from 1 to 86400. Omission or zero keeps
the existing no-cooldown behavior. The active grant captures that value together
with its effect deadline; later definition changes do not alter it. For example,
`data/fixtures/shared_timed_numeric_cooldown.json` grants +2 AC for 60 seconds,
then blocks that exact source for 3600 seconds.

Expiry starts the cooldown at the grant's absolute expiry deadline, even if a
later update notices it. The combat feature menu exposes a free dismissal entry
for each currently active exact-source grant; dismissal starts cooldown at the
current campaign time. A blocked activation does not spend pool uses, and rest
recovery does not clear the separate cooldown. A single campaign-time jump past
both deadlines leaves the source ready. Active and cooldown-only Character
checkpoint state retain grant/source identity and absolute deadlines.

Production acceptance covered the actual combat feature menu and dismissal
control, exact boundaries, pool payment, rest recovery and two independent
sources. Omission/zero retained the previously accepted behavior. Active and
cooldown-only snapshots survived fresh-process recovery with identity and
absolute deadlines intact; malformed full-save preflight refused before session
replacement. The exact accepted boundary is VS-14: expiry and voluntary
dismissal start cooldowns; source removal clears its active grant and retained
cooldown without starting a new cooldown, and other end reasons remain unsupported.
Tagged timed grants and cooldown records must reference an owned saved source
pool; a tagged grant without its deadline refuses loading. Definitions may
contain at most one timed numeric grant and one next-hit grant per activation;
duplicate same-kind operations refuse at loading rather than partially applying
after payment. See the [current
checkpoint](../operations/current.md#accepted-slice--optional-cooldown-after-timed-grant-end-2026-10-13),
[production scenario](../../.artifacts/tests/2b29a42808f848dcb577f74d69d88500/)
and [fresh-process probe](../../.artifacts/tests/timed-numeric-cooldown-relaunch-1bd96120f7504b64a3e1933fbe653946/).

## Bounded source-owned timed numeric grant — production validated (2026-10-12)

Shared class-feature activations may currently author one bounded timed numeric
modifier effect:

```json
{ "type": "timed_numeric_modifier", "kind": "stat", "key": "AC", "amount": 2, "duration_seconds": 60 }
```

This build supports only an AC stat modifier, with a nonzero integer amount from
-100 to 100 and a campaign duration from 1 to 86400 seconds. The feature must
own a numeric resource pool. Activation pays through the existing exact-source
pool path, captures the amount and absolute `campaign_elapsed_seconds` deadline,
and records the owner, source instance and unique grant instance on the
Character. One source may have one active grant; another source instance stacks
additively under the existing modifier query. Duplicate activation is refused
before payment.

Campaign-time advancement expires the grant at its deadline. Combat turn ticks
do not reduce its duration. The existing source-pool removal operation removes
that source's grant and pool while leaving other sources and ordinary modifiers
intact. Allowed Character checkpoints save and validate the grant with no replay
on load; elapsed campaign time determines whether it remains active.

The neutral example is `data/fixtures/shared_timed_numeric_grant.json`.
Production checks exercised neutral and renamed definitions through DataLoader
and the real combat activation menu. They covered minute and hour parameters,
one-use payment and +2 AC, duplicate refusal before payment, staggered source
deadlines, just-before/exact/after expiry, exact-source removal, unrelated
modifier preservation, combat turn ticks, combat/exploration campaign-time
advancement, scene changes, and a large jump past expiry. Two fresh processes
proved allowed-checkpoint recovery preserves owner/source/grant serial/payload/
absolute deadline without reactivation or lifetime restart; malformed full-save
preflight refused before live-session replacement. Evidence is recorded as VS-12
in the [vocabulary checklist](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off),
with raw output under `.artifacts/tests/dda2fafb854345deb66c201809c18779/` and
`.artifacts/tests/timed-numeric-grant-relaunch-0f1cceb0b6ac4904b444f1e2482cadb4/`.
Stacking limits are only the current additive numeric modifier behavior; no
AC-specific cap or alternative combination rule is introduced. General
condition effects, arbitrary modifier payloads, and other save-state families
remain outside this checked subset.

## Bounded subset — production validated (2026-10-12)

An active shared class-feature definition may declare a `resource_pool` with a
stable definition `id`, a supported shared `capacity_formula`, and an explicit
`initial_quantity`. The existing `SharedStepExecutor` formula vocabulary
evaluates actor values such as proficiency bonus. The existing `ClassFeature`
activation path validates the feature, checks its action and pool availability,
spends the declared quantity once, then resolves its supported effects.

Mutable pool state belongs to one `Character` and one exact
`source_instance_id`. Acquisition, availability, spending, activation,
capacity recalculation and removal all use that identity. Two sources using the
same definition therefore have separate state. The owner ID is saved with the
pool and checked during save preflight.

## State behavior

- Acquisition evaluates capacity and validates the explicit initial quantity
  before adding state. Duplicate source-instance acquisition refuses and does
  not refill the existing pool.
- Availability queries do not mutate state. Spending requires a positive
  bounded amount and sufficient current quantity; a failed spend leaves state
  alone.
- Capacity recalculation changes capacity only. Existing current quantity is
  retained when capacity grows and clamped down if capacity shrinks. It never
  refills the pool.
- Removing a source removes only that exact source-instance pool. Removing or
  acquiring a source is an explicit owner operation; querying or loading does
  not replay acquisition.
- Character checkpoints persist owner, source instance, definition ID, capacity
  and current quantity in the existing safe-save DTO. Missing optional state in
  an older schema-2 DTO remains empty. Save preflight validates the state before
  session replacement.

The production combat feature menu exposes one entry per exact owned source
instance and carries that identity through the shared command and activation
path. A focused production Godot scenario used this definition and a renamed
equivalent. It verified formula capacity, authored initial quantity, independent
instances, successful and refused activation, menu cancellation, capacity growth
and shrink, exact-source removal, and an allowed SaveManager save/reload that
preserved owner/source/quantity without reacquisition.

Evidence: `.artifacts/tests/f53f61526df641ba82bcda1f553010ec/` using
`run_tests.ps1 -Suite all -LogicGroup classes -Scenario shared_numeric_pool_flow`
on Windows Godot 4.7. The later combined run at
`.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/` passed pool activation/checkpoint,
rest recovery and rider-limit scenarios together. Dice pools, exchanges, source discovery/acquisition UI, catalog
conversion, other definitions and fresh-process/manual gameplay remain outside
this checked subset.

## Bounded numeric-pool exchange — production validated (2026-10-12)

An active shared `class_feature` may declare one fixed exchange instead of its
own use pool. The payment and restoration IDs name existing numeric pool
definitions on the same actor; each quantity is a fixed positive integer from 1
to 100:

```json
"resource_exchange": {
  "payment_pool_id": "example:pool_a",
  "payment_quantity": 2,
  "restoration_pool_id": "example:pool_b",
  "restoration_quantity": 1
},
"effects": []
```

At activation the production choice path offers exact owned source instances
for each side. They must be different sources. The command takes only those
source IDs from the choice; the pool definitions and quantities come again from
the actor's owned feature. Both pools must still belong to that actor, match the
authored definitions, and satisfy payment and full restoration capacity. Dice
pools are not eligible. The entire restoration must fit; partial recovery is
not allowed.

Validation computes both new quantities before either is stored. A successful
exchange writes both exact source states once. Cancel, changed/stale ownership,
same-source selection, insufficient payment, unknown/mismatched definitions,
and insufficient destination room leave both quantities unchanged. The neutral
two-for-one example is `data/fixtures/shared_numeric_pool_exchange.json`.
Production Godot acceptance also loaded a renamed equivalent and drove both
exact-source popups in combat. It proved one 2-for-1 commit on the selected
sources, unchanged unrelated sources and actor pools, refusal without charging
for cancellation at either popup, insufficient payment, a full destination,
same-source selection, another actor's source, a removed stale source, repeated
submission and forged exchange parameters. An allowed checkpoint save/load
preserved neutral and renamed exchanged counts without reacquisition or replay.

Evidence: `.artifacts/tests/b35a6f698e8f48fb807b4bc82aa808d7/` for the combined
bootstrap, parse, boot, class logic, pool, dice, exchange and recovery run;
dedicated exchange log:
`.artifacts/tests/e0621b7db58a4165b1386dd90ff0380a/shared_numeric_pool_exchange_flow.stdout.log`.

This is the fixed numeric-pool subset of V-039 only. Spell-slot/dice payments,
arbitrary currencies, conditional or post-roll costs, cross-actor transfers,
catalog conversion, and other exchange selectors/policies remain unverified.
No save fields were added.

## Completed-rest recovery policies — production validated (2026-10-12)

A numeric pool may add a `recovery` object inside `resource_pool`. Its keys are
completed-rest triggers and each trigger has one policy:

```json
"recovery": {
  "short_rest_completed": { "mode": "restore_fixed", "amount": 1 },
  "long_rest_completed": { "mode": "restore_to_capacity" }
}
```

`restore_fixed` accepts an integer `amount` from 1 to 100. It adds that amount
to the current quantity and caps the result at capacity. `restore_to_capacity`
sets current quantity to capacity and takes no amount. Unknown triggers, modes,
non-integer/out-of-range amounts and an `amount` on a fill policy are refused
by pool definition validation.

`RestRules` applies these policies once from the successful completion path for
the matching rest type, after the existing actor-eligibility check. Only living,
conscious party Characters participate; dead, 0-HP, familiar and steed actors
are excluded. Recovery looks up the exact pool definition on that actor and
applies the policy to each exact owned source-instance pool. One actor cannot
recover another actor's pool, and every update stays at or below saved capacity.
Short and Long triggers are distinct, so a Long Rest does not also run a
Short-Rest policy.

Starting the rest choice, cancelling it, a refused rest, loading a checkpoint,
or campaign-time advancement alone do not call this completion recovery. The
existing rest durations and controls are unchanged. Recovery settles directly
into the current quantity already stored by allowed Character checkpoints, so
this slice adds no saved fields. It does not implement dawn/dusk or Initiative
recovery, arbitrary cooldowns, Hit Dice policies, resource exchanges, or
catalog conversion. The neutral example in
`data/fixtures/shared_numeric_pool.json` was loaded alongside a renamed equivalent
in the production controls scenario. Its passing run covers actual Overworld
Short Rest and Dungeon entrance Long Rest controls, cancellation/refusal, time,
eligibility, exact-source recovery and checkpoint reload without recovery replay.
Evidence: `.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/numeric_pool_rest_recovery_normal_controls_flow.stdout.log`.
This retained evidence completes the selected acceptance boundary; no extra
acceptance run is pending. Alternate rest/eligibility policies and the broader
V-044/V-048 requirements remain open.

## Existing combat-turn hit-rider limits — production validated (2026-10-12)

A shared class feature may put a `weapon_damage_rider` in `passive_effects`
alongside its `resource_pool`. It can declare `use_limit` as
`once_per_combat_turn` or `once_per_target_per_combat_turn`. The rider's effect
`id` names the limited option. The neutral data example used by focused checks
is `data/fixtures/shared_combat_use_limits.json`. For example:

~~~json
{
  "resource_pool": {
    "id": "example:steady_spark_pool",
    "capacity_formula": { "caster_proficiency_bonus": true },
    "initial_quantity": 2
  },
  "passive_effects": [{
    "type": "weapon_damage_rider",
    "id": "steady_spark_hit",
    "trigger": "weapon_attack_hit",
    "damage_type": "force",
    "dice_by_level": { "1": "1d4" },
    "use_limit": "once_per_target_per_combat_turn"
  }]
}
~~~

The normal weapon-hit aftermath hook evaluates the rider. It checks the exact
owning Character, exact pool source instance, effect option, current
`CombatAction.active_turn_serial`, and—when requested—the target's stable
character or creature ID. The turn serial advances at the existing combat turn
boundary; it is not the round number. The once-per-combat-turn and
per-target-per-combat-turn limits share that boundary. The owner-turn-interval
form below uses a separate per-owner lock reset at the existing turn-start
hook; once-per-round policies remain unsupported.

A miss, dead/ineligible target, missing or mismatched pool, empty pool, or
already-used limit skips the rider. None changes the original attack result.
Only after the rider qualifies does it spend exactly one pool use and record its
limit lock, then apply the rider's supported damage effect. This authored lock
is independent of pool quantity: a pool with more uses still cannot bypass the
selected once-per-turn or once-per-target limit.

Combat-turn locks are transient and clear at every existing combat turn start.
Removing a source stops it from supplying a rider; its pool state is removed by
the existing exact-source removal operation. If that same source ID is
reacquired during the same turn, its combat-turn option remains locked until
the next turn starts. Owner-interval locks follow the per-owner reset policy
below. A new source ID has a separate lock. Locks are not written to Character
checkpoints; active combat remains unsaveable. No arbitrary event subscriptions
or catalog conversion are part of this slice.

The focused Godot scenario uses the production weapon resolver, CombatState
rider aftermath hook, and real combat start/end-turn initiative path. It checks
neutral and renamed option/pool definitions, both limits, duplicate completion,
actor/source independence, a second target, misses, failed melee eligibility,
and pool exhaustion. Final evidence:
`.artifacts/tests/31bbd8579b194f46b3589b20a6b96517/shared_combat_use_limits_flow.stdout.log`.
The combined pool/recovery regression is retained at
`.artifacts/tests/26038762fe2948a4ad5521fe7eec6432/`.
This does not cover UI target selection or manual campaign play. The checked
subsets and remaining parent requirements are tracked as VS-06–09 in the
[vocabulary checklist](../reviews/dnd-code-vocabulary-gap-checklist.md#verified-subsets-to-mark-off).

## Owner-turn-interval hit-rider limit — production validated (2026-10-12)

The same source-owned weapon-hit rider may declare
`"use_limit": "once_per_owner_turn_interval"`. It uses the same exact owner,
source-instance, option ID, verified numeric pool and one-use payment as the
combat-turn forms. It needs no target ID. The weapon must still be a weapon and
the rider's normal trigger, eligibility and damage checks still apply. Omit
`own_turn_only` (or set it to `false`) when qualifying hits outside the owner's
turn should count; this limit itself does not require the owner to be active.

```json
"passive_effects": [{
  "type": "weapon_damage_rider",
  "id": "steady_spark_hit",
  "trigger": "weapon_attack_hit",
  "damage_type": "force",
  "dice_by_level": { "1": "1d4" },
  "use_limit": "once_per_owner_turn_interval"
}]
```

Keep the feature's existing `resource_pool` beside this effect; a qualifying
hit spends one use from that exact source's pool.

An owner interval begins at combat entry before that owner's first turn start.
Its lock begins clear. A qualifying off-turn hit can set that lock, and the
owner's first turn start clears it. Thereafter, each start of that same owner's
turn clears only that owner's owner-interval locks. Starts for other characters
and monsters leave it alone. Therefore a qualifying use anywhere between two
successive starts of the owner's turn shares one use, including uses made on
other actors' turns; this is neither once per round nor own-turn-only.

Locks stay in transient combat memory. Removing a source removes its pool and
stops its rider from being offered, but does not erase that source/option lock
before the owner's next turn start. Reacquiring the same source ID in that
interval stays locked; a different source ID has its own lock. Owner reset does
not restore pool quantity. The existing combat-turn and per-target-combat-turn
locks keep their current reset and target policies. Combat remains unsaveable;
this adds no checkpoint state, general event history, round or active-effect
limits, arbitrary subscriptions or catalog conversion.

The neutral authored example is the second feature in
`data/fixtures/shared_combat_use_limits.json`. Godot 4.7 production acceptance
ran that neutral definition and a renamed copy through actual Opportunity
Attacks, the production weapon aftermath hook and real initiative turn starts.
It checked the initially clear pre-first-turn interval, a qualifying off-turn
use and blocked repeat, the first owner turn reset, survival across another
actor's turn, reset at the next owner turn, independent source and option IDs,
and lock retention across same-ID source removal/reacquisition. Misses, failed
eligibility, empty pools and locked options preserved the underlying attack.
The focused log is
`.artifacts/tests/9973f2cacd994a55872977a7977104af/shared_combat_use_limits_flow.stdout.log`;
the 727 class checks passed in
`.artifacts/tests/2cc5aa83b6564b30bfce4e9f36765413/`. These checks do not
certify UI target selection, manual campaign play or catalog-wide conversion.

## Bounded dice-pool extension — production validated (2026-10-12)

A source-owned pool can extend the numeric pool shape with an authored
`die_size` from `4`, `6`, `8`, `10`, `12` or `20`, plus a bounded
`spend_choice` containing positive integer `minimum` and `maximum` quantities
up to 100. Pool capacity and current quantity count available dice. The selected
neutral feature in `data/fixtures/shared_dice_pool.json` uses capacity two,
two initial uses, and a one-to-two choice:

~~~json
"resource_pool": {
  "id": "example:ember_dice_pool",
  "capacity_formula": 2,
  "initial_quantity": 2,
  "die_size": 6,
  "spend_choice": { "minimum": 1, "maximum": 2 },
  "recovery": {
    "short_rest_completed": { "mode": "restore_fixed", "amount": 1 },
    "long_rest_completed": { "mode": "restore_to_capacity" }
  }
},
"effects": [{ "type": "heal_by_pool_rolls" }]
~~~

The production feature menu asks how many dice to spend and caps the choices at
the exact source's remaining count. The shared command and activation validate
that positive quantity again before payment or rolling. At committed activation,
the exact owner/source pool spends the selected count and advances its saved
activation serial; then `Dice.roll_multiple` rolls that many authored-size dice.
The feature effect applies healing equal to their sum. Its returned result keeps
each roll, die size, total, actual HP restored, owner, source instance and
activation ID together. This slice accepts one pool-roll healing effect per
activation. It does not create transferable or pre-rolled dice.

Existing Short/Long Rest recovery applies to the remaining count using the
numeric-pool rules above. Recovery never rolls or stores die results. Existing
allowed Character checkpoints retain exact owner/source, definition, capacity,
remaining count, die size and activation serial. Loading copies that state; it
does not reacquire the source or replay recovery. There is no activation
continuation in this bounded effect path, so individual roll results are not
checkpoint state.

The focused Windows Godot 4.7 scenario loaded both the neutral and renamed
definitions through production `DataLoader`, then exercised the real combat
feature menu, quantity popup, shared command and activation path. It verified
cancel-before-roll/payment, one- and two-die healing against the individual
recorded rolls, invalid and insufficient quantities refusing before payment,
rolling or action expenditure, and exact actor/source independence. It also
checked authored Short/Long Rest recovery through the existing Overworld and
Dungeon controls, plus allowed SaveManager reload preserving die size, count,
owner, source, definition and activation serial without acquisition, recovery
or random-result replay. Checkpoint numbers deserialize as numeric variants, so
the evidence checks their values rather than relying on integer/float type
identity.

Evidence: `.artifacts/tests/59351e0151bc4045a0af82b9fe5f073b/` — bootstrap,
180-script parse gate, production boot, 712 selected class checks, the dice
pool scenario, the existing numeric pool scenario and the normal-controls
numeric-pool rest recovery scenario all passed. The slice has no activation
continuation, so it does not test continuation persistence. This verifies only
the bounded VS-10 subset of V-038; source discovery/acquisition UI, other pool
definitions, exchanges, transferable or pre-rolled tokens, class dice tables,
payment-after-success, catalog conversion, fresh-process recovery and manual
campaign acceptance remain outside the checked boundary.

Source-owned timed Temporary HP uses the ordinary keep-higher rule: a lower or
equal offer leaves the existing amount and its owner alone. A higher accepted
offer replaces it. When the exact timed grant expires or its pool source is
removed, only Temporary HP still owned by that grant is cleared. Later timed or
ordinary replacement Temporary HP survives that earlier grant's end. This
bounded operation has one pending grant per exact source and does not offer a
choice to replace equal or lower Temporary HP.

### Owned post-roll weapon attack bonus (accepted slice)

A passive feature can declare a fixed numeric bonus for the `weapon_attack`
domain. The source owns a normal numeric pool; the operation requires a
positive amount from 1 to 20 and a cost from 1 to 100. Its optional
`payment_policy` is `pay_on_choice` by default or
`pay_on_converted_success`. For example, the fixture's `Steady Strike` uses
`+5` for one use, while the renamed `Sure Aim` uses `+8` for two uses and pays
only when the final attack hits.

The normal player weapon Attack control offers one exact source after a
non-natural-1 attack roll provisionally misses. Extra Attack swings use the
same captured-result flow, with one choice per swing and the Attack action paid
once. Declining or answering does not roll again. When Stroke of Luck is
available, its existing prompt uses this same captured result before the
bonus-source menu. Settlement waits before miss mastery, hit damage and
hit-only riders, and the final hit is checked after an existing Shield
reaction. The accepted implementation has focused class checks and a focused
production combat-control acceptance. Shared spell
attacks, Opportunity Attacks, monster-owned sources, and other noninteractive
callers have not been added to this slice. The normal player Attack and Extra
Attack controls are the supported host; each swing captures and settles its
own roll while the action remains paid once. Stroke uses the captured roll
before the optional chooser and does not charge an optional pool.

Production evidence: `.artifacts/tests/258a67b64044400b9405460eebfa2cd9/` —
bootstrap, 184-script parse gate, production boot and the focused real-control
scenario passed. That scenario covers exact-source Attack and Extra Attack
payments, one roll per swing, one Attack action, next-hit timing after the final
hit decision, stale completion while a newer choice is pending, stale-funds
refusal followed by actual menu cancellation, and the native Stroke prompt and
settlement. Focused development evidence: `.artifacts/tests/746d768aa31a42a6944ae8b88a66e613/`
(838 selected class checks, with the same required gates), including direct
resolver Shield interaction and natural-result boundaries. This accepts only
the owner's normal combat Attack host. Latest focused development checks after
the canonical Stroke settlement repair passed 841/0 with required gates at
`.artifacts/tests/8545cd6719474f4bb5d1347b933a8299/`: the recorded request and
roll are validated before computing and spending the real native use. Broader
roll domains and noninteractive callers remain open.

The `failed_save_numeric_bonus` and `weapon_attack_numeric_bonus` operations
can use either an authored positive `amount` or a supported `die_size`, never
both. The source's ordinary numeric pool funds the same authored `cost`. An
accepted choice rolls a declared die once after the source definition and
available balance are revalidated; merely listing or opening the choice does
not roll it. `pay_on_choice` charges on acceptance, while
`pay_on_converted_success` charges only when the final save succeeds or attack
hits. The bounded post-roll die fixture uses d6/cost 1 and renamed d8/cost 2;
it exercises only failed saves, the player's normal Attack/Extra Attack, and
shared-spell attack choices. It does not add dice to other roll domains.
