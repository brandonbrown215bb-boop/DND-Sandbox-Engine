# Quarantined Class Features Remediation Plan & Taxonomy Specification

**Document Version**: 1.0.0  
**Author**: Worker 1 (teamwork_preview_worker)  
**Date**: 2026-08-10  
**Status**: Draft - verification gate failed  
**Target File**: `docs/quarantined_features_remediation_plan.md`

---

> Verification note (2026-08-11): this is a planning artifact, not current
> architecture authority. The production matrix mirror now agrees with
> `DataLoader` at 36 mechanics-backed and 157 quarantined records, but the
> bundled taxonomy validators still report incomplete table/snippet coverage.
> See `.agents/orchestrator/GATE_STATUS.md` before using proposed entries.

## 1. Executive Summary & Audit Metrics

This document proposes an audit and remediation specification for the **157
quarantined (effectless) class feature records** across 14 character classes in
`data/core/classes/*.json`. Its completeness claims remain unaccepted until the
failed validation findings are reconciled.

In the engine architecture, raw JSON class feature records carry descriptions, levels, and usages, but rely on runtime curation via `DataLoader.CURATED_FEATURE_EFFECTS` (`src/autoload/data_loader.gd`). Features lacking an `effects` array or engine `resolver` script are sanitized out at runtime to prevent un-backed abilities from polluting character state and combat action menus.

### 1.1 Class Feature Inventory Summary

 across the 14 surveyed classes, there are **193 total feature records**:
- **Mechanics-Backed (Curated)**: **36 records**
- **Quarantined / Effectless**: **157 records**

```
+-----------------------------------------------------------------------------------------+
|                               157 QUARANTINED FEATURE AUDIT                             |
+-------------------+-------------------+-------------------+-------------------+---------+
| Character Class   | Tier 1: Immediate | Tier 2: Vocab Ext | Tier 3: Subsystem | Tier 4: Ribbon | Total |
+-------------------+-------------------+-------------------+-------------------+---------+
| Artificer         |         1         |         0         |         8         |    3    |   12  |
| Barbarian         |         2         |         2         |         2         |    1    |    7  |
| Bard              |         5         |         1         |         3         |    3    |   12  |
| Cleric            |         5         |         2         |         7         |    1    |   15  |
| Druid             |         4         |         0         |         7         |    2    |   13  |
| Fighter           |         3         |         2         |         2         |    1    |    8  |
| Monk              |         7         |         5         |         4         |    1    |   17  |
| Mystic            |         1         |         1         |         6         |    1    |    9  |
| Paladin           |         4         |         1         |         6         |    1    |   12  |
| Ranger            |         2         |         1         |         5         |    6    |   14  |
| Rogue             |         3         |         4         |         2         |    2    |   11  |
| Sorcerer          |         3         |         1         |         6         |    1    |   11  |
| Warlock           |         1         |         0         |         6         |    1    |    8  |
| Wizard            |         1         |         0         |         3         |    4    |    8  |
+-------------------+-------------------+-------------------+-------------------+---------+
| TOTAL             |        42         |        20         |        67         |   28    |  157  |
+-------------------+-------------------+-------------------+-------------------+---------+
```

---

## 2. Taxonomy Tiers & Remediation Framework

Every quarantined feature is assigned to one of four distinct tiers based on engine readiness, rules requirements, and UI placement needs:

1. **Tier 1: Immediate Curation Candidates (42 Features)**  
   Features whose 5e mechanics map cleanly to the engine's existing effect vocabulary (`stat_modifier`, `grant_condition`, `heal_self`, `speed_modifier`, `give_item`, `recover_spell_slots`, `asi_choice`, etc.). Ready for immediate inclusion into `DataLoader.CURATED_FEATURE_EFFECTS`.

2. **Tier 2: Vocabulary Extension Candidates (20 Features)**  
   Features requiring small additions to the engine's core effect vocabulary or event resolvers (e.g. forced displacement, saving throw advantage/rerolls, dice manipulation, contextual reactions, weapon mastery properties).

3. **Tier 3: Subsystem-Quarantined Features (67 Features)**  
   Features dependent on major un-implemented subsystems (e.g., Mystic Psionics, Druid Wild Shape form rosters per ADR-0002, Artificer Infusions, Fighter Battle Master maneuvers, Subclass choice selection frameworks). Must remain quarantined until their specific ADRs/subsystems are implemented.

