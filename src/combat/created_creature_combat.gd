## Encounter projections and orders; plain creature records remain authoritative.
class_name CreatedCreatureCombat
extends RefCounted

static func attach(state: CombatState) -> void:
	AnimatedObjectRules.reconcile()
	var room := LocalRoomCombat.room()
	if room.is_empty(): return
	for record in CreatedCreatureRules.room_records(room):
		if state.player_entities.any(func(entity): return entity.get("combat_id", "") == record["id"]): continue
		var position := LocalRoomRules.coord(record["position"])
		if not state.hex_grid.has_tile(position) or not state.hex_grid.is_hex_passable(position): continue
		if not CreatedCreatureRules.controlled(record):
			state.monster_entities.append(CreatedCreatureRules.monster(record))
			continue
		var owner_index := -1
		for entity in state.player_entities:
			if entity["character"].character_id == record["owner_id"]: owner_index = int(entity.get("owner_player_index", -1))
		var creature := CreatedCreatureRules.character(record)
		state.player_entities.append({"name": creature.character_name, "display_name": creature.character_name, "character": creature, "combat_id": creature.character_id, "owner_player_index": owner_index, "hex_position": position, "is_created_creature": true, "is_animated_object": record.get("source_spell") == "animate_objects", "reaction_available": true, "color": Color(0.4, 0.8, 0.55)})

## Flip the existing initiative record in place: expiry does not reroll or revive.
static func reconcile(state: CombatState) -> void:
	CreatedCreatureRules.settle(state.player_entities, state.monster_entities)
	AnimatedObjectRules.reconcile()
	var changed := false
	for entity in state.player_entities.duplicate():
		if not entity.get("is_created_creature", false): continue
		var creature: Character = entity["character"]
		var record := CreatedCreatureRules.get_record(creature.character_id)
		if entity.get("is_animated_object", false) and record.is_empty():
			state.player_entities.erase(entity)
			state.tracker.remove_combatant(creature.character_id)
			changed = true
			state.hud.add_log("%s reverts to its original object form." % creature.character_name)
			continue
		if record.is_empty() or CreatedCreatureRules.controlled(record) or creature.current_hp <= 0: continue
		var hostile := CreatedCreatureRules.monster(record)
		hostile["conditions"] = creature.conditions.duplicate(true)
		hostile["spell_effects"] = creature.spell_effects.duplicate(true)
		hostile["temp_hp"] = creature.temp_hp
		state.player_entities.erase(entity)
		state.monster_entities.append(hostile)
		changed = true
		for entry in state.tracker.combatants:
			if entry["entity"] is Character and entry["entity"] == creature:
				entry["is_player"] = false
				entry["entity"] = hostile
				entry["name"] = hostile["name"]
		record["order"] = "guard"
		record["order_target"] = ""
		state.hud.add_log("%s stops obeying; control expired, but the Undead still exists." % creature.character_name)
	if changed: state._update_grid_entities()

static func issue(state: CombatState, order: String, target_id: String = "", source_spell: String = "animate_dead") -> Dictionary:
	var owner: Character = state.active_character
	if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner) or not state.turn_budget.can_spend("bonus_action"): return {"success": false, "message": "A conscious owner and an unused Bonus Action are required."}
	var origin: Vector2i = state.player_entities[state.current_player_idx]["hex_position"]
	var records: Array[Dictionary] = []
	var reach := 100 if source_spell == "animate_objects" else 12
	for entity in state.player_entities:
		if not entity.get("is_created_creature", false): continue
		var record := CreatedCreatureRules.get_record(entity["character"].character_id)
		if record.get("source_spell") == source_spell and CreatedCreatureRules.controlled(record) and record["owner_id"] == owner.character_id and HexUtils.get_distance(origin, entity["hex_position"]) <= reach: records.append(record)
	if records.is_empty(): return {"success": false, "message": "No controlled creature of this spell is within %d feet; the Bonus Action is retained." % (reach * 5)}
	if order == "attack":
		var found := false
		for target in state.monster_entities:
			if target["id"] == target_id and target.get("is_alive", false): found = true
		if not found: return {"success": false, "message": "Choose a living enemy for this attack order."}
	elif order != "guard": return {"success": false, "message": "That order is not implemented."}
	for record in records:
		record["order"] = order
		record["order_target"] = target_id
	state._spend_action_cost("bonus_action")
	return {"success": true, "message": "%d controlled creatures receive the same %s order." % [records.size(), "attack" if order == "attack" else "Dodge"]}

