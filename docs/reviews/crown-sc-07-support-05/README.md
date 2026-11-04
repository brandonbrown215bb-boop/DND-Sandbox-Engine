# SC-07 support 05 — Calm Emotions (partial)

Stacked on `codex/crown-spells-sc-07-support-04` (#101).

## What changed
- `data/core/spells/crown_sc_07.json` #3: Calm Emotions as shared data. It covers a 20-ft-radius Sphere (radius 4) at 60 ft, targets only Humanoids, uses a Cha save and concentration for 1 minute, and offers `condition_options` ["calmed", "calmed_indifferent"]. The manifest replaces imported #27.
- `CombatAction.MARKER_RULES`:
  - `calmed` carries `suppress_charmed` and `suppress_frightened`.
  - `calmed_indifferent` carries `attitude_indifferent` and `ends_on_damage`.
- New generic `CombatAction.marker_suppresses(entity, condition)` reads the raw marker storage, so it cannot recurse. It is consulted by:
  - `CombatAction.has_condition` (monsters);
  - `Character.has_condition`;
  - `CombatAction.is_immune_to_condition`, which also blocks new grants.
  An existing condition is suppressed rather than removed, and it comes back when the marker ends.
- `InfluenceRules.effective_attitude(monster)`: a Hostile profile reads as Indifferent while the creature carries an `attitude_indifferent` marker. The profile itself is never rewritten, so the attitude restores itself when the spell ends. `InfluenceRules.roll` uses it.
- `CombatAction._end_damage_broken_spell_effects`: markers with `ends_on_damage` are removed from the damaged creature only.
- `SharedSpell.chosen_condition(effect, spell, target)`: a per-target pick in `spell._chosen_conditions` (keyed by target id) overrides the per-cast pick.

## Proof
`src/spells/crown_sc_07_support_05_flow.gd`, scenario `crown_sc_07_support_05_flow`:
- **Contract:**
  - shared data validates;
  - an unknown option marker is rejected.
- **Renamed neutral definition** through the production loader and `CombatAction.resolve_spell`:
  - per-target picks give one creature option 1 and another option 2;
  - Frightened and Charmed are suppressed but still stored, and a new Frightened is blocked;
  - Hostile reads as Indifferent, while a Friendly creature is unchanged;
  - damage ends option 2 on that creature only;
  - a beast is unaffected;
  - suppressed conditions resume when the spell ends.
- **Player:**
  - a level-3 Bard selects the spell through ordinary class selection;
  - picker, then the real option PopupMenu (both options offered, "Calmed" chosen), then the area click;
  - the Humanoid is calmed and its Frightened is suppressed, the beast is skipped, the slot is spent and concentration is held;
  - ending concentration restores Frightened.
- **Checkpoint and fresh process:** SaveManager save, preflight and load, then `CROWN_SC_07_SUPPORT_05_RECOVER=1` in a new process:
  - Frightened is still suppressed and Charmed is still blocked;
  - Frightened resumes after concentration ends.
- **Logs:**
  - `scenario.log` and `recover.log`: PASSED;
  - `logic.log`: 6936 passed, 0 failed;
  - the support-04 scenario still passes.
- **Saves:** nothing changed in the save format; the new marker names are stored in the existing `conditions`/`condition_sources` maps. Old saves have no such markers, so they load unchanged.

## Limits (why the row is partial)
- The player UI asks for **one option per cast**. A per-creature choice exists only through `spell._chosen_conditions`, because area targets aren't known when the choice prompt runs.
- Option 2 does **not** end when the creature *witnesses allies* taking damage. The damage hook has no roster or sight context.
- Option 2 makes the creature Indifferent toward everyone, not toward "creatures of your choice". Attitude is a single profile value.
- Only engine code that goes through `has_condition` / `is_immune_to_condition` sees the suppression. Direct reads of the raw `conditions` dict do not.
