class_name ProjectedVesselFlow
extends RefCounted

const ITEM := "fixture:projected_vessel"
const CARGO := "fixture:vessel_cargo"
const MANIFEST := "user://projected_vessel_manifest.json"

static func fixtures() -> void:
	ContainmentReleaseFlow.fixtures()
	if DataLoader.get_item(ITEM).is_empty(): DataLoader._load_json_file("res://data/fixtures/projected_vessel/items.json", "item")

static func choose(h: Node, view: LocalRoomView, id: String, kind: String, hex: Vector2i = Vector2i(999, 999)) -> void:
	var menu := await ItemLifecycleControlsFlow.begin_room(h, view, id, kind)
	if menu == null: return
	var selected := 1
	if hex != Vector2i(999, 999):
		selected = -1
		for index in menu.item_count:
			if menu.get_item_text(index) == "Hex (%d, %d)" % [hex.x, hex.y]: selected = index
		h._assert(selected >= 0, "S-167 requested vessel cell is actually offered")
	if selected >= 0: await ItemLifecycleControlsFlow.press(h, menu, selected)

static func offer(view: LocalRoomView, id: String) -> bool:
	view.refresh()
	for i in view.item_lifecycle_offers.item_count:
		if view.item_lifecycle_offers.get_item_metadata(i).instance_id == id:
			view.item_lifecycle_offers.select(i); return true
	return false

static func cargo(owner: Character, id: String, stamp: String) -> String:
	var child := Batch042Checks.add(owner, CARGO)
	var copy := owner.inventory.get_instance(child)
	copy.state["cargo_stamp"] = stamp
	owner.inventory.update_instance(copy)
	ContainerRules.put(owner.inventory, id, child, "hold")
	return child

static func checkpoint(h: Node, dungeon: DungeonState, label: String, snapshots: Dictionary) -> void:
	var view := dungeon.local_view
	view.state.party_positions[view.characters[3].character_id] = [0, 0]
	view.actors.select(3); view.refresh()
	TetherGroupFlow.press(view, "Room map")
	await h.get_tree().process_frame
	var slot := "projected_vessel_" + label
	h._assert(dungeon.local_view == null and SaveManager.save_game(slot), "S-167 allowed entrance checkpoint: " + label)
	var saved := SaveManager._read_save(slot)
	h._assert(not saved.is_empty(), "S-167 checkpoint exists: " + label)
	if saved.is_empty(): return
	snapshots[slot] = {"room": saved.active_dungeon_state.local_rooms["0"], "actors": saved.party.characters, "time": GameManager.campaign_elapsed_seconds}
	var players := saved.duplicate(true)
	players.erase("party")
	h._assert(SaveManager._validate_save_data(players).is_empty(), "S-167 player-only checkpoint validates: " + label)
	var file := FileAccess.open(SaveManager.SAVE_DIR + slot + "_players.sav", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(players)); file.close()
	snapshots[slot + "_players"] = snapshots[slot]
	dungeon._enter_local_room("0")
	await h.get_tree().process_frame

static func verify(slot: String, expected: Dictionary) -> bool:
	if not SaveManager.load_game(slot): return false
	if ContainmentFlow.plain(GameManager.active_dungeon_state.local_rooms["0"]) != ContainmentFlow.plain(expected.room) or int(GameManager.campaign_elapsed_seconds) != int(expected.time): return false
	for id in expected.actors:
		var actor: Character = PartyManager.characters.get(str(id))
		if actor == null: return false
		var dto := actor.to_dict()
		if ContainmentFlow.plain(dto.inventory) != ContainmentFlow.plain(expected.actors[id].inventory) or ContainmentFlow.plain(dto.item_projections) != ContainmentFlow.plain(expected.actors[id].item_projections): return false
	return ContainmentRules.room_error(GameManager.active_dungeon_state.local_rooms["0"], PartyManager.characters.values(), true).is_empty()

