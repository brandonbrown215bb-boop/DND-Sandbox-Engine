class_name TetherGroupFlow
extends RefCounted

const SLOT := "tether_group_checkpoint"

static func position(combat: Node, target) -> Vector2i:
	return target.get("hex_position", Vector2i.ZERO) if target is Dictionary else Batch031Controls._position(combat, target)

static func cast_ui(h: Node, combat: Node, caster: Character, first, second, spell: String = TetherGroupChecks.SPELL) -> void:
	h._p_focus(combat, caster)
	combat._reset_turn_action_economy()
	var serial := caster.spell_cast_serial
	var slots := int(caster.spell_slots.get("1", 0))
	combat.hud._show_spell_selection()
	var found := false
	for i in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[i].get("id") == spell:
			combat.hud._on_spell_selected(i)
			found = true
			break
	await Batch027Controls.answer(h, combat, "", "Level 1")
	combat._on_hex_clicked(position(combat, first))
	h._assert(found and caster.spell_cast_serial == serial and int(caster.spell_slots.get("1", 0)) == slots, "Tether actual first target pick does not invoke or pay before recipient selection completes")
	combat._on_hex_clicked(position(combat, second))
	for _frame in 300:
		await h.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break
	h._assert(not combat._cast_in_progress and caster.spell_cast_serial == serial + 1 and int(caster.spell_slots.get("1", 0)) == slots - 1 and not combat._can_spend_action_cost("action"), "Tether actual two recipient picks finish one invocation, one slot and one Action")

static func bind_pair(h: Node, combat: Node, caster: Character, first: Character, second: Character, base: int) -> String:
	for i in 24:
		SpellEffects.end_concentration(caster, [first, second])
		caster.spell_slots = {"1": 2}
		seed(base + i)
		await cast_ui(h, combat, caster, first, second)
		if TetherRules.held(caster).size() == 2: return str(caster.concentrating_on.effect_source)
	return ""

