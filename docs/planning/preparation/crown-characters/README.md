# Crown character and origin candidates

**Current handoff:** the [cross-set engine mapping](../../crown-engine-mapping/README.md)
is complete as planning. Follow its [bounded queue](../../crown-engine-mapping/assignments.md),
starting with CXM-01/S-249 ammunition. The writing snapshot below and its unchanged
candidate rules/blockers remain inputs; no candidate is promoted or accepted.

**79 written candidates. Not loaded, enabled or gameplay-verified.** This is
the owner-selected authoring pass for Crown characters through total level 5,
prepared on 2026-11-08 against `2a19eb1d` and the existing working-tree inputs.
Nothing here changes production content, engine behavior or slice acceptance.

Start with [the index](index.json). It lists every candidate and the six SRD
invocations excluded because their Warlock prerequisites exceed level 5.

| Set | Written |
|---|---:|
| Base classes | 12 |
| SRD subclasses | 12 |
| Eligible Eldritch Invocations | 22 |
| Metamagic options | 10 |
| Species | 9 |
| Backgrounds | 4 |
| Origin / General / Fighting Style feats | 4 / 2 / 4 |

The class/subclass files contain **121 feature bodies**: 98 base-class headings
and 23 subclass headings. Named suboptions such as Divine Spark, Turn Undead,
Flurry of Blows and Cunning Strike's three options remain inside their parent
feature, with their complete rules and operation plans. They aren't missing
because they have no separate top-level record. Class-level 5 subclass spell
grants are explicit in the spell tables even when the parent feature starts at 3.

## Reading the candidates

- `rules` preserves the official SRD feature or option body, with PDF pages and
  SHA-256. Class `source` also preserves Core Traits and multiclass instructions.
  [Source context](source-pages.json) retains the selected pages, including wide
  tables whose two-column extraction splits rows. Structured candidate tables
  normalize the in-band counts, slots and grants. Higher-level rows retained in
  source context or donor entries grant nothing to Crown characters.
- `authored_operations` specifies triggers, costs, targets, choices, formulas,
  ordering and endings. **These are authoring declarations, not registered
  engine opcodes or executable JSON syntax.** The complete source body still
  applies; an abbreviated operation sentence does not override a qualifier.
- Class `acquisition`, `casting`, `weapon_mastery` and `level_hit_points` retain
  starting packages, actual quantities/GP, proficiency filters, spell choices,
  preparation/replacement windows and class versus character progression.
  Array position 0 is class level 1. Ordinary slot rows are levels 1/2/3;
  Pact rows explicitly use `[slot count, slot level]`.
- `retained_runtime_seed`, `retained_runtime_fragment`, `retained_candidate` and
  `recovered_current_contract_fragments` reuse existing definitions and recovered
  drafts. They are comparison/mapping material, not a second grant list. Some
  retain old thresholds, native-only effects, disabled entries or legacy rules.
  The authored 2024 definition and official source take precedence. The new
  species definitions grant no fixed racial ASIs or inherited legacy weapons.
- `unsupported_behavior`, `equipment_resolution` and
  [required extensions](required-extensions.json) keep incomplete behavior
  explicit. Groups collect related mapping requirements and existing owners;
  they do not declare those owners absent or add new S-IDs. Every group member
  still needs its complete rule mapped and later verified before promotion.
- `reused_from` and `reused_input_hashes` pin starting material. Ignored staging
  drafts have their in-band payload copied here, so they are not the only home
  of the written work. The original four backgrounds are retained and adapted,
  rather than replaced with an unrelated new set.

## Cross-package acquisition

[Multiclass rules](multiclass.json) explicitly give each class's entry ability
requirements, restricted proficiency grants, Hit Die and level-1 feature grants.
They also specify nonstacking Extra Attack/base AC, per-class spell preparation,
separate Pact slots and each half caster's rounded-up slot contribution.
Current secondary-class feature acquisition remains a named blocker; no class
has been opted into production progression by this pass.

[Languages](languages.json) gives Common plus two Standard Language choices and
the class-language tables. Species lineage/legacy spells use **character** levels
3/5, independent of class allocation. Magic Initiate contains all three legal
spell lists and casting-ability choices. Its repeat limit differs from Lessons
of the First Ones, which requires a different Origin feat each time.

The class spell choices reuse [the 183 Crown spell candidates](../crown-spells/README.md)
and their authoritative list memberships. Listing a level-3 spell does not grant
a Paladin or Ranger level-3 slots or preparation. The spell candidates own each
spell's complete payload and its blockers. Familiar, Wild Shape and steed
selectors require their full legal source sets; current curated form menus do
not impose the candidate limit. Missing actor/stat-block or equipment consumers
stay explicit dependencies rather than invented creature/item definitions.

## Concrete retained limits and reconciliations

- Alert includes both Initiative proficiency and the immediate willing-ally
  Initiative swap, including same-combat and Incapacitated restrictions.
- Ascendant Step is available at Warlock 5. Gaze of Two Minds, Gift of the
  Depths, Investment of the Chain Master, Master of Myriad Forms and Pact of
  the Chain are included despite gaps in the old production option list.
- Monk Focus save DC uses Wisdom; Dexterous Attacks changes the Unarmed
  Grapple/Shove DC, not the Focus DC. Open Hand Addle ends at the start of
  the **target's** next turn. Full Deflect reduction/payment/redirection remains
  declared, including actual range, cover and damage type.
- Cleric starting option A has **7 GP**, following SRD p.36. The revised donor's
  structured `7000` copper value would incorrectly give 70 GP and is retained
  only as an identified source conflict.
- Soldier's four Gaming Set IDs already exist in core source. The remaining
  requirement links the chosen proficiency to the granted copy. Background
  candidates retain unresolved Book topics, Parchment, ordinary Pouch, Traveler's
  Clothes, Arrows and Quiver, and explicit Holy Symbol form handling. Class
  candidates also retain missing complete packs and the Wizard's actual
  Quarterstaff/Arcane Focus combination. No unrelated item is substituted.
- Draconic Resilience retains the newer HP/AC preparation and its explicit
  host findings. Source-owned max HP, base-AC selection and refresh still need
  reconciliation with the current contracts before promotion.

JSON, finite inventory, source/reference and link checks establish the written
set only. No engine fixes, gameplay tests, pack installation, production enabling
or save migration were performed. The subsequent
[package-equipment pass](../crown-equipment/README.md) writes the starting gear,
pack contents and previously unresolved item candidates without changing the
production blockers retained above. The subsequent
[reachable-item](../crown-reachable-items/README.md) and
[creature/actor](../crown-creatures/README.md) sets now write those finite
dependencies, including complete Wild Shape/familiar sets, Chain benefits,
Faithful Steed and campaign companions. World/event/object authoring remains
separate. Keep native paths until their replacements cover the
content that still uses them.

## Source and attribution

These candidates include material from the *System Reference Document 5.2.1*
by Wizards of the Coast LLC, available at
[the official SRD PDF](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
This adaptation normalizes extracted source and tables, structures behavior as
authoring data and adds runtime-mapping notes. The local authority PDF hash is
`8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87`.

The [revised class views](../../../../reference/2024/README.md),
[recovered-input map](../../../content_pipeline.md#recovered-local-inputs--2026-11-08),
[existing background preparation](../../crown-backgrounds/README.md) and
[Draconic preparation](../draconic-sorcery.md) locate the reused inputs and their
limits. No donor effect flag or old support label is treated as executable proof.
