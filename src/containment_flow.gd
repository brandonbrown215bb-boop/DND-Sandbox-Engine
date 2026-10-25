class_name ContainmentFlow
extends RefCounted

const SLOT := "containment_party"
const PLAYER_SLOT := "containment_players"
const MANIFEST := "user://containment_manifest.json"

static func fixtures() -> void:
	if DataLoader.get_race("fixture:living_chamber").is_empty(): DataLoader._load_json_file("res://data/fixtures/containment/races.json", "race")
	var room: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/containment/room.json"))
	# The existing entrance checkpoint can save this room without travelling bodies.
	DataLoader.campaigns.values()[0].dungeons["ruins_of_ashvale"].tactical_rooms["0"] = room

static func select(view: LocalRoomView, field: String, kind: String, id: String) -> bool:
	var picker: OptionButton = view.containment_row.find_child(field, true, false)
	if picker == null: return false
	for index in picker.item_count:
		var body: Dictionary = picker.get_item_metadata(index)
		if body.kind == kind and body.id == id:
			picker.select(index)
			return true
	return false

static func begin(view: LocalRoomView, ck: String, cid: String, ok: String, oid: String) -> ConfirmationDialog:
	if not select(view, "ContainmentContainers", ck, cid) or not select(view, "ContainmentCandidates", ok, oid): return null
	TetherGroupFlow.press(view, "Admit occupant")
	for child in view.panel.get_children():
		if child is ConfirmationDialog and not child.is_queued_for_deletion(): return child
	return null

static func accept(h: Node, view: LocalRoomView, ck: String, cid: String, ok: String, oid: String) -> void:
	var dialog := begin(view, ck, cid, ok, oid)
	h._assert(dialog != null, "S-170 real admission confirmation names exact bodies: " + oid + " " + ContainmentRules.admission_error(view.state, view.characters, view.actor(), ck, cid, ok, oid))
	if dialog != null:
		dialog.confirmed.emit()
		dialog.confirmed.emit()
	await h.get_tree().process_frame
	h._assert(ContainmentRules.relation(view.state, ok, oid).get("container_id") == cid, "S-170 clicked admission commits the exact occupant once: " + oid)

