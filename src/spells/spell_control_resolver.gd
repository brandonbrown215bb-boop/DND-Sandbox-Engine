## Direct control spell results, including Sleep and Power Word Stun.
class_name SpellControlResolver
extends RefCounted

static func disintegrate(cast: SpellResolutionContext) -> Dictionary:
	if str(cast.spell.get("id", "")) == "disintegrate" and CombatAction.has_condition(cast.target, "resilient_sphere"):
		return {"success": true, "hit": true, "damage": 0, "sphere_destroyed": true, "slot_level": cast.slot_level, "message": "Disintegrate destroys the Resilient Sphere without harming the creature inside."}

	return {}


static func power_word_stun(cast: SpellResolutionContext) -> Dictionary:
	var current_hp := int(cast.target.current_hp) if cast.target is Character else int(cast.target.get("current_hp", 0))
	var target_name: String = cast.target.character_name if cast.target is Character else str(cast.target.get("name", "Target"))
	var source_cast: Dictionary = cast.effect_cast
	if source_cast.is_empty():
		source_cast = SpellEffects.begin_cast(cast.caster, cast.spell)
	if current_hp <= int(cast.spell.get("hp_threshold", 150)):
		SpellEffects.grant(cast.target, source_cast, "stunned", "end", -1)
		return {"success": true, "hit": true, "damage": 0, "slot_level": cast.slot_level, "condition": "stunned", "effect_cast": source_cast, "message": "%s is Stunned by Power Word Stun and repeats a Constitution save at the end of each of its turns." % target_name}
	SpellEffects.grant(cast.target, source_cast, "power_word_stun_speed_zero", "start", 6)
	return {"success": true, "hit": true, "damage": 0, "slot_level": cast.slot_level, "speed_zero": true, "effect_cast": source_cast, "message": "%s has Speed 0 until the start of %s's next turn." % [target_name, cast.caster.character_name]}


static func animal_messenger(cast: SpellResolutionContext) -> Dictionary:
	if str(cast.spell.get("id", "")) == "animal_messenger" and cast.target is Dictionary and not is_zero_approx(float(cast.target.get("challenge_rating", 0.0))):
		return {
			"success": true,
			"saved": true,
			"automatic_save": true,
			"slot_level": cast.slot_level,
			"message": "%s automatically succeeds on its Charisma save and does not carry the message." % str(cast.target.get("name", "The Beast")),
		}

	return {}


