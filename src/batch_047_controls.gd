class_name Batch047Controls
extends RefCounted

static func _prepare(b: Character) -> Dictionary:
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true), "slots": b.spell_slots.duplicate(true)}
	var spells: Array[String] = [Batch047Checks.CHANGELING]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b047_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	return prior

static func _restore(b: Character, prior: Dictionary) -> void:
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features

## Real HUD cast: open the spell list, pick the spell and slot level, click the caster's own hex.
static func begin(h: Node, combat: Node, caster: Character, spell_id: String) -> void:
	h._p_focus(combat, caster)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == spell_id:
			combat.hud._on_spell_selected(index)
			break
	await Batch027Controls.answer(h, combat, "", "Level 1")
	combat._on_hex_clicked(Batch031Controls._position(combat, caster))

## Begin the real HUD cast and return its open chooser.
static func open(h: Node, combat: Node, caster: Character, spell_id: String, title: String, exclude: PopupMenu = null) -> PopupMenu:
	await begin(h, combat, caster, spell_id)
	for _f in 60:
		await h.get_tree().process_frame
		for window in combat.hud.get_children():
			if window is PopupMenu and window != exclude and window.visible and not window.is_queued_for_deletion() and str(window.title).begins_with(title): return window
	return null

static func _policy(active: Dictionary) -> String:
	var eq: Variant = active.get("record", {}).get("projection", {}).get("equipment", {})
	return str(eq.get("policy", "")) if eq is Dictionary else str(eq)

static func settle(h: Node, combat: Node) -> void:
	for _frame in 300:
		await h.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break

static func fresh_turn(h: Node, combat: Node, b: Character) -> void:
	b.spell_slots = {"1": 1}
	h._p_focus(combat, b)
	combat._reset_turn_action_economy()
	combat.resolving_player_action = false