static func run(h: Node) -> void:
	h._enter_test("tether_group_flow")
	h._setup_mixed_world()
	TetherGroupChecks.load_fixtures()
	var first: Character = PlayerManager.get_player(0).character
	var second: Character = PlayerManager.get_player(1).character
	var caster: Character = PlayerManager.get_player(2).character
	var helper: Character = PlayerManager.get_player(3).character
	SpellPermissionChecks.grant_slot_permission(caster, [TetherGroupChecks.SPELL])
	SpellPermissionChecks.grant_slot_permission(helper, [TetherGroupChecks.RENAMED])
	first.ability_scores.set_score("STR", 1)
	second.ability_scores.set_score("STR", 1)
	helper.ability_scores.set_score("STR", 30)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.4)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	var positions := {caster.character_id: Vector2i.ZERO, first.character_id: Vector2i(1, 0), second.character_id: Vector2i(0, 1), helper.character_id: Vector2i(1, 1)}
	for p in combat.player_entities: p.hex_position = positions[p.character.character_id]
	for i in combat.monster_entities.size():
		combat.monster_entities[i].hex_position = Vector2i(2 + i, 0)
		combat.monster_entities[i].saving_throw_bonuses = {"STR": -100 if i == 0 else 100}
	combat._update_grid_entities()
	caster.spell_slots = {"1": 2}
	await cast_ui(h, combat, caster, combat.monster_entities[0], combat.monster_entities[1])
	h._assert(TetherRules.binding(combat.monster_entities[0], [caster]).size() == 1 and TetherRules.binding(combat.monster_entities[1], [caster]).is_empty(), "Tether actual mixed initial saves bind only the failed recipient under the one cast")
	combat._end_concentration(caster)
	var source := await bind_pair(h, combat, caster, first, second, 91000)
	h._assert(not source.is_empty(), "Tether actual targeting binds two party victims under one Character anchor")
	if source.is_empty(): h._teardown_scene(combat); h._exit_test(); return
	var ar := TetherGroupChecks.relation(caster, first)
	var br := TetherGroupChecks.relation(caster, second)
	# A second source gives the victim a real choice between two exact relations.
	helper.spell_slots = {"1": 2}
	for i in 24:
		seed(92000 + i)
		TetherGroupChecks.cast(helper, [first, second], TetherGroupChecks.RENAMED)
		if helper.tethers.size() == 2: break
		SpellEffects.end_concentration(helper, [first, second])
		helper.spell_slots = {"1": 2}
	var other := str(helper.concentrating_on.get("effect_source", ""))
	first.ability_scores.set_score("STR", 30)
	h._p_focus(combat, first)
	combat._reset_turn_action_economy()
	combat._on_hex_clicked(positions[first.character_id])
	var menu := await Batch027Controls.popup(h, combat, "Choose tether to escape")
	var picked := false
	if menu != null:
		for i in menu.item_count:
			if menu.get_item_text(i).ends_with(ar): menu.id_pressed.emit(menu.get_item_id(i)); picked = true; break
	for _frame in 12: await h.get_tree().process_frame
	h._assert(picked and not caster.tethers.has(ar) and caster.tethers.has(br) and TetherRules.has_source(second, source) and TetherRules.has_source(first, other) and not combat._can_spend_action_cost("action"), "Tether actual escape chooser releases selected relation; both its sibling and the other source stay bound")
	# Rescue offers the existing check/strike controls with the exact relation.
	h._p_focus(combat, helper)
	combat._reset_turn_action_economy()
	combat._on_hex_clicked(positions[second.character_id])
	menu = await Batch027Controls.popup(h, combat, "Choose tether rescue")
	picked = false
	if menu != null:
		for i in menu.item_count:
			if menu.get_item_text(i).begins_with("Pull free:") and menu.get_item_text(i).ends_with(br): menu.id_pressed.emit(menu.get_item_id(i)); picked = true; break
	for _frame in 12: await h.get_tree().process_frame
	h._assert(picked and caster.tethers.is_empty() and caster.concentrating_on.is_empty() and TetherRules.has_source(second, other) and not combat._can_spend_action_cost("action"), "Tether actual rescue chooser frees selected group victim without affecting the other cast")
	combat._end_concentration(helper)
	first.ability_scores.set_score("STR", 1)
	# Checkpoint carries a full group with damage and elapsed original lifetime.
	source = await bind_pair(h, combat, caster, first, second, 93000)
	ar = TetherGroupChecks.relation(caster, first)
	br = TetherGroupChecks.relation(caster, second)
	if source.is_empty(): h._assert(false, "Tether checkpoint pair binds"); h._teardown_scene(combat); h._exit_test(); return
	caster.tethers[br].hp = 3
	SpellEffects.advance_time(PartyManager.characters.values(), 12)
	h._assert(not SaveManager.get_save_block_reason().is_empty(), "Tether live combat retains the existing checkpoint guard")
	h._teardown_scene(combat)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var saved := SaveManager.save_game(SLOT)
	h._assert(saved, "Tether full group saves at the existing overworld checkpoint")
	if not saved: h._exit_test(); return
	var caster_id := caster.character_id
	var first_id := first.character_id
	var second_id := second.character_id
	var helper_id := helper.character_id
	var serial := caster.spell_cast_serial
	# Keep this harness alive while exercising the ordinary DTO/load path. The
	# real save guards above/below still run with test mode disabled.
	var previous_test_mode := GameManager.test_mode
	GameManager.test_mode = true
	var loaded := SaveManager.load_game(SLOT)
	GameManager.test_mode = previous_test_mode
	caster = PartyManager.characters.get(caster_id)
	first = PartyManager.characters.get(first_id)
	second = PartyManager.characters.get(second_id)
	helper = PartyManager.characters.get(helper_id)
	h._assert(loaded and caster.tethers.size() == 2 and caster.tethers.has(ar) and caster.tethers.has(br) and int(caster.tethers[br].hp) == 3 and caster.spell_cast_serial == serial and int(caster.spell_slots["1"]) == 1 and int(first.spell_effects[source].remaining_seconds) == 48 and int(second.spell_effects[source].remaining_seconds) == 48, "Tether real load restores both exact relations, partial HP, lifetime and once-paid source without replay")
	# Keep a partial group for the separate process: released A must stay released.
	first.ability_scores.set_score("STR", 30)
	var escaped := TetherRules.escape(first, [caster], 0, ar)
	h._assert(escaped.get("success", false) and caster.tethers.size() == 1 and caster.tethers.has(br), "Tether recovered group can release one relation while retaining its sibling")
	saved = SaveManager.save_game(SLOT)
	h._assert(saved, "Tether partial group saves without resurrecting its released relation")
	var manifest := {"pid": OS.get_process_id(), "caster": caster_id, "first": first_id, "second": second_id, "helper": helper_id, "source": source, "released": ar, "remaining": br, "serial": serial}
	var file := FileAccess.open("user://tether_group_manifest.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(manifest)); file.close()
	await room_controls(h, caster, helper, first, second)
	h._exit_test()

static func press(view: LocalRoomView, text: String) -> bool:
	for button in view.panel.find_children("*", "Button", true, false):
		if button is Button and not button is OptionButton and button.text == text:
			button.pressed.emit()
			return true
	return false

static func room_menu(view: LocalRoomView) -> PopupMenu:
	for child in view.panel.get_children():
		if child is PopupMenu and not child.is_queued_for_deletion(): return child
	return null

static func object_anchor_layout(room: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	for raw in room.get("cells", []):
		if not raw is Array or raw.size() < 2: continue
		var p := LocalRoomRules.coord(raw)
		if LocalRoomRules.object_at(room, p).is_empty() and LocalRoomRules.passable(room, p): cells.append(p)
	for anchor_a in cells:
		for victim_a in cells:
			if victim_a == anchor_a or HexUtils.get_distance(anchor_a, victim_a) > 1: continue
			for victim_b in cells:
				if victim_b in [anchor_a, victim_a] or HexUtils.get_distance(anchor_a, victim_b) > 2: continue
				for destination in cells:
					if destination in [anchor_a, victim_a, victim_b] or HexUtils.get_distance(destination, victim_a) <= 2 or HexUtils.get_distance(destination, victim_b) > 2: continue
					for anchor_b in cells:
						if anchor_b in [anchor_a, victim_a, victim_b, destination] or HexUtils.get_distance(anchor_a, anchor_b) < 5: continue
						for victim_c in cells:
							if victim_c in [anchor_a, victim_a, victim_b, destination, anchor_b] or HexUtils.get_distance(anchor_b, victim_c) > 1 or HexUtils.get_distance(anchor_a, victim_c) <= 2: continue
							for attacker in cells:
								if attacker in [anchor_a, victim_a, victim_b, destination, anchor_b, victim_c] or HexUtils.get_distance(attacker, anchor_b) > 1: continue
								return {"anchor_a": anchor_a, "victim_a": victim_a, "victim_b": victim_b, "destination": destination, "anchor_b": anchor_b, "victim_c": victim_c, "attacker": attacker}
	return {}

static func select_room_object(view: LocalRoomView, id: String) -> bool:
	for index in view.objects.item_count:
		if str(view.objects.get_item_metadata(index)) == id:
			view.objects.select(index)
			view.refresh()
			return true
	return false

static func room_controls(h: Node, caster: Character, helper: Character, first: Character, second: Character) -> void:
	# The checkpoint above remains untouched while ordinary room buttons exercise
	# ambiguous selections and a source disappearing during an open picker.
	SpellEffects.end_concentration(caster, [first, second])
	first.ability_scores.set_score("STR", 1)
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	for room in dungeon.rooms.values():
		if room.id == 1: dungeon.hex_grid.hex_clicked.emit(room.coord); break
	await h.get_tree().process_frame
	var view: LocalRoomView = dungeon.local_view
	if view == null: h._assert(false, "Tether room controls open existing local room"); h._teardown_scene(dungeon); return
	for owner in [caster, helper]:
		for i in 24:
			owner.spell_slots = {"1": 2}
			seed(94000 + i)
			TetherGroupChecks.cast(owner, [first, second], TetherGroupChecks.SPELL if owner == caster else TetherGroupChecks.RENAMED)
			if owner.tethers.size() == 2: break
			SpellEffects.end_concentration(owner, [first, second])
	var source := str(caster.concentrating_on.get("effect_source", ""))
	var other := str(helper.concentrating_on.get("effect_source", ""))
	var ar := TetherGroupChecks.relation(caster, first)
	var stale := TetherGroupChecks.relation(helper, first)
	var other_second := TetherGroupChecks.relation(helper, second)
	view.actors.select(view.characters.find(first))
	view.refresh()
	press(view, "Escape tether")
	var menu := room_menu(view)
	var selected := -1
	if menu != null:
		for i in menu.item_count:
			if menu.get_item_text(i).ends_with(stale): selected = i
	SpellEffects.remove(first, other)
	SpellEffects.reconcile([caster, helper], view.characters)
	var before := int(GameManager.campaign_elapsed_seconds)
	if selected >= 0: menu.id_pressed.emit(menu.get_item_id(selected))
	h._assert(selected >= 0 and TetherRules.has_source(first, source) and caster.tethers.has(ar) and helper.tethers.has(other_second) and int(GameManager.campaign_elapsed_seconds) == before, "Tether room stale exact escape picker refuses without time or sibling changes: " + JSON.stringify({"selected": selected, "original": caster.tethers.keys(), "other": helper.tethers.keys(), "time_before": before, "time_after": GameManager.campaign_elapsed_seconds}))
	await h.get_tree().process_frame
	# First is now restrained by only the original source; rescue Second still
	# offers two eligible relations. Cutting the selected other cord leaves its sibling.
	view.recipients.select(view.characters.find(second))
	first.ability_scores.set_score("STR", 30)
	first.inventory.add_item("longsword")
	first.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	press(view, "Cut tether")
	menu = room_menu(view)
	selected = -1
	if menu != null:
		for i in menu.item_count:
			if menu.get_item_text(i).ends_with(other_second): selected = i
	if selected >= 0: menu.id_pressed.emit(menu.get_item_id(selected))
	h._assert(selected >= 0 and not TetherRules.has_source(second, other) and TetherRules.has_source(second, source) and TetherRules.has_source(first, source) and caster.tethers.size() == 2 and helper.tethers.is_empty(), "Tether room Cut tether chooser damages only the selected relation and preserves the original group: " + JSON.stringify({"selected": selected, "original": caster.tethers.keys(), "other": helper.tethers.keys()}))
	SpellEffects.end_concentration(caster, view.characters)
	SpellEffects.end_concentration(helper, view.characters)
	var layout := object_anchor_layout(view.state)
	if layout.is_empty():
		h._assert(false, "Object anchor room controls find two separated anchors and a one-relation movement path")
		h._teardown_scene(dungeon)
		return
	view.state.party_positions[first.character_id] = [layout.victim_a.x, layout.victim_a.y]
	view.state.party_positions[second.character_id] = [layout.victim_b.x, layout.victim_b.y]
	view.state.party_positions[helper.character_id] = [layout.victim_c.x, layout.victim_c.y]
	view.state.party_positions[caster.character_id] = [layout.attacker.x, layout.attacker.y]
	for member: Character in [first, second, helper, caster]:
		view.state.party_altitudes[member.character_id] = LocalRoomRules.elevation_feet(view.state, LocalRoomRules.coord(view.state.party_positions[member.character_id]))
	var left := {"id": "fixture_tether_anchor_left", "kind": "loose", "name": "Tether anchor left", "position": [layout.anchor_a.x, layout.anchor_a.y], "plane": "material", "hp": 4, "max_hp": 4, "contents": [], "removed": false}
	var right := {"id": "fixture_tether_anchor_right", "kind": "barrier", "name": "Tether anchor right", "position": [layout.anchor_b.x, layout.anchor_b.y], "plane": "material", "hp": 1, "max_hp": 1, "fixed": true, "height_feet": 5, "material": "wood", "armor_class": 1, "contents": [], "removed": false}
	view.state.objects.append_array([left, right])
	GameManager.transition_context["local_room"] = view.state
	view.refresh()
	caster.ability_scores.set_score("STR", 30)
	caster.ability_scores.set_score("INT", 30)
	caster.inventory.add_item("longsword")
	caster.inventory.equip(Inventory.Slot.WEAPON, "longsword")
	var object_source := ""
	for victim: Character in [first, second, helper]:
		victim.ability_scores.set_score("STR", 1)
		victim.saving_throw_proficiencies.erase("STR")
	for attempt in 32:
		caster.spell_slots = {"1": 2}
		seed(95100 + attempt)
		TetherGroupChecks.cast(caster, [first, second, helper], TetherGroupChecks.OBJECT)
		if TetherRules.binding(first, [caster]).size() == 1 and TetherRules.binding(second, [caster]).size() == 1 and TetherRules.binding(helper, [caster]).size() == 1:
			object_source = str(TetherRules.binding(first, [caster])[0].source)
			break
		for anchor in [left, right]:
			var anchor_tethers: Dictionary = anchor.get("tethers", {})
			for relation in anchor_tethers.keys().duplicate():
				var tether: Dictionary = anchor_tethers.get(relation, {})
				for victim in [first, second, helper]:
					if victim.character_id == str(tether.get("victim_id", "")):
						TetherRules._release_object_anchor(anchor, str(relation), victim)
						break
	var left_relation := str(TetherRules.binding(first, [caster])[0].relation) if not TetherRules.binding(first, [caster]).is_empty() else ""
	var second_object_relation := str(TetherRules.binding(second, [caster])[0].relation) if not TetherRules.binding(second, [caster]).is_empty() else ""
	var right_relation := str(TetherRules.binding(helper, [caster])[0].relation) if not TetherRules.binding(helper, [caster]).is_empty() else ""
	var left_tethers: Dictionary = left.get("tethers", {})
	var right_tethers: Dictionary = right.get("tethers", {})
	h._assert(not object_source.is_empty() and left_tethers.size() == 2 and right_tethers.size() == 1 and str(left_tethers.get(left_relation, {}).get("anchor_id", "")) == left.id and str(right_tethers.get(right_relation, {}).get("anchor_id", "")) == right.id, "Object tether spell settles several victims on two exact room object records")
	if object_source.is_empty() or left_relation.is_empty() or second_object_relation.is_empty() or right_relation.is_empty():
		h._teardown_scene(dungeon)
		return
	SpellEffects.end_concentration(caster, [first, second, helper])
	caster.concentrating_on.clear()
	select_room_object(view, left.id)
	view.actors.select(view.characters.find(caster))
	var move_control := press(view, "Move tether anchor")
	if move_control: view.click(layout.destination)
	var second_after_move := TetherRules.binding(second, [caster])
	h._assert(move_control and left.position == [layout.destination.x, layout.destination.y] and TetherRules.binding(first, [caster]).is_empty() and second_after_move.size() == 1 and second_after_move[0].relation == second_object_relation and TetherRules.binding(helper, [caster]).size() == 1, "Room Move tether anchor releases only the victim moved beyond range and keeps its anchor sibling and second anchor")
	# Add a separate Character relation, open the real Rescue chooser, then destroy
	# its captured object relation before selecting it. The popup must go stale.
	for attempt in 24:
		helper.spell_slots = {"1": 2}
		seed(95200 + attempt)
		TetherGroupChecks.cast(helper, [second], TetherGroupChecks.RENAMED)
		if helper.tethers.size() == 1: break
	var character_relation := TetherGroupChecks.relation(helper, second)
	view.actors.select(view.characters.find(first))
	view.recipients.select(view.characters.find(second))
	view.refresh()
	press(view, "Rescue")
	menu = room_menu(view)
	selected = -1
	if menu != null:
		for i in menu.item_count:
			if menu.get_item_text(i).ends_with(second_object_relation): selected = i
	var second_object_source := str(left.tethers.get(second_object_relation, {}).get("condition_source_id", ""))
	var stale_before := int(GameManager.campaign_elapsed_seconds)
	var left_damage := CombatObjectRules.apply_damage(left, 100, "fire")
	if selected >= 0: menu.id_pressed.emit(menu.get_item_id(selected))
	await h.get_tree().process_frame
	h._assert(selected >= 0 and left_damage > 0 and not TetherRules.has_source(second, second_object_source) and TetherRules.binding(second, [helper]).any(func(entry): return str(entry.relation) == character_relation) and int(GameManager.campaign_elapsed_seconds) == stale_before, "Room stale Rescue popup refuses a destroyed exact object relation without touching its Character tether or time")
	# Save while the right object relation remains at the supported entrance
	# checkpoint. The fresh process below checks the exact room object and victim.
	var room_id := str(view.state.get("id", ""))
	var object_slot := "tether_object_anchor_checkpoint"
	if not view.state.get("exits", []).is_empty():
		view.state.party_positions[caster.character_id] = view.state.exits[0].duplicate()
		view.actors.select(view.characters.find(caster))
	dungeon._leave_local_room()
	for _frame in 20:
		await h.get_tree().process_frame
		if dungeon.local_view == null: break
	dungeon.party_position = Vector2i.ZERO
	dungeon._save_dungeon_state_to_manager()
	var object_saved := SaveManager.save_game(object_slot)
	var right_condition_source := str(right.tethers[right_relation].get("condition_source_id", ""))
	var char_source := str(helper.concentrating_on.get("effect_source", ""))
	var object_manifest := {"pid": OS.get_process_id(), "slot": object_slot, "room_id": room_id, "caster": caster.character_id, "victim": helper.character_id, "character_caster": helper.character_id, "character_victim": second.character_id, "source": object_source, "relation": right_relation, "condition_source": right_condition_source, "character_source": char_source, "character_relation": character_relation, "anchor": right.id, "hp": int(right.hp), "tether_hp": int(right.tethers[right_relation].get("hp", -1)), "position": right.position.duplicate(), "remaining_seconds": int(helper.spell_effects[right_condition_source].get("remaining_seconds", -1)), "serial": caster.spell_cast_serial}
	var object_file := FileAccess.open("user://tether_object_anchor_manifest.json", FileAccess.WRITE)
	if object_file != null: object_file.store_string(JSON.stringify(object_manifest)); object_file.close()
	h._assert(object_saved and dungeon.local_view == null, "Object anchor and unrelated Character tether save at the existing entrance checkpoint: " + SaveManager.get_save_block_reason())
	if object_saved: _reject_malformed_object_checkpoints(h, object_slot)
	# Resume the room and use its ordinary Strike barrier button to destroy the
	# second anchor after the recovery snapshot has been written.
	dungeon._enter_local_room(room_id)
	await h.get_tree().process_frame
	view = dungeon.local_view
	if view != null:
		select_room_object(view, right.id)
		view.actors.select(view.characters.find(caster))
		var struck := false
		for _attempt in 16:
			if not CombatObjectRules.can_target(right): break
			if not press(view, "Strike barrier"): break
			struck = true
			await h.get_tree().process_frame
		h._assert(struck and int(right.hp) == 0 and TetherRules.binding(helper, [caster]).is_empty() and TetherRules.binding(second, [helper]).any(func(entry): return str(entry.relation) == character_relation), "Room Strike barrier destroys only the right anchor relations and leaves the unrelated Character tether")
	h._teardown_scene(dungeon)

static func _reject_malformed_object_checkpoints(h, slot: String) -> void:
	var baseline := SaveManager._read_save(slot)
	var party_before: Dictionary = PartyManager.characters.duplicate()
	var dungeon_before: Dictionary = GameManager.active_dungeon_state.duplicate(true)
	for defect in ["hp", "fractional_hp", "dc", "fractional_range", "anchor_id", "missing_relation", "duplicate_anchor"]:
		var bad: Dictionary = baseline.duplicate(true)
		for world in [bad.get("active_dungeon_state", {})] + bad.get("campaign_ledger", {}).get("dungeon_snapshots", {}).values():
			for room in world.get("local_rooms", {}).values():
				if defect == "duplicate_anchor":
					for object in room.get("objects", []).duplicate():
						if object.get("tethers", {}).is_empty(): continue
						var duplicate: Dictionary = object.duplicate(true)
						duplicate.id += "_foreign_anchor"
						room.objects.append(duplicate)
						break
					continue
				for object in room.get("objects", []):
					for relation in object.get("tethers", {}).keys():
						match defect:
							"hp": object.tethers[relation].hp = 999
							"fractional_hp": object.tethers[relation].hp = 1.5
							"dc": object.tethers[relation].dc = 999
							"fractional_range": object.tethers[relation].range_hexes = 3.5
							"anchor_id": object.tethers[relation].anchor_id = "foreign_anchor"
							"missing_relation": object.tethers.erase(relation)
		var malformed_slot: String = "tether_malformed_" + defect
		var file := FileAccess.open(SaveManager.SAVE_DIR + malformed_slot + ".sav", FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(bad)); file.close()
		var loaded := SaveManager.load_game(malformed_slot)
		h._assert(not loaded and PartyManager.characters == party_before and GameManager.active_dungeon_state == dungeon_before, "Object tether malformed checkpoint %s refuses before replacing the live party/world" % defect)
