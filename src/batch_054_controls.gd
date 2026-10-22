class_name Batch054Controls
extends RefCounted
## Batch 054 scenario: real HUD casts choose a permitted creature and count.

static func _pick(h: Node, menu: PopupMenu, prefix: String) -> void:
	if menu == null: return
	for i in menu.item_count:
		if menu.get_item_text(i).begins_with(prefix):
			menu.id_pressed.emit(menu.get_item_id(i))
			break
	for _f in 3: await h.get_tree().process_frame

static func _created(b: Character) -> Array:
	return CreatedActorRules.actors(b).filter(func(a): return str(a.get_meta("created_spell_id", "")) == Batch054Checks.MENAGERIE)

static func run(h: Node) -> void:
	h._enter_test("batch_054_factory_choices_flow")
	h._setup_world()
	Batch054Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true)}
	var spells: Array[String] = [Batch054Checks.MENAGERIE]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b054_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
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
	# 1. The creature popup lists Cancel plus exactly the declared templates; Cancel spends nothing.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch054Checks.MENAGERIE)
	var menu := await Batch053Controls._popup(h, combat, "Choose a creature")
	var texts: Array = []
	if menu != null:
		for i in menu.item_count: texts.append(menu.get_item_text(i))
	h._assert(texts.size() == 3 and texts[0] == "Cancel" and str(texts[1]).begins_with("Hound") and str(texts[2]).begins_with("Owl"), "054 actual the cast offers Cancel plus exactly the declared creatures (%s)" % str(texts))
	await _pick(h, menu, "Cancel")
	await Batch047Controls.settle(h, combat)
	h._assert(Batch053Controls._slots(b) == 4 and _created(b).is_empty(), "054 actual Cancel spends nothing and creates nothing")
	# 2. A superseded creature popup is stale and spends nothing.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch054Checks.MENAGERIE)
	var old := await Batch053Controls._popup(h, combat, "Choose a creature")
	combat._cast_in_progress = false
	combat.resolving_player_action = false
	await Batch047Controls.begin(h, combat, b, Batch054Checks.MENAGERIE)
	var newer := await Batch053Controls._popup(h, combat, "Choose a creature", old)
	var both := old != null and newer != null
	await _pick(h, old, "Owl")
	h._assert(both and Batch053Controls._slots(b) == 4 and _created(b).is_empty(), "054 actual answering a superseded creature popup spends nothing")
	await _pick(h, newer, "Cancel")
	await Batch047Controls.settle(h, combat)
	# 3. Only one free cell: two Hounds are refused before payment; one Hound succeeds and pays once.
	var blocked: Array = []
	var free := PlacementRules.candidates(combat, origin, "medium", 1)
	for hex in free.slice(1):
		var tile: HexTile = combat.hex_grid.get_tile(hex)
		tile.custom_properties["blocks_movement"] = true
		blocked.append(tile)
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch054Checks.MENAGERIE)
	await _pick(h, await Batch053Controls._popup(h, combat, "Choose a creature"), "Hound")
	var count_menu := await Batch053Controls._popup(h, combat, "How many to create?")
	var counts: Array = []
	if count_menu != null:
		for i in count_menu.item_count: counts.append(count_menu.get_item_text(i))
	await _pick(h, count_menu, "2")
	await Batch047Controls.settle(h, combat)
	h._assert(counts == ["Cancel", "1", "2"] and Batch053Controls._slots(b) == 4 and _created(b).is_empty(), "054 actual two Hounds with one free cell are refused before payment (offered %s)" % str(counts))
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch054Checks.MENAGERIE)
	await _pick(h, await Batch053Controls._popup(h, combat, "Choose a creature"), "Hound")
	await _pick(h, await Batch053Controls._popup(h, combat, "How many to create?"), "1")
	await Batch047Controls.settle(h, combat)
	var made := _created(b)
	var at: Array = combat.player_entities.filter(func(e): return made.any(func(x): return x.character_id == e.get("combat_id", ""))).map(func(e): return e.hex_position)
	h._assert(Batch053Controls._slots(b) == 3 and made.size() == 1 and made[0].character_name == "Hound 1" and at == [free[0]] and Batch053Controls._no_overlap(combat), "054 actual one chosen Hound enters the one free cell; one slot paid once")
	for tile in blocked: tile.custom_properties.erase("blocks_movement")
	# 4. The Owl option (count fixed at 1) asks no count and creates exactly one Owl.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch054Checks.MENAGERIE)
	await _pick(h, await Batch053Controls._popup(h, combat, "Choose a creature"), "Owl")
	await Batch047Controls.settle(h, combat)
	var owls := _created(b)
	h._assert(Batch053Controls._slots(b) == 3 and owls.size() == 1 and owls[0].character_name == "Owl 1" and owls[0].max_hp == 5, "054 actual the Owl option creates exactly one Owl (concentration replaces the Hound) and pays once")
	# 5. Real save/load rebuilds the chosen template.
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_054_factory"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "054 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var names: Array = [] if nb == null else _created(nb).map(func(x): return x.character_name)
		h._assert(loaded and names == ["Owl 1"] and not JSON.stringify(nb.to_dict()).contains("_factory"), "054 actual real load rebuilds the chosen Owl; the transient choice is not saved (%s)" % str(names))
		SaveManager.delete_save(slot)
	h._exit_test()
