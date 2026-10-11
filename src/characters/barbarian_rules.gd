## Narrow resolver for Barbarian rules that occur at combat boundaries.
class_name BarbarianRules
extends RefCounted

const RAGE_TURNS := 2
const PERSISTENT_RAGE_TURNS := 100
const BRUTAL_STRIKE_BASE_OPTIONS: Array[String] = ["forceful", "hamstring"]
const BRUTAL_STRIKE_IMPROVED_OPTIONS: Array[String] = ["staggering", "sundering"]


static func rage_duration(character: Character) -> int:
	return PERSISTENT_RAGE_TURNS if character.has_feature("barbarian_persistent_rage") else RAGE_TURNS


static func maintain_rage(character: Character) -> void:
	if character != null and character.has_condition("raging"):
		# Older saves have no clock; seed it once, never on subsequent attacks.
		if not character.feature_uses.has("barbarian_rage_seconds_remaining"):
			start_rage(character)
		var remaining := int(character.feature_uses["barbarian_rage_seconds_remaining"])
		character.feature_uses["barbarian_rage_upkeep_seconds_remaining"] = mini(remaining, rage_duration(character) * 6)
		_sync_rage_duration(character)


static func start_rage(character: Character) -> void:
	character.feature_uses["barbarian_rage_seconds_remaining"] = PERSISTENT_RAGE_TURNS * 6
	character.feature_uses["barbarian_rage_upkeep_seconds_remaining"] = rage_duration(character) * 6
	_sync_rage_duration(character)


## The same saved clock advances by six seconds per turn and by campaign time.
static func advance_rage_time(character: Character, elapsed_seconds: int) -> void:
	if character == null or not character.has_condition("raging") or elapsed_seconds <= 0:
		return
	if not character.feature_uses.has("barbarian_rage_seconds_remaining"):
		var legacy_duration := int(character.conditions["raging"]) * 6
		character.feature_uses["barbarian_rage_seconds_remaining"] = PERSISTENT_RAGE_TURNS * 6
		character.feature_uses["barbarian_rage_upkeep_seconds_remaining"] = legacy_duration
	for key in ["barbarian_rage_seconds_remaining", "barbarian_rage_upkeep_seconds_remaining"]:
		character.feature_uses[key] = maxi(0, int(character.feature_uses[key]) - elapsed_seconds)
	if int(character.feature_uses["barbarian_rage_seconds_remaining"]) == 0 or int(character.feature_uses["barbarian_rage_upkeep_seconds_remaining"]) == 0:
		character.end_rage()
	else:
		_sync_rage_duration(character)


static func _sync_rage_duration(character: Character) -> void:
	var seconds := mini(int(character.feature_uses["barbarian_rage_seconds_remaining"]), int(character.feature_uses["barbarian_rage_upkeep_seconds_remaining"]))
	var duration := int(ceil(float(seconds) / 6.0))
	character.conditions["raging"] = duration
	character.refresh_modifier("stat", "damage:rage", duration)


static func instinctive_pounce_distance(character: Character) -> int:
	if character == null or not character.has_feature("barbarian_instinctive_pounce") or character._is_wearing_heavy_armor():
		return 0
	return int(floor(float(character.get_speed()) / 2.0))


static func can_recover_rage_at_initiative(character: Character) -> bool:
	if character == null or not character.has_feature("barbarian_persistent_rage") or bool(character.feature_uses.get("barbarian_persistent_rage_recovered", false)):
		return false
	return int(character.feature_uses.get("barbarian_rage", 0)) < character.get_feature_max_uses("barbarian_rage")


static func recover_rage_at_initiative(character: Character) -> int:
	if not can_recover_rage_at_initiative(character):
		return 0
	character.feature_uses["barbarian_persistent_rage_recovered"] = true
	var maximum := character.get_feature_max_uses("barbarian_rage")
	var current := int(character.feature_uses.get("barbarian_rage", 0))
	character.feature_uses["barbarian_rage"] = maximum
	return maximum - current


