class_name ContainmentReleaseFlow
extends RefCounted

const MANIFEST := "user://containment_release_manifest.json"

static func fixtures() -> void:
	ContainmentFlow.fixtures()
	DataLoader._load_json_file("res://data/fixtures/containment/release_races.json", "race")
	DataLoader.campaigns.values()[0].dungeons["ruins_of_ashvale"].tactical_rooms["0"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/containment/release_room.json"))

static func admit(h: Node, view: LocalRoomView, ck: String, cid: String, ok: String, oid: String) -> void:
	view.actors.select(0)
	view.refresh()
	await ContainmentFlow.accept(h, view, ck, cid, ok, oid)

static func block(room: Dictionary, origin: Vector2i, keep: Array = []) -> void:
	room.walls = room.cells.filter(func(c): return LocalRoomRules.coord(c) != origin and LocalRoomRules.coord(c) not in keep)

static func release_dialog(view: LocalRoomView, kind: String, id: String) -> ConfirmationDialog:
	if not ContainmentFlow.select(view, "ContainmentContainers", kind, id): return null
	TetherGroupFlow.press(view, "Finish pending release")
	for child in view.panel.get_children():
		if child is ConfirmationDialog and child.name == "ContainmentRelease" and not child.is_queued_for_deletion(): return child
	return null

static func checkpoint(h: Node, dungeon: DungeonState, label: String, manifest: Dictionary) -> void:
	var view := dungeon.local_view
	view.state.party_positions[view.characters[3].character_id] = [0, 0]
	view.actors.select(3)
	view.refresh()
	TetherGroupFlow.press(view, "Room map")
	await h.get_tree().process_frame
	var slot := "containment_release_" + label
	h._assert(dungeon.local_view == null and SaveManager.save_game(slot), "S-172 existing entrance checkpoint: " + label)
	var save := SaveManager._read_save(slot)
	manifest[slot] = {"room": save.active_dungeon_state.local_rooms["0"], "time": GameManager.campaign_elapsed_seconds, "actors": save.party.characters}
	var players := save.duplicate(true)
	players.erase("party")
	h._assert(SaveManager._validate_save_data(players).is_empty(), "S-172 player-only release checkpoint validates")
	var file := FileAccess.open(SaveManager.SAVE_DIR + slot + "_players.sav", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(players)); file.close()
	manifest[slot + "_players"] = manifest[slot]
	dungeon._enter_local_room("0")
	await h.get_tree().process_frame

static func verify(slot: String, expected: Dictionary) -> bool:
	if not SaveManager.load_game(slot): return false
	if ContainmentFlow.plain(GameManager.active_dungeon_state.local_rooms["0"]) != ContainmentFlow.plain(expected.room) or int(GameManager.campaign_elapsed_seconds) != int(expected.time): return false
	for id in expected.actors:
		var actor: Character = PartyManager.characters.get(str(id))
		var dto: Dictionary = expected.actors[id]
		if actor == null or actor.current_hp != int(dto.current_hp) or ContainmentFlow.plain(actor.inventory.to_dict()) != ContainmentFlow.plain(dto.inventory) or ContainmentFlow.plain(actor.containment) != ContainmentFlow.plain(dto.containment): return false
	return ContainmentRules.room_error(GameManager.active_dungeon_state.local_rooms["0"], PartyManager.characters.values(), true).is_empty()

static func run(h: Node) -> void:
	h._enter_test("containment_release_flow")
	fixtures()
	h._setup_mixed_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	var party := PartyManager.get_active_characters()
	var carrier := h._fresh_char("Carrier", "fixture:renamed_moving_chamber", "fighter", {"STR": 18, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10}) as Character
	carrier.character_id = party[0].character_id
	PartyManager.characters[carrier.character_id] = carrier
	PlayerManager.set_player_character(0, carrier)
	party[0] = carrier
	var first: Character = party[1]
	var second: Character = party[2]
	var rescuer: Character = party[3]
	for actor in party: actor.max_hp = 200; actor.current_hp = 200
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon._enter_local_room("0")
	await h.get_tree().process_frame
	var view := dungeon.local_view
	var room := view.state
	h._assert(carrier.containment == JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/containment/release_policy.json")) and carrier.containment == DataLoader.get_race("fixture:moving_chamber").containment and ContainmentRules.policy_error(carrier.containment).is_empty(), "S-172 neutral/renamed JSON policies use the same owner")
	var gear := Batch042Checks.add(first, "dagger")
	var gear_before := first.inventory.to_dict().duplicate(true)
	var copy_id := Batch042Checks.add(carrier, "dagger")
	var copy := carrier.inventory.get_instance(copy_id)
	copy.state["physical"] = {"size": "tiny"}
	copy.state["release_stamp"] = "exact nested gear"
	carrier.inventory.update_instance(copy)
	var loose := LocalRoomRules.placed_item(room, carrier.inventory.take_instance(copy_id), Vector2i(-1, 0))
	loose.hp = 5; loose.max_hp = 5
	var inner := {"id": "renamed_inner", "name": "Nested chamber", "kind": "container", "size": "tiny", "position": [0, -1], "hp": 10, "max_hp": 10, "open": true, "contents": [], "containment": carrier.containment.duplicate(true)}
	room.objects.append(inner)
	room.objects.append(loose)
	room.party_positions[rescuer.character_id] = [3, 0]
	room.party_positions[first.character_id] = [-1, 1]
	room.party_positions[second.character_id] = [0, 1]
	await admit(h, view, "object", inner.id, "object", str(loose.id))
	await admit(h, view, "character", carrier.character_id, "character", first.character_id)
	await admit(h, view, "character", carrier.character_id, "character", second.character_id)
	await admit(h, view, "character", carrier.character_id, "object", inner.id)
	CombatObjectRules.apply_damage(inner, 100, "force", true)
	h._assert(ContainmentRules.relation(room, "object", inner.id).is_empty() and ContainmentRules.relation(room, "object", str(loose.id)).is_empty() and room.containment_occupants.size() == 2, "S-172 first nested destruction releases parent and children as one reserved batch")
	var destroyed_snapshot := room.duplicate(true)
	CombatObjectRules.settle_destruction(inner)
	h._assert(room == destroyed_snapshot, "S-172 repeated nested destruction cannot repeat the release")
	inner.hp = 10
	inner.position = [0, -1]
	loose.position = [-1, 0]
	await admit(h, view, "object", inner.id, "object", str(loose.id))
	await admit(h, view, "character", carrier.character_id, "object", inner.id)
	var rows: Array = room.containment_occupants.duplicate(true)
	var moved := LocalRoomRules.move(room, carrier, Vector2i(2, 0), view.grid, "walk", party)
	h._assert(moved.success and moved.movement_cost_feet == 10 and moved.seconds == 6 and room.containment_occupants == rows and ContainmentRules.external_location(room, "object", str(loose.id), party).position == [2, 0], "S-172 walking carries several actual occupants and nested relationships at the ordinary movement cost")
	h._assert(not LocalRoomRules.move(room, first, Vector2i(1, 0), view.grid, "walk", party).success, "S-172 internal occupants cannot move independently")
	var old_speed := carrier.speed
	carrier.speed = 1
	h._assert(not LocalRoomRules.move(room, carrier, Vector2i(-4, 0), view.grid, "walk", party).success and room.party_positions[carrier.character_id] == [2, 0], "S-172 carrying occupants never bypasses the ordinary Speed limit")
	carrier.speed = old_speed
	# Exact check confirmation retains the placement reservation as well as identities.
	var choice := ContainmentRules.prepare_check(room, party, first, "character", first.character_id, "escape")
	h._assert(choice.success and choice.release_plan.success, "S-172 escape reserves its release before rolling")
	var exit_hex: Vector2i = choice.release_plan.entries[0].hex
	room.walls.append([exit_hex.x, exit_hex.y])
	var before_time := int(GameManager.campaign_elapsed_seconds)
	h._assert(not ContainmentRules.attempt_check(room, party, first, choice).success and GameManager.campaign_elapsed_seconds == before_time and room.containment_occupants == rows, "S-172 stale release destination refuses before roll/time and preserves every relationship")
	room.walls = []
	view.actors.select(1); view.refresh()
	var dialog := ContainmentHarmFlow.dialog(view, first.character_id, "escape")
	h._assert(dialog != null, "S-172 production escape confirmation")
	if dialog != null: dialog.confirmed.emit(); dialog.confirmed.emit()
	await h.get_tree().process_frame
	h._assert(ContainmentRules.relation(room, "character", first.character_id).is_empty() and first.inventory.to_dict() == gear_before and GameManager.campaign_elapsed_seconds == before_time + 6, "S-172 exact escape releases gear/body and charges once")
	await admit(h, view, "character", carrier.character_id, "character", first.character_id)
	view.actors.select(3); view.refresh()
	dialog = ContainmentHarmFlow.dialog(view, second.character_id, "rescue")
	h._assert(dialog != null, "S-172 distinct rescuer uses normal confirmation")
	if dialog != null: dialog.confirmed.emit(); dialog.confirmed.emit()
	await h.get_tree().process_frame
	h._assert(ContainmentRules.relation(room, "character", second.character_id).is_empty(), "S-172 rescue releases only its selected occupant")
	await admit(h, view, "character", carrier.character_id, "character", second.character_id)
	# Ordinary room-map travel must carry the same graph and room-local object instances.
	var origin := dungeon.party_position
	var neighbor := origin
	for coordinate in dungeon.rooms:
		if HexUtils.get_distance(origin, coordinate) == 1: neighbor = coordinate; break
	var destination_id := str(dungeon.rooms[neighbor].id)
	var definition: Dictionary = room.duplicate(true)
	definition.id = "fixture:destination_chamber"
	definition.objects = []
	definition.party_spawns = [[0, 0], [-1, 0], [0, 1], [1, 0]]
	definition.cells = definition.cells.filter(func(c): return LocalRoomRules.coord(c) != Vector2i(-1, 1) and LocalRoomRules.coord(c) != Vector2i(0, -1))
	definition.erase("containment_occupants")
	dungeon.dungeon_data.tactical_rooms[destination_id] = definition
	room.party_positions[rescuer.character_id] = [0, 0]
	view.actors.select(3); view.refresh()
	TetherGroupFlow.press(view, "Room map")
	await h.get_tree().process_frame
	before_time = int(GameManager.campaign_elapsed_seconds)
	dungeon._on_room_clicked(neighbor)
	await h.get_tree().process_frame
	h._assert(dungeon.party_position == neighbor and GameManager.campaign_elapsed_seconds == before_time + 60 and room.containment_occupants.is_empty() and is_same(LocalRoomRules.get_object(dungeon.local_view.state, inner.id), inner) and ContainmentRules.relation(dungeon.local_view.state, "object", str(loose.id)).container_id == inner.id, "S-172 represented room travel carries actual nested objects, gear and relations once")
	h._assert(DungeonPersistence.local_error(dungeon.local_view.state).is_empty(), "S-172 different destination geometry retains a valid checkpoint DTO for internal remembered cells")
	view = dungeon.local_view
	view.actors.select(3); view.state.party_positions[rescuer.character_id] = [0, 0]; view.refresh()
	TetherGroupFlow.press(view, "Room map")
	await h.get_tree().process_frame
	dungeon._on_room_clicked(origin)
	await h.get_tree().process_frame
	view = dungeon.local_view; room = view.state
	h._assert(dungeon.party_position == origin and is_same(LocalRoomRules.get_object(room, inner.id), inner) and room.containment_occupants.size() == 4, "S-172 return travel neither copies nor readmits bodies")
	view.refresh()
	h._assert(LocalRoomRules.move(room, carrier, Vector2i(2, 0), view.grid, "walk", party).success, "S-172 returning carrier can move away from the entrance")
	# Refuse stops the check before rolling; defer retains the receipt instead.
	var primary := LocalRoomRules.coord(room.party_positions[carrier.character_id])
	block(room, primary)
	carrier.containment.release.no_space = "refuse"
	var blocked := ContainmentRules.prepare_check(room, party, first, "character", first.character_id, "escape")
	var blocked_result := ContainmentRules.attempt_check(room, party, first, blocked)
	h._assert(not blocked_result.success and not blocked_result.get("attempted", false) and not ContainmentRules.relation(room, "character", first.character_id).has("release_pending"), "S-172 authored refusal preserves the relationship without check or cost")
	carrier.containment.release.no_space = "defer"
	block(room, primary, [primary + Vector2i(2, 0)])
	var fallback := ContainmentRules.prepare_release(room, party, [ContainmentRules.relation(room, "character", first.character_id)])
	h._assert(fallback.success and fallback.entries[0].range == 2, "S-172 exhausted primary range uses only the authored wider fallback")
	room.walls = []
	# An expiry is authored on the actual container, saved before it fires.
	carrier.containment["expires_at_seconds"] = int(GameManager.campaign_elapsed_seconds) + 12
	var manifest := {"pid": OS.get_process_id(), "snapshots": {}}
	await checkpoint(h, dungeon, "active", manifest.snapshots)
	view = dungeon.local_view; room = view.state
	h._assert(not SaveManager.get_save_block_reason().is_empty(), "S-172 local-room release does not add a mid-activity checkpoint")
	var root := LocalRoomRules.coord(room.party_positions[carrier.character_id])
	block(room, root, [root + Vector2i(1, 0)])
	GameManager.advance_campaign_time(12)
	h._assert(ContainmentRules.occupants(room, "character", carrier.character_id).size() == 3 and ContainmentRules.occupants(room, "character", carrier.character_id).all(func(r): return r.get("release_pending", {}).get("reason") == "expiry"), "S-172 one remaining destination cannot partially release an expiring group")
	var pending: Array = room.containment_occupants.duplicate(true)
	CombatAction.resolve_damage(carrier, 1000, "force")
	ContainmentRules.advance_internal_damage(room, party, int(GameManager.campaign_elapsed_seconds))
	ContainmentRules.settle_character_loss(carrier)
	h._assert(room.containment_occupants == pending and first.inventory.to_dict() == gear_before and not first.inventory.get_instance(gear).is_empty(), "S-172 repeated expiry preserves pending receipts and exact gear")
	h._assert(ContainmentRules.admission_error(room, party, rescuer, "character", carrier.character_id, "character", rescuer.character_id).contains("expired"), "S-172 expired containers cannot admit new occupants")
	await checkpoint(h, dungeon, "pending", manifest.snapshots)
	view = dungeon.local_view; room = view.state
	var malformed := SaveManager._read_save("containment_release_pending")
	malformed.active_dungeon_state.local_rooms["0"].containment_occupants.filter(func(r): return r.has("release_pending"))[0].release_pending.placement.range_hexes = 0
	h._assert(not SaveManager._validate_save_data(malformed).is_empty(), "S-172 malformed durable release policy refuses checkpoint preflight")
	room.walls = []
	view.refresh()
	var plan := ContainmentRules.prepare_release(room, party, ContainmentRules.occupants(room, "character", carrier.character_id))
	h._assert(plan.success and plan.entries.size() == 3, "S-172 pending batch reserves all legal footprints")
	if plan.success:
		exit_hex = plan.entries[2].hex
		room.walls.append([exit_hex.x, exit_hex.y])
		h._assert(not ContainmentRules.commit_release(room, party, plan).success and room.containment_occupants == pending, "S-172 one newly blocked destination rolls back the whole release")
	room.walls = []
	dialog = release_dialog(view, "character", carrier.character_id)
	h._assert(dialog != null, "S-172 pending release has a production continuation control")
	if dialog != null: dialog.canceled.emit(); dialog.confirmed.emit()
	h._assert(room.containment_occupants == pending, "S-172 cancelled release cannot commit retained callback")
	await h.get_tree().process_frame
	dialog = release_dialog(view, "character", carrier.character_id)
	if dialog != null: dialog.confirmed.emit(); dialog.confirmed.emit()
	await h.get_tree().process_frame
	h._assert(ContainmentRules.occupants(room, "character", carrier.character_id).is_empty() and room.containment_occupants.size() == 1 and first.inventory.to_dict() == gear_before and is_same(LocalRoomRules.get_object(room, str(loose.id)), loose), "S-172 continuation releases the group once and preserves nested containment")
	# Existing object movement owner carries the remaining nested occupant.
	view.actors.select(3); view.refresh()
	var object_state := ContainmentRules.placement_state(room, party)
	var candidates := PlacementRules.candidates(object_state, LocalRoomRules.coord(inner.position), "tiny", 2, object_state.reserved)
	object_state._placement_grid.free()
	var inner_index: int = room.objects.find(inner)
	ContainmentFlow.select(view, "ContainmentContainers", "object", inner.id)
	TetherGroupFlow.press(view, "Move container")
	var replacement: Dictionary = inner.duplicate(true)
	room.objects[inner_index] = replacement
	if not candidates.is_empty(): view.click(candidates[0])
	h._assert(replacement.position == inner.position and not TetherRules.move_object_anchor(inner, room, Vector2i(4, 0), party).success, "S-172 stale object movement refuses same-ID replacement and old body callbacks")
	room.objects[inner_index] = inner
	h._assert(not candidates.is_empty() and TetherRules.move_object_anchor(inner, room, candidates[0], party).success and ContainmentRules.external_location(room, "object", str(loose.id), party).position == inner.position, "S-172 existing object movement owner carries its actual occupant")
	CombatObjectRules.apply_damage(inner, 100, "force")
	CombatObjectRules.settle_destruction(inner)
	var released_position: Array = loose.position.duplicate()
	CombatObjectRules.settle_destruction(inner)
	h._assert(not ContainmentRules.active(room) and loose.position == released_position and loose.contents.size() == 1 and loose.contents[0].instance_id == copy_id and loose.contents[0].state.release_stamp == "exact nested gear", "S-172 repeated destruction releases exact loose gear once")
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(manifest)); file.close()
	h._teardown_scene(dungeon)
	for slot in manifest.snapshots: h._assert(verify(slot, manifest.snapshots[slot]), "S-172 restores exact active/pending state even after the live clock passed expiry: " + slot)
	h._exit_test()
