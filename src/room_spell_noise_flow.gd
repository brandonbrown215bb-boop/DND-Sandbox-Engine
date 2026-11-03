class_name RoomSpellNoiseFlow
extends RefCounted

const SPELL := "fixture:room_resonance"
const TARGET_SPELL := "fixture:room_target_resonance"
const CELLS := [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]]


static func fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/ordinary_actions/room_spell_noise.json", "spell")
	for spell_id in [SPELL, TARGET_SPELL]:
		if spell_id not in DataLoader.classes.wizard.spell_list_ids: DataLoader.classes.wizard.spell_list_ids.append(spell_id)


static func geometry(check: Callable) -> void:
	var caster := PerceptionChecks.actor("room_noise_caster")
	var listener := PerceptionChecks.actor("room_noise_listener")
	var party: Array = [caster, listener]
	var room := LocalRoomRules.create({"id":"room-noise-route", "cells":CELLS, "walls":[[1, 0]], "party_spawns":[[0, 0], [2, 0]]}, party)
	var grid := HexGrid.new()
	for cell in CELLS:
		var tile := HexTile.new()
		tile.coord = LocalRoomRules.coord(cell)
		tile.custom_properties["blocks_sound"] = LocalRoomRules.blocks_sound(room, tile.coord)
		grid.add_tile(tile)
	var noise := {"volume":"loud", "range_feet":60}
	check.call(CombatNoiseRules.can_hear(listener, Vector2i(2, 0), Vector2i.ZERO, grid, noise, caster, room, "material"), "OA04 room sound routes around a blocking wall when an open room route remains")
	for cell in [[0, 1], [1, 1], [2, 1]]:
		room.walls.append(cell)
		grid.get_tile(LocalRoomRules.coord(cell)).custom_properties["blocks_sound"] = true
	check.call(not CombatNoiseRules.can_hear(listener, Vector2i(2, 0), Vector2i.ZERO, grid, noise, caster, room, "material"), "OA04 room walls block sound when every represented route is closed")
	room.walls.clear()
	for cell in CELLS: grid.get_tile(LocalRoomRules.coord(cell)).custom_properties["blocks_sound"] = false
	listener.feature_uses["plane"] = "ethereal"
	check.call(not CombatNoiseRules.can_hear(listener, Vector2i(2, 0), Vector2i.ZERO, grid, noise, caster, room, "material"), "OA04 room sound excludes a listener on another plane")
	listener.feature_uses.erase("plane")
	listener.add_condition("deafened", 10)
	check.call(not CombatNoiseRules.can_hear(listener, Vector2i(2, 0), Vector2i.ZERO, grid, noise, caster, room, "material"), "OA04 room sound excludes a Deafened listener")
	listener.remove_condition("deafened")
	listener.add_condition("silenced", 10)
	check.call(not CombatNoiseRules.can_hear(listener, Vector2i(2, 0), Vector2i.ZERO, grid, noise, caster, room, "material"), "OA04 room Silence at the listener prevents hearing")
	listener.remove_condition("silenced")
	caster.add_condition("silenced", 10)
	check.call(not CombatNoiseRules.can_hear(listener, Vector2i(2, 0), Vector2i.ZERO, grid, noise, caster, room, "material"), "OA04 room Silence at the sound source prevents hearing")
	grid.free()


