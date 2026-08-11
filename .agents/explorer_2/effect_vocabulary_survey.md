# Data Loader & Engine Effect Vocabulary Survey Report

## 1. Executive Summary

This survey provides a comprehensive architectural analysis of `src/autoload/data_loader.gd`, focusing on the `CURATED_FEATURE_EFFECTS` data dictionary, engine feature sanitization pipeline, runtime resolution mechanics, and effect vocabulary capabilities for D&D 5e class features.

`DataLoader` operates as an autoloaded singleton in Godot (`res://src/autoload/data_loader.gd`), responsible for loading, validating, and curating game data from JSON files in `data/core/` and `data/mods/`. To bridge raw D&D 5e class feature records with game engine mechanics, `DataLoader` uses `CURATED_FEATURE_EFFECTS`—a hardcoded dictionary mapping feature identifiers to engine-executable effect definitions.

During content validation, `DataLoader` automatically injects curated effect structures into matching class features that lack inline effect arrays. Any class feature that remains without an `effects` array or an engine `resolver` script is rejected during sanitization as an "unsupported effectless feature" and excluded from active class feature arrays.

Runtime execution of curated features is distributed across three engine layers:
1. **Passive/Stat Layer (`character.gd`)**: Handles stat modifiers, AC recalculations (e.g. Unarmored Defense), extra attack counts, and resource initialization.
2. **Active Action Layer (`class_feature.gd` & `event_resolver.gd`)**: Resolves manually activated abilities (e.g., Second Wind, Lay on Hands, Innate Sorcery) by applying heal, condition, resource recovery, item grant, or movement effects.
3. **Combat Engine Trigger Layer (`combat_state.gd`)**: Hooked directly into turn flow and attack/damage resolution for complex contextual triggers (e.g., Sneak Attack, Divine Smite, Reckless Attack, Favored Foe, Uncanny Dodge).

---

## 2. Catalog of Existing `CURATED_FEATURE_EFFECTS` Entries

The `CURATED_FEATURE_EFFECTS` constant in `src/autoload/data_loader.gd` (lines 42–108) currently contains **34 curated class feature entries** spanning 11 character classes.

