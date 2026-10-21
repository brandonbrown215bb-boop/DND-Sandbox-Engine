class_name Batch052Controls
extends RefCounted
## Batch 052 scenario: the real combat HUD feature list and its mode popups.

static func _index(combat: Node, prefix: String) -> int:
	combat.hud.btn_features.pressed.emit()
	for i in combat.hud.features_registered.size():
		if combat.hud.feature_list.get_item_text(i).begins_with(prefix): return i
	return -1

static func _open(h: Node, combat: Node, prefix: String, title: String, exclude: PopupMenu = null) -> PopupMenu:
	var i := _index(combat, prefix)
	if i < 0: return null
	combat.hud._on_feature_selected(i)
	for _f in 60:
		await h.get_tree().process_frame
		for w in combat.hud.get_children():
			if w is PopupMenu and w != exclude and w.visible and not w.is_queued_for_deletion() and str(w.title).begins_with(title): return w
	return null

static func _press(h: Node, menu: PopupMenu, text: String) -> void:
	if menu == null: return
	for i in menu.item_count:
		if menu.get_item_text(i) == text:
			menu.id_pressed.emit(menu.get_item_id(i))
			break
	for _f in 3: await h.get_tree().process_frame

static func run(h: Node) -> void:
	h._enter_test("batch_052_hud_mode_controls_flow")
	h._setup_world()
	Batch052Checks.load_fixtures()
	var c: Character = PlayerManager.get_player(0).get("character")
	c.origin_feat = ""
	var b := Batch052Checks.kit(c)
	c.max_hp = 200
	c.current_hp = 200
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	h._p_focus(combat, c)
	var hud: Node = combat.hud
	var saved_features := c.features.duplicate(true)
	c.features.assign(c.features.filter(func(f): return str(f.get("type", "")) in ["mode_choice", "rule_upgrade"]))
	hud.update_hud(c, combat.tracker)
	h._assert(not hud.btn_features.disabled, "052 actual the Features button is enabled for an actor with only modes and upgrades")
	c.features.assign(saved_features)
	hud.update_hud(c, combat.tracker)
	var listed := _index(combat, "Activate: Mode: Tide Surge (2/2 uses)") >= 0 and _index(combat, "Choose upgrade: Mode: Blade Ward") >= 0 and _index(combat, "Choose mode: Mode: Tide Mood") >= 0
	h._assert(listed, "052 actual the combat HUD lists owned modes with uses and an upgrade picker")
	var before := Batch052Checks.snapshot(c)
	var menu := await _open(h, combat, "Activate: Mode: Tide Surge", "Activate: Tide Surge")
	h._assert(menu != null and menu.get_item_text(0) == "Cancel" and menu.item_count == 3, "052 actual the popup offers Cancel plus exactly the declared modes")
	await _press(h, menu, "Cancel")
	h._assert(Batch052Checks.snapshot(c) == before and int(c.feature_uses[Batch052Checks.SURGE]) == 2, "052 actual Cancel spends nothing (uses unchanged 2/2)")
	var prior_turn := await _open(h, combat, "Activate: Mode: Tide Surge", "Activate: Tide Surge")
	hud.update_hud(null, combat.tracker)
	hud.update_hud(c, combat.tracker)
	var prior_open := prior_turn != null
	await _press(h, prior_turn, "flow")
	h._assert(prior_open and Batch052Checks.snapshot(c) == before and int(c.feature_uses[Batch052Checks.SURGE]) == 2, "052 actual a popup from before the owner left and regained the active turn spends nothing")
	var old := await _open(h, combat, "Activate: Mode: Tide Surge", "Activate: Tide Surge")
	var newer := await _open(h, combat, "Activate: Mode: Tide Surge", "Activate: Tide Surge", old)
	var both_open := old != null and newer != null
	await _press(h, old, "flow")
	h._assert(both_open and not bool(c.feature_modes.get(Batch052Checks.SURGE, {}).get("active", false)) and int(c.feature_uses[Batch052Checks.SURGE]) == 2, "052 actual answering a superseded popup spends nothing (uses unchanged)")
	await _press(h, newer, "ebb")
	h._assert(int(c.feature_uses[Batch052Checks.SURGE]) == 1 and c.feature_modes[Batch052Checks.SURGE].mode == "ebb" and _index(combat, "Change mode: Mode: Tide Surge (1/2 uses) [ebb, 60s left]") >= 0, "052 actual the current popup activates once; the HUD shows uses and time left")
	var up := await _open(h, combat, "Choose upgrade: Mode: Blade Ward", "Choose upgrade: Blade Ward")
	await _press(h, up, "edge: deep@" + b.blade)
	h._assert(c.get_feature_max_uses(b.ward) == 3 and _index(combat, "Activate: Mode: Blade Ward (") >= 0 and combat.hud.feature_list.get_item_text(_index(combat, "Activate: Mode: Blade Ward (")).contains("/3 uses)"), "052 actual picking an upgrade option from the list applies it")
	Batch050Checks.mute(c, "b052_hud_mute")
	h._assert(_index(combat, "Mode: Blade Ward") >= 0 and combat.hud.feature_list.is_item_disabled(_index(combat, "Mode: Blade Ward")) and combat.hud.feature_list.get_item_text(_index(combat, "Mode: Blade Ward")).ends_with("[Unavailable: suppressed]"), "052 actual a suppressed copy shows as unavailable")
	c.spell_effects.erase("b052_hud_mute")
	combat.hud._hide_feature_selection()
	var expect_modes := c.feature_modes.duplicate(true)
	var expect_uses := int(c.feature_uses[Batch052Checks.SURGE])
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_052_modes"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "052 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nc: Character = PartyManager.characters.get(c.character_id, null)
		h._assert(loaded and nc != null and nc != c and str(nc.feature_modes[Batch052Checks.SURGE].mode) == str(expect_modes[Batch052Checks.SURGE].mode) and bool(nc.feature_modes[Batch052Checks.SURGE].active) and int(nc.feature_uses[Batch052Checks.SURGE]) == expect_uses and nc.get_feature_max_uses(b.ward) == 3, "052 actual real load keeps the active mode, uses and chosen upgrade")
		SaveManager.delete_save(slot)
	h._teardown_scene(combat)
	h._exit_test()