static func run(h: Node) -> void:
	h._enter_test("room_spell_noise_flow")
	h._setup_world()
	fixtures()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id":"ruins_of_ashvale"}
	GameManager.active_dungeon_state.clear()
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	dungeon._enter_local_room("1")
	var view: LocalRoomView = dungeon.local_view
	var caster: Character = view.characters[1]
	var listener: Character = view.characters[0]
	caster.known_spells.append(SPELL)
	caster.known_spells.append(TARGET_SPELL)
	h._own_class_spells(caster)
	caster.wizard_spellbook = caster.wizard_spellbook.filter(func(id): return int(DataLoader.get_spell(str(id)).get("level", 0)) > 0)
	caster.spell_slots["1"] = 2
	var origin := LocalRoomRules.coord(view.state.party_positions[caster.character_id])
	var listener_position := Vector2i(9999, 9999)
	for candidate in HexUtils.get_neighbors(origin):
		if view.grid.has_tile(candidate) and not LocalRoomRules.blocks_sound(view.state, candidate) and not LocalRoomRules.blocks_sound(view.state, origin):
			listener_position = candidate
			break
	h._assert(listener_position != Vector2i(9999, 9999), "OA04 loaded room has a represented open adjacent listener space")
	if listener_position == Vector2i(9999, 9999):
		h._teardown_scene(dungeon)
		h._exit_test()
		return
	view.state.party_positions[caster.character_id] = [origin.x, origin.y]
	view.state.party_positions[listener.character_id] = [listener_position.x, listener_position.y]
	var caster_index := view.characters.find(caster)
	view.actors.select(caster_index)
	view.actors.item_selected.emit(caster_index)
	view.refresh()
	var spells: OptionButton = view.panel.find_child("RoomSharedSpells", true, false)
	var targets: OptionButton = view.panel.find_child("RoomSharedSpellTargets", true, false)
	var cast_button: Button
	for child in view.action_row.get_children():
		if child is VBoxContainer:
			for control in child.get_children():
				if control is Button and control.text == "Cast": cast_button = control
	if spells == null or cast_button == null or targets == null:
		h._assert(false, "OA04 loaded renamed shared spell is offered through the existing room Cast controls")
		h._teardown_scene(dungeon)
		h._exit_test()
		return
	for index in spells.item_count:
		if spells.get_item_metadata(index) == SPELL:
			spells.select(index)
			spells.item_selected.emit(index)
	h._assert(targets.item_count > 0, "OA04 loaded renamed shared spell is offered through the existing room Cast controls")
	var self_target := -1
	var other_target := -1
	for index in targets.item_count:
		var target_id := str(targets.get_item_metadata(index))
		if target_id == "party:" + caster.character_id: self_target = index
		if target_id == "party:" + listener.character_id: other_target = index
	var start_clock := int(GameManager.campaign_elapsed_seconds)
	var starting_slots := int(caster.spell_slots["1"])
	view.last_action_result.clear()
	targets.select(-1)
	cast_button.pressed.emit()
	h._assert(view.last_action_result.is_empty() and int(GameManager.campaign_elapsed_seconds) == start_clock and int(caster.spell_slots["1"]) == starting_slots, "OA04 cancelling the unpaid room target choice spends no slot or room time and emits no sound")
	if other_target >= 0:
		var original_plane: Variant = listener.feature_uses.get("plane", "material")
		listener.feature_uses["plane"] = "ethereal"
		targets.select(other_target)
		cast_button.pressed.emit()
		h._assert(not view.last_action_result.get("success", false) and not view.last_action_result.has("noise") and int(GameManager.campaign_elapsed_seconds) == start_clock and int(caster.spell_slots["1"]) == starting_slots, "OA04 refused cross-plane room cast emits nothing and spends no slot or time")
		if original_plane == "material": listener.feature_uses.erase("plane")
		else: listener.feature_uses["plane"] = original_plane
		# A completed result refreshes the controls, so continue with the newly
		# built production pickers rather than the controls just used above.
		spells = view.panel.find_child("RoomSharedSpells", true, false)
		targets = view.panel.find_child("RoomSharedSpellTargets", true, false)
		for child in view.action_row.get_children():
			if child is VBoxContainer:
				for control in child.get_children():
					if control is Button and control.text == "Cast": cast_button = control
		for index in spells.item_count:
			if spells.get_item_metadata(index) == SPELL:
				spells.select(index)
				spells.item_selected.emit(index)
		for index in targets.item_count:
			if targets.get_item_metadata(index) == "party:" + caster.character_id: self_target = index
	caster.current_hp = caster.max_hp - 4
	var hp_before := caster.current_hp
	caster.add_condition("hidden", 120, "fixture:oa04_hide")
	caster.add_condition("invisible", 120, "fixture:oa04_independent_invisibility")
	if self_target >= 0: targets.select(self_target)
	view.last_action_result.clear()
	cast_button.pressed.emit()
	var cast_result := view.last_action_result
	var expected_listeners: Array[String] = [caster.character_id, listener.character_id]
	h._assert(cast_result.get("success", false) and caster.current_hp == hp_before + 2 and int(caster.spell_slots["1"]) == starting_slots - 1 and int(GameManager.campaign_elapsed_seconds) == start_clock + 6, "OA04 actual loaded room cast applies its effect, pays one slot and advances the room clock once")
	h._assert(cast_result.get("noise", {}).get("volume", "") == "loud" and cast_result.get("heard_by", []).size() == 2 and expected_listeners.all(func(id): return id in cast_result.get("heard_by", [])), "OA04 actual cast returns exact party listener receipts from the room sound owner")
	h._assert(not caster.has_condition("hidden") and caster.condition_sources.get("invisible", {}).has("fixture:oa04_independent_invisibility"), "OA04 loud room effect sound ends Hide while preserving independent Invisibility")
	# The room host's exact target origin is distinct from the casting character.
	var listener_hp_before := listener.max_hp - 4
	listener.current_hp = listener_hp_before
	listener.add_condition("hidden", 120, "fixture:room_target_hide")
	listener.add_condition("invisible", 120, "fixture:room_target_invisibility")
	caster.add_condition("hidden", 120, "fixture:room_caster_hide")
	view.refresh()
	spells = view.panel.find_child("RoomSharedSpells", true, false)
	targets = view.panel.find_child("RoomSharedSpellTargets", true, false)
	for child in view.action_row.get_children():
		if child is VBoxContainer:
			for control in child.get_children():
				if control is Button and control.text == "Cast": cast_button = control
	for index in spells.item_count:
		if spells.get_item_metadata(index) == TARGET_SPELL:
			spells.select(index)
			spells.item_selected.emit(index)
	var target_listener_index := -1
	for index in targets.item_count:
		if targets.get_item_metadata(index) == "party:" + listener.character_id: target_listener_index = index
	h._assert(target_listener_index >= 0, "OA12 target-origin room cast offers the exact selected party target in the actual Cast controls")
	if target_listener_index >= 0:
		targets.select(target_listener_index)
	view.last_action_result.clear()
	cast_button.pressed.emit()
	var target_cast_result: Dictionary = view.last_action_result
	var target_heard: Array = target_cast_result.get("heard_by", [])
	h._assert(target_cast_result.get("success", false) and listener.current_hp == listener_hp_before + 2 and int(caster.spell_slots["1"]) == starting_slots - 2 and int(GameManager.campaign_elapsed_seconds) == start_clock + 12, "OA12 actual target-origin room spell resolves its effect and pays one additional slot/time interval")
	h._assert(target_cast_result.get("noise", {}).get("origin", "") == "target" and target_heard.size() == 2 and caster.character_id in target_heard and listener.character_id in target_heard, "OA12 room sound originates at the exact target and returns both actual party listener receipts")
	h._assert(not listener.has_condition("hidden") and listener.condition_sources.get("invisible", {}).has("fixture:room_target_invisibility") and caster.has_condition("hidden"), "OA12 target-origin room sound ends only target Hide and preserves caster Hide and target's independent Invisibility")
	var sound_line_count := view.hud.log_text.text.split("Loud sound; heard by").size() - 1
	var paid_slots := int(caster.spell_slots["1"])
	var exit_position := LocalRoomRules.coord(view.state.get("exits", [view.state.party_positions[caster.character_id]])[0])
	view.state.party_positions[caster.character_id] = [exit_position.x, exit_position.y]
	dungeon._leave_local_room()
	var paid_clock := int(GameManager.campaign_elapsed_seconds)
	var saved := SaveManager.save_game("oa04_room_spell_noise")
	var loaded := saved and SaveManager.load_game("oa04_room_spell_noise")
	var restored_caster: Character = PlayerManager.get_player(1).get("character") if loaded else null
	h._assert(saved and loaded and restored_caster != null and int(restored_caster.spell_slots["1"]) == paid_slots and restored_caster.current_hp == hp_before + 2 and int(GameManager.campaign_elapsed_seconds) == paid_clock and (view.hud.log_text.text.split("Loud sound; heard by").size() - 1) == sound_line_count, "OA04 allowed entrance checkpoint preserves settled effect/payment/time and does not replay cast or sound")
	geometry(func(ok: bool, message: String): h._assert(ok, message))
	h._teardown_scene(dungeon)
	h._exit_test()
