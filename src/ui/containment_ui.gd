class_name ContainmentUI
extends RefCounted

static func refresh(view: LocalRoomView) -> void:
	view.containment_serial += 1
	for child in view.containment_row.get_children():
		view.containment_row.remove_child(child)
		child.queue_free()
	var bodies: Array = []
	for actor in view.characters + VesselProjectionRules.actors(view.characters): bodies.append({"kind": "character", "id": actor.character_id, "label": actor.character_name})
	for object in view.state.get("objects", []):
		if not bool(object.get("removed", false)): bodies.append({"kind": "object", "id": str(object.id), "label": str(object.name)})
	var containers := OptionButton.new()
	containers.name = "ContainmentContainers"
	var candidates := OptionButton.new()
	candidates.name = "ContainmentCandidates"
	for picker in [containers, candidates]:
		picker.fit_to_longest_item = false
		picker.clip_text = true
		picker.custom_minimum_size.x = 140
	for body in bodies:
		var label := "%s · %s" % [body.label, ContainmentRules.key(body.kind, body.id)]
		candidates.add_item(label)
		candidates.set_item_metadata(candidates.item_count - 1, body)
		if not ContainmentRules.policy(ContainmentRules.entity(view.state, view.characters, body.kind, body.id)).is_empty():
			containers.add_item(label)
			containers.set_item_metadata(containers.item_count - 1, body)
	view.containment_row.visible = containers.item_count > 0 or ContainmentRules.active(view.state)
	view.containment_row.add_child(containers)
	view.containment_row.add_child(candidates)
	view._add_button(view.containment_row, "Inspect occupants", func():
		if containers.selected < 0: return
		var body: Dictionary = containers.get_item_metadata(containers.selected)
		var rows := ContainmentRules.occupants(view.state, body.kind, body.id)
		view.hud.add_log("%s: %d/%d occupants; external location %s" % [body.label, rows.size(), int(ContainmentRules.policy(ContainmentRules.entity(view.state, view.characters, body.kind, body.id)).get("capacity", 0)), JSON.stringify(ContainmentRules.external_location(view.state, body.kind, body.id))])
		for row in rows:
			var target = ContainmentRules.entity(view.state, view.characters, row.occupant_kind, row.occupant_id)
			var gear: Array = target.inventory.owned_instances().map(func(c): return str(c.instance_id)) if target is Character else target.get("contents", []).map(func(c): return str(c.instance_id))
			view.hud.add_log("Inside: %s; gear remains with this body: %s%s" % [ContainmentRules.key(row.occupant_kind, row.occupant_id), ", ".join(gear), "; release settlement deferred: " + str(row.release_pending.reason) if row.has("release_pending") else ""]))
	view._add_button(view.containment_row, "Move container", func():
		if containers.selected < 0: return
		var body: Dictionary = containers.get_item_metadata(containers.selected)
		var target = ContainmentRules.entity(view.state, view.characters, body.kind, body.id)
		if target is Character and target.has_meta("projected_item_id"):
			view.pending_anchor_move_id = body.id
			view.pending_anchor_move_choice = {"vessel": target, "room": view.state, "actor": view.actor(), "serial": view.containment_serial, "position": ContainmentRules.location(view.state, "character", body.id, view.characters), "rows": view.state.get("containment_occupants", []).duplicate(true)}
			view.hud.add_log("Choose a reachable room hex for " + body.id)
			return
		if body.kind != "object": view.hud.add_log("Select the creature actor and click its destination to move it."); return
		view.pending_anchor_move_id = body.id
		view.pending_anchor_move_choice = movement_choice(view, ContainmentRules.entity(view.state, view.characters, body.kind, body.id))
		view.hud.add_log("Choose a legal room hex for " + body.id))
	view._add_button(view.containment_row, "Finish pending release", func():
		if containers.selected < 0: return
		var body: Dictionary = containers.get_item_metadata(containers.selected)
		var rows := ContainmentRules.occupants(view.state, body.kind, body.id).filter(func(r): return r.has("release_pending"))
		var room := view.state
		var actor := view.actor()
		var plan := ContainmentRules.prepare_release(room, view.characters, rows)
		if not plan.success: view._result(plan); return
		var serial := view.containment_serial
		var dialog := ConfirmationDialog.new()
		dialog.name = "ContainmentRelease"
		dialog.title = "Release exact occupants"
		dialog.dialog_text = "Release %d occupants into reserved legal spaces?" % rows.size()
		view.panel.add_child(dialog)
		dialog.confirmed.connect(func():
			if serial == view.containment_serial and view.actor() == actor and is_same(view.state, room):
				view.containment_serial += 1
				view._result(ContainmentRules.commit_release(room, view.characters, plan))
			dialog.queue_free())
		dialog.canceled.connect(func():
			view.containment_serial += 1
			dialog.queue_free())
		dialog.popup_centered())
	for mode in ["escape", "rescue"]:
		var selected_mode: String = mode
		view._add_button(view.containment_row, "Escape containment" if mode == "escape" else "Rescue occupant", func():
			if candidates.selected < 0: return
			var candidate: Dictionary = candidates.get_item_metadata(candidates.selected)
			begin_check(view, candidate.kind, candidate.id, selected_mode))
	view._add_button(view.containment_row, "Admit occupant", func():
		if containers.selected < 0 or candidates.selected < 0: return
		var container: Dictionary = containers.get_item_metadata(containers.selected)
		var candidate: Dictionary = candidates.get_item_metadata(candidates.selected)
		var actor := view.actor()
		var room := view.state
		var choice := ContainmentRules.prepare(room, view.characters, actor, container.kind, container.id, candidate.kind, candidate.id)
		if not choice.success: view._result(choice); return
		var serial := view.containment_serial
		var dialog := ConfirmationDialog.new()
		dialog.name = "ContainmentAdmission"
		dialog.title = "Admit exact occupant"
		dialog.dialog_text = "Admit %s into %s?" % [candidate.id, container.id]
		view.panel.add_child(dialog)
		dialog.confirmed.connect(func():
			if serial == view.containment_serial and view.actor() == actor and is_same(view.state, room):
				view.containment_serial += 1
				view._result(ContainmentRules.admit(room, view.characters, actor, choice))
			dialog.queue_free())
		dialog.canceled.connect(func():
			view.containment_serial += 1
			dialog.queue_free())
		dialog.popup_centered())

