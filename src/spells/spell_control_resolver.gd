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


static func sleep(cast: SpellResolutionContext) -> Dictionary:
	var target_name: String = cast.target.character_name if cast.target is Character else str(cast.target.get("name", "Target"))
	if CombatAction.is_immune_to_magical_sleep(cast.target):
		return {"success": true, "hit": true, "saved": true, "automatic_save": true, "damage": 0, "effect_cast": cast.effect_cast, "message": "%s is unaffected by magical sleep and automatically succeeds." % target_name}
	var save_dc := int(cast.effect_cast.get("save_dc", cast.caster.get_spell_save_dc()))
	var save_total: int = int(cast.target.saving_throw_test_to_dc("WIS", save_dc).get("total", 0)) if cast.target is Character else BarbarianRules.roll_monster_save(cast.target, "WIS")
	var saved := save_total >= save_dc
	if not saved:
		SpellEffects.grant(cast.target, cast.effect_cast, "incapacitated", "start")
	return {"success": true, "hit": true, "saved": saved, "automatic_save": false, "save_total": save_total, "save_dc": save_dc, "damage": 0, "condition": "" if saved else "incapacitated", "effect_cast": cast.effect_cast, "message": "%s %s the Wisdom save against Sleep (%d vs DC %d)." % [target_name, "succeeds on" if saved else "fails", save_total, save_dc] if saved else "%s is Incapacitated by Sleep and repeats the Wisdom save at the end of its next turn." % target_name}


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


