# Find Familiar and Wild Companion: supported first version

Authority: [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
Find Familiar, Wild Companion, Help and the four Beast stat blocks.
This is a bounded integration, not full spell certification.

## Clause checklist

- [x] Ordinary Find Familiar is selectable through the Wizard's supported
  spellbook/preparation path. Its authored-room control takes one hour, spends
  a slot and consumes an owned 10-GP incense copy. Ritual casting takes 70
  minutes, consumes the same component and spends no slot.
- [x] Wild Companion uses its own Magic-action/resource path, ignores incense,
  creates a Fey familiar and ends at the Druid's completed Long Rest.
- [x] Choose Cat, Owl, Rat or Spider and, for the ordinary spell, Celestial,
  Fey or Fiend. Recasting changes the existing bond's form/type; it does not
  create a second familiar. Ordinary bonds survive Long Rests.
- [x] Curated HP, AC, physical abilities, size, movement, Darkvision, skill
  modifiers and Cat's Dexterity-save proficiency reach the encounter creature.
- [x] The familiar has independent initiative and owner-seat control. It cannot
  take the ordinary Attack action; movement, Dodge and Help remain reachable.
  Owl Flyby while flying and Rat Agile prevent movement-triggered attacks.
- [x] Magic-action pocket dismissal/recall/release retain identity and HP where
  appropriate. Zero HP removes the creature. A new cast/resource is required
  afterward. Recall uses a legal unoccupied space within 30 feet.
- [x] A Bonus Action borrows the familiar's sight from its real position within
  100 feet, including Darkvision, until the owner's next turn. Moving the
  familiar updates the viewpoint; losing its presence removes the link.
- [x] Supported Touch spells offer familiar delivery. Preflight requires a
  conscious present familiar within 100 feet, its Reaction and reachable
  targets within 5 feet. Commitment spends its Reaction and the owner's normal
  spell resources. The caster remains the caster for reactions and effects.
- [x] Attack Help benefits the next weapon or spell attack roll and expires at
  the familiar's next turn; removing its source clears the benefit.
- [x] Authored Hidden Cache and Bandit Camp checks offer optional familiar Help
  only for a proficient present form. It applies to that next check immediately
  and cannot be banked or applied to an unauthored task.
- [x] Incense/placement/action/Reaction failures preserve resources. Owner/form/
  type/lifetime/HP checkpoint validation precedes loading. Both ordinary and
  Wild Companion paths have production disk round-trip coverage.

## Explicit limits

The other eligible Beast forms are unavailable. Cat's special jumping,
Spider's ceiling/web interactions, carried equipment and durable familiar
conditions are not complete. The room view does not yet expose independent
familiar scouting or a borrowed audio interaction; combat sight uses the shared
perception boundary. The current authored exploration clock does not simulate
interrupting an hour-long cast. Combat refuses that casting time.

Touch delivery currently covers the reviewed records marked `range_kind:
touch`: Cure Wounds, Guidance, Inflict Wounds, Chill Touch, Shocking Grasp,
Longstrider, Mage Armor, Light, Darkvision, Enhance Ability, Resistance,
Protection from Energy, and Protection from Evil and Good. This does not certify
the complete rules of those spells. Distant Spell delivery and unmarked Touch
records remain unavailable through the familiar path.

Other created creatures and control expiry independent of existence are still
open Wave 4 work. Bodies/forms and authored NPC/illusion foundations also remain
open in [the acceptance checklist](wave4-acceptance.md).
