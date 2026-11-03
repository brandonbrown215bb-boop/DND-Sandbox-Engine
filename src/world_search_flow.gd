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
	InfluenceFlow.logic(check)
	StudyFlow.logic(check)
	_world_help_and_hearing(check)
	var actor := PerceptionChecks.actor("searcher")
	var other := PerceptionChecks.actor("other_searcher")
	var data := {"id":"search-room", "name":"Search room", "cells":[[-1,0],[0,0],[1,0],[2,0],[2,1],[1,-1]], "walls":[], "exits":[[0,0]], "party_spawns":[[0,0],[1,0]], "monster_spawns":[], "encounter_monsters":[], "objects":objects()}
	var room := LocalRoomRules.create(data, [actor, other])
	var grid := PerceptionChecks.grid()
	var cache := LocalRoomRules.get_object(room, "fixture:concealed_cache")
	var remains := LocalRoomRules.get_object(room, "fixture:renamed_remains")
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
	remains.medical_search.dc = 1000
	var medical := LocalRoomSearchRules.search(room, actor, Vector2i.ZERO, grid, [actor, other], "medicine")
	check.call(medical.seconds == 6 and medical.check.check_context.skill == "Medicine" and medical.found.is_empty() and remains.get("medical_discovered_by", []).is_empty() and not medical.message.contains("puncture"), "OA05 failed Medicine Search pays the interval but discloses no source information")
	remains.medical_search.dc = 1
	medical = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, [actor, other], "medicine")
	check.call(medical.seconds == 6 and medical.found.is_empty() and remains.get("medical_discovered_by", []).is_empty(), "OA05 Medicine clue cannot be revealed from the wrong room space")
	remains.plane = "ethereal"
	medical = LocalRoomSearchRules.search(room, actor, Vector2i.ZERO, grid, [actor, other], "medicine")
	check.call(medical.seconds == 6 and medical.found.is_empty(), "OA05 Medicine clue cannot cross planes")
	remains.erase("plane"); room["containment_occupants"] = [{"occupant_kind":"object", "occupant_id":str(remains.id), "container_kind":"object", "container_id":"fixture:closed_container"}]
	medical = LocalRoomSearchRules.search(room, actor, Vector2i.ZERO, grid, [actor, other], "medicine")
	check.call(medical.seconds == 6 and medical.found.is_empty(), "OA05 contained remains are not an accessible local clue source")
	room["containment_occupants"] = []
	var saved_range := int(remains.medical_search.range_feet); remains.medical_search.range_feet = 5
	room.party_positions[actor.character_id] = [2,0]
	medical = LocalRoomSearchRules.search(room, actor, Vector2i.ZERO, grid, [actor, other], "medicine")
	check.call(medical.seconds == 6 and medical.found.is_empty(), "OA05 authored clue vicinity limits source access")
	room.party_positions[actor.character_id] = [0,0]; remains.medical_search.range_feet = saved_range
	medical = LocalRoomSearchRules.search(room, actor, Vector2i.ZERO, grid, [actor, other], "medicine")
	check.call(medical.check.check_context.skill == "Medicine" and medical.found == [remains.name] and medical.medical_information == [remains.medical_search.information] and actor.character_id in remains.medical_discovered_by and other.character_id not in remains.medical_discovered_by, "OA05 successful Medicine Search reveals the actual authored clue only to its observer")
	var malformed_medical := room.duplicate(true); malformed_medical.objects.back().medical_discovered_by = [actor.character_id, actor.character_id]
	check.call(not DungeonPersistence.local_error(malformed_medical).is_empty(), "OA05 duplicate medical observer receipts refuse persistence")
	malformed_medical = room.duplicate(true); malformed_medical.objects.back().medical_discovered_by = [actor.character_id]; malformed_medical.objects.back().erase("medical_search")
	check.call(not DungeonPersistence.local_error(malformed_medical).is_empty(), "OA05 orphaned medical observer receipts refuse persistence")
	var tracks := LocalRoomRules.get_object(room, "fixture:renamed_tracks")
	tracks.tracks_search.dc = 1000
	var tracking := LocalRoomSearchRules.search(room, actor, Vector2i.ZERO, grid, [actor, other], "survival")
	check.call(tracking.seconds == 6 and tracking.check.check_context.skill == "Survival" and tracking.found.is_empty() and tracks.get("tracks_discovered_by", []).is_empty() and not tracking.message.contains("Fresh bootprints"), "OA07 failed Survival Search pays once and discloses no track information")
	tracks.tracks_search.dc = 1
	tracking = LocalRoomSearchRules.search(room, actor, Vector2i.ZERO, grid, [actor, other], "survival")
	check.call(tracking.seconds == 6 and tracking.found.is_empty() and tracks.get("tracks_discovered_by", []).is_empty(), "OA07 track clue is not discoverable from a nearby but wrong room space")
	tracks["plane"] = "ethereal"
	tracking = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, [actor, other], "survival")
	check.call(tracking.seconds == 6 and tracking.found.is_empty(), "OA07 tracks on another plane are not accessible")
	tracks.erase("plane")
	room["containment_occupants"] = [{"occupant_kind":"object", "occupant_id":str(tracks.id), "container_kind":"object", "container_id":"fixture:closed_container"}]
	tracking = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, [actor, other], "survival")
	check.call(tracking.seconds == 6 and tracking.found.is_empty(), "OA07 contained track sources are inaccessible")
	room["containment_occupants"] = []
	tracking = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, [actor, other], "survival")
	check.call(tracking.seconds == 6 and tracking.check.check_context.skill == "Survival" and tracking.track_information == [tracks.tracks_search.information] and actor.character_id in tracks.tracks_discovered_by and other.character_id not in tracks.tracks_discovered_by, "OA07 correct source-space reveals only the authored track clue to the searcher")
	var malformed_tracks: Dictionary = room.duplicate(true)
	LocalRoomRules.get_object(malformed_tracks, "fixture:renamed_tracks").tracks_discovered_by = [actor.character_id, actor.character_id]
	check.call(not DungeonPersistence.local_error(malformed_tracks).is_empty(), "OA07 duplicate track observer receipts refuse persistence")
	malformed_tracks = room.duplicate(true)
	LocalRoomRules.get_object(malformed_tracks, "fixture:renamed_tracks").erase("tracks_search")
	check.call(not DungeonPersistence.local_error(malformed_tracks).is_empty(), "OA07 orphaned track observer receipts refuse persistence")
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