4. **Tier 4: Narrative / Non-Combat Ribbons (28 Features)**  
   Fluff, language, or out-of-combat utility features (e.g. Thieves' Cant, Druidic, Scholar, Ritual Adept). Must be tagged with `"type": "narrative_ribbon"` so they remain quarantined from combat action UI menus.

---

## 3. Engine Effect Vocabulary Extensions (6 Core Areas)

To enable Tier 2 features (and future subsystem integrations), the engine's effect vocabulary (`EventResolver.gd`, `ClassFeature.gd`, `combat_state.gd`) must be extended across 6 capability areas:

### Extension 1: Forced Movement & Spatial Displacement
- **Proposed Effect Types**: `push_target`, `pull_target`, `knock_prone`, `swap_places`.
- **Payload Schema**:
  ```gdscript
  {"type": "push_target", "distance_hexes": 2, "direction": "away", "save_type": "STR", "save_dc_stat": "STR"}
  ```
- **Engine Support Required**: Hex grid boundary and path checking to prevent pushing into occupied or impassable tiles.
- **Features Enabled**: Way of the Open Hand Technique, Repelling Blast, Weapon Mastery (Push/Topple).

### Extension 2: Saving Throw Grants, Advantage & Rerolls
- **Proposed Effect Types**: `save_advantage`, `grant_save_proficiency`, `reroll_save`, `evasion`.
- **Payload Schema**:
  ```gdscript
  {"type": "save_advantage", "abilities": ["DEX"], "condition": "effects_you_can_see"}
  ```
- **Engine Support Required**: Intercepting `combat_state.gd` saving throw calculations to check actor features for matching ability advantage/proficiencies.
- **Features Enabled**: Barbarian Danger Sense, Fighter Indomitable, Monk Diamond Soul, Rogue Evasion.

### Extension 3: Dice Manipulation & Damage Rerolls
- **Proposed Effect Types**: `reroll_damage_dice`, `add_ability_to_damage`, `maximize_damage_dice`.
- **Payload Schema**:
  ```gdscript
  {"type": "reroll_damage_dice", "threshold": [1, 2], "weapon_types": ["two_handed", "versatile"]}
  ```
- **Engine Support Required**: Updating `DiceParser` or damage evaluation in `combat_state.gd` to apply reroll rules on matching dice results.
- **Features Enabled**: Great Weapon Fighting Style, Draconic Sorcerer Elemental Affinity, Tempest Cleric Destructive Wrath.

### Extension 4: Contextual Reaction Schemas
- **Proposed Effect Types**: `reaction_trigger`, `defensive_flourish`, `interception`, `deflect_missiles`, `deflect_attacks`.
- **Payload Schema**:
  ```gdscript
  {"type": "reaction_damage_reduction", "trigger": "ranged_weapon_hit", "reduction_formula": "1d10+DEX+monk_level"}
  ```
- **Engine Support Required**: Reaction phase prompts in `combat_state.gd` when specific triggers fire (ally attacked, incoming hit, ranged attack).
- **Features Enabled**: Monk Deflect Missiles / Deflect Attacks, Bard Cutting Words, Protection/Interception Fighting Styles.

### Extension 5: Subsystem Resource Pools & Roster Quarantines
- **Proposed Effect Types**: `wild_shape_transform`, `psionic_discipline_activate`, `maneuver_execute`, `infusion_apply`.
- **Payload Schema**:
  ```gdscript
  {"type": "wild_shape_transform", "form_id": "wolf", "temp_hp_formula": "2d8+2", "duration_rounds": 10}
  ```
- **Engine Support Required**: Subsystem state managers and temporary HP absorption buffers (ADR-0002).
- **Features Enabled**: Druid Wild Shape, Mystic Psionics, Fighter Battle Master Maneuvers, Artificer Infusions.

### Extension 6: Spatial Radius & Aura Buffs
- **Proposed Effect Types**: `aura_buff`, `ally_radius_grant`.
- **Payload Schema**:
  ```gdscript
  {"type": "aura_buff", "radius_feet": 10, "granted_stat": "all_saves", "amount_formula": "CHA"}
  ```
- **Engine Support Required**: Hex distance check from aura origin to party members at start of turn or during roll resolution.
- **Features Enabled**: Paladin Aura of Protection, Aura of Devotion, Aura of Courage.

---

## 4. Complete 157-Feature Taxonomy & Curation Specification

Below is the complete 100% catalog of all 157 quarantined features, organized by character class.

---

### 4.1 Artificer (12 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `artificer_spellcasting` | 1 | Tier 3 | Channel magical energy through objects to cast spells. | **Subsystem-Quarantined**: Requires Artificer spell slot table and spell preparation framework. |
| `artificer_magical_tinkering` | 1 | Tier 4 | Imbue mundane objects with minor visual/auditory effects. | `"type": "narrative_ribbon"` (Non-combat fluff, excluded from combat UI). |
| `artificer_optional_rule:_firearm_proficiency` | 1 | Tier 4 | Optional proficiency with firearm weapons. | `"type": "narrative_ribbon"` (Character option ribbon). |
| `artificer_replicate_magic_item` | 2 | Tier 3 | Replicate specific magic items from infusion list. | **Subsystem-Quarantined**: Blocked by Infusions subsystem. |
| `artificer_infuse_item` | 2 | Tier 3 | Imbue mundane items with magic infusions. | **Subsystem-Quarantined**: Blocked by Infusions subsystem. |
| `artificer_infusions_known` | 2 | Tier 3 | Track number of infusions known (4 at lvl 2). | **Subsystem-Quarantined**: Blocked by Infusions subsystem. |
| `artificer_artificer_subclass` | 3 | Tier 3 | Choose Artificer specialist subclass. | **Subsystem-Quarantined**: Blocked by Subclass selection system. |
| `artificer_artificer_specialist` | 3 | Tier 3 | Specialist archetype choice. | **Subsystem-Quarantined**: Blocked by Subclass selection system. |
| `artificer_the_right_tool_for_the_job` | 3 | Tier 4 | Produce any artisan tool in 1 hour. | `"type": "narrative_ribbon"` (Non-combat utility). |
| `artificer_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `artificer_subclass_feature` | 5 | Tier 3 | Specialist subclass feature placeholder. | **Subsystem-Quarantined**: Blocked by Subclass system. |
| `artificer_artificer_specialist_feature` | 5 | Tier 3 | Specialist feature grant at level 5. | **Subsystem-Quarantined**: Blocked by Subclass system. |

#### Proposed GDScript Snippet for Artificer Tier 1:
```gdscript
"artificer_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
}
```

---

### 4.2 Barbarian (7 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `barbarian_weapon_mastery` | 1 | Tier 2 | Use weapon mastery properties of two weapons. | See GDScript Snippet below (Tier 2). |
| `barbarian_danger_sense` | 2 | Tier 2 | Advantage on DEX saves against visible effects. | See GDScript Snippet below (Tier 2). |
| `barbarian_primal_knowledge` | 3 | Tier 4 | Extra skill proficiency / use rage for checks. | `"type": "narrative_ribbon"` (Skill ribbon). |
| `barbarian_primal_path` | 3 | Tier 3 | Choose barbarian primal path. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `barbarian_barbarian_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `barbarian_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `barbarian_fast_movement` | 5 | Tier 1 | Speed increases by 10 ft when unarmored/medium armor. | See GDScript Snippet below. |

#### Proposed GDScript Snippets for Barbarian Tiers 1 & 2:
```gdscript
"barbarian_fast_movement": {
    "type": "passive",
    "effects": [{"type": "speed_modifier", "key": "speed", "amount": 10, "requires_no_heavy_armor": true}]
},
"barbarian_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"barbarian_weapon_mastery": {
    "type": "passive",
    "effects": [{"type": "weapon_mastery", "count": 2, "properties": ["push", "cleave", "graze", "topple"]}]
},
"barbarian_danger_sense": {
    "type": "passive",
    "effects": [{"type": "save_advantage", "abilities": ["DEX"], "condition": "effects_you_can_see"}]
}
```

---

### 4.3 Bard (12 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `bard_spellcasting` | 1 | Tier 3 | Cast bard spells via music/words. | **Subsystem-Quarantined**: Blocked by Bard spellcasting roster. |
| `bard_jack_of_all_trades` | 2 | Tier 2 | Add half prof bonus to non-proficient checks. | See GDScript Snippet below (Tier 2). |
| `bard_magical_inspiration` | 2 | Tier 1 | Add BI die to spell damage or healing roll. | See GDScript Snippet below. |
| `bard_song_of_rest_(d6)` | 2 | Tier 1 | Allies regain extra 1d6 HP on short rest. | See GDScript Snippet below. |
| `bard_expertise` | 2 | Tier 4 | Double prof bonus for two chosen skills. | `"type": "narrative_ribbon"` (Skill ribbon). |
| `bard_bard_college` | 3 | Tier 3 | Choose bard college subclass. | **Subsystem-Quarantined**: Blocked by Subclass system. |
| `bard_expertise` | 3 | Tier 4 | Double prof bonus for two more skills. | `"type": "narrative_ribbon"` (Skill ribbon). |
| `bard_bard_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass system. |
| `bard_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `bard_bardic_versatility` | 4 | Tier 4 | Swap skill/cantrip on gaining ASI level. | `"type": "narrative_ribbon"` (Retraining ribbon). |
| `bard_bardic_inspiration_(d8)` | 5 | Tier 1 | BI die upgrades from 1d6 to 1d8. | See GDScript Snippet below. |
| `bard_font_of_inspiration` | 5 | Tier 1 | Regain BI uses on Short or Long Rest. | See GDScript Snippet below. |

#### Proposed GDScript Snippets for Bard Tiers 1 & 2:
```gdscript
"bard_magical_inspiration": {
    "type": "passive",
    "effects": [{"type": "bardic_inspiration_spell_bonus", "description": "Add BI die to spell damage/heal"}]
},
"bard_song_of_rest_(d6)": {
    "type": "passive",
    "effects": [{"type": "short_rest_heal_bonus", "value": "1d6"}]
},
"bard_bardic_inspiration_(d8)": {
    "type": "passive",
    "effects": [{"type": "bardic_inspiration_die_upgrade", "die": "1d8"}]
},
"bard_font_of_inspiration": {
    "type": "passive",
    "effects": [{"type": "feature_cadence_override", "target_feature": "bard_bardic_inspiration", "uses_per": "short_rest"}]
},
"bard_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"bard_jack_of_all_trades": {
    "type": "passive",
    "effects": [{"type": "roll_modifier", "target": "ability_checks", "requires_non_proficient": true, "amount_formula": "floor(prof/2)"}]
}
```

---

### 4.4 Cleric (15 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `cleric_divine_domain` | 1 | Tier 3 | Choose divine domain subclass. | **Subsystem-Quarantined**: Blocked by Divine Domain system. |
| `cleric_spellcasting` | 1 | Tier 3 | Cast cleric divine spells. | **Subsystem-Quarantined**: Blocked by Cleric spell roster. |
| `cleric_divine_order` | 1 | Tier 3 | Dedicated role: Protector vs Thaumaturge. | **Subsystem-Quarantined**: Order selection framework. |
| `cleric_protector` | 1 | Tier 1 | Proficiency with martial weapons and heavy armor. | See GDScript Snippet below. |
| `cleric_thaumaturge` | 1 | Tier 1 | Bonus cantrip + WIS bonus to Religion checks. | See GDScript Snippet below. |
| `cleric_channel_divinity` | 2 | Tier 3 | Fuel divine energy effects. | **Subsystem-Quarantined**: Channel Divinity resource pool. |
| `cleric_channel_divinity:_turn_undead` | 2 | Tier 1 | Censure undead within 30ft, forcing WIS save. | See GDScript Snippet below. |
| `cleric_divine_domain_feature` | 2 | Tier 3 | Subclass feature grant at lvl 2. | **Subsystem-Quarantined**: Blocked by Subclass system. |
| `cleric_divine_spark` | 2 | Tier 1 | 30ft target heal or 1d8+WIS radiant/necrotic damage. | See GDScript Snippet below. |
| `cleric_turn_undead` | 2 | Tier 1 | Present holy symbol to turn undead for 1 minute. | See GDScript Snippet below. |
| `cleric_cleric_subclass` | 3 | Tier 3 | Cleric subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass system. |
| `cleric_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `cleric_cantrip_versatility` | 4 | Tier 4 | Swap cantrips on gaining ASI level. | `"type": "narrative_ribbon"` (Retraining ribbon). |
| `cleric_destroy_undead_(cr_1/2)` | 5 | Tier 2 | Turned undead of CR 1/2 or lower destroyed. | See GDScript Snippet below (Tier 2). |
| `cleric_sear_undead` | 5 | Tier 2 | Turn undead deals radiant damage equal to WIS*d8. | See GDScript Snippet below (Tier 2). |

