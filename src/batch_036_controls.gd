class_name Batch036Controls
extends RefCounted

static func cast(h: Node, combat: Node, caster: Character, target, spell_id: String) -> void:
	h._p_focus(combat, caster)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == spell_id:
			combat.hud._on_spell_selected(index)
			break
	await Batch027Controls.answer(h, combat, "", "Level 1")
	var pos: Vector2i = target.get("hex_position", Vector2i.ZERO) if target is Dictionary else Batch031Controls._position(combat, target)
	combat._on_hex_clicked(pos)
	for _frame in 300:
		await h.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break
	h._assert(not combat._cast_in_progress, "036 cast finishes through its production continuation")

static func run(h: Node) -> void:
	h._enter_test("batch_036_end_and_charge_flow")
	h._setup_world()
	Batch036Checks.load_fixtures()
	seed(36036)
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior_known := b.known_spells.duplicate()
	var prior_book := b.wizard_spellbook.duplicate()
	var prior_choices := b.feature_choices.duplicate(true)
	var prior_features := b.features.duplicate(true)
	var spells: Array[String] = ["fixture:b036_mark"]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b036_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	b.spell_slots["1"] = 10
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(1, 0)
	enemy["current_hp"] = 50
	enemy["max_hp"] = 50
	combat._update_grid_entities()
	# S-086 actual cast, then the caster's concentration ends.
	await cast(h, combat, b, enemy, "fixture:b036_mark")
	var source := str(b.concentrating_on.get("effect_source", ""))
	h._assert(not source.is_empty() and SpellEffects.records(enemy).has(source) and SpellEffects.records(enemy)[source].end_aftermath.size() == 2, "036 actual cast captures the end aftermath on the creature's exact source")
	SpellEffects.clear_source_end_events()
	SpellEffects.end_concentration(b, [enemy])
	var events := SpellEffects.source_end_events().filter(func(e): return e.source_id == source)
	h._assert(events.size() == 1 and events[0].end_reason == "concentration_ended" and events[0].aftermath.size() == 1 and events[0].aftermath[0].aftermath_id == "recoil" and enemy.get("conditions", {}).has("prone") and int(enemy.current_hp) == 50, "036 actual concentration end emits one final event with only its own follow-up at the creature (%s)" % JSON.stringify(events))
	# Second actual cast on a party member, which then expires over real time.
	await cast(h, combat, b, a, "fixture:b036_mark")
	var second := str(b.concentrating_on.get("effect_source", ""))
	var hp := a.current_hp
	SpellEffects.clear_source_end_events()
	GameManager.campaign_elapsed_seconds += 12
	SpellEffects.advance_time([b, a], 12)
	events = SpellEffects.source_end_events().filter(func(e): return e.source_id == second)
	h._assert(events.size() == 1 and events[0].end_reason == "expired" and a.current_hp == hp - 3 and not a.has_condition("prone"), "036 actual expiry fires only the expiry follow-up once")
	h._teardown_scene(combat)
	# S-060 exact copies on a party member, through the inventory spend boundary.
	a.inventory.add_item("fixture:b036_spent_rod")
	a.inventory.add_item("fixture:b036_spent_rod")
	var rods := a.inventory.owned_instances().filter(func(r): return r.definition_id == "fixture:b036_spent_rod")
	a.inventory.spend_instance_charges(str(rods[0].instance_id), 2)
	h._assert(a.inventory.last_charge_receipt.get("degraded", false) and bool(a.inventory.get_instance(str(rods[0].instance_id)).state.degraded) and not a.inventory.get_instance(str(rods[1].instance_id)).state.has("degraded"), "036 actual last-charge degradation affects only the spent copy")
	var reloaded := Character.new()
	reloaded.from_dict(a.to_dict())
	h._assert(InventoryCopies.saved_error(a.inventory.to_dict()).is_empty() and bool(reloaded.inventory.get_instance(str(rods[0].instance_id)).state.get("degraded", false)), "036 actual degraded copy survives save/restore")
	b.known_spells.assign(prior_known)
	b.wizard_spellbook.assign(prior_book)
	b.feature_choices = prior_choices
	b.features = prior_features
	h._exit_test()
