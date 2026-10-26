# Batch 085 build: S-126/S-140 cast-local transformations

Branch `batch-085-cast-local-transforms`, stacked on `batch-084-scenario-fixtures`
(PR #57, including reviewer commit 54074d6). Card Q-20261026-050635-4cf2.

## Finish line (verbatim)
> Extend the existing profiles so JSON can change a qualifying invocation's range, components, school or timing. Prove qualifying and unrelated casts side by side, compatible changes, once-only costs, and no catalog mutation. Bound the first batch explicitly; S-141 duration/concentration follows afterward.

## What changed
- `src/combat/attack_profile_rules.gd`: spell profiles now accept `replace.range_feet`,
  `add.range_feet`, `replace.school`, `replace.casting_time` (action/bonus_action),
  `remove.components` (V/S) and `scope.permission_sources`, all validated at load.
  The new `apply_cast()` builds the per-invocation copy with a `_cast_profile`
  record. Scope is judged on inherited fields, and `spell_dc` now uses the same
  qualifier.
- `src/spells/spell_cast_selection.gd` (production caller): `choose()` puts the
  transformed copy on the cast instead of a plain duplicate. It runs before
  targeting, budget validation and payment, and logs which sources changed the cast.
- `src/combat/combat_command.gd`: a Wand of Magic Missiles activation now copies the
  catalog record. Before this, it wrote `_magic_item_activation` and related keys
  into the shared catalog Magic Missile. The logic suite found this, because
  every later Magic Missile cast in the run counted as a wand activation.
- Fixture `data/fixtures/batch_085/classes/cast_transforms.json` (five source-owned
  profiles). No content ID is branched on (ADR-0018), and no engine defaults
  were added.

## Proof
- Logic: `Batch085Checks` cover qualifying vs unrelated casts, compatible changes
  plus the ignored conflict, scope on inherited fields, once-only reapply,
  raw records and item activations untouched, permission-scoped sources, no
  catalog mutation, Touch/reaction left alone, 10 malformed rules refused,
  the save carrying no profile, and the wand copy.
- HUD scenario `batch_085_cast_transform_flow` uses the real spell menu, slot
  popup and hex clicks:
  1. With the Bonus Action spent, a transformed Magic Missile is refused before
     payment. The slot and the Action stay unspent.
  2. The qualifying cast arrives with range 36, components [S], Bonus Action
     timing and the abjuration school; the conflicting school is ignored. It
     deals damage and spends one slot and the Bonus Action, leaving the Action.
  3. Fire Bolt in the same turn is unchanged and spends the Action.
  4. Ray of Frost shrinks to 10 ft, and a target 15 ft away is refused with
     nothing spent.
  5. The catalog records are unchanged.
- Fresh process: no durable state changed (memory-only profile; rules rebuilt
  from class features), so no reload scenario was added.

## PARTIAL / bounds
See `docs/mechanics/attack-profiles.md` → "PARTIAL (batch 085 bound)".
- HUD player casts only.
- Material components can't be removed.
- Timing changes only between Action and Bonus Action.
- There are no costed profiles, and native Metamagic isn't migrated.
- S-141 is untouched.

## Results
- Each run imported twice. Logic suite: **6380 passed, 0 failed**. No SCRIPT/Parse/Compile errors.
- These scenarios pass: `batch_085_cast_transform_flow`, `wand_magic_missiles_flow`,
  `wand_last_charge_destruction_flow`, `spell_cast_stage_flow`, `sorcerer_subtle_spell`,
  `batch_077_per_swing_choice_flow`, `batch_067_weapon_damage_choice_flow`.
- `sorcerer_twinned_spell` and `wizard_capstone_cast_modes` fail, but they fail
  with the **identical** [FAIL] lines on the base branch `batch-084-scenario-fixtures`.
  Batch 085 didn't cause them; they need a separate fixture repair.
