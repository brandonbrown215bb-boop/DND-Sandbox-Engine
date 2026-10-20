## Data Loader
## Autoloaded singleton for deterministic, validated content registration.
## Core records are loaded before mods. Every collision must be named in
## data/content_manifest.json so precedence cannot depend on enumeration order.
extends Node

signal data_loaded
signal load_error(message: String)

var classes: Dictionary = {}
var subclasses: Dictionary = {}
var races: Dictionary = {}
## Batch 049: feats are a content type so species can grant them by id.
var feats: Dictionary = {}
var items: Dictionary = {}
var spells: Dictionary = {}
var monsters: Dictionary = {}
var events: Dictionary = {}
var campaigns: Dictionary = {}

const CORE_PATH := "res://data/core/"
const MODS_PATH := "res://data/mods/"
const MANIFEST_PATH := "res://data/content_manifest.json"

const CURATED_SPELL_ACCESS := {
	"artificer": {
		"0": ["fire_bolt"],
		"1": ["cure_wounds"],
		"2": ["misty_step"],
	},
	"bard": {
		"0": ["blade_ward", "dancing_lights", "guidance", "light", "mage_hand", "mending", "message", "minor_illusion", "prestidigitation", "starry_wisp", "true_strike", "vicious_mockery"],
		"1": ["animal_friendship", "bane", "charm_person", "color_spray", "command", "comprehend_languages", "cure_wounds", "detect_magic", "disguise_self", "dissonant_whispers", "faerie_fire", "feather_fall", "healing_word", "heroism", "identify", "illusory_script", "longstrider", "silent_image", "sleep", "speak_with_animals", "tashas_hideous_laughter", "thunderwave", "unseen_servant"],
		"2": ["aid", "animal_messenger", "blindness/deafness", "calm_emotions", "detect_thoughts", "enhance_ability", "enlarge/reduce", "enthrall", "heat_metal", "hold_person", "invisibility", "knock", "lesser_restoration", "locate_animals_or_plants", "locate_object", "magic_mouth", "mirror_image", "misty_step", "see_invisibility", "shatter", "silence", "suggestion", "zone_of_truth"],
		"3": ["bestow_curse", "clairvoyance", "dispel_magic", "fear", "glyph_of_warding", "hypnotic_pattern", "leomunds_tiny_hut", "major_image", "mass_healing_word", "nondetection", "plant_growth", "sending", "slow", "speak_with_dead", "speak_with_plants", "stinking_cloud", "tongues"],
		"4": ["charm_monster", "compulsion", "confusion", "dimension_door", "freedom_of_movement", "greater_invisibility", "hallucinatory_terrain", "locate_creature", "phantasmal_killer", "polymorph"],
		"5": ["animate_objects", "awaken", "dominate_person", "dream", "geas", "greater_restoration", "hold_monster", "legend_lore", "mass_cure_wounds", "mislead", "modify_memory", "planar_binding", "raise_dead", "scrying", "seeming", "telepathic_bond", "teleportation_circle"],
		"6": ["eyebite", "find_the_path", "guards_and_wards", "heroes_feast", "irresistible_dance", "mass_suggestion", "programmed_illusion", "true_seeing"],
		"7": ["arcane_sword", "etherealness", "forcecage", "magnificent_mansion", "mirage_arcane", "prismatic_spray", "project_image", "regenerate", "resurrection", "symbol", "teleport"],
		"8": ["antipathy_sympathy", "befuddlement", "dominate_monster", "glibness", "mind_blank", "power_word_stun"],
		"9": ["foresight", "power_word_heal", "power_word_kill", "prismatic_wall", "true_polymorph"],
	},
	"cleric": {
		"0": ["guidance", "light", "mending", "resistance", "sacred_flame", "spare_the_dying", "thaumaturgy"],
		"1": ["bane", "bless", "command", "create_or_destroy_water", "cure_wounds", "detect_evil_and_good", "detect_magic", "detect_poison_and_disease", "guiding_bolt", "healing_word", "inflict_wounds", "protection_from_evil_and_good", "purify_food_and_drink", "sanctuary", "shield_of_faith"],
		"2": ["aid", "augury", "blindness/deafness", "calm_emotions", "continual_flame", "enhance_ability", "find_traps", "gentle_repose", "hold_person", "lesser_restoration", "locate_object", "prayer_of_healing", "protection_from_poison", "silence", "spiritual_weapon", "warding_bond", "zone_of_truth"],
		"3": ["animate_dead", "beacon_of_hope", "bestow_curse", "clairvoyance", "create_food_and_water", "daylight", "dispel_magic", "glyph_of_warding", "magic_circle", "mass_healing_word", "meld_into_stone", "protection_from_energy", "remove_curse", "revivify", "sending", "speak_with_dead", "spirit_guardians", "tongues", "water_walk"],
		"4": ["aura_of_life", "banishment", "control_water", "death_ward", "divination", "freedom_of_movement", "guardian_of_faith", "locate_creature", "stone_shape"],
		"5": ["commune", "contagion", "dispel_evil_and_good", "flame_strike", "geas", "greater_restoration", "hallow", "insect_plague", "legend_lore", "mass_cure_wounds", "planar_binding", "raise_dead", "scrying"],
		"6": ["blade_barrier", "create_undead", "find_the_path", "forbiddance", "harm", "heal", "heroes_feast", "planar_ally", "sunbeam", "true_seeing", "word_of_recall"],
		"7": ["conjure_celestial", "divine_word", "etherealness", "fire_storm", "plane_shift", "regenerate", "resurrection", "symbol"],
		"8": ["antimagic_field", "control_weather", "earthquake", "holy_aura", "sunburst"],
		"9": ["astral_projection", "gate", "mass_heal", "power_word_heal", "true_resurrection"],
	},
	"druid": {
		"0": ["druidcraft", "elementalism", "guidance", "mending", "message", "poison_spray", "produce_flame", "ray_of_frost", "resistance", "shillelagh", "spare_the_dying", "starry_wisp"],
		"1": ["animal_friendship", "charm_person", "create_or_destroy_water", "cure_wounds", "detect_magic", "detect_poison_and_disease", "entangle", "faerie_fire", "fog_cloud", "goodberry", "healing_word", "ice_knife", "jump", "longstrider", "protection_from_evil_and_good", "purify_food_and_drink", "speak_with_animals", "thunderwave"],
		"2": ["aid", "animal_messenger", "augury", "barkskin", "continual_flame", "darkvision", "enhance_ability", "enlarge/reduce", "find_traps", "flame_blade", "flaming_sphere", "gust_of_wind", "heat_metal", "hold_person", "lesser_restoration", "locate_animals_or_plants", "locate_object", "misty_step", "moonbeam", "pass_without_trace", "protection_from_poison", "spike_growth"],
		"3": ["call_lightning", "conjure_animals", "daylight", "dispel_magic", "meld_into_stone", "plant_growth", "protection_from_energy", "revivify", "sleet_storm", "speak_with_plants", "water_breathing", "water_walk", "wind_wall"],
		"4": ["blight", "charm_monster", "confusion", "conjure_minor_elementals", "conjure_woodland_beings", "control_water", "divination", "dominate_beast", "fire_shield", "freedom_of_movement", "giant_insect", "hallucinatory_terrain", "ice_storm", "locate_creature", "polymorph", "stone_shape", "stoneskin", "wall_of_fire"],
		"5": ["antilife_shell", "awaken", "commune_with_nature", "cone_of_cold", "conjure_elemental", "contagion", "geas", "greater_restoration", "insect_plague", "mass_cure_wounds", "planar_binding", "reincarnate", "scrying", "tree_stride", "wall_of_stone"],
		"6": ["conjure_fey", "find_the_path", "flesh_to_stone", "heal", "heroes_feast", "move_earth", "sunbeam", "transport_via_plants", "wall_of_thorns", "wind_walk"],
		"7": ["fire_storm", "mirage_arcane", "plane_shift", "regenerate", "reverse_gravity", "symbol"],
		"8": ["animal_shapes", "antipathy_sympathy", "befuddlement", "control_weather", "earthquake", "incendiary_cloud", "sunburst", "tsunami"],
		"9": ["foresight", "shapechange", "storm_of_vengeance", "true_resurrection"],
	},
	"paladin": {
		"1": ["bless", "command", "cure_wounds", "detect_evil_and_good", "detect_magic", "detect_poison_and_disease", "divine_favor", "divine_smite", "heroism", "protection_from_evil_and_good", "purify_food_and_drink", "searing_smite", "shield_of_faith"],
		"2": ["aid", "find_steed", "gentle_repose", "lesser_restoration", "locate_object", "magic_weapon", "prayer_of_healing", "protection_from_poison", "shining_smite", "warding_bond", "zone_of_truth"],
		"3": ["create_food_and_water", "daylight", "dispel_magic", "magic_circle", "remove_curse", "revivify"],
		"4": ["aura_of_life", "banishment", "death_ward", "locate_creature"],
		"5": ["dispel_evil_and_good", "geas", "greater_restoration", "raise_dead"],
	},
	"ranger": {
		"1": ["alarm", "animal_friendship", "cure_wounds", "detect_magic", "detect_poison_and_disease", "ensnaring_strike", "entangle", "fog_cloud", "goodberry", "hunters_mark", "jump", "longstrider", "speak_with_animals"],
		"2": ["aid", "animal_messenger", "barkskin", "darkvision", "enhance_ability", "find_traps", "gust_of_wind", "lesser_restoration", "locate_animals_or_plants", "locate_object", "magic_weapon", "misty_step", "pass_without_trace", "protection_from_poison", "silence", "spike_growth"],
		"3": ["conjure_animals", "daylight", "dispel_magic", "meld_into_stone", "nondetection", "plant_growth", "protection_from_energy", "revivify", "speak_with_plants", "water_breathing", "water_walk", "wind_wall"],
		"4": ["conjure_woodland_beings", "dominate_beast", "freedom_of_movement", "locate_creature", "stoneskin"],
		"5": ["commune_with_nature", "greater_restoration", "tree_stride"],
	},
	"sorcerer": {
		"0": ["acid_splash", "blade_ward", "chill_touch", "dancing_lights", "elementalism", "fire_bolt", "light", "mage_hand", "mending", "message", "minor_illusion", "poison_spray", "prestidigitation", "ray_of_frost", "shocking_grasp", "sorcerous_burst", "true_strike"],
		"1": ["burning_hands", "charm_person", "chromatic_orb", "color_spray", "comprehend_languages", "detect_magic", "disguise_self", "expeditious_retreat", "false_life", "feather_fall", "fog_cloud", "grease", "ice_knife", "jump", "mage_armor", "magic_missile", "ray_of_sickness", "shield", "silent_image", "sleep", "thunderwave"],
		"2": ["alter_self", "blindness/deafness", "blur", "darkness", "darkvision", "detect_thoughts", "dragons_breath", "enhance_ability", "enlarge/reduce", "flame_blade", "flaming_sphere", "gust_of_wind", "hold_person", "invisibility", "knock", "levitate", "magic_weapon", "mirror_image", "misty_step", "scorching_ray", "see_invisibility", "shatter", "spider_climb", "suggestion", "web"],
		"3": ["blink", "clairvoyance", "counterspell", "daylight", "dispel_magic", "fear", "fireball", "fly", "gaseous_form", "haste", "hypnotic_pattern", "lightning_bolt", "major_image", "protection_from_energy", "sleet_storm", "slow", "stinking_cloud", "tongues", "vampiric_touch", "water_breathing", "water_walk"],
		"4": ["banishment", "blight", "charm_monster", "confusion", "dimension_door", "dominate_beast", "fire_shield", "greater_invisibility", "ice_storm", "polymorph", "stoneskin", "vitriolic_sphere", "wall_of_fire"],
		"5": ["animate_objects", "arcane_hand", "cloudkill", "cone_of_cold", "creation", "dominate_person", "hold_monster", "insect_plague", "seeming", "telekinesis", "teleportation_circle", "wall_of_stone"],
		"6": ["chain_lightning", "circle_of_death", "disintegrate", "eyebite", "flesh_to_stone", "freezing_sphere", "globe_of_invulnerability", "mass_suggestion", "move_earth", "sunbeam", "true_seeing"],
		"7": ["delayed_blast_fireball", "etherealness", "finger_of_death", "fire_storm", "plane_shift", "prismatic_spray", "reverse_gravity", "teleport"],
		"8": ["demiplane", "dominate_monster", "earthquake", "incendiary_cloud", "power_word_stun", "sunburst"],
		"9": ["gate", "meteor_swarm", "power_word_kill", "time_stop", "wish"],
	},
	"warlock": {
		"0": ["blade_ward", "chill_touch", "eldritch_blast", "fire_bolt", "mage_hand", "minor_illusion", "poison_spray", "prestidigitation", "true_strike"],
		"1": ["bane", "charm_person", "comprehend_languages", "detect_magic", "expeditious_retreat", "hellish_rebuke", "hex", "illusory_script", "magic_missile", "protection_from_evil_and_good", "speak_with_animals", "tashas_hideous_laughter", "unseen_servant"],
		"2": ["darkness", "enthrall", "hold_person", "invisibility", "mind_spike", "mirror_image", "misty_step", "ray_of_enfeeblement", "spider_climb", "suggestion"],
		"3": ["counterspell", "dispel_magic", "fear", "fly", "gaseous_form", "hypnotic_pattern", "magic_circle", "major_image", "remove_curse", "tongues", "vampiric_touch"],
		"4": ["banishment", "blight", "charm_monster", "dimension_door", "hallucinatory_terrain"],
		"5": ["contact_other_plane", "dream", "hold_monster", "mislead", "planar_binding", "scrying", "teleportation_circle"],
		"6": ["circle_of_death", "create_undead", "eyebite", "true_seeing"],
		"7": ["etherealness", "finger_of_death", "forcecage", "plane_shift"],
		"8": ["befuddlement", "demiplane", "dominate_monster", "glibness", "power_word_stun"],
		"9": ["astral_projection", "foresight", "gate", "imprisonment", "power_word_kill", "true_polymorph", "weird"],
	},
	"wizard": {
		"0": ["acid_splash", "blade_ward", "chill_touch", "dancing_lights", "elementalism", "fire_bolt", "light", "mage_hand", "mending", "message", "minor_illusion", "poison_spray", "prestidigitation", "ray_of_frost", "shocking_grasp", "true_strike"],
		"1": ["alarm", "burning_hands", "charm_person", "chromatic_orb", "color_spray", "comprehend_languages", "detect_magic", "disguise_self", "expeditious_retreat", "false_life", "feather_fall", "find_familiar", "fog_cloud", "grease", "ice_knife", "identify", "illusory_script", "jump", "longstrider", "mage_armor", "magic_missile", "protection_from_evil_and_good", "ray_of_sickness", "shield", "silent_image", "sleep", "tashas_hideous_laughter", "tensers_floating_disk", "thunderwave", "unseen_servant"],
		"2": ["alter_self", "arcane_lock", "augury", "blindness/deafness", "blur", "continual_flame", "darkness", "darkvision", "detect_thoughts", "dragons_breath", "enhance_ability", "enlarge/reduce", "flaming_sphere", "gentle_repose", "gust_of_wind", "hold_person", "invisibility", "knock", "levitate", "locate_object", "magic_mouth", "magic_weapon", "melfs_acid_arrow", "mind_spike", "mirror_image", "misty_step", "nystuls_magic_aura", "ray_of_enfeeblement", "rope_trick", "scorching_ray", "see_invisibility", "shatter", "spider_climb", "suggestion", "web"],
		"3": ["animate_dead", "bestow_curse", "blink", "clairvoyance", "counterspell", "dispel_magic", "fear", "fireball", "fly", "gaseous_form", "glyph_of_warding", "haste", "hypnotic_pattern", "leomunds_tiny_hut", "lightning_bolt", "magic_circle", "major_image", "nondetection", "phantom_steed", "protection_from_energy", "remove_curse", "sending", "sleet_storm", "slow", "speak_with_dead", "stinking_cloud", "tongues", "vampiric_touch", "water_breathing"],
		"4": ["arcane_eye", "banishment", "black_tentacles", "blight", "charm_monster", "confusion", "conjure_minor_elementals", "control_water", "dimension_door", "divination", "fabricate", "faithful_hound", "fire_shield", "greater_invisibility", "hallucinatory_terrain", "ice_storm", "locate_creature", "phantasmal_killer", "polymorph", "private_sanctum", "resilient_sphere", "secret_chest", "stone_shape", "stoneskin", "vitriolic_sphere", "wall_of_fire"],
		"5": ["animate_objects", "arcane_hand", "cloudkill", "cone_of_cold", "conjure_elemental", "contact_other_plane", "creation", "dominate_person", "dream", "geas", "hold_monster", "legend_lore", "mislead", "modify_memory", "passwall", "planar_binding", "scrying", "seeming", "summon_dragon", "telekinesis", "telepathic_bond", "teleportation_circle", "wall_of_force", "wall_of_stone"],
		"6": ["chain_lightning", "circle_of_death", "contingency", "create_undead", "disintegrate", "eyebite", "flesh_to_stone", "freezing_sphere", "globe_of_invulnerability", "guards_and_wards", "instant_summons", "irresistible_dance", "magic_jar", "mass_suggestion", "move_earth", "programmed_illusion", "sunbeam", "true_seeing", "wall_of_ice"],
		"7": ["arcane_sword", "delayed_blast_fireball", "etherealness", "finger_of_death", "forcecage", "magnificent_mansion", "mirage_arcane", "plane_shift", "prismatic_spray", "project_image", "reverse_gravity", "sequester", "simulacrum", "symbol", "teleport"],
		"8": ["antimagic_field", "antipathy_sympathy", "befuddlement", "clone", "control_weather", "demiplane", "dominate_monster", "incendiary_cloud", "maze", "mind_blank", "power_word_stun", "sunburst"],
		"9": ["astral_projection", "foresight", "gate", "imprisonment", "meteor_swarm", "power_word_kill", "prismatic_wall", "shapechange", "time_stop", "true_polymorph", "weird", "wish"],
	},
}