| Feature ID | Type | Action Cost | Uses / Cadence | Resource Formula | Effects Array & Properties | Execution Handler |
|---|---|---|---|---|---|---|
| `fighter_second_wind` | *active* | *none* | 1 / `"rest"` | *none* | `[{"type": "heal_self", "value": "1d10+level"}]` | `ClassFeature.execute` -> `heal_self` |
| `fighter_action_surge` | *active* | *none* | 1 / `"rest"` | *none* | `[{"type": "grant_extra_action"}]` | `ClassFeature.execute` -> `grant_extra_action` |
| `fighter_extra_attack` | `"passive"` | *none* | *none* | *none* | `[{"type": "extra_attack", "count": 1}]` | `character.gd` (`_apply_passive_feature`) |
| `barbarian_rage` | *active* | `"bonus_action"` | 1 / `"rest"` | *none* | `[{"type": "grant_condition", "condition": "raging", "duration": 10}, {"type": "stat_modifier", "key": "damage:physical", "amount": 2, "duration": 10}]` | `ClassFeature.execute` -> `EventResolver` |
| `barbarian_unarmored_defense` | `"passive"` | *none* | *none* | *none* | `[{"type": "unarmored_defense", "ability": "CON", "allows_shield": true}]` | `character.gd` (`_recalculate_ac`) |
| `barbarian_reckless_attack` | `"passive"` | *none* | *none* | *none* | `[{"type": "reckless_attack"}]` | `combat_state.gd` (`has_feature`) |
| `monk_patient_defense` | *active* | `"bonus_action"` | 1 / `"turn"` | *none* | `[{"type": "grant_condition", "condition": "dodging", "duration": 1}]` | `ClassFeature.execute` -> `EventResolver` |
| `monk_unarmored_defense` | `"passive"` | *none* | *none* | *none* | `[{"type": "unarmored_defense"}]` | `character.gd` (`_recalculate_ac`) |
| `monk_step_of_the_wind` | *active* | `"bonus_action"` | 1 / `"turn"` | *none* | `[{"type": "step_of_the_wind"}]` | `ClassFeature.execute` -> `EventResolver` |
| `monk_martial_arts` | *active* | `"bonus_action"` | 1 / `"turn"` | *none* | `[{"type": "unarmed_attack"}]` | `ClassFeature.execute` -> `EventResolver` |
| `monk_bonus_unarmed_strike` | *active* | `"bonus_action"` | 1 / `"turn"` | *none* | `[{"type": "unarmed_attack"}]` | `ClassFeature.execute` -> `EventResolver` |
| `monk_flurry_of_blows` | *active* | `"bonus_action"` | 1 / `"turn"` | *none* | `[{"type": "unarmed_attack", "count": 2}]` | `ClassFeature.execute` -> `EventResolver` |
| `paladin_divine_smite` | `"passive"` | *none* | *none* | *none* | `[{"type": "divine_smite", "base_dice": "2d8", "damage_type": "radiant"}]` | `combat_state.gd` (`has_feature`) |
| `paladin_fighting_style` | `"passive"` | *none* | *none* | *none* | `[{"type": "defense_style", "ac_bonus": 1, "requires_armor": true}]` | `character.gd` / `combat_state.gd` |
| `ranger_fighting_style` | `"passive"` | *none* | *none* | *none* | `[{"type": "archery", "attack_bonus": 2, "requires_ranged": true}]` | `combat_state.gd` (`has_feature`) |
| `paladin_lay_on_hands` | *active* | `"action"` | 1 / `"rest"` | `"level*5"` | `[{"type": "lay_on_hands", "pool": "level_times_five"}]` | `ClassFeature.execute` -> `EventResolver` |
| `paladin_divine_sense` | *active* | *none* | *none* | *none* | `[{"type": "divine_sense", "duration": 2, "creature_types": ["celestial", "fiend", "undead"]}]` | `ClassFeature.execute` -> `EventResolver` |
| `bard_bardic_inspiration` | *active* | *none* | *none* | *none* | `[{"type": "bardic_inspiration", "die": "1d6", "range": 12}]` | `ClassFeature.execute` -> `EventResolver` |
| `ranger_favored_foe` | `"passive"` | *none* | *none* | *none* | `[{"type": "favored_foe", "base_dice": "1d4", "duration": 10}]` | `combat_state.gd` (`has_feature`) |
| `barbarian_extra_attack` | `"passive"` | *none* | *none* | *none* | `[{"type": "extra_attack", "count": 1}]` | `character.gd` (`_apply_passive_feature`) |
| `ranger_extra_attack` | `"passive"` | *none* | *none* | *none* | `[{"type": "extra_attack", "count": 1}]` | `character.gd` (`_apply_passive_feature`) |
| `monk_extra_attack` | `"passive"` | *none* | *none* | *none* | `[{"type": "extra_attack", "count": 1}]` | `character.gd` (`_apply_passive_feature`) |
| `paladin_extra_attack` | `"passive"` | *none* | *none* | *none* | `[{"type": "extra_attack", "count": 1}]` | `character.gd` (`_apply_passive_feature`) |
| `rogue_sneak_attack` | *active* | *none* | *none* | *none* | `[{"type": "sneak_attack", "dice": "1d6"}]` | `combat_state.gd` (`_is_sneak_attack_valid`) |
| `rogue_uncanny_dodge` | *active* | *none* | *none* | *none* | `[{"type": "reaction", "reaction": "uncanny_dodge"}]` | `combat_state.gd` (`reaction_available`) |
| `rogue_cunning_action` | *active* | `"bonus_action"` | 1 / `"turn"` | *none* | `[{"type": "cunning_action"}]` | `ClassFeature.execute` -> `EventResolver` |
| `wizard_arcane_recovery` | *active* | *none* | *none* | *none* | `[{"type": "recover_spell_slots"}]` | `ClassFeature.execute` -> `EventResolver` |
| `cleric_channel_divinity:_harness_divine_power` | *active* | *none* | *none* | *none* | `[{"type": "recover_spell_slots"}]` | `ClassFeature.execute` -> `EventResolver` |
| `warlock_pact_magic` | `"passive"` | *none* | *none* | *none* | `[{"type": "pact_magic"}]` | `character.gd` (`_update_spell_slots`) |
| `warlock_magical_cunning` | `"active"` | `"action"` | 1 / `"rest"` | *none* | `[{"type": "pact_magic_recovery", "fraction": 0.5}]` | `ClassFeature.execute` -> `EventResolver` |
| `sorcerer_sorcery_points` | `"passive"` | *none* | *none* | *none* | `[{"type": "sorcery_points"}]` | `character.gd` (`_sync_sorcery_points`) |
| `sorcerer_innate_sorcery` | `"active"` | *none* | *none* | *none* | `[{"type": "innate_sorcery", "duration": 10}]` | `ClassFeature.execute` -> `EventResolver` |
| `sorcerer_metamagic` | `"passive"` | *none* | *none* | *none* | `[{"type": "metamagic", "options": ["empowered_spell"]}]` | `combat_state.gd` (`metamagic`) |
| `artificer_tinker's_magic` | `"active"` | *none* | *none* | *none* | `[{"type": "give_item", "item_id": "ball_bearings"}]` | `ClassFeature.execute` -> `EventResolver` |

