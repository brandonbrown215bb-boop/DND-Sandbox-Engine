class_name RollTokenRules
extends RefCounted

const SUPPORTED_PREDICATES := ["any_visible", "self_only", "ally_visible", "enemy_visible"]
const SUPPORTED_TIMINGS := ["long_rest"]


static func pool_definitions(character: Character) -> Array[Dictionary]:
	var pools: Array[Dictionary] = []
	if character == null:
		return pools
	var upgrades: Dictionary = {}
	for feat in character.features:
		if not (feat is Dictionary) or not bool(feat.get("enabled", true)):
			continue
		for effect in feat.get("effects", []):
			if not (effect is Dictionary):
				continue
			if str(effect.get("type", "")) == "roll_token_pool_upgrade":
				var upgrade_pool_id := str(effect.get("pool_id", "")).strip_edges()
				var count := int(effect.get("token_count", 0))
				if not upgrade_pool_id.is_empty() and count > 0:
					upgrades[upgrade_pool_id] = maxi(int(upgrades.get(upgrade_pool_id, 0)), count)
	for feat in character.features:
		if not (feat is Dictionary) or not bool(feat.get("enabled", true)):
			continue
		var feature_id := str(feat.get("id", "")).strip_edges()
		var feature_name := str(feat.get("name", feature_id)).strip_edges()
		for effect in feat.get("effects", []):
			if not (effect is Dictionary) or str(effect.get("type", "")) != "roll_token_pool":
				continue
			var pool_id := str(effect.get("pool_id", feature_id)).strip_edges()
			if pool_id.is_empty():
				continue
			var capacity := _effect_capacity_for_level(effect, character.level)
			if upgrades.has(pool_id):
				capacity = maxi(capacity, int(upgrades[pool_id]))
			if capacity <= 0:
				continue
			pools.append({
				"pool_id": pool_id,
				"feature_id": feature_id,
				"feature_name": feature_name,
				"die_sides": int(effect.get("die_sides", 20)),
				"capacity": capacity,
				"generation_timing": str(effect.get("generation_timing", "long_rest")),
				"target_predicate": str(effect.get("target_predicate", "any_visible")),
				"uses_per_turn": maxi(1, int(effect.get("uses_per_turn", 1))),
			})
	return pools


static func pool_definition(character: Character, pool_id: String) -> Dictionary:
	for pool in pool_definitions(character):
		if str(pool.get("pool_id", "")) == pool_id:
			return pool
	return {}


static func pool_effect_for_character(character: Character, pool_id: String) -> Dictionary:
	return pool_definition(character, pool_id)


static func pool_definitions_for_data(data: Dictionary, subclass: Dictionary, level: int) -> Dictionary:
	var raw_features: Array = []
	for source in [data, subclass]:
		var by_level: Variant = source.get("features_by_level", {})
		if not (by_level is Dictionary):
			continue
		for lvl_key in by_level:
			if int(lvl_key) > level:
				continue
			var list: Variant = by_level[lvl_key]
			if not (list is Array):
				continue
			for feat in list:
				if feat is Dictionary and bool(feat.get("enabled", true)):
					raw_features.append(feat)
	var upgrades: Dictionary = {}
	for feat in raw_features:
		for effect in feat.get("effects", []):
			if effect is Dictionary and str(effect.get("type", "")) == "roll_token_pool_upgrade":
				var upgrade_pool_id := str(effect.get("pool_id", "")).strip_edges()
				var count := int(effect.get("token_count", 0))
				if not upgrade_pool_id.is_empty() and count > 0:
					upgrades[upgrade_pool_id] = maxi(int(upgrades.get(upgrade_pool_id, 0)), count)
	var pools: Dictionary = {}
	for feat in raw_features:
		var feature_id := str(feat.get("id", "")).strip_edges()
		for effect in feat.get("effects", []):
			if not (effect is Dictionary) or str(effect.get("type", "")) != "roll_token_pool":
				continue
			var pool_id := str(effect.get("pool_id", feature_id)).strip_edges()
			if pool_id.is_empty():
				continue
			var capacity := _effect_capacity_for_level(effect, level)
			if upgrades.has(pool_id):
				capacity = maxi(capacity, int(upgrades[pool_id]))
			if capacity <= 0:
				continue
			pools[pool_id] = {
				"pool_id": pool_id,
				"feature_id": feature_id,
				"die_sides": int(effect.get("die_sides", 20)),
				"capacity": capacity,
				"generation_timing": str(effect.get("generation_timing", "long_rest")),
				"target_predicate": str(effect.get("target_predicate", "any_visible")),
				"uses_per_turn": maxi(1, int(effect.get("uses_per_turn", 1))),
			}
	return pools


