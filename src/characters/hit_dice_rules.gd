class_name HitDiceRules
extends RefCounted

const MIN_DIE_SIZE := 4
const MAX_DIE_SIZE := 20


static func class_hit_die_sides(class_id: String) -> int:
	var class_data := DataLoader.get_character_class(class_id)
	var raw_die := str(class_data.get("hit_die", ""))
	if not raw_die.begins_with("d") or not raw_die.substr(1).is_valid_int():
		return 0
	var sides := int(raw_die.substr(1))
	return sides if sides >= MIN_DIE_SIZE and sides <= MAX_DIE_SIZE else 0


static func add_class_level(character: Character, class_id: String) -> bool:
	if character == null or class_id.is_empty() or DataLoader.get_character_class(class_id).is_empty():
		return false
	var sides := class_hit_die_sides(class_id)
	if sides == 0:
		if not character.hit_dice_pools.has(class_id):
			character.hit_dice_pools[class_id] = {"class_id": class_id, "die_size": 0, "total": 0, "spent": 0, "untracked": 1}
			return true
		var unavailable_variant: Variant = character.hit_dice_pools[class_id]
		if not unavailable_variant is Dictionary:
			return false
		var unavailable_pool: Dictionary = unavailable_variant
		var unavailable_die_size: Variant = unavailable_pool.get("die_size", null)
		var unavailable_total: Variant = unavailable_pool.get("total", null)
		var unavailable_spent: Variant = unavailable_pool.get("spent", null)
		var unavailable_untracked: Variant = unavailable_pool.get("untracked", null)
		if str(unavailable_pool.get("class_id", "")) != class_id or not ResourcePoolRules._integer(unavailable_die_size, 0, 0) or not ResourcePoolRules._integer(unavailable_total, 0, 20) or not ResourcePoolRules._integer(unavailable_spent, 0, int(unavailable_total)) or not ResourcePoolRules._integer(unavailable_untracked, 0, 20) or int(unavailable_total) + int(unavailable_untracked) >= 20:
			return false
		unavailable_pool["untracked"] = int(unavailable_untracked) + 1
		character.hit_dice_pools[class_id] = unavailable_pool
		return true
	if not character.hit_dice_pools.has(class_id):
		character.hit_dice_pools[class_id] = {"class_id": class_id, "die_size": sides, "total": 0, "spent": 0, "untracked": 0}
	var pool: Dictionary = character.hit_dice_pools[class_id]
	if str(pool.get("class_id", "")) != class_id or int(pool.get("die_size", 0)) != sides or int(pool.get("total", 0)) + int(pool.get("untracked", 0)) >= 20:
		return false
	pool["total"] = int(pool.get("total", 0)) + 1
	character.hit_dice_pools[class_id] = pool
	return true


static func initialize_acquired_levels(character: Character) -> bool:
	if character == null or not character.hit_dice_pools.is_empty():
		return false
	var allocation: Dictionary = character.class_levels.duplicate(true)
	if not allocation.is_empty() and not Character.saved_class_levels_error({"class_levels": allocation, "class_id": character.class_id, "level": character.level}).is_empty():
		return false
	if allocation.is_empty() and not character.class_id.is_empty():
		if DataLoader.get_character_class(character.class_id).is_empty() or character.level < 1 or character.level > 20:
			return false
		allocation[character.class_id] = character.level
	for raw_class_id in allocation:
		var class_id := str(raw_class_id)
		var count := int(allocation[raw_class_id])
		for _level_index in count:
			if not add_class_level(character, class_id):
				character.hit_dice_pools.clear()
				return false
	return not allocation.is_empty()


static func legacy_untracked_pools(data: Dictionary) -> Dictionary:
	var allocation_variant: Variant = data.get("class_levels", {})
	if not allocation_variant is Dictionary:
		return {"_invalid": -1}
	var allocation: Dictionary = allocation_variant.duplicate(true)
	if allocation.is_empty():
		var primary_class_id: Variant = data.get("class_id", null)
		var character_level: Variant = data.get("level", null)
		if not primary_class_id is String or DataLoader.get_character_class(primary_class_id).is_empty() or not ResourcePoolRules._integer(character_level, 1, 20):
			return {"_invalid": -1}
		allocation[str(primary_class_id)] = int(character_level)
	if not Character.saved_class_levels_error(data).is_empty():
		return {"_invalid": -1}
	var pools: Dictionary = {}
	for class_id_variant in allocation:
		var class_id := str(class_id_variant)
		var sides := class_hit_die_sides(class_id)
		var count := int(allocation[class_id_variant])
		if count > 0:
			pools[class_id] = {"class_id": class_id, "die_size": sides, "total": 0, "spent": 0, "untracked": count}
	return pools


static func remaining_pool(character: Character, class_id: String) -> int:
	if character == null:
		return 0
	var pool_variant: Variant = character.hit_dice_pools.get(class_id, null)
	if not pool_variant is Dictionary:
		return 0
	var pool: Dictionary = pool_variant
	return maxi(0, int(pool.get("total", 0)) - int(pool.get("spent", 0)))


