# 0021 — Source-owned damage-interception wards and ally projection

- **Status:** Accepted
- **Date:** 2026-10-10
- **Affects:** [ADR-0004](0004-staged-2024-rules-and-save-boundary.md), [ADR-0006](0006-composable-class-features.md), [ADR-0018](0018-shared-data-driven-rules-runtime.md), [ADR-0019](0019-shared-ordered-execution-and-zero-hp-replacement.md)

## Context

The 2024 Wizard **Abjurer** subclass introduces **Arcane Ward** (Level 3) and **Projected Ward** (Level 6):

- **Arcane Ward (Level 3):** *"You can weave magic around yourself for protection. When you cast an Abjuration spell with a spell slot, you can simultaneously use a strand of the spell's magic to create a magical ward on yourself that lasts until you finish a Long Rest. The ward has a Hit Point maximum equal to twice your Wizard level plus your Intelligence modifier. Whenever you take damage, the ward takes the damage instead, and if you have any Temporary Hit Points, the ward takes the damage before those Temporary Hit Points. If this damage reduces the ward to 0 Hit Points, you take any remaining damage. While the ward has 0 Hit Points, it can't absorb damage, but its magic remains. Whenever you cast an Abjuration spell with a spell slot, the ward regains a number of Hit Points equal to twice the level of the spell slot. Alternatively, as a Bonus Action, you can expend a spell slot, and the ward regains a number of Hit Points equal to twice the level of the spell slot expended. Once you create the ward, you can't create it again until you finish a Long Rest."*
- **Projected Ward (Level 6):** *"When a creature that you can see within 30 feet of yourself takes damage, you can take a Reaction to cause your Arcane Ward to absorb that damage. If this damage reduces the ward to 0 Hit Points, the warded creature takes any remaining damage."*

### Pinned Source and Correction Ledger

- **Primary Subclass Clause Source:** Licensed 2024 PHB Abjurer compendium page (`https://roll20.net/compendium/dnd5e/Subclasses:Abjurer?expansion=32231&iframe=true`, inspected 2026-10-09). This supplies the Arcane Ward and Projected Ward clauses above; full PHB subclass corpus certification remains outside SRD 5.2.1, so unsupported Abjurer features (`abjurer_abjuration_savant`, `abjurer_spell_breaker`, `abjurer_spell_resistance`) stay `"enabled": false` and `"rules_status": "2024-partial"`.
- **Official Errata Inspection:** D&D Beyond Sage Advice & Errata hub (`https://www.dndbeyond.com/sources/dnd/sae`, updated Oct 7, 2026), current Player's Handbook errata page (`https://www.dndbeyond.com/sources/dnd/sae/players-handbook`), and current PDF (`https://media.dndbeyond.com/compendium-images/phb/downloads/Errata%20-%20Player%27s%20Handbook%205.5e.pdf`, inspected 2026-10-09) list no changes to Arcane Ward or Projected Ward.
- **Official Sage Advice Inspection:** The official Sage Advice Compendium (`https://www.dndbeyond.com/sources/dnd/sae/sage-advice-compendium`, inspected 2026-10-09) answers *"How does Arcane Ward interact with temporary hit points and damage resistance that an abjurer might have?"*:
  - An Arcane Ward is not an extension of the Wizard and does not have its own damage resistances, vulnerabilities, or immunities.
  - Relevant damage resistances or vulnerabilities of the creature protected by the ward (the Abjurer for self-absorption, or the visible target for Projected Ward) apply **first**, before the ward absorbs damage.
  - The ward then absorbs the post-resistance/post-vulnerability damage up to its current Hit Points.
  - If the ward is reduced to `0` Hit Points and leftover damage remains, the protected creature takes that leftover damage **without** applying its resistance or vulnerability a second time, while any relevant **damage immunity** of the creature reduces that leftover damage to `0`.
  - Any still-remaining damage is then taken by the protected creature's **Temporary Hit Points** (`temp_hp`), and finally by its **real Hit Points** (`current_hp`).

Under [ADR-0018](0018-shared-data-driven-rules-runtime.md), source-owned damage-interception capacity pools and ally Reaction projection belong in a shared data-driven runtime primitive (`WardRules`, `damage_ward_pool`, and `damage_ward_projection`) rather than an Abjurer-named switch. A non-production homebrew fixture (`fixture:runeguard`) must exercise the same creation, slot recharge, Bonus Action slot expenditure, Reaction projection, 5-step damage order, and save round-trip without new GDScript branches.

## Decision

### 1. Data-Driven Effect Schema

`DataLoader` validates two passive feature effect types:

