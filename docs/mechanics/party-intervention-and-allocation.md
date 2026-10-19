# Party intervention and allocation — Batch Q

Independent Batch Q review accepts S-083/S-097/S-101/S-102 as VS-64/65/66/67
within the hosts and operations below. S-097 proves one already-supported fixed
helping modifier; defensive, outcome, reroll and token interventions remain open.
This does not convert catalog rules.

## Shared captured bonus and party helper

The existing `transfer_grant` now accepts `effect: "weapon_attack_bonus"` with
`value_policy: "shared_roll"` and `use_cost: "reaction"`. Other transfer fields,
recipient eligibility, original payment and independent campaign deadlines retain
the [captured-grant contract](captured-grants.md). Each recipient may select its
stored face on its own missed normal weapon Attack/Extra Attack. It pays its own
Reaction and consumes its gift once, without rolling again. The gift appears in
the provisional attack chooser; it is not a standalone HP command. Source removal
does not retract a committed gift. Natural 1/20 and already-hit attacks do not
offer this additive consumer.

A separate common active feature can declare this fixed helping operation:

```json
{
  "id": "example:assist",
  "name": "Assist",
  "executor": "class_feature",
  "type": "active",
  "target": "self",
  "action_cost": "free",
  "resource_pool": {
    "id": "example:assists",
    "capacity_formula": 4,
    "initial_quantity": 4,
    "recovery": {"long_rest_completed": {"mode": "restore_to_capacity"}}
  },
  "roll_intervention": {
    "domain": "weapon_attack",
    "amount": 5,
    "use_cost": "reaction"
  },
  "effects": []
}
```

This feature is available only in another living party Character's missed weapon
attack chooser. The helper must be a living, conscious, willing, nonhostile player
Character in that combat, with its own Reaction and exact numeric pool quantity.
The attacker's spent Reaction does not prevent help. The selected helper pays one
quantity and its Reaction even if the modified attack still misses; its entity
Reaction mirror changes too. No standalone activation, self-help, distance/sense
clause, enemy/monster source, defensive subtraction, shared-spell/save/check host,
outcome override, reroll or replacement-token intervention is implied.

The existing captured attack request owns the actor, target, natural, AC and
continuation. Party offers additionally bind the exact helper object, feature,
pool object/content, turn and campaign clock. Stale gifts/helpers and wrong-owner
answers refuse before payment/RNG. A stale visible choice continues as Decline in
the combat controller. Decline/replay/teardown never add dice or spend a helper.
Each swing retains its original Attack-action payment and normal continuation.

## Allocation feature

Use the same active `executor`, `type`, `target`, own `resource_pool` and empty
`effects` fields, with `action_cost` of `action`, `bonus_action` or `free`.
Declare `allocation` instead of `roll_intervention` or `transfer_grant`:

```json
{
  "mode": "fixed_total",
  "total_formula": 12,
  "effect": "heal",
  "max_recipients": 2,
  "per_target_cap": 7,
  "unspent_policy": "forfeit",
  "cancel_policy": "no_payment"
}
```

| Mode | Budget and payment | Cancel/remainder |
|---|---|---|
| `fixed_total` | Actor-only `total_formula` evaluated and captured when the chooser opens; integral 1–100. Confirming spends one numeric pool quantity and the declared action. No dice. | `cancel_policy: "no_payment"`; `unspent_policy: "forfeit"` or `"require_full"`. |
| `rolled_total` | Supported `die_size` 4/6/8/10/12/20, no formula. Opening a valid recipient chooser spends one numeric quantity/action and rolls once; the same retained total serves all recipients. | `cancel_policy: "forfeit"`; remainder is `"forfeit"` or `"require_full"`. Reveal is visibly paid; cancel/refusal never refunds or rerolls it. |
| `captured_dice` | Existing on-acquire dice pool with its spend range. Choose exact retained die identities, including non-prefix selections. Confirming spends those dice and one action; recipients receive their original face sums. | `cancel_policy: "no_payment"`; remainder is `"retain_unselected_dice"` or `"require_full"`. Unselected dice keep their identities/faces; minimum/maximum spend limits apply. |

All modes require `effect` of `heal` or `temporary_hp`, `max_recipients` 1–4 and
`per_target_cap` 1–100. The cap measures allocated HP points for total modes,
and die count per recipient for captured dice. Healing uses normal max-HP and
recovery rules; Temporary HP uses normal keep-higher behavior. Allocations count
the authored amount even where a recipient cannot benefit from all of it.
`require_full` requires the captured total, or offered maximum dice quantity, to
be allocated. Unknown fields/policies and combined effects refuse at loading.

The Features/source command opens sequential recipient and amount/die menus.
Self and eligible willing other Character player entities in that combat are
offered. A recipient can receive multiple additions under its cap; confirmation
settles its accumulated amount once. No range/visibility, downed rescue, creature
host or half-max-HP policy is implied. Counts, caps, eligibility, unique recipients
and unique die ownership validate for the entire selection before any HP effect.
Fixed/dice refusal pays nothing. Rolled refusal retains the already disclosed
original reveal payment, with no additional charge or recipient mutation.

Requests capture exact actor/recipient/source/budget objects, definitions, total,
turn and clock. Removed/reacquired sources, substituted recipients, changed pool
contents/budgets, stale turns/clocks and completed/revoked answers cannot commit.
Only completed pool subsets, ordinary HP and captured gifts persist at existing
checkpoints. Pending menus/rolls are combat-local; there is no new save namespace,
mid-combat permission, migration or rest reroll policy.

See [ADR-0029](../decisions/0029-party-roll-contributions-and-allocations.md) and
the [independent review](../../.artifacts/planning/vocabulary-reports/batch-Q-review.md).