static func _effect_capacity_for_level(effect: Dictionary, level: int) -> int:
	var capacity := int(effect.get("token_count", 0))
	var by_level: Variant = effect.get("token_count_by_level", {})
	if by_level is Dictionary:
		var best_level := -1
		for key in by_level:
			var threshold := int(key)
			if threshold <= level and threshold > best_level:
				best_level = threshold
				capacity = int(by_level[key])
	return capacity


static func sync_pools_on_acquire(character: Character) -> void:
	if character == null:
		return
	var pools := pool_definitions(character)
	for pool in pools:
		var pool_id := str(pool.get("pool_id", ""))
		var capacity := int(pool.get("capacity", 0))
		var die_sides := int(pool.get("die_sides", 20))
		var feature_id := str(pool.get("feature_id", ""))
		var cap_key := "roll_token_capacity:%s" % pool_id
		if not character.roll_tokens.has(pool_id):
			character.roll_token_generation_serial += 1
			var serial := character.roll_token_generation_serial
			var tokens: Array[Dictionary] = []
			for index in capacity:
				var value: int = Dice.roll(die_sides)
				tokens.append({
					"token_id": "%s:%d:%d" % [pool_id, serial, index],
					"value": value,
					"feature_id": feature_id,
					"pool_id": pool_id,
					"die_sides": die_sides,
				})
			character.roll_tokens[pool_id] = tokens
			character.feature_uses[cap_key] = capacity
		else:
			var existing := tokens_for_pool(character, pool_id)
			var previous_cap := int(character.feature_uses.get(cap_key, existing.size()))
			if capacity > previous_cap:
				var delta := capacity - previous_cap
				var serial := maxi(1, character.roll_token_generation_serial)
				var start_idx := existing.size()
				for offset in delta:
					var value: int = Dice.roll(die_sides)
					existing.append({
						"token_id": "%s:%d:%d" % [pool_id, serial, start_idx + offset],
						"value": value,
						"feature_id": feature_id,
						"pool_id": pool_id,
						"die_sides": die_sides,
					})
				character.roll_tokens[pool_id] = existing
				character.feature_uses[cap_key] = capacity


static func ensure_initialized(character: Character) -> void:
	sync_pools_on_acquire(character)


static func generate_for_rest(character: Character, timing: String = "long_rest") -> Array[Dictionary]:
	var generated: Array[Dictionary] = []
	if character == null or not character.is_alive:
		return generated
	var pools := pool_definitions(character)
	var valid_pool_ids: Dictionary = {}
	for pool in pools:
		var pool_id := str(pool.get("pool_id", ""))
		valid_pool_ids[pool_id] = true
		if str(pool.get("generation_timing", "long_rest")) != timing:
			continue
		character.roll_token_generation_serial += 1
		var serial := character.roll_token_generation_serial
		var capacity := int(pool.get("capacity", 0))
		var die_sides := int(pool.get("die_sides", 20))
		var feature_id := str(pool.get("feature_id", ""))
		var tokens: Array[Dictionary] = []
		for index in capacity:
			var value: int = Dice.roll(die_sides)
			var token := {
				"token_id": "%s:%d:%d" % [pool_id, serial, index],
				"value": value,
				"feature_id": feature_id,
				"pool_id": pool_id,
				"die_sides": die_sides,
			}
			tokens.append(token)
			generated.append(token.duplicate(true))
		character.roll_tokens[pool_id] = tokens
		character.feature_uses["roll_token_capacity:%s" % pool_id] = capacity
		clear_turn_counter(character, pool_id)
	for existing_pool_id in character.roll_tokens.keys():
		if not valid_pool_ids.has(str(existing_pool_id)):
			character.roll_tokens.erase(existing_pool_id)
	return generated


static func regenerate_all_pools(character: Character) -> Array[Dictionary]:
	return generate_for_rest(character, "long_rest")


