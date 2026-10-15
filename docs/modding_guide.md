# Authoring content supported today

This guide describes the implemented JSON contracts. The target shared rules
language in [ADR-0018](decisions/0018-shared-data-driven-rules-runtime.md) is not
yet available. Proposed syntax in the class/creature plans is not executable.
New IDs can reuse supported operations; descriptive JSON does not create a
missing rule, trigger, UI action or persisted state model.

## Loading and overrides

Put JSON directly in the content-type directories under `data/mods/`:
`classes`, `subclasses`, `races`, `items`, `spells`, `monsters`, `events` or
`campaigns`. Discovery is sorted and does not recurse through named pack folders.
Prefer namespaced IDs such as `my_mod:warden`.

An additive subclass has its own ID and `class_id` pointing to its parent.
A duplicate ID requires an explicit winner and all replaced sources in
`data/content_manifest.json`; source locators include record indexes (`#1` for
an object or first array record). Enumeration order is not override permission.
The [content pipeline](content_pipeline.md) explains promotion and validation.

External pack discovery, a mod manager and required pack-version compatibility
are unimplemented. Keep content used by saved characters installed: missing
required class/subclass/shared-effect content rejects save preflight.
Do not remove content as a save migration strategy.

## Ordinary spells

Use [shared JSON spell execution](mechanics/shared-spells.md) and its
[current schema](json_schemas/shared_spell_schema.json). Supported definitions
are enabled by operations without a native spell-ID registration. Add their
IDs to intended class lists through an approved override, then learn/prepare
them normally. The guide includes runnable syntax and the relevant Godot check.

Current delivery is automatic, attack or save. Ordered mixed checks, general
summons/movement/hazards and multi-target exploration are not supported by this
contract. Extending generic operations is the development direction; adding
another named native handler is not the target authoring mechanism.

## Current class-feature subset

Common active self-effects use `executor: class_feature`. The executor resolves
the owned record and validates budgets before paying action/resource costs once.
This minimal example reuses a shared pool, level scaling and rest recovery:

```json
{
  "id": "my_mod:warden",
  "name": "Warden",
  "hit_die": "d8",
  "primary_ability": "WIS",
  "subclass_level": 3,
  "features_by_level": {
    "1": [
      {
        "id": "my_mod:resolve", "name": "Resolve", "type": "resource",
        "uses": 2, "uses_by_level": {"1": 2, "5": 3},
        "uses_per": "long_rest", "short_rest_recovery": 1
      },
      {
        "id": "my_mod:mend", "name": "Mend", "type": "active",
        "executor": "class_feature", "resource_id": "my_mod:resolve",
        "resource_cost": 1, "action_cost": "bonus_action",
        "effects": [{"type": "heal_self", "value_by_level": {"1": "1d4+level", "5": "1d8+level"}}]
      }
    ],
    "4": [{"id": "my_mod:improvement_4", "name": "Ability Improvement", "type": "passive", "effects": [{"type": "asi"}]}]
  }
}
```

`features_by_level` uses canonical level keys 1–20. Resource references must
be acquired at the same or an earlier level. Capacity/recovery belong on the
pool; the activation declares cost. Remaining uses persist and load does not
refill them. Shared ability improvements earn saved entitlements; reconstruction
does not replay permanent grants over saved final scores.

Put additive subclass records in `data/mods/subclasses/` with `class_id` and
their own `features_by_level`. One installed option is automatically selected
at the parent subclass level; multiple choices use the Character Sheet. Only
the selected subclass grants features. The current UI does not support respec.

The executor supports only its validated operations. Targeted actions, reactions,
forms and many casting/progression rules still have native paths. Naming a
`resolver` does not define code or make an unsupported rule work. Read
`ClassFeature`, `ClassProgression`, loader validation and
[ADR-0006](decisions/0006-composable-class-features.md) when changing this subset.
The Godot `class_building_blocks` scenario exercises namespaced fixtures through
creation, sheet choices, combat activation and save/load.

### Source-owned numeric pool example

A shared active self-feature can use a bounded numeric pool instead of the
legacy `resource_id` use pool:

```json
{
  "id": "example:steady_spark",
  "name": "Steady Spark",
  "type": "active",
  "executor": "class_feature",
  "action_cost": "free",
  "resource_pool": {
    "id": "example:steady_spark_pool",
    "capacity_formula": { "caster_proficiency_bonus": true },
    "initial_quantity": 1,
    "recovery": {
      "short_rest_completed": { "mode": "restore_fixed", "amount": 1 },
      "long_rest_completed": { "mode": "restore_to_capacity" }
    }
  },
  "effects": [{ "type": "grant_condition", "condition": "steady_spark", "duration": 1 }]
}
```

The source owner calls `ResourcePoolRules.acquire(character, definition,
source_instance_id)` once when that exact source instance is acquired. The same
source-instance ID is required for availability and is passed to
`ClassFeature.execute(..., source_instance_id)`. A second copy of the same
definition gets another ID and another quantity. Content loading, queries and
checkpoint loading do not acquire or refill pools. Capacity recalculation
preserves current quantity on growth and clamps it on shrink. Combat lists each
owned instance separately and carries the chosen ID through shared activation.
Optional `resource_pool.recovery` policies run only after successful matching
rest completion through `RestRules`. `restore_fixed` adds an integer amount
(1–100), capped at capacity. `restore_to_capacity` fills to capacity and takes
no amount. Supported trigger keys are `short_rest_completed` and
`long_rest_completed`. RestRules eligibility limits recipients to living,
conscious party Characters and applies recovery to every exact pool source
owned by that actor. Starting/cancelling/refusing a rest, loading, or ordinary
elapsed time does not trigger recovery. Long Rest runs only its Long Rest
policy. Rest durations and controls do not change. See the
[numeric-pool contract](mechanics/shared-resource-pools.md) for exact limits.

A pool-backed passive weapon-hit rider can also declare one of the bounded
`use_limit` values shown in the [hit-rider contract](mechanics/shared-resource-pools.md).
The feature's exact acquired source supplies its pool, while the option ID and
existing combat turn serial control the transient rider lock. A qualifying rider
spends one pool use; a failed or repeated trigger spends none.

A passive fixed attack bonus can select `weapon_attack`, `shared_spell_attack`,
or both in its `domains` array. Both consumers share the same positive `amount`,
exact pool `cost`, source choice and optional `payment_policy` (`pay_on_choice`
or `pay_on_converted_success`). For example:

```json
{
  "type": "weapon_attack_numeric_bonus",
  "domains": ["weapon_attack", "shared_spell_attack"],
  "amount": 5,
  "cost": 1,
  "payment_policy": "pay_on_choice"
}
```

The shared-spell domain covers ordinary flat and ordered attack spells when the
owner actually rolled a miss in combat. The request pauses before damage and
riders; ordered spells resume their same step and target after the answer.

## Other content and proof

Existing item/monster/campaign schemas describe record shape, not complete
executable semantics. Monster traits/attack-effect prose and `ai_behavior` do
not constitute arbitrary data-driven AI. Campaign records can use existing
world/event operations; they cannot define missing engine behavior by naming it.
Current records are migration inputs, not complete 2024 rules templates.

Validate a new definition with the production loader and actual player/AI path.
Check ownership, legal choices, costs, meaningful results and any durable
state/expiry. Use [proportionate Godot validation](testing.md). Python structure
checks and [the generated inventory](feature_matrix.md) are useful diagnostics,
not gameplay evidence. Never promote availability or full-rules support from
schema validity, a dictionary entry or an assertion count alone.