#### Proposed GDScript Snippets for Cleric Tiers 1 & 2:
```gdscript
"cleric_protector": {
    "type": "passive",
    "effects": [{"type": "grant_proficiency", "weapon_proficiencies": ["martial"], "armor_proficiencies": ["heavy"]}]
},
"cleric_thaumaturge": {
    "type": "passive",
    "effects": [
        {"type": "grant_cantrip", "spell_list": "cleric", "count": 1},
        {"type": "skill_bonus", "skill": "religion", "amount": "WIS"}
    ]
},
"cleric_divine_spark": {
    "type": "active",
    "action_cost": "action",
    "uses": 1,
    "uses_per": "short_rest",
    "effects": [{
        "type": "divine_spark",
        "range": 30,
        "dice": "1d8+WIS",
        "options": ["heal", "damage"],
        "damage_types": ["radiant", "necrotic"]
    }]
},
"cleric_turn_undead": {
    "type": "active",
    "action_cost": "action",
    "uses": 1,
    "uses_per": "short_rest",
    "effects": [{
        "type": "turn_undead",
        "range": 30,
        "save_type": "WIS",
        "target_type": "undead",
        "condition": "turned",
        "duration": 10
    }]
},
"cleric_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"cleric_destroy_undead_(cr_1/2)": {
    "type": "passive",
    "effects": [{"type": "turned_undead_destruction", "max_cr": 0.5}]
},
"cleric_sear_undead": {
    "type": "passive",
    "effects": [{"type": "turn_undead_damage", "dice": "WIS_d8", "damage_type": "radiant"}]
}
```

