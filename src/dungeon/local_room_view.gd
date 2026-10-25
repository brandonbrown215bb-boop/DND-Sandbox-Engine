## Input and HUD for an authored local room; rules and saved data stay separate.
class_name LocalRoomView
extends RefCounted

signal leave_requested
signal encounter_requested
signal save_exit_choice_completed(choice: String)
var state: Dictionary
var characters: Array
var grid: HexGrid
var hud: DungeonHUD
var flush: Callable
var panel: VBoxContainer
var actors: OptionButton
var movement_modes: OptionButton
var objects: OptionButton
var contents: OptionButton
var items: OptionButton
var recipients: OptionButton
var slots: OptionButton
var action_row: HBoxContainer
var familiar_summon_row: HFlowContainer
var familiar_presence_row: HFlowContainer
var body_row: HFlowContainer
var body_targets: OptionButton
var created_row: HFlowContainer
var created_targets: OptionButton
var mode_row: HFlowContainer # Batch 062
var mode_offers: OptionButton
var mode_popup_serial := 0
var tether_popup_serial := 0
var containment_serial := 0
var containment_row: HFlowContainer
var containment_item_rows: Array = []
var item_lifecycle_row: HFlowContainer
var item_lifecycle_offers: OptionButton
var item_lifecycle_serial := 0
var aftermath_row: HFlowContainer
var expand_pack_button: Button
var ration_quarter_button: Button
var ration_half_button: Button
var ration_full_button: Button
var attune_button: Button
var unattune_button: Button
var stow_button: Button
var retrieve_button: Button
var attach_button: Button
var detach_button: Button
var activate_button: Button
var pause_button: Button
var encounter_button: Button
var pending_teleport_spell := ""
var pending_water_area_mode := ""
var pending_anchor_move_choice: Dictionary = {}
var pending_anchor_move_id := ""
var pending_room_creation: Dictionary = {}
var pending_save_exit: Dictionary = {}
var save_exit_serial := 0
var save_exit_cancel_button: Button

func start(room: Dictionary, party: Array, room_grid: HexGrid, room_hud: DungeonHUD, save_callback: Callable) -> void:
	state = room
	LocalRoomAreas.expire(state, int(GameManager.campaign_elapsed_seconds))
	for message in LocalRoomRules.advance_burning_objects(state, int(GameManager.campaign_elapsed_seconds)):
		room_hud.add_log(message)
	characters = party
	CreatedCreatureRules.enter_room(state, characters)
	for message in LocalRoomRules.reconcile_flight_altitudes(state, characters): room_hud.add_log(message)
	grid = room_grid
	hud = room_hud
	flush = save_callback
	var margin := hud.find_child("DockBox", true, false).get_child(0)
	var system_row := margin.get_child(0)
	panel = VBoxContainer.new()
	panel.name = "LocalRoomActions"
	margin.add_child(panel)
	system_row.reparent(panel)
	var instructions := Label.new()
	instructions.text = "Click a space to move, or choose an object to interact. Each hex is five feet."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(instructions)
	var party_row := HBoxContainer.new()
	panel.add_child(party_row)
	actors = OptionButton.new()
	actors.fit_to_longest_item = false
	actors.clip_text = true
	actors.custom_minimum_size.x = 100
	for character in characters: actors.add_item(character.character_name)
	party_row.add_child(actors)
	actors.item_selected.connect(func(_index):
		pending_room_creation.clear()
		if not pending_save_exit.is_empty():
			save_exit_serial += 1
			_finish_save_exit_choice("")
		refresh())
	movement_modes = OptionButton.new()
	movement_modes.custom_minimum_size.x = 100
	party_row.add_child(movement_modes)
	movement_modes.item_selected.connect(func(_index): refresh())
	_add_button(party_row, "Room map", func():
		if not ContainmentRules.relation(state, "character", actor().character_id).is_empty(): hud.add_log("An internal occupant cannot use the room exit.")
		else: leave_requested.emit())
	encounter_button = _add_button(party_row, "Face the guardian", func():
		if ContainmentRules.active(state): hud.add_log("Contained bodies cannot enter an encounter yet.")
		else: encounter_requested.emit())
	objects = OptionButton.new()
	objects.fit_to_longest_item = false
	objects.clip_text = true
	objects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_row.add_child(objects)
	objects.item_selected.connect(func(_index): refresh())
	containment_row = HFlowContainer.new()
	containment_row.name = "RoomContainment"
	panel.add_child(containment_row)
	action_row = HBoxContainer.new()
	panel.add_child(action_row)
	familiar_summon_row = HFlowContainer.new()
	panel.add_child(familiar_summon_row)
	familiar_presence_row = HFlowContainer.new()
	panel.add_child(familiar_presence_row)
	body_row = HFlowContainer.new()
	panel.add_child(body_row)
	created_row = HFlowContainer.new()
	panel.add_child(created_row)
	mode_row = HFlowContainer.new()
	mode_row.name = "RoomModeRow"
	panel.add_child(mode_row)
	item_lifecycle_row = HFlowContainer.new()
	item_lifecycle_row.name = "RoomItemLifecycle"
	panel.add_child(item_lifecycle_row)
	aftermath_row = HFlowContainer.new()
	aftermath_row.name = "RoomSourceEndChildren"
	panel.add_child(aftermath_row)
	var item_row := HBoxContainer.new()
	panel.add_child(item_row)
	var item_action_row := HBoxContainer.new()
	containment_item_rows = [item_row, item_action_row]
	panel.add_child(item_action_row)
	items = OptionButton.new()
	items.fit_to_longest_item = false
	items.clip_text = true
	items.custom_minimum_size.x = 140
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(items)
	items.item_selected.connect(func(_index): _refresh_item_actions())
	slots = OptionButton.new()
	for slot in Inventory.Slot.keys(): slots.add_item(slot.capitalize())
	item_row.add_child(slots)
	_add_button(item_row, "Equip", func():
		var ok := actor().inventory.equip_instance(slots.selected, _selected(items))
		_result({"success": ok, "seconds": 6 if ok else 0, "message": "Item equipped." if ok else "That item cannot use this slot."}))
	_add_button(item_row, "Unequip", func():
		var previous := actor().inventory.unequip(slots.selected)
		_result({"success": not previous.is_empty(), "seconds": 6 if not previous.is_empty() else 0, "message": "Item unequipped." if not previous.is_empty() else "Nothing could be unequipped; items unchanged."}))
	_add_button(item_row, "Use", func():
		var result := actor().inventory.consume_instance(_selected(items), actor())
		result["seconds"] = 6 if result.get("success", false) else 0
		_result(result))
	_add_button(item_row, "Place", func(): _result(LocalRoomRules.place(state, actor(), _selected(items))))
	recipients = OptionButton.new()
	recipients.fit_to_longest_item = false
	recipients.clip_text = true
	recipients.custom_minimum_size.x = 100
	for character in characters: recipients.add_item(character.character_name)
	item_row.add_child(recipients)
	_add_button(item_row, "Give", func():
		_result(LocalRoomRules.transfer(state, actor(), characters[recipients.selected], _selected(items))))
	_add_button(item_action_row, "Inspect item", func():
		var record := actor().inventory.get_instance(_selected(items))
		var definition := DataLoader.get_item(str(record.get("definition_id", "")))
		hud.add_log("%s: %s" % [definition.get("name", "Item"), definition.get("description", "No details are recorded.")]))
	ration_quarter_button = _add_button(item_action_row, "Eat ¼ day", func(): _result(actor().inventory.consume_ration_portion(_selected(items), actor(), 0.25)))
	ration_half_button = _add_button(item_action_row, "Eat ½ day", func(): _result(actor().inventory.consume_ration_portion(_selected(items), actor(), 0.5)))
	ration_full_button = _add_button(item_action_row, "Eat full day", func(): _result(actor().inventory.consume_ration_portion(_selected(items), actor(), 1.0)))
	expand_pack_button = _add_button(item_action_row, "Expand pack", func():
		var result := actor().inventory.expand_pack_instance(_selected(items))
		result["seconds"] = 6 if result.get("success", false) else 0
		_result(result))
	attune_button = _add_button(item_action_row, "Attune (1 hour)", func():
		_result(actor().inventory.attune_instance(_selected(items), actor().character_id)))
	unattune_button = _add_button(item_action_row, "Unattune", func():
		_result(actor().inventory.unattune_instance(_selected(items), actor().character_id)))
	# S-196: stow the exact selected copy, or take the last stowed copy out of the selected container.
	stow_button = _add_button(item_action_row, "Stow", func(): _result(ContainerRules.stow(actor().inventory, _selected(items))))
	retrieve_button = _add_button(item_action_row, "Take out", func(): _result(ContainerRules.retrieve_last(actor().inventory, _selected(items))))
	# S-210: attach the selected part to a socket, or detach the selected host's last part.
	attach_button = _add_button(item_action_row, "Attach", func(): _result(AttachmentRules.attach_any(actor().inventory, _selected(items))))
	# S-064: start or pause the selected copy's cumulative active time.
	activate_button = _add_button(item_action_row, "Activate", func(): _result(ActiveTimeRules.activate(actor(), _selected(items), int(GameManager.campaign_elapsed_seconds))))
	pause_button = _add_button(item_action_row, "Pause", func(): _result(ActiveTimeRules.pause(actor(), _selected(items))))
	# S-066: start, join or stop qualified work on the selected copy.
	_add_button(item_action_row, "Start work", func(): _result(WorkRules.start(actor(), _selected(items))))
	_add_button(item_action_row, "Join work", func(): _result(WorkRules.join(actor(), characters[recipients.selected], WorkRules.active_id(characters[recipients.selected]))))
	_add_button(item_action_row, "Stop work", func(): _result(WorkRules.stop(actor(), _selected(items))))
	# S-169: free the selected character from a tether by a check or by cutting it.
	_add_button(item_action_row, "Rescue", func(): _tether_action("check"))
	_add_button(item_action_row, "Cut tether", func(): _tether_action("strike"))
	# S-168: escape an exact tether outside combat.
	_add_button(item_action_row, "Escape tether", func(): _tether_action("escape"))
	detach_button = _add_button(item_action_row, "Detach", func(): _result(AttachmentRules.detach_last(actor().inventory, _selected(items))))
	refresh()
	hud.add_log("%s — select a character, then click a space to move or an object to interact. Each hex is five feet." % state.get("name", "Room"))

