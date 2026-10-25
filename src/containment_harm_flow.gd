class_name ContainmentHarmFlow
extends RefCounted

const MANIFEST := "user://containment_harm_manifest.json"

static func fixtures() -> void:
	ContainmentFlow.fixtures()
	DataLoader._load_json_file("res://data/fixtures/containment/harm_races.json", "race")
	DataLoader._load_json_file("res://data/fixtures/containment/spells.json", "spell")
	DataLoader.campaigns.values()[0].dungeons["ruins_of_ashvale"].tactical_rooms["0"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/containment/harm_room.json"))

static func actor(view: LocalRoomView, index: int) -> void:
	view.actors.select(index)
	view.refresh()

static func picker(view: LocalRoomView, name: String, id: String) -> bool:
	var button: OptionButton = view.action_row.find_child(name, true, false)
	if button == null: return false
	for index in button.item_count:
		if button.get_item_metadata(index) == id:
			button.select(index)
			button.item_selected.emit(index)
			return true
	return false

static func cast(h: Node, view: LocalRoomView, spell: String, target: String) -> void:
	h._assert(picker(view, "RoomSharedSpells", "fixture:" + spell) and picker(view, "RoomSharedSpellTargets", target), "S-171 real spell pickers select exact recipient " + target)
	h._assert(TetherGroupFlow.press(view, "Cast"), "S-171 actual room spell Cast control")
	await h.get_tree().process_frame

static func dialog(view: LocalRoomView, id: String, mode: String) -> ConfirmationDialog:
	if not ContainmentFlow.select(view, "ContainmentCandidates", "character", id): return null
	TetherGroupFlow.press(view, "Escape containment" if mode == "escape" else "Rescue occupant")
	for child in view.panel.get_children():
		if child is ConfirmationDialog and child.name == "ContainmentCheck" and not child.is_queued_for_deletion(): return child
	return null

static func checkpoint(h: Node, view: LocalRoomView, dungeon: DungeonState, label: String, manifest: Dictionary) -> void:
	TetherGroupFlow.press(view, "Room map")
	await h.get_tree().process_frame
	var slot := "containment_harm_" + label
	h._assert(SaveManager.save_game(slot), "S-171 production entrance checkpoint: " + label)
	var save := SaveManager._read_save(slot)
	var player_only := save.duplicate(true)
	player_only.erase("party")
	h._assert(SaveManager._validate_save_data(player_only).is_empty(), "S-171 player-only checkpoint validates: " + label)
	var file := FileAccess.open(SaveManager.SAVE_DIR + slot + "_players.sav", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(player_only)); file.close()
	var snapshot := {"rows": save.active_dungeon_state.local_rooms["0"].containment_occupants, "objects": save.active_dungeon_state.local_rooms["0"].objects, "time": GameManager.campaign_elapsed_seconds, "actors": {}}
	for member in PartyManager.get_active_characters(): snapshot.actors[member.character_id] = {"hp": member.current_hp, "slots": member.spell_slots.duplicate(), "inventory": member.inventory.to_dict(), "serial": member.spell_cast_serial, "history": member.recent_damage_history.duplicate(true)}
	manifest[slot] = snapshot
	manifest[slot + "_players"] = snapshot
	dungeon._enter_local_room("0")
	await h.get_tree().process_frame

static func run(h: Node) -> void:
	h._enter_test("containment_harm_flow")
	fixtures()
	h._setup_mixed_world()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	var party := PartyManager.get_active_characters()
	var outside: Character = party[0]
	var first: Character = party[1]
	var second: Character = party[2]
	var old_living: Character = party[3]
	var living: Character = h._fresh_char("Living chamber", "fixture:renamed_harm_chamber", "cleric", {"STR": 12, "DEX": 10, "CON": 14, "INT": 10, "WIS": 18, "CHA": 10})
	living.character_id = old_living.character_id
	party[3] = living
	PartyManager.characters[living.character_id] = living
	PlayerManager.set_player_character(3, living)
	first.character_name = "Same occupant"
	second.character_name = "Same occupant"
	for member in party:
		member.max_hp = 200
		member.current_hp = 200
		member.spell_slots["1"] = 40
		for id in ["interior_pulse", "renamed_pulse", "outside_probe", "outgoing_probe", "ordinary_probe", "exterior_wave"]: member.known_spells.append("fixture:" + id)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon._enter_local_room("0")
	await h.get_tree().process_frame
	var view := dungeon.local_view
	var room := view.state
	for member in party:
		member.max_hp = 200
		member.current_hp = 200
		member.spell_slots["1"] = 40
	var chamber := LocalRoomRules.get_object(room, "chamber_a")
	h._assert(living.containment == chamber.containment and living.containment == DataLoader.get_race("fixture:harm_chamber").containment, "S-171 neutral and renamed authored creature policies initialize through DataLoader")
	var gear := Batch042Checks.add(first, "dagger")
	var loose_id := Batch042Checks.add(outside, "dagger")
	var loose_copy := outside.inventory.get_instance(loose_id)
	loose_copy.state["physical"] = {"size": "tiny"}
	outside.inventory.update_instance(loose_copy)
	room.objects.append(LocalRoomRules.placed_item(room, outside.inventory.take_instance(loose_id), Vector2i(0, -1)))
	var loose := LocalRoomRules.get_object(room, "placed:" + loose_id)
	loose.hp = 100
	loose.max_hp = 100
	view.refresh()
	await ContainmentFlow.accept(h, view, "object", "chamber_a", "character", first.character_id)
	await ContainmentFlow.accept(h, view, "object", "chamber_a", "character", second.character_id)
	await ContainmentFlow.accept(h, view, "character", living.character_id, "object", str(loose.id))
	var first_row := ContainmentRules.relation(room, "character", first.character_id)
	var second_row := ContainmentRules.relation(room, "character", second.character_id)
	var loose_row := ContainmentRules.relation(room, "object", str(loose.id))
	var t := int(GameManager.campaign_elapsed_seconds)
	GameManager.advance_campaign_time(6)
	h._assert(first.current_hp == 198 and second.current_hp == 198 and loose.hp == 98 and outside.current_hp == 200 and living.current_hp == 200, "S-171 authored internal Character/object harm excludes outside bodies and container")
	h._assert(ContainmentRules.advance_internal_damage(room, party, t + 6).is_empty() and first.current_hp == 198, "S-171 repeated damage settlement at the same time cannot replay")
	h._assert(first.recent_damage_history.any(func(r): return r.source_instance_id == first_row.source_id), "S-171 shared damage history retains exact containment source")
	var slots := outside.spell_slots.duplicate()
	var serial := outside.spell_cast_serial
	var ordinary := DataLoader.get_spell("fixture:ordinary_probe")
	var refused := CombatAction.resolve_spell(outside, first, ordinary, true)
	h._assert(not refused.success and outside.spell_slots == slots and outside.spell_cast_serial == serial, "S-171 ordinary exterior spell refuses internal target before slot/source costs")
	var attack := CombatAction.resolve_weapon_attack(outside, first, {"damage": "9", "damage_type": "force", "attack_bonus_override": 100})
	h._assert(not attack.get("success", true) and first.current_hp == 198, "S-171 ordinary exterior weapon cannot hit internal occupant")
	var clone := CombatObjectRules.make_resolution_target(loose)
	h._assert(not CombatAction.resolve_spell(outside, clone, ordinary, true).success and outside.spell_slots == slots, "S-171 object resolution copies retain exact interior identity")
	h._assert(picker(view, "RoomSharedSpells", "fixture:outside_probe") and picker(view, "RoomSharedSpellTargets", "party:" + first.character_id), "S-171 select a spell target before container replacement")
	var stale_cast: Button = view.action_row.find_children("*", "Button", true, false).filter(func(b): return b.text == "Cast")[0]
	var chamber_index: int = room.objects.find(chamber)
	room.objects[chamber_index] = chamber.duplicate(true)
	TetherGroupFlow.press(view, "Cast")
	h._assert(outside.spell_slots == slots and outside.spell_cast_serial == serial, "S-171 retained spell selection refuses replaced containment source before costs")
	room.objects[chamber_index] = chamber
	stale_cast.pressed.emit()
	h._assert(outside.spell_slots == slots and outside.spell_cast_serial == serial, "S-171 retained cast callback cannot revive after controls refresh")
	view.refresh()
	await cast(h, view, "outside_probe", "party:" + first.character_id)
	h._assert(first.current_hp == 193 and second.current_hp == 196 and outside.spell_slots["1"] == int(slots["1"]) - 1 and GameManager.campaign_elapsed_seconds == t + 12, "S-171 one eligible external spell hits only selected occupant beside periodic internal harm")
	actor(view, 1)
	var hp := second.current_hp
	await cast(h, view, "renamed_pulse", "party:" + second.character_id)
	h._assert(second.current_hp == hp - 5 and first.current_hp == 191, "S-171 renamed JSON internal effect selects second equal-name occupant, not first")
	var self_slots := first.spell_slots.duplicate()
	var self_area := LocalRoomSharedSpells.cast(room, first, "fixture:exterior_wave", first, party, view.grid)
	h._assert(not self_area.success and first.spell_slots == self_slots, "S-171 internal self selection cannot leak an exterior area step")
	var invalid := LocalRoomSharedSpells.cast(room, first, "fixture:interior_pulse", outside, party, view.grid)
	h._assert(not invalid.success, "S-171 same-interior permission never authorizes an outgoing effect")
	var chp := int(chamber.hp)
	await cast(h, view, "interior_pulse", "object:chamber_a")
	h._assert(chamber.hp == chp - 3 and not first_row.has("release_pending"), "S-171 occupant-to-container damage is distinct from occupant harm and release")
	await cast(h, view, "outgoing_probe", "party:" + outside.character_id)
	h._assert(outside.current_hp == 197, "S-171 explicitly authored outgoing effect reaches external body")
	actor(view, 0)
	var b := LocalRoomRules.get_object(room, "chamber_b")
	await cast(h, view, "ordinary_probe", "object:chamber_b")
	h._assert(b.hp == 17, "S-171 ordinary external effect remains legal beside internal effects")
	var interior_hp := [first.current_hp, second.current_hp]
	var external_hp := [outside.current_hp, living.current_hp]
	var wave := LocalRoomSharedSpells.cast(room, outside, "fixture:exterior_wave", outside, party, view.grid)
	h._assert(wave.success and [first.current_hp, second.current_hp] == interior_hp and outside.current_hp == int(external_hp[0]) - 1 and living.current_hp == int(external_hp[1]) - 1, "S-171 external area-step recipients exclude internal entry cells")
	var before := room.duplicate(true)
	var pending := dialog(view, first.character_id, "rescue")
	h._assert(pending != null, "S-171 actual rescue confirmation identifies selected occupant")
	if pending != null: pending.canceled.emit(); pending.confirmed.emit()
	h._assert(room == before, "S-171 cancelled rescue cannot settle")
	await h.get_tree().process_frame
	var choice := ContainmentRules.prepare_check(room, party, outside, "character", first.character_id, "rescue")
	h._assert(choice.success, "S-171 live rescue is prepared before moving actor")
	room.party_positions[outside.character_id] = [2, 0]
	h._assert(not ContainmentRules.attempt_check(room, party, outside, choice).success, "S-171 moved rescuer refuses captured check before time")
	room.party_positions[outside.character_id] = [0, 0]
	choice = ContainmentRules.prepare_check(room, party, outside, "character", first.character_id, "rescue")
	h._assert(choice.success, "S-171 integer movement coordinates still prepare rescue against JSON room cells")
	chamber.containment.rescue.dc = 2
	h._assert(not ContainmentRules.attempt_check(room, party, outside, choice).success, "S-171 changed authored source refuses captured check")
	chamber.containment.rescue.dc = 1
	choice = ContainmentRules.prepare_check(room, party, outside, "character", first.character_id, "rescue")
	h._assert(choice.success, "S-171 live rescue is prepared before body replacement")
	var replacement := Character.new()
	replacement.from_dict(first.to_dict())
	var replaced := party.duplicate()
	replaced[1] = replacement
	h._assert(not ContainmentRules.attempt_check(room, replaced, outside, choice).success, "S-171 same-ID replacement refuses exact rescue")
	h._assert(not ContainmentRules.prepare_check(room, party, outside, "character", first.character_id, "escape").success and not ContainmentRules.prepare_check(room, party, first, "character", second.character_id, "rescue").success and not ContainmentRules.prepare_check(room, party, living, "object", str(loose.id), "rescue").success, "S-171 occupant, container and rescuer cannot substitute for one another")
	var manifest := {"pid": OS.get_process_id(), "snapshots": {}}
	await checkpoint(h, view, dungeon, "active", manifest.snapshots)
	view = dungeon.local_view
	room = view.state
	chamber = LocalRoomRules.get_object(room, "chamber_a")
	actor(view, 1)
	chamber.containment.escape.dc = 100
	t = int(GameManager.campaign_elapsed_seconds)
	pending = dialog(view, first.character_id, "escape")
	if pending != null: pending.confirmed.emit(); pending.confirmed.emit()
	await h.get_tree().process_frame
	h._assert(GameManager.campaign_elapsed_seconds == t + 6 and not first_row.has("release_pending"), "S-171 failed escape pays one authored time cost despite repeated confirmation")
	chamber.containment.escape.dc = 1
	pending = dialog(view, first.character_id, "escape")
	if pending != null: pending.confirmed.emit(); pending.confirmed.emit()
	await h.get_tree().process_frame
	h._assert(first_row.get("release_pending", {}).get("reason") == "escape" and first_row.release_pending.actor_id == first.character_id and not second_row.has("release_pending"), "S-171 successful exact escape defers shared release for first only")
	var frozen_hp := first.current_hp
	t = int(GameManager.campaign_elapsed_seconds)
	h._assert(dialog(view, first.character_id, "escape") == null and GameManager.campaign_elapsed_seconds == t, "S-171 pending escape refuses repeated costs")
	actor(view, 0)
	pending = dialog(view, second.character_id, "rescue")
	h._assert(pending != null, "S-171 exact second occupant offers rescue after room reopening")
	if pending != null: pending.confirmed.emit(); pending.confirmed.emit()
	await h.get_tree().process_frame
	h._assert(second_row.get("release_pending", {}).get("reason") == "rescue" and second_row.release_pending.actor_id == outside.character_id and first.current_hp == frozen_hp, "S-171 distinct outside rescuer frees selected second occupant; pending first takes no repeated harm")
	var reasons := [first_row.get("release_pending", {}).duplicate(true), second_row.get("release_pending", {}).duplicate(true)]
	CombatObjectRules.apply_damage(chamber, 100, "force")
	CombatObjectRules.settle_destruction(chamber)
	h._assert(chamber.hp == 0 and room.containment_occupants.size() == 3 and [first_row.get("release_pending", {}), second_row.get("release_pending", {})] == reasons, "S-171 repeated container destruction preserves prior escape/rescue receipts and actual occupants")
	CombatAction.resolve_damage(living, 1000, "force")
	h._assert(loose_row.get("release_pending", {}).get("reason") == "container_destroyed" and ContainmentRules.entity(room, party, "object", str(loose.id)) == loose, "S-171 living-container loss uses shared deferred release without deleting its exact object occupant")
	# Independent occupied object destruction before any check.
	var cargo_copy_id := Batch042Checks.add(outside, "dagger")
	var cargo_copy := outside.inventory.get_instance(cargo_copy_id)
	cargo_copy.state["physical"] = {"size": "tiny"}
	outside.inventory.update_instance(cargo_copy)
	var cargo := LocalRoomRules.placed_item(room, outside.inventory.take_instance(cargo_copy_id), Vector2i(1, -1))
	cargo.hp = 30
	cargo.max_hp = 30
	room.objects.append(cargo)
	var admission := ContainmentRules.prepare(room, party, outside, "object", "chamber_b", "object", str(cargo.id))
	h._assert(ContainmentRules.admit(room, party, outside, admission).success, "S-171 independent exact cargo admission")
	CombatObjectRules.apply_damage(b, 100, "force")
	var cargo_row := ContainmentRules.relation(room, "object", str(cargo.id))
	h._assert(cargo_row.get("release_pending", {}).get("reason") == "container_destroyed" and cargo.hp == 30, "S-171 object destruction requests release without transferring damage to occupant")
	var rows_before: Array = room.containment_occupants.duplicate(true)
	GameManager.advance_campaign_time(12)
	h._assert(room.containment_occupants == rows_before and first.current_hp == frozen_hp and first.inventory.get_instance(gear).get("instance_id") == gear, "S-171 repeated settlement preserves pending occupants and gear")
	h._assert(ContainmentRules.room_error(room, party, true).is_empty(), "S-171 destroyed containers with explicit pending releases validate")
	await checkpoint(h, view, dungeon, "pending", manifest.snapshots)
	view = dungeon.local_view
	var bad := SaveManager._read_save("containment_harm_pending")
	bad.active_dungeon_state.local_rooms["0"].containment_occupants[0].release_pending.reason = "invented"
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-171 malformed release checkpoint refuses before replacing session")
	bad = SaveManager._read_save("containment_harm_pending")
	bad.active_dungeon_state.local_rooms["0"].containment_occupants[1].source_id = bad.active_dungeon_state.local_rooms["0"].containment_occupants[0].source_id
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-171 duplicate containment source refuses checkpoint")
	bad = SaveManager._read_save("containment_harm_active")
	bad.active_dungeon_state.local_rooms["0"].containment_serial = 0
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-171 reset source serial refuses checkpoint")
	bad = SaveManager._read_save("containment_harm_active")
	bad.active_dungeon_state.local_rooms["0"].containment_occupants[0].erase("next_damage_seconds")
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-171 missing damage timer refuses checkpoint")
	bad = SaveManager._read_save("containment_harm_pending")
	bad.active_dungeon_state.local_rooms["0"].containment_occupants[0].release_pending.actor_id = outside.character_id
	h._assert(not SaveManager._validate_save_data(bad).is_empty(), "S-171 escape receipt cannot substitute the rescuer identity")
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(manifest)); file.close()
	h._teardown_scene(dungeon)
	for slot in manifest.snapshots: h._assert(verify(slot, manifest.snapshots[slot]), "S-171 same-process restore without replay: " + slot)
	h._exit_test()

static func verify(slot: String, expected: Dictionary) -> bool:
	if not SaveManager.load_game(slot): return false
	var room: Dictionary = GameManager.active_dungeon_state.local_rooms["0"]
	if ContainmentFlow.plain(room.containment_occupants) != ContainmentFlow.plain(expected.rows) or ContainmentFlow.plain(room.objects) != ContainmentFlow.plain(expected.objects) or int(GameManager.campaign_elapsed_seconds) != int(expected.time): return false
	for id in expected.actors:
		var member: Character = PartyManager.characters.get(str(id))
		var data: Dictionary = expected.actors[id]
		if member == null or member.current_hp != int(data.hp) or member.spell_cast_serial != int(data.serial) or ContainmentFlow.plain(member.spell_slots) != ContainmentFlow.plain(data.slots) or ContainmentFlow.plain(member.inventory.to_dict()) != ContainmentFlow.plain(data.inventory) or ContainmentFlow.plain(member.recent_damage_history) != ContainmentFlow.plain(data.history): return false
	if not ContainmentRules.advance_internal_damage(room, PartyManager.characters.values(), int(expected.time)).is_empty(): return false
	return ContainmentRules.room_error(room, PartyManager.characters.values(), true).is_empty()
