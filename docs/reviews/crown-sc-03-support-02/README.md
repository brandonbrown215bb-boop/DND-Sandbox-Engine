# SC-03 support 02 — generic shared `weapon_attack` payload (True Strike)

Stacked on #86 (`codex/crown-spells-sc-03-support-01`).

## What changed
- New shared effect `weapon_attack` (`src/spells/shared_spell.gd`): `ability: "spellcasting"`, `weapon: "equipped_proficient_material"`,
  `damage_type_options` (must include `"weapon"`; other entries are damage types), optional `extra_damage {type, by_character_level}`.
  Strict validation rejects other abilities, weapon rules, option lists without `weapon`, and non-integer/non-dice bands.
- `SharedSpell.weapon_attack_effect()` / `weapon_attack_extra_formula()` replace every `id == "true_strike"` branch in
  targeting (range = equipped weapon reach), validation (proficient weapon worth 1+ CP, creature target), choices
  (damage type options from data; prompt only when >1), and both result hosts (player/monster targets; extra dice/type/label from data).
  Activity title uses the spell name.
- `data/core/spells/crown_sc_03_support_02.json`: True Strike as shared data (SRD 5.2.1 p. True Strike: attack with the component weapon using the
  spellcasting ability; Radiant or normal type; extra Radiant 1d6/2d6/3d6 at levels 5/11/17). Manifest override added.
- CSV: `true_strike` → converted.

## Proof
- `crown_sc_03_support_02_flow`: contract rejections; renamed neutral definition (`crown_sc_03_support_02:neutral_strike`, necrotic options/bands)
  through the production loader, weapon-reach targeting and `CombatAction.resolve_spell`; real True Strike via picker + hex click for both
  damage-type choices with level-5 1d6 Radiant recorded, out-of-reach click does nothing, no-weapon cast refused keeping the action.
- Existing `true_strike_spell_flow` passes on the shared definition. Logic suite: 6935 passed, 0 failed.

## Limits (disclosed)
- The renamed definition's weapon swing is performed by the player cast host (`SpellCastResults`), not inside `resolve_spell`; the renamed proof
  covers loader, range and `resolve_spell`, while the swing is proven on the real spell.
- No class-membership PR. No saved-data shape change, so no old-.sav round trip was needed.
- Internal profile flag `_true_strike` kept as-is (attack-profile marker, not an ID check).

## Windows
```
powershell -ExecutionPolicy Bypass -File .\run_tests.ps1 <path-to-godot.exe> -Suite logic
powershell -ExecutionPolicy Bypass -File .\run_tests.ps1 <path-to-godot.exe> -Suite integration -Scenario crown_sc_03_support_02_flow
powershell -ExecutionPolicy Bypass -File .\run_tests.ps1 <path-to-godot.exe> -Suite integration -Scenario true_strike_spell_flow
```