static func tokens_for_pool(character: Character, pool_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if character == null or not (character.roll_tokens is Dictionary):
		return result
	var raw: Variant = character.roll_tokens.get(pool_id, [])
	if raw is Dictionary and raw.get("tokens") is Array:
		raw = raw["tokens"]
	if not (raw is Array):
		return result
	for entry in raw:
		if entry is Dictionary:
			result.append(entry.duplicate(true))
	return result


static func available_tokens(character: Character, pool_id: String) -> Array[Dictionary]:
	return tokens_for_pool(character, pool_id)


static func get_available_tokens(character: Character, pool_id: String) -> Array[Dictionary]:
	return tokens_for_pool(character, pool_id)


static func get_available_values(character: Character, pool_id: String) -> Array[int]:
	var values: Array[int] = []
	for token in tokens_for_pool(character, pool_id):
		values.append(int(token.get("value", 0)))
	return values


static func all_tokens(character: Character) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if character == null:
		return result
	for pool in pool_definitions(character):
		var pool_id := str(pool.get("pool_id", ""))
		for token in tokens_for_pool(character, pool_id):
			var enriched := token.duplicate(true)
			enriched["feature_name"] = str(pool.get("feature_name", pool_id))
			enriched["target_predicate"] = str(pool.get("target_predicate", "any_visible"))
			enriched["uses_per_turn"] = int(pool.get("uses_per_turn", 1))
			result.append(enriched)
	return result


static func find_token(character: Character, pool_id: String, token_id: String) -> Dictionary:
	if character == null or pool_id.is_empty() or token_id.is_empty():
		return {}
	for token in tokens_for_pool(character, pool_id):
		var tid := str(token.get("token_id", token.get("id", "")))
		if tid == token_id:
			return token
	return {}


static func format_pool_status(character: Character, pool: Dictionary) -> String:
	var pool_id := str(pool.get("pool_id", ""))
	var feature_name := str(pool.get("feature_name", pool_id))
	var capacity := int(pool.get("capacity", 0))
	var tokens := tokens_for_pool(character, pool_id)
	if tokens.is_empty():
		return "%s: exhausted (0/%d remaining)" % [feature_name, capacity]
	var values: Array[String] = []
	for token in tokens:
		values.append(str(int(token.get("value", 0))))
	var turn_status := "%d/turn" % int(pool.get("uses_per_turn", 1)) if can_use_pool_this_turn(character, pool) else "used this turn"
	return "%s: %s (%s)" % [feature_name, ", ".join(values), turn_status]


static func summary_lines(character: Character) -> Array[String]:
	var lines: Array[String] = []
	if character == null:
		return lines
	for pool in pool_definitions(character):
		lines.append(format_pool_status(character, pool))
	return lines


static func can_use_pool_this_turn(owner: Character, pool: Dictionary) -> bool:
	if owner == null or pool.is_empty():
		return false
	var pool_id := str(pool.get("pool_id", ""))
	if pool_id.is_empty():
		return false
	var max_per_turn := maxi(1, int(pool.get("uses_per_turn", 1)))
	var turn_key := "roll_token_turn:%s" % pool_id
	var count_key := "roll_token_turn_uses:%s" % pool_id
	var recorded_turn := int(owner.feature_uses.get(turn_key, -1))
	if recorded_turn != CombatAction.active_turn_serial:
		return true
	return int(owner.feature_uses.get(count_key, 0)) < max_per_turn


static func mark_pool_used_this_turn(owner: Character, pool_id: String) -> void:
	if owner == null or pool_id.is_empty():
		return
	var turn_key := "roll_token_turn:%s" % pool_id
	var count_key := "roll_token_turn_uses:%s" % pool_id
	if int(owner.feature_uses.get(turn_key, -1)) != CombatAction.active_turn_serial:
		owner.feature_uses[turn_key] = CombatAction.active_turn_serial
		owner.feature_uses[count_key] = 1
	else:
		owner.feature_uses[count_key] = int(owner.feature_uses.get(count_key, 0)) + 1


static func clear_turn_counter(owner: Character, pool_id: String = "") -> void:
	if owner == null:
		return
	if not pool_id.is_empty():
		owner.feature_uses.erase("roll_token_turn:%s" % pool_id)
		owner.feature_uses.erase("roll_token_turn_uses:%s" % pool_id)
		return
	for key in owner.feature_uses.keys():
		var key_str := str(key)
		if key_str.begins_with("roll_token_turn:") or key_str.begins_with("roll_token_turn_uses:"):
			owner.feature_uses.erase(key)


static func is_ally(owner: Character, roller, context: Dictionary = {}) -> bool:
	if owner == null or roller == null:
		return false
	if roller is Character and roller == owner:
		return true
	if context.has("roller_is_ally"):
		return bool(context["roller_is_ally"])
	if roller is Dictionary:
		return bool(roller.get("is_player", roller.get("is_ally", false)))
	if roller is Character:
		if bool(roller.feature_uses.get("is_monster_actor", false)) or bool(roller.feature_uses.get("is_hostile", false)):
			return false
		var players: Variant = context.get("players", [])
		if players is Array and not players.is_empty():
			for entry in players:
				if entry is Dictionary and entry.get("character") == roller:
					return true
			return false
		return true
	return false


static func can_see_roller(owner: Character, roller, context: Dictionary = {}) -> bool:
	if owner == null or roller == null:
		return false
	if not owner.is_alive or owner.is_downed() or CombatAction.is_incapacitated(owner):
		return false
	var vis_target = roller
	if roller is Character:
		if roller.is_dead():
			return false
		if roller.feature_uses.get("monster_source") is Dictionary:
			vis_target = roller.feature_uses["monster_source"]
	elif roller is Dictionary:
		if not bool(roller.get("is_alive", true)) or int(roller.get("current_hp", 1)) <= 0:
			return false
	else:
		return false
	if roller is Character and roller == owner:
		return true
	if context.has("roller_visible"):
		return bool(context["roller_visible"])
	var grid: HexGrid = context.get("grid") as HexGrid
	if grid == null and context.get("spell_visibility") is Dictionary:
		grid = context["spell_visibility"].get("grid") as HexGrid
	var owner_pos: Variant = _resolve_actor_position(owner, context, "owner_position")
	var roller_pos: Variant = _resolve_actor_position(vis_target, context, "roller_position")
	if grid != null and owner_pos is Vector2i and roller_pos is Vector2i:
		return CombatPerception.can_see_target(owner, vis_target, owner_pos, roller_pos, grid)
	if owner.has_condition("blinded"):
		var distance_feet := int(context.get("distance_feet", 5))
		if not CombatPerception._has_blindsight(owner, distance_feet) and not CombatPerception._has_truesight(owner, distance_feet):
			return false
	if CombatAction.is_invisible(vis_target):
		var distance_feet := int(context.get("distance_feet", 5))
		if not CombatAction.can_perceive_invisible(owner, distance_feet):
			return false
	return true


static func _resolve_actor_position(actor, context: Dictionary, explicit_key: String) -> Variant:
	if context.has(explicit_key) and context[explicit_key] is Vector2i:
		return context[explicit_key]
	if actor is Dictionary and actor.get("hex_position") is Vector2i:
		return actor["hex_position"]
	var players: Variant = context.get("players", [])
	if actor is Character and players is Array:
		for entry in players:
			if entry is Dictionary and entry.get("character") == actor and entry.get("hex_position") is Vector2i:
				return entry["hex_position"]
	var monsters: Variant = context.get("monsters", [])
	if actor is Dictionary and monsters is Array:
		var actor_id := str(actor.get("id", ""))
		for entry in monsters:
			if entry is Dictionary and (entry == actor or (not actor_id.is_empty() and str(entry.get("id", "")) == actor_id)) and entry.get("hex_position") is Vector2i:
				return entry["hex_position"]
	return null


static func matches_target_predicate(owner: Character, roller, predicate: String, context: Dictionary = {}) -> bool:
	match predicate:
		"self", "self_only":
			return roller is Character and roller == owner
		"ally_visible":
			return is_ally(owner, roller, context)
		"enemy_visible":
			return not is_ally(owner, roller, context)
		"any_visible", "self_or_visible_creature", "visible":
			return true
		_:
			return false


static func validate_replacement_request(owner: Character, roller, pool_id: String, token_id: String, context: Dictionary = {}) -> Dictionary:
	if owner == null:
		return {"valid": false, "reason": "Roll token owner is missing."}
	if not owner.is_alive or owner.is_downed() or CombatAction.is_incapacitated(owner):
		return {"valid": false, "reason": "%s cannot use roll tokens while incapacitated or unconscious." % owner.character_name}
	if roller == null:
		return {"valid": false, "reason": "D20 Test target is missing."}
	var pool := pool_definition(owner, pool_id)
	if pool.is_empty():
		return {"valid": false, "reason": "%s does not own roll token pool '%s'." % [owner.character_name, pool_id]}
	if not can_use_pool_this_turn(owner, pool):
		return {"valid": false, "reason": "%s has already used %s on this turn." % [owner.character_name, str(pool.get("feature_name", pool_id))]}
	var predicate := str(pool.get("target_predicate", "any_visible"))
	if not matches_target_predicate(owner, roller, predicate, context):
		return {"valid": false, "reason": "%s cannot apply %s to that creature (%s)." % [owner.character_name, str(pool.get("feature_name", pool_id)), predicate]}
	if not can_see_roller(owner, roller, context):
		return {"valid": false, "reason": "%s cannot see the creature making the D20 Test." % owner.character_name}
	var token := find_token(owner, pool_id, token_id)
	if token.is_empty():
		return {"valid": false, "reason": "Roll token '%s' is unavailable or already spent." % token_id}
	return {"valid": true, "pool": pool, "token": token}


static func eligible_options_for_test(owners: Array, roller, context: Dictionary = {}) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for candidate in owners:
		var owner: Character = candidate if candidate is Character else (candidate.get("character") if candidate is Dictionary else null)
		if owner == null:
			continue
		for pool in pool_definitions(owner):
			var pool_id := str(pool.get("pool_id", ""))
			if not can_use_pool_this_turn(owner, pool):
				continue
			if not matches_target_predicate(owner, roller, str(pool.get("target_predicate", "any_visible")), context):
				continue
			if not can_see_roller(owner, roller, context):
				continue
			for token in tokens_for_pool(owner, pool_id):
				var tid := str(token.get("token_id", token.get("id", "")))
				options.append({
					"owner": owner,
					"owner_id": owner.character_id,
					"owner_name": owner.character_name,
					"pool_id": pool_id,
					"feature_id": str(pool.get("feature_id", "")),
					"feature_name": str(pool.get("feature_name", pool_id)),
					"source_name": str(pool.get("feature_name", pool_id)),
					"token_id": tid,
					"value": int(token.get("value", 0)),
					"label": "%s — %s: %d" % [owner.character_name, str(pool.get("feature_name", pool_id)), int(token.get("value", 0))],
				})
	return options


static func consume_token(owner: Character, pool_id: String, token_id: String) -> Dictionary:
	if owner == null or not (owner.roll_tokens is Dictionary):
		return {}
	var raw: Variant = owner.roll_tokens.get(pool_id, [])
	var is_wrapped := false
	if raw is Dictionary and raw.get("tokens") is Array:
		is_wrapped = true
		raw = raw["tokens"]
	if not (raw is Array):
		return {}
	var remaining: Array[Dictionary] = []
	var consumed: Dictionary = {}
	for entry in raw:
		if not (entry is Dictionary):
			continue
		var tid := str(entry.get("token_id", entry.get("id", "")))
		if consumed.is_empty() and tid == token_id:
			consumed = entry.duplicate(true)
			continue
		remaining.append(entry.duplicate(true))
	if consumed.is_empty():
		return {}
	if is_wrapped:
		owner.roll_tokens[pool_id]["tokens"] = remaining
	else:
		owner.roll_tokens[pool_id] = remaining
	mark_pool_used_this_turn(owner, pool_id)
	return consumed


static func normalize_decision(seeded_decisions: Dictionary) -> Dictionary:
	if seeded_decisions.is_empty():
		return {}
	for key in [
		"roll_token_replacement",
		"attack_roll_token_replacement",
		"save_roll_token_replacement",
		"monster_save_roll_token_replacement",
		"check_roll_token_replacement",
		"initiative_roll_token_replacement",
		"death_save_roll_token_replacement",
	]:
		if seeded_decisions.get(key) is Dictionary and not (seeded_decisions[key] as Dictionary).is_empty():
			return seeded_decisions[key]
	if seeded_decisions.has("pool_id") and seeded_decisions.has("token_id"):
		return seeded_decisions
	return {}


static func _actor_matches_request_target(roller, req: Dictionary) -> bool:
	if req.has("roller") and req["roller"] != null:
		if roller == req["roller"]:
			return true
		if roller is Character and roller.feature_uses.get("monster_source") == req["roller"]:
			return true
		return false
	var target_id := str(req.get("target_id", "")).strip_edges()
	if target_id.is_empty():
		return true
	if roller is Character:
		if roller.character_id == target_id or roller.character_name == target_id or "player:%s" % roller.character_id == target_id:
			return true
		if roller.feature_uses.get("monster_source") is Dictionary:
			var m_source: Dictionary = roller.feature_uses["monster_source"]
			if str(m_source.get("id", "")) == target_id or str(m_source.get("name", "")) == target_id or "monster:%s" % str(m_source.get("id", "")) == target_id:
				return true
		return false
	if roller is Dictionary:
		var m_id := str(roller.get("id", ""))
		var m_name := str(roller.get("name", ""))
		return m_id == target_id or m_name == target_id or "monster:%s" % m_id == target_id
	return false


static func _matching_requests_for_test(roller, test_kind: String, decisions: Dictionary) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	if decisions.is_empty():
		return matches
	if decisions.has("pool_id") and decisions.has("token_id") and not bool(decisions.get("_consumed", false)):
		matches.append(decisions)
	var candidate_keys := ["roll_token_replacement"]
	match test_kind:
		"attack":
			candidate_keys.append("attack_roll_token_replacement")
		"save":
			candidate_keys.append_array(["save_roll_token_replacement", "concentration_roll_token_replacement", "sanctuary_roll_token_replacement", "counterspell_roll_token_replacement", "relentless_rage_roll_token_replacement"])
		"monster_save":
			candidate_keys.append_array(["save_roll_token_replacement", "monster_save_roll_token_replacement"])
		"ability_check":
			candidate_keys.append("check_roll_token_replacement")
		"initiative":
			candidate_keys.append("initiative_roll_token_replacement")
		"death_save":
			candidate_keys.append("death_save_roll_token_replacement")
	for key in candidate_keys:
		var single: Variant = decisions.get(key)
		if single is Dictionary and not single.is_empty() and not bool(single.get("_consumed", false)):
			var req_kind := str(single.get("test_kind", "")).strip_edges()
			if (req_kind.is_empty() or req_kind == test_kind or (req_kind == "save" and test_kind == "monster_save")) and _actor_matches_request_target(roller, single):
				if single not in matches:
					matches.append(single)
	var list: Variant = decisions.get("roll_token_replacements", [])
	if list is Array:
		for item in list:
			if item is Dictionary and not item.is_empty() and not bool(item.get("_consumed", false)):
				var req_kind := str(item.get("test_kind", "")).strip_edges()
				if (req_kind.is_empty() or req_kind == test_kind or (req_kind == "save" and test_kind == "monster_save")) and _actor_matches_request_target(roller, item):
					if item not in matches:
						matches.append(item)
	return matches


static func _resolve_owner(req: Dictionary, decisions: Dictionary) -> Character:
	if req.get("owner") is Character:
		return req["owner"] as Character
	if req.get("actor") is Character:
		return req["actor"] as Character
	var owner_id := str(req.get("owner_id", "")).strip_edges()
	if not owner_id.is_empty():
		var players: Variant = decisions.get("players", [])
		if players is Array:
			for entry in players:
				if entry is Dictionary and entry.get("character") is Character:
					var c: Character = entry["character"]
					if c.character_id == owner_id or c.character_name == owner_id:
						return c
		if PartyManager != null:
			for c in PartyManager.characters.values():
				if c is Character and (c.character_id == owner_id or c.character_name == owner_id):
					return c
	return null


static func _roll_normal_d20_details(advantage: bool, disadvantage: bool, roller) -> Dictionary:
	var char_roller: Character = roller if roller is Character and not bool(roller.feature_uses.get("is_monster_actor", false)) else null
	if advantage and not disadvantage:
		return Dice.roll_with_advantage_details(20, char_roller)
	if disadvantage and not advantage:
		return Dice.roll_with_disadvantage_details(20, char_roller)
	return Dice.roll_single_details(20, char_roller)


static func resolve_d20_test(roller, test_kind: String, advantage: bool = false, disadvantage: bool = false, decisions: Dictionary = {}) -> Dictionary:
	var matching := _matching_requests_for_test(roller, test_kind, decisions)
	if matching.is_empty():
		var normal: Dictionary = _roll_normal_d20_details(advantage, disadvantage, roller)
		normal["replaced"] = false
		normal["replaced_by_roll_token"] = false
		return normal
	if matching.size() > 1:
		var conflict_msg := "Multiple competing roll token replacements cannot apply to the same D20 Test."
		decisions["roll_token_conflict"] = true
		decisions["roll_token_error"] = conflict_msg
		var fallback: Dictionary = _roll_normal_d20_details(advantage, disadvantage, roller)
		fallback["replaced"] = false
		fallback["replaced_by_roll_token"] = false
		fallback["roll_token_conflict"] = true
		fallback["roll_token_error"] = conflict_msg
		return fallback
	var req: Dictionary = matching[0]
	var owner := _resolve_owner(req, decisions)
	var pool_id := str(req.get("pool_id", "")).strip_edges()
	var token_id := str(req.get("token_id", "")).strip_edges()
	var validation := validate_replacement_request(owner, roller, pool_id, token_id, decisions)
	if not bool(validation.get("valid", false)):
		var reason := str(validation.get("reason", "Roll token replacement refused."))
		decisions["roll_token_refused"] = true
		decisions["roll_token_error"] = reason
		var refused: Dictionary = _roll_normal_d20_details(advantage, disadvantage, roller)
		refused["replaced"] = false
		refused["replaced_by_roll_token"] = false
		refused["roll_token_refused"] = true
		refused["roll_token_error"] = reason
		return refused
	var pool: Dictionary = validation["pool"]
	var consumed := consume_token(owner, pool_id, token_id)
	if consumed.is_empty():
		var reason := "Roll token '%s' could not be consumed." % token_id
		decisions["roll_token_refused"] = true
		decisions["roll_token_error"] = reason
		var refused: Dictionary = _roll_normal_d20_details(advantage, disadvantage, roller)
		refused["replaced"] = false
		refused["replaced_by_roll_token"] = false
		refused["roll_token_refused"] = true
		refused["roll_token_error"] = reason
		return refused
	req["_consumed"] = true
	var token_val := int(consumed.get("value", 1))
	var rolls: Array = [token_val]
	var kept: Array = [true]
	var used_meta := {
		"token_id": token_id,
		"value": token_val,
		"pool_id": pool_id,
		"feature_id": str(consumed.get("feature_id", pool.get("feature_id", ""))),
		"feature_name": str(pool.get("feature_name", pool_id)),
		"owner_id": owner.character_id,
		"owner_name": owner.character_name,
		"test_kind": test_kind,
		"mode": "replaced",
		"rolls": rolls.duplicate(),
		"natural_total": token_val,
	}
	decisions["last_roll_token_used"] = used_meta
	var used_list: Array = decisions.get("roll_tokens_used", [])
	used_list.append(used_meta)
	decisions["roll_tokens_used"] = used_list
	return {
		"total": token_val,
		"rolls": rolls,
		"kept": kept,
		"mode": "replaced",
		"replaced": true,
		"replaced_by_roll_token": true,
		"roll_token_id": token_id,
		"roll_token_value": token_val,
		"roll_token_pool_id": pool_id,
		"roll_token_feature_id": str(consumed.get("feature_id", pool.get("feature_id", ""))),
		"roll_token_feature_name": str(pool.get("feature_name", pool_id)),
		"roll_token_owner_id": owner.character_id,
		"roll_token_owner_name": owner.character_name,
	}


static func serialize_tokens(roll_tokens: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for pool_id in roll_tokens:
		var raw_list: Variant = roll_tokens[pool_id]
		if raw_list is Dictionary and raw_list.get("tokens") is Array:
			raw_list = raw_list["tokens"]
		if not (raw_list is Array):
			continue
		var list_out: Array = []
		for item in raw_list:
			if item is Dictionary:
				list_out.append({
					"token_id": str(item.get("token_id", item.get("id", ""))),
					"value": int(item.get("value", 0)),
					"feature_id": str(item.get("feature_id", item.get("source_id", pool_id))),
					"pool_id": str(item.get("pool_id", pool_id)),
					"die_sides": int(item.get("die_sides", 20)),
				})
		out[str(pool_id)] = list_out
	return out


static func deserialize_tokens(raw_tokens: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw_tokens is Dictionary):
		return out
	for pool_id in raw_tokens:
		var raw_list: Variant = raw_tokens[pool_id]
		if raw_list is Dictionary and raw_list.get("tokens") is Array:
			raw_list = raw_list["tokens"]
		if not (raw_list is Array):
			continue
		var list_out: Array[Dictionary] = []
		for item in raw_list:
			if item is Dictionary:
				list_out.append({
					"token_id": str(item.get("token_id", item.get("id", ""))),
					"value": int(item.get("value", 0)),
					"feature_id": str(item.get("feature_id", item.get("source_id", pool_id))),
					"pool_id": str(item.get("pool_id", pool_id)),
					"die_sides": int(item.get("die_sides", 20)),
				})
		out[str(pool_id)] = list_out
	return out


static func saved_state_error(dto: Dictionary, data: Dictionary, subclass: Dictionary, level: int) -> String:
	if dto.has("roll_token_generation_serial"):
		var raw_serial: Variant = dto.get("roll_token_generation_serial")
		if typeof(raw_serial) == TYPE_BOOL or not (typeof(raw_serial) in [TYPE_INT, TYPE_FLOAT]) or int(raw_serial) < 0:
			return "Character save has invalid roll_token_generation_serial."
	if not dto.has("roll_tokens"):
		return ""
	var raw_tokens: Variant = dto.get("roll_tokens")
	if not (raw_tokens is Dictionary):
		return "Character save roll_tokens must be a dictionary."
	var pools := pool_definitions_for_data(data, subclass, level)
	var seen_token_ids: Dictionary = {}
	for pool_key in raw_tokens:
		var pool_id := str(pool_key).strip_edges()
		if not pools.has(pool_id):
			return "Character save has unowned roll token pool '%s'." % pool_id
		var pool_def: Dictionary = pools[pool_id]
		var raw_list: Variant = raw_tokens[pool_key]
		if raw_list is Dictionary and raw_list.get("tokens") is Array:
			raw_list = raw_list["tokens"]
		if not (raw_list is Array):
			return "Character save roll_tokens['%s'] must be an array." % pool_id
		var capacity := int(pool_def.get("capacity", 0))
		if raw_list.size() > capacity:
			return "Character save roll_tokens['%s'] count %d exceeds capacity %d." % [pool_id, raw_list.size(), capacity]
		var die_sides := int(pool_def.get("die_sides", 20))
		var expected_feature_id := str(pool_def.get("feature_id", ""))
		for entry in raw_list:
			if not (entry is Dictionary):
				return "Character save roll token entry in '%s' must be an object." % pool_id
			var token_id := str(entry.get("token_id", entry.get("id", ""))).strip_edges()
			if token_id.is_empty():
				return "Character save roll token in '%s' is missing token_id." % pool_id
			if seen_token_ids.has(token_id):
				return "Character save has duplicate roll token_id '%s'." % token_id
			seen_token_ids[token_id] = true
			var entry_pool_id := str(entry.get("pool_id", pool_id)).strip_edges()
			if entry_pool_id != pool_id:
				return "Character save roll token '%s' pool_id '%s' does not match '%s'." % [token_id, entry_pool_id, pool_id]
			var entry_feature_id := str(entry.get("feature_id", entry.get("source_id", expected_feature_id))).strip_edges()
			if entry_feature_id != expected_feature_id:
				return "Character save roll token '%s' has unknown feature_id '%s'." % [token_id, entry_feature_id]
			var raw_val: Variant = entry.get("value")
			if typeof(raw_val) == TYPE_BOOL or not (typeof(raw_val) in [TYPE_INT, TYPE_FLOAT]):
				return "Character save roll token '%s' value must be an integer." % token_id
			var val := int(raw_val)
			if float(raw_val) != float(val) or val < 1 or val > die_sides:
				return "Character save roll token '%s' value %s is outside 1..%d." % [token_id, str(raw_val), die_sides]
			if entry.has("die_sides"):
				var raw_sides: Variant = entry.get("die_sides")
				if typeof(raw_sides) == TYPE_BOOL or not (typeof(raw_sides) in [TYPE_INT, TYPE_FLOAT]) or int(raw_sides) != die_sides:
					return "Character save roll token '%s' has invalid die_sides." % token_id
	return ""
