## Executable gameplay slices; registry membership alone does not enable a cast.
class_name SpellSupport
extends RefCounted

const AVAILABLE_SLICES := [
	"animate_dead",
	"animate_objects",
	"aid", "alarm", "alter_self", "animal_friendship", "animal_messenger", "antilife_shell", "aura_of_life", "beacon_of_hope", "blade_ward", "blindness/deafness", "detect_magic", "blur", "detect_evil_and_good", "detect_poison_and_disease", "identify", "goodberry",
	"bless", "bane", "barkskin", "black_tentacles", "blight", "charm_person", "charm_monster", "chill_touch", "cloud_of_daggers", "cloudkill", "color_spray", "command", "counterspell",
	"circle_of_death", "conjure_animals", "conjure_celestial", "dancing_lights", "disintegrate",
	"death_ward", "divine_favor", "divine_smite", "eldritch_blast", "entangle", "false_life", "faerie_fire", "find_steed", "find_familiar", "fog_cloud", "darkness", "darkvision", "see_invisibility", "true_seeing", "conjure_elemental", "conjure_fey", "conjure_minor_elementals", "conjure_woodland_beings",
	"grease", "guidance", "guiding_bolt", "heal", "hold_monster",
	"heroism", "magic_weapon", "enhance_ability", "ice_knife", "light", "mass_cure_wounds", "mass_healing_word",
	"jump", "longstrider", "mage_armor", "mage_hand", "magic_missile", "meteor_swarm", "chain_lightning", "melfs_acid_arrow", "fly", "levitate", "spider_climb", "freedom_of_movement", "water_walk", "wall_of_fire",
	"message", "minor_illusion", "misty_step", "moonbeam", "plant_growth", "power_word_heal",
	"power_word_kill", "power_word_stun", "prestidigitation", "produce_flame", "protection_from_energy", "invisibility",
	"protection_from_evil_and_good", "protection_from_poison", "purify_food_and_drink", "create_or_destroy_water", "ray_of_enfeeblement",
	"ray_of_frost", "ray_of_sickness", "regenerate", "revivify", "gentle_repose", "remove_curse", "resilient_sphere",
	"resistance", "scorching_ray", "shatter", "shield", "shillelagh", "shocking_grasp", "sorcerous_burst", "spare_the_dying", "starry_wisp",
	"sanctuary", "sleep", "sleet_storm", "spike_growth", "spirit_guardians", "sunburst", "thunderwave", "true_strike", "vicious_mockery",
]

static func availability(spell: Dictionary) -> Dictionary:
	if spell.has("execution"):
		var error := SharedSpell.content_error(spell)
		return {"available": error.is_empty(), "reason": error}
	# Preserve the public resolver's legacy raw-record callers for converted IDs.
	# New authored definitions still need the validated shared contract.
	if SharedSpell.uses(DataLoader.get_spell(str(spell.get("id", "")))):
		return {"available": true, "reason": ""}
	if str(spell.get("id", "")) == "animate_dead" and GameManager.current_state == GameManager.GameState.COMBAT:
		return {"available": false, "reason": "Animate Dead takes one minute; use the local room's remains and renewal controls."}
	if str(spell.get("id", "")) == "alarm" and GameManager.current_state == GameManager.GameState.COMBAT:
		return {"available": false, "reason": "Alarm can only be cast while exploring a local room."}
	if str(spell.get("id", "")) == "levitate" and GameManager.current_state == GameManager.GameState.COMBAT:
		return {"available": false, "reason": "Levitate's bounded altitude controls are only supported in local-room exploration."}
	if str(spell.get("id", "")) in AVAILABLE_SLICES:
		return {"available": true, "reason": ""}
	return {"available": false, "reason": "Casting %s is not supported yet." % str(spell.get("name", "this spell"))}

static func is_available(spell: Dictionary) -> bool:
	return bool(availability(spell)["available"])
