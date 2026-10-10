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