static func _world_help_and_hearing(check: Callable) -> void:
	var actor := PerceptionChecks.actor("room_recipient")
	var helper := PerceptionChecks.actor("room_helper")
	helper.skill_proficiencies.assign(["Perception", "Athletics", "Medicine"])
	helper.tool_proficiencies.assign(["Thieves' Tools"])
	actor.ability_scores.wisdom = 50
	var party := [actor, helper]
	var room := LocalRoomRules.create({"id":"hearing-room", "party_spawns":[[0,0],[0,1]], "objects":objects()}, party)
	var grid := PerceptionChecks.grid()
	for member in party: grid.add_entity({"character":member, "hex_position":LocalRoomRules.coord(room.party_positions[member.character_id])})
	grid.perception_participants = grid.entities.duplicate()
	var box := LocalRoomRules.get_object(room, "fixture:renamed_rattle")
	var granted := CheckHelpRules.grant_room(room, helper, actor, "skill", "Perception", party, grid)
	check.call(granted.get("seconds") == 6 and actor.combat_check_help.size() == 1, "S237 room Help grants only an owned proficiency for an adjacent live ally")
	var unrelated := EventResolver.resolve_skill_check(actor, {"ability":"STR", "skill":"Athletics"}, {}, LocalRoomSearchRules.check_context(room, actor, grid, party))
	check.call(unrelated.ordinary_help_sources.is_empty() and actor.combat_check_help.size() == 1, "S237 unrelated room checks preserve selected Help")
	actor.add_condition("blinded", 10)
	var found := LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party, "hearing")
	check.call(found.seconds == 6 and found.check.advantage and found.check.ordinary_help_sources.size() == 1 and actor.combat_check_help.is_empty() and LocalRoomSearchRules.known(box, actor) and not LocalRoomSearchRules.known(box, helper), "S237 hearing Search while Blinded consumes real Perception Help and discovers only for its observer")
	box.erase("discovered_by")
	actor.add_condition("deafened", 10)
	found = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party, "hearing")
	check.call(found.seconds == 6 and found.check.auto_failed and found.found.is_empty(), "S237 Deafened hearing Search actually fails and still costs the attempted Action")
	actor.remove_condition("deafened"); actor.remove_condition("blinded")
	grid.get_tile(Vector2i(1,0)).custom_properties["blocks_sound"] = true
	found = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party, "hearing")
	check.call(found.found.is_empty(), "S237 represented sound obstruction refuses hearing discovery even on a high check")
	grid.get_tile(Vector2i(1,0)).custom_properties["blocks_sound"] = false
	box.discovery.noise.range_feet = 4
	found = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party, "hearing")
	check.call(found.found.is_empty(), "S237 ongoing sound range is required independently of discovery vicinity")
	box.discovery.noise.range_feet = 10
	box.plane = "ethereal"
	found = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party, "hearing")
	check.call(found.found.is_empty(), "S237 hearing Search cannot reveal another plane")
	box.erase("plane")
	var visual := LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party)
	check.call(visual.found.is_empty(), "S237 visual Search cannot substitute for an authored hearing task")
	box.discovery.noise.volume = "invalid"
	check.call(not LocalRoomSearchRules.object_error(box).is_empty() and LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party, "hearing").seconds == 0, "S237 malformed audible discovery refuses before rolling or time")
	box.discovery.noise.volume = "whisper"
	CheckHelpRules.grant_room(room, helper, actor, "tool", "Thieves' Tools", party, grid)
	var tool_check := EventResolver.resolve_skill_check(actor, {"ability":"DEX", "skill":"Sleight of Hand", "tool_id":"thieves_tools"}, {}, LocalRoomSearchRules.check_context(room, actor, grid, party))
	check.call(tool_check.advantage and tool_check.ordinary_help_sources.size() == 1, "S237 room tool Help matches the actual tool ID through the shared check owner")
	CheckHelpRules.grant_room(room, helper, actor, "skill", "Perception", party, grid)
	room.party_positions[helper.character_id] = [4,0]
	found = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party, "hearing")
	check.call(found.check.ordinary_help_sources.is_empty(), "S237 a moved helper cannot supply stale room assistance")
	room.party_positions[helper.character_id] = [0,1]
	actor.combat_check_help.clear()
	CheckHelpRules.grant_room(room, helper, actor, "skill", "Perception", party, grid)
	actor.combat_check_help[0].expires_at_seconds = int(GameManager.campaign_elapsed_seconds)
	found = LocalRoomSearchRules.search(room, actor, Vector2i(1,0), grid, party, "hearing")
	check.call(found.check.ordinary_help_sources.is_empty() and actor.combat_check_help.is_empty(), "S237 unused world Help expires at the next represented interval boundary")
	box["discovered_by"] = [actor.character_id]
	room.party_altitudes[actor.character_id] = 20
	var airborne := CombatNoiseRules.room_interact(room, actor, party, grid, str(box.id), "force_open")
	check.call(airborne.seconds == 0 and not airborne.has("noise"), "S237 flying above an object cannot force it or emit a paid interaction sound")
	room.party_altitudes[actor.character_id] = 0
	var noise := CombatNoiseRules.room_interact(room, actor, party, grid, str(box.id), "force_open")
	check.call(not noise.success and noise.seconds == 6 and noise.noise.volume == "loud" and helper.character_id in noise.heard_by, "S237 paid failed room forcing emits its declared sound to actual listeners")
	box.interaction_noise.force_open.volume = "invalid"
	noise = CombatNoiseRules.room_interact(room, actor, party, grid, str(box.id), "force_open")
	check.call(noise.seconds == 0 and not noise.has("noise"), "S237 malformed operation sound refuses before the real check or cost")
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
	await StudyFlow.room_controls(h, view)
	await _room_controls(h, view)
	view.state.party_positions[actor.character_id] = view.state.exits[0].duplicate()
	dungeon._leave_local_room()
	h._assert(actor.combat_check_help.is_empty(), "S237 leaving the room clears unused world Help before any checkpoint")
	dungeon.party_position = Vector2i.ZERO
	dungeon._save_dungeon_state_to_manager()
	h._assert(SaveManager.save_game(SLOT), "S237 allowed entrance checkpoint saves exact observer discovery")
	var dto := SaveManager._read_save(SLOT)
	var corrupt_study := dto.duplicate(true)
	for object in corrupt_study.active_dungeon_state.local_rooms["1"].objects:
		if object.get("id") == "fixture:survey_stone": object.studied_by.spiral.append(actor.character_id)
	h._assert(not SaveManager._validate_save_data(corrupt_study).is_empty(), "S237 malformed Study receipts refuse full save preflight before session replacement")
	dto.erase("party")
	h._assert(SaveManager._validate_save_data(dto).is_empty(), "S237 player-only discovery checkpoint passes the existing save preflight")
	var player_file := FileAccess.open(SaveManager.SAVE_DIR + PLAYER_SLOT + ".sav", FileAccess.WRITE)
	if player_file != null: player_file.store_string(JSON.stringify(dto)); player_file.close()
	h._assert(player_file != null, "S237 player-only discovery checkpoint is available to the fresh process")
	var manifest := FileAccess.open("user://world_search_expected.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"pid":OS.get_process_id(), "actor_id":actor.character_id, "other_id":other.character_id, "copy_id":copy_id, "clock":GameManager.campaign_elapsed_seconds, "discovery":remote.discovered_by, "medical_information":LocalRoomRules.get_object(view.state, "fixture:renamed_remains").medical_search.information, "medical_discovered_by":LocalRoomRules.get_object(view.state, "fixture:renamed_remains").medical_discovered_by.duplicate(), "tracks_information":LocalRoomRules.get_object(view.state, "fixture:renamed_tracks").tracks_search.information, "tracks_discovered_by":LocalRoomRules.get_object(view.state, "fixture:renamed_tracks").tracks_discovered_by.duplicate(), "recollections":actor.known_recollections.duplicate(true)}))
	manifest.close()
	h._teardown_scene(dungeon)
	h._exit_test()


static func _room_controls(h: Node, view: LocalRoomView) -> void:
	var actor := view.characters[0] as Character
	var helper := view.characters[1] as Character
	view.state.party_positions[actor.character_id] = [1,1]
	view.state.party_positions[helper.character_id] = [2,1]
	helper.skill_proficiencies.assign(["Perception", "Athletics", "Medicine"])
	select_actor(view, 1)
	for index in view.help_choices.item_count:
		if view.help_choices.get_item_metadata(index).name == "Perception": view.help_choices.select(index)
	view.help_recipients.select(0)
	var started := int(GameManager.campaign_elapsed_seconds)
	h._assert(actor.combat_check_help.is_empty() and int(GameManager.campaign_elapsed_seconds) == started, "S237 choosing Help proficiency/recipient is unpaid")
	view.help_button.pressed.emit()
	h._assert(int(GameManager.campaign_elapsed_seconds) == started + 6 and actor.combat_check_help.size() == 1, "S237 actual room Help button grants matching assistance and pays six seconds once")
	select_actor(view, 0)
	actor.add_condition("blinded", 10)
	view.search_sense.select(1); view.search_sense.item_selected.emit(1)
	await search(h, view, Vector2i(1,0))
	var box := LocalRoomRules.get_object(view.state, "fixture:renamed_rattle")
	h._assert(int(GameManager.campaign_elapsed_seconds) == started + 12 and actor.combat_check_help.is_empty() and LocalRoomSearchRules.known(box, actor) and not LocalRoomSearchRules.known(box, helper), "S237 actual Listen Search consumes Help through the shared check and reveals only to its Blinded searcher")
	actor.remove_condition("blinded")
	var remains := LocalRoomRules.get_object(view.state, "fixture:renamed_remains")
	remains.medical_search.dc = 1000
	view.search_sense.select(2); view.search_sense.item_selected.emit(2)
	var medical_started := int(GameManager.campaign_elapsed_seconds)
	await search(h, view, Vector2i.ZERO)
	h._assert(int(GameManager.campaign_elapsed_seconds) == medical_started + 6 and remains.get("medical_discovered_by", []).is_empty() and not view.knowledge.text.contains("puncture"), "OA05 actual Medicine control charges one failed check and keeps the clue hidden")
	remains.medical_search.dc = 1
	select_actor(view, 1)
	for index in view.help_choices.item_count:
		if view.help_choices.get_item_metadata(index).name == "Medicine": view.help_choices.select(index)
	view.help_recipients.select(0)
	view.help_button.pressed.emit()
	select_actor(view, 0)
	view.search_sense.select(2); view.search_sense.item_selected.emit(2)
	medical_started = int(GameManager.campaign_elapsed_seconds)
	await search(h, view, Vector2i.ZERO)
	h._assert(int(GameManager.campaign_elapsed_seconds) == medical_started + 6 and actor.combat_check_help.is_empty() and actor.character_id in remains.get("medical_discovered_by", []) and "A narrow puncture wound caused the death." in view.hud.log_text.text and view.knowledge.text.contains("A narrow puncture wound caused the death."), "OA05 real control consumes matching Medicine Help once, pays once and discloses the authored cause: " + str(view.last_action_result.get("message", "")))
	var tracks := LocalRoomRules.get_object(view.state, "fixture:renamed_tracks")
	tracks.tracks_search.dc = 1000
	view.search_sense.select(3); view.search_sense.item_selected.emit(3)
	var tracks_started := int(GameManager.campaign_elapsed_seconds)
	view.search_button.pressed.emit(); view.search_button.pressed.emit()
	h._assert(int(GameManager.campaign_elapsed_seconds) == tracks_started and tracks.get("tracks_discovered_by", []).is_empty(), "OA07 cancelling the actual Survival Search chooser costs nothing")
	await search(h, view, Vector2i(1,0))
	h._assert(int(GameManager.campaign_elapsed_seconds) == tracks_started + 6 and tracks.get("tracks_discovered_by", []).is_empty() and not view.knowledge.text.contains("Fresh bootprints"), "OA07 actual Survival selector charges a failed check without clue disclosure")
	tracks.tracks_search.dc = 1
	tracks_started = int(GameManager.campaign_elapsed_seconds)
	await search(h, view, Vector2i.ZERO)
	h._assert(int(GameManager.campaign_elapsed_seconds) == tracks_started + 6 and tracks.get("tracks_discovered_by", []).is_empty(), "OA07 wrong source space consumes time but cannot disclose the track clue")
	helper.skill_proficiencies.append("Survival")
	select_actor(view, 1)
	for index in view.help_choices.item_count:
		if view.help_choices.get_item_metadata(index).name == "Survival": view.help_choices.select(index)
	view.help_recipients.select(0)
	view.help_button.pressed.emit()
	select_actor(view, 0)
	view.search_sense.select(3); view.search_sense.item_selected.emit(3)
	tracks_started = int(GameManager.campaign_elapsed_seconds)
	await search(h, view, Vector2i(1,0))
	h._assert(int(GameManager.campaign_elapsed_seconds) == tracks_started + 6 and actor.combat_check_help.is_empty() and actor.character_id in tracks.get("tracks_discovered_by", []) and helper.character_id not in tracks.get("tracks_discovered_by", []) and "Fresh bootprints head toward the eastern passage." in view.hud.log_text.text and view.knowledge.text.contains("Fresh bootprints head toward the eastern passage."), "OA07 actual Survival control consumes matching Help and reveals only the authored clue")
	view.search_button.pressed.emit()
	tracks.tracks_search.information = "Changed while the map choice was open."
	tracks_started = int(GameManager.campaign_elapsed_seconds)
	view.click(Vector2i(1,0))
	h._assert(int(GameManager.campaign_elapsed_seconds) == tracks_started and view.last_action_result.message.contains("stale") and not view.hud.log_text.text.contains("Changed while the map choice was open."), "OA07 stale track source refuses before payment or disclosure")
	tracks.tracks_search.information = "Fresh bootprints head toward the eastern passage."
	view.search_sense.select(2); view.search_sense.item_selected.emit(2)
	view.search_button.pressed.emit()
	remains.removed = true
	medical_started = int(GameManager.campaign_elapsed_seconds)
	var stale_log_start := view.hud.log_text.text.length()
	view.click(Vector2i.ZERO)
	h._assert(int(GameManager.campaign_elapsed_seconds) == medical_started and view.last_action_result.message.contains("stale") and not view.hud.log_text.text.substr(stale_log_start).contains("puncture"), "OA05 removed exact source refuses before payment or disclosure")
	remains.removed = false
	view.refresh()
	view.search_sense.select(0); view.search_sense.item_selected.emit(0)
	select_actor(view, 1)
	for index in view.help_choices.item_count:
		if view.help_choices.get_item_metadata(index).name == "Athletics": view.help_choices.select(index)
	view.help_recipients.select(0)
	view.help_button.pressed.emit()
	select_actor(view, 0)
	for index in view.objects.item_count:
		if view.objects.get_item_metadata(index) == box.id: view.objects.select(index)
	view.objects.item_selected.emit(view.objects.selected)
	var force_started := int(GameManager.campaign_elapsed_seconds)
	var force: Button
	for child in view.action_row.get_children():
		if child is Button and child.text == "Force open": force = child
	if force != null: force.pressed.emit()
	h._assert(force != null and int(GameManager.campaign_elapsed_seconds) == force_started + 6 and not box.open and actor.combat_check_help.is_empty() and "Loud sound; heard by" in view.hud.log_text.text, "S237 actual loud failed room object attempt consumes matching Help, pays once, reports actual listeners and retains the closed object")
	CheckHelpRules.grant_room(view.state, helper, actor, "skill", "Perception", view.characters, view.grid)
	h._assert(actor.combat_check_help.size() == 1, "S237 unused room assistance is present before room exit")


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
		var audible := LocalRoomRules.get_object(room, "fixture:renamed_rattle")
		var medical_source := LocalRoomRules.get_object(room, "fixture:renamed_remains")
		var study_source := LocalRoomRules.get_object(room, "fixture:survey_stone")
		var track_source := LocalRoomRules.get_object(room, "fixture:renamed_tracks")
		h._assert(track_source.tracks_discovered_by == expected.tracks_discovered_by and actor.character_id in track_source.tracks_discovered_by and other.character_id not in track_source.tracks_discovered_by and track_source.tracks_search.information == expected.tracks_information, "OA07 allowed checkpoints recover the exact observer's authored track clue without reroll or replay")
		h._assert(StudyRules.known(study_source, actor, "spiral") and not StudyRules.known(study_source, other, "spiral") and not StudyRules.known(study_source, actor, "age") and study_source.studied_by.spiral.size() == 1, "S237 fresh-process checkpoint restores exact Study source/question/observer without rerolls or failed-answer leaks")
		h._assert(actor.known_recollections == expected.recollections and StudyRules.recollection_known(room, actor, "memory") and not StudyRules.recollection_known(room, other, "memory"), "OA-10 full-party/player-only checkpoint recovers recollection facts for the exact observer without replay")
		h._assert(LocalRoomSearchRules.known(audible, actor) and not LocalRoomSearchRules.known(audible, other) and actor.combat_check_help.is_empty(), "S237 hearing discovery recovers for its exact observer while unused Help never becomes save state")
		h._assert(medical_source.medical_discovered_by == expected.medical_discovered_by and actor.character_id in medical_source.medical_discovered_by and other.character_id not in medical_source.medical_discovered_by and medical_source.medical_search.information == expected.medical_information, "OA05 allowed checkpoint retains the authored clue receipt and text for its exact observer without replay")
		h._assert(not actor.inventory.get_instance(str(expected.copy_id)).is_empty() and LocalRoomRules.get_object(room, "fixture:concealed_cache").contents.is_empty() and int(GameManager.campaign_elapsed_seconds) == int(expected.clock), "S237 recovery retains exact taken copy and clock without replaying Search or Take")
		GameManager.current_state = GameManager.GameState.DUNGEON
		var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
		dungeon._enter_local_room("1")
		h._assert(dungeon.local_view.knowledge.text.contains("ward against flame") and not dungeon.local_view.knowledge.text.contains("northern surveyors"), "S237 recovered actual room knowledge shows learned answers without replaying failed Study")
		h._assert(dungeon.local_view.knowledge.text.contains(expected.medical_information), "OA05 recovered room control shows the learned Medicine clue to its observer")
		h._assert(dungeon.local_view.knowledge.text.contains(expected.tracks_information), "OA07 recovered room control shows the learned Survival track clue to its observer")
		h._assert(visible(dungeon.local_view, str(object.id)), "S237 restored actual room controls offer the recovered searcher's discovery")
		select_actor(dungeon.local_view, 1)
		h._assert(not dungeon.local_view.knowledge.text.contains("ward against flame"), "S237 recovered room knowledge retains each observer's permission")
		h._assert(not dungeon.local_view.knowledge.text.contains(expected.medical_information), "OA05 recovered medical clue remains private to its observer")
		h._assert(not dungeon.local_view.knowledge.text.contains(expected.tracks_information), "OA07 recovered track clue remains private to its observer")
		h._assert(not visible(dungeon.local_view, str(object.id)), "S237 restored actual room controls do not grant another observer's discovery")
		h._teardown_scene(dungeon)

	h._exit_test()
