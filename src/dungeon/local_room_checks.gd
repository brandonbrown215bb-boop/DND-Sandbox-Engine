## Production-record regressions for copy identity, object transactions and DTOs.
class_name LocalRoomChecks
extends RefCounted

static func run(check: Callable) -> void:
	WaveThreeChecks.run(check)
	FamiliarChecks.run(check)
	CorpseChecks.run(check)
	CreatedCreatureChecks.run(check)
	var fire_state := {
		"objects": [
			{"id": "fire_source", "kind": "loose", "name": "Burning logs", "position": [0, 0], "material": "wood", "hp": 20, "max_hp": 20, "flammable": true, "burning": true, "burning_next_tick_seconds": 6, "contents": []},
			{"id": "fire_near", "kind": "loose", "name": "Paper scraps", "position": [1, 0], "material": "paper", "hp": 20, "max_hp": 20, "flammable": true, "contents": []},
			{"id": "fire_closed", "kind": "container", "name": "Closed wooden box", "position": [0, 1], "material": "wood", "hp": 20, "max_hp": 20, "flammable": true, "open": false, "contents": []},
			{"id": "fire_far", "kind": "loose", "name": "Distant paper", "position": [3, 0], "material": "paper", "hp": 20, "max_hp": 20, "flammable": true, "contents": []},
		],
	}
	var fire_messages := LocalRoomRules.advance_burning_objects(fire_state, 6)
	check.call(bool(fire_state["objects"][1].get("burning", false)) and int(fire_state["objects"][1].get("burning_next_tick_seconds", 0)) == 12 and not bool(fire_state["objects"][2].get("burning", false)) and not bool(fire_state["objects"][3].get("burning", false)) and fire_messages.any(func(message): return message.contains("Paper scraps catches fire")), "Recurring room fire ignites exposed flammable objects within one hex, while closed containers and more distant objects stay safe")
	var pack_inventory := Inventory.new()
	check.call(pack_inventory.add_item("explorers_pack"), "An adventuring pack is carried as one inspectable copy before expansion")
	var pack_record: Dictionary = pack_inventory.backpack_instances()[0]
	var pack_instance_id := str(pack_record["instance_id"])
	var expanded_pack := pack_inventory.expand_pack_instance(pack_instance_id)
	check.call(expanded_pack.get("success", false) and pack_inventory.count_item("explorers_pack") == 0 and pack_inventory.count_item("rations") == 10 and pack_inventory.count_item("torch") == 10 and pack_inventory.count_item("oil_flask") == 2, "Expanding the Explorer's Pack creates its exact listed supplies once")
	var expanded_ids: Array[String] = []
	for record in pack_inventory.backpack_instances(): expanded_ids.append(str(record["instance_id"]))
	var pack_roundtrip := Inventory.new()
	pack_roundtrip.from_dict(pack_inventory.to_dict())
	var restored_ids: Array[String] = []
	for record in pack_roundtrip.backpack_instances(): restored_ids.append(str(record["instance_id"]))
	check.call(not pack_inventory.expand_pack_instance(pack_instance_id).get("success", false) and restored_ids == expanded_ids and pack_roundtrip.count_item("torch") == 10, "An expanded pack cannot be opened twice and its individual supplies survive save/load")
	var entertainer_pack := Inventory.new()
	entertainer_pack.add_item("entertainers_pack")
	var entertainer_id := str(entertainer_pack.backpack_instances()[0]["instance_id"])
	var entertainer_result := entertainer_pack.expand_pack_instance(entertainer_id)
	check.call(entertainer_result.get("success", false) and entertainer_pack.count_item("costume") == 3 and entertainer_pack.count_item("oil_flask") == 8 and entertainer_pack.count_item("rations") == 9, "Entertainer's Pack expands every listed copy")
	var priest_pack := Inventory.new()
	priest_pack.add_item("priests_pack")
	var priest_id := str(priest_pack.backpack_instances()[0]["instance_id"])
	var priest_result := priest_pack.expand_pack_instance(priest_id)
	check.call(priest_result.get("success", false) and priest_pack.count_item("holy_water") == 1 and priest_pack.count_item("rations") == 7 and priest_pack.count_item("robe") == 1, "Priest's Pack expands every listed copy")
	var component_inventory := Inventory.new()
	var mage_armor := DataLoader.get_spell("mage_armor")
	check.call(not component_inventory.has_required_spell_component(mage_armor, "wizard"), "A no-cost Material component cannot be replaced when the caster has no focus or pouch")
	component_inventory.add_item("arcane_wand")
	check.call(component_inventory.has_required_spell_component(mage_armor, "wizard") and not component_inventory.has_required_spell_component(mage_armor, "cleric"), "Arcane foci work for their classes and do not work for an incompatible class")
	component_inventory.add_item("wooden_staff")
	check.call(component_inventory.has_spellcasting_focus("druid") and component_inventory.has_spellcasting_focus("ranger"), "A carried Druidic Focus serves both Druid and Ranger spellcasting")
	component_inventory.add_item("longsword")
	component_inventory.add_item("shield")
	var component_records := component_inventory.backpack_instances()
	var weapon_instance := ""
	var shield_instance := ""
	for record in component_records:
		if record["definition_id"] == "longsword": weapon_instance = str(record["instance_id"])
		if record["definition_id"] == "shield": shield_instance = str(record["instance_id"])
	component_inventory.equip_instance(Inventory.Slot.WEAPON, weapon_instance)
	component_inventory.equip_instance(Inventory.Slot.SHIELD, shield_instance)
	check.call(component_inventory.available_spellcasting_hands() == 0 and not component_inventory.has_required_spell_component(mage_armor, "wizard"), "A weapon and shield leave no available hand for V/S/M casting")
	component_inventory.unequip(Inventory.Slot.SHIELD)
	check.call(component_inventory.available_spellcasting_hands() == 1 and component_inventory.has_required_spell_component(mage_armor, "wizard"), "Stowing the shield restores the free hand needed for spell components")
	var full_pack_inventory := Inventory.new()
	for _index in 16: full_pack_inventory.add_item("torch")
	full_pack_inventory.add_item("explorers_pack")
	var blocked_pack_id := str(full_pack_inventory.backpack_instances().back()["instance_id"])
	var refused_expansion := full_pack_inventory.expand_pack_instance(blocked_pack_id)
	check.call(not refused_expansion.get("success", false) and full_pack_inventory.get_instance(blocked_pack_id).get("definition_id", "") == "explorers_pack" and full_pack_inventory.count_item("torch") == 16, "Insufficient space refuses pack expansion without losing the bundle or changing contents")
	var torch_use_inventory := Inventory.new()
	torch_use_inventory.add_item("torch")
	var torch_instance_id := str(torch_use_inventory.backpack_instances()[0]["instance_id"])
	var torch_user := Character.new()
	torch_user.initialize("Torch user", "human", "fighter", AbilityScores.new())
	torch_user.inventory = torch_use_inventory
	var torch_use := torch_use_inventory.consume_instance(torch_instance_id, torch_user)
	var lit_torch := torch_use_inventory.get_instance(torch_instance_id)
	check.call(torch_use.get("success", false) and torch_use.get("consumed", true) == false and LightSourceRules.is_lit(lit_torch) and int(lit_torch.get("state", {}).get("light_source_remaining_seconds", 0)) == 3600, "Lighting a Torch keeps its exact inventory copy and stores its one-hour light-source state")
	var ration_user := Character.new()
	ration_user.initialize("Ration user", "human", "fighter", AbilityScores.new())
	var ration_inventory := Inventory.new()
	ration_inventory.add_item("rations")
	var ration_instance_id := str(ration_inventory.backpack_instances()[0]["instance_id"])
	var ration_result := ration_inventory.consume_instance(ration_instance_id, ration_user)
	check.call(ration_result.get("success", false) and ration_inventory.get_instance(ration_instance_id).is_empty() and ration_user.nourishment_until_seconds >= 86400, "A ration copy is consumed and stores one day of nourishment")
	var partial_ration_user := Character.new()
	partial_ration_user.initialize("Partial ration user", "human", "fighter", AbilityScores.new())
	partial_ration_user.character_id = "partial_ration_user"
	partial_ration_user.inventory.add_item("rations")
	var partial_ration_id := str(partial_ration_user.inventory.backpack_instances()[0]["instance_id"])
	var quarter_ration := partial_ration_user.inventory.consume_ration_portion(partial_ration_id, partial_ration_user, 0.25)
	var ration_copy_after_quarter := partial_ration_user.inventory.get_instance(partial_ration_id)
	var partial_ration_roundtrip := Character.new()
	partial_ration_roundtrip.from_dict(partial_ration_user.to_dict())
	check.call(quarter_ration.get("success", false) and is_equal_approx(partial_ration_user.food_eaten_today_pounds, 0.25) and is_equal_approx(float(ration_copy_after_quarter.get("state", {}).get("food_remaining_daily_fraction", 1.0)), 0.75) and InventoryCopies.saved_error(partial_ration_roundtrip.to_dict()["inventory"]).is_empty(), "A quarter-day inventory ration updates the eater's size-scaled food total and saves the remaining ration portion")
	partial_ration_roundtrip.inventory.consume_ration_portion(partial_ration_id, partial_ration_roundtrip, 0.5)
	partial_ration_roundtrip.inventory.consume_ration_portion(partial_ration_id, partial_ration_roundtrip, 1.0)
	check.call(partial_ration_roundtrip.inventory.get_instance(partial_ration_id).is_empty() and is_equal_approx(partial_ration_roundtrip.food_eaten_today_pounds, 1.0) and partial_ration_roundtrip.nourishment_until_seconds > 0, "Repeated partial ration portions consume one exact ration copy and meet the full daily need")

	var character := Character.new()
	character.initialize("Room checker", "human", "fighter", AbilityScores.new())
	character.character_id = "room_checker"
	character.inventory = Inventory.new()
	var definition: Dictionary = DataLoader.get_campaign("the_lost_crown")["dungeons"]["ruins_of_ashvale"]["tactical_rooms"]["1"]
	var spread_save_state := LocalRoomRules.create(definition, [character])
	var spread_source_position := LocalRoomRules.coord(spread_save_state["cells"].front())
	var spread_neighbor_position := spread_source_position
	var spread_far_position := spread_source_position
	for room_cell in spread_save_state["cells"]:
		var candidate_position := LocalRoomRules.coord(room_cell)
		if HexUtils.get_distance(spread_source_position, candidate_position) == 1:
			spread_neighbor_position = candidate_position
		if HexUtils.get_distance(spread_source_position, candidate_position) >= 3:
			spread_far_position = candidate_position
	var spread_source := {"id": "spread_source", "kind": "loose", "name": "Burning logs", "position": [spread_source_position.x, spread_source_position.y], "material": "wood", "hp": 20, "max_hp": 20, "flammable": true, "burning": true, "burning_next_tick_seconds": int(GameManager.campaign_elapsed_seconds), "contents": []}
	var spread_neighbor := {"id": "spread_neighbor", "kind": "loose", "name": "Paper scraps", "position": [spread_neighbor_position.x, spread_neighbor_position.y], "material": "paper", "hp": 20, "max_hp": 20, "flammable": true, "contents": []}
	var spread_closed := {"id": "spread_closed", "kind": "container", "name": "Closed wooden box", "position": [spread_neighbor_position.x, spread_neighbor_position.y], "material": "wood", "hp": 20, "max_hp": 20, "flammable": true, "open": false, "contents": []}
	var spread_distant := {"id": "spread_distant", "kind": "loose", "name": "Distant paper", "position": [spread_far_position.x, spread_far_position.y], "material": "paper", "hp": 20, "max_hp": 20, "flammable": true, "contents": []}
	spread_save_state["objects"] = [spread_source, spread_neighbor, spread_closed, spread_distant]
	var spread_save_messages := LocalRoomRules.advance_burning_objects(spread_save_state, int(GameManager.campaign_elapsed_seconds))
	var spread_save_snapshot: Dictionary = JSON.parse_string(JSON.stringify(spread_save_state))
	var saved_spread_object: Dictionary = spread_save_snapshot["objects"][1]
	check.call(spread_save_messages.any(func(message): return message.contains("Paper scraps catches fire")) and bool(saved_spread_object.get("burning", false)) and DungeonPersistence.local_error(spread_save_snapshot).is_empty(), "Fire spread marks the adjacent object in a validated room save with its ongoing burn state")
	var climber := Character.new()
	climber.initialize("Tool checker", "human", "fighter", AbilityScores.new())
	climber.inventory.add_item("rope")
	climber.inventory.add_item("climbers_kit")
	var climb_check := EventResolver.resolve_skill_check(climber, {"ability": "STR", "skill": "Athletics", "context": "climbing", "dc": 1})
	check.call(climb_check.get("tool_bonus", 0) == 2 and climber.inventory.skill_tool_bonus("Athletics", "unrelated") == 0, "Carried climbing supplies give their contextual bonus without stacking duplicates")
	var pry_character := Character.new()
	pry_character.initialize("Crowbar user", "human", "fighter", AbilityScores.new())
	pry_character.ability_scores.set_score("STR", 20)
	pry_character.character_id = "crowbar_user"
	pry_character.inventory.add_item("crowbar")
	var pry_state := LocalRoomRules.create(definition, [pry_character])
	pry_state["party_positions"][pry_character.character_id] = [-1, 0]
	LocalRoomRules.get_object(pry_state, "door")["lock_dc"] = 1
	var pry_result := LocalRoomRules.interact(pry_state, "door", "pry", pry_character)
	check.call(pry_result.get("success", false) and LocalRoomRules.get_object(pry_state, "door").get("open", false), "A carried crowbar supplies a playable pry action for locked room objects")
	var state := LocalRoomRules.create(definition, [character])
	check.call(DungeonPersistence.local_error(state).is_empty(), "Authored room validates with production geometry")
	var purifier := Character.new()
	purifier.initialize("Purifier", "human", "cleric", AbilityScores.new())
	purifier.character_id = "purifier_room_check"
	purifier.inventory.equipped.clear()
	purifier.known_spells.append("purify_food_and_drink")
	purifier.known_spells.append("create_or_destroy_water")
	purifier.inventory.add_item("component_pouch")
	purifier.spell_slots["1"] = 3
	state["party_positions"][purifier.character_id] = [1, 1]
	state["objects"].append({"id": "nearby_water", "kind": "loose", "name": "Contaminated water jar", "position": [3, 0], "contents": [], "food_or_drink": true, "water_gallons": 4, "capacity_gallons": 4, "contamination": ["disease"], "contamination_sources": ["sight_rot"]})
	state["objects"].append({"id": "magic_wine", "kind": "loose", "name": "Enchanted wine", "position": [4, 0], "contents": [], "food_or_drink": true, "magical": true, "contamination": ["poison"]})
	var resistant_drinker := Character.new()
	resistant_drinker.initialize("Resistant drinker", "human", "fighter", AbilityScores.new())
	resistant_drinker.character_id = "sight_rot_resistant"
	resistant_drinker.add_modifier("roll", "save:CON", 100, 100)
	state["party_positions"][resistant_drinker.character_id] = [3, 0]
	var resisted_exposure := LocalRoomRules.drink_water(state, "nearby_water", resistant_drinker, 1.0)
	check.call(resisted_exposure.get("success", false) and resisted_exposure.get("disease_exposure", {}).get("exposed", false) and not resisted_exposure.get("disease_exposure", {}).get("infected", true) and not resistant_drinker.has_condition("blinded"), "Drinking Sight Rot water uses its DC 15 Constitution save and a successful save prevents infection")
	var infected_drinker := Character.new()
	infected_drinker.initialize("Infected drinker", "human", "fighter", AbilityScores.new())
	infected_drinker.character_id = "sight_rot_infected"
	infected_drinker.add_condition("blinded", 4, "ordinary_blindness")
	infected_drinker.add_modifier("roll", "save:CON", -100, 100)
	state["party_positions"][infected_drinker.character_id] = [3, 0]
	var failed_exposure := LocalRoomRules.drink_water(state, "nearby_water", infected_drinker, 1.0)
	var contaminated_water_snapshot: Dictionary = JSON.parse_string(JSON.stringify(state))
	var infected_roundtrip := Character.new()
	infected_roundtrip.from_dict(infected_drinker.to_dict())
	infected_roundtrip.tick_conditions()
	check.call(failed_exposure.get("disease_exposure", {}).get("infected", false) and infected_drinker.condition_sources.get("blinded", {}).get("disease:sight_rot", 0) == -1 and infected_roundtrip.condition_sources.get("blinded", {}).get("disease:sight_rot", 0) == -1 and SpellEffects.saved_state_error(infected_roundtrip.to_dict()).is_empty() and infected_roundtrip.has_condition("blinded"), "Failed Sight Rot exposure adds a permanent source-owned Blinded condition that survives character save/load and turn ticks")
	check.call(DungeonPersistence.local_error(contaminated_water_snapshot).is_empty() and LocalRoomRules.get_object(contaminated_water_snapshot, "nearby_water").get("contamination_sources", []) == ["sight_rot"], "A named Sight Rot water source survives a validated room JSON snapshot")
	check.call(SpellEffectApplication.cure_sight_rot(infected_roundtrip) and infected_roundtrip.has_condition("blinded") and not infected_roundtrip.condition_sources.get("blinded", {}).has("disease:sight_rot"), "Ending Sight Rot removes only its blindness source and preserves unrelated blindness")
	var purify_time := LocalRoomRules.purify_food_and_drink(state, "cistern", purifier)
	check.call(purify_time.get("success", false) and purify_time.get("seconds", 0) == 6 and purifier.spell_slots["1"] == 2 and LocalRoomRules.get_object(state, "cistern")["contamination"].is_empty() and LocalRoomRules.get_object(state, "nearby_water")["contamination"].is_empty() and LocalRoomRules.get_object(state, "nearby_water").get("contamination_sources", []).is_empty(), "Purify Food and Drink spends one slot and clears poison, disease, and its source from nonmagical food and drink in its 5-foot sphere")
	var created_water := LocalRoomRules.create_or_destroy_water(state, "cistern", "create", purifier)
	check.call(created_water.get("success", false) and LocalRoomRules.get_object(state, "cistern").get("water_gallons", 0) == 20 and purifier.spell_slots["1"] == 1, "Create Water adds ten gallons to an open authored container")
	var destroyed_water := LocalRoomRules.create_or_destroy_water(state, "cistern", "destroy", purifier)
	check.call(destroyed_water.get("success", false) and LocalRoomRules.get_object(state, "cistern").get("water_gallons", 0) == 10 and purifier.spell_slots["1"] == 0, "Destroy Water removes up to ten gallons from the same container")
	purifier.spell_slots["1"] = 3
	var far_area := LocalRoomRules.create_or_destroy_water_area(state, "rain", Vector2i(999, 999), purifier, [purifier])
	check.call(not far_area.get("success", true) and purifier.spell_slots["1"] == 3, "Create or Destroy Water refuses an out-of-room area without spending a slot")
	state["party_positions"][purifier.character_id] = [1, 1]
	state["objects"].append({"id": "rain_flame", "kind": "loose", "name": "Exposed brazier", "position": [2, 1], "contents": [], "burning": true, "burning_next_tick_seconds": 900})
	state["objects"].append({"id": "covered_flame", "kind": "container", "name": "Closed lantern", "position": [2, 2], "contents": [], "open": false, "burning": true, "burning_next_tick_seconds": 900})
	purifier.inventory.add_item("torch")
	var rain_torch: Dictionary = purifier.inventory.backpack_instances().back().duplicate(true)
	var rain_torch_state: Dictionary = rain_torch.get("state", {}).duplicate(true)
	rain_torch_state["light_source_lit"] = true
	rain_torch["state"] = rain_torch_state
	purifier.inventory.update_instance(rain_torch)
	var rain_result := LocalRoomRules.create_or_destroy_water_area(state, "rain", Vector2i(1, 1), purifier, [purifier])
	check.call(rain_result.get("success", false) and not LocalRoomRules.get_object(state, "rain_flame").get("burning", true) and LocalRoomRules.get_object(state, "covered_flame").get("burning", false) and not LightSourceRules.is_lit(purifier.inventory.get_instance(str(rain_torch["instance_id"]))) and purifier.spell_slots["1"] == 2, "Create Water rain extinguishes exposed room flames and carried Torches while leaving a closed container burning")
	var fog_effect := SpellEffects.begin_cast(purifier, DataLoader.get_spell("fog_cloud"))
	var fog_source := "fog_cloud:%s:water_clear_test" % purifier.character_id
	purifier.spell_effects[fog_effect["source_id"]] = fog_effect.duplicate(true)
	purifier.concentrating_on = {"spell_id": "fog_cloud", "fog_cloud_source_id": fog_source, "effect_source": str(fog_effect["source_id"]), "targets": [purifier]}
	var fog_add := LocalRoomAreas.add(state, "fog_cloud", purifier.character_id, Vector2i.ZERO, 4, 600, 1, {"concentration_source_id": fog_source, "heavily_obscured": true, "footprint": [[0, 0], [4, 0]]})
	var partial_fog_clear := LocalRoomRules.create_or_destroy_water_area(state, "clear_fog", Vector2i.ZERO, purifier, [purifier])
	var fog_area: Dictionary = state["areas"].filter(func(area): return str(area.get("spell_id", "")) == "fog_cloud").front() if state["areas"].any(func(area): return str(area.get("spell_id", "")) == "fog_cloud") else {}
	check.call(fog_add.get("success", false) and partial_fog_clear.get("success", false) and fog_area.get("footprint", []) == [[4, 0]] and not purifier.concentrating_on.is_empty() and DungeonPersistence.local_error(state).is_empty(), "Destroy Water removes only overlapping Fog Cloud cells and saves its remaining footprint")
	var full_fog_clear := LocalRoomRules.create_or_destroy_water_area(state, "clear_fog", Vector2i(4, 0), purifier, [purifier])
	check.call(full_fog_clear.get("success", false) and not state["areas"].any(func(area): return str(area.get("spell_id", "")) == "fog_cloud") and purifier.concentrating_on.is_empty() and purifier.spell_slots["1"] == 0, "Destroy Water removes the remaining Fog Cloud cells and ends that spell's Concentration")
	var daggers_target := Character.new()
	daggers_target.initialize("Daggers target", "human", "fighter", AbilityScores.new())
	daggers_target.character_id = "daggers_room_target"
	var daggers_state := LocalRoomRules.create(definition, [daggers_target])
	var daggers_position := LocalRoomRules.coord(daggers_state["party_positions"][daggers_target.character_id])
	var daggers_source := "cloud_of_daggers:%s:room_transfer" % daggers_target.character_id
	var daggers_added := LocalRoomAreas.add(daggers_state, "cloud_of_daggers", daggers_target.character_id, daggers_position, 0, 60, 100, {"concentration_source_id": daggers_source, "footprint": [[daggers_position.x, daggers_position.y]], "slot_level": 2, "damage_formula": "4d4"})
	var daggers_hp_before := daggers_target.current_hp
	var daggers_entered := LocalRoomAreas.enter(daggers_state, daggers_target.character_id, daggers_position + Vector2i(1, 0), daggers_position, int(GameManager.campaign_elapsed_seconds))
	var daggers_entry := LocalRoomRules.resolve_area_entries(daggers_entered, daggers_target)
	var daggers_end_turn := LocalRoomRules.end_turn_area_saves(daggers_state, daggers_target)
	check.call(daggers_added.get("success", false) and daggers_entry.size() == 1 and daggers_entry[0].get("spell_id", "") == "cloud_of_daggers" and daggers_target.current_hp < daggers_hp_before and daggers_end_turn.is_empty() and DungeonPersistence.local_error(daggers_state).is_empty(), "A saved Cloud of Daggers footprint deals its upcast-aware entry damage once per six-second local turn and validates")
	var spike_target := Character.new()
	spike_target.initialize("Spike Growth target", "human", "fighter", AbilityScores.new())
	spike_target.character_id = "spike_growth_room_target"
	var spike_state := LocalRoomRules.create(definition, [spike_target])
	spike_state["party_positions"][spike_target.character_id] = [-1, 0]
	var spike_source := "spike_growth:%s:room_transfer" % spike_target.character_id
	var spike_added := LocalRoomAreas.add(spike_state, "spike_growth", spike_target.character_id, Vector2i.ZERO, 4, 600, 100, {"concentration_source_id": spike_source, "footprint": [[0, 0], [1, 0]], "slot_level": 2, "damage_formula": "2d4", "difficult_terrain": true, "requires_concentration": true})
	var spike_grid := HexGrid.new()
	for spike_coord in [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]:
		var spike_tile := HexTile.new()
		spike_tile.coord = spike_coord
		spike_tile.terrain = HexTile.TerrainType.ROAD
		spike_tile.is_revealed = true
		spike_tile.is_visible = true
		spike_grid.add_tile(spike_tile)
	var spike_hp_before := spike_target.current_hp
	var spike_move := LocalRoomRules.move(spike_state, spike_target, Vector2i(1, 0), spike_grid)
	check.call(spike_added.get("success", false) and spike_move.get("success", false) and int(spike_move.get("movement_cost_feet", 0)) == 20 and spike_move.get("spike_growth_outcomes", []).size() == 2 and spike_target.current_hp < spike_hp_before and DungeonPersistence.local_error(spike_state).is_empty(), "Spike Growth saves its footprint, doubles movement cost and deals 2d4 Piercing damage for each five-foot step through it")
	spike_grid.free()
	var entangle_target := Character.new()
	entangle_target.initialize("Entangled target", "human", "fighter", AbilityScores.new())
	entangle_target.character_id = "entangle_room_target"
	entangle_target.ability_scores.set_score("STR", 20)
	var entangle_state := LocalRoomRules.create(definition, [entangle_target])
	var entangle_position := LocalRoomRules.coord(entangle_state["party_positions"][entangle_target.character_id])
	var entangle_source := "entangle:%s:room_transfer" % entangle_target.character_id
	var entangle_added := LocalRoomAreas.add(entangle_state, "entangle", entangle_target.character_id, entangle_position, 0, 60, 1, {"concentration_source_id": entangle_source, "footprint": [[entangle_position.x, entangle_position.y]], "save_dc": 1, "difficult_terrain": true, "requires_concentration": true})
	CombatAction.apply_condition(entangle_target, "restrained", 99, entangle_source)
	var entangle_grid := HexGrid.new()
	var entangle_move := LocalRoomRules.move(entangle_state, entangle_target, entangle_position + Vector2i(1, 0), entangle_grid)
	var entangle_escape := LocalRoomRules.escape_entangle(entangle_state, entangle_target)
	check.call(entangle_added.get("success", false) and not entangle_move.get("success", true) and entangle_escape.get("success", false) and entangle_target.condition_sources.get("restrained", {}).is_empty() and DungeonPersistence.local_error(entangle_state).is_empty(), "A saved Entangle area restricts movement and offers a source-specific Strength (Athletics) escape")
	entangle_grid.free()
	var storm_target := Character.new()
	storm_target.initialize("Sleet Storm target", "human", "fighter", AbilityScores.new())
	storm_target.character_id = "sleet_storm_room_target"
	var storm_state := LocalRoomRules.create(definition, [storm_target])
	var storm_position := LocalRoomRules.coord(storm_state["party_positions"][storm_target.character_id])
	var storm_source := "sleet_storm:%s:room_test" % storm_target.character_id
	var storm_added := LocalRoomAreas.add(storm_state, "sleet_storm", storm_target.character_id, storm_position, 0, 600, 100, {"concentration_source_id": storm_source, "footprint": [[storm_position.x, storm_position.y]], "save_dc": 100, "height_feet": 40, "difficult_terrain": true, "requires_concentration": true, "heavily_obscured": true, "douses_exposed_flames": true})
	var storm_outside := storm_position + Vector2i(-1, 0)
	var storm_entered := LocalRoomAreas.enter(storm_state, storm_target.character_id, storm_outside, storm_position, int(GameManager.campaign_elapsed_seconds))
	var storm_entry := LocalRoomRules.resolve_area_entries(storm_entered, storm_target)
	storm_state["party_positions"][storm_target.character_id] = [storm_position.x, storm_position.y]
	var storm_end_turn := LocalRoomRules.end_turn_area_saves(storm_state, storm_target)
	var duplicate_storm_end_turn := LocalRoomRules.end_turn_area_saves(storm_state, storm_target)
	check.call(storm_added.get("success", false) and storm_entry.size() == 1 and storm_entry[0].get("spell_id", "") == "sleet_storm" and not bool(storm_entry[0].get("saved", true)) and storm_target.has_condition("prone") and storm_end_turn.is_empty() and duplicate_storm_end_turn.is_empty() and DungeonPersistence.local_error(storm_state).is_empty(), "Sleet Storm saves on entry, applies Prone on a failed Dexterity save, and suppresses a duplicate start/end-of-turn save in the same six-second turn")
	var moonbeam_target := Character.new()
	moonbeam_target.initialize("Moonbeam target", "human", "fighter", AbilityScores.new())
	moonbeam_target.character_id = "moonbeam_room_target"
	var moonbeam_state := LocalRoomRules.create(definition, [moonbeam_target])
	var moonbeam_position := LocalRoomRules.coord(moonbeam_state["party_positions"][moonbeam_target.character_id])
	var moonbeam_source := "moonbeam:%s:room_test" % moonbeam_target.character_id
	var moonbeam_added := LocalRoomAreas.add(moonbeam_state, "moonbeam", moonbeam_target.character_id, moonbeam_position, 0, 600, 100, {"concentration_source_id": moonbeam_source, "footprint": [[moonbeam_position.x, moonbeam_position.y]], "save_dc": 100, "slot_level": 4, "damage_formula": "4d10", "height_feet": 40, "dim_light": true, "requires_concentration": true})
	var moonbeam_outside := moonbeam_position + Vector2i(-1, 0)
	var moonbeam_entered := LocalRoomAreas.enter(moonbeam_state, moonbeam_target.character_id, moonbeam_outside, moonbeam_position, int(GameManager.campaign_elapsed_seconds))
	var moonbeam_hp_before := moonbeam_target.current_hp
	var moonbeam_entry := LocalRoomRules.resolve_area_entries(moonbeam_entered, moonbeam_target)
	moonbeam_state["party_positions"][moonbeam_target.character_id] = [moonbeam_position.x, moonbeam_position.y]
	var moonbeam_end_turn := LocalRoomRules.end_turn_area_saves(moonbeam_state, moonbeam_target)
	check.call(moonbeam_added.get("success", false) and moonbeam_entry.size() == 1 and moonbeam_entry[0].get("spell_id", "") == "moonbeam" and not bool(moonbeam_entry[0].get("saved", true)) and int(moonbeam_entry[0].get("damage", 0)) >= 4 and int(moonbeam_entry[0].get("damage", 0)) <= 40 and moonbeam_target.current_hp < moonbeam_hp_before and moonbeam_end_turn.is_empty() and DungeonPersistence.local_error(moonbeam_state).is_empty(), "A room-owned Moonbeam deals its slot-scaled Radiant damage on a failed entry save, records its one-save-per-turn limit, and validates")
	var moonbeam_lock_source := "%s:shape_lock" % moonbeam_source
	CombatAction.apply_condition(moonbeam_target, "moonbeam_shape_lock", 99, moonbeam_lock_source)
	LocalRoomAreas.leave(moonbeam_state, moonbeam_target, moonbeam_position, moonbeam_outside)
	check.call(not moonbeam_target.condition_sources.get("moonbeam_shape_lock", {}).has(moonbeam_lock_source), "Leaving the room-owned Moonbeam removes only that area's source-owned shape-shift lock")
	var wall_target := Character.new()
	wall_target.initialize("Wall of Fire target", "human", "fighter", AbilityScores.new())
	wall_target.character_id = "wall_of_fire_room_target"
	wall_target.max_hp = 100
	wall_target.current_hp = 100
	wall_target.add_modifier("roll", "save:DEX", 1000, 100)
	var wall_state := LocalRoomRules.create(definition, [wall_target])
	var wall_fire_position := LocalRoomRules.coord(wall_state["party_positions"][wall_target.character_id])
	var wall_source := "wall_of_fire:%s:room_test" % wall_target.character_id
	var wall_neighbor := wall_fire_position + Vector2i(1, 0)
	var wall_added := LocalRoomAreas.add(wall_state, "wall_of_fire", wall_target.character_id, wall_fire_position, 0, 60, 100, {"concentration_source_id": wall_source, "footprint": [[wall_fire_position.x, wall_fire_position.y]], "dangerous_footprint": [[wall_fire_position.x, wall_fire_position.y], [wall_neighbor.x, wall_neighbor.y]], "save_dc": 100, "slot_level": 4, "damage_formula": "5d8", "requires_concentration": true})
	var hot_side_entry := LocalRoomAreas.enter(wall_state, wall_target.character_id, wall_neighbor + Vector2i(1, 0), wall_neighbor, int(GameManager.campaign_elapsed_seconds))
	var wall_entered := LocalRoomAreas.enter(wall_state, wall_target.character_id, wall_neighbor, wall_fire_position, int(GameManager.campaign_elapsed_seconds))
	var wall_hp_before := wall_target.current_hp
	var wall_entry := LocalRoomRules.resolve_area_entries(wall_entered, wall_target)
	var wall_end_turn := LocalRoomRules.end_turn_area_saves(wall_state, wall_target)
	var repeated_wall_entry := LocalRoomAreas.enter(wall_state, wall_target.character_id, wall_neighbor, wall_fire_position, int(GameManager.campaign_elapsed_seconds))
	var repeated_wall_end := LocalRoomRules.end_turn_area_saves(wall_state, wall_target)
	check.call(wall_added.get("success", false) and hot_side_entry.is_empty() and wall_entry.size() == 1 and not wall_entry[0].has("saved") and int(wall_entry[0].get("damage", 0)) >= 5 and wall_target.current_hp < wall_hp_before and wall_end_turn.size() == 1 and repeated_wall_entry.is_empty() and repeated_wall_end.is_empty() and DungeonPersistence.local_error(JSON.parse_string(JSON.stringify(wall_state))).is_empty(), "A transferred Wall of Fire damages on wall entry and separately at turn end without a save, ignores hot-side-only entry, and saves independent trigger caps through JSON")
	purifier.known_spells.append("prestidigitation")
	var cleaned_bowl := LocalRoomRules.prestidigitation(state, "offering_bowl", "clean", purifier)
	var warmed_bowl := LocalRoomRules.prestidigitation(state, "offering_bowl", "warm", purifier)
	var bowl := LocalRoomRules.get_object(state, "offering_bowl")
	check.call(cleaned_bowl.get("success", false) and not bowl.get("dirty", true) and warmed_bowl.get("success", false) and bowl.get("temperature_effect", {}).get("mode", "") == "warm", "Prestidigitation cleans a Tiny authored object and warms it for one hour")
	var oversized_clean := LocalRoomRules.prestidigitation(state, "cistern", "clean", purifier)
	check.call(not oversized_clean.get("success", true) and purifier.spell_slots["1"] == 0, "Prestidigitation refuses cleaning an object larger than one cubic foot")
	check.call(LocalRoomRules.get_object(state, "magic_wine")["contamination"] == ["poison"], "Purify Food and Drink leaves magical food and drink unchanged")
	state["party_positions"][purifier.character_id] = [3, 0]
	var eaten_half_food := LocalRoomRules.eat_food(state, "food_basket", purifier, 0.5)
	var eaten_food := LocalRoomRules.eat_food(state, "food_basket", purifier, 0.5)
	var drunk_water := LocalRoomRules.drink_water(state, "cistern", purifier)
	check.call(eaten_half_food.get("success", false) and eaten_food.get("success", false) and is_equal_approx(float(LocalRoomRules.get_object(state, "food_basket").get("food_servings", 0)), 2.0) and is_equal_approx(purifier.food_eaten_today_pounds, 1.0) and purifier.nourishment_until_seconds > 0, "Two half-pound room portions combine into a full daily food amount")
	check.call(drunk_water.get("success", false) and LocalRoomRules.get_object(state, "cistern").get("water_gallons", 0) == 9 and purifier.hydration_until_seconds > 0, "Drinking a gallon reduces the water supply and records one day of hydration")
	var berry_eater := Character.new()
	berry_eater.initialize("Berry eater", "human", "druid", AbilityScores.new())
	berry_eater.spell_effects["goodberry_test"] = {"spell_id": "goodberry", "conditions": [], "concentration": false, "remaining_seconds": 86400, "berries_remaining": 1}
	var berry_result := LocalRoomRules.eat_goodberry([berry_eater], berry_eater)
	check.call(berry_result.get("success", false) and SpellEffects.goodberry_count(berry_eater) == 0 and berry_eater.nourishment_until_seconds > 0 and berry_result.get("seconds", 0) == 6, "Eating a Goodberry consumes one saved berry, heals, and records one day of nourishment")
	var character_roundtrip := Character.new()
	character_roundtrip.from_dict(purifier.to_dict())
	check.call(character_roundtrip.nourishment_until_seconds == purifier.nourishment_until_seconds and character_roundtrip.hydration_until_seconds == purifier.hydration_until_seconds and is_equal_approx(character_roundtrip.food_eaten_today_pounds, purifier.food_eaten_today_pounds) and is_equal_approx(character_roundtrip.water_drank_today_gallons, purifier.water_drank_today_gallons), "Nourishment deadlines and current-day food/water totals survive character save data")
	var malformed_survival_state := purifier.to_dict()
	malformed_survival_state["food_eaten_today_pounds"] = -0.25
	check.call(not SurvivalRules.saved_state_error(malformed_survival_state).is_empty(), "Character save validation rejects negative partial food intake")
	check.call(is_equal_approx(SurvivalRules.food_need_for_size("Tiny"), 0.25) and is_equal_approx(SurvivalRules.food_need_for_size("Large"), 4.0) and is_equal_approx(SurvivalRules.food_need_for_size("Gargantuan"), 64.0) and is_equal_approx(SurvivalRules.water_need_for_size("Tiny"), 0.25) and is_equal_approx(SurvivalRules.water_need_for_size("Huge"), 16.0), "Daily food and water needs follow the SRD creature-size table")
	var starving_character := Character.new()
	starving_character.initialize("Starving character", "human", "fighter", AbilityScores.new())
	starving_character.hydration_until_seconds = 5 * 86400
	for day in range(1, 5): SurvivalRules.settle_day(starving_character, day * 86400)
	check.call(starving_character.exhaustion_level == 0 and starving_character.days_without_food == 4, "Malnutrition does not cause exhaustion before five full days without food")
	SurvivalRules.settle_day(starving_character, 5 * 86400)
	check.call(starving_character.exhaustion_level == 1 and "malnutrition" in starving_character.exhaustion_recovery_blockers, "Five days without food add one persistent Exhaustion level and block Long Rest recovery")
	starving_character.add_nourishment()
	starving_character.long_rest()
	check.call(starving_character.exhaustion_level == 0 and starving_character.days_without_food == 0, "A full food portion unlocks recovery and a Long Rest removes one Exhaustion level")
	var dehydrated_character := Character.new()
	dehydrated_character.initialize("Dehydrated character", "human", "fighter", AbilityScores.new())
	dehydrated_character.nourishment_until_seconds = 86400
	dehydrated_character.hydration_until_seconds = 86400
	SurvivalRules.settle_day(dehydrated_character, 86400)
	check.call(dehydrated_character.exhaustion_level == 0, "A full food and water portion covers its saved campaign day")
	SurvivalRules.settle_day(dehydrated_character, 2 * 86400)
	check.call(dehydrated_character.exhaustion_level == 1 and "dehydration" in dehydrated_character.exhaustion_recovery_blockers, "A missed water day causes one Exhaustion level and blocks recovery")
	var exhaustion_saved := Character.new()
	exhaustion_saved.from_dict(dehydrated_character.to_dict())
	check.call(exhaustion_saved.exhaustion_level == 1 and exhaustion_saved.conditions.get("exhaustion", 0) == 1 and "dehydration" in exhaustion_saved.exhaustion_recovery_blockers, "Exhaustion level and its food/water recovery lock survive character save data")
	dehydrated_character.add_hydration()
	dehydrated_character.long_rest()
	check.call(dehydrated_character.exhaustion_level == 0 and dehydrated_character.get_speed() == dehydrated_character.speed, "A full water portion unlocks Long Rest removal and restores movement")
	var partial_character := Character.new()
	partial_character.initialize("Partial eater", "human", "wizard", AbilityScores.new())
	partial_character.ability_scores.set_score("CON", 1)
	partial_character.hydration_until_seconds = 86400
	partial_character.food_eaten_today_pounds = 0.125
	var failure_seed := 1
	for candidate_seed in range(1, 100):
		seed(candidate_seed)
		if not bool(partial_character.saving_throw_test_to_dc("CON", 10).get("success", false)):
			failure_seed = candidate_seed
			break
	seed(failure_seed)
	SurvivalRules.settle_day(partial_character, 86400)
	check.call(partial_character.exhaustion_level == 1 and "malnutrition" in partial_character.exhaustion_recovery_blockers and partial_character.days_without_food == 0, "Eating less than half a day's food makes the DC 10 Constitution save at day end")
	var half_portion_character := Character.new()
	half_portion_character.initialize("Half portion", "human", "wizard", AbilityScores.new())
	half_portion_character.food_eaten_today_pounds = 0.5
	half_portion_character.water_drank_today_gallons = 0.5
	SurvivalRules.settle_day(half_portion_character, 86400)
	check.call(half_portion_character.exhaustion_level == 0 and half_portion_character.days_without_food == 0, "Exactly half the daily food and water needs avoids the under-half hazards")
	var low_water_character := Character.new()
	low_water_character.initialize("Low water", "human", "wizard", AbilityScores.new())
	low_water_character.nourishment_until_seconds = 86400
	low_water_character.water_drank_today_gallons = 0.25
	SurvivalRules.settle_day(low_water_character, 86400)
	check.call(low_water_character.exhaustion_level == 1 and "dehydration" in low_water_character.exhaustion_recovery_blockers, "Drinking less than half the daily water need causes one Exhaustion level without a save")
	var alarm_caster := Character.new()
	alarm_caster.initialize("Alarm caster", "human", "wizard", AbilityScores.new())
	alarm_caster.character_id = "alarm_caster"
	alarm_caster.known_spells.append("alarm")
	alarm_caster.spell_slots["1"] = 1
	alarm_caster.inventory.add_item("component_pouch")
	var alarm_ally := Character.new()
	alarm_ally.initialize("Alarm ally", "human", "fighter", AbilityScores.new())
	alarm_ally.character_id = "alarm_ally"
	var alarm_party: Array = [alarm_caster, alarm_ally]
	var alarm_state := LocalRoomRules.create(definition, alarm_party)
	alarm_state["party_positions"][alarm_caster.character_id] = [-1, 0]
	var alarm_door := LocalRoomRules.get_object(alarm_state, "door")
	alarm_door["locked"] = false
	alarm_door["open"] = false
	var alarm_cast := LocalRoomRules.cast_alarm(alarm_state, "door", "mental", alarm_caster, alarm_party)
	var ignored_ally_entry := LocalRoomAreas.enter(alarm_state, alarm_ally.character_id, Vector2i(-1, 0), Vector2i.ZERO, int(GameManager.campaign_elapsed_seconds))
	var intruder := Character.new()
	intruder.initialize("Intruder", "human", "fighter", AbilityScores.new())
	intruder.character_id = "intruder"
	alarm_state["party_positions"][intruder.character_id] = [0, 1]
	var alarm_crossing := LocalRoomAreas.enter(alarm_state, intruder.character_id, Vector2i(-3, 0), Vector2i(-2, 0), int(GameManager.campaign_elapsed_seconds))
	alarm_door["locked"] = true
	var failed_intruder_open := LocalRoomRules.interact(alarm_state, "door", "open", intruder)
	alarm_door["locked"] = false
	var intruder_open := LocalRoomRules.interact(alarm_state, "door", "open", intruder)
	var alarm_saved: Dictionary = JSON.parse_string(JSON.stringify(alarm_state))
	check.call(alarm_cast.get("success", false) and alarm_cast.get("seconds", 0) == 60 and alarm_caster.spell_slots["1"] == 0 and ignored_ally_entry.is_empty() and alarm_crossing.size() == 1 and LocalRoomRules._alarm_alert_text(alarm_crossing).contains("within 1 mile") and LocalRoomRules._alarm_alert_text(alarm_crossing).contains("wake them if asleep") and int(alarm_crossing[0].get("mental_range_feet", 0)) == 5280 and bool(alarm_crossing[0].get("mental_wakes_if_asleep", false)) and not failed_intruder_open.get("success", true) and failed_intruder_open.get("message", "").contains("within 1 mile") and intruder_open.get("message", "").contains("within 1 mile") and DungeonPersistence.local_error(alarm_saved).is_empty(), "Mental Alarm pings the caster within one mile, can wake them if asleep, excludes the party, and alerts on entry or door touch")
	var prior_transition_context: Dictionary = GameManager.transition_context
	GameManager.transition_context = {"local_room": alarm_state}
	var combat_alarm_crossing := LocalRoomCombat.enter_room_areas({"id": "monster_alarm_test"}, Vector2i(-3, 1), Vector2i(-2, 1))
	GameManager.transition_context = prior_transition_context
	check.call(combat_alarm_crossing.size() == 1 and LocalRoomRules._alarm_alert_text(combat_alarm_crossing).contains("within 1 mile") and int(alarm_state["areas"][0]["triggered_by"].get("monster_alarm_test", 0)) == 1 and DungeonPersistence.local_error(alarm_state).is_empty(), "A room-owned Alarm also delivers its mental ping on combat movement and keeps its per-creature trigger ledger in the saved room")
	var ritual_caster := Character.new()
	ritual_caster.initialize("Ritual caster", "human", "wizard", AbilityScores.new())
	ritual_caster.character_id = "ritual_caster"
	ritual_caster.known_spells.append("alarm")
	ritual_caster.inventory.add_item("component_pouch")
	var ritual_state := LocalRoomRules.create(definition, [ritual_caster])
	ritual_state["party_positions"][ritual_caster.character_id] = [-1, 0]
	var ritual_slots_before := int(ritual_caster.spell_slots.get("1", 0))
	var ritual_alarm := LocalRoomRules.cast_alarm(ritual_state, "door", "audible", ritual_caster, [ritual_caster], true)
	check.call(ritual_alarm.get("success", false) and ritual_alarm.get("seconds", 0) == 660 and int(ritual_caster.spell_slots.get("1", 0)) == ritual_slots_before and bool(ritual_state["areas"][0].get("mental_wakes_if_asleep", false)), "Alarm's ritual option takes eleven minutes, stores its mental delivery rule, and does not spend a spell slot")
	var previous_game_state: int = GameManager.current_state
	GameManager.current_state = GameManager.GameState.COMBAT
	var alarm_combat_support := SpellSupport.availability(DataLoader.get_spell("alarm"))
	GameManager.current_state = previous_game_state
	check.call(not alarm_combat_support.get("available", true), "Alarm stays unavailable to the encounter spell pipeline")
	var area_walker := Character.new()
	area_walker.initialize("Area walker", "human", "fighter", AbilityScores.new())
	area_walker.character_id = "area_walker"
	area_walker.set_movement_speed_feet("climb", 20)
	area_walker.set_movement_speed_feet("swim", 15)
	var movement_roundtrip := Character.new()
	movement_roundtrip.from_dict(area_walker.to_dict())
	check.call(movement_roundtrip.movement_speed_feet("walk") == area_walker.movement_speed_feet("walk") and movement_roundtrip.movement_speed_feet("climb") == 20 and movement_roundtrip.movement_speed_feet("swim") == 15, "Declared climb and swim speeds survive character save data alongside ordinary walking speed")
	var area_state := LocalRoomRules.create(definition, [area_walker])
	area_state["party_positions"][area_walker.character_id] = [-2, 0]
	var area_added := LocalRoomAreas.add(area_state, "area_test", "area_walker", Vector2i(-1, 0), 0, 3600, 1)
	var area_grid := HexGrid.new()
	for cell in area_state.get("cells", []):
		var area_tile := HexTile.new()
		area_tile.coord = LocalRoomRules.coord(cell)
		area_tile.custom_properties["blocks_movement"] = not LocalRoomRules.passable(area_state, area_tile.coord)
		area_grid.add_tile(area_tile)
	var first_area_entry := LocalRoomRules.move(area_state, area_walker, Vector2i(-1, 0), area_grid)
	var area_snapshot: Dictionary = JSON.parse_string(JSON.stringify(area_state))
	check.call(area_added.get("success", false) and first_area_entry.get("entered_areas", []).size() == 1 and DungeonPersistence.local_error(area_snapshot).is_empty(), "A room area records a boundary crossing and its trigger cap survives validated room saving")
	LocalRoomRules.move(area_state, area_walker, Vector2i(-2, 0), area_grid)
	var repeat_area_entry := LocalRoomRules.move(area_state, area_walker, Vector2i(-1, 0), area_grid)
	check.call(repeat_area_entry.get("entered_areas", []).is_empty(), "A persisted room-area trigger cap prevents repeated activation by the same character")
	var tentacle_victim := Character.new()
	tentacle_victim.initialize("Tentacle victim", "human", "fighter", AbilityScores.new())
	tentacle_victim.character_id = "tentacle_victim"
	tentacle_victim.max_hp = 100
	tentacle_victim.current_hp = 100
	var tentacle_caster := Character.new()
	tentacle_caster.initialize("Tentacle caster", "human", "wizard", AbilityScores.new())
	tentacle_caster.character_id = "tentacle_caster"
	var tentacle_state := LocalRoomRules.create(definition, [tentacle_victim])
	tentacle_state["party_positions"][tentacle_victim.character_id] = [-2, 0]
	var tentacle_source := "black_tentacles:tentacle_caster:1"
	var tentacle_area_added := LocalRoomAreas.add(tentacle_state, "black_tentacles", tentacle_caster.character_id, Vector2i(-1, 0), 0, 60, 11, {
		"concentration_source_id": tentacle_source,
		"footprint": [[-1, 0]],
		"save_dc": 100,
		"slot_level": 4,
		"difficult_terrain": true,
		"requires_concentration": true,
	})
	var tentacle_grid := HexGrid.new()
	for cell in tentacle_state.get("cells", []):
		var tentacle_tile := HexTile.new()
		tentacle_tile.coord = LocalRoomRules.coord(cell)
		tentacle_tile.custom_properties["blocks_movement"] = not LocalRoomRules.passable(tentacle_state, tentacle_tile.coord)
		tentacle_grid.add_tile(tentacle_tile)
	var tentacle_entry := LocalRoomRules.move(tentacle_state, tentacle_victim, Vector2i(-1, 0), tentacle_grid)
	var tentacle_hp_before := tentacle_victim.current_hp
	var tentacle_outcomes := LocalRoomRules.resolve_area_entries(tentacle_entry.get("entered_areas", []), tentacle_victim)
	LocalRoomRules.move(tentacle_state, tentacle_victim, Vector2i(-2, 0), tentacle_grid)
	var same_turn_tentacle_reentry := LocalRoomRules.move(tentacle_state, tentacle_victim, Vector2i(-1, 0), tentacle_grid)
	var prior_elapsed_for_tentacle_test: float = GameManager.campaign_elapsed_seconds
	GameManager.campaign_elapsed_seconds = prior_elapsed_for_tentacle_test + 6.0
	var tentacle_end_turn := LocalRoomRules.end_local_turn(tentacle_state, tentacle_victim)
	var duplicate_tentacle_end_turn := LocalRoomRules.end_local_turn(tentacle_state, tentacle_victim)
	var tentacle_escape_failure := LocalRoomRules.escape_black_tentacles(tentacle_state, tentacle_victim)
	tentacle_state["areas"][0]["save_dc"] = 1
	var tentacle_escape_success := LocalRoomRules.escape_black_tentacles(tentacle_state, tentacle_victim)
	var tentacle_escape_cleared_source := not tentacle_victim.has_condition("restrained")
	CombatAction.apply_condition(tentacle_victim, "restrained", 99, tentacle_source)
	GameManager.campaign_elapsed_seconds = prior_elapsed_for_tentacle_test
	var tentacle_restrained: bool = tentacle_victim.condition_sources.get("restrained", {}).has(tentacle_source)
	var tentacle_snapshot: Dictionary = JSON.parse_string(JSON.stringify(tentacle_state))
	tentacle_grid.free()
	var grease_turn_state := LocalRoomRules.create(definition, [tentacle_victim])
	grease_turn_state["party_positions"][tentacle_victim.character_id] = [0, 0]
	var grease_turn_area := LocalRoomAreas.add(grease_turn_state, "grease", "grease_caster", Vector2i.ZERO, 0, 60, 100, {
		"concentration_source_id": "grease:grease_caster:1",
		"footprint": [[0, 0]],
		"save_dc": 100,
		"difficult_terrain": true,
		"requires_concentration": false,
	})
	GameManager.campaign_elapsed_seconds = prior_elapsed_for_tentacle_test + 18.0
	var grease_end_turn := LocalRoomRules.end_local_turn(grease_turn_state, tentacle_victim)
	var duplicate_grease_end_turn := LocalRoomRules.end_local_turn(grease_turn_state, tentacle_victim)
	GameManager.campaign_elapsed_seconds = prior_elapsed_for_tentacle_test
	var grease_turn_snapshot: Dictionary = JSON.parse_string(JSON.stringify(grease_turn_state))
	var prior_room_context: Dictionary = GameManager.transition_context
	var prior_characters: Dictionary = PartyManager.characters.duplicate()
	PartyManager.characters[tentacle_victim.character_id] = tentacle_victim
	PartyManager.characters[tentacle_caster.character_id] = tentacle_caster
	GameManager.transition_context = {"local_room": tentacle_state}
	LocalRoomCombat.remove_concentration(tentacle_caster, "black_tentacles", tentacle_source)
	GameManager.transition_context = prior_room_context
	PartyManager.characters = prior_characters
	check.call(tentacle_area_added.get("success", false) and tentacle_outcomes.size() == 1 and not bool(tentacle_outcomes[0].get("saved", true)) and tentacle_outcomes[0].get("damage", 0) >= 3 and tentacle_outcomes[0].get("damage", 0) <= 18 and tentacle_victim.current_hp < tentacle_hp_before and tentacle_restrained and same_turn_tentacle_reentry.get("entered_areas", []).is_empty() and tentacle_end_turn.get("end_turn_outcomes", []).size() == 1 and not bool(tentacle_end_turn["end_turn_outcomes"][0].get("saved", true)) and duplicate_tentacle_end_turn.get("end_turn_outcomes", []).is_empty() and tentacle_escape_failure.get("success", false) and not tentacle_escape_failure.get("escape_check", {}).get("success", true) and tentacle_escape_success.get("success", false) and tentacle_escape_success.get("escape_check", {}).get("success", false) and tentacle_escape_cleared_source and DungeonPersistence.local_error(tentacle_snapshot).is_empty(), "Transferred Black Tentacles resolves entry and end-turn Strength saves with damage, blocks duplicate same-turn saves, resolves failed and successful Athletics escape actions, and validates its saved turn ledger")
	check.call(grease_turn_area.get("success", false) and grease_end_turn.get("end_turn_outcomes", []).size() == 1 and grease_end_turn["end_turn_outcomes"][0].get("spell_id", "") == "grease" and not bool(grease_end_turn["end_turn_outcomes"][0].get("saved", true)) and tentacle_victim.has_condition("prone") and duplicate_grease_end_turn.get("end_turn_outcomes", []).is_empty() and DungeonPersistence.local_error(grease_turn_snapshot).is_empty(), "Grease resolves its end-of-turn Dexterity save, applies Prone on failure, limits the save to once per turn, and validates its saved ledger")
	check.call(tentacle_state.get("areas", []).is_empty() and not tentacle_victim.has_condition("restrained"), "Ending the room-owned Black Tentacles source clears its Restrained condition")
	check.call(LocalRoomAreas.expire(area_state, int(GameManager.campaign_elapsed_seconds) + 3601) == 1 and area_state.get("areas", []).is_empty(), "Room-owned areas expire against campaign time while their room is unloaded")
	var elevation_state := LocalRoomRules.create(definition, [area_walker])
	elevation_state["party_positions"][area_walker.character_id] = [-2, 0]
	elevation_state["cell_elevations"] = [{"position": [-1, 0], "feet": 10}]
	var elevation_climb := LocalRoomRules.move(elevation_state, area_walker, Vector2i(-1, 0), area_grid, "climb")
	var elevation_fall := LocalRoomRules.move(elevation_state, area_walker, Vector2i(-2, 0), area_grid, "walk")
	var elevation_walk := LocalRoomRules.move(elevation_state, area_walker, Vector2i(-1, 0), area_grid, "walk")
	var elevation_snapshot: Dictionary = JSON.parse_string(JSON.stringify(elevation_state))
	check.call(elevation_climb.get("success", false) and elevation_climb.get("movement_cost_feet", 0) == 5 and elevation_fall.get("fall_damage", 0) > 0 and elevation_walk.get("success", false) and elevation_walk.get("movement_cost_feet", 0) == 15 and elevation_snapshot.get("cell_elevations", []).size() == 1 and DungeonPersistence.local_error(elevation_snapshot).is_empty() and LocalRoomRules.fall_dice_for_drop(9) == 0 and LocalRoomRules.fall_dice_for_drop(10) == 1 and LocalRoomRules.fall_dice_for_drop(250) == 20, "Climb speed crosses authored elevation, walking uphill costs more, falling dice cap at 20d6, and elevation survives save validation")
	area_grid.free()
	var purifier_saved: Dictionary = JSON.parse_string(JSON.stringify(state))
	check.call(DungeonPersistence.local_error(purifier_saved).is_empty() and LocalRoomRules.get_object(purifier_saved, "cistern")["contamination"].is_empty(), "Room contamination and purification survive a validated JSON snapshot")
	var sight_grid := HexGrid.new()
	for cell in state.get("cells", []):
		var sight_tile := HexTile.new()
		sight_tile.coord = LocalRoomRules.coord(cell)
		sight_tile.custom_properties["blocks_sight"] = LocalRoomRules.blocks_sight(state, sight_tile.coord)
		sight_grid.add_tile(sight_tile)
	check.call(not Targeting.has_line_of_sight(Vector2i(-2, 0), Vector2i(2, 0), sight_grid), "A closed room door blocks sight through the shared hex-grid query")
	LocalRoomRules.get_object(state, "door")["open"] = true
	sight_grid.get_tile(Vector2i.ZERO).custom_properties["blocks_sight"] = LocalRoomRules.blocks_sight(state, Vector2i.ZERO)
	check.call(Targeting.has_line_of_sight(Vector2i(-2, 0), Vector2i(2, 0), sight_grid), "Opening that door clears the same sight path")
	var wall_position := LocalRoomRules.coord(state["walls"][0])
	state["wall_details"] = [{"position": [wall_position.x, wall_position.y], "height_feet": 5, "material": "wood"}]
	var wall_snapshot: Dictionary = JSON.parse_string(JSON.stringify(state))
	check.call(not LocalRoomRules.blocks_sight(state, wall_position) and not LocalRoomRules.passable(state, wall_position) and LocalRoomRules.wall_material(wall_snapshot, wall_position) == "wood" and DungeonPersistence.local_error(wall_snapshot).is_empty(), "A low authored wooden wall blocks movement but allows sight and saves its height/material")
	var wall_test_state := {"cells": [[-1, 0], [0, 0], [1, 0]], "walls": [[0, 0]], "wall_details": [{"position": [0, 0], "height_feet": 5, "material": "wood"}], "objects": [], "party_positions": {character.character_id: [-1, 0]}, "areas": []}
	var wall_origin := Vector2i(-1, 0)
	var wall_center := Vector2i.ZERO
	var wall_destination := Vector2i(1, 0)
	var wall_grid := HexGrid.new()
	for wall_test_coord in [wall_origin, wall_center, wall_destination]:
		var wall_test_tile := HexTile.new()
		wall_test_tile.coord = wall_test_coord
		wall_test_tile.custom_properties["blocks_movement"] = wall_test_coord == wall_center
		wall_grid.add_tile(wall_test_tile)
	character.set_movement_speed_feet("climb", 20)
	var walked_wall := LocalRoomRules.move(wall_test_state, character, wall_destination, wall_grid, "walk")
	var climbed_wall := LocalRoomRules.move(wall_test_state, character, wall_destination, wall_grid, "climb")
	check.call(not walked_wall.get("success", true) and climbed_wall.get("success", false) and climbed_wall.get("movement_cost_feet", 0) == 15, "Climb mode spends the wall's height to cross a low wall that blocks ordinary movement")
	var flyer := Character.new()
	flyer.initialize("Flyer", "human", "wizard", AbilityScores.new())
	flyer.character_id = "flyer"
	flyer.max_hp = 100
	flyer.current_hp = 100
	flyer.known_spells.append("fly")
	flyer.spell_slots["3"] = 1
	flyer.inventory.add_item("component_pouch")
	var flight_state: Dictionary = wall_test_state.duplicate(true)
	flight_state["party_positions"] = {flyer.character_id: [-1, 0]}
	flight_state["party_altitudes"] = {flyer.character_id: 0}
	flight_state["cell_elevations"] = [{"position": [1, 0], "feet": -10}]
	flight_state["cell_ceilings"] = [{"position": [-1, 0], "feet": 15}]
	var fly_cast := LocalRoomRules.cast_movement_spell(flight_state, "fly", flyer, [flyer])
	var low_flight_blocked := LocalRoomRules.move(flight_state, flyer, wall_destination, wall_grid, "fly")
	var flight_up := LocalRoomRules.change_flight_altitude(flight_state, flyer, 5)
	var flight_up_again := LocalRoomRules.change_flight_altitude(flight_state, flyer, 5)
	var ceiling_blocks_flight: bool = not LocalRoomRules.change_flight_altitude(flight_state, flyer, 5).get("success", false)
	var fly_move := LocalRoomRules.move(flight_state, flyer, wall_destination, wall_grid, "fly")
	var flyer_snapshot := Character.new()
	flyer_snapshot.from_dict(flyer.to_dict())
	flyer.add_condition("restrained", 2)
	var restrained_flight_stops := flyer.movement_speed_feet("fly") == 0
	flyer.remove_condition("restrained")
	check.call(fly_cast.get("success", false) and int(flyer.spell_slots["3"]) == 0 and int(flyer.spell_effects.values()[0].get("remaining_seconds", 0)) == 600 and flyer.movement_speed_feet("fly") == 60 and not low_flight_blocked.get("success", true) and flight_up.get("success", false) and flight_up_again.get("success", false) and ceiling_blocks_flight and fly_move.get("success", false) and fly_move.get("fall_damage", -1) == 0 and flyer_snapshot.movement_speed_feet("fly") == 60 and restrained_flight_stops, "Fly spends its slot, moves in five-foot vertical steps, respects the authored ceiling, clears a wall only at its height, crosses downward elevation without falling, reloads, and respects Speed 0")
	var saved_altitude_state := LocalRoomRules.create(definition, [flyer])
	saved_altitude_state["cell_ceilings"] = [{"position": [-3, 0], "feet": 15}]
	saved_altitude_state["party_altitudes"][flyer.character_id] = 10
	var altitude_snapshot: Dictionary = JSON.parse_string(JSON.stringify(saved_altitude_state))
	var altitude_snapshot_valid := DungeonPersistence.local_error(altitude_snapshot).is_empty()
	var prior_altitude_context: Dictionary = GameManager.transition_context
	var prior_altitude_dungeon: Dictionary = GameManager.active_dungeon_state.duplicate(true)
	var prior_altitude_snapshots: Dictionary = GameManager.dungeon_snapshots.duplicate(true)
	GameManager.transition_context = {"local_room": saved_altitude_state}
	LocalRoomCombat.capture([{"character": flyer, "hex_position": Vector2i(-3, 0), "altitude_feet": 10}])
	var altitude_returned: bool = saved_altitude_state.get("party_altitudes", {}).get(flyer.character_id, -1) == 10
	GameManager.transition_context = prior_altitude_context
	GameManager.active_dungeon_state = prior_altitude_dungeon
	GameManager.dungeon_snapshots = prior_altitude_snapshots
	check.call(altitude_snapshot_valid and altitude_returned and DungeonPersistence.local_error(saved_altitude_state).is_empty(), "A character's altitude and authored ceiling validate in the saved room and survive combat position capture/return")
	SpellEffects.end_concentration(flyer, [flyer])
	var flight_expiry_messages := LocalRoomRules.reconcile_flight_altitudes(flight_state, [flyer])
	check.call(flyer.movement_speed_feet("fly") == 0 and LocalRoomRules.altitude_feet(flight_state, flyer.character_id) == -10 and flight_expiry_messages.size() == 1, "Ending Fly concentration returns the character to the room floor and resolves the resulting fall")
	flyer.known_spells.append("levitate")
	flyer.spell_slots["2"] = 1
	var levitate_state: Dictionary = saved_altitude_state.duplicate(true)
	levitate_state["party_altitudes"][flyer.character_id] = 0
	levitate_state["party_altitude_modes"][flyer.character_id] = "ground"
	var levitate_cast := LocalRoomRules.cast_movement_spell(levitate_state, "levitate", flyer, [flyer])
	var levitate_save_valid := DungeonPersistence.local_error(JSON.parse_string(JSON.stringify(levitate_state))).is_empty()
	var levitate_lower := LocalRoomRules.change_levitation_altitude(levitate_state, flyer, -5)
	var hp_before_gentle_landing := flyer.current_hp
	SpellEffects.end_concentration(flyer, [flyer])
	var levitate_expiry_messages := LocalRoomRules.reconcile_flight_altitudes(levitate_state, [flyer])
	check.call(levitate_cast.get("success", false) and levitate_cast.get("altitude_feet", -1) == 10 and levitate_save_valid and levitate_lower.get("success", false) and LocalRoomRules.altitude_feet(levitate_state, flyer.character_id) == 0 and flyer.current_hp == hp_before_gentle_landing and levitate_expiry_messages.size() == 1 and levitate_expiry_messages[0].contains("gently"), "Levitate respects the ceiling, saves altitude, moves vertically, and floats its target down gently when Concentration ends: cast=%s lower=%s messages=%s saved=%s" % [levitate_cast, levitate_lower, levitate_expiry_messages, levitate_save_valid])
	flyer.known_spells.append("spider_climb")
	flyer.spell_slots["2"] = 1
	var spider_cast := LocalRoomRules.cast_movement_spell(flight_state, "spider_climb", flyer, [flyer])
	flight_state["party_positions"][flyer.character_id] = [-1, 0]
	var spider_move := LocalRoomRules.move(flight_state, flyer, wall_destination, wall_grid, "climb")
	check.call(spider_cast.get("success", false) and int(flyer.spell_slots["2"]) == 0, "Spider Climb casts with its required component and spends a level-2 slot")
	check.call(flyer.movement_speed_feet("climb") == flyer.movement_speed_feet("walk"), "Spider Climb grants climbing speed equal to walking speed")
	check.call(spider_move.get("success", false), "Spider Climb uses its granted speed to cross an authored wall")
	SpellEffects.end_concentration(flyer, [flyer])
	flyer.class_id = "druid"
	flyer.known_spells.append("freedom_of_movement")
	flyer.spell_slots["4"] = 1
	var freedom_cast := LocalRoomRules.cast_movement_spell(flight_state, "freedom_of_movement", flyer, [flyer])
	var freedom_snapshot := Character.new()
	freedom_snapshot.from_dict(flyer.to_dict())
	check.call(freedom_cast.get("success", false) and int(flyer.spell_slots["4"]) == 0 and flyer.movement_speed_feet("swim") == flyer.movement_speed_feet("walk") and freedom_snapshot.movement_speed_feet("swim") == flyer.movement_speed_feet("walk"), "Freedom of Movement grants a saved swimming speed equal to walking speed and spends its level-4 slot")
	var freedom_speed_before := flyer.get_speed()
	var freedom_slow_result := EventResolver.apply_effects(flyer, [{"type": "reduce_speed", "value": 2, "duration": 3}], flyer)
	check.call(not freedom_slow_result.is_empty() and flyer.get_speed() == freedom_speed_before and str(freedom_slow_result[0].get("message", "")).contains("unaffected"), "Freedom of Movement blocks magical effects that would reduce the protected character's Speed")
	CombatAction.apply_condition(flyer, "restrained", 99, "net:room_check")
	var freedom_escape := LocalRoomRules.escape_nonmagical_restraint(flyer)
	check.call(freedom_escape.get("success", false) and not flyer.has_condition("restrained") and freedom_escape.get("seconds", 0) == 6, "Freedom of Movement spends a local movement step to escape a nonmagical restraint")
	SpellEffects.consume_spell(flyer, "freedom_of_movement")
	wall_grid.free()
	var water_walker := Character.new()
	water_walker.initialize("Water walker", "human", "druid", AbilityScores.new())
	water_walker.character_id = "water_walker"
	water_walker.known_spells.append("water_walk")
	water_walker.spell_slots["3"] = 1
	water_walker.inventory.add_item("component_pouch")
	water_walker.set_movement_speed_feet("swim", 15)
	var water_state := LocalRoomRules.create(definition, [water_walker])
	water_state["party_positions"][water_walker.character_id] = [-1, 0]
	water_state["cell_terrains"] = [{"position": [0, 0], "surface": "water"}, {"position": [1, 0], "surface": "acid"}]
	LocalRoomRules.get_object(water_state, "door")["open"] = true
	var water_grid := HexGrid.new()
	for cell in water_state.get("cells", []):
		var water_tile := HexTile.new()
		water_tile.coord = LocalRoomRules.coord(cell)
		water_tile.terrain = HexTile.TerrainType.WATER if water_tile.coord == Vector2i.ZERO else HexTile.TerrainType.ROAD
		water_tile.custom_properties["blocks_movement"] = water_tile.terrain == HexTile.TerrainType.WATER
		water_grid.add_tile(water_tile)
	var denied_water_step := LocalRoomRules.move(water_state, water_walker, Vector2i.ZERO, water_grid)
	var swim_water_step := LocalRoomRules.move(water_state, water_walker, Vector2i.ZERO, water_grid, "swim")
	water_state["party_positions"][water_walker.character_id] = [-1, 0]
	var denied_acid_step := LocalRoomRules.move(water_state, water_walker, Vector2i(1, 0), water_grid)
	water_state["party_positions"][water_walker.character_id] = [-1, 0]
	var water_walk_cast := LocalRoomRules.cast_movement_spell(water_state, "water_walk", water_walker, [water_walker])
	var water_surface_step := LocalRoomRules.move(water_state, water_walker, Vector2i.ZERO, water_grid)
	var acid_surface_step := LocalRoomRules.move(water_state, water_walker, Vector2i(1, 0), water_grid)
	var water_snapshot: Dictionary = JSON.parse_string(JSON.stringify(water_state))
	check.call(not denied_water_step.get("success", true), "An authored water tile blocks ordinary walking")
	check.call(swim_water_step.get("success", false), "Swim speed allows movement across authored water")
	check.call(water_walk_cast.get("success", false) and SpellEffects.has_spell(water_walker, "water_walk"), "Water Walk casts and its saved effect grants liquid-surface movement")
	check.call(water_surface_step.get("success", false) and acid_surface_step.get("success", false) and not denied_acid_step.get("success", true), "Water Walk crosses authored water and acid surfaces while ordinary walking stops at both")
	check.call(DungeonPersistence.local_error(water_snapshot).is_empty(), "Authored water and acid surface data passes room save validation")
	water_grid.free()
	var teleporter := Character.new()
	teleporter.initialize("Teleporter", "human", "wizard", AbilityScores.new())
	teleporter.character_id = "teleporter"
	teleporter.known_spells.append("misty_step")
	teleporter.spell_slots["2"] = 1
	var teleport_state := LocalRoomRules.create(definition, [teleporter])
	var teleport_grid := HexGrid.new()
	LocalRoomRules.get_object(teleport_state, "door")["open"] = false
	LocalRoomRules.get_object(teleport_state, "door")["locked"] = true
	for cell in teleport_state.get("cells", []):
		var teleport_tile := HexTile.new()
		teleport_tile.coord = LocalRoomRules.coord(cell)
		teleport_tile.custom_properties["blocks_movement"] = not LocalRoomRules.passable(teleport_state, teleport_tile.coord)
		teleport_tile.custom_properties["blocks_sight"] = LocalRoomRules.blocks_sight(teleport_state, teleport_tile.coord)
		teleport_grid.add_tile(teleport_tile)
	var locked_door_position := LocalRoomRules.coord(LocalRoomRules.get_object(teleport_state, "door")["position"])
	var invalid_teleport := LocalRoomRules.cast_teleport(teleport_state, "misty_step", teleporter, locked_door_position, teleport_grid)
	var slots_after_invalid_teleport := int(teleporter.spell_slots.get("2", 0))
	var legal_destination := Vector2i(999, 999)
	var teleport_origin := LocalRoomRules.coord(teleport_state["party_positions"][teleporter.character_id])
	for cell in teleport_state.get("cells", []):
		var candidate := LocalRoomRules.coord(cell)
		if candidate == teleport_origin or not LocalRoomRules.passable(teleport_state, candidate) or not LocalRoomRules.object_at(teleport_state, candidate).is_empty(): continue
		if Targeting.has_line_of_sight(teleport_origin, candidate, teleport_grid) and HexUtils.get_distance(teleport_origin, candidate) <= 6:
			legal_destination = candidate
			break
	var valid_teleport := LocalRoomRules.cast_teleport(teleport_state, "misty_step", teleporter, legal_destination, teleport_grid)
	var teleport_snapshot: Dictionary = JSON.parse_string(JSON.stringify(teleport_state))
	check.call(not invalid_teleport.get("success", true) and slots_after_invalid_teleport == 1, "Misty Step refuses a blocked door without spending its slot")
	check.call(valid_teleport.get("success", false) and valid_teleport.get("seconds", 0) == 6 and LocalRoomRules.coord(teleport_state["party_positions"][teleporter.character_id]) == legal_destination, "Misty Step teleports to a visible unoccupied space: %s at %s" % [valid_teleport, legal_destination])
	check.call(DungeonPersistence.local_error(teleport_snapshot).is_empty(), "Misty Step preserves its new room position in validated saved state")
	teleport_grid.free()
	LocalRoomRules.get_object(state, "door")["open"] = false
	sight_grid.free()
	check.call(not LocalRoomRules.passable(state, Vector2i.ZERO), "Locked closed temple door blocks movement")
	check.call(not LocalRoomRules.interact(state, "door", "open", character)["success"], "Distant object interaction is refused")
	state["party_positions"][character.character_id] = [-2, 0]
	var key: Dictionary = LocalRoomRules.get_object(state, "key")["contents"][0]
	LocalRoomRules.get_object(state, "key")["hp"] = 3
	var key_id := str(key["instance_id"])
	check.call(LocalRoomRules.interact(state, "key", "take", character, key_id)["success"], "A specific world key moves into the backpack")
	check.call(character.inventory.get_instance(key_id)["state"]["physical"]["hp"] == 3, "Picking up an object preserves its material, attachment and damage record")
	check.call(not LocalRoomRules.interact(state, "key", "take", character, key_id)["success"], "Claiming the same key twice is refused")
	state["party_positions"][character.character_id] = [-1, 0]
	check.call(not LocalRoomRules.interact(state, "door", "open", character)["success"], "Opening a locked door is refused")
	check.call(LocalRoomRules.interact(state, "door", "unlock", character)["success"], "Matching carried key unlocks the door")
	check.call(LocalRoomRules.interact(state, "door", "open", character)["success"] and LocalRoomRules.passable(state, Vector2i.ZERO), "Opened door permits movement")
	check.call(not LocalRoomRules.interact(state, "door", "lock", character)["success"], "An open door cannot be locked")
	state["party_positions"][character.character_id] = [1, 0]
	var contents: Array = LocalRoomRules.get_object(state, "chest")["contents"]
	var potion_id := str(contents[1]["instance_id"])
	check.call(not LocalRoomRules.interact(state, "chest", "take", character, potion_id)["success"], "Closed containers refuse taking items")
	LocalRoomRules.interact(state, "chest", "open", character)
	check.call(LocalRoomRules.interact(state, "chest", "take", character, potion_id)["success"], "Selected potion copy transfers from the open chest")
	check.call(contents.size() == 1 and character.inventory.get_instance(potion_id)["definition_id"] == "potion_healing", "Taking one copy preserves the other copy")
	check.call(LocalRoomRules.interact(state, "chest", "put", character, potion_id)["success"] and contents.size() == 2, "Putting a copy back preserves its identity")
	while character.inventory.backpack.size() < Inventory.MAX_BACKPACK_SIZE: character.inventory.add_item("torch")
	check.call(not LocalRoomRules.interact(state, "chest", "take", character, potion_id)["success"] and contents.size() == 2, "Full backpack refuses chest retrieval without removing the world copy")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(state))
	check.call(DungeonPersistence.local_error(roundtrip).is_empty(), "Local room JSON roundtrip remains valid after movement")
	var dungeon_room := Room.new()
	dungeon_room.id = 1
	var plain_dungeon := {"dungeon_id": "ruins_of_ashvale", "rooms": [dungeon_room.to_dict()], "party_position": [0, 0], "local_rooms": {"1": roundtrip}}
	check.call(SaveManager._serialize_dungeon_state(plain_dungeon)["rooms"] == plain_dungeon["rooms"], "Saving an already-deserialized dungeon preserves its room DTOs")
	check.call(not LocalRoomRules.get_object(roundtrip, "door")["locked"] and LocalRoomRules.get_object(roundtrip, "key")["removed"], "Room changes and claimed key survive JSON roundtrip")
	var damaged := roundtrip.duplicate(true)
	damaged["objects"][0]["locked"] = "yes"
	check.call(not DungeonPersistence.local_error(damaged).is_empty(), "Malformed object flags are refused")
	var source := Inventory.new()
	source.add_item("longsword")
	source.add_item("longsword")
	var first: String = source.backpack_instances()[0]["instance_id"]
	var second: String = source.backpack_instances()[1]["instance_id"]
	source.copies.records[first]["state"] = {"charges": 3, "attuned_to": "A"}
	source.copies.records[second]["state"] = {"charges": 7, "attuned_to": "B"}
	check.call(first != second, "Two identical definitions receive different copy identities")
	check.call(source.equip_instance(Inventory.Slot.WEAPON, second), "A selected duplicate copy can be equipped")
	source.unequip(Inventory.Slot.WEAPON)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(source.to_dict()))
	check.call(InventoryCopies.saved_error(saved).is_empty(), "Individual copy DTO passes preflight")
	var restored := Inventory.new()
	restored.from_dict(saved)
	check.call(restored.get_instance(first)["state"]["charges"] == 3 and restored.get_instance(second)["state"]["attuned_to"] == "B", "Save reload preserves distinct copy state without merging")
	var ring_user := Character.new()
	ring_user.character_id = "ring_user"
	var item_owner: Inventory = ring_user.inventory
	item_owner.add_item("ring_of_protection")
	item_owner.add_item("ring_of_protection")
	var ring_copies := item_owner.backpack_instances()
	var ring_one := str(ring_copies[0]["instance_id"])
	var ring_two := str(ring_copies[1]["instance_id"])
	var ring_ac_before := ring_user.get_ac()
	var ring_save_before: int = ring_user.make_saving_throw_result("DEX")["modifier"]
	var ring_attunement := item_owner.attune_instance(ring_one, ring_user.character_id)
	check.call(ring_attunement.get("success", false) and ring_attunement.get("seconds", 0) == 3600, "Attuning a magic ring costs one hour")
	check.call(not item_owner.attune_instance(ring_two, ring_user.character_id).get("success", false), "Ring of Protection cannot be duplicated through simultaneous attunement")
	check.call(item_owner.equip_instance(Inventory.Slot.RING_1, ring_one) and ring_user.get_ac() == ring_ac_before + 1 and ring_user.make_saving_throw_result("DEX")["modifier"] == ring_save_before + 1, "Only the worn, individually attuned Ring of Protection grants its AC and save bonuses")
	var wand_user := Inventory.new()
	wand_user.add_item("wand_of_magic_missiles")
	var wand_id := str(wand_user.backpack_instances()[0]["instance_id"])
	wand_user.copies.records[wand_id]["state"]["charges"] = 0
	wand_user.recover_daily_charges()
	var recovered_charges := int(wand_user.get_instance(wand_id)["state"]["charges"])
	check.call(recovered_charges >= 2 and recovered_charges <= 7, "Wand copy restores its own 1d6 + 1 charges, up to seven, at dawn")
	wand_user.add_item("wand_of_magic_missiles")
	var second_wand_id := str(wand_user.backpack_instances()[1]["instance_id"])
	var spent_one_copy := wand_user.spend_instance_charges(wand_id, 1)
	check.call(spent_one_copy and int(wand_user.get_instance(wand_id)["state"]["charges"]) == recovered_charges - 1 and int(wand_user.get_instance(second_wand_id)["state"]["charges"]) == 7 and not wand_user.spend_instance_charges(wand_id, 100), "Spending Wand charges mutates only the selected copy and refuses an unaffordable spend")
	var curse_user := Inventory.new()
	curse_user.add_item("sword_of_vengeance")
	var cursed_sword_id := str(curse_user.backpack_instances()[0]["instance_id"])
	check.call(curse_user.attune_instance(cursed_sword_id, ring_user.character_id).get("success", false), "Cursed sword can be attuned before its binding restriction applies")
	check.call(not curse_user.unattune_instance(cursed_sword_id, ring_user.character_id).get("success", false), "A cursed attunement cannot be ended voluntarily")
	curse_user.equip_instance(Inventory.Slot.WEAPON, cursed_sword_id)
	curse_user.add_item("longsword")
	var replacement_sword_id := str(curse_user.backpack_instances().back()["instance_id"])
	var cursed_inventory_before := curse_user.to_dict()
	check.call(not curse_user.equip_instance(Inventory.Slot.WEAPON, replacement_sword_id) and curse_user.to_dict() == cursed_inventory_before, "Replacing a curse-bound equipped copy refuses without changing either copy or inventory order")
	check.call(not curse_user.can_equip(Inventory.Slot.WEAPON, "longsword", true) and curse_user.equip(Inventory.Slot.WEAPON, "longsword") == "" and curse_user.to_dict() == cursed_inventory_before, "Catalog and granted-item equip paths cannot bypass the same curse restriction")
	var curse_break_count := curse_user.break_cursed_item_attunements(ring_user.character_id)
	var released_sword_state: Dictionary = curse_user.get_instance(cursed_sword_id).get("state", {})
	check.call(curse_break_count == 1 and not released_sword_state.has("attuned_to") and not released_sword_state.has("cursed_attunement"), "Remove Curse can break the sword's cursed attunement")
	check.call(curse_user.equip_instance(Inventory.Slot.WEAPON, replacement_sword_id) and curse_user.equipped_instance_id(Inventory.Slot.WEAPON) == replacement_sword_id and not curse_user.get_instance(cursed_sword_id).is_empty(), "After Remove Curse, replacing the sword preserves both exact copies")
	var ownership_dto := {"party": {"characters": {"A": {"inventory": saved}, "B": {"inventory": saved}}}, "players": [], "campaign_ledger": {}, "active_dungeon_state": {}}
	check.call(not InventoryCopies.ownership_error(ownership_dto).is_empty(), "The same copy cannot be owned by two saved characters")
	ownership_dto["party"]["characters"].erase("B")
	var world_collision := state.duplicate(true)
	world_collision["objects"][1]["contents"].append(restored.get_instance(first))
	ownership_dto["campaign_ledger"] = {"dungeon_snapshots": {"ashvale": {"local_rooms": {"1": world_collision}}}}
	check.call(not InventoryCopies.ownership_error(ownership_dto).is_empty(), "Saved world and inventory cannot both own the same copy")
	var destination := Inventory.new()
	for index in Inventory.MAX_BACKPACK_SIZE: destination.add_item("torch")
	check.call(not restored.transfer_instance(second, destination) and not restored.get_instance(second).is_empty(), "Full destination refuses transfer without losing the source copy")
	destination.remove_item("torch")
	check.call(restored.transfer_instance(second, destination) and restored.get_instance(second).is_empty() and destination.get_instance(second)["state"]["charges"] == 7, "Transfer preserves identity and individual state")
	var invalid := saved.duplicate(true)
	invalid["copies"]["backpack"][1] = invalid["copies"]["backpack"][0]
	check.call(not InventoryCopies.saved_error(invalid).is_empty(), "Duplicate saved copy ownership is refused")
	var legacy := Inventory.new()
	legacy.from_dict({"backpack": ["torch", "torch"], "equipped": {}, "gold": 9})
	check.call(legacy.backpack_instances().size() == 2 and legacy.backpack_instances()[0]["instance_id"] != legacy.backpack_instances()[1]["instance_id"] and legacy.gold == 9, "Older schema-2 inventory reconstructs each occurrence without duplicate grants")
	var consumables := Inventory.new()
	consumables.add_item("potion_healing")
	consumables.add_item("potion_healing")
	var retained := str(consumables.backpack_instances()[0]["instance_id"])
	var consumed := str(consumables.backpack_instances()[1]["instance_id"])
	character.current_hp = maxi(1, character.max_hp - 4)
	var hp_before := character.current_hp
	check.call(consumables.consume_instance(consumed, character)["success"] and consumables.get_instance(consumed).is_empty() and not consumables.get_instance(retained).is_empty() and character.current_hp > hp_before, "Using a selected duplicate potion heals and consumes only that copy")