func actor() -> Character:
	return characters[actors.selected]

func _tether_action(mode: String) -> void:
	tether_popup_serial += 1
	var serial := tether_popup_serial
	var rescuer := actor()
	var victim: Character = rescuer if mode == "escape" else characters[recipients.selected]
	var bindings := TetherRules.binding(victim, characters)
	if mode != "escape": bindings = bindings.filter(func(b): return TetherRules.rescue_error(rescuer, victim, characters, mode, str(b.relation)).is_empty())
	if bindings.is_empty():
		_result({"success": false, "message": "No eligible tether is selected."})
		return
	if bindings.size() == 1:
		_tether_selected(rescuer, victim, mode, str(bindings[0].relation))
		return
	var menu := PopupMenu.new()
	menu.title = "Choose tether to escape" if mode == "escape" else "Choose tether to rescue"
	for binding in bindings:
		menu.add_item("%s (%s) · %s" % [binding.captor.character_name, DataLoader.get_spell(str(binding.tether.spell_id)).get("name", "Tether"), binding.relation])
	panel.add_child(menu)
	menu.id_pressed.connect(func(index):
		if serial == tether_popup_serial and index >= 0 and index < bindings.size():
			tether_popup_serial += 1
			_tether_selected(rescuer, victim, mode, str(bindings[index].relation))
		menu.queue_free())
	menu.popup_hide.connect(func(): menu.queue_free())
	menu.popup_centered(Vector2i(480, 180))

func _tether_selected(rescuer: Character, victim: Character, mode: String, relation: String) -> void:
	if actor() != rescuer or (mode != "escape" and characters[recipients.selected] != victim): return
	_result(TetherRules.escape(victim, characters, 0, relation) if mode == "escape" else TetherRules.rescue(rescuer, victim, characters, mode, relation))

func _selected(selector: OptionButton) -> String:
	return str(selector.get_item_metadata(selector.selected)) if selector.selected >= 0 else ""


func _body_target() -> Character:
	var selected := _selected(body_targets)
	for member in characters:
		if member.character_id == selected: return member
	return null


func _refresh_bodies() -> void:
	var previous := _selected(body_targets) if body_targets != null else ""
	for child in body_row.get_children():
		body_row.remove_child(child)
		child.queue_free()
	body_row.visible = characters.any(func(member): return member.current_hp <= 0) or "revivify" in actor().known_spells or "gentle_repose" in actor().known_spells
	if not body_row.visible: return
	body_targets = OptionButton.new()
	body_targets.name = "RecoveryTarget"
	for member in characters:
		body_targets.add_item(member.character_name)
		body_targets.set_item_metadata(body_targets.item_count - 1, member.character_id)
		if member.character_id == previous: body_targets.select(body_targets.item_count - 1)
	body_row.add_child(body_targets)
	body_targets.item_selected.connect(func(_index): _refresh_bodies())
	var target := _body_target()
	if target == null: return
	var status := Label.new()
	status.name = "RecoveryStatus"
	status.text = CorpseRules.status(target, int(GameManager.campaign_elapsed_seconds))
	body_row.add_child(status)
	var willingness := CheckBox.new()
	willingness.name = "RevivalWillingness"
	willingness.text = "Accept revival"
	willingness.button_pressed = target.revival_willing
	body_row.add_child(willingness)
	willingness.toggled.connect(func(accepted): target.revival_willing = accepted; flush.call())
	for spell_id in ["revivify", "gentle_repose"]:
		if spell_id not in actor().known_spells: continue
		var recovery_spell_id: String = spell_id
		_add_button(body_row, DataLoader.get_spell(spell_id)["name"], func():
			_result(LocalRoomBodies.cast(state, actor(), _body_target(), characters, recovery_spell_id)))
		if spell_id == "gentle_repose":
			_add_button(body_row, "Gentle Repose ritual (10 min)", func():
				_result(LocalRoomBodies.cast(state, actor(), _body_target(), characters, "gentle_repose", true)))


