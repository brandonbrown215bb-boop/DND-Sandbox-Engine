# Batch 040 build: S-120 then S-163

Branch `batch-040-s120-s163`, stacked on `batch-039-s154-s131` at 087f382 (PR #7, including reviewer fix R1 eec3e3d).
Quest card Q-20261020-164546-32bf. This is build evidence and has not been reviewed yet.
Slice counts and the checkpoint are unchanged.

## Selection
The registry was checked at 087f382. No quest card claims either slice.

| Candidate | Status | Dependencies | Decision |
|---|---|---|---|
| **S-120** Aftermath successor actor/hazard | Planned | S-119 (built in open **034**, PR #1), S-154 (built in open **039**, PR #7) | **Chosen.** Completes the V-021 death/aftermath thread. |
| **S-163** Reversible retained-stat projection | Planned | S-154 (open **039**), S-039 (**Verified**), S-084 (built in open **037**, PR #4) | **Chosen.** Unblocks S-164, S-165 and S-173. |
| S-127, S-161, S-196, S-061 | Planned | Ready | Same reasons as in 039 |

- **No collisions:**
  - Neither slice touches `tools/content_editor/` or the wand charge path.
  - Neither adds `mode_choice` or `rule_alternatives` content, so F1 does not apply.
  - Choosing a projection form is a cast decision, not a feature option.
- **Wild Shape:** S-163 sits next to the parked decision card "Decide the Crown-band Wild Shape contract" (Q-20260810-010133-85ce). That card's next action asks for shared, data-defined projections that preserve current behavior. So `DruidRules` and the Druid data are **not touched**. A projection is refused while Wild Shape is active, and a saved actor holding both is refused.

## S-120: `AftermathSuccessorRules` (src/combat/aftermath_successor_rules.gd)
- **Policy:** an S-119 `zero_hp_aftermath` policy may declare `successor: {template, attack_bonus, side: "source"}`.
  - The template uses S-154's created-actor vocabulary and validation, with forbidden creation features excluded.
  - The loader refuses unknown fields, bad templates, bad sides and bad bonuses.
- **Creation:** when that aftermath settles a final death or destruction, the successor is created **once**.
  - **Character target:** the record goes on the remains as `corpse_state.successor = {policy_id, carrier, owner_id, corpse_id, actors[]}`.
  - **Creature record target:** it goes on `zero_hp_aftermath.successor`.
  - **Identity:** each successor id is tied to that exact death (`<corpse_id>:successor:N`).
  - **Once:** a second settlement or a repeated hit on the dead creature never creates another. A destroyed successor is recorded, not rebuilt or replaced.
- **Stable carrier:** the policy must come from a shared spell (`spell:<id>`, set in `SpellResolver`) or a weapon item (`item:<id>`, set in `resolve_weapon_attack`). An inline policy with no stable carrier, such as a monster attack dictionary, is refused and the receipt says so. This lets a reload rebuild the successor from catalog data instead of from a saved copy of behavior.
- **Exclusions:** the policy's existing `excluded_creature_types` and the non-final-damage rule both mean no successor is created.
- **Revival:** Revivify (and Gentle Repose) on those remains is refused while a successor stands.
- **Combat host:** `attach(state, host)` places living successors at the dead creature's **actual hex**, on the source's (party) side. A second placement never duplicates them.
- **Saves:** `CorpseRules.saved_error` validates the record against the carrier policy: count, ids, the same corpse, an owner other than the dead creature, HP within the maximum, and a cause-source policy match. A reload rebuilds the same successor with its current HP.
- **Cache:** the live cache rebuilds when the host object changes, in the same way as R1 for created actors. Scenarios do not clear the cache.

## S-163: `ActorProjectionRules` (src/characters/actor_projection_rules.gd)
- **Effect:** a shared `actor_projection` effect, carried on a flat self-cast source:
  - `forms`: 1–6 declared forms, each with type, size, speed, six scores, an AC formula, a temp_hp formula, and an attack with a bonus.
  - `retain`: must include `hp`, plus any of `creature_type`, `mental_scores`, `features`, `spellcasting`.
- **Form selection:** the cast decision `_projection_form_id` selects the form. A single form is automatic. With several forms and no selection, the cast is refused.
- **Apply:**
  - Physical scores and speed are set from the form; mental scores are kept when retained. The originals are kept on the source record.
  - AC (S-039-style replacement), size and an unretained creature type are read live from the form.
  - The form grants Temporary HP from its formula, scaled by the paid level. The actor's own current and maximum HP are never replaced.
  - Unretained features are suppressed, with their exact records kept. Unretained spellcasting blocks casting in the production validation path.
  - Spell slots and feature uses are never touched.
- **Revert:** the exact source ending (concentration, expiry, removal through `SpellEffects.remove`) restores scores, speed and the same feature records without duplicates. Leftover form Temporary HP is cleared. Current HP stays as it is, and nothing is refilled or reacquired.
- **Saves:**
  - `SpellEffectPersistence` validates the record: declared form, level and temp-HP match, original scores, DTO scores consistent with the form and retention, suppression consistent with retention, and the cast identity. A saved actor may hold only one projection, and never one alongside Wild Shape.
  - On reload, features rebuilt from the class are re-suppressed (`ActorProjectionRules.restore`), so a later revert restores them once.

## Neutral consumers changed
- `shared_spell.gd`: the effect, validation, carrier rule, timed, manages, and the apply case.
- `spell_effects.gd`: revert on remove, and prune keeps projection records.
- `spell_effect_persistence.gd`.
- `character.gd`: AC, creature type and size hooks, restore on load, and successor sync before saving.
- `spell_cast_validation.gd`: the spellcasting block.
- `zero_hp_aftermath_rules.gd`: successor validation and settlement.
- `corpse_rules.gd`: revival refusal and saved validation.
- `spell_resolver.gd` and `combat_action.gd`: the carrier.
- `created_actor_rules.gd`: a shared `instance()` builder. R1 owner-instance tracking is preserved.

There are no ID branches.

## Fixtures, checks and scenario
- **Fixtures:**
  - `data/fixtures/batch_040/spells/reap.json`: a death-to-bones aftermath with an undead Husk successor, including one allowed feature and one forbidden feature.
  - `data/fixtures/batch_040/spells/form.json`:
    - `b040_shift`: two forms (Hound, Bulwark); retains HP, type and mind; suppresses features and casting.
    - `b040_mantle`: one Wisp form; retains HP, features and casting.
- **Checks:** `Batch040Checks` adds 37 assertions:
  - **S-120:** validation; real-cast creation, values and identity; exclusions and receipt; once-only; refusal without a carrier; excluded types and non-final damage; revival refusal; a destroyed successor is not rebuilt; a creature-record host; the attack profile; saves, reload, five tamper refusals, and legacy corpses.
  - **S-163:** validation and the carrier rule; real-cast scores and speed; AC, Temporary HP, own HP and type; suppression; the attack; refusal of a second projection; Temporary HP spent first; revert; no refill or duplication; upcast; form selection and refusal; replaced type and mind; expiry; saves, reload re-suppression, revert after reload, five tamper refusals, and a double projection.
- **Scenario:** `batch_040_successor_projection_flow` gives 13 ok, 4 of which are the shared cast helper's lines. It covers:
  - An actual HUD cast of the two-form spell without a selection is refused.
  - An actual HUD cast of the single-form spell projects the caster, and an actual monster attack reads AC 15.
  - An actual reaping cast kills a creature, and one Husk is placed at its hex on the caster's side, with no duplicate on a second placement.
  - An actual reaping cast at a party member records the successor and refuses revival.
  - A **real `SaveManager` in-session save and load** happens with **no cache clear**: the projection is kept, and the same successor is rebuilt at 9/15. Concentration ending after the reload restores the same actor.

## Validation
- Import, then the translation revert.
- **Logic:** 5098 passed, 0 failed. A fresh run of 087f382 in a temporary worktree gives a baseline of 5061, so the delta is **+37**, equal to the new checks.
- **Log grep:** clean.
- **Scenarios (all 0 FAIL, 0 script errors):**

  | Scenario | ok |
  |---|---|
  | 031 | 25 |
  | 032 | 33 |
  | 033 | 70 |
  | 034 | 10 |
  | 035 | 9 |
  | 036 | 7 |
  | 037 | 11 |
  | 038 | 7 |
  | 039 | 10 |
  | 040 | 13 |
  | shared_spell_flow | 67 |

- The scenario fix to `attach`'s host match was re-checked with the combat logic group (800/0).

## Limits
- **S-120:**
  - Successors are actors only; object and hazard successors are not modeled.
  - Gear only follows the existing S-119 gear policy. There is no transfer to the successor.
  - Placement covers party-side sources only. A hostile or monster-source successor is not placed.
  - Policies carried only by monster attack dictionaries have no stable carrier and are refused.
  - The successor has no HUD command or AI.
- **S-163:**
  - Self-cast only; no willing or unwilling other target and no save.
  - No automatic end when form Temporary HP runs out.
  - Spellcasting suppression covers the production cast validation path and the `can_cast_spells` helper, not every legacy cast entry point.
  - The form attack is exposed as a profile only.
  - Druid Wild Shape is intentionally left on its own path.
- **Stack dependencies:** S-120 depends on S-119 (034, PR #1). S-163 depends on S-084 (037, PR #4). Both depend on S-154 (039, PR #7). These are built but not registry-Verified.
- **Monsters:** max-HP sources and zero-max death for monsters are filed separately as a parked card.