static func take_turn(state: CombatState, entity: Dictionary) -> void:
	var creature: Character = entity["character"]
	var record := CreatedCreatureRules.get_record(creature.character_id)
	var target: Dictionary = {}
	if str(record.get("order", "guard")) == "attack":
		for candidate in state.monster_entities:
			if candidate["id"] == str(record.get("order_target", "")) and candidate.get("is_alive", false): target = candidate; break
	if target.is_empty():
		record["order"] = "guard"
		record["order_target"] = ""
		creature.add_condition("dodging", 2)
		state._spend_action_cost("action")
		state.hud.add_log("%s takes Dodge without an active attack order." % creature.character_name)
		return
	var origin: Vector2i = entity["hex_position"]
	var destination: Vector2i = target["hex_position"]
	var reach := 64 if record["form_id"] == "skeleton" else 1
	if HexUtils.get_distance(origin, destination) > reach or not Targeting.has_line_of_sight(origin, destination, state.hex_grid):
		var reachable: Dictionary = state._player_reachable(origin, float(creature.get_speed()), creature)
		var best := origin
		var distance := HexUtils.get_distance(origin, destination)
		for candidate in reachable:
			if state._is_occupied_hex(candidate): continue
			var candidate_distance := HexUtils.get_distance(candidate, destination)
			if candidate_distance < distance: best = candidate; distance = candidate_distance
		if best != origin:
			var path: Array[Vector2i] = state._player_path(origin, best, creature)
			await state._check_opportunity_attacks_for_path(creature, entity, path, false)
			origin = entity["hex_position"]
	if creature.is_alive and HexUtils.get_distance(origin, destination) <= reach and Targeting.has_line_of_sight(origin, destination, state.hex_grid):
		var distance := HexUtils.get_distance(origin, destination)
		var profile := CreatedCreatureRules.attack_profile(record, distance > 1)
		profile["attack_distance"] = distance
		var disadvantage := CombatAction.has_condition(target, "dodging") or not CombatPerception.can_see_target(creature, target, origin, destination, state.hex_grid) or distance > int(profile["range"])
		if "ranged" in profile["properties"]:
			for enemy in state.monster_entities:
				if enemy.get("is_alive", false) and HexUtils.get_distance(origin, enemy["hex_position"]) <= 1: disadvantage = true
		var advantage := not CombatPerception.can_see_target(target, creature, destination, origin, state.hex_grid)
		var result := CombatAction.resolve_weapon_attack(creature, target, profile, advantage, disadvantage)
		state._spend_action_cost("attack_action")
		state.hud.add_log(str(result.get("message", "%s attacks." % creature.character_name)))
		if int(target.get("current_hp", 0)) <= 0:
			target["is_alive"] = false
			state.tracker.remove_combatant(str(target["id"]))
			record["order"] = "guard"
			record["order_target"] = ""
	else:
		creature.add_condition("dodging", 2)
		state.hud.add_log("%s moves toward its ordered target and Dodges while out of reach." % creature.character_name)
	CreatedCreatureRules.settle(state.player_entities, state.monster_entities)
	state._update_grid_entities()

static func capture(state: CombatState) -> void:
	CreatedCreatureRules.settle(state.player_entities, state.monster_entities)
	for entity in state.player_entities:
		if not entity.get("is_created_creature", false): continue
		var record := CreatedCreatureRules.get_record(entity["character"].character_id)
		if record.is_empty(): continue
		record["order"] = "guard"
		record["order_target"] = ""
