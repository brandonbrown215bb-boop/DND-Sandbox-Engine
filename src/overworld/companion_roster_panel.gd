## Camp roster UI for the production overworld.
## Owns presentation and user intent; PartyManager remains the lifecycle boundary.
class_name CompanionRosterPanel
extends PanelContainer

signal close_requested
signal lifecycle_changed(message: String)

@onready var capacity_label: Label = $Margin/VBox/Header/CapacityLabel
@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var companion_list: VBoxContainer = $Margin/VBox/Scroll/CompanionList
@onready var feedback_label: Label = $Margin/VBox/FeedbackLabel

## Stable test/accessibility surface: companion ID -> controls currently shown.
var companion_controls: Dictionary = {}


func _ready() -> void:
	close_button.pressed.connect(func(): close_requested.emit())
	if not PartyManager.party_changed.is_connected(_on_party_changed):
		PartyManager.party_changed.connect(_on_party_changed)
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	for child in companion_list.get_children():
		child.queue_free()
	companion_controls.clear()
	var party_count := PartyManager.get_active_characters().size()
	capacity_label.text = "%d / %d active  •  %d open" % [
		party_count,
		PartyManager.MAX_PARTY_SIZE,
		PartyManager.get_empty_slot_count(),
	]
	var companion_ids := PartyManager.get_companion_ids()
	if companion_ids.is_empty():
		var empty := Label.new()
		empty.text = "No companions are available in this campaign."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		companion_list.add_child(empty)
		return
	for companion_id in companion_ids:
		_build_companion_card(companion_id)


func _build_companion_card(companion_id: String) -> void:
	var character := PartyManager.get_companion_character(companion_id)
	if character == null:
		return
	var state := PartyManager.get_companion_state(companion_id)
	var controls: Dictionary = {}
	var card := PanelContainer.new()
	card.name = "Companion_%s" % companion_id
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	vbox.add_child(heading)
	var name_label := Label.new()
	name_label.text = character.character_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	heading.add_child(name_label)
	var state_label := Label.new()
	state_label.text = _state_label(state)
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", _state_color(state))
	heading.add_child(state_label)

	var detail := Label.new()
	detail.text = "%s  •  %s" % [
		DataLoader.get_race(character.race_id).get("name", character.race_id),
		DataLoader.get_character_class(character.class_id).get("name", character.class_id),
	]
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", Color(0.72, 0.70, 0.65))
	vbox.add_child(detail)

	match state:
		"recruited":
			_build_recruited_actions(vbox, companion_id, controls)
		"available":
			_build_available_actions(vbox, companion_id, controls)
		"declined", "dismissed":
			_build_return_action(vbox, companion_id, state, controls)
		_:
			var warning := Label.new()
			warning.text = "Unavailable"
			vbox.add_child(warning)

	companion_controls[companion_id] = controls
	companion_list.add_child(card)


