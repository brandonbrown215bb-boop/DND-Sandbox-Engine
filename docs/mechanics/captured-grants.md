# Captured recipient grants — Batch P

Independent Batch P review accepts **S-082 as VS-63**. S-051/VS-61 remains
the accepted captured-pool primitive. Independent Batch Q review accepts
**S-083 as VS-64**: one shared captured weapon-attack bonus and each recipient's
own Reaction, with original values/deadlines surviving source removal and reload.
See [party contributions and allocation](party-intervention-and-allocation.md).
The current boundary uses bounded Character recipients and self-benefit/normal
weapon-attack consumers. It does not convert Bardic Inspiration, Dance or other catalog rules.

An active `executor: "class_feature"`, `target: "self"` feature may declare
`transfer_grant` instead of ordinary effects. The giver uses `action`,
`bonus_action` or `free`; each completed transfer spends exactly one quantity
from that feature's exact `resource_pool`. Keep `effects` empty and do not
combine resource references, exchanges, legacy uses, `resource_cost` or passive
effects. The pool's normal completed-rest recovery policies still apply.

```json
{
  "id": "example:shared_gift",
  "name": "Shared Gift",
  "executor": "class_feature",
  "type": "active",
  "target": "self",
  "action_cost": "bonus_action",
  "resource_pool": {
    "id": "example:gift_uses",
    "capacity_formula": 4,
    "initial_quantity": 4,
    "recovery": {"long_rest_completed": {"mode": "restore_to_capacity"}}
  },
  "transfer_grant": {
    "kind": "die",
    "value_policy": "shared_roll",
    "die_size": 6,
    "effect": "heal_self",
    "use_cost": "reaction",
    "duration_seconds": 60,
    "max_recipients": 2
  },
  "effects": []
}
```

| Value policy | Required fields and behavior |
|---|---|
| `pool_die` | `kind: "die"`; an on-acquire captured dice pool with `spend_choice` minimum/maximum both 1; `max_recipients: 1`. Move its oldest exact die, retaining original identity, size, face and generation level. No transfer/use-time RNG. Forbid `die_size` and `amount_formula` on the transfer specification. |
| `shared_roll` | `kind: "die"`; numeric pool and supported `die_size` (4/6/8/10/12/20), no `amount_formula`. Roll once after the complete recipient selection succeeds. Every beneficiary receives that same value with independent consumption. |
| `formula` | `kind: "token"` or `"permission"`; numeric pool and actor-only `amount_formula`, no `die_size`. Capture an integral 1–100 at successful transfer, using the existing formula evaluator. Missing inputs refuse before payment. This is a single-use self-benefit permission/token, not a pre-roll replacement token or casting permission. |

Every specification requires `effect` (`heal_self`, `temporary_hp` or the
Batch Q `weapon_attack_bonus` extension),
`use_cost` (`action`, `bonus_action` or `reaction`), `duration_seconds`
(1–86400) and `max_recipients` (1–4). Unknown fields/policies and mixed ordinary
effects refuse. The deadline is campaign time at successful transfer plus the
authored duration. Giver ability/level changes, pool recalculation, removal or
reacquisition do not change an already transferred payload or its deadline.

The current host offers distinct other Character player entities in the same
combat. Each recipient must be alive, not downed/incapacitated/hostile, and have
explicit `willingness: "willing"`. Unknown willingness does not qualify. No
distance, visibility, enemy/object or automatic self-target policy is implied.
The menu selects recipients sequentially, offers completion after a partial
selection, and commits when the authored maximum or offered list is exhausted.
Closing any unfinished menu cancels the whole transfer. Ordinary combat input
is blocked while the choice is open.

Requests retain exact giver, offered recipient objects, source pool object and
snapshot, definition, turn and campaign clock. Same-ID replacement objects,
removed/reacquired sources, changed definitions/pools/budgets, old requests,
duplicates and teardown cannot commit. Public choice metadata does not own the
payload. All recipients validate before any payment, RNG or grant mutation.

The recipient's Features menu displays the captured HP benefit and use cost.
Its own current-turn Action/Bonus Action or its own Reaction pays the use. The
combat entity's Reaction mirror is updated too. Giver budgets, sibling grants
and shared values remain unchanged. A consumed permission heals the recipient
or grants normal keep-higher Temporary HP once. Expiry limits the unused grant;
it does not retract HP/Temporary HP already received. Reaction use is currently
an explicit command on the recipient's turn, not an off-turn roll intervention.

## Checkpoints and identity

`Character.captured_grants` stores giver/recipient, exact source and source class
definition, immutable value/die payload, generation level, shared group,
consumer/cost and original timestamps. `grant_transfer_serial` belongs to the
giver and survives source removal. `transferred_die_serials` retains each
transferred pool source's die serial high-water mark. Reacquiring/recovering that
source generates later identities; it cannot regenerate a die already given
away. Pools that have never transferred a die keep their existing representation.

Both full-save DTO paths validate records before session replacement. Cross-actor
preflight checks matching player/party gifts and serials, the original giver,
shared group values and transferred-die exclusivity against other recipients and
the giver's remaining pool. Missing legacy fields mean empty state. Loading
does not reroll, re-grant, refill or restart deadlines. No namespace, migration,
mid-combat or mid-choice saving is added. Requests/menus stay transient.

The implementation bounds a recipient to 100 live grants and a giver to 100
transferred source serial entries. Queries return copies and do not prune or
mutate. Actual campaign time progression prunes expired grants; successful
transfer also removes expired recipient records before adding its new gift.

Exploration transfer controls, subclass/item/spell-source transfer definitions,
arbitrary transfer-die selection, replacement tokens, spell casting rights,
off-turn intervention, range/sense clauses, redistribution and general effect
payloads remain outside this implementation. Those hosts require their own
consumers and checks. See [ADR-0028](../decisions/0028-captured-recipient-grants.md)
and the [independent review](../../.artifacts/planning/vocabulary-reports/batch-P-review.md).
