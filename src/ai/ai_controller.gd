## Enemy AI Controller
## Implements simple behaviors (melee rush, ranged retreat, spellcasting) for monster turns.
class_name AIController
extends RefCounted


## Evaluate and return the chosen action for a monster.
## Returns {"action": String, "target_id": String, "move_to": Vector2i, "weapon_idx": int}
static func get_monster_action(monster: Dictionary, monster_coord: Vector2i, hex_grid: HexGrid, players: Array, fear_candidates: Array = []) -> Dictionary:
	var all_candidates := fear_candidates if not fear_candidates.is_empty() else players
	var behavior: String = monster.get("ai_behavior", "aggressive")
	var incapacitated := CombatAction.is_incapacitated(monster)
	var speed_hexes := FighterRules.monster_speed(monster)
	if incapacitated and speed_hexes <= 0:
		return {"action": "none"}
	
	# Find closest alive, perceptible, non-charmer player character
	var target_player_idx := -1
	var min_dist := 9999
	
	for i in players.size():
		var p: Dictionary = players[i]
		var char_data: Character = p.get("character")
		if char_data == null or not char_data.is_alive or char_data.current_hp <= 0:
			continue
		if CombatAction.is_charmed_by(monster, char_data):
			continue
		var p_coord: Vector2i = p.get("hex_position", Vector2i.ZERO)
		var dist := HexUtils.get_distance(monster_coord, p_coord)
		if not Targeting.has_line_of_effect(monster_coord, p_coord, hex_grid) or not CombatPerception.can_locate_target(monster, char_data, monster_coord, p_coord, hex_grid):
			continue
		if dist < min_dist:
			min_dist = dist
			target_player_idx = i

	if target_player_idx == -1:
		# No active players left to fight!
		return {"action": "none"}

	var target_player: Dictionary = players[target_player_idx]
	var target_coord: Vector2i = target_player.get("hex_position", Vector2i.ZERO)
	var target_char: Character = target_player.get("character")
	var target_id: String = target_char.character_name
	if incapacitated:
		if speed_hexes <= 0:
			return {"action": "none"}
		if behavior == "defensive" and min_dist <= 2:
			var retreat_hex := _best_retreat_step(monster, monster_coord, target_coord, min_dist, hex_grid, all_candidates)
			if retreat_hex != monster_coord:
				return {"action": "move", "move_to": retreat_hex}
			return {"action": "none"}
		if min_dist > 1:
			var approach_step := _next_approach_step(monster, monster_coord, target_coord, hex_grid, all_candidates)
			if approach_step != monster_coord:
				return {"action": "move", "move_to": approach_step}
		return {"action": "none"}

	var chosen_spell: Dictionary = _choose_offensive_spell(monster, min_dist, CombatPerception.can_see_target(monster, target_char, monster_coord, target_coord, hex_grid))
	if not chosen_spell.is_empty():
		return {
			"action": "cast_spell",
			"target_id": target_id,
			"spell_id": str(chosen_spell.get("id", "")),
		}

	# Determine available attacks
	var attacks: Array = monster.get("attacks", [])
	if attacks.is_empty():
		return {"action": "none"}

	# Select best attack based on range
	var chosen_attack_idx := 0
	var preferred_range := 1
	for idx in attacks.size():
		var range_val: int = CombatAction.weapon_range_hexes(attacks[idx])
		if behavior == "defensive" and min_dist <= 2:
			if range_val > preferred_range:
				chosen_attack_idx = idx
				preferred_range = range_val
			continue
		if min_dist <= range_val:
			chosen_attack_idx = idx
			preferred_range = range_val
			break

	var chosen_attack: Dictionary = attacks[chosen_attack_idx]
	var attack_range: int = CombatAction.weapon_range_hexes(chosen_attack)

	# A movement reduction cannot grant a move when effective speed is zero.
	if speed_hexes <= 0 and min_dist > attack_range:
		return {"action": "none"}
	# Decide movement & action based on behavior
	match behavior:
		"defensive":
			# If player is too close, try to move back and use ranged attack
			if speed_hexes > 0 and min_dist <= 2:
				var best_hex := _best_retreat_step(monster, monster_coord, target_coord, min_dist, hex_grid, all_candidates)
				# Move away and attack if possible
				if best_hex != monster_coord:
					if HexUtils.get_distance(best_hex, target_coord) > attack_range:
						return {"action":"move", "move_to":best_hex}
					return {
						"action": "move_attack",
						"target_id": target_id,
						"move_to": best_hex,
						"attack_idx": chosen_attack_idx
					}

			# Ranged attack if in range, else move closer
			if min_dist <= attack_range:
				return {
					"action": "attack",
					"target_id": target_id,
					"attack_idx": chosen_attack_idx
				}
			elif speed_hexes > 0:
				var step := _next_approach_step(monster, monster_coord, target_coord, hex_grid, all_candidates)
				if step != monster_coord:
					return {
						"action": "move",
						"move_to": step
					}

		"support":
			# For core MVP monsters: simple aggressive behavior if no heal actions
			# Aggressive rush
			pass

	# Default "aggressive": move towards player and attack
	if min_dist <= attack_range:
		return {
			"action": "attack",
			"target_id": target_id,
			"attack_idx": chosen_attack_idx
		}
	elif speed_hexes > 0:
		var step := _next_approach_step(monster, monster_coord, target_coord, hex_grid, all_candidates)
		if step != monster_coord:
			var new_dist := HexUtils.get_distance(step, target_coord)
			if new_dist <= attack_range:
				return {
					"action": "move_attack",
					"target_id": target_id,
					"move_to": step,
					"attack_idx": chosen_attack_idx
				}
			else:
				return {
					"action": "move",
					"move_to": step
				}

	return {"action": "none"}


