class_name WorldSearchFlow
extends RefCounted

const SLOT := "world_search"
const PLAYER_SLOT := "world_search_players"


static func fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/ordinary_actions/search_spells.json", "spell")
	if "fixture:search_spark" not in DataLoader.classes.wizard.spell_list_ids: DataLoader.classes.wizard.spell_list_ids.append("fixture:search_spark")


static func objects() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/ordinary_actions/search_objects.json"))


static func logic(check: Callable) -> void:
	var actor := PerceptionChecks.actor("searcher")
	var other := PerceptionChecks.actor("other_searcher")
	var data := {"id":"search-room", "name":"Search room", "cells":[[-1,0],[0,0],[1,0],[2,0],[2,1],[1,-1]], "walls":[], "exits":[[0,0]], "party_spawns":[[0,0],[1,0]], "monster_spawns":[], "encounter_monsters":[], "objects":objects()}
	var room := LocalRoomRules.create(data, [actor, other])
	var grid := PerceptionChecks.grid()
	var cache := LocalRoomRules.get_object(room, "fixture:concealed_cache")
	check.call(DungeonPersistence.local_error(room).is_empty() and not LocalRoomSearchRules.known(cache, actor), "S237 discovery definitions load into valid room records, initially unknown")
	actor.ability_scores.wisdom = 50
	var result := LocalRoomSearchRules.search(room, actor, Vector2i.ZERO, grid, [actor, other])
	check.call(result.get("seconds") == 6 and result.get("found", []).is_empty() and not LocalRoomSearchRules.known(cache, actor), "S237 searching a different room space cannot find a hidden object")
	result = LocalRoomSearchRules.search(room, actor, Vector2i(2,1), grid, [actor, other])
	check.call(result.get("found", []).is_empty(), "S237 a remote object's authored vicinity is required even with a successful roll")
	cache.discovery.dc = 1000
	result = LocalRoomSearchRules.search(room, actor, Vector2i(-1,0), grid, [actor, other])
	check.call(result.seconds == 6 and result.found.is_empty() and not LocalRoomSearchRules.known(cache, actor), "S237 failed Perception costs one Action interval and cannot discover its object")
	cache.discovery.dc = 15
	cache["plane"] = "ethereal"
	result = LocalRoomSearchRules.search(room, actor, Vector2i(-1,0), grid, [actor, other])
	check.call(result.found.is_empty() and not LocalRoomSearchRules.known(cache, actor), "S237 a successful check cannot discover an object on another plane")
	cache.erase("plane")
	result = LocalRoomSearchRules.search(room, actor, Vector2i(-1,0), grid, [actor, other])
	check.call(result.get("found", []).size() == 1 and LocalRoomSearchRules.known(cache, actor) and not LocalRoomSearchRules.known(cache, other), "S237 real Perception discovers only the exact object for the actual searcher")
	var again := LocalRoomSearchRules.search(room, actor, Vector2i(-1,0), grid, [actor, other])
	check.call(again.found.is_empty() and cache.discovered_by == [actor.character_id], "S237 repeating Search never duplicates discovery receipts")
	check.call(LocalRoomRules.get_object(room, str(cache.id), other).is_empty() and not LocalRoomRules.interact(room, str(cache.id), "take", other, str(cache.contents[0].instance_id)).success, "S237 guessed object/copy identities cannot bypass another actor's missing discovery")
	grid.add_entity({"world_object":cache, "hex_position":Vector2i(-1,0)})
	check.call(CombatObjectRules.at(grid, Vector2i(-1,0), other).is_empty() and not CombatObjectRules.at(grid, Vector2i(-1,0), actor).is_empty() and CombatObjectRules.all_at(grid, Vector2i(-1,0)).size() == 1, "S237 direct combat targets honor discovery while untargeted physical/area queries retain real objects")
	var cast := SpellCastContext.new()
	cast.grid = grid; cast.caster = other
	check.call(not SpellCastTargeting.is_chain_target_selected(cast, Vector2i(-1,0), "object:" + str(cache.id)), "S237 forged unknown object identity refuses chain targeting before spell payment")
	var corrupt := room.duplicate(true)
	corrupt.objects[0].discovered_by.append(actor.character_id)
	check.call(not DungeonPersistence.local_error(corrupt).is_empty(), "S237 duplicated discovery observers refuse before load")
	corrupt = room.duplicate(true); corrupt.objects[0].discovery.range_feet = 0
	check.call(not DungeonPersistence.local_error(corrupt).is_empty(), "S237 malformed discovery ranges refuse before load")
	corrupt = room.duplicate(true); corrupt.objects[0].erase("discovery")
	check.call(not DungeonPersistence.local_error(corrupt).is_empty(), "S237 orphaned discovery receipts refuse before load")
	var old := room.duplicate(true)
	for object in old.objects: object.erase("discovery"); object.erase("discovered_by")
	check.call(DungeonPersistence.local_error(old).is_empty() and LocalRoomSearchRules.known(old.objects[0], other), "S237 legacy room objects need no discovery fields or migration")
	grid.get_tile(Vector2i.ZERO).custom_properties["ambient_illumination"] = "dim"
	check.call(CombatPerception.sight_is_lightly_obscured(actor, Vector2i.ZERO, grid, 0), "S237 dim light at the actor's own hex still obscures ordinary sight")
	var dim := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Perception", "dc":15}, {}, {"sense":"sight", "lightly_obscured":true})
	check.call(dim.disadvantage and dim.roll_mode == "disadvantage", "S237 sight Search uses actual Disadvantage in dim light")
	actor.darkvision_feet = 60
	check.call(not CombatPerception.sight_is_lightly_obscured(actor, Vector2i.ZERO, grid, 0), "S237 actual Darkvision treats dim light as bright for sight Search")
	grid.get_tile(Vector2i.ZERO).custom_properties.ambient_illumination = "dark"
	check.call(CombatPerception.sight_is_lightly_obscured(actor, Vector2i.ZERO, grid, 0), "S237 actual Darkvision treats darkness as dim for sight Search")
	actor.add_condition("blinded", 10)
	actor.feature_uses["creature_blindsight_range_feet"] = 5
	var secret := LocalRoomRules.get_object(room, "fixture:secret_door")
	var sensed := LocalRoomSearchRules.search(room, actor, Vector2i(1,-1), grid, [actor, other])
	check.call(sensed.get("found", []).size() == 1 and LocalRoomSearchRules.known(secret, actor) and not sensed.check.get("auto_failed", false), "S237 in-range Blindsight supplies actual sight to the Perception check while Blinded")
	secret.erase("discovered_by")
	actor.feature_uses["creature_blindsight_range_feet"] = 4
	sensed = LocalRoomSearchRules.search(room, actor, Vector2i(1,-1), grid, [actor, other])
	check.call(sensed.seconds == 0 and not LocalRoomSearchRules.known(secret, actor), "S237 out-of-range Blindsight cannot admit a Blinded Search")
	var unhosted := EventResolver.resolve_skill_check(actor, {"ability":"WIS", "skill":"Perception", "sense":"sight", "dc":15})
	check.call(unhosted.get("auto_failed", false), "S237 unhosted Blinded sight checks retain automatic failure")
	actor.remove_condition("blinded")
	grid.get_tile(Vector2i.ZERO).custom_properties["blocks_sight"] = true
	room.party_positions[other.character_id] = [2,0]
	result = LocalRoomSearchRules.search(room, other, Vector2i(-1,0), grid, [actor, other])
	check.call(result.seconds == 0 and not LocalRoomSearchRules.known(cache, other), "S237 blocked Search refuses before time or discovery")
	grid.free()


