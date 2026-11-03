## Validated monster intent entering the combat domain.
## AI may choose an action, but combat state is the authority that accepts only
## a legal action, target, weapon index, and one-step movement destination.
class_name AICommand
extends RefCounted

const TYPES := ["attack", "move", "move_attack", "cast_spell", "cast_area_spell", "none"]

var action_type: String
var payload: Dictionary


func _init(kind: String, data: Dictionary = {}) -> void:
	action_type = kind
	payload = data.duplicate(true)


static func from_decision(decision: Dictionary, monster: Dictionary, players: Array, grid: HexGrid, fear_candidates: Array = []) -> AICommand:
	var kind := str(decision.get("action", "none"))
	if kind not in TYPES:
		return null
	var command := AICommand.new(kind, decision)
	if not command.is_valid(monster, players, grid, fear_candidates):
		return null
	return command


func is_valid(monster: Dictionary, players: Array, grid: HexGrid, fear_candidates: Array = []) -> bool:
	var all_candidates := fear_candidates if not fear_candidates.is_empty() else players
	if action_type == "none":
		return true
	if monster.is_empty() or grid == null or not bool(monster.get("is_alive", true)) or int(monster.get("current_hp", 1)) <= 0:
		return false
	if action_type in ["attack", "move_attack", "cast_spell"] and CombatAction.is_incapacitated(monster):
		return false
	if action_type in ["attack", "move_attack"]:
		var target_id_val := str(payload.get("target_id", ""))
		if target_id_val.is_empty() or not _has_living_target(target_id_val, players):
			return false
		var target_char := _target_character(target_id_val, players)
		if target_char != null and CombatAction.is_charmed_by(monster, target_char):
			return false
		var target_pos: Variant = _target_position(target_id_val, players)
		if target_char != null and target_pos is Vector2i and not CombatAction.can_locate_target(monster, target_char, monster.get("hex_position", Vector2i.ZERO), target_pos, grid):
			return false
		var attack_idx_val := int(payload.get("attack_idx", -1))
		var attacks: Array = monster.get("attacks", [])
		if attack_idx_val < 0 or attack_idx_val >= attacks.size():
			return false
		var attack_origin: Vector2i = payload.get("move_to", monster.get("hex_position", Vector2i.ZERO)) if action_type == "move_attack" else monster.get("hex_position", Vector2i.ZERO)
		if not Targeting.has_line_of_sight(attack_origin, target_pos, grid) or HexUtils.get_distance(attack_origin, target_pos) > CombatAction.weapon_range_hexes(attacks[attack_idx_val]):
			return false
	if action_type == "cast_spell":
		var target_id_val := str(payload.get("target_id", ""))
		if target_id_val.is_empty() or not _has_living_target(target_id_val, players):
			return false
		var target_char := _target_character(target_id_val, players)
		if target_char != null and CombatAction.is_charmed_by(monster, target_char):
			return false
		var target_pos: Variant = _target_position(target_id_val, players)
		if target_char != null and target_pos is Vector2i and not CombatAction.can_locate_target(monster, target_char, monster.get("hex_position", Vector2i.ZERO), target_pos, grid):
			return false
		var spell_id_val := str(payload.get("spell_id", ""))
		var spell_data: Dictionary = DataLoader.get_spell(spell_id_val)
		if spell_data.is_empty() or str(spell_data.get("casting_time", "action")) == "reaction":
			return false
		if str(spell_data.get("target", "single")) not in ["single", "multi"]:
			return false
		var known_spell := false
		for known in monster.get("spells", []):
			if str(known.get("id", "")) == spell_id_val:
				known_spell = true
				break
		if not known_spell:
			return false
		var spell_level := int(spell_data.get("level", 0))
		if spell_level > 0 and int(monster.get("spell_slots", {}).get(str(spell_level), 0)) <= 0:
			return false
		var target_position: Variant = _target_position(target_id_val, players)
		if target_position == null or not target_position is Vector2i:
			return false
		var spell_dist := HexUtils.get_distance(monster.get("hex_position", Vector2i.ZERO), target_position)
		if spell_dist > int(spell_data.get("range", 0)):
			return false
		if not Targeting.has_line_of_sight(monster.get("hex_position", Vector2i.ZERO), target_position, grid):
			return false
		if bool(spell_data.get("requires_target_sight", false)) and not CombatPerception.can_see_target(monster, target_char, monster.get("hex_position", Vector2i.ZERO), target_position, grid):
			return false
	if action_type == "cast_area_spell":
		var spell_id_val := str(payload.get("spell_id", ""))
		var spell_data: Dictionary = DataLoader.get_spell(spell_id_val)
		if spell_data.is_empty() or not SharedSpell.uses(spell_data) or not spell_data.has("effect_noise") or str(spell_data.get("casting_time", "action")) == "reaction": return false
		if str(spell_data.get("target", "")) != "area": return false
		var known_area_spell: bool = monster.get("spells", []).any(func(known): return str(known.get("id", "")) == spell_id_val)
		if not known_area_spell: return false
		var level := int(spell_data.get("level", 0))
		if level > 0 and int(monster.get("spell_slots", {}).get(str(level), 0)) <= 0: return false
		var center_val: Variant = payload.get("target_coord", null)
		var origin: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		if not center_val is Vector2i or not grid.has_tile(center_val): return false
		var range_hexes := int(spell_data.get("range", 0))
		if HexUtils.get_distance(origin, center_val) > range_hexes or not Targeting.has_line_of_sight(origin, center_val, grid): return false
		var shape: Dictionary = SpellCastTargeting._area_selection_for_spell(null, spell_data)
		if not shape.get("success", false) or str(shape.get("shape", "")) != "sphere": return false
		var footprint := Targeting.get_sphere_targets(center_val, int(shape.get("radius", 0)), grid)
		for participant in players:
			var character: Character = participant.get("character")
			if character == null or not character.is_alive or character.current_hp <= 0: continue
			if participant.get("hex_position", Vector2i.ZERO) in footprint: return false
		for entity in fear_candidates:
			if not entity is Dictionary or not entity.has("is_alive") or not bool(entity.get("is_alive", false)) or int(entity.get("current_hp", 1)) <= 0: continue
			if entity.get("hex_position", Vector2i.ZERO) in footprint: return false
	if action_type in ["move", "move_attack"]:
		if FighterRules.monster_speed(monster) <= 0:
			return false
		var move_to_val: Variant = payload.get("move_to", null)
		if not move_to_val is Vector2i:
			return false
		var current: Variant = monster.get("hex_position", Vector2i.ZERO)
		if not current is Vector2i or HexUtils.get_distance(current, move_to_val) != 1:
			return false
		if not grid.has_tile(move_to_val) or not grid.is_hex_passable(move_to_val):
			return false
		if CombatAction.frightened_forbids_movement_closer(monster, current, move_to_val, all_candidates):
			return false
	return true


