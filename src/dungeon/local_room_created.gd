## Existing room controls for recorded remains and created Undead.
class_name LocalRoomCreated
extends RefCounted

static func refresh(view: LocalRoomView) -> void:
	var selected := ""
	if view.created_targets != null and is_instance_valid(view.created_targets) and view.created_targets.selected >= 0: selected = str(view.created_targets.get_item_metadata(view.created_targets.selected))
	for child in view.created_row.get_children():
		view.created_row.remove_child(child)
		child.queue_free()
	view.created_targets = OptionButton.new()
	view.created_targets.name = "CreatedCreatureTargets"
	view.created_row.add_child(view.created_targets)
	var targets: Array[Dictionary] = []
	for object in view.state["objects"]:
		if str(object.get("kind", "")) == "remains" and not bool(object.get("removed", false)):
			targets.append({"id": object["id"], "text": str(object["name"]), "kind": "body"})
	for member in view.characters:
		if member.is_dead(): targets.append({"id": str(member.corpse_state.get("corpse_id", "")), "text": "%s's remains" % member.character_name, "kind": "body"})
	for record in CreatedCreatureRules.room_records(view.state):
		var control_text := "%d seconds of control" % maxi(0, int(record["control_until"]) - int(GameManager.campaign_elapsed_seconds)) if CreatedCreatureRules.controlled(record) else "uncontrolled"
		targets.append({"id": record["id"], "text": "%s %s · %d/%d HP · %s" % [record["form_id"], record["serial"], record["current_hp"], record["max_hp"], control_text], "kind": "creature"})
	if targets.is_empty(): view.created_row.hide(); return
	view.created_row.show()
	for target in targets:
		view.created_targets.add_item(target["text"])
		view.created_targets.set_item_metadata(view.created_targets.item_count - 1, target["id"])
		if target["id"] == selected: view.created_targets.select(view.created_targets.item_count - 1)
	view.created_targets.item_selected.connect(func(_index): view.refresh())
	var target: Dictionary = targets[view.created_targets.selected]
	var target_id := str(target["id"])
	if target["kind"] == "body":
		if "animate_dead" in view.actor().known_spells:
			view._add_button(view.created_row, "Animate Dead (1 min)", func(): view._result(CreatedCreatureRules.animate(view.state, view.actor(), view.characters, target_id)))
		var object := LocalRoomRules.get_object(view.state, target_id)
		if not object.is_empty() and "gentle_repose" in view.actor().known_spells:
			view._add_button(view.created_row, "Preserve remains", func(): view._result(preserve(view.state, view.actor(), target_id)))
	else:
		var record := CreatedCreatureRules.get_record(target_id)
		if record.get("owner_id", "") != view.actor().character_id: return
		view._add_button(view.created_row, "Renew control (1 min)", func():
			var ids: Array[String] = [target_id]
			view._result(CreatedCreatureRules.renew(view.state, view.actor(), ids)))
		view._add_button(view.created_row, "Renew nearby (up to 4)", func():
			var ids: Array[String] = []
			var origin := LocalRoomRules.coord(view.state["party_positions"][view.actor().character_id])
			for nearby in CreatedCreatureRules.room_records(view.state):
				if nearby["owner_id"] == view.actor().character_id and CreatedCreatureRules.controlled(nearby) and HexUtils.get_distance(origin, LocalRoomRules.coord(nearby["position"])) <= 2: ids.append(str(nearby["id"]))
			view._result(CreatedCreatureRules.renew(view.state, view.actor(), ids)))
		view._add_button(view.created_row, "Follow owner" if not bool(record["following"]) else "Stay here", func(): view._result(order(view.state, view.actor(), target_id, not bool(record["following"]))))

static func order(room: Dictionary, owner: Character, id: String, follow: bool) -> Dictionary:
	var record := CreatedCreatureRules.get_record(id)
	if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner) or record.is_empty() or not CreatedCreatureRules.in_room(record, room) or not CreatedCreatureRules.controlled(record) or record["owner_id"] != owner.character_id: return LocalRoomRules.failure("Only a conscious owner can command a controlled creature.")
	if HexUtils.get_distance(LocalRoomRules.coord(room["party_positions"][owner.character_id]), LocalRoomRules.coord(record["position"])) > 12: return LocalRoomRules.failure("Mental commands require the Undead within 60 feet.")
	record["following"] = follow
	record["order"] = "guard"
	record["order_target"] = ""
	return {"success": true, "seconds": 6, "message": "The Undead follows its owner and Dodges in combat." if follow else "The Undead remains in this room and Dodges until commanded."}

static func preserve(room: Dictionary, caster: Character, id: String) -> Dictionary:
	var spell := DataLoader.get_spell("gentle_repose")
	var error := LocalRoomRules._room_spell_caster_error(caster, spell)
	if not error.is_empty(): return LocalRoomRules.failure(error)
	var body := LocalRoomRules.get_object(room, id)
	if body.is_empty() or str(body.get("kind", "")) != "remains" or bool(body.get("removed", false)) or body.get("remains") == "destroyed": return LocalRoomRules.failure("Choose available recorded remains.")
	var origin := LocalRoomRules.coord(room["party_positions"][caster.character_id])
	var position := LocalRoomRules.coord(body["position"])
	if HexUtils.get_distance(origin, position) > 1 or not LocalRoomBodies._clear_path(room, origin, position): return LocalRoomRules.failure("Move within Touch range of the remains.")
	var component := caster.inventory.required_spell_component_instance(spell)
	if component.is_empty(): return LocalRoomRules.failure("The consumed two-coin component packet is missing.")
	var slot := CombatAction.spend_spell_slot(caster, spell)
	if not slot.get("success", false): return LocalRoomRules.failure(str(slot.get("message", "No spell slot remains.")))
	caster.inventory.destroy_instance(component)
	body["preserved_until"] = int(GameManager.campaign_elapsed_seconds) + 6 + 864000
	return {"success": true, "seconds": 6, "message": "The recorded remains are protected from decay and becoming Undead for ten days."}