static func run(h: Node) -> void:
	h._enter_test("batch_047_form_equipment_chooser_flow")
	h._setup_world()
	Batch047Checks.load_fixtures()
	var b: Character = PlayerManager.get_player(1).get("character")
	var a: Character = PlayerManager.get_player(0).get("character")
	var prior := _prepare(b)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
		entry["has_turn"] = true
	combat.monster_entities[0]["hex_position"] = Vector2i(3, -1)
	combat._update_grid_entities()
	# 1. The normal cast offers the declared forms; canceling it spends nothing.
	fresh_turn(h, combat, b)
	await begin(h, combat, b, Batch047Checks.CHANGELING)
	var form_menu: PopupMenu = await Batch027Controls.popup(h, combat, "Choose a form")
	var labels: Array = []
	if form_menu != null:
		for i in form_menu.item_count: labels.append(form_menu.get_item_text(i))
	h._assert(form_menu != null and labels.size() == 3 and str(labels[0]) == "Cancel" and str(labels[1]).begins_with("Hare") and str(labels[2]).begins_with("Boar"), "047 actual HUD cast offers exactly the declared forms (%s)" % str(labels))
	await Batch027Controls.answer(h, combat, "Choose a form", "Cancel")
	await settle(h, combat)
	h._assert(int(b.spell_slots.get("1", 0)) == 1 and not ActorProjectionRules.is_projected(b) and combat._can_spend_action_cost("action") and not combat._cast_in_progress, "047 actual canceling the form popup spends no slot or action")
	# 2. Picking a form then canceling the equipment popup also spends nothing.
	fresh_turn(h, combat, b)
	await begin(h, combat, b, Batch047Checks.CHANGELING)
	await Batch027Controls.answer(h, combat, "Choose a form", "Boar")
	var eq_menu: PopupMenu = await Batch027Controls.popup(h, combat, "Choose how equipment")
	var eq_labels: Array = []
	if eq_menu != null:
		for i in eq_menu.item_count: eq_labels.append(eq_menu.get_item_text(i))
	h._assert(eq_labels.size() == 3 and str(eq_labels[1]).begins_with("Merged") and str(eq_labels[2]).begins_with("Worn"), "047 actual HUD then offers exactly the legal equipment policies (%s)" % str(eq_labels))
	await Batch027Controls.answer(h, combat, "Choose how equipment", "Cancel")
	await settle(h, combat)
	h._assert(int(b.spell_slots.get("1", 0)) == 1 and not ActorProjectionRules.is_projected(b) and combat._can_spend_action_cost("action"), "047 actual canceling the equipment popup spends no slot or action")
	# 3. An old popup answered after a newer cast opened its own chooser spends nothing and leaves the new cast intact.
	fresh_turn(h, combat, b)
	var old_menu: PopupMenu = await open(h, combat, b, Batch047Checks.CHANGELING, "Choose a form")
	combat._cast_in_progress = false
	combat.resolving_player_action = false
	var new_menu: PopupMenu = await open(h, combat, b, Batch047Checks.CHANGELING, "Choose a form", old_menu)
	var had_both := old_menu != null and new_menu != null
	if old_menu != null:
		for i in old_menu.item_count:
			if old_menu.get_item_text(i).begins_with("Boar"): old_menu.id_pressed.emit(old_menu.get_item_id(i))
	for _f in 6: await h.get_tree().process_frame
	h._assert(had_both and int(b.spell_slots.get("1", 0)) == 1 and not ActorProjectionRules.is_projected(b), "047 actual answering the stale popup spends nothing and projects nothing (both=%s slots=%s proj=%s)" % [had_both, str(b.spell_slots), ActorProjectionRules.is_projected(b)])
	# The current chooser still works and its cast pays exactly once.
	if new_menu != null:
		for i in new_menu.item_count:
			if new_menu.get_item_text(i).begins_with("Hare"): new_menu.id_pressed.emit(new_menu.get_item_id(i))
	await Batch027Controls.answer(h, combat, "Choose how equipment", "Worn")
	await settle(h, combat)
	var live := ActorProjectionRules.active(b)
	h._assert(not live.is_empty() and str(live.form.id) == "b047_hare" and _policy(live) == "worn" and int(b.spell_slots.get("1", 0)) == 0 and not DataLoader.get_spell(Batch047Checks.CHANGELING).has("_projection_form_id"), "047 actual current chooser casts the chosen Hare form with worn equipment, paying one slot (slots=%s live=%s)" % [str(b.spell_slots), str(live.get("form", {}).get("id", "")) + "/" + _policy(live)])
	# 4. A popup outliving its turn is stale: the slot stays unspent.
	var src := str(live.get("source", ""))
	if not src.is_empty(): combat._end_concentration(b)
	fresh_turn(h, combat, b)
	var turn_menu: PopupMenu = await open(h, combat, b, Batch047Checks.CHANGELING, "Choose a form")
	var had_turn := turn_menu != null
	CombatAction.active_turn_serial += 1 # The turn this popup belonged to has ended.
	if turn_menu != null:
		for i in turn_menu.item_count:
			if turn_menu.get_item_text(i).begins_with("Boar"): turn_menu.id_pressed.emit(turn_menu.get_item_id(i))
	await settle(h, combat)
	h._assert(had_turn and not src.is_empty() and int(b.spell_slots.get("1", 0)) == 1 and not ActorProjectionRules.is_projected(b), "047 actual a popup answered after its turn ended spends nothing")
	# 5. A real chosen cast survives a real save and load.
	fresh_turn(h, combat, b)
	await begin(h, combat, b, Batch047Checks.CHANGELING)
	await Batch027Controls.answer(h, combat, "Choose a form", "Boar")
	await Batch027Controls.answer(h, combat, "Choose how equipment", "Merged")
	await settle(h, combat)
	var boar := ActorProjectionRules.active(b)
	h._assert(not boar.is_empty() and str(boar.form.id) == "b047_boar" and _policy(boar) == "merged" and int(b.spell_slots.get("1", 0)) == 0, "047 actual chosen Boar/merged cast applies exactly those picks")
	h._teardown_scene(combat)
	_restore(b, prior)
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var slot := "batch_047_chooser"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "047 actual real save with the chosen projection (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var back := ActorProjectionRules.active(nb)
		h._assert(loaded and nb != null and nb != b and not back.is_empty() and str(back.form.id) == "b047_boar" and _policy(back) == "merged", "047 actual real load keeps the chosen form and equipment policy")
		SaveManager.delete_save(slot)
	h._exit_test()
