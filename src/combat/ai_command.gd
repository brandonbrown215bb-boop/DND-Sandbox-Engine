## Validated monster intent entering the combat domain.
## AI may choose an action, but combat state is the authority that accepts only
## a legal action, target, weapon index, and one-step movement destination.
class_name AICommand
extends RefCounted

const TYPES := ["attack", "move", "move_attack", "cast_spell", "none"]

var action_type: String
var payload: Dictionary


func _init(kind: String, data: Dictionary = {}) -> void:
	action_type = kind
	payload = data.duplicate(true)


static func from_decision(decision: Dictionary, monster: Dictionary, players: Array, grid: HexGrid) -> AICommand:
	var kind := str(decision.get("action", "none"))
	if kind not in TYPES:
		return null
	var command := AICommand.new(kind, decision)
	if not command.is_valid(monster, players, grid):
		return null
	return command


func is_valid(monster: Dictionary, players: Array, grid: HexGrid) -> bool:
	if action_type == "none":
		return true
	if monster.is_empty() or grid == null:
		return false
	if action_type in ["attack", "move_attack"]:
		var target_id := str(payload.get("target_id", ""))
		if target_id.is_empty() or not _has_living_target(target_id, players):
			return false
		var attack_idx := int(payload.get("attack_idx", -1))
		var attacks: Array = monster.get("attacks", [])
		if attack_idx < 0 or attack_idx >= attacks.size():
			return false
	if action_type == "cast_spell":
		var target_id := str(payload.get("target_id", ""))
		if target_id.is_empty() or not _has_living_target(target_id, players):
			return false
		var spell_id := str(payload.get("spell_id", ""))
		var spell_data: Dictionary = DataLoader.get_spell(spell_id)
		if spell_data.is_empty() or str(spell_data.get("casting_time", "action")) == "reaction":
			return false
		if str(spell_data.get("target", "single")) not in ["single", "multi"]:
			return false
		var known_spell := false
		for known in monster.get("spells", []):
			if str(known.get("id", "")) == spell_id:
				known_spell = true
				break
		if not known_spell:
			return false
		var spell_level := int(spell_data.get("level", 0))
		if spell_level > 0 and int(monster.get("spell_slots", {}).get(str(spell_level), 0)) <= 0:
			return false
		var target_position: Variant = _target_position(target_id, players)
		if target_position == null or not target_position is Vector2i:
			return false
		if HexUtils.get_distance(monster.get("hex_position", Vector2i.ZERO), target_position) > int(spell_data.get("range", 0)):
			return false
	if action_type in ["move", "move_attack"]:
		var move_to: Variant = payload.get("move_to", null)
		if not move_to is Vector2i:
			return false
		var current: Variant = monster.get("hex_position", Vector2i.ZERO)
		if not current is Vector2i or HexUtils.get_distance(current, move_to) != 1:
			return false
		if not grid.has_tile(move_to) or not grid.is_hex_passable(move_to):
			return false
	return true


func target_id() -> String:
	return str(payload.get("target_id", ""))


func attack_idx() -> int:
	return int(payload.get("attack_idx", -1))


func spell_id() -> String:
	return str(payload.get("spell_id", ""))


func move_to() -> Vector2i:
	return payload.get("move_to", Vector2i.ZERO)


static func _has_living_target(target_id_value: String, players: Array) -> bool:
	for player in players:
		var character: Character = player.get("character")
		if character != null and character.is_alive and character.character_name == target_id_value:
			return true
	return false


static func _target_position(target_id_value: String, players: Array) -> Variant:
	for player in players:
		var character: Character = player.get("character")
		if character != null and character.is_alive and character.character_name == target_id_value:
			return player.get("hex_position", Vector2i.ZERO)
	return null