static func attempt_relentless_rage(character: Character, accepted_bardic_inspiration: bool = false, decisions: Dictionary = {}) -> Dictionary:
	if character == null or not character.barbarian_relentless_rage_enabled or not character.has_feature("barbarian_relentless_rage") or not character.has_condition("raging"):
		return {"success": false, "used": false}
	var attempts := int(character.feature_uses.get("barbarian_relentless_rage_attempts", 0))
	var dc := 10 + attempts * 5
	character.feature_uses["barbarian_relentless_rage_attempts"] = attempts + 1
	var total := character.make_saving_throw("CON", false, false, decisions)
	var inspiration_note := ""
	if total < dc and accepted_bardic_inspiration:
		var inspiration := BardicInspirationRules.apply_to_test(character, total, dc, true)
		if inspiration.get("used", false):
			total = int(inspiration["total"])
			inspiration_note = " Bardic Inspiration adds %d." % int(inspiration["bonus"])
	character.last_save_note = "Relentless Rage: Constitution save %d vs DC %d.%s" % [total, dc, inspiration_note]
	if total < dc:
		return {"success": false, "used": true, "total": total, "dc": dc, "bardic_inspiration_used": not inspiration_note.is_empty()}
	character.current_hp = character.level * 2
	character.is_alive = true
	return {"success": true, "used": true, "total": total, "dc": dc, "hit_points": character.current_hp, "bardic_inspiration_used": not inspiration_note.is_empty()}


static func brutal_strike_eligible(character: Character, weapon: Dictionary, disadvantage: bool = false) -> bool:
	if character == null or CombatAction.active_turn_actor_id != character.get_instance_id() or disadvantage:
		return false
	for condition in ["blinded", "poisoned", "vicious_mockery_disadvantage", "ray_of_enfeeblement"]:
		if character.has_condition(condition):
			return false
	return character.has_feature("barbarian_brutal_strike") and character.has_condition("reckless_attack") and str(weapon.get("ability", "STR")) == "STR" and int(character.feature_uses.get("barbarian_brutal_strike_used_this_turn", 0)) == 0


static func brutal_strike_options(character: Character) -> Array[String]:
	var options: Array[String] = BRUTAL_STRIKE_BASE_OPTIONS.duplicate()
	if character != null and character.has_feature("barbarian_improved_brutal_strike_13"):
		options.append_array(BRUTAL_STRIKE_IMPROVED_OPTIONS)
	return options


static func commit_brutal_strike(character: Character, weapon: Dictionary, disadvantage: bool, effects: Array[String]) -> bool:
	if not brutal_strike_eligible(character, weapon, disadvantage) or effects.is_empty() or effects.size() > (2 if character.has_feature("barbarian_improved_brutal_strike_17") else 1):
		return false
	var available := brutal_strike_options(character)
	for effect in effects:
		if effect not in available or effects.count(effect) > 1:
			return false
	character.feature_uses["barbarian_brutal_strike_used_this_turn"] = 1
	return true


static func brutal_strike_dice(character: Character) -> String:
	return "2d10" if character != null and character.has_feature("barbarian_improved_brutal_strike_17") else "1d10"


static func apply_brutal_strike_effects(character: Character, target: Dictionary, effects: Array[String]) -> Dictionary:
	var result := {"push_distance": 0, "move_after_push": false, "effects": effects.duplicate()}
	for effect in effects:
		match effect:
			"forceful":
				result["push_distance"] = 3
				result["move_after_push"] = true
			"hamstring":
				target["barbarian_hamstring_owner"] = character.get_instance_id()
				var original_speed := int(target.get("barbarian_hamstring_original_speed", target.get("speed", 6)))
				target["barbarian_hamstring_original_speed"] = original_speed
				target["speed"] = maxi(0, original_speed - 3)
			"staggering":
				target["barbarian_staggered_saves"] = true
				target["barbarian_no_opportunity_owner"] = character.get_instance_id()
			"sundering":
				if not target.has("barbarian_sundering_owner"):
					target["barbarian_sundering_owner"] = character.get_instance_id()
		result["message"] = "Brutal Strike: " + ", ".join(effects)
	return result