static func edge_checks(h: Node, view: LocalRoomView) -> void:
	var owner := view.actor()
	var room := view.state
	owner.inventory.take_instance(str(owner.inventory.backpack_instances()[0].instance_id))
	var id := Batch042Checks.add(owner, "fixture:renamed_vessel")
	await choose(h, view, id, "project")
	var tombstone := {"id": "cargo_tombstone", "kind": "loose", "name": "Previous cargo location", "position": [3, 0], "removed": true, "contents": [], "hp": 1, "max_hp": 1, "fixed": false, "size": "tiny"}
	room.objects.append(tombstone)
	var children: Array = []
	for _i in 2:
		var child := Batch042Checks.add(owner, CARGO)
		var copy := owner.inventory.get_instance(child)
		copy.state["physical"] = {"size": "tiny", "room_id": str(room.id), "object_id": "cargo_tombstone"}
		owner.inventory.update_instance(copy)
		ContainerRules.put(owner.inventory, id, child, "hold")
		children.append(child)
	var before: Dictionary = owner.item_projections[id].duplicate(true)
	h._assert(not ItemProjectionRules.revert(owner, id).reverted and owner.item_projections[id] == before and tombstone.removed and tombstone.contents.is_empty(), "S-167 aliased ground object IDs refuse the whole ending before overwriting any exact cargo")
	h._assert(ContainerRules.remove(owner.inventory, id, children[1]).success, "S-167 aliased cargo remains available to unload normally")
	var result := ItemProjectionRules.revert(owner, id)
	h._assert(result.reverted and not tombstone.removed and tombstone.contents.size() == 1 and tombstone.contents[0].instance_id == children[0] and not owner.inventory.get_instance(children[1]).is_empty(), "S-167 cargo return reuses an empty pickup tombstone and preserves both copies")
	owner.inventory.take_instance(str(owner.inventory.backpack_instances()[0].instance_id))
	id = Batch042Checks.add(owner, ITEM)
	await choose(h, view, id, "project")
	var objects: Array = room.objects.duplicate()
	while room.objects.size() < 200:
		room.objects.append({"id": "empty:" + str(room.objects.size()), "kind": "loose", "name": "Empty", "position": [4, 0], "removed": true, "contents": [], "hp": 1, "max_hp": 1, "fixed": false})
	h._assert(ItemProjectionRules.revert(owner, id, -1, "reverted").get("destination") == "backpack", "S-167 a full room does not block an original returning to an available backpack slot")
	room.objects = objects