func _build_recruited_actions(vbox: VBoxContainer, companion_id: String, controls: Dictionary) -> void:
	var slot_id := PartyManager.get_companion_slot_id(companion_id)
	var owner := PlayerManager.get_player_for_party_slot(slot_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	var owner_label := Label.new()
	owner_label.text = "Controlled by"
	row.add_child(owner_label)
	var owner_selector := _build_seat_selector(owner)
	owner_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_selector.item_selected.connect(_on_owner_selected.bind(companion_id, slot_id, owner_selector))
	row.add_child(owner_selector)
	var dismiss_button := Button.new()
	dismiss_button.text = "Dismiss"
	dismiss_button.pressed.connect(_on_dismiss_pressed.bind(companion_id))
	row.add_child(dismiss_button)
	controls["owner_selector"] = owner_selector
	controls["dismiss_button"] = dismiss_button


func _build_available_actions(vbox: VBoxContainer, companion_id: String, controls: Dictionary) -> void:
	var seat_selector := _build_seat_selector(PlayerManager.active_player_index)
	controls["seat_selector"] = seat_selector
	if PartyManager.get_empty_slot_count() > 0:
		var recruit_row := HBoxContainer.new()
		recruit_row.add_theme_constant_override("separation", 8)
		vbox.add_child(recruit_row)
		var join_label := Label.new()
		join_label.text = "Join under"
		recruit_row.add_child(join_label)
		seat_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recruit_row.add_child(seat_selector)
		var recruit_button := Button.new()
		recruit_button.text = "Recruit"
		recruit_button.pressed.connect(_on_recruit_pressed.bind(companion_id, seat_selector))
		recruit_row.add_child(recruit_button)
		controls["recruit_button"] = recruit_button
	else:
		var replace_row := HBoxContainer.new()
		replace_row.add_theme_constant_override("separation", 8)
		vbox.add_child(replace_row)
		var replace_selector := OptionButton.new()
		for outgoing_id in PartyManager.get_recruited_companions():
			var outgoing := PartyManager.get_companion_character(outgoing_id)
			if outgoing == null:
				continue
			var item_index := replace_selector.item_count
			replace_selector.add_item(outgoing.character_name)
			replace_selector.set_item_metadata(item_index, outgoing_id)
		replace_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replace_row.add_child(replace_selector)
		seat_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replace_row.add_child(seat_selector)
		var replace_button := Button.new()
		replace_button.text = "Replace"
		replace_button.disabled = replace_selector.item_count == 0
		replace_button.pressed.connect(_on_replace_pressed.bind(companion_id, replace_selector, seat_selector))
		replace_row.add_child(replace_button)
		controls["replace_selector"] = replace_selector
		controls["replace_button"] = replace_button

	var decline_button := Button.new()
	decline_button.text = "Not now"
	decline_button.tooltip_text = "Move this companion out of the active invitation list."
	decline_button.pressed.connect(_on_decline_pressed.bind(companion_id))
	vbox.add_child(decline_button)
	controls["decline_button"] = decline_button


func _build_return_action(vbox: VBoxContainer, companion_id: String, state: String, controls: Dictionary) -> void:
	var return_button := Button.new()
	return_button.text = "Reconsider" if state == "declined" else "Invite back"
	return_button.pressed.connect(_on_reconsider_pressed.bind(companion_id))
	vbox.add_child(return_button)
	controls["reconsider_button"] = return_button


func _build_seat_selector(selected_seat: int) -> OptionButton:
	var selector := OptionButton.new()
	for seat_index in PlayerManager.get_player_count():
		selector.add_item("Seat %d" % (seat_index + 1), seat_index)
	if selected_seat >= 0 and selected_seat < selector.item_count:
		selector.select(selected_seat)
	return selector


func _on_recruit_pressed(companion_id: String, seat_selector: OptionButton) -> void:
	var seat := seat_selector.get_selected_id()
	if PartyManager.recruit_companion(companion_id, seat):
		_emit_change("%s joined the party under Seat %d." % [_companion_name(companion_id), seat + 1])
	else:
		_set_feedback("Recruitment failed. Check party capacity.", false)


func _on_decline_pressed(companion_id: String) -> void:
	if PartyManager.decline_companion(companion_id):
		_emit_change("%s will wait at camp." % _companion_name(companion_id))
	else:
		_set_feedback("That invitation is no longer available.", false)


func _on_reconsider_pressed(companion_id: String) -> void:
	if PartyManager.reconsider_companion(companion_id):
		_emit_change("%s is available again." % _companion_name(companion_id))
	else:
		_set_feedback("That companion cannot return right now.", false)


func _on_dismiss_pressed(companion_id: String) -> void:
	if PartyManager.dismiss_companion(companion_id):
		_emit_change("%s left the active party." % _companion_name(companion_id))
	else:
		_set_feedback("Dismissal failed.", false)


func _on_owner_selected(index: int, companion_id: String, slot_id: String, selector: OptionButton) -> void:
	var seat := selector.get_item_id(index)
	if PartyManager.assign_slot_to_seat(slot_id, seat):
		_emit_change("%s is now controlled by Seat %d." % [_companion_name(companion_id), seat + 1])
	else:
		_set_feedback("Seat reassignment failed.", false)


func _on_replace_pressed(incoming_id: String, replace_selector: OptionButton, seat_selector: OptionButton) -> void:
	if replace_selector.item_count == 0:
		_set_feedback("No recruited companion can be replaced.", false)
		return
	var outgoing_id := str(replace_selector.get_item_metadata(replace_selector.selected))
	var seat := seat_selector.get_selected_id()
	if PartyManager.replace_companion(outgoing_id, incoming_id, seat):
		_emit_change("%s replaces %s under Seat %d." % [
			_companion_name(incoming_id),
			_companion_name(outgoing_id),
			seat + 1,
		])
	else:
		_set_feedback("Replacement failed.", false)


func _on_party_changed() -> void:
	refresh()


func _emit_change(message: String) -> void:
	_set_feedback(message, true)
	lifecycle_changed.emit(message)


func _set_feedback(message: String, success: bool) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.55, 0.82, 0.48) if success else Color(0.92, 0.45, 0.38)
	)


func _companion_name(companion_id: String) -> String:
	var character := PartyManager.get_companion_character(companion_id)
	return character.character_name if character != null else companion_id


func _state_label(state: String) -> String:
	match state:
		"recruited": return "IN PARTY"
		"available": return "AVAILABLE"
		"declined": return "AT CAMP"
		"dismissed": return "DISMISSED"
	return state.to_upper()


func _state_color(state: String) -> Color:
	match state:
		"recruited": return Color(0.55, 0.82, 0.48)
		"available": return Color(0.95, 0.78, 0.35)
		"declined": return Color(0.65, 0.68, 0.72)
		"dismissed": return Color(0.82, 0.50, 0.42)
	return Color.WHITE
