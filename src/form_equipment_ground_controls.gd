class_name FormEquipmentGroundControls
extends RefCounted

const SLOT := "form_ground_checkpoint"

static func run(h: Node) -> void:
	h._enter_test("form_equipment_ground_flow")
	h._setup_world()
	FormEquipmentGroundChecks.load_fixtures()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: dungeon.hex_grid.hex_clicked.emit(candidate.coord); break
	await h.get_tree().process_frame
	var view: LocalRoomView = dungeon.local_view
	var room_key := dungeon.local_room_id
	var state := view.state
	var owner: Character = PlayerManager.get_player(1).get("character")
	var receiver: Character = PlayerManager.get_player(0).get("character")
	var prior := {"known": owner.known_spells.duplicate(), "book": owner.wizard_spellbook.duplicate(), "choices": owner.feature_choices.duplicate(true), "features": owner.features.duplicate(true)}
	var ids := FormEquipmentGroundChecks.kit(owner)
	var spells: Array[String] = [Batch041Checks.GUISE]
	owner.known_spells.assign(spells)
	owner.wizard_spellbook.assign(spells)
	owner.feature_choices[owner.get_spellcasting_feature_id()] = spells.duplicate()
	owner.features.append({"id": "fixture:ground_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 2}]})
	owner.spell_slots = {"2": 1}
	var origin := LocalRoomRules.coord(state.party_positions[owner.character_id])
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"], "local_room": state}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for player in combat.player_entities:
		if player.character == owner: player.hex_position = origin
		player.has_turn = true
	combat.monster_entities[0].hex_position = Vector2i(3, -1)
	combat._update_grid_entities()
	h._p_focus(combat, owner)
	combat._reset_turn_action_economy()
	await Batch047Controls.begin(h, combat, owner, Batch041Checks.GUISE)
	await Batch027Controls.answer(h, combat, "Choose how equipment", "Dropped")
	await Batch047Controls.settle(h, combat)
	h._assert(ActorProjectionRules.equipment_policy(owner) == "dropped" and owner.inventory.backpack.size() == 40 and combat.dropped_combat_items.size() == 3 and owner.spell_slots["2"] == 0 and not combat.turn_budget.action_available, "Ground actual HUD transforms with full bag, spends once and drops three copies")
	if combat.dropped_combat_items.size() != 3:
		h._teardown_scene(combat)
		h._teardown_scene(dungeon)
		h._exit_test()
		return
	for object in combat.dropped_combat_items:
		h._assert(LocalRoomRules.coord(object.position) == origin, "Ground actual combat record uses the actor's location")
		if object.instance_id == ids.armor: CombatObjectRules.apply_damage(object, 100, "force")
	combat._update_grid_entities()
	h._assert(combat.hex_grid.entities.any(func(e): return e.get("world_object", {}).get("instance_id", "") == ids.jewel), "Ground actual grid refresh exposes dropped exact copy")
	GameManager.test_mode = true
	await combat._end_battle("victory")
	h._assert(state.objects.any(func(o): return o.get("contents", []).any(func(c): return c.instance_id == ids.jewel)) and FormEquipmentGroundChecks.find(state, ids.armor).is_empty() and ActorProjectionRules.is_projected(owner), "Ground actual battle exit captures surviving copies and destruction while retaining the form")
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	state.party_positions[receiver.character_id] = state.party_positions[owner.character_id].duplicate()
	var jewel := FormEquipmentGroundChecks.find(state, ids.jewel)
	var picked := LocalRoomRules.interact(state, str(jewel.id), "take", receiver, ids.jewel)
	h._assert(picked.success and receiver.inventory.get_instance(ids.jewel).state.source_link == ids.payload.state.source_link and receiver.inventory.get_instance(ids.jewel).state.contents == ids.payload.state.contents and receiver.inventory.get_instance(ids.jewel).state.attached == ids.payload.state.attached and receiver.inventory.get_instance(ids.jewel).state.charges == 3, "Ground another actor takes the exact cursed charged copy, contents, attachments and source links while owner remains transformed")
	h._assert(owner.inventory.get_instance(ids.blade).is_empty() and owner.inventory.equipped_instance_id(Inventory.Slot.RING_2) == ids.clasp and owner.item_curses.has(ids.blade), "Ground allowed curse removal lingers and blocked curse stays worn")
	Batch047Controls._restore(owner, prior)
	# Leave through the actual room/entrance controls; combat and in-room saves remain forbidden.
	var exit_position := LocalRoomRules.coord(state.exits[0])
	state.party_positions[view.actor().character_id] = [exit_position.x, exit_position.y]
	view.refresh()
	view.leave_requested.emit()
	await h.get_tree().process_frame
	if dungeon.local_view == null and dungeon.party_position != Vector2i.ZERO:
		dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
		await h.get_tree().process_frame
	var saved := SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "Ground next allowed entrance checkpoint saves split ownership and transformed actor: " + SaveManager.get_save_block_reason())
	var manifest := {"pid": OS.get_process_id(), "owner_id": owner.character_id, "receiver_id": receiver.character_id, "room_id": room_key, "ids": ids}
	var file := FileAccess.open("user://form_ground_manifest.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest))
		file.close()
	if saved:
		var invalid := SaveManager._read_save(SLOT)
		var invalid_room: Dictionary = invalid.active_dungeon_state.local_rooms[room_key]
		var forged: Dictionary = ids.payload.duplicate(true)
		forged.instance_id = "world:forged-ground-parent"
		invalid_room.objects.append(LocalRoomRules.placed_item(invalid_room, forged, origin))
		h._assert(not SaveManager._validate_save_data(invalid).is_empty() and PartyManager.characters.get(owner.character_id) == owner and ActorProjectionRules.is_projected(owner), "Ground malformed checkpoint with duplicated nested identities refuses before replacing the session")
		var loaded := SaveManager.load_game(SLOT)
		h._assert(loaded and verify(manifest), "Ground real SaveManager reload/reversion preserves actual ownership without duplication")
	h._teardown_scene(dungeon)
	h._exit_test()

static func verify(manifest: Dictionary) -> bool:
	var owner: Character = PartyManager.characters.get(str(manifest.owner_id))
	var receiver: Character = PartyManager.characters.get(str(manifest.receiver_id))
	var room: Dictionary = GameManager.active_dungeon_state.local_rooms.get(str(manifest.room_id), {})
	if owner == null or receiver == null or room.is_empty() or not ActorProjectionRules.is_projected(owner): return false
	var ids: Dictionary = manifest.ids
	var copy := receiver.inventory.get_instance(str(ids.jewel))
	if copy.is_empty() or copy.state.charges != 3 or copy.state.contents != ids.payload.state.contents or copy.state.attached != ids.payload.state.attached or copy.state.source_link != ids.payload.state.source_link or not copy.state.cursed_attunement: return false
	if not FormEquipmentGroundChecks.find(room, str(ids.armor)).is_empty() or FormEquipmentGroundChecks.find(room, str(ids.blade)).is_empty(): return false
	SpellEffects.end_concentration(owner, PartyManager.characters.values())
	if ActorProjectionRules.is_projected(owner) or not owner.inventory.get_instance(str(ids.jewel)).is_empty() or not owner.inventory.get_instance(str(ids.blade)).is_empty() or not owner.inventory.get_instance(str(ids.armor)).is_empty() or owner.inventory.equipped_instance_id(Inventory.Slot.RING_2) != str(ids.clasp): return false
	return receiver.inventory.get_instance(str(ids.jewel)) == copy and DungeonPersistence.local_error(room).is_empty()
