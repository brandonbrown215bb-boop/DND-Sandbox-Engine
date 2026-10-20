# Batch 039 build: S-154 then S-131

Branch `batch-039-s154-s131`, stacked on `batch-038-s104-s085` (fe53898, PR #5).
Quest card Q-20261020-161514-6792. This is build evidence and has not been reviewed yet.
Slice counts and the checkpoint are unchanged.

## Selection
The registry was checked at fe53898. No quest card claims any candidate.

| Candidate | Status | Dependencies | Decision |
|---|---|---|---|
| **S-154** Parameterized created actor | Planned | S-032, S-036, S-049 (all **Verified**) | **Chosen.** Unblocks S-120 and S-163. |
| **S-131** Maximum-HP zero death/remains | Planned | S-130 (built in open **035**, PR #2), S-119 (built in open **034**, PR #1). Neither is registry-Verified yet. | **Chosen.** Completes the 034/035 max-HP and death thread. |
| S-120 Aftermath successor actor | Planned | Needs S-154 | Not ready |
| S-163 Retained-stat projection | Planned | Needs S-154 | Not ready |
| S-127 Reach/mastery/type choice | Planned | Ready (035/037) | Deferred: needs a weapon reach/mastery host |
| S-061 Current vs lifetime capacity | Planned | S-060 (open 036) | Deferred: item-charge adjacent, next to the wand charge conversion |
| S-161 Exclusive bond, S-196 Compartments | Planned | Ready | Lower value; no slice waiting on them |

- Neither chosen slice adds `mode_choice` or `rule_alternatives` content from any source, so F1 (Q-20261020-154337-209c) does not apply.
- Neither touches `tools/content_editor/` or the wand charge path.

## S-154: `CreatedActorRules` (src/characters/created_actor_rules.gd)
**The effect and its template**
- A new shared effect, `create_actor`, takes a bounded `template`:
  - creature type and size
  - speed and six ability scores
  - `ac`, `max_hp` and `count` formulas: `base` + `per_level` × the paid level above the spell's own level, with an optional `max`
  - one attack (name, NdX damage, damage type, range)
  - up to eight features
- Like source carriers, it requires a flat automatic self-cast. The loader refuses unknown fields, types, scores, ranges and dice.

**Ownership and lifetime**
- The cast's own source record on the owner (`spell_effects[source].created_actors = {level, actors: [{actor_id, current_hp}]}`) owns each actor's existence.
- When that exact source ends (expiry, concentration end, removal), its actors end. Another owner's equivalent cast is unaffected. Actors are never rebuilt or revived once their source is gone.

**What each actor gets**
- Each actor is a `Character` with:
  - `class_id = created_actor` and the template's live `creature_type`
  - the derived AC and maximum HP, with a separately tracked current HP
  - the retained owner identity (`created_owner_id`) and source identity
- The attack bonus (spell DC − 8) and the DC are read live from the owner through `SpellPermissionRules.save_dc`.

**Excluded features**
- Template features of a forbidden type are never copied, and the creation receipt reports them. The forbidden types are `create_actor`, `mode_choice`, `rule_upgrade`, `resource`, `zero_hp_replacement` and `spellcasting`, including when they appear as nested effects.
- The catalog template is never mutated.

**Saves**
- `to_dict` writes live current HP back to the record (`sync`).
- `SpellEffectPersistence.saved_state_error` validates the record against the loaded template: owner identity, level 0–9, the exact count for that level, sequential actor ids, and current HP within the derived maximum.
- Reload rebuilds the same actors from their records.

**Combat host**
- `CreatedActorRules.attach(state, owner, origin)` adds the owner's living actors to the owner's side and drops actors whose source has ended.

## S-131: zero-limit maximum-HP death (`MaxHpSourceRules`)
- **Rule:** a reduction rule may declare `zero_limit: {cause, remains}`, with remains of intact, dust or bones. It cannot declare a floor and cannot be an increase.
- **Ordering:** zero-limit reductions settle after ordinary floored reductions. They may take the remaining maximum, including the last point another source's floor left, down to 0. Ordinary reductions still stop at their floor.
- **Death:** a maximum of 0 reached this way is death through `CorpseRules.mark_dead`, with the declared cause and remains. `cause_source` names the exact source instance and rule, which fits S-119's cause schema.
- **Distinct from current-HP zero:** there are no Death Saves and no downed state, and healing does nothing. A downed creature whose maximum stays above 0 is not killed by the rule.
- **Revival:** `CorpseRules.target_error` already refuses revival while the maximum is 0. Removing the source restores the maximum but does not revive.
- **Saves:** a saved zero maximum must be backed by a zero-limit source and a recorded death. Legacy sources without `zero_limit` still validate.

## Neutral consumers changed
- `shared_spell.gd`: the effect list, validation, the flat self-cast rule, timed, managed, and the apply case.
- `spell_effects.gd`: prune keeps created-actor records.
- `spell_effect_persistence.gd`: the record validator.
- `character.gd`: `sync` in `to_dict`.
- `max_hp_source_rules.gd`.

There are no ID branches.

## Fixtures, checks and scenario
- **Fixtures:**
  - `data/fixtures/batch_039/spells/conjure.json`: a level-2 concentration self-cast. Its warden template has AC 13+1/level, HP 20+10/level and count 1+1/level (max 3), with one allowed feature and two forbidden features.
  - `data/fixtures/batch_039/monsters/withering.json`: a damage-dealt zero-limit reduction with dust remains.
- **Checks:** `Batch039Checks` adds 37 assertions:
  - template refusals
  - a real `SpellResolver` cast at base level and upcast
  - owner-linked attack and live DC, no catalog mutation, separate current HP
  - lifetime: concentration end, expiry, and an independent second owner
  - saved record plus five tamper refusals, and the reload
  - zero-limit validation, partial reductions, death and its remains/cause, not-downed and no healing, revival refusal, floor interplay, removal without revival, the downed-but-above-zero case
  - zero-max saves, reload, three refusals and legacy sources
- **Scenario:** `batch_039_created_actor_flow` (10 ok, including the shared cast helper's ok line):
  - An actual HUD cast creates one owner-linked warden and pays one slot. The warden joins the owner's side.
  - An actual monster attack reads the template AC of 13.
  - An actual withering monster hit takes a party member's maximum to 0: death with dust, not unconsciousness, and revival is refused.
  - The encounter drops the warden once its source is gone.
  - A **real `SaveManager.save_game`/`load_game`** rebuilds the same warden with its damaged current HP (17/20). Concentration ending after the reload ends it.

## Validation
- Import, then the translation revert.
- **Logic:** 5050 passed, 0 failed. A fresh run of fe53898 in a temporary worktree gives a baseline of 5013, so the delta is **+37**, equal to the new checks.
- **Log grep:** no SCRIPT ERROR, Parse Error or Compile Error in the logic or scenario logs.
- **Scenarios (all 0 FAIL):**

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
  | shared_spell_flow | 67 |

## Limits
- **Owner:** only a flat self-cast `Character` owner can create actors. Hosts on steps, items or features are open.
- **Attack:** the created actor's attack is exposed as an owner-linked profile. Commanding the actor (turn control, orders, AI) is not wired, and joining an encounter is an explicit `attach` call, not automatic at combat start.
- **Template features:** limited to declared records. Options chosen at creation (S-154's "selected options") are not modeled beyond the paid level.
- **Live instances:** they are cached per actor id. If a record is withdrawn and later re-added without `sync`, the cached HP is lost. Production sources never come back, but a reviewer may want this hardened.
- **Zero limit:** covers `Character` targets only, not monster dictionaries. Revival after the maximum is restored follows the existing Revivify rules, including the one-minute limit from the time of death.
- **Dependencies:** S-131 depends on S-130 (035, PR #2) and S-119 (034, PR #1), which are built but not registry-Verified. S-154's created-actor records are class-agnostic and do not use the F1 lookups.
