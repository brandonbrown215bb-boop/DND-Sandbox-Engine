# SC-04 support 01: shared matching-dice leap + costed diamond (Chromatic Orb)

Stacked on `codex/crown-spells-sc-03-support-07` (#92). SC-04's only queue row (`chromatic_orb`) is fully covered by this PR, and the CSV row is now marked `converted`.

## What changed (all generic, no spell-ID branches)
- **`leap_on_matching_dice`**, a new shared spell field `{range: 1..60 hexes, max_leaps: "slot_level" | 1..9}`. It is valid only on a single-target spell attack with a damage die. If the hit's kept damage dice show two equal faces of the spell's damage die, the effect leaps to a new living creature within `range` of the last target. The caster chooses the creature through the new `CombatHud.request_spell_leap_target_choice` popup. The leap gets a new attack and damage roll. Leaps stop at `max_leaps`, and each creature can be targeted once per casting. Rerolled (discarded) dice do not count.
- **`SpellCastContext.last_target_result`** is runtime-only. It is not saved, so the save shape is unchanged.
- **`SharedSpell.damage_die_sides`** comes with validation of the new field.
- **New item `diamond_50gp`** (spell_component, 50 GP) in `data/core/items/crown_sc_04_components.json`.
- **Chromatic Orb** is shared data in `data/core/spells/crown_sc_04_support_01.json`, with the manifest override replacing `imported_spells.json#30`. Per SRD 5.2.1 it has:
  - range 90 ft
  - V/S/M with a 50 GP diamond that is not consumed
  - a 3d8 ranged spell attack
  - a choice of six damage types
  - +1d8 per slot level above 1st
  - leaps of 30 ft, up to the slot level

## Proof
- **Renamed neutral spell:** `neutral_spark` (2d6 cold, a fixed single leap) goes through the production loader and `CombatAction.resolve_spell`.
- **Real Wizard cast:** a Wizard prepares Chromatic Orb through ordinary class selection. It is cast with the real picker, the slot popup, the damage-type popup and a hex click.
  - Without the diamond the cast is refused and no slot is spent.
  - With the diamond, the test alternates 1st- and 2nd-level slots. It checks that:
    - each cast spends one slot
    - leaps happen only after a hit and never exceed the slot level
    - the orb never returns to the first target
    - the Fire choice is applied
    - leaps were observed on both slot levels
    - the diamond is kept
- Logs are in `logs/`.
  - **SC-04 flow:** passes.
  - **Logic suite:** 6935 passed, 0 failed.
  - **Other scenarios:** mixed_mechanics_encounter, crown_sc_03_support_05/07 and ordinary_action_flow pass.

## Limits
- Leap candidates are any living creature in range, including the caster and allies. The caster chooses, as the rules allow.
- The leap's attack ignores the spell's range from the caster, as intended, since it is measured from the previous target. Sight and cover use the existing resolver.
- Only the exact `diamond_50gp` item satisfies the material component. A more valuable diamond item would not count, and a focus or pouch does not substitute.
- The new item may appear wherever item directories are scanned, such as shops.
- **Pre-existing failure, not caused by this PR:** `conversion_batch_001_flow` fails identically on the base f2baf33. The Bless upcast case raises an "Invalid access to 'targets'" error in `_resolve_player_target`.