static func run(h: Node) -> void:
	h._enter_test("containment_flow")
	fixtures()
	h._setup_mixed_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	var actors := PartyManager.get_active_characters()
	var controller: Character = actors[0]
	var first: Character = actors[1]
	var second: Character = actors[2]
	var old_helper: Character = actors[3]
	var helper: Character = h._fresh_char("Living chamber", "fixture:renamed_chamber", "fighter", {"STR": 16, "DEX": 12, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10})
	helper.character_id = old_helper.character_id
	PartyManager.characters[helper.character_id] = helper
	PlayerManager.set_player_character(3, helper)
	h._assert(helper.containment == DataLoader.get_race("fixture:living_chamber").containment and ContainmentRules.policy_error(helper.containment).is_empty(), "S-170 neutral and renamed JSON creature capacities initialize without identity dispatch")
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon._enter_local_room("0")
	await h.get_tree().process_frame
	var view := dungeon.local_view
	var room := view.state
	var party := view.characters
	var a := LocalRoomRules.get_object(room, "chamber_a")
	var b := LocalRoomRules.get_object(room, "chamber_b")
	# Actual exact copies, one still owned by a creature and two placed in the room.
	var owned := Batch042Checks.add(first, "dagger")
	var owned_copy := first.inventory.get_instance(owned)
	owned_copy.state["s170_stamp"] = "owned by first"
	first.inventory.update_instance(owned_copy)
	var ground_ids := []
	for position in [Vector2i.ZERO, Vector2i(1, -1)]:
		var id := Batch042Checks.add(controller, "dagger")
		var copy := controller.inventory.get_instance(id)
		copy.state["s170_stamp"] = "exact room gear " + id
		copy.state["physical"] = {"size": "tiny"}
		controller.inventory.update_instance(copy)
		room.objects.append(LocalRoomRules.placed_item(room, controller.inventory.take_instance(id), position))
		ground_ids.append("placed:" + id)
	view.refresh()
	var before := room.duplicate(true)
	var dialog := begin(view, "object", "chamber_a", "character", first.character_id)
	h._assert(dialog != null, "S-170 real control opens an admission choice")
	if dialog != null:
		dialog.canceled.emit()
		dialog.confirmed.emit()
	h._assert(room == before, "S-170 cancelled and retained confirmation cannot commit")
	await h.get_tree().process_frame
	dialog = begin(view, "object", "chamber_a", "character", first.character_id)
	room.party_positions[first.character_id] = [2, 0]
	if dialog != null: dialog.confirmed.emit()
	h._assert(not ContainmentRules.active(room), "S-170 occupant moved during confirmation refuses")
	room.party_positions[first.character_id] = [-1, 1]
	await h.get_tree().process_frame
	dialog = begin(view, "object", "chamber_a", "character", first.character_id)
	view.actors.select(1)
	view.refresh()
	if dialog != null: dialog.confirmed.emit()
	h._assert(not ContainmentRules.active(room), "S-170 actor switch revokes the pending confirmation")
	view.actors.select(0)
	view.refresh()
	await h.get_tree().process_frame
	var captured := ContainmentRules.prepare(room, party, controller, "object", "chamber_a", "character", first.character_id)
	h._assert(not ContainmentRules.prepare(room, party, controller, "object", "chamber_a", "object", "chamber_a").success, "S-170 self containment refuses")
	var replacement := Character.new()
	replacement.from_dict(first.to_dict())
	var replaced := party.duplicate()
	replaced[replaced.find(first)] = replacement
	h._assert(not ContainmentRules.admit(room, replaced, controller, captured).success and not ContainmentRules.active(room), "S-170 same-ID replacement refuses a captured body instance")
	# All three positions must be represented, not merely mutually adjacent.
	var original: Dictionary = room.party_positions.duplicate(true)
	room.party_positions[controller.character_id] = [99, 99]
	room.party_positions[first.character_id] = [99, 100]
	a.position = [100, 99]
	h._assert(not ContainmentRules.prepare(room, party, controller, "object", "chamber_a", "character", first.character_id).success, "S-170 adjacent invented locations outside room geometry refuse")
	room.party_positions = original
	a.position = [-1, 0]
	first.feature_uses["plane"] = "ethereal"
	h._assert(not ContainmentRules.prepare(room, party, controller, "object", "chamber_a", "character", first.character_id).success, "S-170 cross-plane occupant refuses")
	first.feature_uses.erase("plane")
	var policy: Dictionary = a.containment.duplicate(true)
	a.containment.sizes = ["tiny"]
	h._assert(not ContainmentRules.prepare(room, party, controller, "object", "chamber_a", "character", first.character_id).success, "S-170 declared size eligibility refuses")
	a.containment = policy
	var cycle_room := room.duplicate(true)
	cycle_room.party_positions[first.character_id] = [0, 0]
	var nested := ContainmentRules.prepare(cycle_room, party, controller, "character", helper.character_id, "character", first.character_id)
	h._assert(ContainmentRules.admit(cycle_room, party, controller, nested).success and not ContainmentRules.prepare(cycle_room, party, controller, "character", first.character_id, "character", helper.character_id).success, "S-170 live admission rejects a containment cycle before commitment: " + str(nested.get("message", "")))
	await accept(h, view, "object", "chamber_a", "character", first.character_id)
	dialog = begin(view, "object", "chamber_a", "character", second.character_id)
	a.containment.capacity = 1
	if dialog != null: dialog.confirmed.emit()
	h._assert(ContainmentRules.occupants(room, "object", "chamber_a").size() == 1, "S-170 capacity shrunk during actual confirmation refuses atomically")
	a.containment.capacity = 2
	await h.get_tree().process_frame
	await accept(h, view, "object", "chamber_a", "character", second.character_id)
	h._assert(begin(view, "object", "chamber_a", "object", ground_ids[0]) == null and ContainmentRules.occupants(room, "object", "chamber_a").size() == 2, "S-170 a full multi-occupant container refuses an additional body")
	await accept(h, view, "object", "chamber_b", "object", ground_ids[1])
	await accept(h, view, "character", helper.character_id, "object", ground_ids[0])
	h._assert(ContainmentRules.occupants(room, "object", "chamber_a").size() == 2 and ContainmentRules.occupants(room, "object", "chamber_b").size() == 1 and ContainmentRules.occupants(room, "character", helper.character_id).size() == 1, "S-170 independent object and creature containers retain separate exact occupants")
	h._assert(not ContainmentRules.prepare(room, party, controller, "character", helper.character_id, "character", first.character_id).success, "S-170 duplicate occupancy refuses across independent containers")
	var physical := PhysicalFactsRules.get_location(first, {"room": room, "players": [{"character": first, "hex_position": Vector2i(-1, 1)}]})
	var ended: Dictionary = LocatedSourceEndRules.capture(first, {}, "probe").final_location
	h._assert(physical.get("location_kind") == "internal" and not physical.location_known and physical.position == null and physical.external_location.position == a.position and not ended.location_known, "S-170 accepted location and source-anchor queries never expose an internal body's entry cell")
	var inventory_before := first.inventory.to_dict()
	h._assert(not LocalRoomRules.transfer(room, first, controller, owned).success and first.inventory.to_dict() == inventory_before and first.inventory.get_instance(owned).state.s170_stamp == "owned by first", "S-170 creature admission retains gear ownership and blocks external gear transfer")
	var hp := int(a.hp)
	h._assert(CombatObjectRules.apply_damage(a, 1, "force") == 1 and int(a.hp) == hp - 1 and not LocalRoomRules.fire_bolt_object(room, "chamber_a", controller, view.grid).success, "S-171 external object damage preserves occupants; unsupported native cast still refuses")
	select(view, "ContainmentContainers", "object", "chamber_a")
	h._assert(TetherGroupFlow.press(view, "Inspect occupants") and view.hud.log_text.text.contains("2/2 occupants") and view.hud.log_text.text.contains(first.character_id) and view.hud.log_text.text.contains(second.character_id) and view.hud.log_text.text.contains(owned), "S-170 real inspection lists exact occupants, capacity and retained gear")
	# A contained body no longer occupies its remembered external entry cell.
	h._assert(LocalRoomRules.move(room, controller, Vector2i(-1, 1), view.grid, "walk", party).success, "S-170 internal occupant frees its former external room cell")
	room.party_positions[controller.character_id] = [0, 0]
	view.refresh()
	var invalid := room.duplicate(true)
	invalid.containment_occupants.append(invalid.containment_occupants[0].duplicate(true))
	h._assert(not DungeonPersistence.local_error(invalid).is_empty(), "S-170 room DTO rejects duplicate occupancy")
	invalid = room.duplicate(true)
	invalid.containment_occupants = [{"container_kind": "character", "container_id": first.character_id, "occupant_kind": "character", "occupant_id": helper.character_id}, {"container_kind": "character", "container_id": helper.character_id, "occupant_kind": "character", "occupant_id": first.character_id}]
	h._assert(not DungeonPersistence.local_error(invalid).is_empty(), "S-170 room DTO rejects multi-body cycles")
	var probe := room.duplicate(true)
	probe.containment_occupants = []
	probe.objects.append({"id": "ordinary_compartments", "kind": "container", "name": "Just inventory", "size": "large", "hp": 1, "position": [-1, 0], "contents": [], "capacity": 20})
	h._assert(not ContainmentRules.prepare(probe, party, controller, "object", "ordinary_compartments", "character", first.character_id).success, "S-170 ordinary inventory capacity never establishes creature containment")
	# A body becoming downed is still the same occupant; later release owns removal.
	first.take_damage(first.current_hp)
	h._assert(not first.is_alive and ContainmentRules.relation(room, "character", first.character_id).get("container_id") == "chamber_a" and ContainmentRules.room_error(room, party, true).is_empty(), "S-170 a downed existing occupant retains its exact saved relationship")
	# Switching scale at the entrance doesn't move or release any body.
	TetherGroupFlow.press(view, "Room map")
	await h.get_tree().process_frame
	h._assert(dungeon.local_view == null and GameManager.active_dungeon_state.get("save_checkpoint", false), "S-170 ordinary entrance control reaches the existing save checkpoint")
	var travel_origin := dungeon.party_position
	for target in dungeon.rooms.keys():
		if HexUtils.get_distance(travel_origin, target) == 1: dungeon._on_room_clicked(target); break
	GameManager.exit_dungeon()
	h._assert(dungeon.party_position == travel_origin and GameManager.current_state == GameManager.GameState.DUNGEON, "S-170 room travel and dungeon exit refuse to strand contained party bodies")
	var manifest := {"pid": OS.get_process_id(), "room_id": str(room.id), "rows": room.containment_occupants.duplicate(true), "actors": {}, "objects": room.objects.duplicate(true), "owned": owned, "first": first.character_id, "helper": helper.character_id}
	for actor in party: manifest.actors[actor.character_id] = {"inventory": actor.inventory.to_dict(), "containment": actor.containment.duplicate(true), "current_hp": actor.current_hp, "is_alive": actor.is_alive}
	h._assert(SaveManager.save_game(SLOT), "S-170 production entrance SaveManager checkpoint saves exact relationships")
	var saved := SaveManager._read_save(SLOT)
	h._assert(SaveManager._validate_save_data(saved).is_empty(), "S-170 full party DTO validates")
	var player_only := saved.duplicate(true)
	player_only.erase("party")
	h._assert(SaveManager._validate_save_data(player_only).is_empty(), "S-170 supported player-only DTO validates")
	var file := FileAccess.open(SaveManager.SAVE_DIR + PLAYER_SLOT + ".sav", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(player_only)); file.close()
	var bad := saved.duplicate(true)
	bad.party.characters[helper.character_id].containment.capacity = 0.5
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-170 malformed creature capacity refuses before restore")
	bad = saved.duplicate(true)
	bad.active_dungeon_state.local_rooms["0"].containment_occupants[0].occupant_id = "missing-body"
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-170 missing exact body refuses before restore")
	bad = saved.duplicate(true)
	bad.players[3].character.containment.capacity = 1
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-170 conflicting player and party body policies refuse")
	bad = saved.duplicate(true)
	# The player mirror is Small while the authoritative restored party body is Medium.
	bad.party.characters[first.character_id].race_id = "human"
	bad.players[1].character.race_id = "halfling"
	bad.active_dungeon_state.local_rooms["0"].containment_occupants = bad.active_dungeon_state.local_rooms["0"].containment_occupants.filter(func(r): return r.occupant_id != second.character_id)
	LocalRoomRules.get_object(bad.active_dungeon_state.local_rooms["0"], "chamber_a").containment.sizes = ["small"]
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-170 player mirror cannot hide an ineligible authoritative party body")
	bad = saved.duplicate(true)
	var object_room: Dictionary = bad.active_dungeon_state.local_rooms["0"]
	object_room.containment_occupants.append({"container_kind": "object", "container_id": "chamber_b", "occupant_kind": "object", "occupant_id": ground_ids[0]})
	object_room.containment_occupants = object_room.containment_occupants.filter(func(r): return r.container_kind != "character")
	h._assert(not DungeonPersistence.local_error(object_room).is_empty(), "S-170 standalone room DTO enforces object-only container capacity")
	bad = saved.duplicate(true)
	for map_room in bad.active_dungeon_state.rooms:
		if int(map_room.id) != 0:
			bad.active_dungeon_state.party_position = map_room.coord.duplicate()
			break
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-170 a party in another dungeon room cannot retain external access to contained bodies")
	file = FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(manifest)); file.close()
	h._teardown_scene(dungeon)
	for slot in [SLOT, PLAYER_SLOT]: h._assert(verify(manifest, slot), "S-170 same-process exact restore through " + slot)
	h._exit_test()

static func plain(value):
	return JSON.parse_string(JSON.stringify(value))

static func verify(manifest: Dictionary, slot: String) -> bool:
	if not SaveManager.load_game(slot): return false
	var room: Dictionary = GameManager.active_dungeon_state.get("local_rooms", {}).get("0", {})
	if room.get("containment_occupants") != manifest.rows or plain(room.get("objects")) != plain(manifest.objects): return false
	for id in manifest.actors:
		var actor: Character = PartyManager.characters.get(str(id))
		if actor == null or plain(actor.inventory.to_dict()) != plain(manifest.actors[id].inventory) or actor.containment != manifest.actors[id].containment: return false
		if actor.current_hp != int(manifest.actors[id].current_hp) or actor.is_alive != bool(manifest.actors[id].is_alive): return false
	var first: Character = PartyManager.characters.get(str(manifest.first))
	if first.inventory.get_instance(str(manifest.owned)).get("state", {}).get("s170_stamp") != "owned by first": return false
	if ContainmentRules.location(room, "character", first.character_id).get("kind") != "internal": return false
	if not ContainmentRules.room_error(room, PartyManager.characters.values(), true).is_empty(): return false
	return true