func _refresh_item_actions() -> void:
	if expand_pack_button == null or items == null:
		return
	var record := actor().inventory.get_instance(_selected(items))
	var definition := DataLoader.get_item(str(record.get("definition_id", "")))
	var is_ration := str(record.get("definition_id", "")) == "rations"
	ration_quarter_button.disabled = not is_ration
	ration_half_button.disabled = not is_ration
	ration_full_button.disabled = not is_ration
	expand_pack_button.disabled = definition.get("pack_contents", []).is_empty()
	var state: Dictionary = record.get("state", {})
	attune_button.disabled = not bool(definition.get("requires_attunement", false)) or not str(state.get("attuned_to", "")).is_empty()
	unattune_button.disabled = str(state.get("attuned_to", "")) != actor().character_id
	if detach_button != null: detach_button.disabled = AttachmentRules.attached(actor().inventory, str(record.get("instance_id", ""))).is_empty()
	if retrieve_button != null: retrieve_button.disabled = ContainerRules.contents(actor().inventory, str(record.get("instance_id", ""))).is_empty()

func click(position: Vector2i) -> void:
	if not pending_anchor_move_id.is_empty():
		if pending_anchor_move_choice.has("vessel"):
			var choice := pending_anchor_move_choice
			pending_anchor_move_id = ""
			pending_anchor_move_choice = {}
			if not is_same(choice.room, state) or not is_same(choice.actor, actor()) or choice.serial != containment_serial or choice.position != ContainmentRules.location(state, "character", choice.vessel.character_id, characters) or choice.rows != state.get("containment_occupants", []):
				_result(LocalRoomRules.failure("That vessel movement choice changed."))
				return
			_result(VesselProjectionRules.move(state, actor(), choice.vessel, position, grid, characters))
			return
		var anchor := LocalRoomRules.get_object(state, pending_anchor_move_id)
		pending_anchor_move_id = ""
		var choice := pending_anchor_move_choice
		pending_anchor_move_choice = {}
		if not choice.is_empty() and (not is_same(choice.body, anchor) or not is_same(choice.room, state) or not is_same(choice.actor, actor()) or choice.serial != containment_serial or choice.position != anchor.get("position") or choice.policy != ContainmentRules.policy(anchor) or choice.rows != state.get("containment_occupants", [])):
			_result(LocalRoomRules.failure("That container movement choice changed. Choose again."))
			return
		_result(TetherRules.move_object_anchor(anchor, state, position, characters))
		refresh()
		return
	if ContainmentRules.active(state):
		_result(LocalRoomRules.move(state, actor(), position, grid, "walk", characters))
		return
	if not pending_save_exit.is_empty():
		var options: Array = pending_save_exit.get("options", [])
		var ids: Array = pending_save_exit.get("ids", [])
		var index := options.find(position)
		if index < 0 or index + 1 >= ids.size():
			hud.add_log("That exit is no longer offered. Choose a highlighted room hex or cancel.")
			return
		_finish_save_exit_choice(str(ids[index + 1]))
		return
	if not pending_room_creation.is_empty():
		LocalRoomCreated.choose_destination(self, position)
		return
	if not pending_water_area_mode.is_empty():
		var mode := pending_water_area_mode
		pending_water_area_mode = ""
		_result(LocalRoomRules.create_or_destroy_water_area(state, mode, position, actor(), characters))
		return
	if not pending_teleport_spell.is_empty():
		var spell_id := pending_teleport_spell
		pending_teleport_spell = ""
		_result(LocalRoomRules.cast_teleport(state, spell_id, actor(), position, grid, characters))
		return
	var object := LocalRoomRules.object_at(state, position)
	if not object.is_empty():
		for index in objects.item_count:
			if _object_id(index) == str(object["id"]): objects.select(index); refresh(); return
	var mode := str(movement_modes.get_item_metadata(movement_modes.selected)) if movement_modes != null and movement_modes.item_count > 0 else "walk"
	_result(LocalRoomRules.move(state, actor(), position, grid, mode, characters))


func choose_save_exit(options: Array, ids: Array) -> String:
	if options.is_empty() or ids.size() != options.size() + 1: return ""
	save_exit_serial += 1
	var mine := save_exit_serial
	pending_save_exit = {"options": options.duplicate(), "ids": ids.duplicate(), "actor_id": actor().character_id}
	var highlights: Dictionary = {}
	for option in options: highlights[option] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	grid.set_highlights(highlights)
	var paused_controls: Array = []
	for control in panel.find_children("*", "BaseButton", true, false):
		paused_controls.append({"control": control, "disabled": control.disabled})
		control.disabled = true
	save_exit_cancel_button = _add_button(action_row, "Cancel exit", func(): _finish_save_exit_choice(""))
	hud.add_log("Choose a highlighted legal room hex for the required exit, or cancel.")
	var answer: String = await save_exit_choice_completed
	for paused in paused_controls:
		if is_instance_valid(paused.control): paused.control.disabled = paused.disabled
	if mine != save_exit_serial: return ""
	save_exit_serial += 1
	return answer


func _finish_save_exit_choice(answer: String) -> void:
	if pending_save_exit.is_empty(): return
	pending_save_exit.clear()
	grid.clear_highlights()
	if save_exit_cancel_button != null:
		save_exit_cancel_button.queue_free()
		save_exit_cancel_button = null
	save_exit_choice_completed.emit(answer)

func _object_id(index: int) -> String:
	return str(objects.get_item_metadata(index))

