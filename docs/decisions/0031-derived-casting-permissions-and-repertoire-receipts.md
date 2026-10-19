# ADR-0031: Derived casting permissions and preparation receipts

Date: 2026-10-17
Status: Accepted bounded implementation (Batch 021, VS-76–78)

## Decision and reason

Derive casting permissions from current class/book/feature ownership and exact
equipped item copies. The flattened known-spell list is a display projection,
not casting authority. Capture one permission and allowed payment on the
transient invocation, rebuild production spell data at the command boundary,
and revalidate the source and policy before costs. A stale or mismatched
selection refuses without searching another source. Ordinary casts and supported
Shield/Counterspell reactions reuse the same permission/payment rules.

An invocation retains its selected ability for its attack, save and effect
consumers. Durable spell effects retain their actual save DC through the existing
effect record. Item permissions pay existing per-copy charge state.

Opted-in class spellcasting sources keep separate preparation lists, class-level
capacities and replacement policies. Choices reuse `feature_choices`; the
optional `spell_repertoire_state` receipt stores only the trained class level
and an open Long Rest replacement window. The receipt is necessary because a
reload must not reopen a replacement already used at that level or rest.

## Compatibility and boundaries

Keep schema 2 and the existing 2024 save namespace/checkpoint restrictions.
Missing repertoire receipts remain compatible; existing selected sources do not
gain a replacement merely because a receipt is absent. Full-save validation
checks both Character DTO paths before live replacement. Reconstruction does
not acquire spells or refill charges. No pending casting/preparation UI is saved.

This extends ADR-0018's shared data-driven direction and ADR-0030's actual
class-level identity; it does not supersede their acquisition, source ownership
or save guarantees. Existing primary preparation and the Wizard book remain
their own owners until authored conversion. This is not combined/Pact slot
progression, general native multiclass acquisition, multiple editable spellbooks,
catalog conversion or broad component/ritual support.

## Acceptance

Source/payment refusal must leave costs and unrelated sources intact. Production
controls must demonstrate independent preparation and exact-copy item payment;
fresh-process checkpoint recovery must preserve choices, spent replacement
windows and original charges, with malformed saves refused before replacement.
The [Batches 021–023 acceptance review](../../.artifacts/planning/vocabulary-reports/batch-021-023-acceptance-review.md)
owns current commands, evidence and bounded acceptance; the Batch 021 repair
report retains the original repair receipts.
