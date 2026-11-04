# SC-07 support 04: Enthrall as shared data

Based on `codex/crown-spells-sc-07-support-03` (#100).

## Changes
- `data/core/spells/crown_sc_07.json` + manifest: Enthrall (SRD 5.2.1).
  - Level 2 enchantment, 60 ft, V/S, concentration up to 1 minute.
  - Chosen creatures you can see (`multi`, `requires_target_sight`) make a Wis save.
  - On a failed save the target gets `enthralled`.
- **Generic marker:** `CombatAction.MARKER_RULES.enthralled = {perception_penalty_10}` and `CombatAction.perception_penalty(entity)`. These are read by:
  - `EventResolver.resolve_skill_check` (Character, skill Perception);
  - `EventResolver.monster_ability_check_modifier` (monster Perception);
  - the new `EventResolver.passive_perception(entity)` (10 + Wisdom (Perception) modifier).
- **Generic save trait:** `fighting_caster_side` in `SharedSpell.SAVE_AUTO_SUCCESS_TRAITS`. It reuses `SpellSaveResolver.is_fighting_caster_side` (opposed initiative combatant, not friendly). `save_auto_success` now receives the cast context.
- No spell-ID branches.

## Proof (`src/spells/crown_sc_07_support_04_flow.gd`, scenario `crown_sc_07_support_04_flow`)
- **Contract:** the shared definition loads clean, and an unknown trait or unknown condition is rejected.
- **Renamed neutral definition** through the loader and `CombatAction.resolve_spell`:
  - A failed save enthralls the target.
  - Monster Perception and Passive Perception go from 13 to 3. Insight and Stealth are unchanged.
  - A Character's Perception check and Passive Perception drop by 10; Insight is unchanged.
  - A fought opposed combatant auto-succeeds with no dice.
  - A friendly creature in initiative is not "fought".
- **Player controls:** a Warlock learns Enthrall through level-up selection and casts it with the picker, two hex clicks and a confirm click.
  - The hostile combatant auto-succeeds.
  - The friendly bystander fails and is enthralled under concentration (Passive Perception 3).
  - Ending concentration clears it.
- **Checkpoint and fresh process** (`CROWN_SC_07_SUPPORT_04_RECOVER=1`): the enthralled record survives, still applies -10 and ends with concentration.
- **Logs:**
  - flow and recover logs;
  - regressions: `crown_sc_06_flow` (Sleep trait), `condition_recovery_flow`, `crown_sc_07_support_01_flow`;
  - logic suite: 6936 passed, 0 failed.
- **Saves:** there is no save schema change, only a new condition string. Old saves carry no `enthralled` key and load unchanged, and the checkpoint goes through the production save preflight.

## Limits
- "Creatures of your choice" is capped at 100 targets with `base_targets: 100`. Selection ends when you click a selected target again.
- No engine system consumes Passive Perception yet: Hide/Search use active checks, per the 2024 rules. `EventResolver.passive_perception` is the single owner and includes the penalty.
- The hearing requirement is not modeled. The SRD 5.2.1 text has none.