---

## 3. Schema Conventions & Field Definitions

Curated feature effect definitions follow a structured Godot Dictionary schema with container-level metadata and item-level effect descriptors.

### 3.1 Container Schema (Top-Level Feature Dictionary)

| Field | Type | Default | Description |
|---|---|---|---|
| `type` | String | `"active"` | Activation type: `"passive"`, `"active"`. If omitted, defaults to `"active"`. |
| `action_cost` | String | `"none"` | Action budget required: `"action"`, `"bonus_action"`, `"reaction"`, `"none"`. |
| `uses` | Integer | `1` | Base usage count per cadence. |
| `uses_per` | String | `"none"` | Recharge cadence: `"turn"`, `"combat"`, `"short_rest"`, `"long_rest"`, `"rest"`. |
| `resource_formula` | String | `""` | Formula for dynamic pool calculation (e.g., `"level*5"` for Paladin Lay on Hands). |
| `effects` | Array[Dictionary] | `[]` | List of discrete effect payload objects executed when feature is triggered or applied. |

### 3.2 Effect Item Schema (Payload Dictionary)

Every element inside the `effects` array is a Dictionary containing a required `"type"` discriminator key, accompanied by type-specific parameter keys:

* **Discriminator Key**:
  * `"type"` (String): Identifies the exact effect handler in `ClassFeature` or `EventResolver`.

* **Parameter Keys**:
  * `"value"` (String / int): Dice string (e.g. `"1d10+level"`) or numeric value.
  * `"condition"` (String): Condition name string (e.g. `"raging"`, `"dodging"`, `"innate_sorcery"`).
  * `"duration"` (Integer): Duration in turns.
  * `"key"` (String): Stat or roll key (e.g. `"damage:physical"`, `"AC"`, `"speed"`).
  * `"amount"` (Integer): Numeric modifier amount.
  * `"ability"` (String): Ability score key (`"STR"`, `"DEX"`, `"CON"`, `"INT"`, `"WIS"`, `"CHA"`).
  * `"allows_shield"` (Boolean): Flag indicating if shields are allowed with unarmored defense.
  * `"count"` (Integer): Attack count multiplier (e.g. `2` for Flurry of Blows or Extra Attack).
  * `"base_dice"` / `"dice"` (String): Base damage dice formula (e.g. `"2d8"`, `"1d6"`).
  * `"damage_type"` (String): Valid damage type string from `VALID_DAMAGE_TYPES`.
  * `"ac_bonus"` / `"attack_bonus"` (Integer): Stat bonus numbers.
  * `"requires_armor"` / `"requires_ranged"` (Boolean): Equipment prerequisites.
  * `"pool"` (String): Resource formula descriptor (e.g. `"level_times_five"`).
  * `"creature_types"` (Array[String]): Target classification filter list (e.g. `["celestial", "fiend", "undead"]`).
  * `"die"` (String): Die type string (e.g. `"1d6"`).
  * `"range"` (Integer): Range in hexes or feet.
  * `"reaction"` (String): Reaction type string (e.g. `"uncanny_dodge"`).
  * `"fraction"` (Float): Fraction multiplier for slot recovery (e.g. `0.5`).
  * `"options"` (Array[String]): Configuration choices array (e.g. `["empowered_spell"]`).
  * `"item_id"` (String): Item registry identifier (e.g. `"ball_bearings"`).