---

### 4.5 Druid (13 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `druid_druidic` | 1 | Tier 4 | Secret language of druids. | `"type": "narrative_ribbon"` (Language ribbon). |
| `druid_spellcasting` | 1 | Tier 3 | Cast druid primal spells. | **Subsystem-Quarantined**: Blocked by Druid spell roster. |
| `druid_magician` | 1 | Tier 1 | Extra cantrip + bonus to Nature checks. | See GDScript Snippet below. |
| `druid_primal_order` | 1 | Tier 3 | Primal order role selection. | **Subsystem-Quarantined**: Order selection framework. |
| `druid_warden` | 1 | Tier 1 | Martial weapons + medium armor proficiencies. | See GDScript Snippet below. |
| `druid_druid_circle` | 2 | Tier 3 | Choose druid circle subclass. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `druid_wild_companion` | 2 | Tier 3 | Summon animal spirit familiar. | **Subsystem-Quarantined**: Blocked by Companion subsystem. |
| `druid_wild_shape` | 2 | Tier 3 | Transform into beast shape (ADR-0002 wolf contract). | **Subsystem-Quarantined**: Blocked by Wild Shape subsystem per ADR-0002. |
| `druid_druid_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `druid_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `druid_cantrip_versatility` | 4 | Tier 4 | Swap cantrip on gaining ASI level. | `"type": "narrative_ribbon"` (Retraining ribbon). |
| `druid_wild_shape_improvement` | 4 | Tier 3 | Swimming/flying beast shapes unlocked. | **Subsystem-Quarantined**: Blocked by Wild Shape form table per ADR-0002. |
| `druid_wild_resurgence` | 5 | Tier 1 | Convert spell slot to regain 1 Wild Shape use. | See GDScript Snippet below. |

#### Proposed GDScript Snippets for Druid Tier 1:
```gdscript
"druid_magician": {
    "type": "passive",
    "effects": [
        {"type": "grant_cantrip", "spell_list": "druid", "count": 1},
        {"type": "skill_bonus", "skill": "nature", "amount": "WIS"}
    ]
},
"druid_warden": {
    "type": "passive",
    "effects": [{"type": "grant_proficiency", "weapon_proficiencies": ["martial"], "armor_proficiencies": ["medium"]}]
},
"druid_wild_resurgence": {
    "type": "active",
    "action_cost": "action",
    "uses": 1,
    "uses_per": "turn",
    "effects": [{"type": "resource_conversion", "source": "spell_slot", "target": "wild_shape", "amount": 1}]
},
"druid_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
}
```

---

### 4.6 Fighter (8 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `fighter_fighting_style` | 1 | Tier 1 | Choose combat specialization option. | See GDScript Snippet below (Defense/Archery in T1; GWF/Protection in T2). |
| `fighter_weapon_mastery` | 1 | Tier 2 | Use weapon mastery properties of 3 weapons. | See GDScript Snippet below (Tier 2). |
| `fighter_tactical_mind` | 2 | Tier 2 | Spend Second Wind charge to add 1d10 to failed check. | See GDScript Snippet below (Tier 2). |
| `fighter_martial_archetype` | 3 | Tier 3 | Choose martial archetype subclass. | **Subsystem-Quarantined**: Blocked by Subclass / Maneuver roster system. |
| `fighter_fighter_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `fighter_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `fighter_martial_versatility` | 4 | Tier 4 | Swap fighting style/mastery on ASI level. | `"type": "narrative_ribbon"` (Retraining ribbon). |
| `fighter_tactical_shift` | 5 | Tier 1 | Move up to half speed without OA when using Second Wind. | See GDScript Snippet below. |

#### Proposed GDScript Snippets for Fighter Tiers 1 & 2:
```gdscript
"fighter_fighting_style": {
    "type": "passive",
    "effects": [{"type": "fighting_style_choice", "options": ["defense", "archery", "great_weapon_fighting", "protection", "two_weapon_fighting"]}]
},
"fighter_tactical_shift": {
    "type": "passive",
    "effects": [{"type": "second_wind_trigger", "grant_movement": "half_speed", "prevent_opportunity_attacks": true}]
},
"fighter_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"fighter_weapon_mastery": {
    "type": "passive",
    "effects": [{"type": "weapon_mastery", "count": 3, "properties": ["push", "cleave", "graze", "topple", "vex"]}]
},
"fighter_tactical_mind": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "short_rest",
    "effects": [{
        "type": "check_bonus_die",
        "trigger": "failed_ability_check",
        "die": "1d10",
        "expends_resource": "second_wind",
        "refund_on_failure": true
    }]
}
```

---

### 4.7 Monk (17 Quarantined Features)