func target_id() -> String:
	return str(payload.get("target_id", ""))


func attack_idx() -> int:
	return int(payload.get("attack_idx", -1))


func spell_id() -> String:
	return str(payload.get("spell_id", ""))


func target_coord() -> Vector2i:
	return payload.get("target_coord", Vector2i.ZERO)


func move_to() -> Vector2i:
	return payload.get("move_to", Vector2i.ZERO)


func can_execute_attack(monster: Dictionary, players: Array, grid: HexGrid, attack_origin: Vector2i) -> bool:
	if action_type not in ["attack", "move_attack"] or not bool(monster.get("is_alive", true)) or int(monster.get("current_hp", 1)) <= 0 or CombatAction.is_incapacitated(monster):
		return false
	var target := target_id()
	if target.is_empty() or not _has_living_target(target, players):
		return false
	var target_char := _target_character(target, players)
	var target_pos: Variant = _target_position(target, players)
	if target_char == null or not target_pos is Vector2i or CombatAction.is_charmed_by(monster, target_char):
		return false
	if not CombatAction.can_locate_target(monster, target_char, attack_origin, target_pos, grid):
		return false
	var attacks: Array = monster.get("attacks", [])
	var index := attack_idx()
	return Targeting.has_line_of_sight(attack_origin, target_pos, grid) and index >= 0 and index < attacks.size() and HexUtils.get_distance(attack_origin, target_pos) <= CombatAction.weapon_range_hexes(attacks[index])


static func _has_living_target(target_id_value: String, players: Array) -> bool:
	for player in players:
		var character: Character = player.get("character")
		if character != null and character.is_alive and character.current_hp > 0 and character.character_name == target_id_value:
			return true
	return false


static func _target_position(target_id_value: String, players: Array) -> Variant:
	for player in players:
		var character: Character = player.get("character")
		if character != null and character.is_alive and character.current_hp > 0 and character.character_name == target_id_value:
			return player.get("hex_position", Vector2i.ZERO)
	return null


static func _target_character(target_id_value: String, players: Array) -> Character:
	for player in players:
		var character: Character = player.get("character")
		if character != null and character.is_alive and character.current_hp > 0 and character.character_name == target_id_value:
			return character
	return null
