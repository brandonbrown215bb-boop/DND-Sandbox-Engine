## Production-path probe for the post-combat dungeon victory contract.
##
## This keeps GameManager.test_mode disabled. It uses the normal dungeon and
## combat scenes, the real turn/input handlers, and the production result
## overlay. The probe is evidence tooling for Q-20260810-163315-4a24; it is
## intentionally not part of the player-facing runtime.
extends Node

var _started := false
var _is_supervisor := false


func _ready() -> void:
	if not _is_supervisor:
		# A scene launched with an explicit probe scene is itself the current
		# scene, so GameManager.change_state would free this node. Move the
		# actual probe under /root before the first production transition.
		var supervisor := Node.new()
		supervisor.set_script(get_script())
		supervisor.set("_is_supervisor", true)
		get_tree().root.call_deferred("add_child", supervisor)
		return
	if _started:
		return
	_started = true
	call_deferred("_run")


func _fresh_character() -> Character:
	var scores := AbilityScores.new()
	scores.from_dict({"STR": 16, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	var character := Character.new()
	character.initialize("Victory Contract Tester", "human", "fighter", scores)
	return character


func _setup_normal_campaign() -> void:
	GameManager.test_mode = false
	GameManager.active_campaign = DataLoader.campaigns.values()[0]
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.transition_context = {}
	GameManager.is_loading_save = false
	GameManager.game_in_progress = true
	GameManager.defeated_monsters.clear()
	GameManager.cleared_dungeons.clear()
	GameManager.claimed_rewards.clear()
	GameManager.completed_milestones.clear()
	PlayerManager.reset()
	PartyManager.reset()
	PlayerManager.add_player("Victory Contract Tester")
	var character := _fresh_character()
	character.inventory.equip(Inventory.Slot.WEAPON, "longsword", true)
	PlayerManager.set_player_character(0, character)
	PartyManager.register_player_character(0, character)


func _wait_for_state(state: GameManager.GameState, timeout_seconds: float = 5.0) -> Node:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if GameManager.current_state == state:
			var found := _find_state_node(get_tree().root, state)
			if found != null:
				return found
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	return null


func _find_state_node(node: Node, state: GameManager.GameState) -> Node:
	if state == GameManager.GameState.DUNGEON and node is DungeonState:
		return node
	if state == GameManager.GameState.COMBAT and node is CombatState:
		return node
	for child in node.get_children():
		var found := _find_state_node(child, state)
		if found != null:
			return found
	return null


func _find_overlay(combat: Node) -> Node:
	for child in combat.get_children():
		if child.has_method("_on_continue") and child.has_method("show_result"):
			return child
	return null


func _drive_victory(combat: Node) -> void:
	for player_entity in combat.player_entities:
		var character: Character = player_entity.get("character")
		character.base_ac = 1000
		character.max_hp = 10000
		character.current_hp = 10000
		character.is_alive = true
	for monster in combat.monster_entities:
		monster["current_hp"] = 0
		monster["is_alive"] = false
	# This is the same terminal chokepoint used by the live attack handler. The
	# surrounding scene/state flow remains normal; only the encounter outcome is
	# controlled so the contract probe cannot stall in unrelated AI/reaction UI.
	combat._check_battle_end_conditions()
	await get_tree().create_timer(0.2).timeout


func _run() -> void:
	print("NORMAL_VICTORY_PROBE_BEGIN test_mode=%s" % GameManager.test_mode)
	_setup_normal_campaign()

	seed(424242)
	GameManager.enter_dungeon("ruins_of_ashvale")
	var dungeon := await _wait_for_state(GameManager.GameState.DUNGEON)
	if dungeon == null:
		push_error("NORMAL_VICTORY_PROBE_FAIL dungeon scene did not load")
		get_tree().quit(1)
		return

	var target_room: Room = null
	for candidate in dungeon.rooms.values():
		if candidate is Room and candidate.type == Room.RoomType.COMBAT and (target_room == null or candidate.id < target_room.id):
			target_room = candidate
	if target_room == null:
		push_error("NORMAL_VICTORY_PROBE_FAIL no adjacent combat room")
		get_tree().quit(1)
		return

	var target_room_id := target_room.id
	var position_before_combat: Vector2i = target_room.coord
	var input_before_combat: bool = dungeon.hex_grid.is_processing_input()
	var room_cleared_before_combat: bool = target_room.is_cleared
	for candidate in dungeon.rooms.values():
		if candidate is Room:
			print("DUNGEON_ROOM id=%d coord=%s type=%s" % [candidate.id, candidate.coord, Room.RoomType.keys()[candidate.type]])
	for room_id in range(1, target_room_id + 1):
		var step_room: Room = null
		for candidate in dungeon.rooms.values():
			if candidate is Room and candidate.id == room_id:
				step_room = candidate
				break
		if step_room != null and GameManager.current_state == GameManager.GameState.DUNGEON:
			dungeon._on_room_clicked(step_room.coord)
			await get_tree().create_timer(0.4).timeout
		if GameManager.current_state == GameManager.GameState.COMBAT:
			break
	print("DUNGEON_BEFORE room_id=%d party_position=%s room_cleared=%s input=%s" % [target_room_id, position_before_combat, room_cleared_before_combat, input_before_combat])
	var combat := await _wait_for_state(GameManager.GameState.COMBAT)
	if combat == null:
		push_error("NORMAL_VICTORY_PROBE_FAIL combat scene did not load")
		get_tree().quit(1)
		return
	var combat_elapsed := 0.0
	while (combat.player_entities.is_empty() or combat.monster_entities.is_empty()) and combat_elapsed < 5.0:
		await get_tree().create_timer(0.1).timeout
		combat_elapsed += 0.1
	if combat.player_entities.is_empty() or combat.monster_entities.is_empty():
		push_error("NORMAL_VICTORY_PROBE_FAIL combat scene did not finish spawning entities")
		get_tree().quit(1)
		return

	await _drive_victory(combat)
	var overlay := _find_overlay(combat)
	if overlay == null:
		var alive_count := 0
		for monster in combat.monster_entities:
			if monster.get("is_alive", false):
				alive_count += 1
		print("COMBAT_NO_OVERLAY battle_ending=%s active=%s players=%d monsters=%d alive_monsters=%d" % [combat._battle_ending, combat.active_combatant, combat.player_entities.size(), combat.monster_entities.size(), alive_count])
		push_error("NORMAL_VICTORY_PROBE_FAIL production victory overlay did not appear")
		get_tree().quit(1)
		return
	var result_overlay: BattleResultOverlay = overlay
	print("OVERLAY visible=%s title=%s subtitle=%s continue=%s menu=%s combat_input=%s state=%s" % [result_overlay.visible, result_overlay._title.text, result_overlay._subtitle.text, result_overlay._btn_continue.text, result_overlay._btn_menu.text, combat.is_processing_input(), GameManager.GameState.keys()[GameManager.current_state]])
	print("COMBAT_STATE defeated=%s party_hp=%d party_max_hp=%d spell_slots=%s feature_uses=%s" % [GameManager.defeated_monsters, PartyManager.get_active_characters()[0].current_hp, PartyManager.get_active_characters()[0].max_hp, PartyManager.get_active_characters()[0].spell_slots, PartyManager.get_active_characters()[0].feature_uses])

	overlay._on_continue()
	var returned_dungeon := await _wait_for_state(GameManager.GameState.DUNGEON, 6.0)
	if returned_dungeon == null:
		push_error("NORMAL_VICTORY_PROBE_FAIL Continue did not return to dungeon")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.4).timeout
	var returned_room: Room = null
	for candidate in returned_dungeon.rooms.values():
		if candidate is Room and candidate.id == target_room_id:
			returned_room = candidate
			break
	var persisted_rooms = GameManager.active_dungeon_state.get("rooms", null)
	print("PERSISTENCE active_dungeon_state rooms_type=%s rooms_count=%d" % [type_string(typeof(persisted_rooms)), persisted_rooms.size() if persisted_rooms is Dictionary or persisted_rooms is Array else -1])
	print("DUNGEON_AFTER state=%s room_id=%d party_position=%s room_cleared=%s pending=%d boss_defeated=%s input=%s transition=%s" % [GameManager.GameState.keys()[GameManager.current_state], target_room_id, returned_dungeon.party_position, returned_room.is_cleared if returned_room else false, returned_dungeon.pending_combat_room_id, returned_dungeon.boss_defeated, returned_dungeon.hex_grid.is_processing_input(), GameManager.transition_context])
	var contract_passed := GameManager.current_state == GameManager.GameState.DUNGEON
	contract_passed = contract_passed and returned_room != null and returned_room.is_cleared
	contract_passed = contract_passed and returned_dungeon.pending_combat_room_id == -1
	contract_passed = contract_passed and returned_dungeon.party_position == position_before_combat
	contract_passed = contract_passed and returned_dungeon.hex_grid.is_processing_input()
	contract_passed = contract_passed and not GameManager.defeated_monsters.is_empty()
	print("NORMAL_VICTORY_CONTRACT_%s" % ("PASSED" if contract_passed else "FAILED"))
	print("NORMAL_VICTORY_PROBE_END")
	get_tree().quit(0 if contract_passed else 1)
