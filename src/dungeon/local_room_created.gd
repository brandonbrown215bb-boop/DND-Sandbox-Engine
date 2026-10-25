## Room actions for remains, created Undead and data-driven actor factories.
class_name LocalRoomCreated
extends RefCounted

static func refresh(view: LocalRoomView) -> void:
	_prune_room_positions(view)
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
	if targets.is_empty():
		view.created_row.hide()
		if not view.pending_room_creation.is_empty(): _add_creation_controls(view)
		return
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
	if not view.pending_room_creation.is_empty():
		_add_creation_controls(view)

static func _prune_room_positions(view: LocalRoomView) -> void:
	var live: Dictionary = {}
	for member in view.characters:
		for created in CreatedActorRules.actors(member): live[created.character_id] = true
		for id in member.item_projections: live[ItemProjectionRules.actor_id(str(id))] = true
	var positions: Dictionary = view.state.get("created_actor_positions", {}).duplicate(true)
	for id in positions.keys():
		if not live.has(str(id)): positions.erase(id)
	view.state["created_actor_positions"] = positions

## Room creation is a staged map choice. The owner, room geometry and live
## occupancy are read again for every click and once more before payment.
static func begin_creation(view: LocalRoomView, spell_id: String) -> void:
	var spell := DataLoader.get_spell(spell_id).duplicate(true)
	var effect := CreatedActorRules._effect(spell)
	var error := LocalRoomRules._room_spell_caster_error(view.actor(), spell)
	if effect.is_empty() or not error.is_empty():
		view._result(LocalRoomRules.failure(error if not error.is_empty() else "This spell has no supported creature factory."))
		return
	var slot := str(CombatAction.get_spell_slot_level(view.actor(), spell))
	if int(spell.get("level", 0)) > 0 and int(view.actor().spell_slots.get(slot, 0)) <= 0 and not view.actor().has_free_spell_cast(str(spell.id)):
		view._result(LocalRoomRules.failure("No spell slot or free cast remains."))
		return
	var options := CreatedActorRules.templates(effect)
	if options.is_empty():
		view._result(LocalRoomRules.failure("This spell has no supported creature choices."))
		return
	view.pending_room_creation = {"spell_id": spell_id, "template_id": str(options[0].id), "count": 1, "selected": [], "options": options, "choosing_factory": true}
	_add_creation_controls(view)

static func _add_creation_controls(view: LocalRoomView) -> void:
	view.created_row.show()
	for child in view.created_row.get_children():
		if str(child.name).begins_with("RoomCreate_"):
			view.created_row.remove_child(child)
			child.queue_free()
	var pending := view.pending_room_creation
	if pending.is_empty(): return
	var spell := DataLoader.get_spell(str(pending.spell_id)).duplicate(true)
	var effect := CreatedActorRules._effect(spell)
	var template_pick := OptionButton.new()
	template_pick.name = "RoomCreate_Template"
	for template in pending.options:
		template_pick.add_item("%s (%s)" % [template.name, template.size])
		template_pick.set_item_metadata(template_pick.item_count - 1, template.id)
		if str(template.id) == str(pending.template_id): template_pick.select(template_pick.item_count - 1)
	template_pick.item_selected.connect(func(index: int):
		view.pending_room_creation.template_id = str(template_pick.get_item_metadata(index))
		view.pending_room_creation.erase("selected")
		view.pending_room_creation.selected = []
		_add_creation_controls(view))
	view.created_row.add_child(template_pick)
	var material := MaterialTargetRules.cap(_material_cast(view, spell, effect), effect)
	var template := CreatedActorRules._template(spell, str(pending.template_id))
	var upcast := maxi(0, CombatAction.get_spell_slot_level(view.actor(), spell) - int(spell.get("level", 0)))
	var counts := CreatedActorRules.creation_counts(effect, template, upcast)
	if not material.is_empty(): counts = counts.filter(func(n): return int(n) <= int(material.get("total", 0)))
	var count_pick := OptionButton.new()
	count_pick.name = "RoomCreate_Count"
	for count in counts:
		count_pick.add_item("%d creature%s" % [count, "" if int(count) == 1 else "s"])
		count_pick.set_item_metadata(count_pick.item_count - 1, count)
		if int(count) == int(pending.count): count_pick.select(count_pick.item_count - 1)
	if not counts.has(int(pending.count)) and count_pick.item_count > 0:
		count_pick.select(count_pick.item_count - 1)
		view.pending_room_creation.count = int(count_pick.get_item_metadata(count_pick.selected))
	count_pick.item_selected.connect(func(index: int):
		view.pending_room_creation.count = int(count_pick.get_item_metadata(index))
		view.pending_room_creation.selected = []
		_add_creation_controls(view))
	view.created_row.add_child(count_pick)
	var status := Label.new()
	status.name = "RoomCreate_Status"
	var chosen: Array = pending.get("selected", [])
	status.text = "Choose the creature and count, then confirm." if bool(pending.get("choosing_factory", true)) else "Click a legal cell (%d/%d placed). Cancel clears the pending cast." % [chosen.size(), int(pending.count)]
	view.created_row.add_child(status)
	var cancel_button := view._add_button(view.created_row, "Cancel creation", func():
		view.pending_room_creation.clear()
		view.refresh())
	cancel_button.name = "RoomCreate_Cancel"
	if counts.is_empty():
		status.text = "There are no eligible remains for this creature; nothing has been spent."
		return
	var legal := _room_candidates(view, template, int(PlacementRules.policy(effect).range_hexes), chosen)
	var all_destinations := PlacementRules.reserve(_placement_state(view), LocalRoomRules.coord(view.state.party_positions[view.actor().character_id]), str(template.size), int(PlacementRules.policy(effect).range_hexes), int(pending.count))
	if bool(pending.get("choosing_factory", true)):
		if all_destinations.is_empty():
			status.text = "There is not enough legal room space for the selected count; nothing has been spent."
			if str(PlacementRules.policy(effect).no_space) == "spend":
				var spend_button := view._add_button(view.created_row, "Pay and create nothing", func(): _finish(view, spell, effect, [], true))
				spend_button.name = "RoomCreate_Spend"
		else:
			var confirm_button := view._add_button(view.created_row, "Confirm creature and count", func():
				if view.pending_room_creation.is_empty(): return
				view.pending_room_creation.choosing_factory = false
				var policy := PlacementRules.policy(effect)
				if not bool(policy.choose):
					_finish(view, spell, effect, all_destinations, false)
				else:
					_add_creation_controls(view))
			confirm_button.name = "RoomCreate_Confirm"
		return
	if all_destinations.is_empty():
		if str(PlacementRules.policy(effect).no_space) == "spend":
			var spend_button := view._add_button(view.created_row, "Pay and create nothing", func(): _finish(view, spell, effect, [], true))
			spend_button.name = "RoomCreate_Spend"
		else:
			status.text = "There is not enough legal room space for the selected count; nothing has been spent."
	else:
		for cell in legal:
			view.grid.add_highlight(cell, HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.MOVEMENT])