---

## 4. Runtime Feature Resolution & GDScript Mapping Pipeline

The lifecycle of class features from disk JSON to runtime execution follows a strict 5-stage pipeline:

```
[1. Disk JSON] -> [2. DataLoader Curation & Sanitization] -> [3. Character Level-Up / Unlocking] -> [4. Resource Budget Tracking] -> [5. Combat / Event Execution]
```

### Stage 1: File Loading & Manifest Validation (`data_loader.gd`)
1. `DataLoader.load_all_data()` opens `res://data/core/classes/*.json`.
2. Reads JSON into raw Dictionaries and calls `_validate_content(data, "class", source)`.

### Stage 2: In-Memory Curation & Sanitization (`data_loader.gd`)
1. `_curate_feature_effects(data)` iterates through all `features_by_level`.
2. For each feature record, if `feature.id` exists in `CURATED_FEATURE_EFFECTS` AND `feature.effects` is empty, `DataLoader` merges the curated dictionary using `feature.merge(curated, true)`.
3. `_sanitize_class_features(data, source)` checks every feature for execution readiness:
   ```gdscript
   var has_effects: bool = feature.get("effects", []) is Array and not feature.get("effects", []).is_empty()
   var has_resolver := not str(feature.get("resolver", "")).is_empty()
   if not has_effects and not has_resolver:
       _validation_warnings.append("Rejected unsupported effectless feature '%s' in %s" % [feature.get("id", ""), source])
       continue
   ```
4. Features failing this test are rejected from the class record and logged in `_validation_warnings`.

### Stage 3: Character Initialization & Passive Application (`character.gd`)
1. `_unlock_features_for_level(lvl)` adds unlocked feature dictionaries to `character.features`.
2. If `feature.type == "passive"`:
   * Calls `_apply_passive_feature(feature)`: handles `extra_attack` and `modify_crit_range`.
   * Unarmored Defense (`barbarian_unarmored_defense`, `monk_unarmored_defense`) is evaluated dynamically inside `_recalculate_ac()`.
3. If `feature.type == "active"`:
   * Initializes `feature_uses[feature_id] = get_feature_max_uses(feature_id, feature)`.

### Stage 4: Usage Budgeting & Rest Recovery (`character.gd`)
1. `get_feature_max_uses()` handles constant `uses` or dynamic formulas (`"level*5"` for Paladin Lay on Hands).
2. Rest cadences (`short_rest()`, `long_rest()`) call `_restore_features_for_cadences()` to reset `feature_uses` according to `uses_per`.

### Stage 5: Active Action & Combat Trigger Execution
* **Active Abilities (`class_feature.gd`)**:
  * `ClassFeature.execute(character, feature, target)` checks `character.use_feature(feature_id)`.
  * If valid, loops through `feature.effects`:
    * Direct handlers in `ClassFeature`: `heal_self`, `grant_extra_action`.
    * Fallback handler: `EventResolver._apply_single_effect(character, effect)`.
* **Event Resolver (`event_resolver.gd`)**:
  * `_apply_single_effect` handles `damage`, `heal`, `temporary_hp`, `full_heal`, `give_item`, `spend_resource`, `restore_resource`, `grant_condition`, `apply_condition`, `remove_condition`, `stat_modifier`, `ac_bonus`, `speed_modifier`, `roll_modifier`, `pact_magic_recovery`, `innate_sorcery`, `reaction`, etc.
