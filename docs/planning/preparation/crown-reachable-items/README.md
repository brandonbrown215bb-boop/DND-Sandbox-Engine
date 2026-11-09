# Remaining Crown reachable-item candidates

**Current handoff:** the [cross-set engine mapping](../../crown-engine-mapping/README.md)
is complete as planning. Follow its [bounded queue](../../crown-engine-mapping/assignments.md),
starting with CXM-01/S-249 ammunition. The writing snapshot below and its unchanged
candidate rules/blockers remain inputs; no candidate is promoted or accepted.

**73 new written candidates; 29 existing equipment candidates reused.** All stay
outside production loading, enabling and gameplay acceptance. Prepared on
2026-11-08 against the current source tree and the earlier candidate sets.

Start with [the index](index.json). It lists 102 selected item references and
points directly to existing equipment candidates instead of duplicating them.
Together with the [105 package-equipment candidates](../crown-equipment/README.md),
this gives 178 distinct written item/choice candidates across both sets.

| New candidates | Count |
|---|---:|
| Remaining weapons | 23 |
| Remaining armor | 8 |
| Additional ammunition types | 4 |
| Net, Crossbow Bolt Case, Component Pouch | 3 |
| Healing potions, all four grades | 4 |
| Exact spell-component forms | 16 |
| Sold components for out-of-band level-6 spells | 2 |
| Currency reward wrappers | 2 |
| Crown Fragment and Ashvale Brass Key | 2 |
| Existing custom Antidote | 1 |
| Physical spell, character and tool creations | 8 |
| **Total new** | **73** |

## What selects an item

[Reachability](reachability.json) retains each source occurrence, JSON pointer
or code-path explanation, file hash and candidate link. It covers:

- The pinned 64-ID Windows shop export and 66 **current-source shop leads**.
  The latter adds `diamond_50gp` and `druidic_focus_quarterstaff`; it checks
  source type/value/effect-name declarations for writing scope, not loaded
  availability or executable behavior. No fresh Godot export was run.
- Current companion class starting seeds, campaign dungeon rewards, generated
  loot, all four loaded event tables and nested outcomes, tactical-object
  contents and matching keys.
- The ten direct encounter monsters' exact loot-table metadata. Code copies it
  into combat entities, but this trace found no generic post-combat settlement
  of those tables. Their contents remain possible reward dependencies, not
  newly certified drops. Existing campaign rewards remain separate.
- Material requirements from all 183 spell candidates and physical creations
  from selected spells, invocations, Rock Gnome and Tinker's Tools.

The material map classifies **86 spells with no Material component, 78 with
unpriced/unconsumed materials, 18 requiring exact materials, and True Strike's
actual qualifying weapon**. [Spell materials](spell-materials.json) preserves
every original material string, spell-candidate hash and reference. A Component
Pouch or class-permitted focus can replace only unpriced, unconsumed materials;
it does not supply a 300 GP diamond or Warding Bond's two worn platinum rings.
Substitutable scraps keep their full source description without inventing a
catalog entry for every feather. A separate actual object target, such as Rope
Trick's touched Rope, remains required even when its Material is substituted.

## Written rules and reuse

Each new item contains source rules/facts, authoring operations, unchanged item
seeds with hashes/indices, applicable manifest declarations, source consumers
and blockers. [Selected SRD pages](source-pages.json) preserve the full source
context, including weapon properties/masteries, armor rules, ammunition units,
Material substitution, potion use/miscibility and rarity valuation. Spell and
character candidates continue to own their full creation/casting clauses.

**These are authoring declarations, not registered engine syntax.** Retaining
multiple old definitions preserves comparison inputs; manifest precedence is
still authoritative. A schema, source description or supported effect name is
not gameplay verification. [Required mappings](required-extensions.json) group
the remaining requirements under existing owners without claiming they are all
absent or closing any slices.

The eight creation candidates cover Goodberries, food, water, Prestidigitation
trinkets, Rock Gnome devices, Book of Shadows, pact weapons and Tiny scrap
assemblies. [Creation boundaries](created-item-boundaries.json) distinguish
actual supplies from changes to existing items, illusions, spectral weapons,
spatial effects and actors. Created food spoils after 24 hours; created water
has no source-specified expiry. A transient trinket has no damage or monetary
worth. These do not become permanent shop goods.

## Blockers and source reconciliations

- Preserve the Antidote's existing custom cure. It is not SRD Antitoxin's
  one-hour Advantage against Poisoned. Writing changes neither availability.
- SRD p.91 includes **Musket and Pistol**. The older scope's non-SRD label was
  wrong; the source classification is corrected without removing either item.
- The existing combined Druid Quarterstaff/focus seed was missed in the first
  equipment pass. That existing candidate now retains it alongside the older
  `wooden_staff` comparison seed. Reuse the combined definition; do not assign
  its creation as missing engine work. The Arcane staff still needs its own
  weapon/focus reconciliation.
- Retain current potion shop prices alongside official rarity valuation.
  Different values and older Action-cost donor copies are explicit comparison
  inputs, not an instruction to rewrite prices. Potion use, administration,
  exact consumption and mixing still require their actual hosts.
- Gold wrappers are not extra Pouch/Sack grants. Dungeon rewards currently
  special-case `gold_` IDs, while event `give_item` adds inventory copies.
  Reconcile actual currency delivery and once-only receipts later; no reward
  host was fixed here. Creature loot metadata must not duplicate boss rewards.
- Net's damage-weapon seed needs its real save/restraint/object rule. Ammunition
  needs typed piece counts, Loading/free-hand rules, recovery and separate
  storage. Existing generic item fields do not finish these consumers.
- Material worth is not automatically its merchant price. Gentle Repose's two
  coins and shop packet, the two Warding Bond rings, sense-specific Clairvoyance
  forms, consumed ink/dust and reusable tokens need exact identity/quantity.
  Higher-level black-pearl and mushroom powders stay sold item candidates;
  their level-6 spells do not become Crown casting permissions.

The subsequent [creature/actor pass](../crown-creatures/README.md) now writes the
complete in-band individual form sets, encounter/companion definitions and
spell-owned actors/effects. It reuses these item links and the unpaid-loot
boundary; no monster reward settlement is implied. World/event/object authoring
remains. Generic craft
lists and open-ended object requests retain explicit dependencies; this pass
does not pull in every dormant magic-item shell or every possible craft result.
Later selected consumers can add named items to this finite set.

## Checks and attribution

Structural checks cover JSON, unique IDs, cross-folder reuse, source pointers
and hashes, unchanged seed payloads, every selected item root, all 183 spell
materials, legal 28-form pact-weapon selection and candidate/source-page links.
No engine edits, gameplay tests, content enabling, save changes or promotion
were part of this pass.

Adapted from the *System Reference Document 5.2.1* by Wizards of the Coast LLC,
[official PDF](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
The PDF SHA-256 is
`8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87`.
The adaptation normalizes selected clauses/tables and adds authoring/mapping
notes. Custom Crown items use their explicitly identified campaign definitions,
not an asserted SRD equivalent. See the
[content scope](../../crown-content-scope.md#campaign-and-world-inventory) and
[content pipeline](../../../content_pipeline.md) for the larger boundary.
