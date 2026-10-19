# Character Sheet Value Audit

> **Archived material.** This preserves a past snapshot, not current instructions.
> Read the [current checkpoint](../../operations/current.md) and [roadmap](../../../roadmap.md) before acting.


> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

Date: 2026-08-10

Scope: representative race/class values through character initialization,
level-up, save/load, runtime HP mutation, and Character Sheet rendering.

The reproducible evidence case is `character_value_audit` in
`src/viewport_harness.gd`. It uses the production `Character`, `DataLoader`,
serialization, and `CharacterSheet` paths. It passed with zero engine errors.

## Matrix

All four cases started from the same base scores:
`STR 10, DEX 10, CON 14, INT 10, WIS 10, CHA 10`.

| Case | Racial score path | Raw class die (`hd.faces`) | Generated record | Runtime level-1 HP | Expected level-1 HP from raw die |
|---|---|---:|---|---:|---:|
| Human Fighter | All six scores +1; verified | 10 | `d10` | 12 | 12 |
| Elf Wizard | DEX +2, INT +1; Perception proficiency; verified | 6 | `d6` | 8 | 8 |
| Half-Orc Barbarian | STR +2, CON +1; verified | 12 | `d12` | 14 | 14 |
| Dwarf Rogue | No ability bonus; verified | 8 | `d8` | 10 | 10 |

The level-1 HP calculation is `hit_die_sides + CON modifier`. The raw class
files carry the die faces under `hd.faces`; the repaired converter and generated
records now preserve those values.

## Downstream trace

- Racial ability bonuses are applied once during `Character.initialize` and
  survive `Character.to_dict()` / `from_dict()` without being applied again.
- Level-up raises max HP and refills current HP. The behavior is internally
  consistent with the generated `d1` record, but the source die makes the
  resulting HP too low.
- Save/load preserved max HP, current HP, and racialized ability scores in all
  four cases.
- After a runtime HP mutation, Character Sheet rendering displayed the exact
  `HP current/max` pair for all four cases.

## Confirmed repair

The class-data generation boundary now maps `hd.faces` to `hit_die`, and all 14
production class records have been corrected. The new exact HP assertions would
have failed against the previous `d1` records; the existing automated suite
only required positive HP and therefore did not catch the defect.