- `damage_ward_pool`:
  - `pool_id` (required non-empty string identifier)
  - `creation_trigger` (`"spell_cast_with_slot"`)
  - `trigger_schools` (non-empty array of valid spell schools, e.g. `["Abjuration"]`)
  - `creation_uses_per` (`"long_rest"`)
  - `max_hp_level_multiplier` (integer `1..10`)
  - `max_hp_ability` (ability key in `["STR", "DEX", "CON", "INT", "WIS", "CHA"]`)
  - `max_hp_flat_bonus` (optional integer `-20..100`, default `0`)
  - `recharge_slot_multiplier` (integer `1..10`)
  - `bonus_action_slot_recharge` (boolean)
- `damage_ward_projection`:
  - `pool_id` (required non-empty string identifier matching an earlier or same-level `damage_ward_pool` on the class or subclass)
  - `trigger` (`"visible_creature_damaged"`)
  - `action_cost` (`"reaction"`)
  - `range_feet` (integer `5..300`, divisible by `5`)
  - `target_predicate` (`"visible_creature_within_range"` or `"ally_visible_within_range"`)

In `data/core/subclasses/abjurer.json`, `abjurer_arcane_ward` (Level 3) declares `damage_ward_pool` (`pool_id: "arcane_ward"`, `creation_trigger: "spell_cast_with_slot"`, `trigger_schools: ["Abjuration"]`, `creation_uses_per: "long_rest"`, `max_hp_level_multiplier: 2`, `max_hp_ability: "INT"`, `recharge_slot_multiplier: 2`, `bonus_action_slot_recharge: true`) and `abjurer_projected_ward` (Level 6) declares `damage_ward_projection` (`pool_id: "arcane_ward"`, `trigger: "visible_creature_damaged"`, `action_cost: "reaction"`, `range_feet: 30`, `target_predicate: "visible_creature_within_range"`).

### 2. Ward Lifecycle, Slot Creation/Recharge, and Bonus Action Expenditure

- **Maximum HP Calculation:** `max_hp = maxi(1, character.level * max_hp_level_multiplier + character.ability_scores.get_ability_modifier(max_hp_ability) + max_hp_flat_bonus)`. Level-up recomputes `max_hp` for any created ward and clamps `current_hp` to `[0, max_hp]`.
- **Creation and Slot Cast Recharge (`WardRules.on_slot_spell_cast`):**
  - Triggered only when a character casts a spell whose `school` (case-insensitive) is in `trigger_schools`, using an actual expended spell slot of `slot_level >= 1` after any Counterspell interruption check succeeds.
  - Cantrips (`level == 0`), ritual casts (`_ritual_cast`), free casts (`spell_free_cast`, Spell Mastery, Signature Spells, Mystic Arcanum, Divine Intervention, magic item charges), refused casts, and Counterspelled casts (where the incoming slot is refunded) never create or recharge a ward.
  - Reaction spells cast with a real spell slot (such as `shield` or `counterspell`) qualify when their school is in `trigger_schools`.
  - If the ward has not yet been created since the last Long Rest (`not created_since_long_rest`), the first qualifying cast creates the ward at full capacity (`active = true`, `created_since_long_rest = true`, `current_hp = max_hp`) without also adding `recharge_slot_multiplier * slot_level` on top of `max_hp`.
  - If the ward is already created (`active == true`, including at `0` HP), a qualifying slot cast restores `recharge_slot_multiplier * slot_level` HP, capped at `max_hp`.
- **Bonus Action Slot Recharge (`WardRules.recharge_ward_from_slot_bonus_action`):**
  - Requires an already-created ward (`active == true` and `created_since_long_rest == true`), `current_hp < max_hp`, an available spell slot of the chosen level (`slot_level >= 1`), and an unspent Bonus Action (`turn_budget.can_spend("bonus_action")` in combat).
  - Expends one spell slot of `slot_level` and restores `recharge_slot_multiplier * slot_level` HP to the ward, capped at `max_hp`. It cannot create an uncreated ward.
- **Rest Lifecycle:**
  - Short Rest preserves the ward's `active`, `created_since_long_rest`, `current_hp`, and `max_hp` state unchanged.
  - Long Rest (`Character.long_rest()`) expires all active wards and resets `created_since_long_rest` to `false` (`current_hp = 0`, `active = false`), ready to be created again on the next qualifying slot cast.

### 3. Five-Step Damage Pipeline (`CombatAction.resolve_damage`)

Every damage occurrence through `CombatAction.resolve_damage` executes in five ordered steps:

1. **Protected Creature Resistance / Vulnerability (and pre-ward source/target reductions):** Apply source damage-roll reductions (`ray_of_enfeeblement`), target `Resistance` spell reduction, and the protected creature's damage resistances and vulnerabilities (halving on resistance via `floor`, doubling on vulnerability) **once**.
2. **Ward Interception (`WardRules.absorb_damage`):**
   - If the damaged target is a `Character` with an active self `damage_ward_pool` (`current_hp > 0`), or if another living, non-incapacitated `Character` with `damage_ward_projection` and an active ward (`current_hp > 0`, `reaction_available == true`) within `range_feet` and with line of sight (`CombatPerception.can_see_target`) accepts the Projected Ward Reaction for that damage occurrence, the ward absorbs `ward_absorbed = mini(damage_after_step_1, ward.current_hp)`.
   - Projected Ward spends `protector.reaction_available = false` when committed. Declining or canceling the prompt leaves `reaction_available` and `ward.current_hp` untouched.
   - The committed projection belongs to one damage occurrence. Weapon and spell settlement assign a transient occurrence ID shared only by the typed components of that hit. Reusing a decision dictionary across subsequent hits or ordered steps cannot reuse the spent Reaction. Occurrence IDs are never persisted.
   - `ward.current_hp` decreases by `ward_absorbed`. If `ward.current_hp` reaches `0`, the ward remains `active = true` at `0` HP so later qualifying casts or Bonus Action slot expenditures can recharge it.
   - Leftover damage is `damage_after_ward = damage_after_step_1 - ward_absorbed`. The protected creature's resistance or vulnerability is **never** applied a second time to `damage_after_ward`.
3. **Protected Creature Immunity on Leftover Damage:** If `damage_after_ward > 0` and the protected creature is immune to `damage_type`, `damage_after_ward` becomes `0`.
4. **Temporary Hit Points (`temp_hp`):** Absorb `temp_hp_absorbed = mini(damage_after_ward, target.temp_hp)`.
5. **Real Hit Points (`current_hp`), Death Ward, and Zero-HP Replacement:**
   - Post-ward damage taken by the creature is `resolved = damage_after_ward` (`temp_hp_absorbed + hp_loss`).
   - If `resolved == 0` (the ward absorbed all damage, or immunity negated the leftover), the creature takes `0` damage: `temp_hp` and `current_hp` are unchanged, no Concentration save is triggered, damage-broken spell effects do not end, and Zero-HP Replacement does not trigger.
   - If `resolved > 0`, Concentration save DC uses `clampi(int(floor(float(resolved) / 2.0)), 10, 30)` (post-ward damage taken, including Temp HP absorbed and excluding `ward_absorbed`), and `SharedStepExecutor.resolve_zero_hp_replacement` receives `resolved` as the triggering damage when `current_hp` reaches `0`.

`CombatAction.resolve_damage` returns `ward_absorbed`, `ward_pool_id`, `ward_owner_id`, and `ward_remaining_hp` alongside `damage`, `hp_loss`, `resolved`, and `temp_hp_absorbed`.

### 4. Save Compatibility and Preflight Validation

- `Character.to_dict()` and `Character.from_dict()` persist `damage_wards` within schema version 2 (`SaveManager.CURRENT_SCHEMA_VERSION == 2`) as:
  ```json
  {
    "version": 1,
    "pools": {
      "arcane_ward": {
        "pool_id": "arcane_ward",
        "source_feature_id": "abjurer_arcane_ward",
        "active": true,
        "created_since_long_rest": true,
        "current_hp": 7,
        "max_hp": 10
      }
    }
  }
  ```
- Existing schema-2 saves without `damage_wards` default to an empty/uncreated ward state with no migration.
- `ClassProgression.saved_choices_error(dto)` invokes `WardRules.saved_state_error(dto, data, subclass, level)` during `SaveManager.load_game` preflight. Malformed `damage_wards` payloads (non-Dictionary, unsupported `version`, non-Dictionary `pools`, unowned `pool_id` or `source_feature_id`, non-boolean `active`/`created_since_long_rest`, `active: true` when `created_since_long_rest: false`, non-integer or negative `current_hp`/`max_hp`, `max_hp` mismatching derived capacity, or `current_hp > max_hp`) are rejected before `PartyManager` or `PlayerManager` state is mutated.

## Acceptance Boundary

1. `abjurer.json` and `fixture:runeguard` pass `DataLoader` schema and cross-reference validation; malformed `damage_ward_pool` and `damage_ward_projection` definitions fail validation cleanly.
2. Qualifying slot-paid spell casts (including `shield`/`counterspell` Reactions) create or recharge the ward only after Counterspell checks pass; cantrips, rituals, free casts, and Counterspelled casts never create or recharge the ward; Bonus Action slot expenditure recharges an already-created ward.
3. `CombatAction.resolve_damage` enforces the 5-step damage order (`resistance/vulnerability -> ward -> immunity on leftover -> Temporary HP -> real HP`) without double-halving on resistant targets, and both Concentration saves and Zero-HP Replacement observe post-ward `resolved` damage.
4. Projected Ward Reaction prompts in combat when a visible creature within range takes damage, enforces Reaction availability, range, sight, non-incapacitation, and target predicate, and leaves state untouched when declined.
5. Corrupt `damage_wards` save payloads fail preflight without mutating live party state, and valid active/depleted ward state survives a two-process fresh-relaunch save/load round-trip.