static func select_actor(view: LocalRoomView, index: int) -> void:
	view.actors.select(index)
	view.actors.item_selected.emit(index)


static func search(h: Node, view: LocalRoomView, position: Vector2i) -> void:
	view.search_button.pressed.emit()
	h._assert(not view.pending_search.is_empty(), "S237 actual room Search button opens an unpaid space choice")
	view.click(position)
	await h.get_tree().process_frame


static func visible(view: LocalRoomView, id: String) -> bool:
	for index in view.objects.item_count:
		if view.objects.get_item_metadata(index) == id: return true
	return false


static func spell_targets_hide(view: LocalRoomView, id: String) -> bool:
	var spells: OptionButton = view.panel.find_child("RoomSharedSpells", true, false)
	if spells == null: return false
	var selected := false
	for index in spells.item_count:
		if spells.get_item_metadata(index) == "fixture:search_spark": spells.select(index); spells.item_selected.emit(index); selected = true
	if not selected: return false
	var targets: OptionButton = view.panel.find_child("RoomSharedSpellTargets", true, false)
	for index in targets.item_count:
		if targets.get_item_metadata(index) == "object:" + id: return false
	return true


static func run(h: Node) -> void:
	h._enter_test("world_search_flow")
	h._setup_world()
	fixtures()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id":"ruins_of_ashvale"}
	GameManager.active_dungeon_state.clear()
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon._enter_local_room("1")
	var view := dungeon.local_view
	var actor := view.characters[0] as Character
	var other := view.characters[1] as Character
	other.known_spells.append("fixture:search_spark")
	h._own_class_spells(other)
	other.wizard_spellbook = other.wizard_spellbook.filter(func(id): return int(DataLoader.get_spell(str(id)).get("level", 0)) > 0)
	var definition := {"id":"search-objects", "objects":objects(), "party_spawns":[[0,0],[1,0]]}
	var loaded := LocalRoomRules.create(definition, [actor, other])
	view.state.objects.append_array(loaded.objects)
	view.state.party_positions[actor.character_id] = [0,0]
	view.state.party_positions[other.character_id] = [0,1]
	actor.ability_scores.wisdom = 50
	view.refresh()
	var cache := LocalRoomRules.get_object(view.state, "fixture:concealed_cache")
	var started := int(GameManager.campaign_elapsed_seconds)
	h._assert(not visible(view, str(cache.id)) and not view.grid.object_visible(cache) and CombatObjectRules.all_at(view.grid, Vector2i(-1,0)).has(cache), "S237 unknown objects are absent from actual room chooser/drawing but remain real physical objects")
	view.search_button.pressed.emit(); view.search_button.pressed.emit()
	h._assert(view.pending_search.is_empty() and int(GameManager.campaign_elapsed_seconds) == started, "S237 cancelled Search rolls nothing, spends no time and reveals nothing")
	select_actor(view, 1)
	other.known_spells.append("misty_step")
	view.refresh()
	var teleport: Button
	for child in view.action_row.get_children():
		if child is Button and child.text == "Misty Step": teleport = child
	if teleport != null:
		teleport.pressed.emit()
		view.search_button.pressed.emit()
		h._assert(view.pending_teleport_spell.is_empty() and not view.pending_search.is_empty(), "S237 switching actual Misty Step map choice to Search cancels the unpaid teleport")
		for child in view.action_row.get_children():
			if child is Button and child.text == "Misty Step": teleport = child
		teleport.pressed.emit()
		h._assert(view.pending_search.is_empty() and view.pending_teleport_spell == "misty_step", "S237 switching actual Search choice to Misty Step leaves only the newly requested operation armed")
		view.search_button.pressed.emit(); view.search_button.pressed.emit()
		h._assert(view.pending_search.is_empty() and view.pending_teleport_spell.is_empty() and int(GameManager.campaign_elapsed_seconds) == started, "S237 cancelling the replacement Search cannot leave an invisible spell choice or spend time")
	else: h._assert(false, "S237 actual Misty Step map-choice control is reachable")
	other.known_spells.erase("misty_step")
	select_actor(view, 0)
	view.search_button.pressed.emit()
	var completed := {"done":false}
	ReadyActionFlow._run(func(): await view.choose_save_exit([Vector2i(-1,0)], ["cancel", "one"]), completed)
	await h.get_tree().process_frame
	h._assert(view.pending_search.is_empty() and not view.pending_save_exit.is_empty(), "S237 required spell-exit choice takes over from Search without leaving a hidden map operation")
	view._finish_save_exit_choice("")
	await h.get_tree().process_frame
	h._assert(completed.done and view.pending_search.is_empty() and int(GameManager.campaign_elapsed_seconds) == started, "S237 cancelling the required-exit chooser cannot revive or charge the earlier Search")
	view.search_button.pressed.emit(); select_actor(view, 1)
	h._assert(view.pending_search.is_empty() and not LocalRoomSearchRules.known(cache, actor) and not LocalRoomSearchRules.known(cache, other), "S237 actor change cancels an old Search choice")
	select_actor(view, 0)
	view.state.party_positions[actor.character_id] = [0,0]; view.refresh()
	for kind in ["fog_cloud", "darkness"]:
		var now := int(GameManager.campaign_elapsed_seconds)
		LocalRoomAreas.add(view.state, kind, other.character_id, Vector2i(-1,0), 0, 60, 1, {"heavily_obscured":true})
		var area_id := str(view.state.areas[-1].id)
		view.refresh()
		await search(h, view, Vector2i(-1,0))
		h._assert(int(GameManager.campaign_elapsed_seconds) == now and not LocalRoomSearchRules.known(cache, actor), "S237 actual room-area sight blocks outside observer Search before time/discovery: " + kind)
		view.state.areas = view.state.areas.filter(func(area): return area.id != area_id)
		view.refresh()
	await search(h, view, Vector2i(0,1))
	h._assert(int(GameManager.campaign_elapsed_seconds) == started + 6 and not visible(view, str(cache.id)), "S237 wrong-space Search consumes its one real Action interval without revealing a cache elsewhere")
	await search(h, view, Vector2i(-1,0))
	h._assert(int(GameManager.campaign_elapsed_seconds) == started + 12 and visible(view, str(cache.id)) and view.grid.entities.any(func(entity): return entity.get("world_object", {}).get("id") == cache.id), "S237 actual Search click changes room chooser/board and advances six seconds once")
	view.click(Vector2i(-1,0))
	h._assert(int(GameManager.campaign_elapsed_seconds) == started + 12 and cache.discovered_by == [actor.character_id], "S237 repeated map click after Search cannot repeat its roll, cost or discovery")
	select_actor(view, 1)
	h._assert(not visible(view, str(cache.id)), "S237 switching to another actual room observer hides undiscovered object names and contents")
	h._assert(spell_targets_hide(view, str(cache.id)), "S237 actual shared object-spell target selector cannot expose another observer's undiscovered names/IDs")
	var containment_targets: OptionButton = view.panel.find_child("ContainmentCandidates", true, false)
	var hidden_in_containment := true
	for index in containment_targets.item_count:
		if containment_targets.get_item_metadata(index).get("id") == cache.id: hidden_in_containment = false
	h._assert(hidden_in_containment, "S237 actual containment candidate selector cannot expose another observer's undiscovered objects")
	select_actor(view, 0)
	view.state.party_positions[actor.character_id] = [0,0]
	view.refresh()
	view.objects.select(0)
	for index in view.objects.item_count:
		if view.objects.get_item_metadata(index) == cache.id: view.objects.select(index)
	view.objects.item_selected.emit(view.objects.selected)
	var take: Button
	for child in view.action_row.get_children():
		if child is Button and child.text == "Take": take = child
	var copy_id := str(cache.contents[0].instance_id)
	if take != null: take.pressed.emit()
	h._assert(take != null and not actor.inventory.get_instance(copy_id).is_empty() and cache.contents.is_empty(), "S237 discovered real cache permits the existing exact-item Take control")
	h._assert(not SaveManager.save_game("world_search_forbidden"), "S237 Search does not open a new active-room save checkpoint")
	# Preserve another renamed, discovered object for both checkpoint forms.
	view.state.party_positions[actor.character_id] = [2,0]; view.refresh()
	await search(h, view, Vector2i(2,1))
	var remote := LocalRoomRules.get_object(view.state, "fixture:renamed_cache")
	h._assert(LocalRoomSearchRules.known(remote, actor) and not LocalRoomSearchRules.known(remote, other), "S237 loaded renamed object uses the same discovery rule without ID registration")
	view.state.party_positions[actor.character_id] = view.state.exits[0].duplicate()
	dungeon._leave_local_room()
	dungeon.party_position = Vector2i.ZERO
	dungeon._save_dungeon_state_to_manager()
	h._assert(SaveManager.save_game(SLOT), "S237 allowed entrance checkpoint saves exact observer discovery")
	var dto := SaveManager._read_save(SLOT)
	dto.erase("party")
	h._assert(SaveManager._validate_save_data(dto).is_empty(), "S237 player-only discovery checkpoint passes the existing save preflight")
	var player_file := FileAccess.open(SaveManager.SAVE_DIR + PLAYER_SLOT + ".sav", FileAccess.WRITE)
	if player_file != null: player_file.store_string(JSON.stringify(dto)); player_file.close()
	h._assert(player_file != null, "S237 player-only discovery checkpoint is available to the fresh process")
	var manifest := FileAccess.open("user://world_search_expected.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"pid":OS.get_process_id(), "actor_id":actor.character_id, "other_id":other.character_id, "copy_id":copy_id, "clock":GameManager.campaign_elapsed_seconds, "discovery":remote.discovered_by}))
	manifest.close()
	h._teardown_scene(dungeon)
	h._exit_test()


static func reload(h: Node) -> void:
	h._enter_test("world_search_reload")
	fixtures()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://world_search_expected.json"))
	for slot in [SLOT, PLAYER_SLOT]:
		PlayerManager.reset()
		PartyManager.reset()
		GameManager.active_dungeon_state.clear()
		GameManager.campaign_elapsed_seconds = 0
		h._assert(OS.get_process_id() != int(expected.pid) and SaveManager.load_game(slot), "S237 discovery checkpoint loads into cleared state in a genuinely fresh process: " + slot)
		var actor := PlayerManager.get_player(0).character as Character
		var other := PlayerManager.get_player(1).character as Character
		var room: Dictionary = GameManager.active_dungeon_state.local_rooms["1"]
		var object := LocalRoomRules.get_object(room, "fixture:renamed_cache")
		h._assert(object.discovered_by == expected.discovery and LocalRoomSearchRules.known(object, actor) and not LocalRoomSearchRules.known(object, other), "S237 fresh load preserves observer-specific discovery without replay or global reveal")
		h._assert(not actor.inventory.get_instance(str(expected.copy_id)).is_empty() and LocalRoomRules.get_object(room, "fixture:concealed_cache").contents.is_empty() and int(GameManager.campaign_elapsed_seconds) == int(expected.clock), "S237 recovery retains exact taken copy and clock without replaying Search or Take")
		GameManager.current_state = GameManager.GameState.DUNGEON
		var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
		dungeon._enter_local_room("1")
		h._assert(visible(dungeon.local_view, str(object.id)), "S237 restored actual room controls offer the recovered searcher's discovery")
		select_actor(dungeon.local_view, 1)
		h._assert(not visible(dungeon.local_view, str(object.id)), "S237 restored actual room controls do not grant another observer's discovery")
		h._teardown_scene(dungeon)

	h._exit_test()