> **Note on Mechanics-Backed Features**: Out of 24 total feature records in `data/core/classes/monk.json`, **7 features** are already mechanics-backed and active in `DataLoader.gd` (`monk_martial_arts`, `monk_unarmored_defense`, `monk_bonus_unarmed_strike`, `monk_patient_defense`, `monk_step_of_the_wind`, `monk_flurry_of_blows`, `monk_extra_attack`). The **17 quarantined features** requiring remediation are cataloged in the taxonomy table below.

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `monk_dexterous_attacks` | 1 | Tier 1 | Use DEX instead of STR for unarmed/monk weapons. | See GDScript Snippet below. |
| `monk_martial_arts_die` | 1 | Tier 1 | Roll 1d6 for unarmed strike damage. | See GDScript Snippet below. |
| `monk_dedicated_weapon` | 2 | Tier 4 | Designate chosen weapon as monk weapon. | `"type": "narrative_ribbon"` (Equipment preference ribbon). |
| `monk_ki` | 2 | Tier 3 | Harness ki energy pool. | **Subsystem-Quarantined**: Blocked by Ki / Focus point pool subsystem. |
| `monk_unarmored_movement` | 2 | Tier 1 | Speed +10 ft when unarmored and without shield. | See GDScript Snippet below. |
| `monk_monk's_focus` | 2 | Tier 3 | Focus points resource framework. | **Subsystem-Quarantined**: Blocked by Focus points pool. |
| `monk_uncanny_metabolism` | 2 | Tier 1 | Regain focus + heal Martial Arts die + level on initiative. | See GDScript Snippet below. |
| `monk_deflect_missiles` | 3 | Tier 2 | Reaction reduce ranged weapon damage by 1d10+DEX+lvl. | See GDScript Snippet below (Tier 2). |
| `monk_ki-fueled_attack` | 3 | Tier 1 | Bonus action attack after spending Ki on main action. | See GDScript Snippet below. |
| `monk_monastic_tradition` | 3 | Tier 3 | Choose monastic tradition subclass. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `monk_deflect_attacks` | 3 | Tier 2 | Reaction reduce bludgeoning/piercing/slashing damage. | See GDScript Snippet below (Tier 2). |
| `monk_monk_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `monk_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `monk_quickened_healing` | 4 | Tier 1 | Spend 2 ki to heal Martial Arts die + prof bonus. | See GDScript Snippet below. |
| `monk_slow_fall` | 4 | Tier 2 | Reaction reduce fall damage by 5*monk_level. | See GDScript Snippet below (Tier 2). |
| `monk_focused_aim` | 5 | Tier 2 | Spend 1-3 ki on missed attack to add +2 per ki to roll. | See GDScript Snippet below (Tier 2). |
| `monk_stunning_strike` | 5 | Tier 2 | Spend 1 ki on melee hit to force CON save or stun. | See GDScript Snippet below (Tier 2). |

#### Proposed GDScript Snippets for Monk Tiers 1 & 2:
```gdscript
"monk_dexterous_attacks": {
    "type": "passive",
    "effects": [{"type": "stat_substitution", "attack_types": ["unarmed", "monk_weapon"], "replace_stat": "STR", "with_stat": "DEX"}]
},
"monk_martial_arts_die": {
    "type": "passive",
    "effects": [{"type": "unarmed_die_override", "die": "1d6"}]
},
"monk_unarmored_movement": {
    "type": "passive",
    "effects": [{"type": "speed_modifier", "key": "speed", "amount": 10, "requires_unarmored": true}]
},
"monk_uncanny_metabolism": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "long_rest",
    "effects": [
        {"type": "restore_resource", "resource": "focus_points", "amount": "max"},
        {"type": "heal_self", "value": "1d6+level"}
    ]
},
"monk_ki-fueled_attack": {
    "type": "passive",
    "effects": [{"type": "conditional_bonus_attack", "trigger": "spent_ki_on_action", "action_cost": "bonus_action"}]
},
"monk_quickened_healing": {
    "type": "active",
    "action_cost": "action",
    "uses": 1,
    "uses_per": "turn",
    "effects": [
        {"type": "spend_resource", "resource": "ki", "amount": 2},
        {"type": "heal_self", "value": "1d6+prof"}
    ]
},
"monk_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"monk_deflect_missiles": {
    "type": "active",
    "action_cost": "reaction",
    "uses": 1,
    "uses_per": "turn",
    "effects": [{
        "type": "reaction_damage_reduction",
        "trigger": "ranged_weapon_hit",
        "reduction_formula": "1d10+DEX+monk_level",
        "on_zero_hp_counter": "catch_and_redirect"
    }]
},
"monk_deflect_attacks": {
    "type": "active",
    "action_cost": "reaction",
    "uses": 1,
    "uses_per": "turn",
    "effects": [{
        "type": "reaction_damage_reduction",
        "trigger": "incoming_physical_hit",
        "reduction_formula": "1d10+DEX+monk_level"
    }]
},
"monk_slow_fall": {
    "type": "active",
    "action_cost": "reaction",
    "uses": 1,
    "uses_per": "turn",
    "effects": [{"type": "reaction_fall_reduction", "reduction_formula": "5*monk_level"}]
},
"monk_focused_aim": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "turn",
    "effects": [{
        "type": "attack_roll_bonus",
        "trigger": "missed_attack_roll",
        "cost_per_bonus": {"resource": "ki", "cost": 1, "bonus": 2},
        "max_ki_spend": 3
    }]
},
"monk_stunning_strike": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "turn",
    "effects": [{
        "type": "on_hit_trigger",
        "spend_resource": {"resource": "ki", "amount": 1},
        "save_type": "CON",
        "on_failure": {"type": "grant_condition", "condition": "stunned", "duration": 1}
    }]
}
```

---