* **Combat Engine Triggers (`combat_state.gd`)**:
  * Hardcoded trigger checks evaluate feature presence via `attacker.has_feature(...)`:
    * `sneak_attack`: `_is_sneak_attack_valid()` checks finesse/ranged weapon, advantage or adjacent ally, and once-per-turn state.
    * `divine_smite`: Prompted on melee hit, consumes spell slot for radiant damage.
    * `reckless_attack`: Declared before attack roll to grant advantage on STR attacks.
    * `favored_foe`: Applied on hit to add bonus damage.
    * `uncanny_dodge`: Evaluated when hit to reduce incoming damage by half.

---

## 5. Effect Vocabulary Taxonomy (Supported vs. Unsupported)

### 5.1 Supported Effect Types Catalog

The engine currently supports **35 distinct effect types** across `ClassFeature.gd`, `EventResolver.gd`, `character.gd`, and `combat_state.gd`:

1. **Healing & Recovery**: `heal_self`, `heal`, `full_heal`, `temporary_hp`, `recover_spell_slots`, `pact_magic_recovery`, `lay_on_hands`.
2. **Combat Actions & Resource Control**: `grant_extra_action`, `spend_resource`, `restore_resource`, `give_item`, `cunning_action`, `step_of_the_wind`, `unarmed_attack`.
3. **Conditions & Buffs**: `grant_condition`, `apply_condition`, `remove_condition`, `remove_all_conditions`, `innate_sorcery`, `set_concentration`, `clear_concentration`.
4. **Stat & Roll Modifiers**: `stat_modifier`, `ac_bonus`, `speed_modifier`, `movement`, `reduce_speed`, `roll_modifier`, `vision_bonus`, `modify_crit_range`, `extra_attack`, `unarmored_defense`, `defense_style`, `archery`.
5. **Combat Triggers & Class Mechanics**: `sneak_attack`, `divine_smite`, `reckless_attack`, `favored_foe`, `bardic_inspiration`, `divine_sense`, `pact_magic`, `sorcery_points`, `metamagic`, `reaction`.
6. **Tactical Utility**: `teleport_random`, `reveal_map`, `area_selection`, `damage`, `gold`, `rest`, `start_combat`.

### 5.2 Unsupported / Missing Effect Vocabulary Patterns for D&D 5e

To support the remaining 157 quarantined class features across the 14 character classes, the engine requires extending its effect vocabulary in 6 distinct capability areas:

```
+-----------------------------------------------------------------------------------+
|                            MISSING VOCABULARY GAP MATRIX                          |
+------------------------------+----------------------------------------------------+
| Missing Category             | Typical D&D 5e Mechanics Affected                  |
+------------------------------+----------------------------------------------------+
| 1. Forced Movement / Grid    | Push, pull, knock prone, reposition (Open Hand,    |
|    Displacement              | Repelling Blast, Crusher, Tempest Cleric).         |
+------------------------------+----------------------------------------------------+
| 2. Saving Throw Advantage    | Advantage on saves, save proficiencies, rerolls    |
|    & Rerolls                 | (Danger Sense, Indomitable, Diamond Soul, Evasion).|
+------------------------------+----------------------------------------------------+
| 3. Dice Manipulation &       | Reroll 1s/2s, add ability mod to damage, max damage|
|    Damage Rerolls            | (Great Weapon Fighting, Elemental Affinity).       |
+------------------------------+----------------------------------------------------+
| 4. Contextual Reaction       | Trigger on ally attacked, incoming hit, spell cast |
|    Schemas                   | (Cutting Words, Shield, Counterspell, Sentinel).   |
+------------------------------+----------------------------------------------------+
| 5. Subsystem Pools &         | Form transformations, energy dice, maneuvers       |
|    Form Rosters              | (Druid Wild Shape, Mystic Psionics, Battle Master).|
+------------------------------+----------------------------------------------------+
| 6. Spatial Radius & Aura     | Aura of Protection, aura buffs, ally range check   |
|    Modifiers                 | (Paladin Auras, Bardic Auras, Marshal Auras).      |
+------------------------------+----------------------------------------------------+
```

1. **Forced Movement & Spatial Displacement**:
   * *Required Types*: `push_target`, `pull_target`, `knock_prone`, `swap_places`.
   * *Fields*: `distance_hexes`, `direction` (`"away"`, `"towards"`), `save_type` (`"STR"`, `"DEX"`).
   * *Features Affected*: Way of the Open Hand Technique, Repelling Blast, Tempest Cleric Thunderbolt Strike, Telekinetic.

