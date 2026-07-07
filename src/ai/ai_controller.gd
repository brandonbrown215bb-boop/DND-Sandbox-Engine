## Enemy AI Controller
## Implements simple behaviors (melee rush, ranged retreat, spellcasting) for monster turns.
class_name AIController
extends RefCounted


## Evaluate and return the chosen action for a monster.
## Returns {"action": String, "target_id": String, "move_to": Vector2i, "weapon_idx": int}
static func get_monster_action(monster: Dictionary, monster_coord: Vector2i, hex_grid: HexGrid, players: Array) -> Dictionary:
	var behavior: String = monster.get("ai_behavior", "aggressive")
	
	# Find closest alive player character
	var target_player_idx := -1
	var min_dist := 9999
	
	for i in players.size():
		var p: Dictionary = players[i]
		var char_data: Character = p.get("character")
		if char_data == null or not char_data.is_alive:
			continue
			
		var p_coord: Vector2i = p.get("hex_position", Vector2i.ZERO)
		var dist := HexUtils.get_distance(monster_coord, p_coord)
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

	# Determine available attacks
	var attacks: Array = monster.get("attacks", [])
	if attacks.is_empty():
		return {"action": "none"}

	# Select best attack based on range
	var chosen_attack_idx := 0
	var preferred_range := 1
	for idx in attacks.size():
		var range_val: int = int(attacks[idx].get("range", 1))
		if min_dist <= range_val:
			chosen_attack_idx = idx
			preferred_range = range_val
			break

	var chosen_attack: Dictionary = attacks[chosen_attack_idx]
	var attack_range: int = int(chosen_attack.get("range", 1))

	# Decide movement & action based on behavior
	match behavior:
		"defensive":
			# If player is too close, try to move back and use ranged attack
			if min_dist <= 2:
				# Find neighbor furthest from player
				var best_hex := monster_coord
				var max_d := min_dist
				for n in HexUtils.get_neighbors(monster_coord):
					if hex_grid.is_hex_passable(n):
						var d := HexUtils.get_distance(n, target_coord)
						if d > max_d:
							max_d = d
							best_hex = n
				
				# Move away and attack if possible
				if best_hex != monster_coord:
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
			else:
				# Pathfind towards player
				var path := hex_grid.find_path(monster_coord, target_coord)
				if path.size() > 1:
					var step = path[1] # first step in path
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
	else:
		# Pathfind closer
		var path := hex_grid.find_path(monster_coord, target_coord)
		if path.size() > 1:
			var step = path[1]
			# If step makes them close enough to attack, do move_attack
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
