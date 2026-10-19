# Source-owned stat protections

Batch G S-039/S-040 are accepted as VS-46/47 after
[independent review and repairs](../../.artifacts/planning/vocabulary-reports/batch-G-review.md).
Original implementation and production validation remain in
[the build/validation report](../../.artifacts/planning/vocabulary-reports/batch-G-build-validation.md).
This is executable authoring syntax,
not a conversion or certification of named rules.

## Source activation

An active self-targeted `executor: "class_feature"` with a numeric
`resource_pool` may have exactly one effect:

```json
{
  "type": "timed_protection",
  "duration_seconds": 60,
  "group": "stance",
  "stacking": "exclusive",
  "eligibility": {"armor": "none", "shield": "any"},
  "benefits": [
    {"stat": "AC", "operation": "base", "value": {
      "op": "add", "left": 13, "right": {"caster_ability_modifier": "DEX"}
    }},
    {"stat": "STR", "operation": "set", "value": 18}
  ]
}
```

The existing feature picker, owned command, budget and exact pool source own
activation. One successful activation pays the authored feature cost once and
creates one identified grant. An active source cannot activate again. Refusal
for invalid data, equipment, unavailable formula or group conflict precedes
payment and grant creation. Duration is an integer 1–86400 campaign seconds.
The deadline is the original activation time plus duration; equality is expired.

The grant retains recipient/owner, feature definition, exact pool source,
grant identity, acquisition order, payload, start and deadline. Sources with the
same feature definition remain independent. Definitions/catalog records are not
modified. Removing a numeric pool removes only its protection grants too.

## Equipment facts and stat order

Both eligibility fields are required: `armor` is `none`, `worn` or `any`;
`shield` is `none` or `any`. Equipment is read through the recipient's actual
inventory slots/copies. An unknown armor/shield definition cannot qualify.
Eligibility is checked before activation and on subsequent stat/choice queries.
Changing equipment suppresses an ineligible grant while retaining its original
source and deadline. Unequipping restores a still-live eligible grant without
reacquisition. There is no arbitrary equipment/fact predicate language here.

Each effect has 1–8 benefits, with at most one occurrence of each stat/operation
pair. `AC` supports `base` and `add`. A base accepts the existing actor numeric
formula language; cast-only/result/choice inputs are rejected. It is preflighted
at activation and reevaluated on later AC reads, using effective ability
modifiers. Unavailable later formulas contribute no alternative. The ordinary
equipment/native base and all eligible selected alternative bases compete by
maximum; bases are never summed. A legal shield adds its normal bonus once to
each candidate. Native Mage Armor participates in the existing maximum; additive
protection bonuses apply afterward, alongside ordinary existing AC bonuses.
Existing shaped-form AC remains under its native owner and bypasses this AC path.

`STR`, `DEX`, `CON`, `INT`, `WIS`, `CHA` support `set`, `floor`, `cap` and `add`.
Setting/floor/cap values are integers 1–30; additions are integers −30–30.
The order is permanent score → highest selected setting (if any) → maximum
floors → minimum caps → sum additions → clamp 1–30. Setting may lower a permanent
score; a floor cannot. Equal settings retain every exact source even when their
numeric projection is equal. Score operations use fixed values to avoid recursive
effective-score formulas. AC formulas reuse the shared evaluator.

`AbilityScores.get_score` and modifier reads expose the effective projection.
The six underlying fields, `get_permanent_score`, `set_score` and `to_dict` retain
permanent scores. Permanent ASI/fixed increases and racial increases read that
underlying score, including while a temporary setting is active. Epic Boon
eligibility and its actual option list use permanent scores for the 30 limit.
Permanent CON increases use permanent modifier changes for their existing HP
increase; level-up HP likewise uses permanent CON, so temporary CON cannot become
a lasting HP increase.
This projection does not itself grant HP, recalculate existing maximum HP for
temporary CON, refill pools or recalculate every resource capacity. Those are
separate consumers; no named item/form/class rule is certified by these probes.

## Compatibility and recipient choice

The `group` is a simple identifier. `stacking: "stack"` retains every eligible
owned grant in that group. `stacking: "exclusive"` retains all owned alternatives
but applies only one eligible grant from that group. Different feature IDs do
not evade the same exclusive group. A live group cannot mix stacking policies.
Different groups coexist; base AC still uses the maximum, and additive benefits
combine only from selected/stacking grants.

Combat's Features list exposes `Choose protection: <group>`. The actual recipient
chooses an exact grant, including equal-value copies with different source IDs
and deadlines, or keeps the current choice. Selection is free and spends no
source pool. The saved selection names that exact grant; it does not remove the
other alternatives. With no eligible explicit selection, the earliest acquired
eligible surviving grant is the deterministic fallback. Temporary equipment
ineligibility retains the preference, so it can resume while still alive.
Removal/expiry clears an invalid preference and uses fallback without granting
anything or moving any surviving deadline.

The owned command validates the group. The pending request captures the exact
actor object, owner ID, generation and full offered grant records. Answers must
match the canonical request and a still-owned, live, equipment-eligible offer.
Recipient binding loss, source loss, caller substitution, old popup answers and
completed replay cannot change a selection. Opening another request supersedes
the previous generation. Decline and scene teardown cancel only pending choice;
selection, grants and clocks remain. Menus/requests/generations stay transient.

## Checkpoint recovery and limits

Optional `protection_grants`, `protection_selections` and `protection_serial`
fields use existing schema-2 allowed checkpoints and namespace. Preflight checks
both player and party character DTOs before replacing live state. It checks
containers, source/pool/owner/grant IDs, serial/order uniqueness, payload against
the currently loaded feature, policy consistency, original start/deadline and
selected group/grant. Restore copies remaining state without feature acquisition
or pool recovery. Old saves with none of these fields retain ordinary behavior.

Supported grant hosts are self-targeted numeric-pool ClassFeature activations on
Characters; equipment supplies eligibility, not a new item-effect execution host.
The real ordinary monster weapon command proves downstream AC consequences.
Cross-actor grants, auras, item-copy activation effects, THP replacement, arbitrary
predicates, forms and mid-choice saves are not added here. The pending request is
never serialized, even when an allowed checkpoint retains a lasting selection.
