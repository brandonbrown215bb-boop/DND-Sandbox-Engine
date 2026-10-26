class_name Batch086Controls
extends RefCounted
## Batch 086 (S-121/S-122): Find Steed through the real spell menu and hex
## clicks. A Large steed arrives only where its whole footprint fits; a blocked
## space (wall under an edge cell, caster/creature overlap) is refused with the
## level-2 slot and the Action unspent, and the cast stays pending so the player
## can pick again; Cancel spends nothing; a space that becomes blocked after the
## spell was selected is refused at the click; the steed survives a real
## save/load and is recovered on a full-footprint space in a fresh process.

const SLOT := "batch_086_find_steed"

static func _settle(h: Node, combat: Node) -> void:
	for _frame in 120:
		await h.get_tree().process_frame
		if not combat.resolving_player_action: break

static func _paladin(h: Node) -> Character:
	var p: Character = h._fresh_char("Steed Paladin", "human", "paladin", {"STR": 16, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16})
	p.character_id = "b086_steed_paladin"
	for _i in 4: p.level_up()
	h._ready_spell_components(p)
	p.known_spells.assign(["find_steed"])
	h._own_class_spells(p)
	p.features.append({"id": "fixture:b086_prepared_permission", "effects": [{"type": "always_prepared_spells", "spells": ["find_steed"], "ability": "CHA", "maximum_spell_level": 2}]})
	p.spell_slots["2"] = 2
	return p

static func _turn(combat: Node, p: Character) -> void:
	combat.current_player_idx = 0
	combat.active_character = p
	combat.active_combatant = {"is_player": true, "entity": p}
	combat.turn_budget.reset(p, combat.player_entities)
	combat._update_grid_entities()

static func _steed(combat: Node, p: Character) -> Dictionary:
	for e in combat.player_entities:
		if bool(e.get("is_steed", false)) and e.get("steed_owner") == p: return e
	return {}

static func _unspent(p: Character, combat: Node) -> bool:
	return int(p.spell_slots.get("2", 0)) == 2 and combat.turn_budget.action_available and _steed(combat, p).is_empty() and PaladinRules.find_steed_state(p).is_empty()

