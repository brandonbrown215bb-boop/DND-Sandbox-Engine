class_name Batch053Controls
extends RefCounted
## Batch 053 scenario: real HUD casts place created actors at legal destinations.

static func _slots(b: Character) -> int:
	return int(b.spell_slots.get("1", 0))

static func _sources(b: Character) -> int:
	return b.spell_effects.values().filter(func(r): return r.has("created_actors")).size()

static func _popup(h: Node, combat: Node, title: String, exclude: PopupMenu = null) -> PopupMenu:
	for _f in 60:
		await h.get_tree().process_frame
		for w in combat.hud.get_children():
			if w is PopupMenu and w != exclude and w.visible and not w.is_queued_for_deletion() and str(w.title).begins_with(title): return w
	return null

static func _press(h: Node, menu: PopupMenu, index: int) -> String:
	if menu == null or index >= menu.item_count: return ""
	var text := menu.get_item_text(index)
	menu.id_pressed.emit(menu.get_item_id(index))
	for _f in 3: await h.get_tree().process_frame
	return text

static func _hex(text: String) -> Vector2i:
	var parts := text.trim_prefix("Hex (").trim_suffix(")").split(", ")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i(9999, 9999)

static func _no_overlap(combat: Node) -> bool:
	var seen := {}
	for e in combat.player_entities + combat.monster_entities:
		var alive: bool = e.character.is_alive if e.has("character") and e.character is Character else bool(e.get("is_alive", false))
		if not alive: continue
		if seen.has(e.hex_position): return false
		seen[e.hex_position] = true
	return true

