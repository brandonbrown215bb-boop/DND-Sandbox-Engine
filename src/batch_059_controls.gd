class_name Batch059Controls
extends RefCounted
## Batch 059 scenario: a real HUD cast is limited by nearby remains; none refuses before cost.

static func _created(b: Character) -> Array:
	return CreatedActorRules.actors(b).filter(func(a): return str(a.get_meta("created_spell_id", "")) == Batch059Checks.REMAINS)

static func begin(h: Node, combat: Node, caster: Character) -> void:
	h._p_focus(combat, caster)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == Batch059Checks.REMAINS:
			combat.hud._on_spell_selected(index)
			break
	await Batch027Controls.answer(h, combat, "", "Level 4")
	combat._on_hex_clicked(Batch031Controls._position(combat, caster))

static func run(h: Node) -> void:
	h._enter_test("batch_059_corpse_limit_flow")
	h._setup_world()
	Batch059Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true)}
	var spells: Array[String] = [Batch059Checks.REMAINS]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b059_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 4}]})
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin", "goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 3)
		entry["has_turn"] = true
	combat.monster_entities[0]["hex_position"] = Vector2i(6, 6)
	combat.monster_entities[1]["hex_position"] = Vector2i(7, 6)
	combat._update_grid_entities()
	# 1. No eligible remains in range: refused before cost (SRD: the spell needs a chosen corpse or pile of bones).
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_effects.clear()
	b.spell_slots = {"4": 2}
	await begin(h, combat, b)
	await Batch047Controls.settle(h, combat)
	h._assert(b.spell_slots.get("4", 0) == 2 and _created(b).is_empty(), "059 actual with no eligible remains within 10 feet the cast is refused and the slot is unspent")
	# 2. One pile of Humanoid bones nearby: a 4th-level slot (3 creatures) creates only one Skeleton.
	var bones: Dictionary = combat.monster_entities[1]
	bones["current_hp"] = 0
	bones["is_alive"] = false
	bones["creature_type"] = "humanoid"
	bones["remains"] = "bones"
	bones["hex_position"] = Vector2i(0, 4)
	combat.tracker.remove_combatant(bones["id"])
	combat._update_grid_entities()
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"4": 2}
	await begin(h, combat, b)
	var smenu := await Batch053Controls._popup(h, combat, "How many Skeleton")
	var soffered := Batch058Controls._texts(smenu)
	await Batch054Controls._pick(h, smenu, "1")
	var zmenu := await Batch053Controls._popup(h, combat, "How many Zombie")
	var zoffered := Batch058Controls._texts(zmenu)
	await Batch054Controls._pick(h, zmenu, "0")
	await Batch047Controls.settle(h, combat)
	var names: Array = _created(b).map(func(x): return x.character_name)
	h._assert(soffered == ["Cancel", "0", "1"] and zoffered == ["Cancel", "0"] and b.spell_slots.get("4", 0) == 1 and names == ["Skeleton 1"] and bool(bones.get("material_used", false)), "059 actual one pile of bones caps a 3-creature slot at one Skeleton; the cast succeeds and the bones are used (%s / %s / %s)" % [str(soffered), str(zoffered), str(names)])
	# 3. Used bones no longer count: the next cast is refused before cost.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"4": 1}
	await begin(h, combat, b)
	await Batch047Controls.settle(h, combat)
	h._assert(b.spell_slots.get("4", 0) == 1 and _created(b).size() == 1, "059 actual used remains cannot be animated again; the slot is unspent")
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	# Real save/load: the created Skeleton survives; no new saved fields were added.
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_059_corpse_limit"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "059 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var back: Array = [] if nb == null else _created(nb).map(func(x): return "%s/%d" % [x.character_name, x.base_ac])
		h._assert(loaded and back == ["Skeleton 1/14"], "059 actual real load rebuilds the one Skeleton (%s)" % str(back))
		SaveManager.delete_save(slot)
	h._exit_test()
