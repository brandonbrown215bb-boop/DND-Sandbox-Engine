# Class Features Inventory Survey Report

## Executive Summary

- **Total Character Classes Surveyed**: 14
- **Total Class Feature Records**: 193
- **Mechanics-Backed (Curated) Feature Records**: 36
- **Quarantined / Effectless Feature Records**: **157**
- **157 Quarantined Target Verification**: VERIFIED PASSED

This survey cataloged every feature record across all 14 core class JSON files in `data/core/classes/*.json`. Raw JSON feature records do not carry direct `effects` or `resolver` keys; mechanics backing is applied at runtime via DataLoader's `CURATED_FEATURE_EFFECTS` dictionary in `src/autoload/data_loader.gd`.

### Class Feature Metrics Summary

| Class | Total Feature Records | Mechanics-Backed (Curated) | Quarantined / Effectless |
|---|---:|---:|---:|
| `artificer` | 13 | 1 | 12 |
| `barbarian` | 11 | 4 | 7 |
| `bard` | 13 | 1 | 12 |
| `cleric` | 16 | 1 | 15 |
| `druid` | 13 | 0 | 13 |
| `fighter` | 11 | 3 | 8 |
| `monk` | 24 | 7 | 17 |
| `mystic` | 9 | 0 | 9 |
| `paladin` | 18 | 6 | 12 |
| `ranger` | 17 | 3 | 14 |
| `rogue` | 14 | 3 | 11 |
| `sorcerer` | 15 | 4 | 11 |
| `warlock` | 10 | 2 | 8 |
| `wizard` | 9 | 1 | 8 |
| **TOTAL** | **193** | **36** | **157** |

---

## Complete Class Feature Catalog by Class