static func run(h: Node) -> void:
	h._enter_test("projected_vessel_flow")
	fixtures()
	h._setup_mixed_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon._enter_local_room("0")
	await h.get_tree().process_frame
	var view := dungeon.local_view
	var room := view.state
	var owner: Character = view.characters[0]
	var passenger: Character = view.characters[1]
	var second_passenger: Character = view.characters[2]
	var first := Batch042Checks.add(owner, ITEM)
	var second := Batch042Checks.add(owner, ITEM)
	var child := cargo(owner, first, "actual first cargo")
	var sibling_cargo := cargo(owner, second, "independent second cargo")
	var gear := Batch042Checks.add(passenger, CARGO)
	var gear_before := passenger.inventory.to_dict().duplicate(true)
	var first_copy := owner.inventory.get_instance(first).duplicate(true)
	h._assert(DataLoader.get_load_errors().is_empty(), "S-167 neutral/renamed data passes production loading")
	var policy: Dictionary = DataLoader.get_item(ITEM).actor_projection
	for patch in [{"on_dismissal": {"cargo": "recreate", "passengers": "release"}}, {"on_destruction": {"cargo": "release", "passengers": "retain"}}, {"on_reversion": {"cargo": "retain", "passengers": "retain"}}, {"containment": {}}]:
		var bad := policy.duplicate(true); bad.vessel.merge(patch, true)
		h._assert(not ItemProjectionRules.policy_error(bad).is_empty(), "S-167 invalid/missing/unsafe ending declaration refuses")
	await choose(h, view, first, "project", Vector2i(1, 0))
	await choose(h, view, second, "project", Vector2i(-1, 0))
	var form := ItemProjectionRules.actor(owner, first)
	var sibling := ItemProjectionRules.actor(owner, second)
	h._assert(form != null and sibling != null and form != sibling and owner.inventory.get_instance(first).is_empty() and owner.item_projections[first].copy.state.contents.hold[0].instance_id == child, "S-167 identical vessel copies keep distinct exact originals and cargo")
	if form == null or sibling == null: h._exit_test(); return
	room.party_positions[passenger.character_id] = [1, -1]
	room.party_positions[second_passenger.character_id] = [-1, 1]
	await ContainmentFlow.accept(h, view, "character", form.character_id, "character", passenger.character_id)
	await ContainmentFlow.accept(h, view, "character", sibling.character_id, "character", second_passenger.character_id)
	h._assert(not ContainmentRules.prepare(room, view.characters, owner, "character", form.character_id, "character", sibling.character_id).success, "S-167 vessels cannot be stowed as passenger bodies")
	# Production cargo transfer works while projected, using the same compartment.
	var loaded := Batch042Checks.add(owner, CARGO)
	offer(view, first)
	var cargo_items: OptionButton = view.item_lifecycle_row.find_child("VesselCargoItems", true, false)
	for i in cargo_items.item_count:
		if cargo_items.get_item_metadata(i) == loaded: cargo_items.select(i)
	TetherGroupFlow.press(view, "Stow cargo")
	h._assert(owner.inventory.get_instance(loaded).is_empty() and ContainerRules.contents(owner.inventory, first).size() == 2, "S-167 clicked load transfers the actual copy into the projected hold")
	view.exact_choice_menu = null
	offer(view, first); TetherGroupFlow.press(view, "Take out cargo")
	h._assert(view.exact_choice_menu != null and view.exact_choice_menu.item_count == 2, "S-167/068 Take out cargo with two held copies opens the exact cargo menu")
	# Batch 068: two cargo copies are held, so the exact menu opens; pick the loaded copy.
	var unload_options := ContainerRules.content_options(owner.inventory, first)
	if view.exact_choice_menu != null:
		for i in unload_options.size():
			if str(unload_options[i].instance_id) == loaded: view.exact_choice_menu.id_pressed.emit(i)
	h._assert(not owner.inventory.get_instance(loaded).is_empty() and ContainerRules.contents(owner.inventory, first)[0].instance_id == child, "S-167 clicked unload returns the selected vessel's exact cargo")
	# Stale move callback, then a real loaded movement through the shared path owner.
	view.refresh(); ContainmentFlow.select(view, "ContainmentContainers", "character", form.character_id)
	TetherGroupFlow.press(view, "Move container")
	view.refresh(); view.click(Vector2i(2, 0))
	h._assert(room.created_actor_positions[form.character_id] == [1, 0], "S-167 stale vessel movement refuses")
	ContainmentFlow.select(view, "ContainmentContainers", "character", form.character_id)
	TetherGroupFlow.press(view, "Move container")
	var before_time := int(GameManager.campaign_elapsed_seconds)
	view.click(Vector2i(2, 0))
	h._assert(room.created_actor_positions[form.character_id] == [2, 0] and ContainmentRules.external_location(room, "character", passenger.character_id, view.characters).position == [2, 0] and ContainerRules.contents(owner.inventory, first)[0].instance_id == child and GameManager.campaign_elapsed_seconds == before_time + 6, "S-167 actual loaded movement carries cargo/passenger identities at ordinary time cost")
	h._assert(not LocalRoomRules.move(room, passenger, Vector2i(2, -1), view.grid, "walk", view.characters).success and passenger.inventory.to_dict() == gear_before, "S-167 passenger remains a real body with its exact gear")
	var snapshots := {}
	await checkpoint(h, dungeon, "active", snapshots)
	view = dungeon.local_view; room = view.state
	var active_save := SaveManager._read_save("projected_vessel_active")
	form.current_hp -= 3
	var identity_hp := form.current_hp
	var invalid_save := active_save.duplicate(true)
	invalid_save.active_dungeon_state.local_rooms["0"].containment_occupants[0].occupant_id = "missing body"
	h._assert(not SaveManager._validate_save_data(invalid_save).is_empty() and SaveManager._validate_save_data(active_save).is_empty() and ItemProjectionRules.actor(owner, first) == form and form.current_hp == identity_hp, "S-167 valid/refused save preflight cannot replace or heal the live vessel body")
	var active_id: String = GameManager.active_dungeon_state.local_room_id
	GameManager.active_dungeon_state.local_room_id = "elsewhere"
	var remote_cargo := Batch042Checks.add(owner, CARGO)
	h._assert(not ContainerRules.put(owner.inventory, first, remote_cargo, "hold").success and not ContainerRules.remove(owner.inventory, first, child).success and not ItemProjectionRules.revert(owner, first).reverted, "S-167 remembered room coordinates never authorize remote cargo transfers or voluntary reversion")
	GameManager.active_dungeon_state.local_room_id = active_id
	# Existing room tombstones are reusable; physical size overrides still need
	# their actual footprint, and aliased planned IDs cannot overwrite one another.
	var cargo_copy: Dictionary = owner.item_projections[first].copy.state.contents.hold[0]
	var physical_before: Dictionary = cargo_copy.state.get("physical", {}).duplicate(true)
	cargo_copy.state["physical"] = {"size": "large"}
	room.walls = room.cells.filter(func(c): return LocalRoomRules.coord(c) not in [Vector2i(2, 0), Vector2i(2, -1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(-1, 0)])
	var blocked_record: Dictionary = owner.item_projections[first].duplicate(true)
	var blocked_relations: Array = room.containment_occupants.duplicate(true)
	h._assert(not ItemProjectionRules.revert(owner, first, -1, "dismissed").reverted and owner.item_projections[first] == blocked_record and room.containment_occupants == blocked_relations, "S-167 cargo physical-size override blocks the complete voluntary ending without moving passengers")
	room.walls = []
	cargo_copy.state["physical"] = physical_before
	if physical_before.is_empty(): cargo_copy.state.erase("physical")
	view.actors.select(0); view.refresh()
	await choose(h, view, first, "revert")
	var returned := owner.inventory.get_instance(first)
	h._assert(not returned.is_empty() and returned.state.contents == first_copy.state.contents and not ItemProjectionRules.is_projected(owner, first) and ContainmentRules.relation(room, "character", passenger.character_id).is_empty() and ItemProjectionRules.actor(owner, second) == sibling and sibling.is_alive and ContainerRules.contents(owner.inventory, second)[0].instance_id == sibling_cargo, "S-167 voluntary reversion retains exact cargo, legally releases passenger and leaves identical sibling alone")
	h._assert(passenger.inventory.to_dict() == gear_before and not passenger.inventory.get_instance(gear).is_empty(), "S-167 reversion never recreates passenger gear")
	# Full backpack returns the original onto legal ground; dismissal releases cargo.
	ItemFormReturnChecks.fill(owner)
	await choose(h, view, second, "dismiss")
	var ground := ItemFormReturnControls.find(room, second)
	h._assert(not ground.is_empty() and not ground.state.has("contents") and ItemFormReturnControls.find(room, sibling_cargo).get("state", {}).get("cargo_stamp") == "independent second cargo" and owner.inventory.backpack.size() == 40 and ContainmentRules.relation(room, "character", second_passenger.character_id).is_empty(), "S-167 full backpack dismissal places exact original, cargo and passenger separately")
	# A renamed surviving ground form can explicitly retain real passengers.
	owner.inventory.take_instance(str(owner.inventory.backpack_instances()[0].instance_id))
	var retained := Batch042Checks.add(owner, "fixture:retaining_vessel")
	room.party_positions[passenger.character_id] = [1, -1]
	await choose(h, view, retained, "project", Vector2i(1, 0))
	room.party_positions[passenger.character_id] = [1, -1]
	await ContainmentFlow.accept(h, view, "character", ItemProjectionRules.actor_id(retained), "character", passenger.character_id)
	await choose(h, view, retained, "revert")
	var retained_ground := LocalRoomRules.get_object(room, "placed:" + retained)
	h._assert(not retained_ground.is_empty() and ContainmentRules.relation(room, "character", passenger.character_id).container_kind == "object" and ContainmentRules.relation(room, "character", passenger.character_id).container_id == retained_ground.id and not LocalRoomRules.interact(room, str(retained_ground.id), "take", owner, retained).get("success", false), "S-167 retain passengers retargets actual graph to the surviving ground copy and prevents pickup")
	var release := ContainmentRules.prepare_release(room, view.characters, ContainmentRules.occupants(room, "object", str(retained_ground.id)))
	h._assert(release.success and ContainmentRules.commit_release(room, view.characters, release).success, "S-167 retained passengers disembark through ordinary legal release")
	# Destruction cannot partially release cargo while passengers have no space.
	owner.inventory.take_instance(str(owner.inventory.backpack_instances()[0].instance_id))
	var doomed := Batch042Checks.add(owner, "fixture:destroyed_vessel")
	var doomed_cargo := cargo(owner, doomed, "recover this same cargo")
	await choose(h, view, doomed, "project", Vector2i(1, 0))
	room.party_positions[passenger.character_id] = [1, -1]
	await ContainmentFlow.accept(h, view, "character", ItemProjectionRules.actor_id(doomed), "character", passenger.character_id)
	var doomed_body := ItemProjectionRules.actor(owner, doomed)
	ItemFormReturnChecks.fill(owner)
	ContainmentReleaseFlow.block(room, Vector2i(1, 0))
	view.refresh()
	doomed_body.take_damage(999)
	var pending_copy: Dictionary = owner.item_projections.get(doomed, {}).duplicate(true)
	var pending_rows: Array = room.containment_occupants.duplicate(true)
	for _i in 3: ItemProjectionRules.revert(owner, doomed); doomed_body.take_damage(999)
	h._assert(ItemProjectionRules.is_projected(owner, doomed) and not doomed_body.is_alive and owner.item_projections[doomed] == pending_copy and room.containment_occupants == pending_rows and ItemFormReturnControls.find(room, doomed_cargo).is_empty(), "S-167 blocked lethal release retains destroyed original, actual cargo and passenger without replay or partial settlement")
	await checkpoint(h, dungeon, "pending", snapshots)
	view = dungeon.local_view; room = view.state
	var bad_save := SaveManager._read_save("projected_vessel_pending")
	bad_save.active_dungeon_state.local_rooms["0"].created_actor_positions.erase(ItemProjectionRules.actor_id(doomed))
	h._assert(not SaveManager._validate_save_data(bad_save).is_empty(), "S-167 missing exact vessel location refuses before replacing live session")
	var saved_pending := SaveManager._read_save("projected_vessel_pending")
	for mutation in [func(d): d.party.characters[owner.character_id].item_projections[doomed].ending.overflow = -1, func(d): d.active_dungeon_state.local_rooms["0"].containment_occupants[0].container_id = "missing vessel", func(d): d.active_dungeon_state.local_rooms["0"].containment_occupants[0].release_pending.placement.range_hexes = 0, func(d): d.players[0].character.item_projections[doomed].copy.state.contents.hold[0].instance_id = doomed]:
		var invalid := saved_pending.duplicate(true)
		mutation.call(invalid)
		h._assert(not SaveManager._validate_save_data(invalid).is_empty() and owner.item_projections[doomed] == pending_copy and passenger.inventory.to_dict() == gear_before, "S-167 malformed pending source/identity/policy refuses without touching the live exact state")
	room.walls = []; view.actors.select(0); view.refresh()
	await choose(h, view, doomed, "dismiss")
	h._assert(not ItemProjectionRules.is_projected(owner, doomed) and owner.inventory.get_instance(doomed).is_empty() and ItemFormReturnControls.find(room, doomed).is_empty() and ItemFormReturnControls.find(room, doomed_cargo).get("state", {}).get("cargo_stamp") == "recover this same cargo" and ContainmentRules.relation(room, "character", passenger.character_id).is_empty() and passenger.inventory.to_dict() == gear_before, "S-167 recovered destruction releases exact cargo/passenger and destroys only the declared original")
	var before_room := room.duplicate(true)
	doomed_body.take_damage(999); ItemProjectionRules.revert(owner, doomed)
	h._assert(room == before_room, "S-167 repeated destruction cannot duplicate released cargo")
	view.actors.select(0); view.refresh()
	await edge_checks(h, view)
	await checkpoint(h, dungeon, "settled", snapshots)
	var manifest := {"pid": OS.get_process_id(), "snapshots": snapshots, "doomed": doomed, "cargo": doomed_cargo, "owner": owner.character_id, "passenger": passenger.character_id}
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(manifest)); file.close()
	h._teardown_scene(dungeon)
	for slot in snapshots: h._assert(verify(slot, snapshots[slot]), "S-167 exact checkpoint restores without admission/return replay: " + slot)
	h._exit_test()
