# SC-07 support 09: Bestow Curse option 4 limited to attack-roll hits and spell damage

Stacked on #105. SRD 5.2.1 says Bestow Curse's option 4 deals an extra 1d8 Necrotic "whenever you hit it with an attack roll or a spell". In #105 the rider fired on any damage the caster dealt; this PR limits it to those two triggers.

## Generic change
- `CombatAction.with_damage_origin(decisions, origin)` tags a damage call with `damage_origin` = `attack_hit` or `spell`.
- Marker damage riders now resolve only when the call carries one of those tags. The other checks still apply: the source must be the marker's source, there is no rider from a rider, and damage-link or response child calls are skipped.
- **Tagged (only the primary settlement):**
  - the weapon attack-roll hit (`_settle_weapon_attack_hit`)
  - spell damage (`SpellDamageRolls._finish_spell_damage`, which covers spell attacks and save spells)
  - spell zone damage (`spell_zone_terrain`, `combat_spell_zones`)
  - Hunter's Mark and Divine Smite damage
- **Untagged:** extra damage packets, weapon riders, room hazards, traps, falls, items, class features and aftermath damage. None of these can trigger the rider.
- There are no spell-ID branches.

## Proof
- **`crown_sc_07_support_09_flow`:**
  - Hazard, fall and item damage dealt by the caster adds no Necrotic.
  - The real `LocalRoomAreas` hazard path, placed by the caster, deals only its own 3 damage.
  - The caster's weapon attack-roll hit adds 1d8, and another creature's hit adds nothing.
  - The caster's Sacred Flame through `CombatAction.resolve_spell` adds 1d8.
- **Support-08 rerun:** the support-08 scenario and its fresh-process recovery still pass. Its direct damage calls are now tagged as spell damage.
- **Logic suite:** 6936 passed, 0 failed. Logs are in this folder.
- **Save data:** no change, so no save round trip is needed.

## Limits
- A damage path that isn't tagged (for example a feature that deals attack-hit damage outside `_settle_weapon_attack_hit`) under-triggers rather than over-triggers.
- Monster attack paths are not tagged; Bestow Curse's caster is always a Character.
- The CSV row stays converted, and its note is updated.