static func run(h: Node) -> void:
	h._enter_test("batch_053_legal_placement_flow")
	h._setup_world()
	Batch053Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true)}
	var spells: Array[String] = [Batch053Checks.PAIR, Batch053Checks.GAMBLE]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b053_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	var origin := Vector2i(0, 1)
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else origin
		entry["has_turn"] = true
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(1, 0)
	combat._update_grid_entities()
	# 1. Cancel at the first destination popup spends nothing.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch053Checks.PAIR)
	var first := await _popup(h, combat, "Place Warden 1 of 2")
	var legal := PlacementRules.candidates(combat, origin, "medium", 1)
	h._assert(first != null and first.get_item_text(0) == "Cancel" and first.item_count == legal.size() + 1, "053 actual the cast offers Cancel plus exactly the legal adjacent destinations (%d)" % legal.size())
	await _press(h, first, 0)
	await Batch047Controls.settle(h, combat)
	h._assert(_slots(b) == 4 and _sources(b) == 0, "053 actual Cancel spends no slot and creates nothing")
	# 2. A superseded popup is stale; the newer cast still completes and pays once.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch053Checks.PAIR)
	var old := await _popup(h, combat, "Place Warden 1 of 2")
	combat._cast_in_progress = false
	combat.resolving_player_action = false
	await Batch047Controls.begin(h, combat, b, Batch053Checks.PAIR)
	var newer := await _popup(h, combat, "Place Warden 1 of 2", old)
	var both := old != null and newer != null
	await _press(h, old, 1)
	h._assert(both and _slots(b) == 4 and _sources(b) == 0, "053 actual answering a superseded destination popup spends nothing")
	var pick1 := _hex(await _press(h, newer, 1))
	var second := await _popup(h, combat, "Place Warden 2 of 2")
	var offered: Array = []
	if second != null:
		for i in second.item_count: offered.append(second.get_item_text(i))
	h._assert(second != null and "Hex (%d, %d)" % [pick1.x, pick1.y] not in offered and second.item_count == legal.size(), "053 actual the second warden is not offered the first warden's reserved cell")
	var pick2 := _hex(await _press(h, second, 1))
	await Batch047Controls.settle(h, combat)
	var live := CreatedActorRules.actors(b)
	var at: Array = combat.player_entities.filter(func(e): return e.get("created_owner_id", "") == b.character_id).map(func(e): return e.hex_position)
	h._assert(_slots(b) == 3 and _sources(b) == 1 and live.size() == 2 and at.size() == 2 and pick1 in at and pick2 in at and pick1 != pick2 and _no_overlap(combat), "053 actual two wardens enter at the two chosen cells, one slot paid once, no overlap (%s)" % str(at))
	# 3. A cell taken between the pick and confirmation refuses before payment.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch053Checks.PAIR)
	var m1 := await _popup(h, combat, "Place Warden 1 of 2")
	var t1 := _hex(await _press(h, m1, 1))
	var m2 := await _popup(h, combat, "Place Warden 2 of 2")
	var prior_enemy: Vector2i = enemy["hex_position"]
	enemy["hex_position"] = t1
	combat._update_grid_entities()
	var had_m2 := m2 != null
	var spent_before := _slots(b)
	var sources_before := _sources(b)
	await _press(h, m2, 1)
	await Batch047Controls.settle(h, combat)
	h._assert(had_m2 and _slots(b) == spent_before and _sources(b) == sources_before, "053 actual confirmation rechecks: a destination occupied after the pick refuses with nothing spent")
	enemy["hex_position"] = prior_enemy
	combat._update_grid_entities()
	# A destination popup that outlives its turn is stale.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	var src_before := _sources(b)
	await Batch047Controls.begin(h, combat, b, Batch053Checks.PAIR)
	var turn_menu := await _popup(h, combat, "Place Warden 1 of 2")
	var had_turn := turn_menu != null
	CombatAction.active_turn_serial += 1
	await _press(h, turn_menu, 1)
	await Batch047Controls.settle(h, combat)
	h._assert(had_turn and _slots(b) == 4 and _sources(b) == src_before, "053 actual a destination popup answered after its turn ended spends nothing")
	# 4. No legal space: 'refuse' spends nothing, 'spend' pays once and creates nothing.
	var blocked: Array = []
	for hex in HexUtils.get_neighbors(origin):
		var tile: HexTile = combat.hex_grid.get_tile(hex)
		if tile != null and not bool(tile.custom_properties.get("blocks_movement", false)):
			tile.custom_properties["blocks_movement"] = true
			blocked.append(tile)
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	var before_sources := _sources(b)
	await Batch047Controls.begin(h, combat, b, Batch053Checks.PAIR)
	await Batch047Controls.settle(h, combat)
	h._assert(_slots(b) == 4 and _sources(b) == before_sources and await _popup(h, combat, "Place Warden") == null, "053 actual walled in: the 'refuse' summon opens no picker and spends nothing")
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	var entities_before: int = combat.player_entities.size()
	await Batch047Controls.begin(h, combat, b, Batch053Checks.GAMBLE)
	await Batch047Controls.settle(h, combat)
	h._assert(_slots(b) == 3 and combat.player_entities.size() <= entities_before and not CreatedActorRules.actors(b).any(func(x): return str(x.get_meta("created_source_id", "")).contains(Batch053Checks.GAMBLE)), "053 actual walled in: the 'spend' summon pays exactly one slot and creates nothing")
	for tile in blocked: tile.custom_properties.erase("blocks_movement")
	# 5. A projected item copy takes a legal adjacent cell, never an occupied one.
	var fig := Batch042Checks.add(a, Batch042Checks.FIGURINE)
	ItemProjectionRules.project(a, fig)
	var joined := ItemProjectionRules.attach(combat, a, Vector2i.ZERO)
	var hound_at: Array = combat.player_entities.filter(func(e): return e.get("combat_id", "") == ItemProjectionRules.actor_id(fig)).map(func(e): return e.hex_position)
	h._assert(joined.size() == 1 and hound_at.size() == 1 and HexUtils.get_distance(Vector2i.ZERO, hound_at[0]) == 1 and _no_overlap(combat), "053 actual a projected copy enters a legal adjacent cell without overlap (%s)" % str(hound_at))
	ItemProjectionRules.revert(a, fig)
	a.inventory.destroy_instance(fig)
	# 6. Real save/load keeps the created wardens' record.
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_053_placement"
	var saved: bool = SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(slot)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		h._assert(loaded and nb != null and CreatedActorRules.actors(nb).size() == CreatedActorRules.actors(b).size() and not JSON.stringify(nb.to_dict()).contains("_placement"), "053 actual real save/load keeps the wardens; transient picks are not saved")
		SaveManager.delete_save(slot)
	else:
		h._assert(false, "053 actual real save (block='%s')" % SaveManager.get_save_block_reason())
	h._exit_test()

