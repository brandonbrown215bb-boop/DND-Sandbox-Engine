## Finds poison and contagion details represented by tracked combat creatures.
class_name DetectPoisonRules
extends RefCounted

const RANGE_HEXES := 6

static func sensed_hazards(origin: Vector2i, players: Array, monsters: Array) -> Dictionary:
	var sensed: Dictionary = {}
	for entry in players:
		var character: Character = entry.get("character")
		if character == null or not character.is_alive or HexUtils.get_distance(origin, entry.get("hex_position", Vector2i.ZERO)) > RANGE_HEXES:
			continue
		var target_id := character.character_id if not character.character_id.is_empty() else "runtime_%d" % character.get_instance_id()
		_add_condition_hazards(sensed, target_id, character.character_name, character.conditions, entry.get("hex_position", Vector2i.ZERO))
	for monster in monsters:
		if not bool(monster.get("is_alive", false)):
			continue
		var position: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		if HexUtils.get_distance(origin, position) > RANGE_HEXES:
			continue
		var target_id := str(monster.get("id", monster.get("monster_id", "")))
		if target_id.is_empty():
			continue
		var target_name := str(monster.get("name", "Creature"))
		_add_condition_hazards(sensed, target_id, target_name, monster.get("conditions", {}), position)
		for attack in monster.get("attacks", []):
			if not attack is Dictionary:
				continue
			var poisonous := str(attack.get("damage_type", "")).to_lower() == "poison"
			for effect in attack.get("extra_effects", []):
				if effect is Dictionary and str(effect.get("type", "")).to_lower().contains("poison"):
					poisonous = true
			if not poisonous:
				continue
			var attack_name := str(attack.get("name", "poisonous attack"))
			var hazard_id := "poisonous_creature:%s:%s" % [target_id, attack_name]
			sensed[hazard_id] = {"name": target_name, "kind": "poisonous or venomous creature (%s)" % attack_name, "hex": position}
	return sensed


static func _add_condition_hazards(sensed: Dictionary, target_id: String, target_name: String, conditions: Dictionary, position: Vector2i) -> void:
	if conditions.has("poisoned"):
		var poison_id := "poisoned:%s" % target_id
		sensed[poison_id] = {"name": target_name, "kind": "poison (specific poison not represented)", "hex": position}