const CURATED_PACT_MAGIC := {
	"1": {"slot_level": 1, "slots": 1},
	"2": {"slot_level": 1, "slots": 2},
	"3": {"slot_level": 2, "slots": 2},
	"4": {"slot_level": 2, "slots": 2},
	"5": {"slot_level": 3, "slots": 2},
	"6": {"slot_level": 3, "slots": 2},
	"7": {"slot_level": 4, "slots": 2},
	"8": {"slot_level": 4, "slots": 2},
	"9": {"slot_level": 5, "slots": 2},
	"10": {"slot_level": 5, "slots": 2},
	"11": {"slot_level": 5, "slots": 3},
	"12": {"slot_level": 5, "slots": 3},
	"13": {"slot_level": 5, "slots": 3},
	"14": {"slot_level": 5, "slots": 3},
	"15": {"slot_level": 5, "slots": 3},
	"16": {"slot_level": 5, "slots": 3},
	"17": {"slot_level": 5, "slots": 4},
	"18": {"slot_level": 5, "slots": 4},
	"19": {"slot_level": 5, "slots": 4},
	"20": {"slot_level": 5, "slots": 4},
}

const CURATED_FEATURE_EFFECTS := {
	"fighter_second_wind": {"effects": [{"type": "heal_self", "value": "1d10+level"}], "uses_per": "long_rest"},
	"fighter_action_surge": {"effects": [{"type": "grant_extra_action"}], "uses_per": "rest"},
	"fighter_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"barbarian_unarmored_defense": {"type": "passive", "effects": [
		{"type": "unarmored_defense", "ability": "CON", "allows_shield": true}
	]},
	"barbarian_reckless_attack": {"type": "passive", "effects": [
		{"type": "reckless_attack"}
	]},
	"monk_patient_defense": {"type": "active", "effects": [{"type": "monk_bonus_action"}], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action", "options": ["disengage", "disengage_dodge"]},
	"monk_unarmored_defense": {"type": "passive", "effects": [{"type": "unarmored_defense"}]},
	"monk_step_of_the_wind": {"type": "active", "effects": [{"type": "monk_bonus_action"}], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action", "options": ["dash", "dash_disengage"]},
	"monk_martial_arts": {"type": "passive", "effects": [{"type": "martial_arts"}]},
	"monk_bonus_unarmed_strike": {"effects": [
		{"type": "unarmed_attack"}
	], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action"},
	"monk_flurry_of_blows": {"effects": [
		{"type": "unarmed_attack", "count": 2}
	], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action", "focus_cost": 1},
	"monk_monk's_focus": {"type": "passive", "effects": [{"type": "monk_focus"}]},
	"monk_uncanny_metabolism": {"type": "passive", "effects": [{"type": "uncanny_metabolism"}]},
	"monk_deflect_attacks": {"type": "passive", "effects": [{"type": "reaction", "reaction": "deflect_attacks"}]},
	"monk_stunning_strike": {"type": "passive", "effects": [{"type": "stunning_strike"}]},
	"monk_open_hand_technique": {"type": "passive", "effects": [{"type": "open_hand_technique"}]},
	"monk_slow_fall": {"type": "active", "effects": [{"type": "slow_fall"}], "action_cost": "reaction", "uses_per": "combat"},
	"monk_empowered_strikes": {"type": "passive", "effects": [{"type": "empowered_strikes"}]},
	"monk_wholeness_of_body": {"type": "active", "effects": [{"type": "wholeness_of_body"}], "action_cost": "bonus_action", "uses_per": "long_rest"},
	"monk_evasion": {"type": "passive", "effects": [{"type": "evasion"}]},
	"monk_acrobatic_movement": {"type": "passive", "effects": [{"type": "acrobatic_movement"}]},
	"monk_heightened_focus": {"type": "passive", "effects": [{"type": "heightened_focus"}]},
	"monk_self_restoration": {"type": "passive", "effects": [{"type": "self_restoration"}]},
	"monk_fleet_step": {"type": "passive", "effects": [{"type": "fleet_step"}]},
	"monk_deflect_energy": {"type": "passive", "effects": [{"type": "deflect_energy"}]},
	"monk_disciplined_survivor": {"type": "passive", "effects": [{"type": "disciplined_survivor"}]},
	"monk_perfect_focus": {"type": "passive", "effects": [{"type": "perfect_focus"}]},
	"monk_quivering_palm": {"type": "active", "effects": [{"type": "quivering_palm"}], "action_cost": "action", "focus_cost": 4},
	"monk_superior_defense": {"type": "active", "effects": [{"type": "superior_defense"}], "action_cost": "free", "focus_cost": 3},
	"paladin_divine_smite": {"type": "passive", "effects": [
		{"type": "divine_smite", "base_dice": "2d8", "damage_type": "radiant"}
	]},
	"paladin_fighting_style": {"type": "passive", "effects": [
		{"type": "defense_style", "ac_bonus": 1, "requires_armor": true}
	]},
	"ranger_fighting_style": {"type": "passive", "effects": [
		{"type": "archery", "attack_bonus": 2, "requires_ranged": true}
	]},
	"paladin_lay_on_hands": {"effects": [
		{"type": "lay_on_hands", "pool": "level_times_five"}
	], "uses": 1, "uses_per": "long_rest", "action_cost": "bonus_action", "resource_formula": "level*5"},
	"paladin_divine_sense": {"effects": [
		{"type": "divine_sense", "duration": 2, "creature_types": ["celestial", "fiend", "undead"]}
	]},
	"bard_bardic_inspiration": {"effects": [
		{"type": "bardic_inspiration", "die": "1d6", "range": 12}
	]},
	"ranger_favored_foe": {"type": "passive", "effects": [
		{"type": "favored_foe", "base_dice": "1d4", "duration": 10}
	]},
	"barbarian_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"ranger_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"monk_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"paladin_extra_attack": {"type": "passive", "effects": [{"type": "extra_attack", "count": 1}]},
	"rogue_sneak_attack": {"effects": [{"type": "sneak_attack", "dice": "1d6"}]},
	"rogue_uncanny_dodge": {"effects": [{"type": "reaction", "reaction": "uncanny_dodge"}]},
	"rogue_cunning_action": {"effects": [{"type": "cunning_action"}], "uses": 1, "uses_per": "turn", "action_cost": "bonus_action"},
	"cleric_channel_divinity:_harness_divine_power": {"effects": [{"type": "recover_spell_slots"}]},
	"warlock_pact_magic": {"type": "passive", "effects": [{"type": "pact_magic"}]},
	"sorcerer_sorcery_points": {"type": "passive", "effects": [{"type": "sorcery_points"}]},
	"sorcerer_metamagic": {"type": "passive", "effects": [{"type": "metamagic", "options": ["careful_spell", "distant_spell", "empowered_spell", "extended_spell", "heightened_spell", "quickened_spell", "seeking_spell", "subtle_spell", "transmuted_spell", "twinned_spell"]}]},
	"artificer_tinker's_magic": {"type": "active", "effects": [{"type": "give_item", "item_id": "ball_bearings"}]},
}

const CURATED_SPELL_EFFECTS := {
	"hunters_mark": {"concentration": true, "effects": [{
		"type": "hunters_mark", "dice": "1d6", "duration": 10
	}]},
}

const CURATED_MONSTER_TYPES := {
	"goblin": "humanoid",
	"goblin_chief": "humanoid",
	"skeleton": "undead",
	"zombie": "undead",
	"wight": "undead",
	"lich_king": "undead",
	"ooze": "ooze",
	"giant_spider": "beast",
}

# Imported weapon descriptions omit the traits used by Martial Arts eligibility.
const MONK_SIMPLE_MELEE_WEAPONS := ["club", "dagger", "greatclub", "handaxe", "javelin", "light_hammer", "mace", "quarterstaff", "sickle", "spear"]
const MONK_LIGHT_MARTIAL_WEAPONS := ["scimitar", "shortsword"]

const VALID_SPELL_CASTING_TIMES := ["action", "bonus_action", "reaction", "minute", "hour"]
const VALID_SPELL_TARGETS := ["self", "single", "single_ally", "multi", "area", "cone", "point"]
const VALID_SPELL_SCHOOLS := ["abjuration", "conjuration", "divination", "enchantment", "evocation", "illusion", "necromancy", "necrotic", "transmutation"]
const VALID_DAMAGE_TYPES := ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic", "piercing", "poison", "psychic", "radiant", "slashing", "thunder", "none"]
const VALID_ABILITIES := ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const VALID_SKILLS := ["Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception", "History", "Insight", "Intimidation", "Investigation", "Medicine", "Nature", "Perception", "Performance", "Persuasion", "Religion", "Sleight of Hand", "Stealth", "Survival"]
const DICE_FIELDS := ["damage", "damage_per_dart", "healing", "hit_points", "versatile_damage", "dice"]

var _load_errors: Array[String] = []
var _validation_warnings: Array[String] = []
var _manifest: Dictionary = {}
var _registered_sources: Dictionary = {}


func _ready() -> void:
	load_all_data()


func load_all_data() -> void:
	_load_errors.clear()
	_validation_warnings.clear()
	_registered_sources.clear()
	for registry in [classes, subclasses, races, feats, items, spells, monsters, events, campaigns]:
		registry.clear()
	_manifest = _read_manifest()

	_load_directory(CORE_PATH)
	_load_directory(MODS_PATH)
	_populate_class_spell_access()
	_validate_cross_references()

	if not _validation_warnings.is_empty():
		push_warning("[DataLoader] Rejected %d unsupported effectless feature records; they remain unavailable until curated." % _validation_warnings.size())
	for err in _load_errors:
		push_error("[DataLoader] %s" % err)
		load_error.emit(err)

	print("[DataLoader] Loaded: %d classes, %d races, %d items, %d spells, %d monsters, %d event tables, %d campaigns" % [
		classes.size(), races.size(), items.size(), spells.size(), monsters.size(), events.size(), campaigns.size()
	])
	if OS.is_debug_build():
		print("[DataLoader] Layers: %s | packs: %s | approved overrides: %d | validation failures: %d" % [
			", ".join(get_content_layers()), ", ".join(get_content_pack_ids()), _manifest.get("overrides", []).size(), _load_errors.size()
		])
	if _load_errors.is_empty():
		data_loaded.emit()


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_load_errors.append("Missing content manifest: %s" % MANIFEST_PATH)
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_load_errors.append("Cannot open content manifest: %s" % MANIFEST_PATH)
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary:
		_load_errors.append("Invalid content manifest: %s" % MANIFEST_PATH)
		return {}
	var manifest: Dictionary = json.data
	if int(manifest.get("schema_version", 0)) != 1:
		_load_errors.append("Unsupported content manifest schema in %s" % MANIFEST_PATH)
		return {}
	_validate_manifest(manifest)
	return manifest


func _validate_manifest(manifest: Dictionary) -> void:
	var packs: Array = manifest.get("packs", [])
	if packs.is_empty():
		_load_errors.append("Content manifest must declare at least one content pack")
		return
	var pack_ids: Dictionary = {}
	for pack in packs:
		if not pack is Dictionary:
			_load_errors.append("Content manifest contains a non-object pack entry")
			continue
		var pack_id := str(pack.get("id", ""))
		if pack_id.is_empty() or str(pack.get("version", "")).is_empty() or str(pack.get("ruleset_compatibility", "")).is_empty():
			_load_errors.append("Content pack metadata requires id, version, and ruleset_compatibility")
			continue
		if pack_ids.has(pack_id):
			_load_errors.append("Duplicate content pack ID '%s'" % pack_id)
		else:
			pack_ids[pack_id] = true
	for pack in packs:
		if not pack is Dictionary:
			continue
		var pack_id := str(pack.get("id", ""))
		var dependencies: Array = pack.get("dependencies", [])
		if not dependencies is Array:
			_load_errors.append("Content pack '%s' dependencies must be an array" % pack_id)
			continue
		for dependency in dependencies:
			if str(dependency) == pack_id or not pack_ids.has(str(dependency)):
				_load_errors.append("Content pack '%s' has invalid dependency '%s'" % [pack_id, dependency])
	for layer in manifest.get("layers", []):
		if not layer is Dictionary:
			_load_errors.append("Content manifest contains a non-object layer entry")
			continue
		var layer_id := str(layer.get("id", ""))
		if layer_id.is_empty() or not layer.has("precedence") or str(layer.get("path", "")).is_empty() or not pack_ids.has(str(layer.get("pack_id", ""))):
			_load_errors.append("Content layer '%s' requires id, precedence, path, and a declared pack_id" % layer_id)


func _load_directory(base_path: String) -> void:
	_load_content_type(base_path + "classes/", "class")
	_load_content_type(base_path + "subclasses/", "subclass")
	_load_content_type(base_path + "races/", "race")
	_load_content_type(base_path + "feats/", "feat")
	_load_content_type(base_path + "items/", "item")
	_load_content_type(base_path + "spells/", "spell")
	_load_content_type(base_path + "monsters/", "monster")
	_load_content_type(base_path + "events/", "event")
	_load_content_type(base_path + "campaigns/", "campaign")


func _load_content_type(dir_path: String, content_type: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_load_errors.append("Cannot open directory: %s" % dir_path)
		return
	var file_names: PackedStringArray = dir.get_files()
	file_names.sort()
	for file_name in file_names:
		if file_name.ends_with(".json"):
			_load_json_file(dir_path + file_name, content_type)


func _load_json_file(file_path: String, content_type: String) -> void:
	if not FileAccess.file_exists(file_path):
		_load_errors.append("File not found: %s" % file_path)
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_load_errors.append("Cannot open file: %s" % file_path)
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		_load_errors.append("JSON parse error in %s line %d: %s" % [file_path, json.get_error_line(), json.get_error_message()])
		return
	if json.data is Dictionary:
		_register_content(json.data, content_type, "%s#1" % file_path)
	elif json.data is Array:
		var index := 0
		for entry in json.data:
			index += 1
			if entry is Dictionary:
				_register_content(entry, content_type, "%s#%d" % [file_path, index])
			else:
				_load_errors.append("Non-dictionary entry in array in %s" % file_path)
	else:
		_load_errors.append("Content root must be an object or array in %s" % file_path)


func _register_content(raw_data: Dictionary, content_type: String, source_path: String) -> void:
	var data := raw_data.duplicate(true)
	var id := str(data.get("id", data.get("table_id", "")))
	if id.is_empty():
		_load_errors.append("Missing 'id' or 'table_id' in %s" % source_path)
		return
	if not _validate_content(data, content_type, source_path):
		return
	data["_source"] = source_path.get_slice("#", 0)
	data["_source_record"] = source_path

	var existing_source := _source_for(content_type, id)
	if not existing_source.is_empty():
		var override := _find_override(content_type, id, existing_source, source_path)
		if override.is_empty():
			_load_errors.append("Unapproved duplicate %s ID '%s': %s conflicts with %s" % [content_type, id, source_path, existing_source])
			return
		var winner := str(override.get("winner", ""))
		var replaces: Array = override.get("replaces", [])
		if source_path == winner:
			data = _merge_missing_fields(data, _get_registry(content_type).get(id, {}))
			_set_registry(content_type, id, data)
			_set_source(content_type, id, source_path)
		elif source_path in replaces and existing_source == winner:
			return
		else:
			_load_errors.append("Invalid override manifest for %s ID '%s'" % [content_type, id])
		return
	else:
		_set_registry(content_type, id, data)
		_set_source(content_type, id, source_path)


func _validate_content(data: Dictionary, content_type: String, source: String) -> bool:
	var previous_errors := _load_errors.size()
	if data.has("spell_permissions") and (content_type != "item" or not SpellPermissionRules.item_definition_error(data).is_empty()):
		_load_errors.append("Invalid item spell permission in %s" % source)
		return false
	if data.has("source_benefits") and (content_type != "item" or data.get("type", "") not in ["weapon", "armor", "shield", "ring", "wand", "staff", "rod", "wondrous"] or (data.get("type", "") == "wondrous" and not data.has("worn_slot")) or not SourceBenefitRules.benefits_error(data["source_benefits"]).is_empty()):
		_load_errors.append("Invalid equipped item source benefits in " + source)
		return false
	if content_type == "spell" and data.has("execution"):
		var execution_error := SharedSpell.content_error(data)
		if not execution_error.is_empty():
			_load_errors.append("Spell in %s: %s" % [source, execution_error])
			return false
	if content_type == "monster" and data.has("special_abilities"):
		var ability_error := SharedStepExecutor.validate_monster_special_abilities(data)
		if not ability_error.is_empty():
			_load_errors.append("Monster in %s: %s" % [source, ability_error])
			return false
	var required: Array = ["id", "name"]
	match content_type:
		"class": required = ["id", "name", "hit_die", "primary_ability"]
		"subclass": required = ["id", "name", "class_id", "features_by_level"]
		"race": required = ["id", "name"]
		"feat": required = ["id", "name", "features"]
		"item": required = ["id", "name", "type"]
		"spell": required = ["id", "name", "level"]
		"monster": required = ["id", "name", "hit_points", "armor_class", "speed", "attacks", "ai_behavior"]
		"event": required = ["table_id"] if not data.has("id") else ["id"]
		"campaign": required = ["id", "name", "win_condition", "map", "dungeons"]
	for field in required:
		if not data.has(field):
			_load_errors.append("%s missing required field '%s' in %s" % [content_type.capitalize(), field, source])
			return false
	if content_type == "item" and data.has("incoming_negation_rule"):
		var negation_error := CastInterruptionRules.incoming_negation_rule_error(data.incoming_negation_rule)
		if not negation_error.is_empty():
			_load_errors.append("Item in %s: %s" % [source, negation_error])
			return false
	if content_type == "item" and data.has("attack_unit_substitution"):
		if CombatChildActions.units(data) == 0 or data.get("type") != "consumable" or data.get("action_cost", "action") != "action":
			_load_errors.append("Invalid item strike substitution: " + str(data.get("id", "")))
			return false
	if content_type == "item" and str(data.get("type", "")) not in ["weapon", "armor", "shield", "ring", "wand", "staff", "rod", "wondrous", "consumable", "tool", "currency", "spell_component"]:
		_load_errors.append("Item has unsupported type '%s' in %s" % [data.get("type"), source])
		return false
	if content_type in ["race", "feat", "item"]:
		var owned_error := OwnedFeatureSources.definition_error(data, content_type) # Batch 049: card 209c.
		if not owned_error.is_empty():
			_load_errors.append("%s in %s" % [owned_error, source])
			return false
	if content_type == "item":
		var measure_error := ItemTypeRules.definition_error(data) # Batch 048: magic-item types and measurements.
		if not measure_error.is_empty():
			_load_errors.append("%s in %s" % [measure_error, source])
			return false
	if content_type == "item":
		var context_effect_error := _check_context_item_effect_error(data)
		if not context_effect_error.is_empty():
			_load_errors.append("Item in %s: %s" % [source, context_effect_error])
			return false
	if content_type == "event":
		var event_context_error := _check_context_event_error(data)
		if not event_context_error.is_empty():
			_load_errors.append("Event table in %s: %s" % [source, event_context_error])
			return false
	if data.has("permanent_progression"):
		var progression_error := PermanentProgressionRules.definition_error(data, false)
		if content_type != "class" or not progression_error.is_empty():
			_load_errors.append("Invalid permanent progression in %s: %s" % [source, progression_error])
			return false
	if content_type in ["class", "subclass"]:
		var layout_error := _feature_layout_error(data)
		if not layout_error.is_empty():
			_load_errors.append("%s in %s: %s" % [content_type.capitalize(), source, layout_error])
			return false
		if content_type == "class":
			var slots_error := _spell_slot_progression_error(data)
			if not slots_error.is_empty():
				_load_errors.append("Class in %s: %s" % [source, slots_error])
				return false
		_curate_feature_effects(data)
		_sanitize_class_features(data, source)
	if content_type == "spell":
		_curate_spell_effects(data)
	if content_type == "monster":
		_curate_monster_data(data)
	if content_type == "item" and data.get("type", "") == "weapon":
		FighterRules.curate_weapon(data)
		var weapon_id := str(data.get("id", ""))
		if weapon_id in MONK_SIMPLE_MELEE_WEAPONS and not data.has("weapon_type"):
			data["weapon_type"] = "simple"
		if weapon_id in MONK_LIGHT_MARTIAL_WEAPONS:
			data["weapon_type"] = "martial"
			var properties: Array = data.get("properties", []).duplicate()
			for property_name in ["light", "finesse"]:
				if property_name not in properties:
					properties.append(property_name)
			data["properties"] = properties
	if content_type == "spell" and int(data.get("level", -1)) < 0:
		_load_errors.append("Spell has invalid level in %s" % source)
		return false
	if not _validate_semantics(data, content_type, source):
		return false
	return _load_errors.size() == previous_errors


func _spell_slot_progression_error(data: Dictionary) -> String:
	if not data.has("spell_slots_by_character_level"):
		return ""
	var progression: Variant = data["spell_slots_by_character_level"]
	if not progression is Dictionary:
		return "spell_slots_by_character_level must be an object"
	for key in progression:
		if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20:
			return "Spell slot progression keys must be canonical character levels 1-20"
		var slots: Variant = progression[key]
		if not slots is Array or slots.size() > 9:
			return "Spell slot progression entries must be arrays of up to nine spell levels"
		for count in slots:
			if not (count is int or count is float) or float(count) != float(int(count)) or int(count) < 0 or int(count) > 20:
				return "Spell slot counts must be integers from 0-20"
	return ""


func _validate_semantics(data: Dictionary, content_type: String, source: String) -> bool:
	var valid := true
	if content_type == "spell":
		valid = _validate_enum(data, "casting_time", VALID_SPELL_CASTING_TIMES, content_type, source) and valid
		valid = _validate_enum(data, "target", VALID_SPELL_TARGETS, content_type, source) and valid
		valid = _validate_enum(data, "school", VALID_SPELL_SCHOOLS, content_type, source) and valid
		var level := int(data.get("level", 0))
		if level < 0 or level > 9:
			_load_errors.append("Spell level must be between 0 and 9 in %s" % source)
			valid = false
	if data.has("damage_type") and str(data.get("damage_type")) not in VALID_DAMAGE_TYPES:
		_load_errors.append("Unsupported damage type '%s' in %s" % [data.get("damage_type"), source])
		valid = false
	if data.has("ability") and str(data.get("ability")) not in VALID_ABILITIES:
		_load_errors.append("Unsupported ability '%s' in %s" % [data.get("ability"), source])
		valid = false
	if data.has("range") and (not (data.get("range") is int or data.get("range") is float) or float(data.get("range")) < 0):
		_load_errors.append("Range must be a non-negative number in %s" % source)
		valid = false
	if data.has("last_charge_aftermath"):
		var charge_error := LastChargeRules.validate(data["last_charge_aftermath"])
		if charge_error.is_empty() and int(data.get("maximum_charges", 0)) <= 0: charge_error = "last_charge_aftermath requires maximum_charges"
		if not charge_error.is_empty():
			_load_errors.append("%s in %s" % [charge_error, source])
			valid = false
	if content_type == "item" and data.has("container"):
		var container_error := ContainerRules.policy_error(data["container"])
		if not container_error.is_empty():
			_load_errors.append("%s in %s" % [container_error, source])
			valid = false
	if content_type == "item" and data.has("active_time"):
		var active_error := ActiveTimeRules.policy_error(data["active_time"])
		if not active_error.is_empty():
			_load_errors.append("%s in %s" % [active_error, source])
			valid = false
	if content_type == "item" and data.has("work"):
		var work_error := WorkRules.policy_error(data["work"])
		if not work_error.is_empty():
			_load_errors.append("%s in %s" % [work_error, source])
			valid = false
	if content_type == "item" and data.has("attachments"):
		var attachment_error := AttachmentRules.policy_error(data["attachments"])
		if not attachment_error.is_empty():
			_load_errors.append("%s in %s" % [attachment_error, source])
			valid = false
	if content_type == "item" and data.has("curse"):
		var curse_error := CurseRules.policy_error(data)
		if not curse_error.is_empty():
			_load_errors.append("%s in %s" % [curse_error, source])
			valid = false
	if content_type == "item" and data.has("actor_projection"):
		var item_projection_error := ItemProjectionRules.policy_error(data["actor_projection"])
		if not item_projection_error.is_empty():
			_load_errors.append("%s in %s" % [item_projection_error, source])
			valid = false
	if data.has("zero_hp_aftermath"):
		var aftermath_error := ZeroHpAftermathRules.validate_policy(data["zero_hp_aftermath"])
		if not aftermath_error.is_empty():
			_load_errors.append("%s in %s" % [aftermath_error, source])
			valid = false
	if content_type == "monster" and data.get("attacks") is Array:
		for attack in data["attacks"]:
			if attack is Dictionary and attack.get("extra_effects") is Array:
				for effect in attack["extra_effects"]:
					if effect is Dictionary and str(effect.get("type", "")) == "max_hp_source":
						var source_error := MaxHpSourceRules.validate_rule(effect.get("rule", null))
						if not source_error.is_empty():
							_load_errors.append("Attack '%s' %s in %s" % [attack.get("name", ""), source_error, source])
							valid = false
			if attack is Dictionary and attack.has("zero_hp_aftermath"):
				var attack_error := ZeroHpAftermathRules.validate_policy(attack["zero_hp_aftermath"])
				if not attack_error.is_empty():
					_load_errors.append("Attack '%s' %s in %s" % [attack.get("name", ""), attack_error, source])
					valid = false
	valid = _validate_nested_values(data, source) and valid
	return valid


func _check_context_item_effect_error(item: Dictionary) -> String:
	for effect_value in item.get("effects", []):
		if not effect_value is Dictionary or str(effect_value.get("type", "")) != "skill_check_context_bonus":
			continue
		var effect: Dictionary = effect_value
		if str(item.get("type", "")) != "tool":
			return "skill_check_context_bonus requires a tool item"
		for field in ["id", "ability", "skill", "task_id", "purpose_id", "required_tool_id", "source_event_id", "source_check_id", "bonus"]:
			if not effect.has(field):
				return "skill_check_context_bonus requires '%s'" % field
		if str(effect.get("id", "")).is_empty() or not _is_context_token(str(effect.get("id", ""))):
			return "skill_check_context_bonus id must be a lowercase token"
		if str(effect.get("ability", "")) not in VALID_ABILITIES or str(effect.get("skill", "")) not in VALID_SKILLS:
			return "skill_check_context_bonus ability or skill is unsupported"
		for field in ["task_id", "purpose_id", "source_check_id"]:
			if not _is_context_token(str(effect.get(field, ""))):
				return "skill_check_context_bonus %s must be a lowercase token" % field
		if str(effect.get("required_tool_id", "")) != str(item.get("id", "")):
			return "skill_check_context_bonus required_tool_id must match its item"
		if str(effect.get("source_event_id", "")).strip_edges().is_empty() or effect.get("source_event_id") != str(effect.get("source_event_id", "")).strip_edges():
			return "skill_check_context_bonus source_event_id must be a non-empty exact ID"
		var bonus: Variant = effect.get("bonus")
		if not (bonus is int or bonus is float) or float(bonus) != float(int(bonus)) or int(bonus) < 1 or int(bonus) > 20:
			return "skill_check_context_bonus bonus must be an integer from 1 to 20"
	return ""


func _check_context_event_error(table: Dictionary) -> String:
	var events_value: Variant = table.get("events", [])
	if not events_value is Array:
		return "events must be an array"
	for event_value in events_value:
		if not event_value is Dictionary:
			continue
		var event_record: Dictionary = event_value
		var checks: Array = []
		if event_record.get("check", {}) is Dictionary and not event_record.get("check", {}).is_empty():
			checks.append(event_record["check"])
		for choice_value in event_record.get("choices", []):
			if choice_value is Dictionary and choice_value.get("check", {}) is Dictionary and not choice_value.get("check", {}).is_empty():
				checks.append(choice_value["check"])
		for check_value in checks:
			var check: Dictionary = check_value
			if not check.has("check_context"):
				continue
			var context_value: Variant = check.get("check_context")
			if not context_value is Dictionary or str(event_record.get("id", "")).strip_edges().is_empty() or not _is_context_token(str(check.get("id", ""))):
				return "a context-aware check requires event/check IDs and a context object"
			var context: Dictionary = context_value
			for field in context:
				if str(field) not in ["task_id", "purpose_id", "required_tool_id"]:
					return "check_context has unsupported field '%s'" % field
			for field in ["task_id", "purpose_id"]:
				if not context.has(field) or str(context.get(field, "")).strip_edges().is_empty():
					return "check_context requires '%s'" % field
			if not _is_context_token(str(context["task_id"])) or not _is_context_token(str(context["purpose_id"])):
				return "check_context task_id and purpose_id must be lowercase tokens"
			if context.has("required_tool_id") and str(context.get("required_tool_id", "")).strip_edges().is_empty():
				return "check_context required_tool_id must be omitted or a non-empty item ID"
			var check_skill := str(check.get("skill", ""))
			if str(check.get("ability", "")) not in VALID_ABILITIES or (not check_skill.is_empty() and check_skill not in VALID_SKILLS):
				return "context-aware check requires a supported ability and, when present, a supported skill"
	return ""


func _is_context_token(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]{0,63}$")
	return pattern.search(value) != null


func _validate_enum(data: Dictionary, field: String, allowed: Array, content_type: String, source: String) -> bool:
	if not data.has(field):
		return true
	if str(data.get(field)) in allowed:
		return true
	_load_errors.append("%s has unsupported %s '%s' in %s" % [content_type.capitalize(), field, data.get(field), source])
	return false


func _validate_nested_values(value, source: String) -> bool:
	var valid := true
	if value is Dictionary:
		for key in value:
			var child = value[key]
			if str(key) in DICE_FIELDS and child is String and not str(child).is_valid_float():
				var expression := str(child).replace(" ", "")
				var dice_pattern := RegEx.new()
				dice_pattern.compile("^[0-9]*[dD][0-9]+([+-]([0-9]+|[A-Za-z_][A-Za-z0-9_]*))?$")
				if dice_pattern.search(expression) == null:
					_load_errors.append("Invalid dice expression '%s' in %s" % [child, source])
					valid = false
			if str(key) in ["uses", "duration", "count", "max_targets", "dart_count"] and child is int and int(child) < 0:
				_load_errors.append("Numeric field '%s' cannot be negative in %s" % [key, source])
				valid = false
			valid = _validate_nested_values(child, source) and valid
	elif value is Array:
		for child in value:
			valid = _validate_nested_values(child, source) and valid
	return valid


func _feature_layout_error(data: Dictionary) -> String:
	if not data.get("features_by_level", {}) is Dictionary:
		return "features_by_level must be an object"
	var choice_level: Variant = data.get("subclass_level", 3)
	if not (choice_level is int or choice_level is float) or float(choice_level) != float(int(choice_level)) or int(choice_level) < 1 or int(choice_level) > 20:
		return "subclass_level must be an integer 1-20"
	for key in data.get("features_by_level", {}):
		if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20:
			return "features_by_level keys must be canonical levels 1-20"
		if not data["features_by_level"][key] is Array:
			return "features_by_level entries must be arrays"
		for feature in data["features_by_level"][key]:
			if not feature is Dictionary or not feature.get("id", "") is String or feature.get("id", "").is_empty() or not feature.get("name", "") is String or feature.get("name", "").is_empty():
				return "Every feature requires a nonempty ID and name"
			if not feature.get("effects", []) is Array:
				return "Feature '%s' effects must be an array" % feature["id"]
			if not feature.get("passive_effects", []) is Array:
				return "Feature '%s' passive effects must be an array" % feature["id"]
	return ""

func _sanitize_class_features(data: Dictionary, source: String) -> void:
	data["support_status"] = "partial"
	data["rules_status"] = data.get("rules_status", "2024-partial" if str(data.get("id", "")) == "monk" else "transition-pending")
	var by_level: Dictionary = data.get("features_by_level", {})
	var sanitized: Dictionary = {}
	for level_key in by_level:
		var kept: Array = []
		var raw_features = by_level[level_key]
		if not raw_features is Array:
			sanitized[str(level_key)] = kept
			continue
		for feature in raw_features:
			if not feature is Dictionary:
				continue
			if feature.get("enabled", true) == false:
				continue
			if feature.get("type") == "zero_hp_replacement" or feature.get("trigger") == "zero_hp":
				var zero_error := SharedStepExecutor.validate_zero_hp_replacement_rule(feature)
				if not zero_error.is_empty():
					_load_errors.append("Feature '%s' in %s: %s" % [feature.get("id", ""), source, zero_error])
				else: kept.append(feature)
				continue
			if feature.get("type") == "attack_profile":
				var profile_error := AttackProfileRules.validate_rule(feature)
				if not profile_error.is_empty():
					_load_errors.append("Feature '%s' in %s: %s" % [feature.get("id", ""), source, profile_error])
				else: kept.append(feature)
				continue
			if feature.get("type") in ["mode_choice", "rule_upgrade"]:
				var declared := {}
				for any_level in by_level:
					for other in by_level[any_level]:
						if other is Dictionary: declared[str(other.get("id", ""))] = true
				var mode_error := FeatureModeRules.validate_rule(feature) if feature.type == "mode_choice" else RuleUpgradeRules.validate_rule(feature, declared)
				if not mode_error.is_empty():
					_load_errors.append("Feature '%s' in %s: %s" % [feature.get("id", ""), source, mode_error])
				else: kept.append(feature)
				continue
			if feature.get("type") == "exclusive_bond":
				var bond_error := BondRules.rule_error(feature)
				if not bond_error.is_empty():
					_load_errors.append("Feature '%s' in %s: %s" % [feature.get("id", ""), source, bond_error])
				else: kept.append(feature)
				continue
			if feature.get("type") == "death_save_outcome":
				var save_error := ZeroHpAftermathRules.validate_death_save_rule(feature)
				if not save_error.is_empty():
					_load_errors.append("Feature '%s' in %s: %s" % [feature.get("id", ""), source, save_error])
				else: kept.append(feature)
				continue
			if feature.has("executor") or feature.get("type", "") == "resource":
				var common_error := _feature_content_error(feature) if feature.has("executor") else _resource_content_error(feature)
				if not common_error.is_empty():
					_load_errors.append("Feature '%s' in %s: %s" % [feature.get("id", ""), source, common_error])
					continue
				kept.append(feature)
				feature["rules_status"] = feature.get("rules_status", data["rules_status"])
				continue
			var has_effects: bool = (feature.get("effects", []) is Array and not feature.get("effects", []).is_empty()) or (feature.get("passive_effects", []) is Array and not feature.get("passive_effects", []).is_empty())
			var has_resolver := not str(feature.get("resolver", "")).is_empty()
			if not has_effects and not has_resolver:
				_validation_warnings.append("Rejected unsupported effectless feature '%s' in %s" % [feature.get("id", ""), source])
				continue
			var error := _feature_content_error(feature)
			if not error.is_empty():
				_load_errors.append("Feature '%s' in %s: %s" % [feature.get("id", ""), source, error])
				continue
			kept.append(feature)
			feature["rules_status"] = feature.get("rules_status", data["rules_status"])
		sanitized[str(level_key)] = kept
	data["features_by_level"] = sanitized

func _resource_content_error(feature: Dictionary) -> String:
	if feature.has("resource_id") or not feature.get("effects", []).is_empty():
		return "A pool cannot reference another pool or execute effects"
	if feature.get("uses_per", "") not in ["short_rest", "long_rest", "rest", "turn", "combat"]:
		return "Resource pool requires a supported recovery cadence"
	return _uses_content_error(feature)

func _uses_content_error(feature: Dictionary) -> String:
	if feature.has("resource_formula"):
		return "Common resources use capacities, ability modifiers or level tables; formulas are not supported"
	if feature.has("resource_id"):
		for field in ["uses", "uses_per", "uses_by_level", "uses_ability", "minimum_uses", "short_rest_recovery"]:
			if feature.has(field):
				return "Referenced resource settings belong on the pool, not '%s'" % field
	if feature.has("uses_ability") and feature["uses_ability"] not in VALID_ABILITIES:
		return "Unknown resource ability"
	if not feature.get("uses_by_level", {}) is Dictionary:
		return "Resource scaling must be a level table"
	for key in feature.get("uses_by_level", {}):
		var value: Variant = feature["uses_by_level"][key]
		if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20 or not (value is int or value is float) or float(value) != float(int(value)) or int(value) < 0 or int(value) > 100:
			return "Resource scaling requires integer levels 1-20 and capacities 0-100"
	for key in ["uses", "minimum_uses", "short_rest_recovery"]:
		var value: Variant = feature.get(key, 1)
		if not (value is int or value is float) or float(value) != float(int(value)) or int(value) < 0 or int(value) > 100:
			return "Resource capacity and recovery must be integers 0-100"
	return ""


func _feature_content_error(feature: Dictionary) -> String:
	var protection_aura_count := 0
	var aura_effects: Variant = feature.get("effects", [])
	if aura_effects is Array:
		for aura_effect in aura_effects:
			if aura_effect is Dictionary and aura_effect.get("type") == "protection_aura": protection_aura_count += 1
	if protection_aura_count > 1: return "One feature may own only one protection aura."
	if feature.has("executor"):
		var error := ClassFeature.content_error(feature)
		return error if not error.is_empty() else _uses_content_error(feature)
	var resolver := str(feature.get("resolver", ""))
	if not resolver.is_empty() and resolver not in ["fighter_rules", "monk_rules", "barbarian_rules", "cleric_rules", "druid_rules", "paladin_rules", "warlock_rules"]:
		return "Unknown resolver '%s'" % resolver
	if feature.get("effects", []).is_empty() and feature.get("passive_effects", []).is_empty():
		var implemented := ["fighter_fighting_style", "fighter_weapon_mastery", "fighter_tactical_mind", "fighter_tactical_shift", "fighter_tactical_master", "fighter_studied_attacks", "fighter_indomitable", "fighter_epic_boon", "champion_remarkable_athlete", "champion_additional_fighting_style", "champion_heroic_warrior", "champion_survivor"]
		if resolver == "barbarian_rules" and feature.get("id", "") in ["barbarian_instinctive_pounce", "barbarian_persistent_rage", "barbarian_relentless_rage", "barbarian_brutal_strike", "barbarian_improved_brutal_strike_13", "barbarian_improved_brutal_strike_17"]:
			return ""
		if resolver == "cleric_rules" and feature.get("id", "") in ["cleric_divine_spark", "cleric_turn_undead", "cleric_sear_undead", "cleric_improved_blessed_strikes", "cleric_divine_intervention", "cleric_greater_divine_intervention"]:
			return ""
		if resolver == "druid_rules" and feature.get("id", "") in ["druid_wild_shape", "druid_wild_resurgence", "druid_wild_companion", "druid_improved_elemental_fury", "druid_beast_spells", "druid_nature_magician"]:
			return ""
		if resolver == "paladin_rules" and feature.get("id", "") in ["paladin_restoring_touch", "paladin_channel_divinity_divine_sense", "paladin_abjure_foes"]:
			return ""
		if resolver == "warlock_rules" and feature.get("id", "") in ["fiend_dark_ones_blessing", "fiend_dark_ones_own_luck", "fiend_fiendish_resilience", "fiend_hurl_through_hell"]:
			return ""
		return "" if resolver == "fighter_rules" and feature.get("id", "") in implemented else "Resolver has no registered behavior for this feature"
	var supported := ["heal_self", "grant_extra_action", "extra_attack", "modify_crit_range", "asi", "ability_score_increase", "skill_proficiency_choice", "skill_expertise_choice", "jack_of_all_trades", "short_rest_recharge", "initiative_resource_recovery", "resource_from_spell_slot", "spellcasting", "spell_list_expansion", "always_prepared_spells", "spell_free_cast", "concentration_protection", "spell_damage_dice_override", "attack_advantage_against_condition", "saving_throw_proficiency", "protection_aura", "saving_throw_aura", "aura_radius_expansion", "condition_immunity_aura", "additional_spell_target", "countercharm", "epic_boon_choice", "feature_choice", "grant_condition", "stat_modifier", "unarmored_defense", "reckless_attack", "monk_bonus_action", "martial_arts", "unarmed_attack", "monk_focus", "unarmored_movement", "speed_bonus", "initiative_advantage", "saving_throw_advantage", "ability_check_override", "ability_check_advantage", "ability_check_floor", "weapon_mastery", "weapon_damage_rider", "uncanny_metabolism", "reaction", "stunning_strike", "empowered_strikes", "evasion", "heightened_focus", "self_restoration", "fleet_step", "deflect_energy", "disciplined_survivor", "perfect_focus", "superior_defense", "divine_smite", "defense_style", "archery", "lay_on_hands", "divine_sense", "abjure_foes", "bardic_inspiration", "favored_foe", "sneak_attack", "cunning_strike", "cunning_action", "recover_spell_slots", "pact_magic", "pact_magic_recovery", "sorcery_points", "sorcerer_font_of_magic", "innate_sorcery", "metamagic", "metamagic_choices", "sorcery_incarnate", "arcane_apotheosis", "blindsight", "wizard_ritual_casting", "wizard_memorize_spell", "wizard_spell_mastery", "wizard_signature_spells", "elusive", "rogue_steady_aim", "stroke_of_luck", "give_item", "source_benefits"]
	supported.append("check_floor")
	supported.append_array(["warlock_invocations", "warlock_mystic_arcanum", "concentration_save_advantage", "dark_ones_blessing", "dark_ones_own_luck", "fiendish_resilience", "hurl_through_hell", "roll_token_pool", "roll_token_pool_upgrade", "damage_ward_pool", "damage_ward_projection", "rest_slot_recovery", "failed_save_numeric_bonus", "failed_save_outcome_override", "roll_outcome_override", "weapon_attack_numeric_bonus", "attack_total_adjustment", "defending_ac_adjustment", "ability_check_numeric_bonus", "ability_check_mandatory_reroll", "ability_check_roll_mode", "ability_check_roll_mode_policy", "recipient_damage_map", "incoming_spell_negation"])
	var effects: Array = feature.get("effects", []).duplicate()
	effects.append_array(feature.get("passive_effects", []))
	if effects.filter(func(e): return e is Dictionary and e.get("type", "") == "source_benefits").size() > 1: return "One source benefits payload per feature."
	var failed_save_modification_abilities: Array[String] = []
	var weapon_attack_bonus_domains: Array[String] = []
	var ability_check_bonus_filters: Array[String] = []
	var ability_check_reroll_filters: Array[String] = []
	for effect in effects:
		if not effect is Dictionary or effect.get("type", "") not in supported:
			return "Unknown or unimplemented effect operation"
		if effect.get("type", "") in ["asi", "ability_score_increase", "skill_proficiency_choice", "skill_expertise_choice", "jack_of_all_trades", "short_rest_recharge", "initiative_resource_recovery", "resource_from_spell_slot", "spellcasting", "spell_list_expansion", "always_prepared_spells", "concentration_protection", "spell_damage_dice_override", "attack_advantage_against_condition", "saving_throw_proficiency", "protection_aura", "saving_throw_aura", "aura_radius_expansion", "condition_immunity_aura", "additional_spell_target", "countercharm", "epic_boon_choice", "feature_choice", "modify_crit_range", "extra_attack", "speed_bonus", "initiative_advantage", "saving_throw_advantage", "ability_check_override", "ability_check_advantage", "ability_check_floor", "ability_check_roll_mode", "ability_check_roll_mode_policy", "weapon_mastery", "blindsight", "wizard_ritual_casting", "wizard_memorize_spell", "wizard_spell_mastery", "wizard_signature_spells", "sorcerer_font_of_magic", "roll_token_pool", "roll_token_pool_upgrade", "damage_ward_pool", "damage_ward_projection", "failed_save_numeric_bonus", "weapon_attack_numeric_bonus", "attack_total_adjustment", "defending_ac_adjustment", "incoming_spell_negation"] and feature.get("type", "") != "passive":
			return "This class progression effect requires a passive feature"
		if effect.get("type", "") == "incoming_spell_negation":
			var rule: Dictionary = effect.duplicate(true)
			rule.erase("type")
			var negation_error := CastInterruptionRules.incoming_negation_rule_error(rule)
			if not negation_error.is_empty(): return negation_error
		if effect.get("type", "") == "check_floor":
			if feature.get("type") != "passive": return "Check floors require passive features."
			var floor_error := CheckFloorRules.content_error(effect)
			if not floor_error.is_empty(): return floor_error
		if effect.get("type", "") == "failed_save_numeric_bonus":
			var ability := str(effect.get("ability", "")).to_upper()
			var amount: Variant = effect.get("amount", null)
			var has_numeric_bonus: bool = effect.has("amount") and not effect.has("die_size") and ResourcePoolRules._integer(amount, 1, 20)
			var has_die_bonus: bool = effect.has("die_size") and not effect.has("amount") and ResourcePoolRules._integer(effect.get("die_size"), 1, 20) and int(effect.get("die_size")) in ResourcePoolRules.SUPPORTED_DIE_SIZES
			var cost: Variant = effect.get("cost", null)
			var payment_policy: Variant = effect.get("payment_policy", "pay_on_choice")
			if ability not in VALID_ABILITIES or not (has_numeric_bonus or has_die_bonus) or not ResourcePoolRules._integer(cost, 1, ResourcePoolRules.MAX_CAPACITY):
				return "Failed-save bonuses require a supported ability, one amount (1-20) or supported die_size, and pool cost 1-100"
			if not payment_policy is String or str(payment_policy) not in SpellDamageRolls.FAILED_SAVE_BONUS_PAYMENT_POLICIES:
				return "Failed-save numeric bonuses require a supported payment_policy"
			var has_cause: bool = effect.has("cause_id")
			var has_purpose: bool = effect.has("purpose_id")
			if has_cause != has_purpose:
				return "Contextual failed-save bonuses require both cause_id and purpose_id"
			for context_field in ["cause_id", "purpose_id", "required_sense"]:
				if not effect.has(context_field): continue
				var context_token: Variant = effect[context_field]
				if not context_token is String or not str(context_token).is_valid_identifier() or str(context_token) != str(context_token).to_lower():
					return "Failed-save %s must be a lowercase identifier" % context_field
			if ability in failed_save_modification_abilities:
				return "A passive source can declare only one failed-save modification per ability"
			failed_save_modification_abilities.append(ability)
			if feature.get("type", "") != "passive" or not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary:
				return "Failed-save numeric bonuses require a passive feature with its owned numeric pool"
			var pool_error := ResourcePoolRules.definition_error(feature)
			if not pool_error.is_empty():
				return "Failed-save numeric bonus pool is invalid: %s" % pool_error
			for field in effect:
				if field not in ["type", "ability", "amount", "die_size", "cost", "payment_policy", "cause_id", "purpose_id", "required_sense"]:
					return "Failed-save numeric bonus contains an unsupported field"
		if effect.get("type", "") == "weapon_attack_numeric_bonus":
			var attack_amount: Variant = effect.get("amount", null)
			var attack_cost: Variant = effect.get("cost", null)
			var attack_domains: Variant = effect.get("domains", [])
			var attack_policy: Variant = effect.get("payment_policy", "pay_on_choice")
			var has_numeric_bonus: bool = effect.has("amount") and not effect.has("die_size") and ResourcePoolRules._integer(attack_amount, 1, 20)
			var has_die_bonus: bool = effect.has("die_size") and not effect.has("amount") and ResourcePoolRules._integer(effect.get("die_size"), 1, 20) and int(effect.get("die_size")) in ResourcePoolRules.SUPPORTED_DIE_SIZES
			if not (has_numeric_bonus or has_die_bonus) or not ResourcePoolRules._integer(attack_cost, 1, ResourcePoolRules.MAX_CAPACITY):
				return "Attack bonuses require one amount (1-20) or supported die_size and pool cost from 1 to 100"
			if not attack_domains is Array or attack_domains.is_empty() or attack_domains.size() > 2:
				return "Attack bonuses must name one or more supported attack domains"
			var seen_attack_domains: Array[String] = []
			for attack_domain in attack_domains:
				if not attack_domain is String or attack_domain not in ["weapon_attack", "shared_spell_attack"] or attack_domain in seen_attack_domains:
					return "Attack bonuses must name unique weapon_attack or shared_spell_attack domains"
				if attack_domain in weapon_attack_bonus_domains:
					return "A passive source can declare only one modification per attack domain"
				seen_attack_domains.append(str(attack_domain))
				weapon_attack_bonus_domains.append(str(attack_domain))
			if not attack_policy is String or str(attack_policy) not in SpellDamageRolls.FAILED_SAVE_BONUS_PAYMENT_POLICIES:
				return "Attack bonuses require a supported payment_policy"
			if feature.get("type", "") != "passive" or not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary:
				return "Weapon attack bonuses require a passive feature with its owned numeric pool"
			var attack_pool_error := ResourcePoolRules.definition_error(feature)
			if not attack_pool_error.is_empty():
				return "Attack bonus pool is invalid: %s" % attack_pool_error
			for attack_field in effect:
				if attack_field not in ["type", "amount", "die_size", "cost", "domains", "payment_policy"]:
					return "Attack bonus contains an unsupported field"
		if effect.get("type", "") in ["attack_total_adjustment", "defending_ac_adjustment"]:
			var adjustment_amount: Variant = effect.get("amount", null)
			var adjustment_cost: Variant = effect.get("cost", null)
			var adjustment_domains: Variant = effect.get("domains", null)
			var adjustment_policy: Variant = effect.get("payment_policy", "pay_on_choice")
			var adjustment_trigger: Variant = effect.get("trigger", null)
			if not ResourcePoolRules._integer(adjustment_amount, 1, 20) or not ResourcePoolRules._integer(adjustment_cost, 1, ResourcePoolRules.MAX_CAPACITY):
				return "Attack-result adjustments require a positive amount (1-20) and pool cost from 1 to 100"
			if not adjustment_domains is Array or adjustment_domains.is_empty() or adjustment_domains.size() > 2:
				return "Attack-result adjustments must name supported attack domains"
			var seen_adjustment_domains: Array[String] = []
			for adjustment_domain in adjustment_domains:
				if not adjustment_domain is String or adjustment_domain not in ["weapon_attack", "shared_spell_attack"] or str(adjustment_domain) in seen_adjustment_domains:
					return "Attack-result adjustments require unique weapon_attack or shared_spell_attack domains"
				if str(adjustment_domain) in weapon_attack_bonus_domains:
					return "A passive source can declare only one modification per attack domain"
				seen_adjustment_domains.append(str(adjustment_domain))
				weapon_attack_bonus_domains.append(str(adjustment_domain))
			if adjustment_trigger != "provisional_hit":
				return "Attack-result adjustments must trigger on one provisional hit"
			if not adjustment_policy is String or str(adjustment_policy) not in SpellDamageRolls.FAILED_SAVE_BONUS_PAYMENT_POLICIES:
				return "Attack-result adjustments require a supported payment_policy"
			if feature.get("type", "") != "passive" or not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary:
				return "Attack-result adjustments require a passive feature with its owned numeric pool"
			var adjustment_pool_error := ResourcePoolRules.definition_error(feature)
			if not adjustment_pool_error.is_empty():
				return "Attack-result adjustment pool is invalid: %s" % adjustment_pool_error
			for adjustment_field in effect:
				if adjustment_field not in ["type", "amount", "cost", "domains", "trigger", "payment_policy"]:
					return "Attack-result adjustment contains an unsupported field"
		if effect.get("type", "") == "weapon_attack_numeric_bonus":
			var attack_amount: Variant = effect.get("amount", null)
			var attack_cost: Variant = effect.get("cost", null)
			var attack_domains: Variant = effect.get("domains", [])
			var attack_policy: Variant = effect.get("payment_policy", "pay_on_choice")
			var has_numeric_bonus: bool = effect.has("amount") and not effect.has("die_size") and ResourcePoolRules._integer(attack_amount, 1, 20)
			var has_die_bonus: bool = effect.has("die_size") and not effect.has("amount") and ResourcePoolRules._integer(effect.get("die_size"), 1, 20) and int(effect.get("die_size")) in ResourcePoolRules.SUPPORTED_DIE_SIZES
			if not (has_numeric_bonus or has_die_bonus) or not ResourcePoolRules._integer(attack_cost, 1, ResourcePoolRules.MAX_CAPACITY):
				return "Weapon attack bonuses require one amount (1-20) or supported die_size and pool cost from 1 to 100"
			if not attack_domains is Array or attack_domains.is_empty() or attack_domains.size() > 2:
				return "Attack bonuses must name one or more supported attack domains"
			for attack_domain in attack_domains:
				if not attack_domain is String or attack_domain not in ["weapon_attack", "shared_spell_attack"] or attack_domains.count(attack_domain) != 1:
					return "Attack bonuses must name unique weapon_attack or shared_spell_attack domains"
			if not attack_policy is String or str(attack_policy) not in SpellDamageRolls.FAILED_SAVE_BONUS_PAYMENT_POLICIES:
				return "Attack bonuses require a supported payment_policy"
			if feature.get("type", "") != "passive" or not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary:
				return "Weapon attack bonuses require a passive feature with its owned numeric pool"
			var attack_pool_error := ResourcePoolRules.definition_error(feature)
			if not attack_pool_error.is_empty():
				return "Attack bonus pool is invalid: %s" % attack_pool_error
			for attack_field in effect:
				if attack_field not in ["type", "amount", "die_size", "cost", "domains", "payment_policy"]:
					return "Attack bonus contains an unsupported field"
		if effect.get("type", "") == "failed_save_outcome_override":
			var ability := str(effect.get("ability", "")).to_upper()
			var cost: Variant = effect.get("cost", null)
			if ability not in VALID_ABILITIES or not ResourcePoolRules._integer(cost, 1, ResourcePoolRules.MAX_CAPACITY):
				return "Failed-save outcome overrides require a supported ability and pool cost from 1 to 100"
			if ability in failed_save_modification_abilities:
				return "A passive source can declare only one failed-save modification per ability"
			failed_save_modification_abilities.append(ability)
			if feature.get("type", "") != "passive" or not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary:
				return "Failed-save outcome overrides require a passive feature with its owned numeric pool"
			var pool_error := ResourcePoolRules.definition_error(feature)
			if not pool_error.is_empty():
				return "Failed-save outcome override pool is invalid: %s" % pool_error
			for field in effect:
				if field not in ["type", "ability", "cost"]:
					return "Failed-save outcome override contains an unsupported field"
		if effect.get("type", "") == "roll_outcome_override":
			var override_domains: Variant = effect.get("domains", null)
			var override_outcomes: Variant = effect.get("outcomes", null)
			var override_cost: Variant = effect.get("cost", null)
			if not override_domains is Array or override_domains.is_empty() or not override_outcomes is Array or override_outcomes.is_empty() or not ResourcePoolRules._integer(override_cost, 1, ResourcePoolRules.MAX_CAPACITY):
				return "Roll outcome overrides require domains, outcomes and a pool cost from 1 to 100"
			var seen_domains: Array[String] = []
			for override_domain in override_domains:
				if not override_domain is String or override_domain not in ["weapon_attack", "shared_spell_attack", "shared_spell_save"] or str(override_domain) in seen_domains:
					return "Roll outcome override contains an unsupported or duplicate domain"
				seen_domains.append(str(override_domain))
			var seen_outcomes: Array[String] = []
			for override_outcome in override_outcomes:
				if not override_outcome is String or override_outcome not in ["hit", "miss", "success", "failure"] or str(override_outcome) in seen_outcomes:
					return "Roll outcome override contains an unsupported or duplicate outcome"
				seen_outcomes.append(str(override_outcome))
			for override_domain in seen_domains:
				var expected_outcomes: Array = ["success", "failure"] if override_domain == "shared_spell_save" else ["hit", "miss"]
				for override_outcome in seen_outcomes:
					if override_outcome not in expected_outcomes:
						return "Roll outcome override outcome does not match its domain"
				var override_stage := "after_roll_before_consequences" if override_domain == "shared_spell_save" else "provisional_outcome"
				if str(effect.get("stage", "")) != override_stage:
					return "Roll outcome override stage does not match its authorized domain window"
				if override_domain != "shared_spell_save":
					if override_domain in weapon_attack_bonus_domains:
						return "A passive source can declare only one modification per attack domain"
					weapon_attack_bonus_domains.append(override_domain)
			if seen_domains.has("shared_spell_save") and str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES:
				return "Saving-throw outcome overrides require a supported ability"
			if seen_domains.has("shared_spell_save"):
				var override_ability := str(effect.get("ability", "")).to_upper()
				if override_ability in failed_save_modification_abilities:
					return "A passive source can declare only one failed-save modification per ability"
				failed_save_modification_abilities.append(override_ability)
			if not seen_domains.has("shared_spell_save") and effect.has("ability"):
				return "Attack outcome overrides cannot declare a save ability"
			if feature.get("type", "") != "passive" or not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary:
				return "Roll outcome overrides require a passive feature with its owned numeric pool"
			var override_pool_error := ResourcePoolRules.definition_error(feature)
			if not override_pool_error.is_empty():
				return "Roll outcome override pool is invalid: %s" % override_pool_error
			for field in effect:
				if field not in ["type", "domains", "outcomes", "stage", "ability", "cost"]:
					return "Roll outcome override contains an unsupported field"
		if effect.get("type", "") == "ability_check_numeric_bonus":
			var check_amount: Variant = effect.get("amount", null)
			var check_cost: Variant = effect.get("cost", null)
			var check_policy: Variant = effect.get("payment_policy", "pay_on_choice")
			var has_check_amount: bool = effect.has("amount") and not effect.has("die_size") and ResourcePoolRules._integer(check_amount, 1, 20)
			var has_check_die: bool = effect.has("die_size") and not effect.has("amount") and ResourcePoolRules._integer(effect.get("die_size"), 1, 20) and int(effect.get("die_size")) in ResourcePoolRules.SUPPORTED_DIE_SIZES
			for required_field in ["id", "domain", "ability", "skill", "required_tool_id"]:
				if not effect.get(required_field, "") is String:
					return "Ability-check bonus eligibility fields must be strings"
				if required_field not in ["skill", "required_tool_id"] and str(effect.get(required_field, "")).strip_edges().is_empty():
					return "Ability-check bonuses require explicit identity and check-context eligibility fields"
			var effect_skill := str(effect.get("skill", ""))
			if not str(effect.get("id", "")).is_valid_identifier() or str(effect.get("domain", "")) != "event_skill_check" or str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES or (not effect_skill.is_empty() and effect_skill not in VALID_SKILLS):
				return "Ability-check bonuses require a supported domain, ability, optional supported skill and effect ID"
			var filter_error := ClassFeature.ability_check_filter_error(effect)
			if not filter_error.is_empty(): return filter_error
			if not (has_check_amount or has_check_die) or not ResourcePoolRules._integer(check_cost, 1, ResourcePoolRules.MAX_CAPACITY):
				return "Ability-check bonuses require one amount (1-20) or supported die_size and pool cost from 1 to 100"
			if not check_policy is String or str(check_policy) not in SpellDamageRolls.FAILED_SAVE_BONUS_PAYMENT_POLICIES:
				return "Ability-check bonuses require a supported payment_policy"
			var check_filter := "%s|%s|%s|%s|%s|%s|%s|%s" % [str(effect.get("domain", "")), str(effect.get("ability", "")).to_upper(), str(effect.get("skill", "")), str(effect.get("task_id", "")), str(effect.get("purpose_id", "")), str(effect.get("required_tool_id", "")), str(effect.get("source_event_id", "")), str(effect.get("source_check_id", ""))]
			if check_filter in ability_check_bonus_filters:
				return "A passive source can declare only one ability-check modification for one exact context"
			ability_check_bonus_filters.append(check_filter)
			if feature.get("type", "") != "passive" or not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary:
				return "Ability-check numeric bonuses require a passive feature with its owned numeric pool"
			var check_pool_error := ResourcePoolRules.definition_error(feature)
			if not check_pool_error.is_empty():
				return "Ability-check bonus pool is invalid: %s" % check_pool_error
			for check_field in effect:
				if check_field not in ["type", "id", "domain", "ability", "skill", "task_id", "purpose_id", "required_tool_id", "source_event_id", "source_check_id", "amount", "die_size", "cost", "payment_policy"]:
					return "Ability-check bonus contains an unsupported field"
		if effect.get("type", "") == "ability_check_mandatory_reroll":
			var reroll_cost: Variant = effect.get("cost", null)
			var outcomes: Variant = effect.get("eligible_outcomes", null)
			var reroll_domain := str(effect.get("domain", ""))
			var reroll_mode := str(effect.get("reroll_mode", ""))
			var bonus_policy := str(effect.get("bonus_dice_policy", ""))
			for required_field in ["id", "domain", "ability"]:
				if not effect.get(required_field, "") is String:
					return "Ability-check reroll eligibility fields must be strings"
			var reroll_skill := str(effect.get("skill", ""))
			if not str(effect.get("id", "")).is_valid_identifier() or reroll_domain not in ["event_skill_check", "weapon_attack", "shared_spell_attack", "shared_spell_save"] or str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES or (not reroll_skill.is_empty() and reroll_skill not in VALID_SKILLS):
				return "Test rerolls require a supported domain, ability, optional supported skill and effect ID"
			var allowed_test_outcomes: Array = ["success", "failure"] if reroll_domain in ["event_skill_check", "shared_spell_save"] else ["hit", "miss"]
			if reroll_domain == "event_skill_check":
				var filter_error := ClassFeature.ability_check_filter_error(effect)
				if not filter_error.is_empty(): return filter_error
			elif not reroll_skill.is_empty() or effect.has("task_id") or effect.has("purpose_id") or effect.has("required_tool_id") or effect.has("source_event_id") or effect.has("source_check_id"):
				return "Combat test rerolls cannot declare event-check eligibility fields"
			if not outcomes is Array or outcomes.is_empty() or outcomes.size() > 2 or outcomes.any(func(value): return value not in allowed_test_outcomes) or (outcomes.size() == 2 and outcomes[0] == outcomes[1]):
				return "Test rerolls must declare unique eligible outcomes for their domain"
			if reroll_mode not in ["natural_only", "whole_test"] or bonus_policy not in ["keep", "reroll"] or not ResourcePoolRules._integer(reroll_cost, 1, ResourcePoolRules.MAX_CAPACITY):
				return "Test rerolls require a supported reroll mode, bonus-dice policy and pool cost"
			if str(effect.get("selection_policy", "mandatory_new")) not in ["mandatory_new", "choose_old_or_new"] or str(effect.get("new_roll_mode", "captured")) not in ["captured", "normal", "advantage", "disadvantage"]:
				return "Ability-check rerolls require a supported kept-result and new-test mode policy"
			if effect.has("level_bonus_formula") and (not SharedStepExecutor.formula_content_error(effect.get("level_bonus_formula")).is_empty() or not ResourcePoolRules._actor_formula_error(effect.get("level_bonus_formula")).is_empty()):
				return "Ability-check reroll level bonus requires an actor-only formula"
			for reroll_field in effect:
				if reroll_field not in ["type", "id", "domain", "ability", "skill", "task_id", "purpose_id", "required_tool_id", "source_event_id", "source_check_id", "spell_id", "eligible_outcomes", "reroll_mode", "bonus_dice_policy", "selection_policy", "new_roll_mode", "level_bonus_formula", "cost"]:
					return "Test reroll contains an unsupported field"
			if effect.has("spell_id") and (reroll_domain not in ["shared_spell_attack", "shared_spell_save"] or get_spell(str(effect.get("spell_id", ""))).is_empty()):
				return "Spell reroll source must name a loaded shared spell"
			var reroll_filter := "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [reroll_domain, str(effect.get("ability", "")).to_upper(), reroll_skill, str(effect.get("task_id", "")), str(effect.get("purpose_id", "")), str(effect.get("required_tool_id", "")), str(effect.get("source_event_id", "")), str(effect.get("source_check_id", "")), str(effect.get("id", ""))]
			if reroll_filter in ability_check_reroll_filters:
				return "A passive source cannot repeat one ability-check reroll effect ID"
			ability_check_reroll_filters.append(reroll_filter)
			if feature.get("type", "") != "passive" or not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary:
					return "Test rerolls require a passive feature with its owned numeric pool"
			var reroll_pool_error := ResourcePoolRules.definition_error(feature)
			if not reroll_pool_error.is_empty():
				return "Ability-check reroll pool is invalid: %s" % reroll_pool_error
			for reroll_field in effect:
				if reroll_field not in ["type", "id", "domain", "ability", "skill", "task_id", "purpose_id", "required_tool_id", "source_event_id", "source_check_id", "spell_id", "eligible_outcomes", "reroll_mode", "bonus_dice_policy", "selection_policy", "new_roll_mode", "level_bonus_formula", "cost"]:
					return "Test reroll contains an unsupported field"
		if effect.get("type", "") in ["warlock_invocations", "warlock_mystic_arcanum"] and feature.get("type", "") != "passive":
			return "Warlock progression features must be passive"
		if effect.get("type", "") == "warlock_mystic_arcanum" and int(effect.get("spell_level", 0)) not in [6, 7, 8, 9]:
			return "Mystic Arcanum must name a spell level from 6 to 9"
		if effect.get("type", "") == "source_benefits":
			if feature.get("type", "") != "passive" or effect.size() != 2 or not SourceBenefitRules.benefits_error(effect.get("benefits")).is_empty(): return "Invalid passive source benefits"
		if effect.get("type", "") == "feature_choice":
			var options: Variant = effect.get("options", [])
			if not options is Array or options.size() < 2:
				return "Feature choice requires at least two options"
			for count_field in ["count", "pick"]:
				if effect.has(count_field) and not SharedStepExecutor._integer(effect[count_field], 1, options.size()):
					return "Feature choice count/pick must be an integer between 1 and the option count"
			if effect.has("count") and effect.has("pick") and int(effect.count) != int(effect.pick):
				return "Feature choice count and pick must agree"
			if effect.has("allow_duplicates") and not effect["allow_duplicates"] is bool:
				return "Feature choice allow_duplicates must be a boolean"
			if effect.has("allow_replacement") and not effect["allow_replacement"] is bool:
				return "Feature choice allow_replacement must be a boolean"
			var seen_feature_options: Array[String] = []
			for option in options:
				if not option is Dictionary or not option.get("id", "") is String or option.get("id", "").is_empty() or not option.get("name", "") is String or option.get("name", "").is_empty() or option.get("id", "") in seen_feature_options or not option.get("effects", []) is Array:
					return "Feature choice options require unique IDs, names, and effect arrays"
				seen_feature_options.append(str(option["id"]))
				if option.has("minimum_level") and not SharedStepExecutor._integer(option["minimum_level"], 1, 20):
					return "Feature choice option minimum level must be from 1 to 20"
				if option.has("class_id") and (not option["class_id"] is String or option["class_id"].is_empty()):
					return "Feature choice option class ID must be a nonempty string"
				if option.has("repeatable") and not option["repeatable"] is bool:
					return "Feature choice option repeatable must be a boolean"
				if option.has("requires_choices"):
					var reqs: Variant = option["requires_choices"]
					if not reqs is Array or reqs.is_empty() or reqs.any(func(val): return not val is String or str(val).is_empty()):
						return "Feature choice option requires_choices must be a nonempty array of choice IDs"
				if option.has("when"):
					var when: Variant = option["when"]
					if not when is Dictionary or when.is_empty():
						return "Feature choice option predicate must be a nonempty dictionary"
					var when_err := SharedStepExecutor.validate_actor_predicate(when)
					if not when_err.is_empty():
						return "Feature choice option predicate is invalid: " + when_err
				if option["effects"].filter(func(e): return e is Dictionary and e.get("type", "") == "source_benefits").size() > 1: return "One source benefits payload per option."
				for option_effect in option["effects"]:
					if not option_effect is Dictionary or option_effect.get("type", "") not in ["proficiency_grant", "spellcasting_capacity_bonus", "ability_check_bonus", "weapon_damage_rider", "spell_damage_bonus", "spell_range_bonus", "spell_cast_temporary_hp", "fighting_style", "spell_list_expansion", "extra_attack", "source_benefits"]:
						return "Feature choice contains an unsupported option effect"
					if option_effect.get("type", "") == "source_benefits" and (option_effect.size() != 2 or not SourceBenefitRules.benefits_error(option_effect.get("benefits")).is_empty()): return "Invalid choice source benefits"
					if option_effect.get("type", "") == "fighting_style" and option_effect.get("style", "") not in ["archery", "defense", "great_weapon_fighting", "two_weapon_fighting"]:
						return "Feature choice contains an unsupported fighting style"
					if option_effect.get("type", "") == "spell_list_expansion":
						var expanded_lists: Variant = option_effect.get("spell_lists", [])
						if not expanded_lists is Array or expanded_lists.is_empty() or expanded_lists.any(func(value): return not str(value).is_valid_identifier()):
							return "Feature choice spell list expansion requires class list IDs"
					if option_effect.get("type", "") == "proficiency_grant":
						for proficiency in option_effect.get("weapon_proficiencies", []) + option_effect.get("armor_proficiencies", []):
							if not proficiency is String or proficiency.is_empty():
								return "Proficiency grants must contain nonempty names"
					if option_effect.get("type", "") == "spellcasting_capacity_bonus" and (option_effect.get("kind", "") not in ["cantrips", "prepared_spells"] or int(option_effect.get("amount", 0)) < 1 or int(option_effect.get("amount", 0)) > 5):
						return "Spellcasting capacity bonuses require a supported kind and amount from 1-5"
					if option_effect.get("type", "") == "ability_check_bonus":
						var skills: Variant = option_effect.get("skills", [])
						if not skills is Array or skills.is_empty() or str(option_effect.get("ability", "")).to_upper() not in VALID_ABILITIES or int(option_effect.get("minimum_bonus", 0)) < 0 or int(option_effect.get("minimum_bonus", 0)) > 20:
							return "Ability check bonuses require skills, a valid ability, and a minimum from 0-20"
					if option_effect.get("type", "") == "weapon_damage_rider":
						var dice_table: Variant = option_effect.get("dice_by_level", {})
						var valid_damage_types := ["radiant", "necrotic", "fire", "cold", "lightning", "thunder", "acid", "poison", "psychic", "force"]
						var damage_type_options: Variant = option_effect.get("damage_type_options", [])
						var damage_type_valid: bool = str(option_effect.get("damage_type", "")) in valid_damage_types or (damage_type_options is Array and not damage_type_options.is_empty() and damage_type_options.all(func(value): return str(value) in valid_damage_types))
						if option_effect.get("trigger", "") != "weapon_attack_hit" or option_effect.get("uses_per", "") != "turn" or not damage_type_valid or not dice_table is Dictionary or dice_table.is_empty():
							return "Weapon damage riders require a weapon-hit trigger, damage type, turn limit, and dice table"
						for key in dice_table:
							if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20 or str(dice_table[key]).is_empty():
								return "Weapon damage rider levels and dice are invalid"
					if option_effect.get("type", "") in ["spell_damage_bonus", "spell_range_bonus", "spell_cast_temporary_hp"] and (int(option_effect.get("spell_level", -1)) != 0 or not str(option_effect.get("spell_list", "")).is_valid_identifier()):
						return "Spell damage bonuses require a valid ability, cantrip level and class spell list"
					if option_effect.get("type", "") == "spell_damage_bonus" and str(option_effect.get("ability", "")).to_upper() not in VALID_ABILITIES:
						return "Spell damage bonuses require a valid ability score"
					if option_effect.get("type", "") == "spell_range_bonus":
						var range_table: Variant = option_effect.get("bonus_feet_by_level", {})
						if int(option_effect.get("minimum_range_feet", 0)) < 1 or not range_table is Dictionary or range_table.is_empty() or str(option_effect.get("requires_feature", "")).is_empty():
							return "Spell range bonuses require a minimum range, level table, and feature gate"
						for key in range_table:
							if not str(key).is_valid_int() or int(key) < 1 or int(key) > 20 or int(range_table[key]) < 1:
								return "Spell range bonus levels and distances are invalid"
					if option_effect.get("type", "") == "spell_cast_temporary_hp" and (int(option_effect.get("multiplier", 0)) < 1 or option_effect.get("action_cost", "") != "magic_action" or str(option_effect.get("requires_feature", "")).is_empty()):
						return "Spell temporary Hit Points require a multiplier, Magic action, and feature gate"
		if effect.get("type", "") == "always_prepared_spells" and (not effect.get("spells", []) is Array or effect.get("spells", []).is_empty()):
			return "Always-prepared spells requires a spell ID list"
		if effect.get("type", "") == "spell_free_cast":
			var free_cast_spells: Variant = effect.get("spells", [])
			var free_cast_uses_by_level: Variant = effect.get("uses_by_level", {})
			if not free_cast_uses_by_level is Dictionary or not free_cast_spells is Array or free_cast_spells.is_empty() or free_cast_spells.any(func(spell_id): return not str(spell_id).is_valid_identifier()) or int(effect.get("uses", 1)) < 1 or effect.get("uses_per", "long_rest") != "long_rest":
				return "Free spell casts require spell IDs, positive uses, and Long Rest recovery"
			for key in free_cast_uses_by_level:
				var count: Variant = free_cast_uses_by_level[key]
				if not str(key).is_valid_int() or int(key) < 1 or int(key) > 20 or not (count is int or count is float) or int(count) < 1 or int(count) > 100:
					return "Free spell cast level capacities must be positive values for levels 1-20"
		if effect.get("type", "") == "concentration_protection":
			if feature.get("type", "") != "passive" or not effect.get("spells", []) is Array or effect.get("spells", []).is_empty() or effect.get("spells", []).any(func(spell_id): return not str(spell_id).is_valid_identifier()):
				return "Concentration protection must be a passive feature naming spell IDs"
		if effect.get("type", "") == "spell_damage_dice_override":
			if feature.get("type", "") != "passive" or not str(effect.get("spell_id", "")).is_valid_identifier() or str(effect.get("dice", "")) not in ["1d4", "1d6", "1d8", "1d10", "1d12", "2d6", "2d8"]:
				return "Spell damage die upgrades require a passive feature, spell ID and supported die expression"
		if effect.get("type", "") == "attack_advantage_against_condition" and (feature.get("type", "") != "passive" or not str(effect.get("condition", "")).is_valid_identifier()):
			return "Condition-based attack advantage requires a passive feature and condition ID"
		if effect.get("type", "") == "blindsight" and (feature.get("type", "") != "passive" or int(effect.get("range_feet", 0)) < 5 or int(effect.get("range_feet", 0)) > 300 or int(effect.get("range_feet", 0)) % 5 != 0):
			return "Blindsight requires a passive feature and range in 5-foot steps"
		if effect.get("type", "") == "protection_aura":
			if feature.get("type") != "passive": return "Protection aura must be passive."
			var protection_aura_error := AuraProtectionRules.content_error(effect)
			if not protection_aura_error.is_empty(): return protection_aura_error
		if effect.get("type", "") == "saving_throw_aura":
			var aura_id := str(effect.get("aura_id", ""))
			var aura_radius := int(effect.get("radius_feet", 0))
			if not aura_id.is_valid_identifier() or str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES or int(effect.get("minimum_bonus", 0)) < 1 or int(effect.get("minimum_bonus", 0)) > 20 or aura_radius < 5 or aura_radius > 150 or aura_radius % 5 != 0:
				return "Saving-throw auras require an aura ID, valid ability/minimum bonus, and radius in 5-foot steps"
		if effect.get("type", "") == "aura_radius_expansion":
			var expanded_aura_id := str(effect.get("aura_id", ""))
			var expanded_radius := int(effect.get("radius_feet", 0))
			if not expanded_aura_id.is_valid_identifier() or expanded_radius < 5 or expanded_radius > 150 or expanded_radius % 5 != 0:
				return "Aura expansion requires an aura ID and radius in 5-foot steps"
		if effect.get("type", "") == "condition_immunity_aura":
			var condition_aura_id := str(effect.get("aura_id", ""))
			var condition_radius: Variant = effect.get("radius_feet", 0)
			if not condition_aura_id.is_valid_identifier() or str(effect.get("condition", "")) not in ["blinded", "charmed", "deafened", "frightened", "paralyzed", "petrified", "poisoned", "stunned"]:
				return "Condition immunity auras require an aura ID and supported condition"
			if effect.has("radius_feet") and (not (condition_radius is int or condition_radius is float) or not is_finite(float(condition_radius)) or float(condition_radius) != floor(float(condition_radius)) or int(condition_radius) < 5 or int(condition_radius) > 150 or int(condition_radius) % 5 != 0):
				return "Condition immunity aura radius must use 5-foot steps from 5 to 150"
		if effect.get("type", "") == "weapon_damage_rider":
			var rider_error := _weapon_damage_rider_error(effect)
			if not rider_error.is_empty():
				return rider_error
			if effect.has("use_limit") and (not feature.has("resource_pool") or not feature["resource_pool"] is Dictionary or feature["resource_pool"].is_empty()):
				return "A bounded weapon damage rider requires its feature's exact source resource pool"
			if (str(effect.get("use_limit", "")) == "once_per_active_instance" or effect.has("payment_waiver")) and not feature.get("effects", []).any(func(entry): return entry is Dictionary and str(entry.get("type", "")) == "timed_numeric_modifier"):
				return "Active-instance riders and waivers require this source's timed numeric modifier activation"
		if effect.get("type", "") == "additional_spell_target" and (not effect.get("spells", []) is Array or effect.get("spells", []).is_empty() or int(effect.get("additional_targets", 0)) < 1 or int(effect.get("range_from_primary_feet", 0)) < 1):
			return "Additional spell targets requires spell IDs, a target count, and a range"
		if effect.get("type", "") == "epic_boon_choice":
			var boons: Variant = effect.get("options", [])
			if not boons is Array or boons.is_empty():
				return "Epic Boon choice requires an option list"
			var seen_boons: Array[String] = []
			for boon in boons:
				if boon not in ["combat_prowess", "irresistible_offense", "spell_recall"] or boon in seen_boons:
					return "Epic Boon choice contains an unsupported or duplicate option"
				seen_boons.append(str(boon))
			var ability_rules: Variant = effect.get("ability_scores_by_option", {})
			if not ability_rules is Dictionary:
				return "Epic Boon ability restrictions must be an object"
			for boon_id in ability_rules:
				if boon_id not in boons or not ability_rules[boon_id] is Array or ability_rules[boon_id].is_empty():
					return "Epic Boon ability restriction references an invalid option"
				for ability in ability_rules[boon_id]:
					if str(ability).to_upper() not in VALID_ABILITIES:
						return "Epic Boon ability restriction contains an invalid ability"
		if effect.get("type", "") == "skill_proficiency_choice":
			var options: Variant = effect.get("options", [])
			var count := int(effect.get("count", 1))
			if not options is Array or options.is_empty() or count < 1 or count > options.size():
				return "Skill proficiency choice requires a bounded option list and count"
			var seen_options: Array[String] = []
			for option in options:
				if not option is String or option.is_empty() or option.length() > 32 or option in seen_options:
					return "Skill proficiency choices must be unique skill names"
				seen_options.append(option)
		if effect.get("type", "") == "skill_expertise_choice":
			var expertise_count := int(effect.get("count", 2))
			if expertise_count < 1 or expertise_count > 18:
				return "Expertise choice requires a bounded number of skills"
			var allowed_expertise_skills: Variant = effect.get("allowed_skills", [])
			if not allowed_expertise_skills is Array or allowed_expertise_skills.size() > 18 or allowed_expertise_skills.any(func(skill): return not skill is String or skill.is_empty()) or (not allowed_expertise_skills.is_empty() and expertise_count > allowed_expertise_skills.size()):
				return "Expertise choice allowed skills must be a bounded list that fits its count"
		if effect.get("type", "") == "jack_of_all_trades" and feature.get("type", "") != "passive":
			return "Jack of All Trades must be passive"
		if effect.get("type", "") == "pact_magic_recovery" and effect.has("fraction_by_level"):
			var pact_recovery_table: Variant = effect["fraction_by_level"]
			if not pact_recovery_table is Dictionary or pact_recovery_table.is_empty() or not pact_recovery_table.has("1"):
				return "Pact Magic recovery level fractions must include level 1"
			for key in pact_recovery_table:
				var recovery_fraction: Variant = pact_recovery_table[key]
				if not str(key).is_valid_int() or int(key) < 1 or int(key) > 20 or not (recovery_fraction is int or recovery_fraction is float) or float(recovery_fraction) < 0.0 or float(recovery_fraction) > 1.0:
					return "Pact Magic recovery fractions must be between 0 and 1 for levels 1-20"
		if effect.get("type", "") == "short_rest_recharge" and (feature.get("type", "") != "passive" or str(effect.get("resource_id", "")).is_empty()):
			return "Short-rest recharge must name a resource on a passive feature"
		if effect.get("type", "") == "short_rest_recharge":
			if effect.has("once_per_long_rest") and not effect["once_per_long_rest"] is bool:
				return "Short-rest recharge cadence flag must be boolean"
			var recovery_table: Variant = effect.get("amount_by_level", {})
			if not recovery_table is Dictionary:
				return "Short-rest recovery level amounts must be a table"
			for key in recovery_table:
				var recovery_amount: Variant = recovery_table[key]
				if not str(key).is_valid_int() or int(key) < 1 or int(key) > 20 or not (recovery_amount is int or recovery_amount is float) or int(recovery_amount) < 1 or int(recovery_amount) > 100:
					return "Short-rest recovery level amounts must be positive values for levels 1-20"
		if effect.get("type", "") == "initiative_resource_recovery" and (feature.get("type", "") != "passive" or str(effect.get("resource_id", "")).is_empty() or int(effect.get("minimum", 1)) < 1 or int(effect.get("minimum", 1)) > 100):
			return "Initiative recovery must name a resource and a minimum from 1-100 on a passive feature"
		if effect.get("type", "") == "resource_from_spell_slot" and (feature.get("type", "") != "passive" or str(effect.get("resource_id", "")).is_empty() or int(effect.get("amount", 1)) < 1 or int(effect.get("amount", 1)) > 100):
			return "Spell-slot recovery must name a resource and a positive amount on a passive feature"
		if effect.get("type", "") == "spellcasting":
			if effect.has("separate_repertoire") and not effect.separate_repertoire is bool: return "Separate repertoire policy must be a boolean"
			if effect.get("replacement", "level") not in ["level", "long_rest", "fixed"]: return "Unknown repertoire replacement boundary"
			if not ResourcePoolRules._integer(effect.get("replacement_count", 1), 0, 100): return "Invalid repertoire replacement count"
			if not ResourcePoolRules._integer(effect.get("maximum_spell_level", 9), 0, 9): return "Invalid spell permission level limit"
			for field in ["spell_lists", "allowed_components", "book_spells"]:
				if not effect.has(field): continue
				if not effect[field] is Array: return "Spell permission restrictions must be arrays"
				for value in effect[field]:
					if not value is String or (field == "allowed_components" and value not in ["V", "S", "M"]): return "Invalid spell permission restriction"
			if feature.get("type", "") != "passive" or str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES:
				return "Spellcasting must be a passive feature with a spellcasting ability"
			var capacities: Variant = effect.get("capacity_by_level", {})
			if not capacities is Dictionary or capacities.size() != 20:
				return "Spellcasting capacity must define all character levels 1-20"
			var previous_cantrips := 0
			var previous_prepared := 0
			for spell_level in range(1, 21):
				var capacity: Variant = capacities.get(str(spell_level), {})
				if not capacity is Dictionary:
					return "Spellcasting capacity entries must be objects"
				for field in ["cantrips", "prepared_spells"]:
					var count: Variant = capacity.get(field, -1)
					if not (count is int or count is float) or float(count) != float(int(count)) or int(count) < 0 or int(count) > 100:
						return "Spellcasting %s capacity must be an integer from 0-100" % field
				if int(capacity["cantrips"]) < previous_cantrips or int(capacity["prepared_spells"]) < previous_prepared:
					return "Spellcasting capacities cannot decrease as class level increases"
				previous_cantrips = int(capacity["cantrips"])
				previous_prepared = int(capacity["prepared_spells"])
			for field in ["default_cantrips", "default_prepared_spells"]:
				var defaults: Variant = effect.get(field, [])
				if not defaults is Array:
					return "Spellcasting defaults must be spell ID arrays"
		if effect.get("type", "") == "spell_list_expansion":
			if feature.get("type", "") != "passive" or not effect.get("spell_lists", []) is Array:
				return "Spell list expansion must be a passive feature with a spell list array"
		if effect.get("type", "") == "weapon_mastery":
			var capacity: Variant = effect.get("capacity_by_level", {})
			if not capacity is Dictionary or capacity.is_empty() or not capacity.has("1"):
				return "Weapon Mastery requires a level-1 capacity table"
			var prior_capacity := 0
			var capacity_levels: Array = capacity.keys()
			capacity_levels.sort_custom(func(a, b): return int(a) < int(b))
			for key in capacity_levels:
				var value: Variant = capacity[key]
				if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20 or not (value is int or value is float) or float(value) != float(int(value)) or int(value) < prior_capacity or int(value) > 20:
					return "Weapon Mastery capacities must be increasing integers at levels 1-20"
				prior_capacity = int(value)
			if effect.has("melee_only") and not effect["melee_only"] is bool:
				return "Weapon Mastery melee_only must be boolean"
		if effect.get("type", "") == "ability_score_increase":
			var scores: Variant = effect.get("scores", {})
			var maximum := int(effect.get("maximum", 20))
			if not scores is Dictionary or scores.is_empty() or maximum < 1 or maximum > 30:
				return "Fixed ability score increase needs scores and a maximum from 1-30"
			for ability in scores:
				var amount: Variant = scores[ability]
				if str(ability).to_upper() not in VALID_ABILITIES or not (amount is int or amount is float) or float(amount) != float(int(amount)) or int(amount) < 1 or int(amount) > 10:
					return "Fixed ability score increase has an invalid ability or amount"
		if effect.get("type", "") == "saving_throw_advantage" and str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES:
			return "Saving throw advantage requires a supported ability"
		if effect.get("type", "") == "ability_check_advantage" and str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES:
			return "Ability check effect requires a supported ability"
		if effect.get("type", "") == "ability_check_floor" and not effect.has("minimum_roll") and str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES:
			return "Ability check floor requires a supported ability or a minimum die roll"
		if effect.get("type", "") == "ability_check_override":
			var skills: Variant = effect.get("skills", [])
			if not skills is Array or skills.is_empty() or skills.size() > 18:
				return "Ability check override requires a bounded skill list"
			for skill in skills:
				if not skill is String or skill.is_empty() or skill.length() > 32:
					return "Ability check override contains an invalid skill"
				if str(effect.get("ability", "")).to_upper() not in VALID_ABILITIES:
					return "Ability check override requires a supported ability"
		if effect.get("type", "") == "ability_check_floor":
			var applies_to: Variant = effect.get("applies_to", [])
			if not applies_to is Array or applies_to.is_empty():
				return "Ability check floor requires a check type"
			for check_type in applies_to:
				if check_type not in ["ability_check", "saving_throw"]:
					return "Ability check floor contains an unsupported check type"
			if effect.has("minimum_roll") and (int(effect["minimum_roll"]) < 1 or int(effect["minimum_roll"]) > 20 or not effect.get("requires_proficiency", false) is bool):
				return "Minimum check rolls must be 1-20 with an explicit proficiency requirement"
		if effect.get("type", "") == "saving_throw_proficiency":
			var save_abilities: Variant = effect.get("abilities", [])
			if feature.get("type", "") != "passive" or not save_abilities is Array or save_abilities.is_empty() or save_abilities.any(func(ability): return str(ability).to_upper() not in VALID_ABILITIES):
				return "Saving-throw proficiency requires a passive feature with valid abilities"
		for field in ["condition", "unless_condition"]:
			if effect.has(field) and (not effect[field] is String or effect[field].is_empty() or not effect[field].is_valid_identifier()):
				return "Conditional feature effect requires a simple condition ID"
		if effect.get("type", "") == "speed_bonus":
			var bonus := int(effect.get("bonus", 0))
			if bonus < 0 or bonus > 20:
				return "Speed bonus must be between 0 and 20 tiles"
			var levels: Variant = effect.get("bonus_by_level", {})
			if not levels is Dictionary:
				return "Speed bonus scaling must be a level table"
			for key in levels:
				var value: Variant = levels[key]
				if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20 or not (value is int or value is float) or float(value) != float(int(value)) or int(value) < 0 or int(value) > 20:
					return "Speed bonus scaling requires integer levels 1-20 and bonuses 0-20"
		if effect.get("type", "") == "roll_token_pool":
			var pool_id: Variant = effect.get("pool_id", "")
			var die_sides: Variant = effect.get("die_sides", 0)
			var timing := str(effect.get("generation_timing", ""))
			var predicate := str(effect.get("target_predicate", ""))
			var uses_per_turn: Variant = effect.get("uses_per_turn", 0)
			if not (pool_id is String) or str(pool_id).strip_edges().is_empty():
				return "Roll token pool requires a nonempty pool_id"
			if typeof(die_sides) == TYPE_BOOL or not (die_sides is int or die_sides is float) or int(die_sides) != 20:
				return "Roll token pool requires die_sides == 20"
			if timing not in RollTokenRules.SUPPORTED_TIMINGS:
				return "Roll token pool requires supported generation_timing"
			if predicate not in RollTokenRules.SUPPORTED_PREDICATES:
				return "Roll token pool requires a supported target_predicate"
			if typeof(uses_per_turn) == TYPE_BOOL or not (uses_per_turn is int or uses_per_turn is float) or float(uses_per_turn) != float(int(uses_per_turn)) or int(uses_per_turn) < 1 or int(uses_per_turn) > 10:
				return "Roll token pool requires integer uses_per_turn from 1-10"
			var has_count: bool = effect.has("token_count")
			var has_table: bool = effect.has("token_count_by_level")
			if not has_count and not has_table:
				return "Roll token pool requires token_count or token_count_by_level"
			if has_count:
				var count: Variant = effect["token_count"]
				if typeof(count) == TYPE_BOOL or not (count is int or count is float) or float(count) != float(int(count)) or int(count) < 1 or int(count) > 10:
					return "Roll token pool token_count must be an integer from 1-10"
			if has_table:
				var table: Variant = effect["token_count_by_level"]
				if not (table is Dictionary) or table.is_empty():
					return "Roll token pool token_count_by_level must be a nonempty object"
				for key in table:
					var val: Variant = table[key]
					if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20 or typeof(val) == TYPE_BOOL or not (val is int or val is float) or float(val) != float(int(val)) or int(val) < 1 or int(val) > 10:
						return "Roll token pool token_count_by_level requires levels 1-20 and counts 1-10"
		if effect.get("type", "") == "roll_token_pool_upgrade":
			var upgrade_pool_id: Variant = effect.get("pool_id", "")
			var upgrade_count: Variant = effect.get("token_count", 0)
			if not (upgrade_pool_id is String) or str(upgrade_pool_id).strip_edges().is_empty():
				return "Roll token pool upgrade requires a nonempty pool_id"
			if typeof(upgrade_count) == TYPE_BOOL or not (upgrade_count is int or upgrade_count is float) or float(upgrade_count) != float(int(upgrade_count)) or int(upgrade_count) < 1 or int(upgrade_count) > 10:
				return "Roll token pool upgrade token_count must be an integer from 1-10"
		if effect.get("type", "") == "damage_ward_pool":
			var ward_pool_id: Variant = effect.get("pool_id", "")
			var creation_trigger := str(effect.get("creation_trigger", ""))
			var trigger_schools: Variant = effect.get("trigger_schools", [])
			var creation_uses_per := str(effect.get("creation_uses_per", ""))
			var level_mult: Variant = effect.get("max_hp_level_multiplier", 0)
			var ability := str(effect.get("max_hp_ability", "")).to_upper()
			var recharge_mult: Variant = effect.get("recharge_slot_multiplier", 0)
			var bonus_recharge: Variant = effect.get("bonus_action_slot_recharge", null)
			if not (ward_pool_id is String) or str(ward_pool_id).strip_edges().is_empty():
				return "Damage ward pool requires a nonempty pool_id"
			if creation_trigger not in WardRules.SUPPORTED_CREATION_TRIGGERS:
				return "Damage ward pool requires supported creation_trigger"
			if not (trigger_schools is Array) or trigger_schools.is_empty() or trigger_schools.any(func(s): return not (s is String) or str(s) not in WardRules.SUPPORTED_SCHOOLS):
				return "Damage ward pool requires a nonempty trigger_schools array of supported spell schools"
			if creation_uses_per not in WardRules.SUPPORTED_CREATION_USES_PER:
				return "Damage ward pool requires supported creation_uses_per"
			if typeof(level_mult) == TYPE_BOOL or not (level_mult is int or level_mult is float) or float(level_mult) != float(int(level_mult)) or int(level_mult) < 1 or int(level_mult) > 10:
				return "Damage ward pool max_hp_level_multiplier must be an integer from 1-10"
			if ability not in VALID_ABILITIES:
				return "Damage ward pool requires a valid max_hp_ability"
			if effect.has("max_hp_flat_bonus"):
				var flat_bonus: Variant = effect["max_hp_flat_bonus"]
				if typeof(flat_bonus) == TYPE_BOOL or not (flat_bonus is int or flat_bonus is float) or float(flat_bonus) != float(int(flat_bonus)) or int(flat_bonus) < -20 or int(flat_bonus) > 100:
					return "Damage ward pool max_hp_flat_bonus must be an integer from -20 to 100"
			if typeof(recharge_mult) == TYPE_BOOL or not (recharge_mult is int or recharge_mult is float) or float(recharge_mult) != float(int(recharge_mult)) or int(recharge_mult) < 1 or int(recharge_mult) > 10:
				return "Damage ward pool recharge_slot_multiplier must be an integer from 1-10"
			if typeof(bonus_recharge) != TYPE_BOOL:
				return "Damage ward pool bonus_action_slot_recharge must be boolean"
		if effect.get("type", "") == "damage_ward_projection":
			var proj_pool_id: Variant = effect.get("pool_id", "")
			var proj_trigger := str(effect.get("trigger", ""))
			var proj_cost := str(effect.get("action_cost", ""))
			var proj_range: Variant = effect.get("range_feet", 0)
			var proj_predicate := str(effect.get("target_predicate", ""))
			if not (proj_pool_id is String) or str(proj_pool_id).strip_edges().is_empty():
				return "Damage ward projection requires a nonempty pool_id"
			if proj_trigger not in WardRules.SUPPORTED_PROJECTION_TRIGGERS:
				return "Damage ward projection requires a supported trigger"
			if proj_cost not in WardRules.SUPPORTED_PROJECTION_ACTION_COSTS:
				return "Damage ward projection requires a supported action_cost"
			if typeof(proj_range) == TYPE_BOOL or not (proj_range is int or proj_range is float) or float(proj_range) != float(int(proj_range)) or int(proj_range) < 5 or int(proj_range) > 300 or int(proj_range) % 5 != 0:
				return "Damage ward projection range_feet must be 5-300 in 5-foot steps"
			if proj_predicate not in WardRules.SUPPORTED_PROJECTION_PREDICATES:
				return "Damage ward projection requires a supported target_predicate"
		if effect.get("type", "") == "rest_slot_recovery":
			for field in effect:
				if field not in ["type", "trigger", "class_level_source", "budget_formula", "flat_budget", "min_slot_level", "max_slot_level", "slot_pool", "recoverable_pool_ids", "excluded_resource_pool_ids", "lowest_eligible_slot", "lower_than_paid_slot"]:
					return "Rest slot recovery contains unsupported field '%s'" % str(field)
			if feature.get("type", "") not in ["triggered", "active"]:
				return "Rest slot recovery requires a triggered or active feature"
			var uses_err := _uses_content_error(feature)
			if not uses_err.is_empty():
				return uses_err
			if not feature.has("resource_id") and str(feature.get("uses_per", "")) not in ["long_rest", "short_rest", "rest"]:
				return "Rest slot recovery requires a rest recovery cadence or resource_id"
			var rec_trigger := str(effect.get("trigger", ""))
			var cls_source: Variant = effect.get("class_level_source", "")
			var formula := str(effect.get("budget_formula", ""))
			var min_lvl: Variant = effect.get("min_slot_level", 1)
			var max_lvl: Variant = effect.get("max_slot_level", 0)
			if rec_trigger not in RestRules.SUPPORTED_TRIGGERS:
				return "Rest slot recovery requires a supported trigger"
			if not (cls_source is String) or str(cls_source).strip_edges().is_empty():
				return "Rest slot recovery requires a nonempty class_level_source"
			if formula not in RestRules.SUPPORTED_BUDGET_FORMULAS:
				return "Rest slot recovery requires a supported budget_formula"
			if formula == "flat":
				var flat_val: Variant = effect.get("flat_budget", 0)
				if typeof(flat_val) == TYPE_BOOL or not (flat_val is int or flat_val is float) or float(flat_val) != float(int(flat_val)) or int(flat_val) < 1 or int(flat_val) > 20:
					return "Rest slot recovery flat_budget must be an integer from 1-20"
			if str(effect.get("slot_pool", "ordinary")) not in ["ordinary", "pact"]: return "Rest slot recovery slot_pool must be ordinary or pact"
			if typeof(min_lvl) == TYPE_BOOL or not (min_lvl is int or min_lvl is float) or float(min_lvl) != float(int(min_lvl)) or int(min_lvl) < 1 or int(min_lvl) > 9:
				return "Rest slot recovery min_slot_level must be an integer from 1-9"
			if typeof(max_lvl) == TYPE_BOOL or not (max_lvl is int or max_lvl is float) or float(max_lvl) != float(int(max_lvl)) or int(max_lvl) < int(min_lvl) or int(max_lvl) > 9:
				return "Rest slot recovery max_slot_level must be an integer from min_slot_level to 9"
			for field in ["lowest_eligible_slot", "lower_than_paid_slot"]:
				if effect.has(field) and not effect[field] is bool: return "Rest slot recovery %s must be boolean" % field
			for field in ["recoverable_pool_ids", "excluded_resource_pool_ids"]:
				if effect.has(field):
					var pool_ids: Variant = effect[field]
					if not pool_ids is Array or pool_ids.size() > 40: return "Rest slot recovery %s must be a bounded array" % field
					var seen_pool_ids: Dictionary = {}
					for pool_id in pool_ids:
						if not pool_id is String or str(pool_id).strip_edges().is_empty() or seen_pool_ids.has(pool_id): return "Rest slot recovery pool IDs must be nonempty and unique"
						seen_pool_ids[pool_id] = true
			if effect.has("lowest_eligible_slot") and effect.has("lower_than_paid_slot"):
				return "Rest slot recovery cannot combine lowest-eligible and lower-than-paid slot filters"
	return ""


func _curate_feature_effects(data: Dictionary) -> void:
	var by_level: Dictionary = data.get("features_by_level", {})
	for level_key in by_level:
		var raw_features = by_level[level_key]
		if not raw_features is Array:
			continue
		for index in raw_features.size():
			var feature = raw_features[index]
			if not feature is Dictionary:
				continue
			var feature_id := str(feature.get("id", ""))
			if feature_id not in CURATED_FEATURE_EFFECTS or not feature.get("effects", []).is_empty() or not feature.get("passive_effects", []).is_empty():
				continue
			var curated: Dictionary = CURATED_FEATURE_EFFECTS[feature_id]
			feature.merge(curated, true)
			raw_features[index] = feature


func _curate_spell_effects(data: Dictionary) -> void:
	var spell_id := str(data.get("id", ""))
	if spell_id not in CURATED_SPELL_EFFECTS or not data.get("effects", []).is_empty():
		return
	data.merge(CURATED_SPELL_EFFECTS[spell_id], true)


func _curate_monster_data(data: Dictionary) -> void:
	var monster_id := str(data.get("id", ""))
	if monster_id in CURATED_MONSTER_TYPES and not data.has("creature_type"):
		data["creature_type"] = CURATED_MONSTER_TYPES[monster_id]


func _find_override(content_type: String, id: String, existing: String, candidate: String) -> Dictionary:
	for entry in _manifest.get("overrides", []):
		if entry is Dictionary and str(entry.get("type", "")) == content_type and str(entry.get("id", "")) == id:
			var sources: Array = entry.get("replaces", [])
			if str(entry.get("winner", "")) in [existing, candidate] and (existing in sources or candidate in sources):
				return entry
	return {}


func _merge_missing_fields(winner: Dictionary, fallback: Dictionary) -> Dictionary:
	var merged := winner.duplicate(true)
	for key in fallback:
		if key not in merged or key in ["_source", "_source_record"]:
			merged[key] = fallback[key]
	return merged


func _get_registry(content_type: String) -> Dictionary:
	match content_type:
		"class": return classes
		"subclass": return subclasses
		"race": return races
		"feat": return feats
		"item": return items
		"spell": return spells
		"monster": return monsters
		"event": return events
		"campaign": return campaigns
	return {}


func _set_registry(content_type: String, id: String, data: Dictionary) -> void:
	_get_registry(content_type)[id] = data


func _source_for(content_type: String, id: String) -> String:
	return str(_registered_sources.get(content_type, {}).get(id, ""))


func _set_source(content_type: String, id: String, source: String) -> void:
	if not _registered_sources.has(content_type):
		_registered_sources[content_type] = {}
	_registered_sources[content_type][id] = source


func _populate_class_spell_access() -> void:
	for class_id in CURATED_SPELL_ACCESS:
		if not classes.has(class_id):
			continue
		var class_data: Dictionary = classes[class_id]
		var access: Dictionary = CURATED_SPELL_ACCESS[class_id]
		var known: Dictionary = {}
		for level_key in access:
			var ids: Array = access[level_key]
			if level_key == "0":
				class_data["cantrips_known"] = ids.duplicate()
			else:
				known[level_key] = ids.duplicate()
		class_data["spells_known_by_level"] = known
		if class_id == "warlock" and class_data.get("pact_magic_by_level", {}).is_empty():
			class_data["pact_magic_by_level"] = CURATED_PACT_MAGIC.duplicate(true)


func _validate_cross_references() -> void:
	for class_data in classes.values():
		var progression_error := PermanentProgressionRules.definition_error(class_data)
		if not progression_error.is_empty(): _load_errors.append(progression_error)
	for id in subclasses:
		var parent := str(subclasses[id].get("class_id", ""))
		if not classes.has(parent):
			_load_errors.append("Subclass '%s' references missing class '%s'" % [id, parent])
		else:
			for key in subclasses[id].get("features_by_level", {}):
				if int(key) < int(classes[parent].get("subclass_level", 3)):
					_load_errors.append("Subclass '%s' grants features before class '%s' allows selection" % [id, parent])
	for class_id in classes:
		var class_data: Dictionary = classes[class_id]
		var legacy_id := str(class_data.get("legacy_subclass", ""))
		if not legacy_id.is_empty() and subclasses.get(legacy_id, {}).get("class_id", "") != class_id:
			_load_errors.append("Class '%s' references missing or mismatched legacy subclass '%s'" % [class_id, legacy_id])
		_validate_feature_resources(class_data)
		for feature_level in class_data.get("features_by_level", {}):
			for feature in class_data["features_by_level"][feature_level]:
				for effect in feature.get("effects", []) + feature.get("passive_effects", []):
					if effect.get("type", "") == "spellcasting":
						for field in ["default_cantrips", "default_prepared_spells"]:
							for spell_id in effect.get(field, []):
								if not spells.has(str(spell_id)):
									_load_errors.append("Feature '%s' references missing default spell '%s'" % [feature.get("id", ""), spell_id])
					if effect.get("type", "") in ["spellcasting", "spell_list_expansion"]:
						for list_id in effect.get("spell_lists", []):
							if not classes.has(str(list_id)):
								_load_errors.append("Feature '%s' references unknown class spell list '%s'" % [feature.get("id", ""), list_id])
		for level_key in class_data.get("spells_known_by_level", {}):
			for spell_id in class_data["spells_known_by_level"][level_key]:
				if not spells.has(str(spell_id)):
					_load_errors.append("Class '%s' references missing spell '%s'" % [class_id, spell_id])
		for spell_id in class_data.get("cantrips_known", []):
			if not spells.has(str(spell_id)):
				_load_errors.append("Class '%s' references missing cantrip '%s'" % [class_id, spell_id])
		for spell_id in class_data.get("spell_list_ids", []):
			if not spells.has(str(spell_id)):
				_load_errors.append("Class '%s' references missing spell-list entry '%s'" % [class_id, spell_id])
	for id in subclasses:
		_validate_feature_resources(subclasses[id], classes.get(str(subclasses[id].get("class_id", "")), {}))

	for campaign_id in campaigns:
		var campaign: Dictionary = campaigns[campaign_id]
		for goal in campaign.get("win_condition", {}).get("goals", []):
			var goal_type := str(goal.get("type", ""))
			var goal_id := str(goal.get("item_id", goal.get("monster_id", "")))
			if goal_type == "collect_item" and not items.has(goal_id):
				_load_errors.append("Campaign '%s' references missing goal item '%s'" % [campaign_id, goal_id])
			if goal_type == "defeat_monster" and not monsters.has(goal_id):
				_load_errors.append("Campaign '%s' references missing goal monster '%s'" % [campaign_id, goal_id])
		for dungeon_id in campaign.get("dungeons", {}):
			var dungeon: Dictionary = campaign["dungeons"][dungeon_id]
			var boss_id := str(dungeon.get("boss", {}).get("monster_id", ""))
			if not monsters.has(boss_id):
				_load_errors.append("Campaign '%s' dungeon '%s' references missing boss '%s'" % [campaign_id, dungeon_id, boss_id])
			for monster_id in dungeon.get("monster_pool", []):
				if not monsters.has(str(monster_id)):
					_load_errors.append("Campaign '%s' dungeon '%s' references missing monster '%s'" % [campaign_id, dungeon_id, monster_id])
			for loot in dungeon.get("loot", []):
				var item_id := str(loot.get("item_id", ""))
				if not items.has(item_id):
					_load_errors.append("Campaign '%s' dungeon '%s' references missing loot '%s'" % [campaign_id, dungeon_id, item_id])
			var event_table := str(dungeon.get("event_table", ""))
			if not events.has(event_table):
				_load_errors.append("Campaign '%s' dungeon '%s' references missing event table '%s'" % [campaign_id, dungeon_id, event_table])

	for monster_id in monsters:
		var monster: Dictionary = monsters[monster_id]
		for loot in monster.get("loot_table", []):
			var loot_item_id := str(loot.get("item_id", ""))
			if not loot_item_id.is_empty() and not items.has(loot_item_id):
				_load_errors.append("Monster '%s' references missing loot item '%s'" % [monster_id, loot_item_id])

	for table_id in events:
		_validate_event_references(events[table_id], str(table_id))
	_validate_check_context_cross_references()


func _validate_check_context_cross_references() -> void:
	for table_id in events:
		var table: Dictionary = events[table_id]
		for event_value in table.get("events", []):
			if not event_value is Dictionary:
				continue
			var event_record: Dictionary = event_value
			for check in _checks_in_event(event_record):
				if not check.has("check_context"):
					continue
				var context_value: Variant = check.get("check_context", {})
				if not context_value is Dictionary:
					continue
				var tool_id := str(context_value.get("required_tool_id", ""))
				if tool_id.is_empty():
					continue
				var tool: Dictionary = items.get(tool_id, {})
				if tool.is_empty() or str(tool.get("type", "")) != "tool":
					_load_errors.append("Event '%s' check '%s' references missing/non-tool context source '%s'" % [event_record.get("id", ""), check.get("id", ""), tool_id])
	for tool_id in items:
		var tool: Dictionary = items[tool_id]
		for effect_value in tool.get("effects", []):
			if not effect_value is Dictionary or str(effect_value.get("type", "")) != "skill_check_context_bonus":
				continue
			var effect: Dictionary = effect_value
			var linked: Dictionary = get_event_check_record(str(effect.get("source_event_id", "")), str(effect.get("source_check_id", "")))
			var linked_check: Dictionary = linked.get("check", {})
			var linked_context: Dictionary = linked_check.get("check_context", {})
			if str(tool_id) != str(effect.get("required_tool_id", "")) or linked.is_empty() or linked_context.is_empty() or str(linked_check.get("ability", "")) != str(effect.get("ability", "")) or str(linked_check.get("skill", "")) != str(effect.get("skill", "")) or str(linked_context.get("task_id", "")) != str(effect.get("task_id", "")) or str(linked_context.get("purpose_id", "")) != str(effect.get("purpose_id", "")) or str(linked_context.get("required_tool_id", "")) != str(effect.get("required_tool_id", "")):
				_load_errors.append("Tool '%s' context bonus '%s' does not match a loaded event/check context" % [tool_id, effect.get("id", "")])
	for class_id in classes:
		var class_data: Dictionary = classes[class_id]
		for level in class_data.get("features_by_level", {}):
			for feature in class_data["features_by_level"][level]:
				if not feature is Dictionary:
					continue
				for effect_value in feature.get("passive_effects", []):
					if not effect_value is Dictionary or str(effect_value.get("type", "")) not in ["ability_check_numeric_bonus", "ability_check_mandatory_reroll", "ability_check_roll_mode", "ability_check_roll_mode_policy", "check_floor"]:
						continue
					var effect: Dictionary = effect_value
					var effect_type := str(effect.get("type", ""))
					if effect_type == "ability_check_mandatory_reroll" and str(effect.get("domain", "")) != "event_skill_check":
						continue
					if effect_type != "check_floor":
						# Only concrete references require a loaded target. Task/purpose or
						# check-only selectors may apply across several event tables.
						if not effect.has("source_event_id"): continue
						var event_id := str(effect["source_event_id"])
						if get_event_record(event_id).is_empty():
							_load_errors.append("Class '%s' check filter references missing event '%s'" % [class_id, event_id])
							continue
						if not effect.has("source_check_id"): continue
						var record := get_event_check_record(event_id, str(effect["source_check_id"]))
						var check: Dictionary = record.get("check", {})
						var context: Dictionary = check.get("check_context", {}).duplicate(true)
						context.merge({"origin_event_id": event_id, "origin_check_id": str(effect["source_check_id"])})
						var mismatch := record.is_empty() or not EventResolver.ability_check_context_matches(effect, context) or str(check.get("skill", "")) != str(effect.get("skill", ""))
						if effect_type in ["ability_check_roll_mode", "ability_check_roll_mode_policy"]:
							mismatch = mismatch or str(check.get("ability", "")).to_upper() != str(effect.get("ability", "")).to_upper()
						else:
							mismatch = mismatch or str(context.get("required_tool_id", "")) != str(effect.get("required_tool_id", ""))
						if mismatch:
							_load_errors.append("Class '%s' ability-check operation '%s' does not match its loaded event/check" % [class_id, effect.get("id", "")])
						continue
					var linked := get_event_check_record(str(effect.get("source_event_id", "")), str(effect.get("source_check_id", "")))
					var linked_check: Dictionary = linked.get("check", {})
					var linked_context: Dictionary = linked_check.get("check_context", {})
					var context_mismatch := linked.is_empty() or linked_context.is_empty() or str(linked_check.get("skill", "")) != str(effect.get("skill", "")) or str(linked_context.get("task_id", "")) != str(effect.get("task_id", "")) or str(linked_context.get("purpose_id", "")) != str(effect.get("purpose_id", ""))
					if effect_type in ["ability_check_roll_mode", "ability_check_roll_mode_policy", "check_floor"]:
						context_mismatch = context_mismatch or str(linked_check.get("ability", "")).to_upper() != str(effect.get("ability", "")).to_upper()
					else:
						context_mismatch = context_mismatch or str(linked_context.get("required_tool_id", "")) != str(effect.get("required_tool_id", ""))
					if context_mismatch:
						_load_errors.append("Class '%s' ability-check operation '%s' does not match a unique loaded event/check context" % [class_id, effect.get("id", "")])


func _checks_in_event(event_record: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var check_value: Variant = event_record.get("check", {})
	if check_value is Dictionary and not check_value.is_empty():
		result.append(check_value)
	var choices_value: Variant = event_record.get("choices", [])
	if choices_value is Array:
		for choice_value in choices_value:
			if not choice_value is Dictionary:
				continue
			var choice_check: Variant = choice_value.get("check", {})
			if choice_check is Dictionary and not choice_check.is_empty():
				result.append(choice_check)
	return result


func _validate_event_references(value, source: String) -> void:
	if value is Dictionary:
		if str(value.get("type", "")) == "give_item":
			var item_id := str(value.get("item_id", ""))
			if not item_id.is_empty() and not items.has(item_id):
				_load_errors.append("Event '%s' references missing item '%s'" % [source, item_id])
		if str(value.get("type", "")) == "start_combat":
			for monster_id in value.get("monsters", []):
				if not monsters.has(str(monster_id)):
					_load_errors.append("Event '%s' references missing combat monster '%s'" % [source, monster_id])
		for key in value:
			_validate_event_references(value[key], source)
	elif value is Array:
		for child in value:
			_validate_event_references(child, source)


func _weapon_damage_rider_error(effect: Dictionary) -> String:
	var dice_table: Variant = effect.get("dice_by_level", {})
	var valid_damage_types := ["radiant", "necrotic", "fire", "cold", "lightning", "thunder", "acid", "poison", "psychic", "force"]
	var damage_type_options: Variant = effect.get("damage_type_options", [])
	var damage_type_valid: bool = str(effect.get("damage_type", "")) in valid_damage_types or (damage_type_options is Array and not damage_type_options.is_empty() and damage_type_options.all(func(value): return str(value) in valid_damage_types))
	var once_per_turn: Variant = effect.get("once_per_turn", effect.get("uses_per", "") == "turn")
	if effect.get("trigger", "") != "weapon_attack_hit" or not damage_type_valid or not dice_table is Dictionary or dice_table.is_empty() or not once_per_turn is bool:
		return "Weapon damage riders require a weapon-hit trigger, damage type, and dice table"
	if effect.has("use_limit") and (effect.has("once_per_turn") or effect.has("uses_per")):
		return "Weapon damage rider cannot combine a bounded use_limit with a legacy turn cadence"
	if effect.has("uses_per") and effect["uses_per"] != "turn":
		return "Weapon damage riders only support a turn limit"
	if effect.has("melee_only") and not effect["melee_only"] is bool:
		return "Weapon damage rider melee_only must be boolean"
	for flag in ["own_turn_only", "first_round_only"]:
		if effect.has(flag) and (not effect[flag] is bool or (flag == "first_round_only" and not effect.has("use_limit"))):
			return "Scoped rider eligibility requires a boolean and bounded use_limit"
	if effect.has("payment_waiver"):
		var waiver: Variant = effect["payment_waiver"]
		if not effect.has("use_limit") or not waiver is Dictionary or waiver.size() != 2 or waiver.get("parent", "") not in ["weapon_attack", "opportunity_attack"] or not waiver.get("requires_active_source", null) is bool or waiver.get("requires_active_source", null) != true:
			return "Rider waiver requires a supported parent and requires_active_source:true"
		for field in waiver:
			if field not in ["parent", "requires_active_source"]:
				return "Rider waiver contains an unsupported field"
	if effect.has("payment_replacement"):
		var replacement: Variant = effect["payment_replacement"]
		if effect.has("payment_waiver") or not effect.has("use_limit") or not replacement is Dictionary or replacement.size() != 2:
			return "Rider payment replacement requires a bounded use and cannot combine with a waiver"
		var pool_id := str(replacement.get("pool_id", ""))
		var pool_id_pattern := RegEx.new()
		pool_id_pattern.compile("^[a-z0-9_.:-]{1,100}$")
		if pool_id_pattern.search(pool_id) == null or not ResourcePoolRules._integer(replacement.get("quantity", null), 1, 100):
			return "Rider payment replacement requires a pool_id and quantity from 1 through 100"
		for field in replacement:
			if field not in ["pool_id", "quantity"]:
				return "Rider payment replacement contains an unsupported field"
	for key in dice_table:
		if not str(key).is_valid_int() or str(int(key)) != str(key) or int(key) < 1 or int(key) > 20 or str(dice_table[key]).is_empty():
			return "Weapon damage rider levels and dice are invalid"
		var dice_pattern := RegEx.new()
		dice_pattern.compile("^[1-9][0-9]?d(4|6|8|10|12|20)(\\+[0-9]{1,3})?$")
		if dice_pattern.search(str(dice_table[key])) == null:
			return "Weapon damage rider dice must use a supported bounded damage expression"
	if effect.has("use_limit") and (str(effect["use_limit"]) not in ["once_per_combat_turn", "once_per_target_per_combat_turn", "once_per_owner_turn_interval", "once_per_round", "once_per_roll", "once_per_active_instance"] or not str(effect.get("id", "")).is_valid_identifier()):
		return "Weapon damage rider use_limit requires a supported bounded limit and option ID"
	return ""


func get_all_classes() -> Array:
	return _sorted_values(classes).filter(func(record: Dictionary): return str(record.get("id", "")) not in ["artificer", "mystic"])

func get_character_class(id: String) -> Dictionary:
	return classes.get(id, {})

func get_subclass(id: String) -> Dictionary:
	return subclasses.get(id, {})

func get_subclasses_for_class(id: String) -> Array:
	return _sorted_values(subclasses).filter(func(record: Dictionary): return record.get("class_id", "") == id)

func _validate_feature_resources(data: Dictionary, base: Dictionary = {}) -> void:
	var owned := {}
	var token_pools := {}
	var ward_pools := {}
	for source in [base, data]:
		for level_key in source.get("features_by_level", {}):
			for feature in source["features_by_level"][level_key]:
				var id := str(feature.get("id", ""))
				# Two legacy imported progressions repeat their own upgrade marker.
				var legacy_upgrade: bool = (id == "paladin_divine_sense" and data.get("id", "") == "paladin") or (id == "sorcerer_metamagic" and data.get("id", "") == "sorcerer")
				if id.is_empty() or (owned.has(id) and not legacy_upgrade):
					_load_errors.append("Duplicate or missing feature ID '%s' in %s" % [id, data.get("id", "")])
				owned[id] = {"record": feature, "level": int(level_key)}
				for effect in feature.get("effects", []) + feature.get("passive_effects", []):
					if effect is Dictionary and str(effect.get("type", "")) == "roll_token_pool":
						var token_pool_id := str(effect.get("pool_id", id)).strip_edges()
						if not token_pool_id.is_empty():
							token_pools[token_pool_id] = mini(int(token_pools.get(token_pool_id, 99)), int(level_key))
					if effect is Dictionary and str(effect.get("type", "")) == "damage_ward_pool":
						var ward_pool_id := str(effect.get("pool_id", id)).strip_edges()
						if not ward_pool_id.is_empty():
							ward_pools[ward_pool_id] = mini(int(ward_pools.get(ward_pool_id, 99)), int(level_key))
	for id in owned:
		var feature: Dictionary = owned[id]["record"]
		if feature.get("type") == "zero_hp_replacement" or feature.get("trigger") == "zero_hp":
			var zero_error := SharedStepExecutor.validate_zero_hp_replacement_rule(feature)
			if not zero_error.is_empty(): _load_errors.append("Feature '%s': %s" % [id, zero_error])
		if feature.has("resource_id"):
			var pool := str(feature["resource_id"])
			if not owned.has(pool) or owned[pool]["record"].get("type", "") != "resource" or int(owned[pool]["level"]) > int(owned[id]["level"]):
				_load_errors.append("Feature '%s' requires an earlier or same-level resource pool '%s' in %s" % [id, pool, data.get("id", "")])
		for effect in feature.get("effects", []) + feature.get("passive_effects", []):
			if effect is Dictionary and str(effect.get("type", "")) == "roll_token_pool_upgrade":
				var upgrade_pool_id := str(effect.get("pool_id", "")).strip_edges()
				if not token_pools.has(upgrade_pool_id) or int(token_pools[upgrade_pool_id]) > int(owned[id]["level"]):
					_load_errors.append("Feature '%s' requires an earlier or same-level roll_token_pool '%s' in %s" % [id, upgrade_pool_id, data.get("id", "")])
			if effect is Dictionary and str(effect.get("type", "")) == "damage_ward_projection":
				var proj_pool_id := str(effect.get("pool_id", "")).strip_edges()
				if not ward_pools.has(proj_pool_id) or int(ward_pools[proj_pool_id]) > int(owned[id]["level"]):
					_load_errors.append("Feature '%s' requires an earlier or same-level damage_ward_pool '%s' in %s" % [id, proj_pool_id, data.get("id", "")])

func get_all_races() -> Array:
	return _sorted_values(races)

func get_race(id: String) -> Dictionary:
	return races.get(id, {})

func get_feat(id: String) -> Dictionary:
	return feats.get(id, {})

func get_all_items() -> Array:
	return _sorted_values(items)

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func get_all_spells() -> Array:
	return _sorted_values(spells)

func get_spell_list_options(list_ids: Array) -> Array:
	var options: Array = []
	var seen: Dictionary = {}
	for list_id in list_ids:
		var class_data: Dictionary = classes.get(str(list_id), {})
		for spell_id in class_data.get("spell_list_ids", []):
			var id := str(spell_id)
			if seen.has(id) or not spells.has(id):
				continue
			seen[id] = true
			options.append(spells[id])
	options.sort_custom(func(a, b):
		if int(a.get("level", 0)) == int(b.get("level", 0)):
			return str(a.get("name", "")) < str(b.get("name", ""))
		return int(a.get("level", 0)) < int(b.get("level", 0)))
	return options

func get_spell(id: String) -> Dictionary:
	return spells.get(id, {})

func get_castable_spell_list_options(list_ids: Array) -> Array:
	return get_spell_list_options(list_ids).filter(func(spell): return SpellSupport.is_available(spell))

func get_all_monsters() -> Array:
	return _sorted_values(monsters)

func get_monster(id: String) -> Dictionary:
	return monsters.get(id, {})

func get_event_table(table_id: String) -> Dictionary:
	return events.get(table_id, {})


func get_event_record(event_id: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for table_id in events:
		var table: Dictionary = events[table_id]
		for event_value in table.get("events", []):
			if not event_value is Dictionary:
				continue
			var found := _find_event_record(event_value, event_id, str(table_id))
			if not found.is_empty():
				matches.append(found)
	if matches.size() != 1:
		return {}
	return matches[0]


func _find_event_record(value: Dictionary, event_id: String, table_id: String) -> Dictionary:
	if str(value.get("id", "")) == event_id:
		return {"event": value.duplicate(true), "table_id": table_id}
	var nested: Variant = value.get("chain_event", {})
	if nested is Dictionary and not nested.is_empty():
		return _find_event_record(nested, event_id, table_id)
	return {}


func get_event_check_record(event_id: String, check_id: String) -> Dictionary:
	var event_result := get_event_record(event_id)
	if event_result.is_empty():
		return {}
	var event_record: Dictionary = event_result.get("event", {})
	var matching_check: Dictionary = {}
	var check_owner: Dictionary = {}
	var top_check: Variant = event_record.get("check", {})
	if top_check is Dictionary and str(top_check.get("id", "")) == check_id:
		matching_check = top_check
		check_owner = event_record
	for choice_value in event_record.get("choices", []):
		if not choice_value is Dictionary:
			continue
		var choice_check: Variant = choice_value.get("check", {})
		if choice_check is Dictionary and str(choice_check.get("id", "")) == check_id:
			if not matching_check.is_empty():
				return {}
			matching_check = choice_check
			check_owner = choice_value
	if matching_check.is_empty():
		return {}
	return {"event": event_record, "check": matching_check.duplicate(true), "check_owner": check_owner.duplicate(true), "table_id": event_result.get("table_id", "")}

func get_all_campaigns() -> Array:
	return _sorted_values(campaigns)

func get_campaign(id: String) -> Dictionary:
	return campaigns.get(id, {})

func get_load_errors() -> Array[String]:
	return _load_errors

func get_validation_warnings() -> Array[String]:
	return _validation_warnings


func get_content_layers() -> Array[String]:
	var layers: Array[String] = []
	for layer in _manifest.get("layers", []):
		if layer is Dictionary:
			layers.append(str(layer.get("id", "")))
	return layers


func get_content_pack_ids() -> Array[String]:
	var pack_ids: Array[String] = []
	for pack in _manifest.get("packs", []):
		if pack is Dictionary:
			pack_ids.append(str(pack.get("id", "")))
	return pack_ids

func get_registry_hash() -> String:
	var snapshot: Array = []
	for content_type in ["class", "subclass", "race", "item", "spell", "monster", "event", "campaign"]:
		var registry := _get_registry(content_type)
		var ids: Array = registry.keys()
		ids.sort()
		for id in ids:
			snapshot.append({"type": content_type, "id": id, "data": registry[id]})
	return JSON.stringify(snapshot)

func _sorted_values(registry: Dictionary) -> Array:
	var ids: Array = registry.keys()
	ids.sort()
	var result: Array = []
	for id in ids:
		result.append(registry[id])
	return result

func reload() -> void:
	load_all_data()