### 4.8 Mystic (9 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `mystic_mystic_order` | 1 | Tier 3 | Choose Mystic order subclass. | **Subsystem-Quarantined**: Blocked by Mystic Order framework. |
| `mystic_psionic_disciplines_and_talents` | 1 | Tier 3 | Master psionic talents and disciplines. | **Subsystem-Quarantined**: Blocked by Psionics system. |
| `mystic_psionics` | 1 | Tier 3 | Core psionic energy pool system. | **Subsystem-Quarantined**: Blocked by Psionics system. |
| `mystic_using_a_discipline` | 1 | Tier 3 | Execute psionic discipline modes. | **Subsystem-Quarantined**: Blocked by Discipline execution system. |
| `mystic_mystical_recovery` | 2 | Tier 3 | Convert psi points to HP vigor. | **Subsystem-Quarantined**: Blocked by Psi energy conversion system. |
| `mystic_telepathy` | 2 | Tier 4 | Telepathically speak to creatures within 120 ft. | `"type": "narrative_ribbon"` (Communication ribbon). |
| `mystic_mystic_order_feature` | 3 | Tier 3 | Order feature grant at lvl 3. | **Subsystem-Quarantined**: Blocked by Mystic Order framework. |
| `mystic_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `mystic_strength_of_mind` | 4 | Tier 2 | Swap WIS save proficiency for another score save prof. | See GDScript Snippet below (Tier 2). |

#### Proposed GDScript Snippets for Mystic Tiers 1 & 2:
```gdscript
"mystic_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"mystic_strength_of_mind": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "short_rest",
    "effects": [{
        "type": "save_proficiency_swap",
        "base_save": "WIS",
        "replacement_choices": ["STR", "DEX", "CON", "INT", "CHA"]
    }]
}
```

---

### 4.9 Paladin (12 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `paladin_spellcasting` (L1) | 1 | Tier 3 | Cast divine spells via meditation. | **Subsystem-Quarantined**: Blocked by Paladin spell roster. |
| `paladin_weapon_mastery` | 1 | Tier 2 | Weapon mastery properties for two weapons. | See GDScript Snippet below (Tier 2). |
| `paladin_spellcasting` (L2) | 2 | Tier 3 | Paladin spellcasting level 2 entry. | **Subsystem-Quarantined**: Blocked by Paladin spell roster. |
| `paladin_paladin's_smite` | 2 | Tier 1 | Always prepare Divine Smite + 1 free cast per long rest. | See GDScript Snippet below. |
| `paladin_channel_divinity` | 3 | Tier 3 | Channel divine energy for sacred oath. | **Subsystem-Quarantined**: Blocked by Channel Divinity pool. |
| `paladin_channel_divinity:_harness_divine_power` | 3 | Tier 1 | Expend Channel Divinity to recover spell slot. | See GDScript Snippet below. |
| `paladin_divine_health` | 3 | Tier 1 | Immunity to disease condition. | See GDScript Snippet below. |
| `paladin_sacred_oath` | 3 | Tier 3 | Choose sacred oath subclass. | **Subsystem-Quarantined**: Blocked by Sacred Oath system. |
| `paladin_paladin_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `paladin_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `paladin_martial_versatility` | 4 | Tier 4 | Swap fighting style/mastery on ASI level. | `"type": "narrative_ribbon"` (Retraining ribbon). |
| `paladin_faithful_steed` | 5 | Tier 3 | Prepare/cast Find Steed for mount summon. | **Subsystem-Quarantined**: Blocked by Mount / Summoning subsystem. |

#### Proposed GDScript Snippets for Paladin Tiers 1 & 2:
```gdscript
"paladin_paladin's_smite": {
    "type": "passive",
    "effects": [
        {"type": "always_prepared_spell", "spell_id": "divine_smite"},
        {"type": "free_spell_cast", "spell_id": "divine_smite", "uses": 1, "uses_per": "long_rest"}
    ]
},
"paladin_channel_divinity:_harness_divine_power": {
    "type": "active",
    "action_cost": "bonus_action",
    "uses": 1,
    "uses_per": "short_rest",
    "effects": [{"type": "recover_spell_slots", "max_slot_level": "ceil(prof/2)"}]
},
"paladin_divine_health": {
    "type": "passive",
    "effects": [{"type": "grant_condition_immunity", "condition": "disease"}]
},
"paladin_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"paladin_weapon_mastery": {
    "type": "passive",
    "effects": [{"type": "weapon_mastery", "count": 2, "properties": ["push", "cleave", "graze", "topple"]}]
}
```

---

### 4.10 Ranger (14 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `ranger_deft_explorer` (L1) | 1 | Tier 4 | Canny skill expertise + language grants. | `"type": "narrative_ribbon"` (Skill ribbon). |
| `ranger_favored_enemy` | 1 | Tier 4 | Advantage on tracking/survival checks vs favored enemy. | `"type": "narrative_ribbon"` (Knowledge ribbon). |
| `ranger_natural_explorer` | 1 | Tier 4 | Travel benefits in favored terrain. | `"type": "narrative_ribbon"` (Exploration ribbon). |
| `ranger_spellcasting` (L1) | 1 | Tier 3 | Cast nature spells. | **Subsystem-Quarantined**: Blocked by Ranger spell roster. |
| `ranger_weapon_mastery` | 1 | Tier 2 | Weapon mastery properties for two weapons. | See GDScript Snippet below (Tier 2). |
| `ranger_spellcasting` (L2) | 2 | Tier 3 | Ranger spellcasting level 2 entry. | **Subsystem-Quarantined**: Blocked by Ranger spell roster. |
| `ranger_spellcasting_focus` | 2 | Tier 4 | Use druidic focus as spellcasting focus. | `"type": "narrative_ribbon"` (Equipment ribbon). |
| `ranger_deft_explorer` (L2) | 2 | Tier 1 | Roving: Speed +10 ft + climb/swim speed. | See GDScript Snippet below. |
| `ranger_primal_awareness` | 3 | Tier 3 | Bonus spell roster grants (Speak with Animals, etc.). | **Subsystem-Quarantined**: Blocked by Spell roster grants. |
| `ranger_primeval_awareness` | 3 | Tier 4 | Spend spell slot to sense aberrations/celestials 1 mi. | `"type": "narrative_ribbon"` (Sense ribbon). |
| `ranger_ranger_archetype` | 3 | Tier 3 | Choose ranger archetype subclass. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `ranger_ranger_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `ranger_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `ranger_martial_versatility` | 4 | Tier 4 | Swap fighting style/mastery on ASI level. | `"type": "narrative_ribbon"` (Retraining ribbon). |