### Artificer (13 records: 1 mechanics-backed, 12 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `artificer_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | You have learned how to channel magical energy through objects. See the Player's Handbook for the rules on spellcasti... |
| 1 | `artificer_tinker's_magic` | Tinker's Magic | **Mechanics-Backed** | active (action) | 1 / combat | curated: give_item:ball_bearings | You know the Mending cantrip. As a {@action Magic} action while holding Tinker's Tools, you can create one item in an... |
| 1 | `artificer_magical_tinkering` | Magical Tinkering | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | {@i 1st-level artificer feature} You've learned how to invest a spark of magic into mundane objects. To use this abil... |
| 1 | `artificer_optional_rule:_firearm_proficiency` | Optional Rule: Firearm Proficiency | **Quarantined** | passive | None | None (empty JSON) | The secrets of creating and operating gunpowder weapons have been discovered in various corners of the D&D multiverse... |
| 2 | `artificer_replicate_magic_item` | Replicate Magic Item | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | You have learned arcane plans that you use to make magic items. {'type': 'entries', 'entries': [{'type': 'entries', '... |
| 2 | `artificer_infuse_item` | Infuse Item | **Quarantined** | passive | None | None (empty JSON) | {@i 2nd-level artificer feature} You've gained the ability to imbue mundane items with certain magical infusions, tur... |
| 2 | `artificer_infusions_known` | Infusions Known | **Quarantined** | passive | None | None (empty JSON) | When you gain this feature, pick four artificer infusions to learn, choosing from the "{@filter Artificer Infusions t... |
| 3 | `artificer_artificer_subclass` | Artificer Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain an Artificer subclass of your choice. The {@subclass Alchemist}, {@subclass Armorer}, {@subclass Artillerist... |
| 3 | `artificer_artificer_specialist` | Artificer Specialist | **Quarantined** | passive | None | None (empty JSON) | {@i 3rd-level artificer feature} Choose the type of specialist you are, each of which is detailed at the end of the c... |
| 3 | `artificer_the_right_tool_for_the_job` | The Right Tool for the Job | **Quarantined** | passive | None | None (empty JSON) | {@i 3rd-level artificer feature} You've learned how to produce exactly the tool you need: with thieves' tools or arti... |
| 4 | `artificer_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | You gain the {@feat Ability Score Improvement} feat or another feat of your choice for which you qualify. You gain th... |
| 5 | `artificer_subclass_feature` | Subclass feature | **Quarantined** | passive | None | None (empty JSON) | You gain a feature from your Artificer Subclass. |
| 5 | `artificer_artificer_specialist_feature` | Artificer Specialist Feature | **Quarantined** | passive | None | None (empty JSON) | {@i 5th-level artificer feature} You gain a feature granted by your Artificer Specialist choice. |

### Barbarian (11 records: 4 mechanics-backed, 7 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `barbarian_rage` | Rage | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: grant_condition+stat_modifier | In battle, you fight with primal ferocity. On your turn, you can enter a rage as a bonus action. While raging, you ga... |
| 1 | `barbarian_unarmored_defense` | Unarmored Defense | **Mechanics-Backed** | passive | None | curated: unarmored_defense:10+DEX+CON with shield | While you are not wearing any armor, your Armor Class equals 10 + your Dexterity modifier + your Constitution modifie... |
| 1 | `barbarian_weapon_mastery` | Weapon Mastery | **Quarantined** | passive | None | None (empty JSON) | Your training with weapons allows you to use the weapon mastery properties properties of two kinds of {@filter Simple... |
| 2 | `barbarian_danger_sense` | Danger Sense | **Quarantined** | passive | None | None (empty JSON) | At 2nd level, you gain an uncanny sense of when things nearby aren't as they should be, giving you an edge when you d... |
| 2 | `barbarian_reckless_attack` | Reckless Attack | **Mechanics-Backed** | passive | None | curated: reckless_attack | Starting at 2nd level, you can throw aside all concern for defense to attack with fierce desperation. When you make y... |
| 3 | `barbarian_primal_knowledge` | Primal Knowledge | **Quarantined** | passive | None | None (empty JSON) | {@i 3rd-level barbarian optional class features feature} When you reach 3rd level and again at 10th level, you gain p... |
| 3 | `barbarian_primal_path` | Primal Path | **Quarantined** | passive | None | None (empty JSON) | At 3rd level, you choose a path that shapes the nature of your rage from the list of available paths. Your choice gra... |
| 3 | `barbarian_barbarian_subclass` | Barbarian Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Barbarian subclass of your choice. A subclass is a specialization that grants you features at certain Barb... |
| 4 | `barbarian_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 5 | `barbarian_extra_attack` | Extra Attack | **Mechanics-Backed** | active (action) | 1 / combat | curated: extra_attack | Beginning at 5th level, you can attack twice, instead of once, whenever you take the {@action Attack} action on your ... |
| 5 | `barbarian_fast_movement` | Fast Movement | **Quarantined** | passive | None | None (empty JSON) | Starting at 5th level, your speed increases by 10 feet while you aren't wearing heavy armor. |

### Bard (13 records: 1 mechanics-backed, 12 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `bard_bardic_inspiration` | Bardic Inspiration | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: bardic_inspiration | You can inspire others through stirring words or music. To do so, you use a bonus action on your turn to choose one c... |
| 1 | `bard_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | You have learned to untangle and reshape the fabric of reality in harmony with your wishes and music. Your spells are... |
| 2 | `bard_jack_of_all_trades` | Jack of All Trades | **Quarantined** | passive | None | None (empty JSON) | Starting at 2nd level, you can add half your proficiency bonus, rounded down, to any ability check you make that does... |
| 2 | `bard_magical_inspiration` | Magical Inspiration | **Quarantined** | passive | None | None (empty JSON) | {@i 2nd-level bard optional class features feature} If a creature has a Bardic Inspiration die from you and casts a s... |
| 2 | `bard_song_of_rest_(d6)` | Song of Rest (d6) | **Quarantined** | passive | None | None (empty JSON) | Beginning at 2nd level, you can use soothing music or oration to help revitalize your wounded allies during a short r... |
| 2 | `bard_expertise` | Expertise | **Quarantined** | passive | None | None (empty JSON) | You gain Expertise in two of your skill proficiencies of your choice. {@skill Performance} and {@skill Persuasion} ar... |
| 3 | `bard_bard_college` | Bard College | **Quarantined** | passive | None | None (empty JSON) | At 3rd level, you delve into the advanced techniques of a bard college of your choice from the list of available coll... |
| 3 | `bard_expertise` | Expertise | **Quarantined** | passive | None | None (empty JSON) | At 3rd level, choose two of your skill proficiencies. Your proficiency bonus is doubled for any ability check you mak... |
| 3 | `bard_bard_subclass` | Bard Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Bard subclass of your choice. A subclass is a specialization that grants you features at certain Bard leve... |
| 4 | `bard_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `bard_bardic_versatility` | Bardic Versatility | **Quarantined** | passive | None | None (empty JSON) | {@i 4th-level bard optional class features feature} Whenever you reach a level in this class that grants the Ability ... |
| 5 | `bard_bardic_inspiration_(d8)` | Bardic Inspiration (d8) | **Quarantined** | passive | None | None (empty JSON) | At 5th level, your Bardic Inspiration die changes to a d8. |
| 5 | `bard_font_of_inspiration` | Font of Inspiration | **Quarantined** | passive | None | None (empty JSON) | Beginning when you reach 5th level, you regain all of your expended uses of Bardic Inspiration when you finish a shor... |

### Cleric (16 records: 1 mechanics-backed, 15 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `cleric_divine_domain` | Divine Domain | **Quarantined** | passive | None | None (empty JSON) | Choose one domain related to your deity from the list of available domains. Each domain is detailed in their own feat... |
| 1 | `cleric_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | As a conduit for divine power, you can cast cleric spells. See chapter 10 for the general rules of spellcasting and c... |
| 1 | `cleric_divine_order` | Divine Order | **Quarantined** | passive | None | None (empty JSON) | You have dedicated yourself to one of the following sacred roles of your choice. {'type': 'entries', 'entries': [{'ty... |
| 1 | `cleric_protector` | Protector | **Quarantined** | passive | None | None (empty JSON) | Trained for battle, you gain proficiency with {@filter Martial weapons=martial weapon} and training with {@filter Hea... |
| 1 | `cleric_thaumaturge` | Thaumaturge | **Quarantined** | passive | None | None (empty JSON) | You know one extra cantrip from the {@filter Cleric spell list=Cleric}. In addition, your mystical connection to the ... |
| 2 | `cleric_channel_divinity` | Channel Divinity | **Quarantined** | passive | None | None (empty JSON) | At 2nd level, you gain the ability to channel divine energy directly from your deity, using that energy to fuel magic... |
| 2 | `cleric_channel_divinity:_harness_divine_power` | Channel Divinity: Harness Divine Power | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: recover_spell_slots | {@i 2nd-level cleric optional class features feature} You can expend a use of your Channel Divinity to fuel your spel... |
| 2 | `cleric_channel_divinity:_turn_undead` | Channel Divinity: Turn Undead | **Quarantined** | active (reaction) | 1 / combat | None (empty JSON) | As an action, you present your holy symbol and speak a prayer censuring the undead. Each undead that can see or hear ... |
| 2 | `cleric_divine_domain_feature` | Divine Domain feature | **Quarantined** | passive | None | None (empty JSON) | At 2nd level, you gain a feature from your Divine Domain. |
| 2 | `cleric_divine_spark` | Divine Spark | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | As a {@action Magic} action, you point your Holy Symbol at another creature you can see within 30 feet of yourself an... |
| 2 | `cleric_turn_undead` | Turn Undead | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | As a {@action Magic} action, you present your Holy Symbol and censure Undead creatures. Each Undead of your choice wi... |
| 3 | `cleric_cleric_subclass` | Cleric Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Cleric subclass of your choice. A subclass is a specialization that grants you features at certain Cleric ... |
| 4 | `cleric_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `cleric_cantrip_versatility` | Cantrip Versatility | **Quarantined** | passive | None | None (empty JSON) | {@i 4th-level cleric optional class features feature} Whenever you reach a level in this class that grants the Abilit... |
| 5 | `cleric_destroy_undead_(cr_1/2)` | Destroy Undead (CR 1/2) | **Quarantined** | passive | None | None (empty JSON) | Starting at 5th level, when an {@filter undead of CR 1/2 or lower rating=[&0;&1/2]=undead=!swarm} fails its saving th... |
| 5 | `cleric_sear_undead` | Sear Undead | **Quarantined** | passive | None | None (empty JSON) | Whenever you use Turn Undead, you can roll a number of d8s equal to your Wisdom modifier (minimum of 1d8) and add the... |

### Druid (13 records: 0 mechanics-backed, 13 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `druid_druidic` | Druidic | **Quarantined** | passive | None | None (empty JSON) | You know {@language Druidic}, the secret language of druids. You can speak the language and use it to leave hidden me... |
| 1 | `druid_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | Drawing on the divine essence of nature itself, you can cast spells to shape that essence to your will. See chapter 1... |
| 1 | `druid_magician` | Magician | **Quarantined** | passive | None | None (empty JSON) | You know one extra cantrip from the {@filter Druid spell list=Druid}. In addition, your mystical connection to nature... |
| 1 | `druid_primal_order` | Primal Order | **Quarantined** | passive | None | None (empty JSON) | You have dedicated yourself to one of the following sacred roles of your choice. {'type': 'entries', 'entries': [{'ty... |
| 1 | `druid_warden` | Warden | **Quarantined** | passive | None | None (empty JSON) | Trained for battle, you gain proficiency with {@filter Martial weapons=martial weapon} and training with {@filter Med... |
| 2 | `druid_druid_circle` | Druid Circle | **Quarantined** | passive | None | None (empty JSON) | At 2nd level, you choose to identify with a circle of druids from the list of available circles. Your choice grants y... |
| 2 | `druid_wild_companion` | Wild Companion | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | {@i 2nd-level druid optional class features feature} You gain the ability to summon a spirit that assumes an animal f... |
| 2 | `druid_wild_shape` | Wild Shape | **Quarantined** | active (bonus_action) | 1 / combat | None (empty JSON) | Starting at 2nd level, you can use your action to magically assume the shape of a beast that you have seen before. Yo... |
| 3 | `druid_druid_subclass` | Druid Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Druid subclass of your choice. A subclass is a specialization that grants you features at certain Druid le... |
| 4 | `druid_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `druid_cantrip_versatility` | Cantrip Versatility | **Quarantined** | passive | None | None (empty JSON) | {@i 4th-level druid optional class features feature} Whenever you reach a level in this class that grants the Ability... |
| 4 | `druid_wild_shape_improvement` | Wild Shape Improvement | **Quarantined** | passive | None | None (empty JSON) | At 4th level, your Wild Shape improves as shown on the Beast Shapes table. |
| 5 | `druid_wild_resurgence` | Wild Resurgence | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | Once on each of your turns, if you have no uses of Wild Shape left, you can give yourself one use by expending a spel... |

### Fighter (11 records: 3 mechanics-backed, 8 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `fighter_fighting_style` | Fighting Style | **Quarantined** | passive | None | None (empty JSON) | You adopt a particular style of fighting as your specialty. Choose one of the following options. You can't take the s... |
| 1 | `fighter_second_wind` | Second Wind | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: heal_self | You have a limited well of stamina that you can draw on to protect yourself from harm. On your turn, you can use a bo... |
| 1 | `fighter_weapon_mastery` | Weapon Mastery | **Quarantined** | passive | None | None (empty JSON) | Your training with weapons allows you to use the weapon mastery properties properties of three kinds of {@filter Simp... |
| 2 | `fighter_action_surge` | Action Surge | **Mechanics-Backed** | active (action) | 1 / combat | curated: grant_extra_action | Starting at 2nd level, you can push yourself beyond your normal limits for a moment. On your turn, you can take one a... |
| 2 | `fighter_tactical_mind` | Tactical Mind | **Quarantined** | passive | None | None (empty JSON) | You have a mind for tactics on and off the battlefield. When you fail an ability check, you can expend a use of your ... |
| 3 | `fighter_martial_archetype` | Martial Archetype | **Quarantined** | passive | None | None (empty JSON) | At 3rd level, you choose an archetype from the list available that you strive to emulate in your combat styles and te... |
| 3 | `fighter_fighter_subclass` | Fighter Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Fighter subclass of your choice. A subclass is a specialization that grants you features at certain Fighte... |
| 4 | `fighter_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `fighter_martial_versatility` | Martial Versatility | **Quarantined** | passive | None | None (empty JSON) | {@i 4th-level fighter optional class features feature} Whenever you reach a level in this class that grants the Abili... |
| 5 | `fighter_extra_attack` | Extra Attack | **Mechanics-Backed** | active (action) | 1 / combat | curated: extra_attack | Beginning at 5th level, you can attack twice, instead of once, whenever you take the {@action Attack} action on your ... |
| 5 | `fighter_tactical_shift` | Tactical Shift | **Quarantined** | active (bonus_action) | 1 / combat | None (empty JSON) | Whenever you activate your Second Wind with a Bonus Action, you can move up to half your Speed without provoking {@ac... |

### Monk (24 records: 7 mechanics-backed, 17 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `monk_martial_arts` | Martial Arts | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: unarmed_attack | Your practice of martial arts gives you mastery of combat styles that use unarmed strikes and monk weapons, which are... |
| 1 | `monk_unarmored_defense` | Unarmored Defense | **Mechanics-Backed** | passive | None | curated: unarmored_defense | Beginning at 1st level, while you are wearing no armor and not wielding a shield, your AC equals 10 + your Dexterity ... |
| 1 | `monk_bonus_unarmed_strike` | Bonus Unarmed Strike | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: unarmed_attack | You can make an Unarmed Strike as a Bonus Action. |
| 1 | `monk_dexterous_attacks` | Dexterous Attacks | **Quarantined** | passive | None | None (empty JSON) | You can use your Dexterity modifier instead of your Strength modifier for the attack and damage rolls of your Unarmed... |
| 1 | `monk_martial_arts_die` | Martial Arts Die | **Quarantined** | passive | None | None (empty JSON) | You can roll 1d6 in place of the normal damage of your Unarmed Strike or Monk weapons. This die changes as you gain M... |
| 2 | `monk_dedicated_weapon` | Dedicated Weapon | **Quarantined** | passive | None | None (empty JSON) | {@i 2nd-level monk optional class features feature} You train yourself to use a variety of weapons as monk weapons, n... |
| 2 | `monk_flurry_of_blows` | Flurry of Blows | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: unarmed_attack x2 | Immediately after you take the {@action Attack} action on your turn, you can spend 1 ki point to make two unarmed str... |
| 2 | `monk_ki` | Ki | **Quarantined** | passive | None | None (empty JSON) | Starting at 2nd level, your training allows you to harness the mystic energy of ki. Your access to this energy is rep... |
| 2 | `monk_patient_defense` | Patient Defense | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: grant_condition | You can spend 1 ki point to take the {@action Dodge} action as a bonus action on your turn. |
| 2 | `monk_step_of_the_wind` | Step of the Wind | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: step_of_the_wind | You can spend 1 ki point to take the {@action Disengage} or {@action Dash} action as a bonus action on your turn, and... |
| 2 | `monk_unarmored_movement` | Unarmored Movement | **Quarantined** | passive | None | None (empty JSON) | Starting at 2nd level, your speed increases by 10 feet while you are not wearing armor or wielding a shield. This bon... |
| 2 | `monk_monk's_focus` | Monk's Focus | **Quarantined** | passive | None | None (empty JSON) | Your focus and martial training allow you to harness a well of extraordinary energy within yourself. This energy is r... |
| 2 | `monk_uncanny_metabolism` | Uncanny Metabolism | **Quarantined** | passive | None | None (empty JSON) | When you roll Initiative, you can regain all expended Focus Points. When you do so, roll your Martial Arts die, and r... |
| 3 | `monk_deflect_missiles` | Deflect Missiles | **Quarantined** | active (reaction) | 1 / combat | None (empty JSON) | Starting at 3rd level, you can use your reaction to deflect or catch the missile when you are hit by a ranged weapon ... |
| 3 | `monk_ki-fueled_attack` | Ki-Fueled Attack | **Quarantined** | active (bonus_action) | 1 / combat | None (empty JSON) | {@i 3rd-level monk optional class features feature} If you spend 1 ki point or more as part of your action on your tu... |
| 3 | `monk_monastic_tradition` | Monastic Tradition | **Quarantined** | passive | None | None (empty JSON) | When you reach 3rd level, you commit yourself to a monastic tradition, chosen from the list of available traditions. ... |
| 3 | `monk_deflect_attacks` | Deflect Attacks | **Quarantined** | active (reaction) | 1 / combat | None (empty JSON) | When an attack roll hits you and its damage includes Bludgeoning, Piercing, or Slashing damage, you can take a Reacti... |
| 3 | `monk_monk_subclass` | Monk Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Monk subclass of your choice. A subclass is a specialization that grants you features at certain Monk leve... |
| 4 | `monk_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `monk_quickened_healing` | Quickened Healing | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | {@i 4th-level monk optional class features feature} As an action, you can spend 2 ki points and roll a Martial Arts d... |
| 4 | `monk_slow_fall` | Slow Fall | **Quarantined** | active (reaction) | 1 / combat | None (empty JSON) | Beginning at 4th level, you can use your reaction when you fall to reduce any falling damage you take by an amount eq... |
| 5 | `monk_extra_attack` | Extra Attack | **Mechanics-Backed** | active (action) | 1 / combat | curated: extra_attack | Beginning at 5th level, you can attack twice, instead of once, whenever you take the {@action Attack} action on your ... |
| 5 | `monk_focused_aim` | Focused Aim | **Quarantined** | passive | None | None (empty JSON) | {@i 5th-level monk optional class features feature} When you miss with an attack roll, you can spend 1 to 3 ki points... |
| 5 | `monk_stunning_strike` | Stunning Strike | **Quarantined** | passive | None | None (empty JSON) | Starting at 5th level, you can interfere with the flow of ki in an opponent's body. When you hit another creature wit... |

### Mystic (9 records: 0 mechanics-backed, 9 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `mystic_mystic_order` | Mystic Order | **Quarantined** | passive | None | None (empty JSON) | At 1st level, you choose a Mystic Order from the list of available orders. Each order specializes in a specific appro... |
| 1 | `mystic_psionic_disciplines_and_talents` | Psionic Disciplines and Talents | **Quarantined** | passive | None | None (empty JSON) | {@filter Psionic talents=T} and {@filter disciplines=D} are the heart of a mystic's craft. They are the mental exerci... |
| 1 | `mystic_psionics` | Psionics | **Quarantined** | active (bonus_action) | 1 / combat | None (empty JSON) | As a student of psionics, you can master and use psionic talents and disciplines, the rules for which appear at the e... |
| 1 | `mystic_using_a_discipline` | Using a Discipline | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | Each psionic discipline has several ways you can use it, all contained in its description. The discipline specifies t... |
| 2 | `mystic_mystical_recovery` | Mystical Recovery | **Quarantined** | active (bonus_action) | 1 / combat | None (empty JSON) | Starting at 2nd level, you can draw vigor from the psi energy you use to power your psionic disciplines. Immediately ... |
| 2 | `mystic_telepathy` | Telepathy | **Quarantined** | passive | None | None (empty JSON) | At 2nd level, your mind awakens to the ability to communicate via telepathy. You can telepathically speak to any crea... |
| 3 | `mystic_mystic_order_feature` | Mystic Order feature | **Quarantined** | passive | None | None (empty JSON) | At 3rd level, you gain another feature from your Mystic Order. |
| 4 | `mystic_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, and again at 8th, 12th, 16th, and 19th level, you can increase one ability score of your ch... |
| 4 | `mystic_strength_of_mind` | Strength of Mind | **Quarantined** | passive | None | None (empty JSON) | Even the simplest psionic technique requires a deep understanding of how psionic energy can augment mind and body. Th... |

### Paladin (18 records: 6 mechanics-backed, 12 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `paladin_divine_sense` | Divine Sense | **Mechanics-Backed** | active (action) | 1 / combat | curated: divine_sense | The presence of strong evil registers on your senses like a noxious odor, and powerful good rings like heavenly music... |
| 1 | `paladin_lay_on_hands` | Lay on Hands | **Mechanics-Backed** | active (action) | 1 / combat | curated: lay_on_hands | Your blessed touch can heal wounds. You have a pool of healing power that replenishes when you take a long rest. With... |
| 1 | `paladin_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | You have learned to cast spells through prayer and meditation. See chapter 7 for the rules on spellcasting. The infor... |
| 1 | `paladin_weapon_mastery` | Weapon Mastery | **Quarantined** | passive | None | None (empty JSON) | Your training with weapons allows you to use the weapon mastery properties properties of two kinds of {@filter weapon... |
| 2 | `paladin_divine_smite` | Divine Smite | **Mechanics-Backed** | passive | None | curated: divine_smite | Starting at 2nd level, when you hit a creature with a melee weapon attack, you can expend one spell slot to deal radi... |
| 2 | `paladin_fighting_style` | Fighting Style | **Mechanics-Backed** | passive | None | curated: defense_style:+1 AC while armored | At 2nd level, you adopt a particular style of fighting as your specialty. Choose one of the following options. You ca... |
| 2 | `paladin_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | By 2nd level, you have learned to draw on divine magic through meditation and prayer to cast spells as a cleric does.... |
| 2 | `paladin_paladin's_smite` | Paladin's Smite | **Quarantined** | passive | None | None (empty JSON) | You always have the Divine Smite spell prepared. In addition, you can cast it without expending a spell slot, but you... |
| 3 | `paladin_channel_divinity` | Channel Divinity | **Quarantined** | passive | None | None (empty JSON) | Your oath allows you to channel divine energy to fuel magical effects. Each Channel Divinity option provided by your ... |
| 3 | `paladin_channel_divinity:_harness_divine_power` | Channel Divinity: Harness Divine Power | **Quarantined** | active (bonus_action) | 1 / combat | None (empty JSON) | {@i 3rd-level paladin optional class features feature} You can expend a use of your Channel Divinity to fuel your spe... |
| 3 | `paladin_divine_health` | Divine Health | **Quarantined** | passive | None | None (empty JSON) | By 3rd level, the divine magic flowing through you makes you immune to disease. |
| 3 | `paladin_sacred_oath` | Sacred Oath | **Quarantined** | passive | None | None (empty JSON) | When you reach 3rd level, you swear the oath that binds you as a paladin forever. Up to this time you have been in a ... |
| 3 | `paladin_divine_sense` | Divine Sense | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: divine_sense | As a Bonus Action, you can open your awareness to detect Celestials, Fiends, and Undead. For the next 10 minutes or u... |
| 3 | `paladin_paladin_subclass` | Paladin Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Paladin subclass of your choice. A subclass is a specialization that grants you features at certain Paladi... |
| 4 | `paladin_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `paladin_martial_versatility` | Martial Versatility | **Quarantined** | passive | None | None (empty JSON) | {@i 4th-level paladin optional class features feature} Whenever you reach a level in this class that grants the Abili... |
| 5 | `paladin_extra_attack` | Extra Attack | **Mechanics-Backed** | active (action) | 1 / combat | curated: extra_attack | Beginning at 5th level, you can attack twice, instead of once, whenever you take the {@action Attack} action on your ... |
| 5 | `paladin_faithful_steed` | Faithful Steed | **Quarantined** | passive | None | None (empty JSON) | You can call on the aid of an otherworldly steed. You always have the Find Steed spell prepared. You can also cast th... |

### Ranger (17 records: 3 mechanics-backed, 14 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `ranger_deft_explorer` | Deft Explorer | **Quarantined** | passive | None | None (empty JSON) | {@i 1st-level ranger optional class features feature, which replaces the Natural Explorer feature} You are an unsurpa... |
| 1 | `ranger_favored_enemy` | Favored Enemy | **Quarantined** | passive | None | None (empty JSON) | Beginning at 1st level, you have significant experience studying, tracking, hunting, and even talking to a certain ty... |
| 1 | `ranger_favored_foe` | Favored Foe | **Mechanics-Backed** | passive | None | curated: favored_foe | {@i 1st-level ranger optional class features feature, which replaces the Favored Enemy feature and works with the Foe... |
| 1 | `ranger_natural_explorer` | Natural Explorer | **Quarantined** | passive | None | None (empty JSON) | You are particularly familiar with one type of natural environment and are adept at traveling and surviving in such r... |
| 1 | `ranger_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | You have learned to channel the magical essence of nature to cast spells. See chapter 7 for the rules on spellcasting... |
| 1 | `ranger_weapon_mastery` | Weapon Mastery | **Quarantined** | passive | None | None (empty JSON) | Your training with weapons allows you to use the weapon mastery properties properties of two kinds of {@filter weapon... |
| 2 | `ranger_fighting_style` | Fighting Style | **Mechanics-Backed** | passive | None | curated: archery:+2 ranged attack | At 2nd level, you adopt a particular style of fighting as your specialty. Choose one of the following options. You ca... |
| 2 | `ranger_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | By the time you reach 2nd level, you have learned to use the magical essence of nature to cast spells, much as a drui... |
| 2 | `ranger_spellcasting_focus` | Spellcasting Focus | **Quarantined** | passive | None | None (empty JSON) | {@i 2nd-level ranger optional class features feature} You can use a druidic focus as a spellcasting focus for your ra... |
| 2 | `ranger_deft_explorer` | Deft Explorer | **Quarantined** | passive | None | None (empty JSON) | Thanks to your travels, you gain the following benefits. {'type': 'entries', 'entries': [{'type': 'entries', 'name': ... |
| 3 | `ranger_primal_awareness` | Primal Awareness | **Quarantined** | passive | None | None (empty JSON) | {@i 3rd-level ranger optional class features feature, which replaces the Primeval Awareness feature} You can focus yo... |
| 3 | `ranger_primeval_awareness` | Primeval Awareness | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | Beginning at 3rd level, you can use your action and expend one ranger spell slot to focus your awareness on the regio... |
| 3 | `ranger_ranger_archetype` | Ranger Archetype | **Quarantined** | passive | None | None (empty JSON) | At 3rd level, you choose an archetype that you strive to emulate from the list of available archetypes. Your choice g... |
| 3 | `ranger_ranger_subclass` | Ranger Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Ranger subclass of your choice. A subclass is a specialization that grants you features at certain Ranger ... |
| 4 | `ranger_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `ranger_martial_versatility` | Martial Versatility | **Quarantined** | passive | None | None (empty JSON) | {@i 4th-level ranger optional class features feature} Whenever you reach a level in this class that grants the Abilit... |
| 5 | `ranger_extra_attack` | Extra Attack | **Mechanics-Backed** | active (action) | 1 / combat | curated: extra_attack | Beginning at 5th level, you can attack twice, instead of once, whenever you take the {@action Attack} action on your ... |

### Rogue (14 records: 3 mechanics-backed, 11 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `rogue_expertise` | Expertise | **Quarantined** | passive | None | None (empty JSON) | At 1st level, choose two of your skill proficiencies, or one of your skill proficiencies and your proficiency with th... |
| 1 | `rogue_sneak_attack` | Sneak Attack | **Mechanics-Backed** | active (action) | 1 / combat | curated: sneak_attack | Beginning at 1st level, you know how to strike subtly and exploit a foe's distraction. Once per turn, you can deal an... |
| 1 | `rogue_thieves'_cant` | Thieves' Cant | **Quarantined** | passive | None | None (empty JSON) | During your rogue training you learned thieves' cant, a secret mix of dialect, jargon, and code that allows you to hi... |
| 1 | `rogue_weapon_mastery` | Weapon Mastery | **Quarantined** | passive | None | None (empty JSON) | Your training with weapons allows you to use the weapon mastery properties properties of two kinds of {@filter weapon... |
| 2 | `rogue_cunning_action` | Cunning Action | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: cunning_action | Starting at 2nd level, your quick thinking and agility allow you to move and act quickly. You can take a bonus action... |
| 3 | `rogue_roguish_archetype` | Roguish Archetype | **Quarantined** | passive | None | None (empty JSON) | At 3rd level, you choose an archetype that you emulate in the exercise of your rogue abilities from the list of avail... |
| 3 | `rogue_steady_aim` | Steady Aim | **Quarantined** | active (bonus_action) | 1 / combat | None (empty JSON) | {@i 3rd-level rogue optional class features feature} As a bonus action, you give yourself advantage on your next atta... |
| 3 | `rogue_rogue_subclass` | Rogue Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Rogue subclass of your choice. A subclass is a specialization that grants you features at certain Rogue le... |
| 4 | `rogue_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 5 | `rogue_uncanny_dodge` | Uncanny Dodge | **Mechanics-Backed** | active (reaction) | 1 / combat | curated: reaction:uncanny_dodge | Starting at 5th level, when an attacker that you can see hits you with an attack, you can use your reaction to halve ... |
| 5 | `rogue_cunning_strike` | Cunning Strike | **Quarantined** | passive | None | None (empty JSON) | You've developed cunning ways to use your Sneak Attack. When you deal Sneak Attack damage, you can add one of the fol... |
| 5 | `rogue_poison_(cost:_1d6)` | Poison (Cost: 1d6) | **Quarantined** | passive | None | None (empty JSON) | You add a toxin to your strike, forcing the target to make a Constitution saving throw. On a failed save, the target ... |
| 5 | `rogue_trip_(cost:_1d6)` | Trip (Cost: 1d6) | **Quarantined** | passive | None | None (empty JSON) | If the target is Large or smaller, it must succeed on a Dexterity saving throw or have the Prone condition. |
| 5 | `rogue_withdraw_(cost:_1d6)` | Withdraw (Cost: 1d6) | **Quarantined** | active (action) | 1 / combat | None (empty JSON) | Immediately after the attack, you move up to half your Speed without provoking {@action Opportunity Attack Attacks}. |

### Sorcerer (15 records: 4 mechanics-backed, 11 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `sorcerer_sorcerous_origin` | Sorcerous Origin | **Quarantined** | passive | None | None (empty JSON) | Choose a sorcerous origin, which describes the source of your innate magical power, from the list of available origin... |
| 1 | `sorcerer_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | An event in your past, or in the life of a parent or ancestor, left an indelible mark on you, infusing you with arcan... |
| 1 | `sorcerer_innate_sorcery` | Innate Sorcery | **Mechanics-Backed** | active (bonus_action) | 1 / combat | curated: innate_sorcery:+1 spell DC and spell-attack advantage | An event in your past left an indelible mark on you, infusing you with simmering magic. As a Bonus Action, you can un... |
| 2 | `sorcerer_flexible_casting` | Flexible Casting | **Quarantined** | active (bonus_action) | 1 / combat | None (empty JSON) | You can use your sorcery points to gain additional spell slots, or sacrifice spell slots to gain additional sorcery p... |
| 2 | `sorcerer_font_of_magic` | Font of Magic | **Quarantined** | passive | None | None (empty JSON) | At 2nd level, you tap into a deep wellspring of magic within yourself. This wellspring is represented by sorcery poin... |
| 2 | `sorcerer_sorcery_points` | Sorcery Points | **Mechanics-Backed** | passive | None | curated: sorcery_points | You have 2 sorcery points, and you gain one additional point every time you level up, to a maximum of 20 at level 20.... |
| 2 | `sorcerer_metamagic` | Metamagic | **Mechanics-Backed** | passive | None | curated: metamagic | Because your magic flows from within, you can alter your spells to suit your needs; you gain two Metamagic options of... |
| 2 | `sorcerer_metamagic_options` | Metamagic Options | **Quarantined** | passive | None | None (empty JSON) | The following options are available to your Metamagic feature. The options are presented in alphabetical order. {'typ... |
| 3 | `sorcerer_metamagic` | Metamagic | **Mechanics-Backed** | passive | None | curated: metamagic | At 3rd level, you gain the ability to twist your spells to suit your needs. You gain two of the following Metamagic o... |
| 3 | `sorcerer_metamagic_options` | Metamagic Options | **Quarantined** | passive | None | None (empty JSON) | {@i 3rd-level sorcerer optional class features feature} When you choose Metamagic options, you have access to the fol... |
| 3 | `sorcerer_sorcerer_subclass` | Sorcerer Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Sorcerer subclass of your choice. A subclass is a specialization that grants you features at certain Sorce... |
| 4 | `sorcerer_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `sorcerer_sorcerous_versatility` | Sorcerous Versatility | **Quarantined** | passive | None | None (empty JSON) | {@i 4th-level sorcerer optional class features feature} Whenever you reach a level in this class that grants the Abil... |
| 5 | `sorcerer_magical_guidance` | Magical Guidance | **Quarantined** | passive | None | None (empty JSON) | {@i 5th-level sorcerer optional class features feature} You can tap into your inner wellspring of magic to try to con... |
| 5 | `sorcerer_sorcerous_restoration` | Sorcerous Restoration | **Quarantined** | passive | None | None (empty JSON) | When you finish a Short Rest, you can regain expended Sorcery Points, but no more than a number equal to half your So... |

### Warlock (10 records: 2 mechanics-backed, 8 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `warlock_otherworldly_patron` | Otherworldly Patron | **Quarantined** | passive | None | None (empty JSON) | At 1st level, you have struck a bargain with an otherworldly being chosen from the list of available patrons. Your ch... |
| 1 | `warlock_pact_magic` | Pact Magic | **Mechanics-Backed** | passive | None | curated: pact_magic | Your arcane research and the magic bestowed on you by your patron have given you facility with spells. See chapter 10... |
| 1 | `warlock_eldritch_invocation_options` | Eldritch Invocation Options | **Quarantined** | passive | None | None (empty JSON) | Eldritch Invocation options appear in alphabetical order. {'type': 'options', 'count': 1, 'entries': [{'type': 'refOp... |
| 1 | `warlock_eldritch_invocations` | Eldritch Invocations | **Quarantined** | passive | None | None (empty JSON) | You have unearthed Eldritch Invocations, pieces of forbidden knowledge that imbue you with an abiding magical ability... |
| 2 | `warlock_eldritch_invocations` | Eldritch Invocations | **Quarantined** | passive | None | None (empty JSON) | In your study of occult lore, you have unearthed eldritch invocations, fragments of forbidden knowledge that imbue yo... |
| 2 | `warlock_magical_cunning` | Magical Cunning | **Mechanics-Backed** | passive | None | curated: pact_magic_recovery:half_max | You can perform an esoteric rite for 1 minute. At the end of it, you regain expended Pact Magic spell slots but no mo... |
| 3 | `warlock_pact_boon` | Pact Boon | **Quarantined** | passive | None | None (empty JSON) | At 3rd level, your otherworldly patron bestows a gift upon you for your loyal service. You gain one of the following ... |
| 3 | `warlock_warlock_subclass` | Warlock Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Warlock subclass of your choice. A subclass is a specialization that grants you features at certain Warloc... |
| 4 | `warlock_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 4 | `warlock_eldritch_versatility` | Eldritch Versatility | **Quarantined** | passive | None | None (empty JSON) | {@i 4th-level warlock optional class features feature} Whenever you reach a level in this class that grants the Abili... |

### Wizard (9 records: 1 mechanics-backed, 8 quarantined)

| Level | ID | Name | Status | Type / Cost | Uses | JSON Effect Data | Description Summary |
|---:|---|---|---|---|---|---|---|
| 1 | `wizard_arcane_recovery` | Arcane Recovery | **Mechanics-Backed** | passive | None | curated: recover_spell_slots | You have learned to regain some of your magical energy by studying your spellbook. Once per day when you finish a sho... |
| 1 | `wizard_spellcasting` | Spellcasting | **Quarantined** | passive | None | None (empty JSON) | As a student of arcane magic, you have a spellbook containing spells that show the first glimmerings of your true pow... |
| 1 | `wizard_ritual_adept` | Ritual Adept | **Quarantined** | passive | None | None (empty JSON) | You can cast any spell as a Ritual if that spell has the Ritual tag and the spell is in your spellbook. You needn't h... |
| 2 | `wizard_arcane_tradition` | Arcane Tradition | **Quarantined** | passive | None | None (empty JSON) | When you reach 2nd level, you choose an arcane tradition from the list of available traditions, shaping your practice... |
| 2 | `wizard_scholar` | Scholar | **Quarantined** | passive | None | None (empty JSON) | While studying magic, you also specialized in another field of study. Choose one of the following skills in which you... |
| 3 | `wizard_cantrip_formulas` | Cantrip Formulas | **Quarantined** | passive | None | None (empty JSON) | {@i 3rd-level wizard optional class features feature} You have scribed a set of arcane formulas in your spellbook tha... |
| 3 | `wizard_wizard_subclass` | Wizard Subclass | **Quarantined** | passive | None | None (empty JSON) | You gain a Wizard subclass of your choice. A subclass is a specialization that grants you features at certain Wizard ... |
| 4 | `wizard_ability_score_improvement` | Ability Score Improvement | **Quarantined** | passive | None | None (empty JSON) | When you reach 4th level, you can increase one ability score of your choice by 2, or you can increase two ability sco... |
| 5 | `wizard_memorize_spell` | Memorize Spell | **Quarantined** | passive | None | None (empty JSON) | Whenever you finish a Short Rest, you can study your spellbook and replace one of the level 1+ Wizard spells you have... |

---

## Catalog of Mechanics-Backed (Curated) Features (36 Records)

| Class | Level | Feature ID | Feature Name | Curated Effect Summary |
|---|---:|---|---|---|
| `artificer` | 1 | `artificer_tinker's_magic` | Tinker's Magic | `give_item:ball_bearings` |
| `barbarian` | 1 | `barbarian_rage` | Rage | `grant_condition+stat_modifier` |
| `barbarian` | 1 | `barbarian_unarmored_defense` | Unarmored Defense | `unarmored_defense:10+DEX+CON with shield` |
| `barbarian` | 2 | `barbarian_reckless_attack` | Reckless Attack | `reckless_attack` |
| `barbarian` | 5 | `barbarian_extra_attack` | Extra Attack | `extra_attack` |
| `bard` | 1 | `bard_bardic_inspiration` | Bardic Inspiration | `bardic_inspiration` |
| `cleric` | 2 | `cleric_channel_divinity:_harness_divine_power` | Channel Divinity: Harness Divine Power | `recover_spell_slots` |
| `fighter` | 1 | `fighter_second_wind` | Second Wind | `heal_self` |
| `fighter` | 2 | `fighter_action_surge` | Action Surge | `grant_extra_action` |
| `fighter` | 5 | `fighter_extra_attack` | Extra Attack | `extra_attack` |
| `monk` | 1 | `monk_martial_arts` | Martial Arts | `unarmed_attack` |
| `monk` | 1 | `monk_unarmored_defense` | Unarmored Defense | `unarmored_defense` |
| `monk` | 1 | `monk_bonus_unarmed_strike` | Bonus Unarmed Strike | `unarmed_attack` |
| `monk` | 2 | `monk_flurry_of_blows` | Flurry of Blows | `unarmed_attack x2` |
| `monk` | 2 | `monk_patient_defense` | Patient Defense | `grant_condition` |
| `monk` | 2 | `monk_step_of_the_wind` | Step of the Wind | `step_of_the_wind` |
| `monk` | 5 | `monk_extra_attack` | Extra Attack | `extra_attack` |
| `paladin` | 1 | `paladin_divine_sense` | Divine Sense | `divine_sense` |
| `paladin` | 1 | `paladin_lay_on_hands` | Lay on Hands | `lay_on_hands` |
| `paladin` | 2 | `paladin_divine_smite` | Divine Smite | `divine_smite` |
| `paladin` | 2 | `paladin_fighting_style` | Fighting Style | `defense_style:+1 AC while armored` |
| `paladin` | 3 | `paladin_divine_sense` | Divine Sense | `divine_sense` |
| `paladin` | 5 | `paladin_extra_attack` | Extra Attack | `extra_attack` |
| `ranger` | 1 | `ranger_favored_foe` | Favored Foe | `favored_foe` |
| `ranger` | 2 | `ranger_fighting_style` | Fighting Style | `archery:+2 ranged attack` |
| `ranger` | 5 | `ranger_extra_attack` | Extra Attack | `extra_attack` |
| `rogue` | 1 | `rogue_sneak_attack` | Sneak Attack | `sneak_attack` |
| `rogue` | 2 | `rogue_cunning_action` | Cunning Action | `cunning_action` |
| `rogue` | 5 | `rogue_uncanny_dodge` | Uncanny Dodge | `reaction:uncanny_dodge` |
| `sorcerer` | 1 | `sorcerer_innate_sorcery` | Innate Sorcery | `innate_sorcery:+1 spell DC and spell-attack advantage` |
| `sorcerer` | 2 | `sorcerer_sorcery_points` | Sorcery Points | `sorcery_points` |
| `sorcerer` | 2 | `sorcerer_metamagic` | Metamagic | `metamagic` |
| `sorcerer` | 3 | `sorcerer_metamagic` | Metamagic | `metamagic` |
| `warlock` | 1 | `warlock_pact_magic` | Pact Magic | `pact_magic` |
| `warlock` | 2 | `warlock_magical_cunning` | Magical Cunning | `pact_magic_recovery:half_max` |
| `wizard` | 1 | `wizard_arcane_recovery` | Arcane Recovery | `recover_spell_slots` |

---

## Catalog of Quarantined / Effectless Features (157 Records)

| # | Class | Level | Feature ID | Feature Name | Short Description |
|---:|---|---:|---|---|---|
| 1 | `artificer` | 1 | `artificer_spellcasting` | Spellcasting | You have learned how to channel magical energy through objects. See the Player's Handbook for the... |
| 2 | `artificer` | 1 | `artificer_magical_tinkering` | Magical Tinkering | {@i 1st-level artificer feature} You've learned how to invest a spark of magic into mundane objec... |
| 3 | `artificer` | 1 | `artificer_optional_rule:_firearm_proficiency` | Optional Rule: Firearm Proficiency | The secrets of creating and operating gunpowder weapons have been discovered in various corners o... |
| 4 | `artificer` | 2 | `artificer_replicate_magic_item` | Replicate Magic Item | You have learned arcane plans that you use to make magic items. {'type': 'entries', 'entries': [{... |
| 5 | `artificer` | 2 | `artificer_infuse_item` | Infuse Item | {@i 2nd-level artificer feature} You've gained the ability to imbue mundane items with certain ma... |
| 6 | `artificer` | 2 | `artificer_infusions_known` | Infusions Known | When you gain this feature, pick four artificer infusions to learn, choosing from the "{@filter A... |
| 7 | `artificer` | 3 | `artificer_artificer_subclass` | Artificer Subclass | You gain an Artificer subclass of your choice. The {@subclass Alchemist}, {@subclass Armorer}, {@... |
| 8 | `artificer` | 3 | `artificer_artificer_specialist` | Artificer Specialist | {@i 3rd-level artificer feature} Choose the type of specialist you are, each of which is detailed... |
| 9 | `artificer` | 3 | `artificer_the_right_tool_for_the_job` | The Right Tool for the Job | {@i 3rd-level artificer feature} You've learned how to produce exactly the tool you need: with th... |
| 10 | `artificer` | 4 | `artificer_ability_score_improvement` | Ability Score Improvement | You gain the {@feat Ability Score Improvement} feat or another feat of your choice for which you ... |
| 11 | `artificer` | 5 | `artificer_subclass_feature` | Subclass feature | You gain a feature from your Artificer Subclass. |
| 12 | `artificer` | 5 | `artificer_artificer_specialist_feature` | Artificer Specialist Feature | {@i 5th-level artificer feature} You gain a feature granted by your Artificer Specialist choice. |
| 13 | `barbarian` | 1 | `barbarian_weapon_mastery` | Weapon Mastery | Your training with weapons allows you to use the weapon mastery properties properties of two kind... |
| 14 | `barbarian` | 2 | `barbarian_danger_sense` | Danger Sense | At 2nd level, you gain an uncanny sense of when things nearby aren't as they should be, giving yo... |
| 15 | `barbarian` | 3 | `barbarian_primal_knowledge` | Primal Knowledge | {@i 3rd-level barbarian optional class features feature} When you reach 3rd level and again at 10... |
| 16 | `barbarian` | 3 | `barbarian_primal_path` | Primal Path | At 3rd level, you choose a path that shapes the nature of your rage from the list of available pa... |
| 17 | `barbarian` | 3 | `barbarian_barbarian_subclass` | Barbarian Subclass | You gain a Barbarian subclass of your choice. A subclass is a specialization that grants you feat... |
| 18 | `barbarian` | 4 | `barbarian_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 19 | `barbarian` | 5 | `barbarian_fast_movement` | Fast Movement | Starting at 5th level, your speed increases by 10 feet while you aren't wearing heavy armor. |
| 20 | `bard` | 1 | `bard_spellcasting` | Spellcasting | You have learned to untangle and reshape the fabric of reality in harmony with your wishes and mu... |
| 21 | `bard` | 2 | `bard_jack_of_all_trades` | Jack of All Trades | Starting at 2nd level, you can add half your proficiency bonus, rounded down, to any ability chec... |
| 22 | `bard` | 2 | `bard_magical_inspiration` | Magical Inspiration | {@i 2nd-level bard optional class features feature} If a creature has a Bardic Inspiration die fr... |
| 23 | `bard` | 2 | `bard_song_of_rest_(d6)` | Song of Rest (d6) | Beginning at 2nd level, you can use soothing music or oration to help revitalize your wounded all... |
| 24 | `bard` | 2 | `bard_expertise` | Expertise | You gain Expertise in two of your skill proficiencies of your choice. {@skill Performance} and {@... |
| 25 | `bard` | 3 | `bard_bard_college` | Bard College | At 3rd level, you delve into the advanced techniques of a bard college of your choice from the li... |
| 26 | `bard` | 3 | `bard_expertise` | Expertise | At 3rd level, choose two of your skill proficiencies. Your proficiency bonus is doubled for any a... |
| 27 | `bard` | 3 | `bard_bard_subclass` | Bard Subclass | You gain a Bard subclass of your choice. A subclass is a specialization that grants you features ... |
| 28 | `bard` | 4 | `bard_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 29 | `bard` | 4 | `bard_bardic_versatility` | Bardic Versatility | {@i 4th-level bard optional class features feature} Whenever you reach a level in this class that... |
| 30 | `bard` | 5 | `bard_bardic_inspiration_(d8)` | Bardic Inspiration (d8) | At 5th level, your Bardic Inspiration die changes to a d8. |
| 31 | `bard` | 5 | `bard_font_of_inspiration` | Font of Inspiration | Beginning when you reach 5th level, you regain all of your expended uses of Bardic Inspiration wh... |
| 32 | `cleric` | 1 | `cleric_divine_domain` | Divine Domain | Choose one domain related to your deity from the list of available domains. Each domain is detail... |
| 33 | `cleric` | 1 | `cleric_spellcasting` | Spellcasting | As a conduit for divine power, you can cast cleric spells. See chapter 10 for the general rules o... |
| 34 | `cleric` | 1 | `cleric_divine_order` | Divine Order | You have dedicated yourself to one of the following sacred roles of your choice. {'type': 'entrie... |
| 35 | `cleric` | 1 | `cleric_protector` | Protector | Trained for battle, you gain proficiency with {@filter Martial weapons=martial weapon} and traini... |
| 36 | `cleric` | 1 | `cleric_thaumaturge` | Thaumaturge | You know one extra cantrip from the {@filter Cleric spell list=Cleric}. In addition, your mystica... |
| 37 | `cleric` | 2 | `cleric_channel_divinity` | Channel Divinity | At 2nd level, you gain the ability to channel divine energy directly from your deity, using that ... |
| 38 | `cleric` | 2 | `cleric_channel_divinity:_turn_undead` | Channel Divinity: Turn Undead | As an action, you present your holy symbol and speak a prayer censuring the undead. Each undead t... |
| 39 | `cleric` | 2 | `cleric_divine_domain_feature` | Divine Domain feature | At 2nd level, you gain a feature from your Divine Domain. |
| 40 | `cleric` | 2 | `cleric_divine_spark` | Divine Spark | As a {@action Magic} action, you point your Holy Symbol at another creature you can see within 30... |
| 41 | `cleric` | 2 | `cleric_turn_undead` | Turn Undead | As a {@action Magic} action, you present your Holy Symbol and censure Undead creatures. Each Unde... |
| 42 | `cleric` | 3 | `cleric_cleric_subclass` | Cleric Subclass | You gain a Cleric subclass of your choice. A subclass is a specialization that grants you feature... |
| 43 | `cleric` | 4 | `cleric_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 44 | `cleric` | 4 | `cleric_cantrip_versatility` | Cantrip Versatility | {@i 4th-level cleric optional class features feature} Whenever you reach a level in this class th... |
| 45 | `cleric` | 5 | `cleric_destroy_undead_(cr_1/2)` | Destroy Undead (CR 1/2) | Starting at 5th level, when an {@filter undead of CR 1/2 or lower rating=[&0;&1/2]=undead=!swarm}... |
| 46 | `cleric` | 5 | `cleric_sear_undead` | Sear Undead | Whenever you use Turn Undead, you can roll a number of d8s equal to your Wisdom modifier (minimum... |
| 47 | `druid` | 1 | `druid_druidic` | Druidic | You know {@language Druidic}, the secret language of druids. You can speak the language and use i... |
| 48 | `druid` | 1 | `druid_spellcasting` | Spellcasting | Drawing on the divine essence of nature itself, you can cast spells to shape that essence to your... |
| 49 | `druid` | 1 | `druid_magician` | Magician | You know one extra cantrip from the {@filter Druid spell list=Druid}. In addition, your mystical ... |
| 50 | `druid` | 1 | `druid_primal_order` | Primal Order | You have dedicated yourself to one of the following sacred roles of your choice. {'type': 'entrie... |
| 51 | `druid` | 1 | `druid_warden` | Warden | Trained for battle, you gain proficiency with {@filter Martial weapons=martial weapon} and traini... |
| 52 | `druid` | 2 | `druid_druid_circle` | Druid Circle | At 2nd level, you choose to identify with a circle of druids from the list of available circles. ... |
| 53 | `druid` | 2 | `druid_wild_companion` | Wild Companion | {@i 2nd-level druid optional class features feature} You gain the ability to summon a spirit that... |
| 54 | `druid` | 2 | `druid_wild_shape` | Wild Shape | Starting at 2nd level, you can use your action to magically assume the shape of a beast that you ... |
| 55 | `druid` | 3 | `druid_druid_subclass` | Druid Subclass | You gain a Druid subclass of your choice. A subclass is a specialization that grants you features... |
| 56 | `druid` | 4 | `druid_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 57 | `druid` | 4 | `druid_cantrip_versatility` | Cantrip Versatility | {@i 4th-level druid optional class features feature} Whenever you reach a level in this class tha... |
| 58 | `druid` | 4 | `druid_wild_shape_improvement` | Wild Shape Improvement | At 4th level, your Wild Shape improves as shown on the Beast Shapes table. |
| 59 | `druid` | 5 | `druid_wild_resurgence` | Wild Resurgence | Once on each of your turns, if you have no uses of Wild Shape left, you can give yourself one use... |
| 60 | `fighter` | 1 | `fighter_fighting_style` | Fighting Style | You adopt a particular style of fighting as your specialty. Choose one of the following options. ... |
| 61 | `fighter` | 1 | `fighter_weapon_mastery` | Weapon Mastery | Your training with weapons allows you to use the weapon mastery properties properties of three ki... |
| 62 | `fighter` | 2 | `fighter_tactical_mind` | Tactical Mind | You have a mind for tactics on and off the battlefield. When you fail an ability check, you can e... |
| 63 | `fighter` | 3 | `fighter_martial_archetype` | Martial Archetype | At 3rd level, you choose an archetype from the list available that you strive to emulate in your ... |
| 64 | `fighter` | 3 | `fighter_fighter_subclass` | Fighter Subclass | You gain a Fighter subclass of your choice. A subclass is a specialization that grants you featur... |
| 65 | `fighter` | 4 | `fighter_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 66 | `fighter` | 4 | `fighter_martial_versatility` | Martial Versatility | {@i 4th-level fighter optional class features feature} Whenever you reach a level in this class t... |
| 67 | `fighter` | 5 | `fighter_tactical_shift` | Tactical Shift | Whenever you activate your Second Wind with a Bonus Action, you can move up to half your Speed wi... |
| 68 | `monk` | 1 | `monk_dexterous_attacks` | Dexterous Attacks | You can use your Dexterity modifier instead of your Strength modifier for the attack and damage r... |
| 69 | `monk` | 1 | `monk_martial_arts_die` | Martial Arts Die | You can roll 1d6 in place of the normal damage of your Unarmed Strike or Monk weapons. This die c... |
| 70 | `monk` | 2 | `monk_dedicated_weapon` | Dedicated Weapon | {@i 2nd-level monk optional class features feature} You train yourself to use a variety of weapon... |
| 71 | `monk` | 2 | `monk_ki` | Ki | Starting at 2nd level, your training allows you to harness the mystic energy of ki. Your access t... |
| 72 | `monk` | 2 | `monk_unarmored_movement` | Unarmored Movement | Starting at 2nd level, your speed increases by 10 feet while you are not wearing armor or wieldin... |
| 73 | `monk` | 2 | `monk_monk's_focus` | Monk's Focus | Your focus and martial training allow you to harness a well of extraordinary energy within yourse... |
| 74 | `monk` | 2 | `monk_uncanny_metabolism` | Uncanny Metabolism | When you roll Initiative, you can regain all expended Focus Points. When you do so, roll your Mar... |
| 75 | `monk` | 3 | `monk_deflect_missiles` | Deflect Missiles | Starting at 3rd level, you can use your reaction to deflect or catch the missile when you are hit... |
| 76 | `monk` | 3 | `monk_ki-fueled_attack` | Ki-Fueled Attack | {@i 3rd-level monk optional class features feature} If you spend 1 ki point or more as part of yo... |
| 77 | `monk` | 3 | `monk_monastic_tradition` | Monastic Tradition | When you reach 3rd level, you commit yourself to a monastic tradition, chosen from the list of av... |
| 78 | `monk` | 3 | `monk_deflect_attacks` | Deflect Attacks | When an attack roll hits you and its damage includes Bludgeoning, Piercing, or Slashing damage, y... |
| 79 | `monk` | 3 | `monk_monk_subclass` | Monk Subclass | You gain a Monk subclass of your choice. A subclass is a specialization that grants you features ... |
| 80 | `monk` | 4 | `monk_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 81 | `monk` | 4 | `monk_quickened_healing` | Quickened Healing | {@i 4th-level monk optional class features feature} As an action, you can spend 2 ki points and r... |
| 82 | `monk` | 4 | `monk_slow_fall` | Slow Fall | Beginning at 4th level, you can use your reaction when you fall to reduce any falling damage you ... |
| 83 | `monk` | 5 | `monk_focused_aim` | Focused Aim | {@i 5th-level monk optional class features feature} When you miss with an attack roll, you can sp... |
| 84 | `monk` | 5 | `monk_stunning_strike` | Stunning Strike | Starting at 5th level, you can interfere with the flow of ki in an opponent's body. When you hit ... |
| 85 | `mystic` | 1 | `mystic_mystic_order` | Mystic Order | At 1st level, you choose a Mystic Order from the list of available orders. Each order specializes... |
| 86 | `mystic` | 1 | `mystic_psionic_disciplines_and_talents` | Psionic Disciplines and Talents | {@filter Psionic talents=T} and {@filter disciplines=D} are the heart of a mystic's craft. They a... |
| 87 | `mystic` | 1 | `mystic_psionics` | Psionics | As a student of psionics, you can master and use psionic talents and disciplines, the rules for w... |
| 88 | `mystic` | 1 | `mystic_using_a_discipline` | Using a Discipline | Each psionic discipline has several ways you can use it, all contained in its description. The di... |
| 89 | `mystic` | 2 | `mystic_mystical_recovery` | Mystical Recovery | Starting at 2nd level, you can draw vigor from the psi energy you use to power your psionic disci... |
| 90 | `mystic` | 2 | `mystic_telepathy` | Telepathy | At 2nd level, your mind awakens to the ability to communicate via telepathy. You can telepathical... |
| 91 | `mystic` | 3 | `mystic_mystic_order_feature` | Mystic Order feature | At 3rd level, you gain another feature from your Mystic Order. |
| 92 | `mystic` | 4 | `mystic_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, and again at 8th, 12th, 16th, and 19th level, you can increase one abil... |
| 93 | `mystic` | 4 | `mystic_strength_of_mind` | Strength of Mind | Even the simplest psionic technique requires a deep understanding of how psionic energy can augme... |
| 94 | `paladin` | 1 | `paladin_spellcasting` | Spellcasting | You have learned to cast spells through prayer and meditation. See chapter 7 for the rules on spe... |
| 95 | `paladin` | 1 | `paladin_weapon_mastery` | Weapon Mastery | Your training with weapons allows you to use the weapon mastery properties properties of two kind... |
| 96 | `paladin` | 2 | `paladin_spellcasting` | Spellcasting | By 2nd level, you have learned to draw on divine magic through meditation and prayer to cast spel... |
| 97 | `paladin` | 2 | `paladin_paladin's_smite` | Paladin's Smite | You always have the Divine Smite spell prepared. In addition, you can cast it without expending a... |
| 98 | `paladin` | 3 | `paladin_channel_divinity` | Channel Divinity | Your oath allows you to channel divine energy to fuel magical effects. Each Channel Divinity opti... |
| 99 | `paladin` | 3 | `paladin_channel_divinity:_harness_divine_power` | Channel Divinity: Harness Divine Power | {@i 3rd-level paladin optional class features feature} You can expend a use of your Channel Divin... |
| 100 | `paladin` | 3 | `paladin_divine_health` | Divine Health | By 3rd level, the divine magic flowing through you makes you immune to disease. |
| 101 | `paladin` | 3 | `paladin_sacred_oath` | Sacred Oath | When you reach 3rd level, you swear the oath that binds you as a paladin forever. Up to this time... |
| 102 | `paladin` | 3 | `paladin_paladin_subclass` | Paladin Subclass | You gain a Paladin subclass of your choice. A subclass is a specialization that grants you featur... |
| 103 | `paladin` | 4 | `paladin_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 104 | `paladin` | 4 | `paladin_martial_versatility` | Martial Versatility | {@i 4th-level paladin optional class features feature} Whenever you reach a level in this class t... |
| 105 | `paladin` | 5 | `paladin_faithful_steed` | Faithful Steed | You can call on the aid of an otherworldly steed. You always have the Find Steed spell prepared. ... |
| 106 | `ranger` | 1 | `ranger_deft_explorer` | Deft Explorer | {@i 1st-level ranger optional class features feature, which replaces the Natural Explorer feature... |
| 107 | `ranger` | 1 | `ranger_favored_enemy` | Favored Enemy | Beginning at 1st level, you have significant experience studying, tracking, hunting, and even tal... |
| 108 | `ranger` | 1 | `ranger_natural_explorer` | Natural Explorer | You are particularly familiar with one type of natural environment and are adept at traveling and... |
| 109 | `ranger` | 1 | `ranger_spellcasting` | Spellcasting | You have learned to channel the magical essence of nature to cast spells. See chapter 7 for the r... |
| 110 | `ranger` | 1 | `ranger_weapon_mastery` | Weapon Mastery | Your training with weapons allows you to use the weapon mastery properties properties of two kind... |
| 111 | `ranger` | 2 | `ranger_spellcasting` | Spellcasting | By the time you reach 2nd level, you have learned to use the magical essence of nature to cast sp... |
| 112 | `ranger` | 2 | `ranger_spellcasting_focus` | Spellcasting Focus | {@i 2nd-level ranger optional class features feature} You can use a druidic focus as a spellcasti... |
| 113 | `ranger` | 2 | `ranger_deft_explorer` | Deft Explorer | Thanks to your travels, you gain the following benefits. {'type': 'entries', 'entries': [{'type':... |
| 114 | `ranger` | 3 | `ranger_primal_awareness` | Primal Awareness | {@i 3rd-level ranger optional class features feature, which replaces the Primeval Awareness featu... |
| 115 | `ranger` | 3 | `ranger_primeval_awareness` | Primeval Awareness | Beginning at 3rd level, you can use your action and expend one ranger spell slot to focus your aw... |
| 116 | `ranger` | 3 | `ranger_ranger_archetype` | Ranger Archetype | At 3rd level, you choose an archetype that you strive to emulate from the list of available arche... |
| 117 | `ranger` | 3 | `ranger_ranger_subclass` | Ranger Subclass | You gain a Ranger subclass of your choice. A subclass is a specialization that grants you feature... |
| 118 | `ranger` | 4 | `ranger_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 119 | `ranger` | 4 | `ranger_martial_versatility` | Martial Versatility | {@i 4th-level ranger optional class features feature} Whenever you reach a level in this class th... |
| 120 | `rogue` | 1 | `rogue_expertise` | Expertise | At 1st level, choose two of your skill proficiencies, or one of your skill proficiencies and your... |
| 121 | `rogue` | 1 | `rogue_thieves'_cant` | Thieves' Cant | During your rogue training you learned thieves' cant, a secret mix of dialect, jargon, and code t... |
| 122 | `rogue` | 1 | `rogue_weapon_mastery` | Weapon Mastery | Your training with weapons allows you to use the weapon mastery properties properties of two kind... |
| 123 | `rogue` | 3 | `rogue_roguish_archetype` | Roguish Archetype | At 3rd level, you choose an archetype that you emulate in the exercise of your rogue abilities fr... |
| 124 | `rogue` | 3 | `rogue_steady_aim` | Steady Aim | {@i 3rd-level rogue optional class features feature} As a bonus action, you give yourself advanta... |
| 125 | `rogue` | 3 | `rogue_rogue_subclass` | Rogue Subclass | You gain a Rogue subclass of your choice. A subclass is a specialization that grants you features... |
| 126 | `rogue` | 4 | `rogue_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 127 | `rogue` | 5 | `rogue_cunning_strike` | Cunning Strike | You've developed cunning ways to use your Sneak Attack. When you deal Sneak Attack damage, you ca... |
| 128 | `rogue` | 5 | `rogue_poison_(cost:_1d6)` | Poison (Cost: 1d6) | You add a toxin to your strike, forcing the target to make a Constitution saving throw. On a fail... |
| 129 | `rogue` | 5 | `rogue_trip_(cost:_1d6)` | Trip (Cost: 1d6) | If the target is Large or smaller, it must succeed on a Dexterity saving throw or have the Prone ... |
| 130 | `rogue` | 5 | `rogue_withdraw_(cost:_1d6)` | Withdraw (Cost: 1d6) | Immediately after the attack, you move up to half your Speed without provoking {@action Opportuni... |
| 131 | `sorcerer` | 1 | `sorcerer_sorcerous_origin` | Sorcerous Origin | Choose a sorcerous origin, which describes the source of your innate magical power, from the list... |
| 132 | `sorcerer` | 1 | `sorcerer_spellcasting` | Spellcasting | An event in your past, or in the life of a parent or ancestor, left an indelible mark on you, inf... |
| 133 | `sorcerer` | 2 | `sorcerer_flexible_casting` | Flexible Casting | You can use your sorcery points to gain additional spell slots, or sacrifice spell slots to gain ... |
| 134 | `sorcerer` | 2 | `sorcerer_font_of_magic` | Font of Magic | At 2nd level, you tap into a deep wellspring of magic within yourself. This wellspring is represe... |
| 135 | `sorcerer` | 2 | `sorcerer_metamagic_options` | Metamagic Options | The following options are available to your Metamagic feature. The options are presented in alpha... |
| 136 | `sorcerer` | 3 | `sorcerer_metamagic_options` | Metamagic Options | {@i 3rd-level sorcerer optional class features feature} When you choose Metamagic options, you ha... |
| 137 | `sorcerer` | 3 | `sorcerer_sorcerer_subclass` | Sorcerer Subclass | You gain a Sorcerer subclass of your choice. A subclass is a specialization that grants you featu... |
| 138 | `sorcerer` | 4 | `sorcerer_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 139 | `sorcerer` | 4 | `sorcerer_sorcerous_versatility` | Sorcerous Versatility | {@i 4th-level sorcerer optional class features feature} Whenever you reach a level in this class ... |
| 140 | `sorcerer` | 5 | `sorcerer_magical_guidance` | Magical Guidance | {@i 5th-level sorcerer optional class features feature} You can tap into your inner wellspring of... |
| 141 | `sorcerer` | 5 | `sorcerer_sorcerous_restoration` | Sorcerous Restoration | When you finish a Short Rest, you can regain expended Sorcery Points, but no more than a number e... |
| 142 | `warlock` | 1 | `warlock_otherworldly_patron` | Otherworldly Patron | At 1st level, you have struck a bargain with an otherworldly being chosen from the list of availa... |
| 143 | `warlock` | 1 | `warlock_eldritch_invocation_options` | Eldritch Invocation Options | Eldritch Invocation options appear in alphabetical order. {'type': 'options', 'count': 1, 'entrie... |
| 144 | `warlock` | 1 | `warlock_eldritch_invocations` | Eldritch Invocations | You have unearthed Eldritch Invocations, pieces of forbidden knowledge that imbue you with an abi... |
| 145 | `warlock` | 2 | `warlock_eldritch_invocations` | Eldritch Invocations | In your study of occult lore, you have unearthed eldritch invocations, fragments of forbidden kno... |
| 146 | `warlock` | 3 | `warlock_pact_boon` | Pact Boon | At 3rd level, your otherworldly patron bestows a gift upon you for your loyal service. You gain o... |
| 147 | `warlock` | 3 | `warlock_warlock_subclass` | Warlock Subclass | You gain a Warlock subclass of your choice. A subclass is a specialization that grants you featur... |
| 148 | `warlock` | 4 | `warlock_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 149 | `warlock` | 4 | `warlock_eldritch_versatility` | Eldritch Versatility | {@i 4th-level warlock optional class features feature} Whenever you reach a level in this class t... |
| 150 | `wizard` | 1 | `wizard_spellcasting` | Spellcasting | As a student of arcane magic, you have a spellbook containing spells that show the first glimmeri... |
| 151 | `wizard` | 1 | `wizard_ritual_adept` | Ritual Adept | You can cast any spell as a Ritual if that spell has the Ritual tag and the spell is in your spel... |
| 152 | `wizard` | 2 | `wizard_arcane_tradition` | Arcane Tradition | When you reach 2nd level, you choose an arcane tradition from the list of available traditions, s... |
| 153 | `wizard` | 2 | `wizard_scholar` | Scholar | While studying magic, you also specialized in another field of study. Choose one of the following... |
| 154 | `wizard` | 3 | `wizard_cantrip_formulas` | Cantrip Formulas | {@i 3rd-level wizard optional class features feature} You have scribed a set of arcane formulas i... |
| 155 | `wizard` | 3 | `wizard_wizard_subclass` | Wizard Subclass | You gain a Wizard subclass of your choice. A subclass is a specialization that grants you feature... |
| 156 | `wizard` | 4 | `wizard_ability_score_improvement` | Ability Score Improvement | When you reach 4th level, you can increase one ability score of your choice by 2, or you can incr... |
| 157 | `wizard` | 5 | `wizard_memorize_spell` | Memorize Spell | Whenever you finish a Short Rest, you can study your spellbook and replace one of the level 1+ Wi... |
