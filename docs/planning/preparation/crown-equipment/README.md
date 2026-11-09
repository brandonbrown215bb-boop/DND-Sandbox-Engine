# Crown package equipment candidates

**Current handoff:** the [cross-set engine mapping](../../crown-engine-mapping/README.md)
is complete as planning. Follow its [bounded queue](../../crown-engine-mapping/assignments.md),
starting with CXM-01/S-249 ammunition. The writing snapshot below and its unchanged
candidate rules/blockers remain inputs; no candidate is promoted or accepted.

**105 written candidates, outside production. Not enabled or gameplay-verified.**
Prepared on 2026-11-08 from the existing character/origin packages and SRD 5.2.1.
This is the equipment writing pass, not an engine implementation or a complete
Crown merchant/loot catalog.

The subsequent [reachable-item pass](../crown-reachable-items/README.md) adds
73 candidates and reuses this set for shops, rewards, companions and spell/item
dependencies. It also retains the already-existing combined Druid staff seed;
that omission in the first pass is corrected below without a runtime change.

Start with [the index](index.json), [the package map](packages.json) and
[the mapping requirements](required-extensions.json).

| Written set | Count |
|---|---:|
| Weapons actually granted, including Quarterstaff | 15 |
| Armor and Shield | 5 |
| Ordinary gear | 29 |
| Arrows | 1 |
| Complete equipment packs | 6 |
| Artisan tools, Herbalism Kit and Thieves' Tools | 19 |
| Musical Instrument variants | 10 |
| Gaming Set variants | 4 |
| Named focus forms, including both staff combinations | 8 |
| Holy Symbol form choice | 1 |
| Background/Warlock Book topics | 3 |
| Wizard Spellbook | 1 |
| Bard, Monk and Soldier equipment choices | 3 |
| **Total** | **105** |

The package map retains every alternative and its GP for all twelve classes
and four backgrounds. It links each item and quantity to one candidate, expands
all six pack lists, and exposes all 17 Artisan tools, ten instruments and four
Gaming Sets where those choices permit them. These are source choices, not a
menu restricted to whichever items currently work. Craft lists preserve legal
products but do not grant them or expand this pass to every possible recipe.

## What is retained

- Each candidate preserves normalized source facts, its selected source pages,
  authoring operations, consumers and explicit unsupported behavior. The
  [source context](source-pages.json) preserves the full selected PDF pages,
  including complete weapon property/mastery and tool-proficiency rules.
  Two-column extraction can interleave headings or table cells; normalized
  quantities and values were checked against the equipment tables and bodies.
- Existing item definitions are copied unchanged in `retained_runtime_seeds`,
  with file hashes and zero-based array indices. All matching definitions and
  applicable manifest collision declarations remain available for comparison;
  array order is not precedence. Staff candidates reuse `arcane_staff` and
  `wooden_staff`, with the Quarterstaff weapon role explicitly retained.
- `definition` and `authored_operations` describe the intended candidate.
  **They are not registered runtime syntax.** An existing effect, description,
  support label or source hash does not certify complete behavior.
- Mapping groups point to existing slices. They describe requirements to
  reconcile, not a finding that every named owner is absent. This pass changes
  no slice acceptance, runtime contract or gameplay behavior.

## Blockers kept explicit

- Missing exact item seeds stay candidates: Arrows, Quiver, Book/topic variants,
  Parchment, ordinary Pouch, Traveler's Clothes, Candle, Ink, Ink Pen and the
  three absent pack definitions need deliberate production mapping. Choice
  records are declarations, not new loaded items. No Gold Pouch, component
  pouch or unrelated book substitutes for a missing ordinary item.
- Arrows use individual pieces; a purchase lot is 20. Quiver is a separate
  item holding 20 Arrows. Spending and post-fight recovery need exact counters.
- Pack grants must resolve actual quantities once, including sheets, days,
  flasks and recoverable hazard supplies. A pack's listed weight does not mean
  all contents fit inside its 30-pound Backpack. Do not add a full shell's
  weight/value to the same contents again. Unknown weights remain unknown.
- Monk's equipment matches its chosen tool proficiency; Soldier's Gaming Set
  matches its chosen set. Bard's starting instrument is a separate choice;
  the source does not require it to match one of the three proficiencies.
  Holy Symbol retains all three legal forms instead of forcing an Amulet.
- An Arcane/Druidic staff is one object with both focus and Quarterstaff roles.
  The Druid candidate now also retains the existing combined
  `druidic_focus_quarterstaff` weapon/focus seed. Reuse it directly; the older
  focus-only comparison seeds do not supply both roles. Preserve
  class permission, hands, worn/borne/held form and Material-component limits.
- Book topics are `prayers`, `history` and `occult lore`; the Scholar pack's
  Book has no specified topic. The +5 bonus requires consulting accurate
  nonfiction about the eligible check's topic. Topic alone does not establish
  accuracy. Spellbook stays a separate Wizard-owned item and procedure.
- Rations' retained seed costs 0.2 GP; the official table gives 0.5 GP per day.
  Retained descriptions/effects also omit or abbreviate tool tasks, hazards,
  Rope bindings, Healer's Kit uses, Holy Water's attack replacement, Torch
  attacks and cumulative Oil/light behavior. Their full intended clauses and
  mapping requirements are written here; production records remain unchanged.
- Craft procedures/results, environmental exposure and spellbook copying/loss
  remain owned by their broader source/runtime work. Their references are
  dependencies, not a claim that this package pass authored every result item.

## Checks and remaining scope

Structural checks cover JSON, unique candidate IDs, all package alternatives
and quantities/GP, recursive pack/choice/base references, retained seed payloads
and hashes, finite choice inventories and documentation links. No Godot checks
were run: nothing was loaded, enabled, promoted or changed in game source.

Merchant stock, loot and selected spell-component/created-item dependencies now
have [their own writing pass](../crown-reachable-items/README.md). The subsequent
[creature/actor pass](../crown-creatures/README.md) links companion/monster gear
and exact-copy blockers to these candidates. Broader Crown world content remains
separate authoring.
The [Crown content scope](../../crown-content-scope.md#campaign-and-world-inventory)
still owns that larger boundary. Keep native paths until replacements cover
the content that uses them.

## Source and attribution

Adapted from the *System Reference Document 5.2.1* by Wizards of the Coast LLC,
[official PDF](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
The authority PDF SHA-256 is
`8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87`.
This adaptation normalizes source tables and bodies and adds authored behavior
and mapping notes. The existing [character packages](../crown-characters/README.md)
own starting alternatives and source class/background clauses; the
[item audit](../../../audits/items.md) and
[content pipeline](../../../content_pipeline.md) locate reuse inputs and limits.