2. **Saving Throw Grants, Advantage & Rerolls**:
   * *Required Types*: `save_advantage`, `grant_save_proficiency`, `reroll_save`, `evasion`.
   * *Fields*: `save_abilities` (`["DEX"]`, `["ALL"]`), `trigger` (`"on_failed_save"`).
   * *Features Affected*: Barbarian Danger Sense, Fighter Indomitable, Monk Diamond Soul, Rogue Evasion, Rogue Slippery Mind.

3. **Dice Manipulation & Damage Rerolls**:
   * *Required Types*: `reroll_damage_dice`, `add_ability_to_damage`, `maximize_damage_dice`.
   * *Fields*: `threshold` (`[1, 2]`), `ability` (`"CHA"`), `damage_type` (`"lightning"`).
   * *Features Affected*: Great Weapon Fighting Style, Draconic Sorcerer Elemental Affinity, Tempest Cleric Destructive Wrath.

4. **Contextual Reaction Schemas**:
   * *Required Types*: `reaction_trigger`, `defensive_flourish`, `interception`.
   * *Fields*: `trigger_event` (`"ally_attacked"`, `"incoming_hit"`, `"spell_cast"`), `reaction_action`.
   * *Features Affected*: Bard Cutting Words, Fighter/Paladin Protection/Interception Fighting Style, Wizard Shield/Counterspell.

5. **Subsystem Resource Pools & Roster Quarantines**:
   * *Required Types*: `wild_shape_transform`, `psionic_discipline_activate`, `maneuver_execute`, `channel_divinity_option`.
   * *Features Affected*: Druid Wild Shape, Mystic Psionics, Fighter Battle Master Maneuvers, Cleric/Paladin Channel Divinity options.

6. **Spatial Radius & Aura Buffs**:
   * *Required Types*: `aura_buff`, `ally_radius_grant`.
   * *Fields*: `radius_feet`, `granted_stat`, `granted_ability_mod`.
   * *Features Affected*: Paladin Aura of Protection, Aura of Devotion, Aura of Courage.

---

## 6. Guidance for Feature Curation Specs

When formulating proposed dictionary definitions for `CURATED_FEATURE_EFFECTS` in `data_loader.gd`:

1. **Tier 1 (Immediate Candidates)**:
   Must strictly use existing supported effect types (`stat_modifier`, `grant_condition`, `heal_self`, `extra_attack`, `grant_extra_action`, `recover_spell_slots`, `give_item`, `reaction`, etc.).
   *Example Spec*:
   ```gdscript
   "fighter_second_wind": {"effects": [{"type": "heal_self", "value": "1d10+level"}], "uses_per": "rest"},
   ```

2. **Tier 2 (Vocabulary Extension Candidates)**:
   Must specify both the proposed dictionary structure AND the exact new effect type required (e.g. `save_advantage`, `push_target`, `reroll_damage_dice`).
   *Example Spec*:
   ```gdscript
   "barbarian_danger_sense": {"type": "passive", "effects": [{"type": "save_advantage", "abilities": ["DEX"], "condition": "visible_effects"}]},
   ```

3. **Tiers 3 & 4 (Subsystem-Quarantined & Narrative Ribbons)**:
   * Tier 3 features should remain un-curated (or documented with their blocking subsystem dependency/ADR).
   * Tier 4 features should remain intentionally quarantined or tagged with `"type": "narrative_ribbon"` so they do not populate combat UI menus.

---

## 7. Verification Method

To verify the integrity and syntax of `src/autoload/data_loader.gd` and the feature curation pipeline:

1. **Python Feature Matrix & Validation Suite**:
   Run from repository root:
   ```powershell
   python src/generate_feature_matrix.py
   python src/validate_and_test.py
   ```
   Both commands must exit with code `0`.

2. **DataLoader Inspection**:
   Inspect `src/autoload/data_loader.gd` using `view_file` to confirm `CURATED_FEATURE_EFFECTS` syntax matches GDScript Dictionary formatting.
