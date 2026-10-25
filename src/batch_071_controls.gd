class_name Batch071Controls
extends RefCounted
## Batch 071 (S-130/S-131): maximum-HP sources cast on real goblin combatants
## through the HUD spell picker and target click. Cancel spends nothing; same-
## named sources do not combine; ending concentration restores the maximum; a
## zero maximum kills once with the declared remains; a character recipient's
## source survives a real save/load and batch_071_monster_max_hp_reload.

const SLOT := "batch_071_monster_max_hp"
const SPELLS := [Batch071Checks.WITHER, Batch071Checks.SAP, Batch071Checks.VIGOR]

static var _prior := {}

static func _arm(c: Character) -> void:
	_prior[c] = [c.known_spells.duplicate(), c.wizard_spellbook.duplicate(), c.feature_choices.duplicate(true), c.features.duplicate(true), c.spell_slots.duplicate(true)]
	c.known_spells.assign(SPELLS)
	c.wizard_spellbook.assign(SPELLS)
	c.feature_choices[c.get_spellcasting_feature_id()] = SPELLS.duplicate()
	c.features.append({"id": "fixture:b071_prepared_permission", "effects": [{"type": "always_prepared_spells", "spells": SPELLS.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	c.spell_slots["1"] = 4
	c.willingness = "willing"

static func _disarm(c: Character) -> void:
	var p: Array = _prior.get(c, [])
	if p.is_empty(): return
	c.known_spells.assign(p[0]); c.wizard_spellbook.assign(p[1]); c.feature_choices = p[2]; c.features = p[3]; c.spell_slots = p[4]
	_prior.erase(c)

static func _turn(combat: Node, c: Character) -> void:
	for i in combat.player_entities.size():
		if combat.player_entities[i].get("character") == c: combat.current_player_idx = i
	combat.active_character = c
	combat.active_combatant = {"is_player": true, "entity": c}
	combat.turn_budget.reset(c, combat.player_entities)

static func _cancel(h: Node, combat: Node, c: Character, spell_id: String) -> bool:
	combat.hud.update_hud(c, combat.tracker)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if str(combat.hud.spells_registered[index].get("id", "")) == spell_id:
			combat.hud._on_spell_selected(index)
			await Batch027Controls.answer(h, combat, "", "")
			for _f in 10: await h.get_tree().process_frame
			combat.pending_action_type = ""
			return true
	return false

static func run(h: Node) -> void:
	h._enter_test("batch_071_monster_max_hp_flow")
	h._setup_world()
	Batch071Checks.load_fixtures()
	var alice: Character = PlayerManager.get_player(0).get("character")
	var bob: Character = PlayerManager.get_player(1).get("character")
	_arm(alice)
	_arm(bob)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		if entry.get("character") == alice: entry["hex_position"] = Vector2i.ZERO
		if entry.get("character") == bob: entry["hex_position"] = Vector2i(0, 1)
	var gob: Dictionary = combat.monster_entities[0]
	gob["hex_position"] = Vector2i(2, 0)
	gob["max_hp"] = 20
	gob["current_hp"] = 20
	var husk := Batch071Checks.monster("b071_live_husk", 6)
	husk["hex_position"] = Vector2i(3, 0)
	combat.monster_entities.append(husk)
	combat._update_grid_entities()
	_turn(combat, bob)
	var shown := await _cancel(h, combat, bob, Batch071Checks.WITHER)
	h._assert(shown and int(bob.spell_slots["1"]) == 4 and combat.turn_budget.action_available and int(gob.max_hp) == 20, "071 live Cancel at the slot prompt spends no slot or action and changes no maximum")
	var ok: bool = await Batch031Controls._cast_to(h, combat, bob, Batch071Checks.WITHER, Vector2i(2, 0))
	h._assert(ok and int(gob.max_hp) == 14 and int(gob.current_hp) == 14 and int(bob.spell_slots["1"]) == 3 and not combat.turn_budget.action_available, "071 live HUD cast on the goblin: max 20 -> 14, current clamped, one slot and the Action paid")
	ok = await Batch031Controls._cast_to(h, combat, bob, Batch071Checks.SAP, Vector2i(2, 0))
	h._assert(int(gob.max_hp) == 14 and int(bob.spell_slots["1"]) == 3, "071 live a second cast with no Action left is refused before paying")
	_turn(combat, alice)
	ok = await Batch031Controls._cast_to(h, combat, alice, Batch071Checks.WITHER, Vector2i(2, 0))
	h._assert(ok and int(gob.max_hp) == 14 and MaxHpSourceRules.sources(gob).size() == 2, "071 live a second caster's same-named spell does not combine (max stays 14)")
	_turn(combat, bob)
	ok = await Batch031Controls._cast_to(h, combat, bob, Batch071Checks.SAP, Vector2i(2, 0))
	h._assert(ok and int(gob.max_hp) == 10 and int(gob.current_hp) == 10, "071 live switching concentration to a different spell: bob's wither ends, alice's holds, sap adds (max 10)")
	SpellEffects.end_concentration(alice, [gob])
	h._assert(int(gob.max_hp) == 16 and int(gob.current_hp) == 10, "071 live ending alice's concentration restores 6; current is not raised (16/10: %d/%d, conc=%s, sources=%s)" % [int(gob.max_hp), int(gob.current_hp), str(alice.concentrating_on.keys()), str(MaxHpSourceRules.sources(gob))])
	_turn(combat, alice)
	ok = await Batch031Controls._cast_to(h, combat, alice, Batch071Checks.WITHER, Vector2i(3, 0))
	var after: Dictionary = husk.get("zero_hp_aftermath", {})
	h._assert(ok and not bool(husk.is_alive) and int(husk.max_hp) == 0 and after.get("remains", "") == "dust" and after.get("cause", "") == "withered", "071 live a 6-maximum husk reaches 0 maximum: dies once, dust remains")
	var snapshot := JSON.stringify(after)
	var slots := int(bob.spell_slots["1"])
	_turn(combat, bob)
	await Batch031Controls._cast_to(h, combat, bob, Batch071Checks.WITHER, Vector2i(3, 0))
	h._assert(JSON.stringify(husk.get("zero_hp_aftermath", {})) == snapshot and int(husk.max_hp) == 0 and int(bob.spell_slots["1"]) == slots, "071 live a cast at the dead husk is refused before paying; no duplicate death or remains")
	SpellEffects.end_concentration(alice, [husk])
	h._assert(not bool(husk.is_alive) and int(husk.current_hp) == 0, "071 live ending the zero-limit source never revives the body")
	_turn(combat, bob)
	var base := alice.max_hp
	ok = await Batch031Controls._cast_to(h, combat, bob, Batch071Checks.VIGOR, Batch031Controls._position(combat, alice))
	h._assert(ok and alice.max_hp == base + 5, "071 live vigor on alice raises her maximum by 5")
	GameManager.test_mode = true
	h._teardown_scene(combat)
	_disarm(alice)
	_disarm(bob)
	var dto := alice.to_dict()
	var json_back := Character.new()
	json_back.from_dict(JSON.parse_string(JSON.stringify(dto)))
	h._assert(json_back.max_hp == alice.max_hp and json_back.max_hp_sources.size() == alice.max_hp_sources.size() and SpellEffectPersistence.saved_state_error(JSON.parse_string(JSON.stringify(dto))).is_empty(), "071 live JSON-text DTO round trip keeps the linked source")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "071 live real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var nc: Character = PartyManager.characters.get(alice.character_id, null)
		h._assert(loaded and nc != null and nc.max_hp == base + 5 and nc.max_hp_sources.size() == alice.max_hp_sources.size(), "071 live real load keeps the vigor source (max %d)" % (nc.max_hp if nc else -1))
		var f := FileAccess.open("user://batch_071_ids.txt", FileAccess.WRITE)
		f.store_string("%s|%d" % [alice.character_id, base])
		f.close()
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("batch_071_monster_max_hp_reload")
	Batch071Checks.load_fixtures()
	var parts := FileAccess.get_file_as_string("user://batch_071_ids.txt").strip_edges().split("|")
	var loaded := SaveManager.load_game(SLOT)
	var nc: Character = PartyManager.characters.get(parts[0], null) if parts.size() == 2 else null
	var base := int(parts[1]) if parts.size() == 2 else -1
	h._assert(loaded and nc != null and nc.max_hp == base + 5, "071 fresh process the vigor source rebuilds once (+5)")
	if nc != null:
		for source in SpellEffects.records(nc).keys():
			if SpellEffects.records(nc)[source].has("max_hp_source"): SpellEffects.remove(nc, source, "expired")
		h._assert(nc.max_hp == base and nc.max_hp_sources.is_empty(), "071 fresh process ending the cast restores the base maximum")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://batch_071_ids.txt"))
	h._exit_test()
