# SC-07 support 10: Bestow Curse repair (supersedes #105–#106)

Rebases the held Bestow Curse commits onto main and fixes the review findings.

## What changed
- **Curse damage is a packet in the same occurrence.** The old child `resolve_damage` call and the `damage_origin` tag are gone.
  - Weapon hits: the curse is the last hit packet, so a critical doubles its dice and Deflect/Uncanny Dodge leftovers apply to it.
  - `SpellDamageRolls._finish_spell_damage`: the curse is added after the Empowered and zero-HP deferrals return, so a continuation rolls it once. It ignores the save scale and the multiplier, so a half-damage save still takes the full 1d8.
  - Spell-zone ticks (Spike Growth, Wall of Fire, Cloud of Daggers) use `CombatAction.resolve_spell_damage_occurrence`.
  - The packet is skipped when the occurrence dealt no damage. Returned `damage`/`resolved` include it, so concentration, aftermath and logs see it.
- **Duration is bound to the slot.** Records store `duration_slot_level`. Preflight checks the duration, Concentration and `until_dispelled` against that slot's tier, and allows Extended Spell's doubling up to 24 h. Finite records saved without a slot still load.

## Checks (Windows, Godot 4.7)
- `crown_sc_07_support_08_flow` passes, including its fresh-process recovery and the legacy support-05/06 chain. New checks cover the saved slot, five forged-tier rejections and the slotless legacy record.
- `crown_sc_07_support_09_flow` passes. It covers critical and non-critical weapon hits, another creature's hit, an immune hit, Necrotic immunity, a half-damage save, a critical spell, zero damage, Guiding Bolt, Sacred Flame, a downing hit and zone ticks.
- Logic `spells,combat,conditions,persistence`: 3745 passed, 0 failed.
- An independent read-only review found no blockers.

## Limits
- The packet rides weapon hits, `SpellDamageRolls` settlements and zone ticks only. Other direct spell settlements and monster casters add none. Divine Smite and Hunter's Mark add no second packet to a hit.
- A shared spell with two damage steps against one target would pay the packet twice; only fixtures do that today.
- Uncanny Dodge reduces the packet on a weapon hit but not on a spell attack.
- On a hit where the packet is skipped, the displayed rolled total still includes its dice.
- Preflight proves a save agrees with the slot it names. A save forged consistently as slot 9 still passes.