#### Proposed GDScript Snippets for Ranger Tiers 1 & 2:
```gdscript
"ranger_deft_explorer_roving": {
    "type": "passive",
    "effects": [
        {"type": "speed_modifier", "key": "speed", "amount": 10, "requires_no_heavy_armor": true},
        {"type": "grant_movement_type", "movement_types": ["climb", "swim"]}
    ]
},
"ranger_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"ranger_weapon_mastery": {
    "type": "passive",
    "effects": [{"type": "weapon_mastery", "count": 2, "properties": ["vex", "nick", "slow"]}]
}
```

---

### 4.11 Rogue (11 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `rogue_expertise` | 1 | Tier 4 | Double prof bonus for two skill proficiencies. | `"type": "narrative_ribbon"` (Skill ribbon). |
| `rogue_thieves'_cant` | 1 | Tier 4 | Secret dialect of thieves. | `"type": "narrative_ribbon"` (Language ribbon). |
| `rogue_weapon_mastery` | 1 | Tier 2 | Weapon mastery properties for two weapons. | See GDScript Snippet below (Tier 2). |
| `rogue_roguish_archetype` | 3 | Tier 3 | Choose roguish archetype subclass. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `rogue_steady_aim` | 3 | Tier 1 | Bonus action advantage on next attack, speed set to 0. | See GDScript Snippet below. |
| `rogue_rogue_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `rogue_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `rogue_cunning_strike` | 5 | Tier 2 | Forego 1d6 Sneak Attack to apply Poison/Trip/Withdraw. | See GDScript Snippet below (Tier 2). |
| `rogue_poison_(cost:_1d6)` | 5 | Tier 2 | Forego 1d6 SA die for target CON save vs poisoned. | See GDScript Snippet below (Tier 2). |
| `rogue_trip_(cost:_1d6)` | 5 | Tier 2 | Forego 1d6 SA die for target DEX save vs prone. | See GDScript Snippet below (Tier 2). |
| `rogue_withdraw_(cost:_1d6)` | 5 | Tier 1 | Forego 1d6 SA die to move half speed without OA. | See GDScript Snippet below. |

#### Proposed GDScript Snippets for Rogue Tiers 1 & 2:
```gdscript
"rogue_steady_aim": {
    "type": "active",
    "action_cost": "bonus_action",
    "uses": 1,
    "uses_per": "turn",
    "effects": [
        {"type": "grant_condition", "condition": "advantage_next_attack", "duration": 1},
        {"type": "set_movement_speed", "speed": 0, "duration": 1}
    ]
},
"rogue_withdraw_(cost:_1d6)": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "turn",
    "effects": [
        {"type": "cunning_strike_cost", "dice_deducted": "1d6"},
        {"type": "movement_bonus", "amount": "half_speed", "prevent_opportunity_attacks": true}
    ]
},
"rogue_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"rogue_weapon_mastery": {
    "type": "passive",
    "effects": [{"type": "weapon_mastery", "count": 2, "properties": ["vex", "nick", "slow"]}]
},
"rogue_cunning_strike": {
    "type": "passive",
    "effects": [{"type": "cunning_strike_framework", "options": ["poison", "trip", "withdraw"]}]
},
"rogue_poison_(cost:_1d6)": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "turn",
    "effects": [
        {"type": "cunning_strike_cost", "dice_deducted": "1d6"},
        {
            "type": "on_hit_trigger",
            "save_type": "CON",
            "on_failure": {"type": "grant_condition", "condition": "poisoned", "duration": 10}
        }
    ]
},
"rogue_trip_(cost:_1d6)": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "turn",
    "effects": [
        {"type": "cunning_strike_cost", "dice_deducted": "1d6"},
        {
            "type": "on_hit_trigger",
            "target_max_size": "large",
            "save_type": "DEX",
            "on_failure": {"type": "grant_condition", "condition": "prone", "duration": 0}
        }
    ]
}
```

---

### 4.12 Sorcerer (11 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `sorcerer_sorcerous_origin` | 1 | Tier 3 | Choose sorcerous origin subclass. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `sorcerer_spellcasting` | 1 | Tier 3 | Cast innate sorcerer spells. | **Subsystem-Quarantined**: Blocked by Sorcerer spell roster. |
| `sorcerer_flexible_casting` | 2 | Tier 1 | Bonus action convert Sorcery Points <-> Spell Slots. | See GDScript Snippet below. |
| `sorcerer_font_of_magic` | 2 | Tier 3 | Wellspring of magic resource management. | **Subsystem-Quarantined**: Font of Magic pool management. |
| `sorcerer_metamagic_options` (L2) | 2 | Tier 3 | Selection menu for Metamagic choices. | **Subsystem-Quarantined**: Metamagic selection system. |
| `sorcerer_metamagic_options` (L3) | 3 | Tier 3 | Expanded Metamagic choices at level 3. | **Subsystem-Quarantined**: Metamagic selection system. |
| `sorcerer_sorcerer_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `sorcerer_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `sorcerer_sorcerous_versatility` | 4 | Tier 4 | Swap metamagic option or cantrip on ASI level. | `"type": "narrative_ribbon"` (Retraining ribbon). |
| `sorcerer_magical_guidance` | 5 | Tier 2 | Spend 1 sorcery point to reroll failed ability check. | See GDScript Snippet below (Tier 2). |
| `sorcerer_sorcerous_restoration` | 5 | Tier 1 | Regain floor(lvl/2) sorcery points on short rest. | See GDScript Snippet below. |