static func begin_check(view: LocalRoomView, kind: String, id: String, mode: String) -> void:
	var actor := view.actor()
	var room := view.state
	var choice := ContainmentRules.prepare_check(room, view.characters, actor, kind, id, mode)
	if not choice.success: view._result(choice); return
	var serial := view.containment_serial
	var dialog := ConfirmationDialog.new()
	dialog.name = "ContainmentCheck"
	dialog.title = "Escape containment" if mode == "escape" else "Rescue exact occupant"
	dialog.dialog_text = "%s: %s for %s inside %s (%d seconds)?" % [actor.character_name, mode, ContainmentRules.key(kind, id), ContainmentRules.key(choice._row.container_kind, choice._row.container_id), int(choice.policy[mode].seconds)]
	view.panel.add_child(dialog)
	dialog.confirmed.connect(func():
		if serial == view.containment_serial and view.actor() == actor and is_same(view.state, room):
			view.containment_serial += 1
			view._result(ContainmentRules.attempt_check(room, view.characters, actor, choice))
		dialog.queue_free())
	dialog.canceled.connect(func():
		view.containment_serial += 1
		dialog.queue_free())
	dialog.popup_centered()

static func movement_choice(view: LocalRoomView, body: Dictionary) -> Dictionary:
	return {"body": body, "room": view.state, "actor": view.actor(), "serial": view.containment_serial, "position": body.get("position", []).duplicate(), "policy": ContainmentRules.policy(body).duplicate(true), "rows": view.state.get("containment_occupants", []).duplicate(true)}