static func run(h: Node) -> void:
	h._enter_test("batch_086_find_steed_arrival_flow")
	h._setup_world()
	GameManager.transition_context["monster_ids"] = ["goblin"]
	var p := _paladin(h)
	PlayerManager.set_player_character(0, p)
	PartyManager.reset()
	PartyManager.register_player_character(0, p)
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
	combat._battle_ending = true
	Batch076FootprintControls._clear_area(combat)
	for i in combat.player_entities.size():
		combat.player_entities[i]["hex_position"] = Vector2i(-5, -i)
	combat.player_entities[0]["hex_position"] = Vector2i.ZERO
	var goblin: Dictionary = combat.monster_entities[0]
	goblin["hex_position"] = Vector2i(7, -6)
	_turn(combat, p)
	# 1. Wall under one edge cell of a Large footprint centred 15 ft away.
	var wall: HexTile = combat.hex_grid.get_tile(Vector2i(4, -1))
	wall.custom_properties["blocks_movement"] = true
	await h._cast_menu_spell(combat, "find_steed", 2)
	var pending_ok: bool = combat.pending_action_type == "cast_spell" or not combat.pending_spell_data.is_empty()
	await combat._on_hex_clicked(Vector2i(3, 0))
	await _settle(h, combat)
	h._assert(pending_ok and _unspent(p, combat), "086 live a space whose Large footprint has a wall under an edge cell (center open) is refused; the slot and Action are unspent and no steed exists (slots=%s)" % p.spell_slots.get("2"))
	# 2. A space adjacent to the caster: the center is free but the footprint overlaps the caster.
	await combat._on_hex_clicked(Vector2i(1, 0))
	await _settle(h, combat)
	h._assert(_unspent(p, combat), "086 live an adjacent space whose Large footprint overlaps the caster is refused with nothing spent")
	# 3. Cancel spends nothing.
	await combat._on_hud_action("cancel", {})
	await _settle(h, combat)
	h._assert(combat.pending_spell_data.is_empty() and _unspent(p, combat), "086 live Cancel after choosing Find Steed spends no slot and no Action")
	# 4. Stale selection: the space was legal when the spell was chosen, then a creature moved into the footprint.
	wall.custom_properties["blocks_movement"] = false
	_turn(combat, p)
	await h._cast_menu_spell(combat, "find_steed", 2)
	var target := Vector2i(3, 0)
	var was_legal := SummonArrivalRules.destination_error(combat, combat.player_entities, p, Vector2i.ZERO, target, DataLoader.get_spell("find_steed")).is_empty()
	goblin["hex_position"] = Vector2i(4, 0)
	combat._update_grid_entities()
	await combat._on_hex_clicked(target)
	await _settle(h, combat)
	h._assert(was_legal and _unspent(p, combat), "086 live a space that becomes blocked by another creature's body after the spell was chosen is refused at confirmation; nothing is spent")
	# 5. Legal space: the whole footprint fits.
	goblin["hex_position"] = Vector2i(7, -6)
	combat._update_grid_entities()
	await combat._on_hex_clicked(target)
	await _settle(h, combat)
	var steed: Dictionary = _steed(combat, p)
	h._assert(not steed.is_empty() and steed.get("hex_position") == target and int(p.spell_slots.get("2", 0)) == 1 and not combat.turn_budget.action_available and PhysicalFactsRules.get_size(steed.get("character")) == "large", "086 live a space whose whole Large footprint fits summons the steed there, spending one level-2 slot and the Action (pos=%s slots=%s)" % [str(steed.get("hex_position")), p.spell_slots.get("2")])
	# 6. Recovery (production caller: combat start for a saved steed): the saved
	# space is now walled, so the factory chooses the nearest full-footprint space.
	combat.hex_grid.get_tile(Vector2i(4, -1)).custom_properties["blocks_movement"] = true
	combat.hex_grid.get_tile(Vector2i(2, 0)).custom_properties["blocks_movement"] = true
	var recovered: Dictionary = combat._add_find_steed_entity(combat.player_entities[0])
	var at: Vector2i = recovered.get("entity", {}).get("hex_position", Vector2i(999, 999))
	var count: int = combat.player_entities.filter(func(e): return bool(e.get("is_steed", false))).size()
	h._assert(bool(recovered.get("success", false)) and count == 1 and PlacementRules.legal_error(combat, at, at, "large", -1, [], {"ignore_entity": recovered.entity.character}).is_empty() and HexUtils.get_distance(Vector2i.ZERO, at) == 2, "086 live recovery re-places the single steed on the nearest space whose whole footprint fits (at=%s)" % str(at))
	combat.hex_grid.get_tile(Vector2i(4, -1)).custom_properties["blocks_movement"] = false
	combat.hex_grid.get_tile(Vector2i(2, 0)).custom_properties["blocks_movement"] = false
	combat._sync_find_steeds()
	var hp_before := int(PaladinRules.find_steed_state(p).get("current_hp", 0))
	h._teardown_scene(combat)
	# 7. Real save/load.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "086 live real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var np: Character = PartyManager.characters.get(p.character_id, null)
		var st: Dictionary = PaladinRules.find_steed_state(np) if np != null else {}
		h._assert(loaded and not st.is_empty() and int(st.get("current_hp", 0)) == hp_before and hp_before > 0, "086 live real load keeps the bonded steed (hp=%d)" % hp_before)
	h._exit_test()

static func run_reload(h: Node) -> void:
	h._enter_test("batch_086_find_steed_arrival_reload")
	var loaded := SaveManager.load_game(SLOT)
	var p: Character = PartyManager.characters.get("b086_steed_paladin", null)
	var st: Dictionary = PaladinRules.find_steed_state(p) if p != null else {}
	h._assert(loaded and p != null and not st.is_empty() and int(st.get("current_hp", 0)) > 0, "086 fresh process the saved steed state loads")
	if p != null:
		GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
		GameManager.test_mode = true
		PlayerManager.set_player_character(0, p)
		var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 1.5)
		combat._battle_ending = true
		var steed: Dictionary = _steed(combat, p)
		var at: Vector2i = steed.get("hex_position", Vector2i(999, 999))
		var legal := not steed.is_empty() and PlacementRules.legal_error(combat, at, at, "large", -1, [], {"ignore_entity": steed.character}).is_empty()
		h._assert(legal and int(steed.character.current_hp) == int(st.get("current_hp", 0)), "086 fresh process combat start recovers the persistent steed on a space whose whole Large footprint fits (at=%s)" % str(at))
		h._teardown_scene(combat)
	SaveManager.delete_save(SLOT)
	h._exit_test()
