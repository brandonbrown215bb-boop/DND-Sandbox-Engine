# Animate Dead: supported Crown first version

Authority: [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
Animate Dead, Skeleton and Zombie. This is a bounded integration, not full
spell certification.

## Clause checklist

- [x] Level-5 Cleric preparation exposes Animate Dead. Authored-room casting
  takes 60 seconds and spends one level-3 slot after prepared-spell, component,
  free-hand, range, path, body and placement checks. Combat refuses the minute
  casting time. The shared component-pouch/focus boundary handles unpriced
  Material components; no special consumed component is invented.
- [x] Recorded Small/Medium Humanoid bones produce a Skeleton; a recorded
  corpse produces a Zombie. An already-consumed body cannot produce another
  creature. Ashvale's temple supplies one authored pile of eligible bones.
- [x] Gentle Repose protection rejects creation before time, slot or body loss.
  Its additional world-remains control consumes the existing copper packet,
  spends a slot and stores ten days of protection; party-body ritual casting
  retains its separately verified path.
- [x] Creature identity, HP, owner, source remains and room location survive
  encounter exit and the existing dungeon-entrance disk checkpoint.
- [x] Controlled creatures have independent initiative outside party slots.
  Attack orders use the real feature picker and clicked enemy, spend one Bonus
  Action, reach owned creatures within 60 feet and give the same order to each.
  Invalid orders retain the Bonus Action. The task persists until its enemy is
  defeated or the encounter ends. No attack order means Dodge; new creatures
  wait in their room until given an explicit Follow order.
- [x] Room follow/stay controls issue a standing order. Following uses legal
  placement on entry to an authored room; Stay retains the previous location.
  Creator death prevents new commands without deleting the creature.
- [x] Control lasts 24 hours; existence has no spell deadline. Expiry retains
  HP/location and changes allegiance, including an in-place initiative
  conversion during combat. Expired actors use the existing hostile AI.
- [x] Recasting before control expires renews up to four selected/nearby actors
  within 10 feet using one minute and one level-3 slot. Renewal retains identity
  and damage. Control must still be active at completion; expired renewal
  refuses before cost.
- [x] Curated Skeleton/Zombie AC, HP, physical scores, speed, size, Darkvision,
  immunities, Skeleton vulnerability, weapon attack bonuses/damage and Zombie
  save bonus reach actual combat projections. Skeleton has Shortsword and
  Shortbow; Zombie has Slam. Shared damage resolves Zombie Undead Fortitude
  with a real Constitution save, including critical/Radiant exclusions.
- [ ] Higher-slot multi-body creation and expanded renewal.
- [ ] Arbitrary action/destination orders, hazard-avoidance movement under the
  default Dodge order, equipment changes and durable conditions/spell effects.
- [ ] Long-cast interruption and full world-body creation/transport/decay.

## Evidence and limits

`CreatedCreatureChecks` calls production rules/damage and rejects malformed
saved identities/control clocks. `created_undead_flow` exercises real Crown
preparation, room protection/refusal, creation and renewal, feature-picker
orders, initiative attacks, encounter capture, disk checkpoint/load, in-combat
expiry and a later hostile projection. Current acceptance and raw log paths
are recorded in [operations](../operations/current.md).

Initial creation reserves a legal nearby five-foot cell; full multi-cell
placement is not modeled. Party gear stays with its original Character while
the new Undead uses its curated weapons. Created creatures do not participate
in overworld encounters, and no fresh-process relaunch or manual visual
acceptance is claimed. World-remains Gentle Repose has ordinary casting only;
its ritual control and automatic decay remain open. This does not certify
Animate Objects or Finger of Death's Zombie.