#### Proposed GDScript Snippets for Sorcerer Tiers 1 & 2:
```gdscript
"sorcerer_flexible_casting": {
    "type": "active",
    "action_cost": "bonus_action",
    "uses": 1,
    "uses_per": "turn",
    "effects": [{"type": "convert_resource", "source": "sorcery_points", "target": "spell_slot"}]
},
"sorcerer_sorcerous_restoration": {
    "type": "passive",
    "effects": [{"type": "short_rest_resource_recovery", "resource": "sorcery_points", "amount": "floor(level/2)"}]
},
"sorcerer_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
},
"sorcerer_magical_guidance": {
    "type": "active",
    "action_cost": "none",
    "uses": 1,
    "uses_per": "turn",
    "effects": [
        {"type": "spend_resource", "resource": "sorcery_points", "amount": 1},
        {"type": "check_reroll", "trigger": "failed_ability_check"}
    ]
}
```

---

### 4.13 Warlock (8 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `warlock_otherworldly_patron` | 1 | Tier 3 | Choose otherworldly patron subclass. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `warlock_eldritch_invocation_options` | 1 | Tier 3 | Selection menu for Eldritch Invocations. | **Subsystem-Quarantined**: Invocations selection roster. |
| `warlock_eldritch_invocations` (L1) | 1 | Tier 3 | Imbue fragments of forbidden knowledge. | **Subsystem-Quarantined**: Invocations subsystem. |
| `warlock_eldritch_invocations` (L2) | 2 | Tier 3 | Gain additional invocations at level 2. | **Subsystem-Quarantined**: Invocations subsystem. |
| `warlock_pact_boon` | 3 | Tier 3 | Patron gift: Blade, Chain, Tome, or Talisman. | **Subsystem-Quarantined**: Pact Boon subsystem. |
| `warlock_warlock_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `warlock_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `warlock_eldritch_versatility` | 4 | Tier 4 | Swap invocation or pact boon on ASI level. | `"type": "narrative_ribbon"` (Retraining ribbon). |

#### Proposed GDScript Snippet for Warlock Tier 1:
```gdscript
"warlock_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
}
```

---

### 4.14 Wizard (8 Quarantined Features)

| Feature ID | Level | Tier | 5e Rule Mechanics Summary | Proposed Curation / Quarantine Specification |
|---|---:|---|---|---|
| `wizard_spellcasting` | 1 | Tier 3 | Cast wizard arcane spells via spellbook. | **Subsystem-Quarantined**: Blocked by Wizard spellbook roster. |
| `wizard_ritual_adept` | 1 | Tier 4 | Cast ritual spells without preparing them. | `"type": "narrative_ribbon"` (Ritual ribbon). |
| `wizard_arcane_tradition` | 2 | Tier 3 | Choose arcane tradition subclass. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `wizard_scholar` | 2 | Tier 4 | Expertise in chosen academic skill. | `"type": "narrative_ribbon"` (Skill ribbon). |
| `wizard_cantrip_formulas` | 3 | Tier 4 | Swap one cantrip in spellbook on long rest. | `"type": "narrative_ribbon"` (Preparation ribbon). |
| `wizard_wizard_subclass` | 3 | Tier 3 | Subclass selection entry. | **Subsystem-Quarantined**: Blocked by Subclass framework. |
| `wizard_ability_score_improvement` | 4 | Tier 1 | +2 to one stat or +1 to two stats. | See GDScript Snippet below. |
| `wizard_memorize_spell` | 5 | Tier 4 | Replace one prepared spell during short rest. | `"type": "narrative_ribbon"` (Preparation ribbon). |

#### Proposed GDScript Snippet for Wizard Tier 1:
```gdscript
"wizard_ability_score_improvement": {
    "type": "passive",
    "effects": [{"type": "asi_choice", "stat_points": 2, "max_stat": 20}]
}
```

---

## 5. System Verification & Validation Results

The execution integrity of the feature matrix generation pipeline and offline unit testing suite was verified directly on the target workspace:

1. **Feature Matrix Generation Script (`src/generate_feature_matrix.py`)**:
   - **Command**: `python src/generate_feature_matrix.py`
   - **Result**: PASSED (Exit Code `0`).
   - **Output**: Successfully processed 193 class feature records across 14 class JSONs and generated markdown tables.

2. **Validation and Unit Testing Suite (`src/validate_and_test.py`)**:
   - **Command**: `python src/validate_and_test.py`
   - **Result**: PASSED (Exit Code `0`).
   - **Output**:
     - Hex Math tests: PASSED.
     - Dice Parser Tokenizer tests: PASSED.
     - Core RPG Mechanics & Rules tests: PASSED.
     - Save/Load Serialization schema tests: PASSED.
     - JSON structural validation (`data/core/`): PASSED.

---

## 6. Implementation Roadmap & Execution Plan

1. **Phase 1: Tier 1 Curation Merge**:
   Add the 42 Tier 1 GDScript dictionary definitions into `CURATED_FEATURE_EFFECTS` in `src/autoload/data_loader.gd` and mirror them in `src/generate_feature_matrix.py`.

2. **Phase 2: Effect Vocabulary Extensions (Tier 2)**:
   Implement the 6 Effect Vocabulary extensions in `EventResolver.gd` and `combat_state.gd`, then merge the 20 Tier 2 feature definitions into `CURATED_FEATURE_EFFECTS`.

3. **Phase 3: Subsystem ADR Implementations (Tier 3)**:
   Unpark and execute specific subsystem ADRs (such as ADR-0002 for Druid Wild Shape, Mystic Psionics ADR, Infusions ADR) to expose Tier 3 features progressively.

4. **Phase 4: Ribbon Taxonomy Tagging (Tier 4)**:
   Update `data_loader.gd` sanitization logic to recognize `"type": "narrative_ribbon"`, preserving these 28 features as passive character sheet flags while keeping combat UI menus clean.
