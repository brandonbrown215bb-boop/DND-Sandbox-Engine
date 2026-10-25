## The same exact-copy chooser in combat Features and the room's item controls.
class_name ItemLifecycleUI
extends RefCounted

static func refresh_room(view: LocalRoomView) -> void:
	var selected := ""
	if view.item_lifecycle_offers != null and is_instance_valid(view.item_lifecycle_offers) and view.item_lifecycle_offers.selected >= 0:
		var old: Dictionary = view.item_lifecycle_offers.get_item_metadata(view.item_lifecycle_offers.selected)
		selected = str(old.instance_id) + str(old.kind) + str(old.bond_id)
	for child in view.item_lifecycle_row.get_children():
		view.item_lifecycle_row.remove_child(child)
		child.queue_free()
	var offers := ItemLifecycleControls.offers(view.actor())
	view.item_lifecycle_row.visible = not offers.is_empty()
	view.item_lifecycle_offers = OptionButton.new()
	view.item_lifecycle_offers.name = "ItemLifecycleOffers"
	view.item_lifecycle_offers.fit_to_longest_item = false
	view.item_lifecycle_offers.clip_text = true
	view.item_lifecycle_offers.custom_minimum_size.x = 250
	view.item_lifecycle_row.add_child(view.item_lifecycle_offers)
	for offer in offers:
		view.item_lifecycle_offers.add_item(offer.text)
		view.item_lifecycle_offers.set_item_metadata(view.item_lifecycle_offers.item_count - 1, offer)
		if str(offer.instance_id) + str(offer.kind) + str(offer.bond_id) == selected: view.item_lifecycle_offers.select(view.item_lifecycle_offers.item_count - 1)
	view._add_button(view.item_lifecycle_row, "Use item control", func(): open_room(view))
	var cargo_items := OptionButton.new()
	cargo_items.name = "VesselCargoItems"
	cargo_items.fit_to_longest_item = false
	cargo_items.custom_minimum_size.x = 120
	for copy in view.actor().inventory.backpack_instances():
		cargo_items.add_item(InventoryCopies.display_name(copy, cargo_items.item_count + 1))
		cargo_items.set_item_metadata(cargo_items.item_count - 1, str(copy.instance_id))
	view.item_lifecycle_row.add_child(cargo_items)
	view._add_button(view.item_lifecycle_row, "Stow cargo", func():
		if view.item_lifecycle_offers.selected < 0: return
		var offer: Dictionary = view.item_lifecycle_offers.get_item_metadata(view.item_lifecycle_offers.selected)
		var record := ItemLifecycleControls.copy_for(view.actor(), str(offer.instance_id))
		var compartments := ContainerRules.compartments(str(record.get("definition_id", "")))
		if compartments.is_empty(): view._result(LocalRoomRules.failure("That copy has no cargo compartment.")); return
		view._result(ContainerRules.put(view.actor().inventory, str(offer.instance_id), view._selected(cargo_items), str(compartments.keys()[0]))))
	view._add_button(view.item_lifecycle_row, "Take out cargo", func():
		if view.item_lifecycle_offers.selected < 0: return
		var offer: Dictionary = view.item_lifecycle_offers.get_item_metadata(view.item_lifecycle_offers.selected)
		view._result(ContainerRules.retrieve_last(view.actor().inventory, str(offer.instance_id))))

static func open_room(view: LocalRoomView) -> void:
	if view.item_lifecycle_offers.selected < 0: return
	var offer: Dictionary = view.item_lifecycle_offers.get_item_metadata(view.item_lifecycle_offers.selected)
	view.item_lifecycle_serial += 1
	var result := await request(view, view.actor(), offer, view.item_lifecycle_serial)
	view._result(result)

static func request(view, owner: Character, offer: Dictionary, serial: int) -> Dictionary:
	var room := view is LocalRoomView
	var budget: Object = ModeControls.outside_combat() if room else view.get_parent()
	var parent: Node = view.panel if room else view
	var turn := CombatAction.active_turn_serial
	var blocked := ItemLifecycleControls.error(owner, offer, budget)
	if not blocked.is_empty(): return ItemLifecycleControls.fail(blocked)
	var host = LocalRoomCreated._placement_state(view) if room else budget
	var origin := _origin(view, owner)
	var picks: Array = []
	var no_space := false
	var options: Array[String] = ["cancel"]
	var labels := {"cancel": "Cancel"}
	if offer.kind == "project":
		var policy := ItemProjectionRules._policy(str(ItemLifecycleControls.copy_for(owner, str(offer.instance_id)).definition_id))
		var placement := PlacementRules.policy(policy)
		var legal := PlacementRules.candidates(host, origin, str(policy.template.size), int(placement.range_hexes))
		if legal.is_empty():
			if placement.no_space != "spend": return ItemLifecycleControls.fail("No legal projection destination; nothing was spent.")
			no_space = true
			options.append("confirm")
			labels.confirm = "Pay activation (no space; no form)"
		elif placement.choose:
			for hex in legal:
				var key := str(options.size())
				options.append(key)
				labels[key] = "Hex (%d, %d)" % [hex.x, hex.y]
		else:
			picks = [legal[0]]
			options.append("confirm")
			labels.confirm = "Project at (%d, %d)" % [legal[0].x, legal[0].y]
	else:
		options.append("confirm")
		labels.confirm = str(offer.text)
	var picked := await _choose(parent, "Item: " + str(offer.text), options, labels)
	if picked.is_empty() or picked == "cancel": return ItemLifecycleControls.fail("Item control canceled; nothing was spent.")
	if not is_instance_valid(parent) or not parent.is_inside_tree(): return ItemLifecycleControls.fail("That room or encounter has closed.")
	if serial != view.item_lifecycle_serial or (view.actor() != owner if room else view.active_character != owner or turn != CombatAction.active_turn_serial): return ItemLifecycleControls.fail("That choice is no longer current; nothing was spent.")
	# Consume this popup before committing; a duplicate signal cannot replay it.
	view.item_lifecycle_serial += 1
	if picked != "confirm":
		var parts := str(labels[picked]).trim_prefix("Hex (").trim_suffix(")").split(", ")
		picks = [Vector2i(int(parts[0]), int(parts[1]))]
	host = LocalRoomCreated._placement_state(view) if room else budget
	return ItemLifecycleControls.apply(owner, offer, host, _origin(view, owner), picks, no_space, budget)

static func _origin(view, owner: Character) -> Vector2i:
	if view is LocalRoomView: return LocalRoomRules.coord(view.state.get("party_positions", {}).get(owner.character_id, [-9999, -9999]))
	for entity in view.get_parent().player_entities:
		if entity.get("character") == owner: return entity.hex_position
	return Vector2i(-9999, -9999)

static func _choose(parent: Node, title: String, options: Array[String], labels: Dictionary) -> String:
	var menu := PopupMenu.new()
	menu.title = title
	menu.name = "ItemLifecyclePopup"
	for i in options.size(): menu.add_item(str(labels[options[i]]), i)
	var answer := {"index": -1, "done": false}
	menu.id_pressed.connect(func(id: int):
		# Godot hides an activated menu before emitting id_pressed.
		if int(answer.index) < 0:
			answer.index = id
			answer.done = true)
	menu.popup_hide.connect(func(): answer.done = true)
	parent.add_child(menu)
	menu.popup_centered()
	while not answer.done and is_instance_valid(parent) and parent.is_inside_tree() and is_instance_valid(menu): await parent.get_tree().process_frame
	if is_instance_valid(menu): menu.queue_free()
	return options[int(answer.index)] if int(answer.index) >= 0 and int(answer.index) < options.size() else ""