func refresh() -> void:
	ContainmentUI.refresh(self)
	_refresh_source_end_children()
	LocalRoomCreated.refresh(self)
	LocalRoomModes.refresh(self) # Batch 062: owned modes outside combat.
	ItemLifecycleUI.refresh_room(self)
	if movement_modes != null:
		var selected_mode := "walk"
		if movement_modes.item_count > 0 and movement_modes.selected >= 0: selected_mode = str(movement_modes.get_item_metadata(movement_modes.selected))
		movement_modes.clear()
		for mode in ["walk", "climb", "swim", "fly", "levitate"]:
			if LocalRoomRules.movement_speed_feet(actor(), mode) <= 0: continue
			movement_modes.add_item(mode.capitalize())
			movement_modes.set_item_metadata(movement_modes.item_count - 1, mode)
			if mode == selected_mode: movement_modes.select(movement_modes.item_count - 1)
		if movement_modes.selected < 0 and movement_modes.item_count > 0: movement_modes.select(0)
	grid.tiles.clear()
	grid.clear_entities()
	grid.clear_highlights()
	for cell in state["cells"]:
		var tile := HexTile.new()
		tile.coord = LocalRoomRules.coord(cell)
		tile.terrain = HexTile.TerrainType.WATER if LocalRoomRules.surface_at(state, tile.coord) == "water" else HexTile.TerrainType.ROAD
		tile.is_visible = true
		tile.is_revealed = true
		tile.custom_properties["blocks_movement"] = not LocalRoomRules.passable(state, tile.coord)
		tile.custom_properties["surface"] = LocalRoomRules.surface_at(state, tile.coord)
		tile.custom_properties["blocks_sight"] = LocalRoomRules.blocks_sight(state, tile.coord)
		tile.custom_properties["elevation_feet"] = LocalRoomRules.elevation_feet(state, tile.coord)
		tile.custom_properties["ceiling_feet"] = LocalRoomRules.ceiling_feet(state, tile.coord)
		if tile.custom_properties["blocks_movement"] and LocalRoomRules.has_wall(state, tile.coord):
			tile.custom_properties["wall_height_feet"] = LocalRoomRules.wall_height_feet(state, tile.coord)
			tile.custom_properties["wall_material"] = LocalRoomRules.wall_material(state, tile.coord)
		grid.add_tile(tile)
	for character in characters:
		if not ContainmentRules.relation(state, "character", character.character_id).is_empty(): continue
		grid.add_entity({"hex_position": LocalRoomRules.coord(state["party_positions"][character.character_id]), "character": character, "is_player": true, "color": Color(0.6, 0.8, 1.0)})
	for character in characters:
		if PaladinRules.find_steed_state(character).is_empty(): continue
		var steed_position := LocalRoomRules.find_steed_position(state, character, characters)
		if steed_position != Vector2i(9999, 9999):
			grid.add_entity({"hex_position": steed_position, "is_player": true, "is_steed": true, "name": "%s's Steed" % character.character_name, "color": Color(0.62, 0.43, 0.28)})
	for character in characters:
		var familiar_position := LocalRoomFamiliars.ensure_position(state, character, characters)
		if familiar_position != FamiliarRules.ABSENT:
			grid.add_entity({"hex_position": familiar_position, "character": FamiliarRules.character(character), "is_player": true, "is_familiar": true, "color": Color(0.55, 0.9, 0.65)})
	for owner in characters:
		for id in owner.item_projections:
			var projected := ItemProjectionRules.actor(owner, str(id))
			var position: Variant = state.get("created_actor_positions", {}).get(ItemProjectionRules.actor_id(str(id)), null)
			if projected != null and projected.is_alive and position is Array:
				grid.add_entity({"hex_position": LocalRoomRules.coord(position), "character": projected, "name": projected.character_name, "is_player": true, "is_created_actor": true, "color": Color(0.7, 0.6, 0.4)})
		for created in CreatedActorRules.actors(owner):
			var created_position: Variant = state.get("created_actor_positions", {}).get(created.character_id, null)
			if created_position is Array and created_position.size() == 2:
				grid.add_entity({"hex_position": LocalRoomRules.coord(created_position), "character": created, "name": created.character_name, "is_player": true, "is_created_actor": true, "color": Color(0.4, 0.8, 0.55)})
	for record in CreatedCreatureRules.room_records(state):
		grid.add_entity({"hex_position": LocalRoomRules.coord(record["position"]), "character": CreatedCreatureRules.character(record), "name": "%s %s" % [record["form_id"], record["serial"]], "is_player": CreatedCreatureRules.controlled(record), "color": Color(0.4, 0.8, 0.55) if CreatedCreatureRules.controlled(record) else Color.RED})
	if ContainmentRules.relation(state, "character", actor().character_id).is_empty(): grid.add_highlight(LocalRoomRules.coord(state["party_positions"][actor().character_id]), HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SELECTED])
	for exit in state["exits"]:
		grid.add_highlight(LocalRoomRules.coord(exit), HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.MOVEMENT])
	if not bool(state.get("encounter_cleared", false)):
		for index in state["encounter_monsters"].size():
			var monster := DataLoader.get_monster(str(state["encounter_monsters"][index])).duplicate(true)
			monster["monster_id"] = monster["id"]
			grid.add_entity({"hex_position": LocalRoomRules.coord(state["monster_spawns"][index]), "monster": monster, "is_player": false, "color": Color.RED})
	var selected := _selected(objects)
	objects.clear()
	for object in state["objects"]:
		if bool(object.get("removed", false)) or not ContainmentRules.relation(state, "object", str(object.id)).is_empty(): continue
		objects.add_item("%s%s" % [object["name"], " [locked]" if object.get("locked", false) else ""])
		objects.set_item_metadata(objects.item_count - 1, object["id"])
		if selected == str(object["id"]): objects.select(objects.item_count - 1)
		grid.add_entity({"hex_position": LocalRoomRules.coord(object["position"]), "world_object": object, "color": Color(0.85, 0.69, 0.39)})
	grid.selected_object_id = _object_id(objects.selected) if objects.selected >= 0 else ""
	objects.tooltip_text = objects.get_item_text(objects.selected) if objects.selected >= 0 else ""
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()
	# Shared spells revalidate containment crossings; encounter transfer still needs S-172.
	var occupied := ContainmentRules.active(state)
	for row in [familiar_summon_row, familiar_presence_row, body_row, created_row, mode_row, item_lifecycle_row, aftermath_row] + containment_item_rows: row.visible = not occupied
	if occupied and ContainmentRules.relation(state, "character", actor().character_id).is_empty() and not VesselProjectionRules.actors([actor()]).is_empty(): item_lifecycle_row.show()
	_refresh_shared_spells()
	if occupied:
		encounter_button.disabled = true
		grid.queue_redraw()
		return
	for movement_spell in ["fly", "levitate", "spider_climb", "freedom_of_movement", "water_walk"]:
		if movement_spell in actor().known_spells and SpellSupport.is_available(DataLoader.get_spell(movement_spell)):
			var selected_movement_spell: String = movement_spell
			_add_button(action_row, "Cast %s" % str(DataLoader.get_spell(selected_movement_spell).get("name", selected_movement_spell)), func():
				_result(LocalRoomRules.cast_movement_spell(state, selected_movement_spell, actor(), characters)))
	if "create_or_destroy_water" in actor().known_spells and SpellSupport.is_available(DataLoader.get_spell("create_or_destroy_water")):
		_add_button(action_row, "Create Water Rain", func():
			pending_water_area_mode = "rain"
			hud.add_log("Choose the center of the 30-foot rain cube."))
		_add_button(action_row, "Destroy Fog", func():
			pending_water_area_mode = "clear_fog"
			hud.add_log("Choose the center of the 30-foot cube to clear of fog."))
	for row in [familiar_summon_row, familiar_presence_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	familiar_summon_row.visible = actor().has_feature("druid_wild_companion") or "find_familiar" in actor().known_spells
	familiar_presence_row.visible = not FamiliarRules.state(actor()).is_empty()
	if actor().has_feature("druid_wild_companion"):
		var familiar_forms := OptionButton.new()
		for form in DruidRules.wild_companion_forms():
			familiar_forms.add_item(str(form.get("name", form["id"])))
			familiar_forms.set_item_metadata(familiar_forms.item_count - 1, form["id"])
		familiar_summon_row.add_child(familiar_forms)
		var shape_summon := _add_button(familiar_summon_row, "Familiar: Wild Shape use", func():
			_result(LocalRoomFamiliars.summon(state, actor(), characters, _selected(familiar_forms), "wild_shape")))
		shape_summon.disabled = int(actor().feature_uses.get("druid_wild_shape_uses", 0)) <= 0
		var slot_summon := _add_button(familiar_summon_row, "Familiar: spell slot", func():
			_result(LocalRoomFamiliars.summon(state, actor(), characters, _selected(familiar_forms), "spell_slot")))
		slot_summon.disabled = not actor().spell_slots.values().any(func(value): return int(value) > 0)
	if "find_familiar" in actor().known_spells:
		var spell_forms := OptionButton.new()
		for form in DruidRules.wild_companion_forms():
			spell_forms.add_item(str(form.get("name", form["id"])))
			spell_forms.set_item_metadata(spell_forms.item_count - 1, form["id"])
		familiar_summon_row.add_child(spell_forms)
		var creature_types := OptionButton.new()
		for type in ["celestial", "fey", "fiend"]:
			creature_types.add_item(type.capitalize())
			creature_types.set_item_metadata(creature_types.item_count - 1, type)
		familiar_summon_row.add_child(creature_types)
		_add_button(familiar_summon_row, "Find Familiar (1 hour)", func():
			_result(LocalRoomFamiliars.cast_find_familiar(state, actor(), characters, _selected(spell_forms), _selected(creature_types))))
		_add_button(familiar_summon_row, "Find Familiar ritual (70 min)", func():
			_result(LocalRoomFamiliars.cast_find_familiar(state, actor(), characters, _selected(spell_forms), _selected(creature_types), true)))
	var familiar_state := FamiliarRules.state(actor())
	_refresh_bodies()
	if not familiar_state.is_empty():
		var familiar_status := Label.new()
		familiar_status.text = "Familiar %d/%d HP%s" % [int(familiar_state["current_hp"]), int(familiar_state["max_hp"]), " · dismissed" if bool(familiar_state["pocket"]) else ""]
		familiar_presence_row.add_child(familiar_status)
		var presence_mode := "recall" if bool(familiar_state["pocket"]) else "dismiss"
		_add_button(familiar_presence_row, "Recall familiar" if presence_mode == "recall" else "Dismiss familiar", func():
			_result(LocalRoomFamiliars.change_presence(state, actor(), characters, presence_mode)))
		_add_button(familiar_presence_row, "Release familiar", func():
			_result(LocalRoomFamiliars.change_presence(state, actor(), characters, "release")))
	var steed_state := PaladinRules.find_steed_state(actor())
	if not steed_state.is_empty() and int(steed_state.get("current_hp", 0)) > 0:
		var mounted := bool(steed_state.get("mounted", false))
		_add_button(action_row, "Dismount Steed" if mounted else "Mount Steed", func():
			_result(LocalRoomRules.toggle_find_steed_mount(state, actor(), characters)))
	if "misty_step" in actor().known_spells and SpellSupport.is_available(DataLoader.get_spell("misty_step")):
		_add_button(action_row, "Misty Step", func():
			pending_teleport_spell = "misty_step"
			hud.add_log("Choose a visible, unoccupied space within 30 feet for Misty Step."))
	var actor_altitude := LocalRoomRules.altitude_feet(state, actor().character_id)
	var actor_floor := LocalRoomRules.elevation_feet(state, LocalRoomRules.coord(state["party_positions"][actor().character_id]))
	if actor().movement_speed_feet("fly") > 0 or actor_altitude > actor_floor:
		var altitude_label := Label.new()
		var room_ceiling := LocalRoomRules.ceiling_feet(state, LocalRoomRules.coord(state["party_positions"][actor().character_id]))
		altitude_label.text = "Altitude: %d ft · ceiling %d ft" % [actor_altitude, room_ceiling]
		action_row.add_child(altitude_label)
		if actor().movement_speed_feet("fly") > 0:
			var rise_button := _add_button(action_row, "Fly up 5 ft", func(): _result(LocalRoomRules.change_flight_altitude(state, actor(), 5)))
			rise_button.disabled = actor_altitude + 10 > LocalRoomRules.ceiling_feet(state, LocalRoomRules.coord(state["party_positions"][actor().character_id]))
			var descend_button := _add_button(action_row, "Fly down 5 ft", func(): _result(LocalRoomRules.change_flight_altitude(state, actor(), -5)))
			descend_button.disabled = actor_altitude <= actor_floor
		if SpellEffects.has_spell(actor(), "levitate"):
			var rise_button := _add_button(action_row, "Levitate up 5 ft", func(): _result(LocalRoomRules.change_levitation_altitude(state, actor(), 5)))
			rise_button.disabled = actor_altitude + 10 > LocalRoomRules.ceiling_feet(state, LocalRoomRules.coord(state["party_positions"][actor().character_id]))
			var descend_button := _add_button(action_row, "Levitate down 5 ft", func(): _result(LocalRoomRules.change_levitation_altitude(state, actor(), -5)))
			descend_button.disabled = actor_altitude - 5 < actor_floor
	_add_button(action_row, "End Turn", func(): _result(LocalRoomRules.end_local_turn(state, actor())))
	if actor().has_condition("restrained"):
		var has_tentacle_source := false
		var has_entangle_source := false
		for source_id in actor().condition_sources.get("restrained", {}):
			for area in state.get("areas", []):
				if str(area.get("spell_id", "")) == "black_tentacles" and str(area.get("concentration_source_id", "")) == str(source_id):
					has_tentacle_source = true
					break
				if str(area.get("spell_id", "")) == "entangle" and str(area.get("concentration_source_id", "")) == str(source_id):
					has_entangle_source = true
					break
		if has_tentacle_source:
			_add_button(action_row, "Escape (Athletics)", func(): _result(LocalRoomRules.escape_black_tentacles(state, actor())))
		if has_entangle_source:
			_add_button(action_row, "Escape Entangle (Athletics)", func(): _result(LocalRoomRules.escape_entangle(state, actor())))
		if SpellEffects.has_spell(actor(), "freedom_of_movement") and not CombatAction.nonmagical_restraint_sources(actor()).is_empty():
			_add_button(action_row, "Escape restraint (5 ft)", func(): _result(LocalRoomRules.escape_nonmagical_restraint(actor())))
	var object := LocalRoomRules.get_object(state, _selected(objects))
	if not object.is_empty():
		_add_button(action_row, "Inspect", func(): _interact("inspect"))
		if not object.get("tethers", {}).is_empty() and not bool(object.get("fixed", false)):
			_add_button(action_row, "Move tether anchor", func():
				pending_anchor_move_id = str(object.get("id", ""))
				pending_anchor_move_choice = ContainmentUI.movement_choice(self, object)
				hud.add_log("Choose a room hex for %s." % str(object.get("name", "the anchor"))))
		if str(object.get("kind", "")) == "barrier" and int(object.get("hp", 0)) > 0:
			_add_button(action_row, "Strike barrier", func(): _interact("strike"))
		if CombatObjectRules.can_take_spell_damage(object):
			for spell_id in actor().known_spells:
				var object_spell := DataLoader.get_spell(str(spell_id))
				if LocalRoomSharedSpells.object_spell(object_spell):
					var selected_spell_id := str(spell_id)
					_add_button(action_row, str(object_spell["name"]), func(): _result(LocalRoomSharedSpells.cast_object(state, actor(), selected_spell_id, str(object["id"]), characters, grid)))
		if bool(object.get("food_or_drink", false)) and not bool(object.get("magical", false)) and not object.get("contamination", []).is_empty() and "purify_food_and_drink" in actor().known_spells:
			_add_button(action_row, "Purify Food", func():
				_result(LocalRoomRules.purify_food_and_drink(state, str(object["id"]), actor())))
		if str(object.get("kind", "")) == "container" and bool(object.get("food_or_drink", false)) and "create_or_destroy_water" in actor().known_spells:
			_add_button(action_row, "Create Water", func():
				_result(LocalRoomRules.create_or_destroy_water(state, str(object["id"]), "create", actor())))
			if float(object.get("water_gallons", 0.0)) > 0.0:
				_add_button(action_row, "Destroy Water", func():
					_result(LocalRoomRules.create_or_destroy_water(state, str(object["id"]), "destroy", actor())))
		if bool(object.get("food_or_drink", false)) and not bool(object.get("magical", false)):
			if float(object.get("food_servings", 0.0)) > 0.0:
				var daily_food_need := SurvivalRules.food_need_for_character(actor())
				_add_button(action_row, "Eat ¼ day", func(): _result(LocalRoomRules.eat_food(state, str(object["id"]), actor(), daily_food_need * 0.25)))
				_add_button(action_row, "Eat ½ day", func(): _result(LocalRoomRules.eat_food(state, str(object["id"]), actor(), daily_food_need * 0.5)))
				_add_button(action_row, "Eat full day", func(): _result(LocalRoomRules.eat_food(state, str(object["id"]), actor(), daily_food_need)))
			if float(object.get("water_gallons", 0.0)) > 0.0:
				var daily_water_need := SurvivalRules.water_need_for_character(actor())
				_add_button(action_row, "Drink ¼ day", func(): _result(LocalRoomRules.drink_water(state, str(object["id"]), actor(), daily_water_need * 0.25)))
				_add_button(action_row, "Drink ½ day", func(): _result(LocalRoomRules.drink_water(state, str(object["id"]), actor(), daily_water_need * 0.5)))
				_add_button(action_row, "Drink full day", func(): _result(LocalRoomRules.drink_water(state, str(object["id"]), actor(), daily_water_need)))
		if "prestidigitation" in actor().known_spells:
			if float(object.get("volume_cubic_feet", 1001.0)) <= 1.0:
				_add_button(action_row, "Clean", func():
					_result(LocalRoomRules.prestidigitation(state, str(object["id"]), "clean", actor())))
				_add_button(action_row, "Soil", func():
					_result(LocalRoomRules.prestidigitation(state, str(object["id"]), "soil", actor())))
			_add_button(action_row, "Warm", func():
				_result(LocalRoomRules.prestidigitation(state, str(object["id"]), "warm", actor())))
			_add_button(action_row, "Cool", func():
				_result(LocalRoomRules.prestidigitation(state, str(object["id"]), "cool", actor())))
		if bool(object.get("burning", false)):
			_add_button(action_row, "Extinguish", func(): _interact("extinguish"))
		if str(object.get("kind", "")) == "door" and "alarm" in actor().known_spells:
			var alarm_mode := OptionButton.new()
			alarm_mode.add_item("Bell alert")
			alarm_mode.set_item_metadata(0, "audible")
			alarm_mode.add_item("Mental alert")
			alarm_mode.set_item_metadata(1, "mental")
			alarm_mode.select(0)
			action_row.add_child(alarm_mode)
			_add_button(action_row, "Alarm", func():
				_result(LocalRoomRules.cast_alarm(state, str(object["id"]), str(alarm_mode.get_item_metadata(alarm_mode.selected)), actor(), characters)))
			_add_button(action_row, "Ritual Alarm", func():
				_result(LocalRoomRules.cast_alarm(state, str(object["id"]), str(alarm_mode.get_item_metadata(alarm_mode.selected)), actor(), characters, true)))
		if str(object.get("kind", "")) in ["door", "container"]:
			_add_button(action_row, "Close" if object.get("open", false) else "Open", func(): _interact("close" if object.get("open", false) else "open"))
			if object.get("lockable", false):
				_add_button(action_row, "Unlock" if object.get("locked", false) else "Lock", func(): _interact("unlock" if object.get("locked", false) else "lock"))
				if object.get("locked", false):
					_add_button(action_row, "Pick lock", func(): _interact("pick_lock"))
					if actor().inventory.has_item("crowbar"): _add_button(action_row, "Pry", func(): _interact("pry"))
		if SpellEffects.goodberry_count_for_party(characters) > 0:
			_add_button(action_row, "Eat Goodberry", func(): _result(LocalRoomRules.eat_goodberry(characters, actor())))
		contents = OptionButton.new()
		contents.fit_to_longest_item = false
		contents.clip_text = true
		contents.custom_minimum_size.x = 120
		for record in object["contents"]:
			contents.add_item(InventoryCopies.display_name(record, contents.item_count + 1))
			contents.set_item_metadata(contents.item_count - 1, record["instance_id"])
		action_row.add_child(contents)
		var take_button := _add_button(action_row, "Take", func(): _interact("take", _selected(contents)))
		take_button.disabled = contents.item_count == 0
		if str(object.get("kind", "")) == "container": _add_button(action_row, "Put", func(): _interact("put", _selected(items)))
	var selected_item_id := _selected(items)
	items.clear()
	var selected_item_index := -1
	for record in actor().inventory.backpack_instances():
		items.add_item(InventoryCopies.display_name(record, items.item_count + 1))
		items.set_item_metadata(items.item_count - 1, record["instance_id"])
		if str(record["instance_id"]) == selected_item_id:
			selected_item_index = items.item_count - 1
	if items.item_count > 0:
		items.select(selected_item_index if selected_item_index >= 0 else 0)
	_refresh_item_actions()
	encounter_button.text = "Face hostile Undead" if CreatedCreatureRules.hostile_in_room(state) else "Face the guardian"
	encounter_button.disabled = bool(state.get("encounter_cleared", false)) and not CreatedCreatureRules.hostile_in_room(state)
	hud.btn_rest.disabled = true
	hud.update_hud()
	grid.queue_redraw()

func _interact(action: String, instance_id: String = "") -> void:
	_result(LocalRoomRules.interact(state, _selected(objects), action, actor(), instance_id))

func _refresh_shared_spells() -> void:
	var selected_serial := containment_serial
	var selected_caster := actor()
	var selected_room := state
	var selected_relations: Array = state.get("containment_occupants", []).duplicate()
	var selected_containers: Array = selected_relations.map(func(r): return ContainmentRules.entity(state, characters, r.container_kind, r.container_id))
	var target_bodies := {}
	var spells := OptionButton.new()
	spells.name = "RoomSharedSpells"
	for spell_id in actor().known_spells:
		var spell := DataLoader.get_spell(str(spell_id))
		if not LocalRoomSharedSpells.party_spell(spell) and not LocalRoomSharedSpells.object_spell(spell): continue
		spells.add_item(str(spell["name"]))
		spells.set_item_metadata(spells.item_count - 1, str(spell_id))
	if spells.item_count == 0:
		spells.free()
		return
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = "Spells"
	row.add_child(label)
	row.add_child(spells)
	var targets := OptionButton.new()
	targets.name = "RoomSharedSpellTargets"
	row.add_child(targets)
	var refresh_targets := func():
		targets.clear()
		target_bodies.clear()
		var spell := DataLoader.get_spell(str(spells.get_item_metadata(spells.selected)))
		if LocalRoomSharedSpells.party_spell(spell):
			for character: Character in characters:
				if character.is_dead() or (spell.get("target", "single") == "self" and character != actor()): continue
				if not ContainmentRules.target_error(actor(), character, spell, state, characters).is_empty(): continue
				targets.add_item(character.character_name + " · " + character.character_id)
				targets.set_item_metadata(targets.item_count - 1, "party:" + character.character_id)
				target_bodies["party:" + character.character_id] = character
		if LocalRoomSharedSpells.object_spell(spell):
			for object in state["objects"]:
				if not CombatObjectRules.can_take_spell_damage(object, true) or not ContainmentRules.target_error(actor(), object, spell, state, characters).is_empty(): continue
				targets.add_item(str(object["name"]) + " · " + str(object.id))
				targets.set_item_metadata(targets.item_count - 1, "object:" + str(object["id"]))
				target_bodies["object:" + str(object["id"])] = object
	spells.item_selected.connect(func(_index): refresh_targets.call())
	refresh_targets.call()
	_add_button(row, "Cast", func():
		if not pending_save_exit.is_empty(): return
		if targets.selected < 0: return
		if selected_serial != containment_serial or actor() != selected_caster or not is_same(state, selected_room): return
		var current_relations: Array = state.get("containment_occupants", [])
		var relations_current := current_relations.size() == selected_relations.size()
		for i in mini(current_relations.size(), selected_relations.size()):
			var r: Dictionary = selected_relations[i]
			if not is_same(current_relations[i], r) or not is_same(ContainmentRules.entity(state, characters, r.container_kind, r.container_id), selected_containers[i]): relations_current = false
		var selected_id := str(targets.get_item_metadata(targets.selected))
		var selected_kind := "character" if selected_id.begins_with("party:") else "object"
		if not relations_current or not is_same(target_bodies.get(selected_id), ContainmentRules.entity(state, characters, selected_kind, selected_id.substr(selected_id.find(":") + 1))):
			_result(LocalRoomRules.failure("That exact spell target or containment source changed. Choose again."))
			return
		var spell_id := str(spells.get_item_metadata(spells.selected))
		var selected_spell := DataLoader.get_spell(spell_id)
		if not CreatedActorRules._effect(selected_spell).is_empty():
			LocalRoomCreated.begin_creation(self, spell_id)
			return
		var target_id := str(targets.get_item_metadata(targets.selected))
		if target_id.begins_with("object:"):
			_result(LocalRoomSharedSpells.cast_object(state, actor(), spell_id, target_id.trim_prefix("object:"), characters, grid))
		else:
			for character: Character in characters:
				if character.character_id == target_id.trim_prefix("party:"):
					if selected_spell.has("save_exit_placement"):
						_result(await LocalRoomSharedSpells.cast_with_save_exit(state, actor(), spell_id, character, characters, grid, Callable(self, "choose_save_exit")))
					else:
						_result(LocalRoomSharedSpells.cast(state, actor(), spell_id, character, characters, grid))
					break)
	action_row.add_child(row)


func _result(result: Dictionary) -> void:
	var acting_body: Character = result.get("acting_body", actor())
	for outcome in result.get("heat_outcomes", []):
		hud.add_log("%s takes %d Fire damage from the hot surface (%s)." % [acting_body.character_name, int(outcome.get("damage", 0)), str(outcome.get("damage_formula", ""))])
	for outcome in result.get("spike_growth_outcomes", []):
		hud.add_log("%s takes %d Piercing damage from Spike Growth (%s)." % [acting_body.character_name, int(outcome.get("damage", 0)), str(outcome.get("damage_formula", "2d4"))])
	for outcome in result.get("end_turn_outcomes", []):
		if str(outcome.get("spell_id", "")) == "surface_heat":
			hud.add_log("%s takes %d Fire damage from the hot surface (%s)." % [acting_body.character_name, int(outcome.get("damage", 0)), str(outcome.get("damage_formula", ""))])
		elif str(outcome.get("spell_id", "")) == "wall_of_fire":
			hud.add_log("%s takes %d Fire damage from Wall of Fire (%s)." % [acting_body.character_name, int(outcome.get("damage", 0)), str(outcome.get("damage_formula", "5d8"))])
		elif str(outcome.get("spell_id", "")) == "cloud_of_daggers":
			hud.add_log("%s takes %d Slashing damage from Cloud of Daggers (%s)." % [acting_body.character_name, int(outcome.get("damage", 0)), str(outcome.get("damage_formula", "4d4"))])
		elif str(outcome.get("spell_id", "")) == "grease":
			var grease_turn_text := "succeeds" if bool(outcome.get("saved", false)) else "fails and falls Prone"
			hud.add_log("%s %s the Grease end-of-turn Dexterity save (%d vs DC %d)." % [acting_body.character_name, grease_turn_text, int(outcome.get("save_total", 0)), int(outcome.get("save_dc", 0))])
		elif str(outcome.get("spell_id", "")) == "sleet_storm":
			var storm_turn_text := "succeeds" if bool(outcome.get("saved", false)) else "fails and falls Prone"
			hud.add_log("%s %s the Sleet Storm end-of-turn Dexterity save (%d vs DC %d)." % [acting_body.character_name, storm_turn_text, int(outcome.get("save_total", 0)), int(outcome.get("save_dc", 0))])
		elif str(outcome.get("spell_id", "")) == "moonbeam":
			var moonbeam_turn_text := "succeeds" if bool(outcome.get("saved", false)) else "fails"
			hud.add_log("%s %s the Moonbeam Constitution save (%d vs DC %d) and takes %d Radiant damage (%s)." % [acting_body.character_name, moonbeam_turn_text, int(outcome.get("save_total", 0)), int(outcome.get("save_dc", 0)), int(outcome.get("damage", 0)), str(outcome.get("damage_formula", "2d10"))])
		else:
			var turn_save_text := "succeeds" if bool(outcome.get("saved", false)) else "fails, takes %d Bludgeoning damage, and is Restrained" % int(outcome.get("damage", 0))
			hud.add_log("%s %s the Black Tentacles end-of-turn Strength save (%d vs DC %d)." % [acting_body.character_name, turn_save_text, int(outcome.get("save_total", 0)), int(outcome.get("save_dc", 0))])
	for outcome in LocalRoomRules.resolve_area_entries(result.get("entered_areas", []), acting_body):
		if str(outcome.get("spell_id", "")) == "wall_of_fire":
			hud.add_log("%s takes %d Fire damage from Wall of Fire (%s)." % [acting_body.character_name, int(outcome.get("damage", 0)), str(outcome.get("damage_formula", "5d8"))])
		elif str(outcome.get("spell_id", "")) == "cloud_of_daggers":
			hud.add_log("%s takes %d Slashing damage from Cloud of Daggers (%s)." % [acting_body.character_name, int(outcome.get("damage", 0)), str(outcome.get("damage_formula", "4d4"))])
		elif str(outcome.get("spell_id", "")) == "grease":
			var grease_text := "succeeds" if bool(outcome.get("saved", false)) else "fails and falls Prone"
			hud.add_log("%s %s the Grease Dexterity save (%d vs DC %d)." % [acting_body.character_name, grease_text, int(outcome.get("save_total", 0)), int(outcome.get("save_dc", 0))])
		elif str(outcome.get("spell_id", "")) == "sleet_storm":
			var storm_text := "succeeds" if bool(outcome.get("saved", false)) else "fails and falls Prone"
			hud.add_log("%s %s the Sleet Storm Dexterity save (%d vs DC %d)." % [acting_body.character_name, storm_text, int(outcome.get("save_total", 0)), int(outcome.get("save_dc", 0))])
		elif str(outcome.get("spell_id", "")) == "moonbeam":
			var moonbeam_text := "succeeds" if bool(outcome.get("saved", false)) else "fails"
			var reverted_text := "; reverts from Wild Shape and cannot shape-shift until leaving" if bool(outcome.get("shape_reverted", false)) else ""
			hud.add_log("%s %s the Moonbeam Constitution save (%d vs DC %d), takes %d Radiant damage (%s)%s." % [acting_body.character_name, moonbeam_text, int(outcome.get("save_total", 0)), int(outcome.get("save_dc", 0)), int(outcome.get("damage", 0)), str(outcome.get("damage_formula", "2d10")), reverted_text])
		elif str(outcome.get("spell_id", "")) == "black_tentacles":
			var tentacle_text := "succeeds" if bool(outcome.get("saved", false)) else "fails, takes %d Bludgeoning damage, and is Restrained" % int(outcome.get("damage", 0))
			hud.add_log("%s %s the Black Tentacles Strength save (%d vs DC %d)." % [acting_body.character_name, tentacle_text, int(outcome.get("save_total", 0)), int(outcome.get("save_dc", 0))])
	for notification in GameManager.advance_campaign_time(int(result.get("seconds", 0))):
		if notification.has("message"): hud.add_log(str(notification.message))
	for fire_message in LocalRoomRules.advance_burning_objects(state, int(GameManager.campaign_elapsed_seconds)):
		hud.add_log(fire_message)
	for fall_message in LocalRoomRules.reconcile_flight_altitudes(state, characters):
		hud.add_log(fall_message)
	hud.add_log(str(result.get("message", "")))
	flush.call()
	refresh()

func _refresh_source_end_children() -> void:
	if aftermath_row == null: return
	for widget in aftermath_row.get_children():
		aftermath_row.remove_child(widget)
		widget.queue_free()
	var requests := LocatedSourceEndRules.observe(state, characters)
	for request in requests:
		var invocation := str(request.invocation)
		var child_id := str(request.child_id)
		_add_button(aftermath_row, "Continue: " + child_id, func():
			var result := LocatedSourceEndRules.answer(state, invocation, child_id, true, characters)
			_result({"success": result.get("success", false), "message": "Source-end child: " + child_id}))
		_add_button(aftermath_row, "Cancel: " + child_id, func():
			var result := LocatedSourceEndRules.answer(state, invocation, child_id, false, characters)
			_result({"success": result.get("success", false), "message": "Source-end child canceled: " + child_id}))
	aftermath_row.visible = not requests.is_empty()

func stop() -> void:
	containment_serial += 1
	save_exit_serial += 1
	_finish_save_exit_choice("")
	item_lifecycle_serial += 1
	hud.btn_rest.disabled = false
	if is_instance_valid(panel):
		panel.get_child(0).reparent(panel.get_parent())
		panel.get_parent().remove_child(panel)
		panel.queue_free()

func _add_button(row: Container, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	row.add_child(button)
	return button
