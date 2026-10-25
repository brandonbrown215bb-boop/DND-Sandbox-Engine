class_name ItemFormReturnControls
extends RefCounted

const SLOT := "item_form_return_pending"
const SETTLED_SLOT := "item_form_return_settled"

static func find(room: Dictionary, id: String) -> Dictionary:
	for object in room.get("objects", []):
		for copy in object.get("contents", []):
			if str(copy.instance_id) == id: return copy
	return {}

static func run(h: Node) -> void:
	h._enter_test("item_form_return_flow")
	h._setup_world()
	ItemFormReturnChecks.load_fixtures()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: dungeon.hex_grid.hex_clicked.emit(candidate.coord); break
	await h.get_tree().process_frame
	var state: Dictionary = dungeon.local_view.state
	var room_key := dungeon.local_room_id
	var original_walls: Array = state.get("walls", []).duplicate(true)
	var owner: Character = PlayerManager.get_player(0).character
	var voluntary := Batch042Checks.add(owner, ItemFormReturnChecks.ITEM)
	var ground := Batch042Checks.add(owner, ItemFormReturnChecks.RENAMED)
	var pending := Batch042Checks.add(owner, ItemFormReturnChecks.ITEM)
	var independent := Batch042Checks.add(owner, ItemFormReturnChecks.ITEM)
	var copy := owner.inventory.get_instance(pending)
	copy.state["engraving"] = "same exact original"
	owner.inventory.update_instance(copy)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"], "local_room": state}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	var origin := LocalRoomRules.coord(state.party_positions[owner.character_id])
	ItemProjectionRules.project(owner, voluntary)
	ItemProjectionRules.attach(combat, owner, origin)
	var v := ItemProjectionRules.actor(owner, voluntary)
	v.take_damage(7)
	h._assert(ItemProjectionRules.revert(owner, voluntary).reverted and owner.inventory.get_instance(voluntary).state.item_form_hp == 22, "S-166 actual combat voluntary ending returns the original and resets its form HP")
	combat._update_grid_entities()
	ItemProjectionRules.project(owner, ground)
	ItemProjectionRules.attach(combat, owner, origin)
	var target := ItemProjectionRules.actor(owner, ground)
	target.current_hp = 1
	ItemFormReturnChecks.fill(owner)
	var target_at := origin
	for entity in combat.player_entities:
		if entity.get("character") == target: target_at = entity.hex_position
	var attack_cells := PlacementRules.reserve(combat, target_at, "medium", 1, 1)
	if not attack_cells.is_empty(): combat.monster_entities[0].hex_position = attack_cells[0]
	combat._update_grid_entities()
	for _try in 6:
		if target.current_hp <= 0: break
		Batch031Controls._seed_hit()
		await combat._execute_monster_attack(combat.monster_entities[0], target.character_name, 0)
	var ground_copy := find(state, ground)
	var expected_item_hp := 12 - maxi(0, int(combat.last_monster_weapon_attack_result.get("damage", 0)) - 1)
	h._assert(target.current_hp == 0 and not ItemProjectionRules.is_projected(owner, ground) and not ground_copy.is_empty() and int(ground_copy.state.get("combat_object_hp", 0)) == expected_item_hp and expected_item_hp > 0 and expected_item_hp < 12 and owner.inventory.backpack.size() == 40, "S-166 actual lethal monster hit settles exact overflow into the ground copy when the backpack is full (original HP %d)" % expected_item_hp)
	# These two were already in the full bag; each projection frees one slot.
	ItemProjectionRules.project(owner, pending)
	ItemProjectionRules.project(owner, independent)
	ItemProjectionRules.attach(combat, owner, origin)
	var blocked := ItemProjectionRules.actor(owner, pending)
	var other := ItemProjectionRules.actor(owner, independent)
	other.current_hp = 7
	ItemFormReturnChecks.fill(owner)
	var end_at := Vector2i.ZERO
	for entity in combat.player_entities:
		if entity.get("character") == blocked: end_at = entity.hex_position
	for hex in HexUtils.get_hexes_in_range(end_at, 1):
		var raw := [hex.x, hex.y]
		if hex != end_at and state.cells.any(func(c): return LocalRoomRules.coord(c) == hex) and not state.walls.any(func(c): return LocalRoomRules.coord(c) == hex): state.walls.append(raw)
	combat._update_grid_entities()
	blocked.take_damage(25)
	for _i in 3:
		ItemProjectionRules.revert(owner, pending)
		combat._update_grid_entities()
	h._assert(ItemProjectionRules.is_projected(owner, pending) and owner.item_projections[pending].ending.overflow == 3 and owner.item_projections[pending].copy.state.combat_object_hp == 9 and other.current_hp == 7 and ItemProjectionRules.is_projected(owner, independent), "S-166 blocked ground preserves the settled exact copy and independent identical injured form across repeated callbacks")
	GameManager.test_mode = true
	await combat._end_battle("victory")
	h._teardown_scene(combat)
	# Retain the actual explored room in the dormant dungeon ledger, then save
	# from the already supported overworld checkpoint.
	GameManager.remember_dungeon()
	h._teardown_scene(dungeon)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	GameManager.active_dungeon_state.clear()
	var room: Dictionary = GameManager.dungeon_snapshots["ruins_of_ashvale"].local_rooms[room_key]
	var manifest := {"pid": OS.get_process_id(), "owner": owner.character_id, "room_key": room_key, "pending": pending, "independent": independent, "ground": ground, "ground_hp": int(ground_copy.get("state", {}).get("combat_object_hp", 0)), "walls": original_walls}
	h._assert(SaveManager.save_game(SLOT), "S-166 actual safe checkpoint saves blocked return and dormant ground copy")
	var file := FileAccess.open("user://item_form_return_manifest.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest))
		file.close()
	# This must settle BEFORE the dormant ledger is captured by SaveManager.
	room.walls = original_walls.duplicate(true)
	h._assert(SaveManager.save_game(SETTLED_SLOT) and not ItemProjectionRules.is_projected(owner, pending) and not find(room, pending).is_empty(), "S-166 save-time legal return commits before the dormant world snapshot")
	h._assert(verify(manifest), "S-166 production reload preserves blocked and completed returns without overflow replay")
	h._exit_test()

static func verify(manifest: Dictionary) -> bool:
	if not SaveManager.load_game(SETTLED_SLOT): return false
	var owner: Character = PartyManager.characters.get(str(manifest.owner))
	var room: Dictionary = GameManager.dungeon_snapshots.get("ruins_of_ashvale", {}).get("local_rooms", {}).get(str(manifest.room_key), {})
	if owner == null or find(room, str(manifest.pending)).get("state", {}).get("combat_object_hp") != 9 or ItemProjectionRules.is_projected(owner, str(manifest.pending)): return false
	if not SaveManager.load_game(SLOT): return false
	owner = PartyManager.characters.get(str(manifest.owner))
	room = GameManager.dungeon_snapshots.get("ruins_of_ashvale", {}).get("local_rooms", {}).get(str(manifest.room_key), {})
	if owner == null or not ItemProjectionRules.is_projected(owner, str(manifest.pending)) or not find(room, str(manifest.pending)).is_empty(): return false
	var other := ItemProjectionRules.actor(owner, str(manifest.independent))
	if other == null or other.current_hp != 7: return false
	for _i in 3: ItemProjectionRules.revert(owner, str(manifest.pending))
	if owner.item_projections[manifest.pending].copy.state.combat_object_hp != 9: return false
	var returned_ground := find(room, str(manifest.ground))
	if returned_ground.get("state", {}).get("combat_object_hp") != manifest.ground_hp: return false
	room.walls = manifest.walls.duplicate(true)
	# A recovered summon occupying every possible return cell also blocks it.
	var origin := LocalRoomRules.coord(owner.item_projections[manifest.pending].ending.location.position)
	var positions: Dictionary = room.get("created_actor_positions", {}).duplicate(true)
	for cell in HexUtils.get_hexes_in_range(origin, 1): room.created_actor_positions["occupied:" + str(cell)] = [cell.x, cell.y]
	if ItemProjectionRules.revert(owner, str(manifest.pending)).reverted: return false
	room.created_actor_positions = positions
	var returned := ItemProjectionRules.revert(owner, str(manifest.pending))
	var copy := find(room, str(manifest.pending))
	if not returned.reverted or returned.destination != "ground" or copy.get("state", {}).get("combat_object_hp") != 9 or copy.state.get("engraving") != "same exact original": return false
	if ItemProjectionRules.revert(owner, str(manifest.pending)).reverted or owner.inventory.backpack.size() != 40 or other.current_hp != 7: return false
	if find(room, str(manifest.ground)) != returned_ground: return false
	return ItemProjectionRules.saved_error(owner.to_dict()).is_empty() and DungeonPersistence.local_error(room).is_empty()