static func spend(character: Character, class_id: String) -> Dictionary:
	if character == null or character.is_dead() or character.current_hp <= 0:
		return {"success": false, "reason": "ineligible_actor"}
	if character.current_hp >= character.max_hp:
		return {"success": false, "reason": "already_at_max_hp"}
	var pool_variant: Variant = character.hit_dice_pools.get(class_id, null)
	if not pool_variant is Dictionary:
		return {"success": false, "reason": "no_such_class_pool"}
	var pool: Dictionary = pool_variant
	var sides := int(pool.get("die_size", 0))
	if sides < MIN_DIE_SIZE or sides > MAX_DIE_SIZE or str(pool.get("class_id", "")) != class_id or remaining_pool(character, class_id) <= 0 or sides != class_hit_die_sides(class_id):
		return {"success": false, "reason": "no_remaining_die"}
	var roll_details: Dictionary = Dice.roll_single_details(sides, character)
	var con_modifier := character.ability_scores.get_ability_modifier("CON")
	var healing := maxi(1, int(roll_details.get("total", 0)) + con_modifier)
	pool["spent"] = int(pool.get("spent", 0)) + 1
	character.hit_dice_pools[class_id] = pool
	var hp_before := character.current_hp
	character.heal(healing)
	return {"success": true, "class_id": class_id, "die_size": sides, "roll": int(roll_details.get("total", 0)), "constitution_modifier": con_modifier, "healing": mini(healing, character.current_hp - hp_before), "current_hp": character.current_hp, "roll_details": roll_details}


static func recover_long_rest(character: Character) -> int:
	if character == null or character.is_dead() or character.current_hp <= 0:
		return 0
	var recovered_count := 0
	for raw_class_id in character.hit_dice_pools:
		var class_id := str(raw_class_id)
		var pool_variant: Variant = character.hit_dice_pools[raw_class_id]
		if not pool_variant is Dictionary:
			continue
		var pool: Dictionary = pool_variant
		var pool_total: Variant = pool.get("total", null)
		var pool_spent: Variant = pool.get("spent", null)
		var pool_untracked: Variant = pool.get("untracked", null)
		var saved_die_size: Variant = pool.get("die_size", null)
		var sides := class_hit_die_sides(class_id)
		if str(pool.get("class_id", "")) != class_id or sides == 0 or not ResourcePoolRules._integer(saved_die_size, MIN_DIE_SIZE, MAX_DIE_SIZE) or int(saved_die_size) != sides:
			continue
		if not ResourcePoolRules._integer(pool_total, 0, 20) or not ResourcePoolRules._integer(pool_spent, 0, int(pool_total)) or not ResourcePoolRules._integer(pool_untracked, 0, 20) or int(pool_total) + int(pool_untracked) > 20:
			continue
		var untracked := int(pool_untracked)
		var spent := int(pool_spent)
		pool["total"] = int(pool_total) + untracked
		pool["untracked"] = 0
		pool["spent"] = 0
		recovered_count += untracked + spent
		character.hit_dice_pools[raw_class_id] = pool
	return recovered_count


static func saved_state_error(data: Dictionary) -> String:
	if not data.has("hit_dice_pools"):
		return ""
	var pools_variant: Variant = data.get("hit_dice_pools")
	if not pools_variant is Dictionary:
		return "Hit Dice pools are not an object."
	var allocation_variant: Variant = data.get("class_levels", {})
	if not allocation_variant is Dictionary:
		return "Hit Dice class allocation is not an object."
	var allocation: Dictionary = allocation_variant.duplicate(true)
	if allocation.is_empty():
		var primary_class_id: Variant = data.get("class_id", null)
		var character_level: Variant = data.get("level", null)
		if not primary_class_id is String or DataLoader.get_character_class(primary_class_id).is_empty() or not ResourcePoolRules._integer(character_level, 1, 20):
			return "Hit Dice fallback class allocation is invalid."
		allocation[str(primary_class_id)] = int(character_level)
	elif not Character.saved_class_levels_error(data).is_empty():
		return "Hit Dice class allocation is invalid."
	var pools: Dictionary = pools_variant
	if pools.size() != allocation.size():
		return "Hit Dice pools do not match acquired classes."
	var sum_total := 0
	for class_id_variant in allocation:
		var class_id := str(class_id_variant)
		var expected_count := int(allocation[class_id_variant])
		var pool_variant: Variant = pools.get(class_id, null)
		if pool_variant == null:
			if expected_count > 0:
				return "Hit Dice pool is missing an acquired class."
			continue
		if not pool_variant is Dictionary:
			return "Hit Dice pool entry is not an object."
		var pool: Dictionary = pool_variant
		var sides := class_hit_die_sides(class_id)
		var saved_die_size: Variant = pool.get("die_size", null)
		if pool.size() != 5 or str(pool.get("class_id", "")) != class_id:
			return "Hit Dice pool class identity or die size does not match loaded class data."
		if not ResourcePoolRules._integer(saved_die_size, 0, MAX_DIE_SIZE):
			return "Hit Dice pool die size must be a bounded integer."
		if int(saved_die_size) != sides:
			return "Hit Dice pool class identity or die size does not match loaded class data."
		if not ResourcePoolRules._integer(pool.get("total", null), 0, 20) or not ResourcePoolRules._integer(pool.get("untracked", null), 0, 20) or int(pool.total) + int(pool.untracked) != expected_count:
			return "Hit Dice pool total does not match acquired class levels."
		if not ResourcePoolRules._integer(pool.get("spent", null), 0, int(pool.get("total", 0))):
			return "Spent Hit Dice exceed the acquired pool."
		if sides == 0 and (int(pool.total) != 0 or int(pool.spent) != 0):
			return "Unavailable class Hit Dice must remain untracked."
		sum_total += expected_count
	if sum_total != int(data.get("level", -1)):
		return "Hit Dice pool totals do not match character level."
	return ""