static func choose_destination(view: LocalRoomView, position: Vector2i) -> void:
	var pending := view.pending_room_creation
	if pending.is_empty() or bool(pending.get("choosing_factory", true)): return
	var spell := DataLoader.get_spell(str(pending.spell_id)).duplicate(true)
	var effect := CreatedActorRules._effect(spell)
	var template := CreatedActorRules._template(spell, str(pending.template_id))
	var chosen: Array = pending.get("selected", []).duplicate()
	var origin := LocalRoomRules.coord(view.state.get("party_positions", {}).get(view.actor().character_id, [-999, -999]))
	var policy := PlacementRules.policy(effect)
	var error := _legal_error(view, origin, position, str(template.size), int(policy.range_hexes), chosen)
	if not error.is_empty():
		view.hud.add_log("That cell is no longer legal (%s); nothing was spent." % error)
		_add_creation_controls(view)
		return
	chosen.append(position)
	view.pending_room_creation.selected = chosen
	if chosen.size() < int(pending.count):
		_add_creation_controls(view)
		return
	_finish(view, spell, effect, chosen, false)

static func _finish(view: LocalRoomView, spell: Dictionary, effect: Dictionary, picks: Array, spend_without_space: bool) -> void:
	var pending := view.pending_room_creation.duplicate(true)
	if pending.is_empty(): return
	if not spend_without_space and picks.size() != int(pending.count):
		view.pending_room_creation.clear()
		view._result(LocalRoomRules.failure("The selected arrival count changed; nothing was spent."))
		return
	var template := CreatedActorRules._template(spell, str(pending.template_id))
	var origin := LocalRoomRules.coord(view.state.get("party_positions", {}).get(view.actor().character_id, [-999, -999]))
	if not picks.is_empty() and PlacementRules.confirm_error(_placement_state(view), origin, str(template.size), int(PlacementRules.policy(effect).range_hexes), picks) != "":
		view.pending_room_creation.clear()
		view._result(LocalRoomRules.failure("A selected destination became blocked; no slot, remains or creature was consumed."))
		return
	var cast := _material_cast(view, spell, effect)
	var factory := {"template_id": str(pending.template_id), "count": int(pending.count)}
	var upcast := maxi(0, CombatAction.get_spell_slot_level(view.actor(), spell) - int(spell.get("level", 0)))
	if int(factory.count) not in CreatedActorRules.creation_counts(effect, template, upcast):
		view.pending_room_creation.clear()
		view._result(LocalRoomRules.failure("The permitted creation count changed; nothing was spent."))
		return
	# The room picker chooses one kind per cast, including mixed-capable spells.
	if CreatedActorRules.is_mixed(effect): factory["mix"] = {str(pending.template_id): int(pending.count)}
	if not MaterialTargetRules.spec(effect).is_empty():
		var reserved := MaterialTargetRules.reservation(cast, effect, factory)
		if reserved.size() != int(factory.count):
			view.pending_room_creation.clear()
			view._result(LocalRoomRules.failure("The eligible remains changed while choosing; nothing was spent."))
			return
		cast.material_targets = reserved
	spell["_factory"] = factory
	spell["_placement"] = PlacementRules.encode(picks)
	if spend_without_space:
		spell.erase("_factory")
		spell["_placement"] = []
	view.pending_room_creation.clear()
	var result := LocalRoomSharedSpells.cast_creation(view.state, view.actor(), spell, view.characters, view.grid)
	if result.get("success", false) and not spend_without_space:
		var created := CreatedActorRules.actors(view.actor())
		var effect_cast: Dictionary = result.get("effect_cast", spell.get("_effect_cast", {}))
		var source_id := str(effect_cast.get("source_id", ""))
		var source_record: Dictionary = view.actor().spell_effects.get(source_id, {})
		var actor_entries: Array = source_record.get("created_actors", {}).get("actors", [])
		var destination_index := 0
		var actor_positions: Dictionary = view.state.get("created_actor_positions", {}).duplicate(true)
		for made in created:
			if str(made.get_meta("created_source_id", "")) != source_id: continue
			if destination_index >= picks.size(): break
			actor_positions[made.character_id] = [picks[destination_index].x, picks[destination_index].y]
			destination_index += 1
		view.state["created_actor_positions"] = actor_positions
		if destination_index == picks.size() and not cast.material_targets.is_empty():
			cast.spell = spell
			cast.spell["_effect_cast"] = effect_cast
			MaterialTargetRules.consume_created(cast)
	result["seconds"] = 6
	view._result(result)

