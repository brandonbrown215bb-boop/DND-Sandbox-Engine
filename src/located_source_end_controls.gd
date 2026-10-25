class_name LocatedSourceEndControls
extends RefCounted

const SLOT := "located_source_end_checkpoint"

static func press_child(view: LocalRoomView, text: String) -> bool:
	for button in view.aftermath_row.get_children():
		if button is Button and button.text == text:
			button.pressed.emit()
			return true
	return false

static func run(h: Node) -> void:
	h._enter_test("located_source_end_flow")
	h._setup_world()
	LocatedSourceEndChecks.load_fixtures()
	GameManager._reset_campaign_ledgers()
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	GameManager.current_state = GameManager.GameState.DUNGEON
	GameManager.transition_context = {"dungeon_id": "ruins_of_ashvale"}
	var dungeon: DungeonState = await h._spawn_scene("res://scenes/dungeon.tscn", 0.2)
	for candidate in dungeon.rooms.values():
		if candidate.id == 1: dungeon.hex_grid.hex_clicked.emit(candidate.coord); break
	await h.get_tree().process_frame
	var view: LocalRoomView = dungeon.local_view
	var actor: Character = view.actor()
	actor.origin_feat = ""
	LocatedSourceEndChecks.kit(actor)
	actor.current_hp = 10
	var room_key := dungeon.local_room_id
	var origin_hex := LocalRoomRules.coord(view.state.party_positions[actor.character_id])
	var origin: Array = [origin_hex.x, origin_hex.y]
	var mode_menu := await Batch062Controls._open(h, view, "Activate: Mode: Afterglow")
	var opened := mode_menu != null
	await Batch052Controls._press(h, mode_menu, "guard")
	h._assert(opened and int(actor.feature_uses.get(LocatedSourceEndChecks.MODE, -1)) == 3 and actor.feature_modes.get(LocatedSourceEndChecks.MODE, {}).get("active", false), "Located actual room mode activation spends one use through ordinary controls: " + JSON.stringify({"opened": opened, "uses": actor.feature_uses.get(LocatedSourceEndChecks.MODE), "state": actor.feature_modes.get(LocatedSourceEndChecks.MODE)}))
	GameManager.advance_campaign_time(6)
	view.refresh()
	var pending: Dictionary = view.state.get("source_end_continuations", {}).values()[0]
	var source := str(pending.event.source_id)
	h._assert(not actor.feature_modes[LocatedSourceEndChecks.MODE].active and pending.event.end_reason == "duration" and pending.event.recipient_id == actor.character_id and pending.event.final_location.position == origin and pending.event.final_location.plane == "material", "Located actual mode expiry captures source, recipient, exact reason and final room location: " + JSON.stringify({"source": source, "location": pending.event.final_location, "reason": pending.event.end_reason}))
	# Move through the real room input before the delayed child becomes observable.
	var destination := LocalRoomRules.coord(origin) + Vector2i(1, 0)
	view.click(destination)
	h._assert(LocalRoomRules.coord(view.state.party_positions[actor.character_id]) == destination and pending.current.is_empty(), "Located actual movement after source expiry leaves the delayed origin unchanged")
	GameManager.advance_campaign_time(6)
	view.refresh()
	var stale_invocation := str(pending.invocation)
	var canceled := press_child(view, "Cancel: mend")
	var successor_id := str(pending.receipts[1].get("successor_id", "")) if pending.receipts.size() > 1 else ""
	var area_id := str(pending.receipts[2].get("successor_id", "")) if pending.receipts.size() > 2 else ""
	var object := LocalRoomRules.get_object(view.state, successor_id)
	var area := {}
	for candidate in view.state.areas:
		if candidate.id == area_id: area = candidate
	h._assert(canceled and actor.current_hp == 10 and not object.is_empty() and object.position == origin and area.get("center") == origin and successor_id != source and area_id != source and pending.remaining.is_empty(), "Located clicked child cancel skips healing and resumes actual object/hazard siblings at the captured origin: " + JSON.stringify({"canceled": canceled, "hp": actor.current_hp, "object_id": successor_id, "area_id": area_id, "receipts": pending.receipts.size()}))
	var old_answer := LocatedSourceEndRules.answer(view.state, stale_invocation, "mend", true, view.characters)
	h._assert(not old_answer.get("success", false) and actor.current_hp == 10, "Located stale child answer cannot replay the paid parent or canceled child")
	# The hazard is consumed through ordinary room movement and damages real HP.
	# Clicking the actual loose remnant selects it. Movement through that cell
	# still uses the same room movement owner (as a longer path can do).
	view._result(LocalRoomRules.move(view.state, actor, LocalRoomRules.coord(origin), view.grid, "walk", view.characters))
	var after_entry := actor.current_hp
	view.click(destination)
	view._result(LocalRoomRules.move(view.state, actor, LocalRoomRules.coord(origin), view.grid, "walk", view.characters))
	h._assert(after_entry == 7 and actor.current_hp == 7 and int(area.triggered_by.get(actor.character_id, 0)) == 1, "Located actual room entry deals damage once and retains the per-recipient trigger ledger")
	# A second activation accepts the same declared child through the room UI.
	mode_menu = await Batch062Controls._open(h, view, "Activate: Mode: Afterglow")
	await Batch052Controls._press(h, mode_menu, "stride")
	GameManager.advance_campaign_time(18)
	view.refresh()
	var accepted := press_child(view, "Continue: mend")
	h._assert(accepted and actor.current_hp == 11 and int(actor.feature_uses[LocatedSourceEndChecks.MODE]) == 2 and not actor.feature_modes[LocatedSourceEndChecks.MODE].active, "Located accepted child resumes once without another mode use")
	# Exercise the existing shared spell producer through its room cast owner.
	var wizard: Character = view.characters[1]
	if LocatedSourceEndChecks.SPELL not in wizard.known_spells: wizard.known_spells.append(LocatedSourceEndChecks.SPELL)
	if LocatedSourceEndChecks.SPELL not in wizard.wizard_spellbook: wizard.wizard_spellbook.append(LocatedSourceEndChecks.SPELL)
	wizard.spell_slots["1"] = 2
	var spell_result := LocalRoomSharedSpells.cast(view.state, wizard, LocatedSourceEndChecks.SPELL, actor, view.characters, view.grid)
	var spell_source := str(spell_result.get("effect_cast", {}).get("source_id", ""))
	var broken := SpellEffects.remove(actor, spell_source, "destroyed")
	view.refresh()
	h._assert(spell_result.get("success", false) and broken.get("end_reason") == "destroyed" and not actor.spell_effects.has(spell_source) and int(wizard.spell_slots["1"]) == 1 and view.state.objects.any(func(o): return o.get("parent_source_id", "") == spell_source), "Located shared room spell pays once, captures destruction and leaves its actual distinct successor after source cleanup")
	# Also retain one unobserved future continuation at the allowed checkpoint.
	mode_menu = await Batch062Controls._open(h, view, "Activate: Mode: Afterglow")
	await Batch052Controls._press(h, mode_menu, "guard")
	FeatureModeRules.end(actor, LocatedSourceEndChecks.MODE, "dismissed")
	view.refresh()
	# Exact item copies and created actors feed the same room-owned continuation queue.
	actor.inventory.add_item(LocatedSourceEndChecks.ITEM)
	actor.inventory.add_item(LocatedSourceEndChecks.ITEM)
	var exact_copy_ids: Array = actor.inventory.copies.backpack.duplicate().slice(-2)
	var copy_a := str(exact_copy_ids[0])
	var copy_b := str(exact_copy_ids[1])
	var cells: Array = view.state.cells
	var form_cell_a: Vector2i = LocalRoomRules.coord(cells[0]) # Captured before the exact copy leaves its item state.
	var form_cell_b: Vector2i = LocalRoomRules.coord(cells[1])
	var projected_a := ItemProjectionRules.project(actor, copy_a)
	var projected_b := ItemProjectionRules.project(actor, copy_b)
	view.state.created_actor_positions[ItemProjectionRules.actor_id(copy_a)] = [form_cell_a.x, form_cell_a.y]
	view.state.created_actor_positions[ItemProjectionRules.actor_id(copy_b)] = [form_cell_b.x, form_cell_b.y]
	var ended_a := ItemProjectionRules.revert(actor, copy_a, -1, "dismissed")
	var ended_b := ItemProjectionRules.revert(actor, copy_b, -1, "expired")
	var actor_spell := DataLoader.get_spell(LocatedSourceEndChecks.ACTOR_SPELL)
	var actor_cast := SpellEffects.begin_cast(wizard, actor_spell)
	var actor_parent_source := str(actor_cast.source_id)
	var actors_created := CreatedActorRules.create(wizard, actor_cast, CreatedActorRules._effect(actor_spell).template, 1, actor_spell)
	var created_actors := CreatedActorRules.actors(wizard)
	if created_actors.size() == 2:
		var actor_cell_a: Vector2i = LocalRoomRules.coord(cells[2])
		var actor_cell_b: Vector2i = LocalRoomRules.coord(cells[3]) if cells.size() > 3 else LocalRoomRules.coord(cells[1])
		view.state.created_actor_positions[created_actors[0].character_id] = [actor_cell_a.x, actor_cell_a.y]
		view.state.created_actor_positions[created_actors[1].character_id] = [actor_cell_b.x, actor_cell_b.y]
		created_actors[0].current_hp = 0
		created_actors[0].is_alive = false
	var actor_death := CreatedActorRules.end_actor(created_actors[0] if not created_actors.is_empty() else null, "death", {"damage_type": "fire"})
	CreatedActorRules.end_actor(created_actors[0] if not created_actors.is_empty() else null, "death", {"damage_type": "fire"})
	SpellEffects.remove(wizard, actor_parent_source, "expired", {"cause": "duration"})
	var producer_pending: Array = view.state.source_end_continuations.values().filter(func(p): return p.event.source_kind in ["item_copy", "created_actor"])
	var reason_set := producer_pending.map(func(p): return str(p.event.source_kind) + ":" + str(p.event.end_reason))
	h._assert(projected_a.get("projected", false) and projected_b.get("projected", false) and ended_a.get("reverted", false) and ended_b.get("reverted", false) and actor_death.get("end_reason") == "death" and actors_created.get("created", false) and not wizard.spell_effects.has(actor_parent_source) and not view.state.created_actor_positions.has(created_actors[1].character_id) and reason_set.count("item_copy:dismissed") == 1 and reason_set.count("item_copy:expired") == 1 and reason_set.count("created_actor:death") == 1 and reason_set.count("created_actor:expired") == 1, "Loaded exact copies and created actors retain distinct ending reasons, serial/source identities and cleanup")
	var object_ids: Array = view.state.objects.filter(func(o): return o.has("parent_source_id")).map(func(o): return o.id)
	var area_ids: Array = view.state.areas.filter(func(a): return a.has("parent_source_id")).map(func(a): return a.id)
	var exact_expected_objects: Array = []
	for source_pending in producer_pending:
		var entry: Dictionary = source_pending.event.record.end_aftermath.filter(func(e): return e.id == source_pending.aftermath_id)[0]
		var child: Dictionary = entry.children[0]
		exact_expected_objects.append({"id": str(source_pending.invocation) + ":child:" + str(child.id), "position": source_pending.event.final_location.position, "name": child.name, "source_id": source_pending.event.source_id})
	var expected_hp := actor.current_hp
	var expected_uses := int(actor.feature_uses[LocatedSourceEndChecks.MODE])
	var expected_queue: int = view.state.source_end_continuations.size()
	h._assert(DungeonPersistence.local_error(view.state).is_empty(), "Located pre-checkpoint room DTO validates: " + DungeonPersistence.local_error(view.state))
	var exit_position := LocalRoomRules.coord(view.state.exits[0])
	view.state.party_positions[actor.character_id] = [exit_position.x, exit_position.y]
	view.refresh()
	view.leave_requested.emit()
	await h.get_tree().process_frame
	if dungeon.local_view == null and dungeon.party_position != Vector2i.ZERO:
		dungeon.hex_grid.hex_clicked.emit(Vector2i.ZERO)
		await h.get_tree().process_frame
	var saved := SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "Located actual entrance checkpoint saves completed receipts and one waiting timer without a mid-decision save: " + SaveManager.get_save_block_reason())
	var manifest := {"pid": OS.get_process_id(), "owner_id": actor.character_id, "wizard_id": wizard.character_id, "room_id": room_key, "object_ids": object_ids, "area_ids": area_ids, "queue_count": expected_queue, "hp": expected_hp, "uses": expected_uses, "origin": origin, "exact_expected_objects": exact_expected_objects, "exact_copy_ids": exact_copy_ids, "slot_count": int(wizard.spell_slots.get("1", -1))}
	var manifest_file := FileAccess.open("user://located_source_end_manifest.json", FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest))
		manifest_file.close()
	if saved:
		var invalid := SaveManager._read_save(SLOT)
		var invalid_room: Dictionary = invalid.active_dungeon_state.local_rooms[room_key]
		invalid_room.source_end_continuations.values()[0].remaining = DataLoader.get_feat(LocatedSourceEndChecks.FEAT).features[0].end_aftermath[0].children.duplicate(true)
		h._assert(not SaveManager._validate_save_data(invalid).is_empty() and PartyManager.characters.get(actor.character_id) == actor and actor.current_hp == expected_hp, "Located malformed continuation preflight refuses before replacing the live session")
		var loaded := SaveManager.load_game(SLOT)
		var recovered: Character = PartyManager.characters.get(actor.character_id)
		var restored: Dictionary = GameManager.active_dungeon_state.local_rooms.get(room_key, {})
		LocatedSourceEndRules.observe(restored, PartyManager.characters.values())
		h._assert(loaded and recovered != null and recovered.current_hp == expected_hp and int(recovered.feature_uses[LocatedSourceEndChecks.MODE]) == expected_uses and restored.source_end_continuations.size() == expected_queue and restored.objects.filter(func(o): return o.has("parent_source_id")).map(func(o): return o.id) == object_ids, "Located real checkpoint recovery retains identities, costs, timer and settled children without replay: " + JSON.stringify({"loaded": loaded, "owner": recovered != null, "hp": recovered.current_hp if recovered != null else -1, "expected_hp": expected_hp, "uses": recovered.feature_uses.get(LocatedSourceEndChecks.MODE, -1) if recovered != null else -1, "expected_uses": expected_uses, "queue": restored.get("source_end_continuations", {}).size(), "expected_queue": expected_queue, "objects": restored.get("objects", []).filter(func(o): return o.has("parent_source_id")).map(func(o): return o.id), "expected_objects": object_ids}))
		# Existing encounter area owner consumes the same saved room hazard.
		GameManager.current_state = GameManager.GameState.COMBAT
		GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"], "local_room": restored}
		var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.2)
		var visitor: Character = PartyManager.characters.get(wizard.character_id)
		var visitor_hp := visitor.current_hp
		var combat_entries: Array = await combat._area_spells._resolve_spell_zone_entries(visitor, LocalRoomRules.coord(origin) + Vector2i(1, 0), LocalRoomRules.coord(origin))
		h._assert(combat_entries.any(func(result): return result.get("hazard_kind", "") == "entry_damage") and visitor.current_hp < visitor_hp, "Located saved hazard deals actual entry damage through CombatSpellZones")
		var live_position := LocalRoomRules.coord(origin) + Vector2i(2, 0)
		for entity in combat.player_entities:
			if entity.get("character") == recovered: entity.hex_position = live_position
		var live_cast := CombatAction.resolve_spell(visitor, recovered, DataLoader.get_spell(LocatedSourceEndChecks.SPELL), false)
		var live_end := SpellEffects.remove(recovered, str(live_cast.get("effect_cast", {}).get("source_id", "")), "destroyed")
		h._assert(live_end.get("final_location", {}).get("position") == [live_position.x, live_position.y], "Located combat capture uses the recipient's live final position instead of its stale room checkpoint position")
		h._teardown_scene(combat)
	h._teardown_scene(dungeon)
	h._exit_test()
