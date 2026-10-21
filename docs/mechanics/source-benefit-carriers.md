# Exact source benefit carriers

Batch L accepts S-049/S-050 as VS-59/60 after independent source/evidence review
and bounded repairs. It supplies a common projection for fixed additive AC and
walking speed benefits; see the [slice registry](../planning/vocabulary-slices.md).

## Payload and hosts

The same payload works on three carriers:

```json
[{"stat": "AC", "amount": 2}, {"stat": "speed", "amount": 1}]
```

Amounts are integral JSON numbers from 1 through 10. Speed uses existing hex
units (one hex is five feet). Only `AC` and `speed` are supported; each stat may
occur once. Extra fields and malformed values refuse at content loading.

- An equippable item declares `source_benefits` with this array. Its existing
  exact copy identity is the source. Only equipped copies project benefits;
  an item requiring attunement also requires that copy's actual attunement to
  the actor. Backpack ownership alone grants nothing.
- A passive class feature, or a feature-choice option's `effects`, contains
  `{"type":"source_benefits","benefits":[...]}`. Only one such payload is
  allowed per feature/option. The source is the actor's feature entitlement,
  or exact selected option occurrence (actor, feature, option, choice index).
  Replacing the option ends that occurrence. Remaining occurrences retain
  their identities; reselecting the same entitlement is not a new timed grant.
- A shared spell declares one flat
  `{"type":"grant_source_benefits","benefits":[...]}` effect, `target:"self"`,
  automatic delivery and `duration_seconds` (1–86400). Both ordinary and
  concentration casts use the existing `spell:<caster>:<serial>` source.
  Other recipients, ordered steps, damage, attack/save delivery, gates,
  repeat saves and additional effects are unavailable for this carrier host.

`SourceBenefitRules.query(character)` returns separate plain receipts containing
owner, recipient, carrier kind, exact source, definition and payload. Querying
does not acquire anything, charge resources, allocate identities or roll dice.
`Character.get_ac()` and walking `get_speed()` sum the eligible additions. This
operation explicitly adds all independent authored sources, including identical
definitions. It does not implement named spell nonstacking or general stacking
policies. Authors must not treat it as certification of those rules.

## Actual controls and cleanup

Class Progression's existing Choose/Replace controls own progression changes.
It also shows exact-copy Equip/Stow controls for items carrying these benefits,
outside combat. Inventory ownership, slot, curse and backpack-capacity checks
remain authoritative. Failed or stale equipment controls change nothing.
Transfers retain copy identity; only its currently equipped owner can benefit.
Destruction and stowing remove that copy's projection without touching siblings.

The normal combat spell picker and cast path own Action/slot expenditure and
cast creation. Each live cast gets its own Dismiss entry in the feature menu.
The command revalidates that the active actor owns that exact live self-cast;
an item/progression source or stale cast cannot be dismissed through this route.
Dismissal costs no additional Action/slot. A concentration carrier also clears
its matching concentration through the existing owner. Expiry and concentration
loss use ordinary SpellEffects cleanup and the campaign clock. Each cast keeps
its original independent remaining duration. Current-turn movement follows speed
changes without refunding distance already spent, even when removal exhausts the
remaining allowance before a later gain. This turn state is never serialized.

## Checkpoints

Items reuse saved copy records; progression reuses validated saved feature
choices. Their additive projections are derived, never permanently written into
base AC/speed, and reconstruction does not replay acquisition. Cast records save
the payload on the existing timed spell record. Preflight checks both player and
party DTO paths before live state replacement: payload must equal the loaded
definition, caster must be the recipient, duration cannot exceed the authored
duration, concentration must match the same spell/caster and a concentration
record (an ordinary sibling is insufficient), and the exact source must refer to an already
allocated positive cast serial. The normal spell-effect and inventory validators
still own their remaining invariants.

No new save namespace, migration or saving boundary is introduced. Legacy saves
remain untouched. Fresh-process checks must verify identities, remaining time,
quantities and malformed-load refusal; helper-only reconstruction is insufficient.

## Modes, forms and exact item state

`mode_choice` and `rule_upgrade` reconstruct ownership from the saved class and
subclass at the character's class level. Rest/activation choices, added modes,
exclusive alternatives and event windows retain their existing identities on
reload. Species, species-granted feats and exact equipped item copies also
acquire these feature types through `OwnedFeatureSources`. Items requiring
attunement grant them only to their attuned owner. Chosen/background/level-up
feat acquisition and ordinary HUD controls for these modes remain follow-ups.

Item pools and upgrade options belong to the exact copy. Unequipping or
transferring it stamps its remaining uses and remembered option on its record;
reacquisition and reload restore those values without replaying acquisition.
Suppression and form merging disable benefits and activation, while expiry,
end conditions and stored capacity still use the owned upgraded rule. Two
identical copies have separate pools; the same definition's same power grants
its benefits once, with copies considered in sorted identity order.

Item activation modes may declare `uses_per: "dawn"`. Campaign day boundaries
refill carried copies, container contents, attached children and copies in saved
rooms. Optional `recharge_while: "equipped"` or `"attuned"` checks that specific
condition: equipped does not imply attuned. Suppression/merging alone does not
block recharge. Equipped item powers recovering on a rest also use their owned
upgraded capacity. Unheld copies refill their record stamp using their remembered
upgrade option. Rest choices cannot declare `recharge_while`. Mid-combat dropped
copies are not visited until returned to a room or inventory; there is no
separate sunrise clock.

An `actor_projection` with `equipment: ["dropped"]` sets removable equipped
copies aside in the backpack. It refuses before casting costs or form changes
when the backpack cannot hold them. Cursed copies retain their removal policy.
The projection records whether it actually supplied the current Temporary HP;
damage preserves that ownership, while an accepted replacement (including an
equal amount) transfers it. Reversion removes only the projection's own HP.
Self concentration retains a source record without a strong self-reference.

An item's `projection` preserves its exact identity across transfers. Projected
copies and their children use the ordinary state, serial and global ownership
checks, including both player and party checkpoint representations. Active
`active_time` copies must be paused before stowing, attaching or projecting;
storage cannot silently freeze an active budget. Work must also be stopped
before attachment or projection. Losing a work copy, or a participant resting,
applies its `work.on_interrupt` keep/reset policy immediately. Rest duration
does not count as work. Each participant can work on one job at a time; both
party and player-only checkpoints enforce that limit. Work's existing item-only and party-membership limits
remain; it does not check helpers' spatial co-location.

Regressions live in `src/stack_repair_checks.gd`; these fixture-backed repairs do
not convert catalog content or accept the full planned slices.

## Limits

This adds no catalog conversion, monster/other-recipient cast host, arbitrary
benefit operations, source-owned resource acquisition, permanent proficiency
ledger, general cast permission, aura or stacking policy. Form projections retain
their existing early-return policy; this slice does not claim item/benefit
retention during Wild Shape. Duration upgrades such as Extended Spell are not
offered for fixed-duration carriers; captured duration upgrades need separate work.
Broader item effects and source dependencies remain
separate work. Neutral and renamed fixtures live in `data/fixtures/batch_l/`.