static func roll_monster_save(target: Dictionary, ability: String, source: Character = null, advantage: bool = false, disadvantage: bool = false, decisions: Dictionary = {}) -> int:
	return int(roll_monster_save_result(target, ability, source, advantage, disadvantage, decisions).get("total", 0))


static func roll_monster_save_result(target: Dictionary, ability: String, source: Character = null, advantage: bool = false, disadvantage: bool = false, decisions: Dictionary = {}) -> Dictionary:
	# Only an initial forced enemy save counts as upkeep. Repeat saves omit source.
	if source != null and not bool(target.get("is_player", false)):
		maintain_rage(source)
	var scores: Dictionary = target.get("ability_scores", {})
	var bonus := int(target.get("saving_throw_bonuses", {}).get(ability, AbilityScores.get_modifier(int(scores.get(ability, 10)))))
	var beacon_advantage := advantage or (SpellEffects.has_spell(target, "beacon_of_hope") and ability.to_upper() == "WIS")
	var staggered_disadvantage := disadvantage or consume_staggered_save(target)
	var d20_details := RollTokenRules.resolve_d20_test(target, "monster_save", beacon_advantage, staggered_disadvantage, decisions)
	var roll := int(d20_details.get("total", 1))
	var natural_roll := roll
	if target.get("conditions", {}).has("blessed"):
		roll += Dice.roll(4)
	if target.get("conditions", {}).has("baned"):
		roll -= Dice.roll(4)
	var total := roll + bonus
	var out := {
		"natural_roll": natural_roll,
		"rolls": d20_details.get("rolls", [natural_roll]),
		"kept": d20_details.get("kept", [true]),
		"modifier": bonus,
		"total": total,
		"ability": ability.to_upper(),
		"roll_token_replaced": bool(d20_details.get("replaced", false)),
	}
	if bool(d20_details.get("replaced", false)):
		out["roll_token_id"] = str(d20_details.get("roll_token_id", ""))
		out["roll_token_value"] = int(d20_details.get("roll_token_value", natural_roll))
		out["roll_token_pool_id"] = str(d20_details.get("roll_token_pool_id", ""))
		out["roll_token_owner_id"] = str(d20_details.get("roll_token_owner_id", ""))
	if d20_details.has("roll_token_error"):
		out["roll_token_error"] = str(d20_details["roll_token_error"])
	return out


static func consume_sundering_bonus(attacker: Character, target: Dictionary) -> bool:
	var owner_id := int(target.get("barbarian_sundering_owner", -1))
	if not target.has("barbarian_sundering_owner") or owner_id == attacker.get_instance_id():
		return false
	target.erase("barbarian_sundering_owner")
	return true


static func consume_staggered_save(target: Dictionary) -> bool:
	if not bool(target.get("barbarian_staggered_saves", false)):
		return false
	target.erase("barbarian_staggered_saves")
	return true


static func clear_turn_effects(character: Character, targets: Array[Dictionary]) -> void:
	if character == null:
		return
	var owner_id := character.get_instance_id()
	for target in targets:
		if int(target.get("barbarian_hamstring_owner", -1)) == owner_id:
			target["speed"] = int(target.get("barbarian_hamstring_original_speed", target.get("speed", 6)))
			target.erase("barbarian_hamstring_owner")
			target.erase("barbarian_hamstring_original_speed")
		if int(target.get("barbarian_no_opportunity_owner", -1)) == owner_id:
			target.erase("barbarian_no_opportunity_owner")
		if int(target.get("barbarian_sundering_owner", -1)) == owner_id:
			target.erase("barbarian_sundering_owner")