static func _best_retreat_step(monster: Dictionary, monster_coord: Vector2i, target_coord: Vector2i, min_dist: int, hex_grid: HexGrid, players: Array) -> Vector2i:
	var best_hex := monster_coord
	var max_d := min_dist
	for n in HexUtils.get_neighbors(monster_coord):
		if not hex_grid.is_hex_passable(n):
			continue
		if CombatAction.frightened_forbids_movement_closer(monster, monster_coord, n, players):
			continue
		var d := HexUtils.get_distance(n, target_coord)
		if d > max_d:
			max_d = d
			best_hex = n
	return best_hex


static func _next_approach_step(monster: Dictionary, monster_coord: Vector2i, target_coord: Vector2i, hex_grid: HexGrid, players: Array) -> Vector2i:
	var path := hex_grid.find_path(monster_coord, target_coord)
	if path.size() > 1:
		var step: Vector2i = path[1]
		if not CombatAction.frightened_forbids_movement_closer(monster, monster_coord, step, players):
			return step
	var best_hex := monster_coord
	var best_dist := HexUtils.get_distance(monster_coord, target_coord)
	for n in HexUtils.get_neighbors(monster_coord):
		if not hex_grid.is_hex_passable(n):
			continue
		if CombatAction.frightened_forbids_movement_closer(monster, monster_coord, n, players):
			continue
		var d := HexUtils.get_distance(n, target_coord)
		if d < best_dist:
			best_dist = d
			best_hex = n
	return best_hex


static func _is_charm_caster(monster: Dictionary, character_id: String) -> bool:
	return CombatAction.is_charmed_by(monster, character_id)


static func _choose_offensive_spell(monster: Dictionary, distance: int, target_visible: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var best_level := -1
	var monster_blinded := not target_visible
	for known in monster.get("spells", []):
		var spell_id := str(known.get("id", ""))
		var spell_data: Dictionary = DataLoader.get_spell(spell_id)
		if spell_data.is_empty() or str(spell_data.get("casting_time", "action")) == "reaction":
			continue
		if monster_blinded and bool(spell_data.get("requires_target_sight", false)):
			continue
		if str(spell_data.get("target", "single")) not in ["single", "multi"]:
			continue
		if not spell_data.has("damage") and not spell_data.has("damage_per_dart") and not spell_data.has("damage_per_ray") and str(spell_data.get("attack_type", "none")) == "none":
			continue
		if distance > int(spell_data.get("range", 0)):
			continue
		var spell_level := int(spell_data.get("level", 0))
		if spell_level > 0 and int(monster.get("spell_slots", {}).get(str(spell_level), 0)) <= 0:
			continue
		if spell_level > best_level:
			best = spell_data
			best_level = spell_level
	return best