static func _placement_state(view: LocalRoomView) -> Dictionary:
	var state := view.state.duplicate(false)
	state["room"] = view.state
	state["_placement_grid"] = view.grid
	state["_placement_players"] = []
	state["monster_entities"] = []
	for member in view.characters:
		if state.get("party_positions", {}).has(member.character_id) and ContainmentRules.relation(state, "character", member.character_id).is_empty():
			state["_placement_players"].append({"character": member, "hex_position": LocalRoomRules.coord(state.party_positions[member.character_id])})
		for created in CreatedActorRules.actors(member):
			var saved: Variant = state.get("created_actor_positions", {}).get(created.character_id, null)
			if saved is Array: state["_placement_players"].append({"character": created, "hex_position": LocalRoomRules.coord(saved)})
		for id in member.item_projections:
			var projected := ItemProjectionRules.actor(member, str(id))
			var saved: Variant = state.get("created_actor_positions", {}).get(ItemProjectionRules.actor_id(str(id)), null)
			if projected != null and saved is Array: state["_placement_players"].append({"character": projected, "hex_position": LocalRoomRules.coord(saved)})
		var steed := PaladinRules.find_steed_state(member)
		var steed_position := PaladinRules.find_steed_room_position(member, str(view.state.id))
		if int(steed.get("current_hp", 0)) > 0 and not bool(steed.get("mounted", false)) and steed_position != Vector2i(9999, 9999):
			state["monster_entities"].append({"hex_position": steed_position, "is_alive": true})
	for record in CreatedCreatureRules.room_records(state):
		state["monster_entities"].append({"hex_position": LocalRoomRules.coord(record.position), "is_alive": int(record.current_hp) > 0, "creature_type": "undead", "size": "medium"})
	return state

static func _room_candidates(view: LocalRoomView, template: Dictionary, reach: int, reserved: Array) -> Array[Vector2i]:
	var origin := LocalRoomRules.coord(view.state.get("party_positions", {}).get(view.actor().character_id, [-999, -999]))
	var state := _placement_state(view)
	var out: Array[Vector2i] = []
	for cell in PlacementRules.candidates(state, origin, str(template.size), reach, reserved): out.append(cell)
	return out

static func _legal_error(view: LocalRoomView, origin: Vector2i, position: Vector2i, size: String, reach: int, reserved: Array) -> String:
	return PlacementRules.legal_error(_placement_state(view), origin, position, size, reach, reserved)

static func _material_cast(view: LocalRoomView, spell: Dictionary, _effect: Dictionary) -> SpellCastContext:
	var cast := SpellCastContext.new()
	cast.caster = view.actor()
	cast.spell = spell
	cast.grid = view.grid
	cast.player_index = view.characters.find(view.actor())
	cast.players = []
	cast.monsters = []
	for member in view.characters:
		var position := LocalRoomRules.coord(view.state.get("party_positions", {}).get(member.character_id, [9999, 9999]))
		cast.players.append({"character": member, "hex_position": position, "is_alive": member.is_alive, "creature_type": member.creature_type, "size": member.get_creature_size()})
	for object in view.state.get("objects", []):
		if str(object.get("kind", "")) != "remains" or bool(object.get("removed", false)): continue
		var ref: Dictionary = object.duplicate(false)
		ref.merge({"id": str(object.id), "hex_position": LocalRoomRules.coord(object.position), "is_alive": false, "creature_type": str(object.get("creature_type", "humanoid")), "size": str(object.get("size", "medium")), "material_used": bool(object.get("material_used", false)), "_local_room_object": object}, true)
		cast.monsters.append(ref)
	return cast

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
