class_name Batch061Controls
extends RefCounted
## Batch 061 scenario: a real HUD cast of a mixed after_owner summon puts both
## kinds into the real initiative order right after the owner; a refused cast
## spends nothing; a real save and load keeps each kind's declared timing.

static func _names(combat: Node) -> Array:
	return combat.tracker.combatants.map(func(c): return str(c.name))

static func run(h: Node) -> void:
	h._enter_test("batch_061_summon_timing_flow")
	h._setup_world()
	Batch061Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true)}
	var spells: Array[String] = [Batch061Checks.INSECTS]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b061_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
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
	combat._update_grid_entities()
	# (a) Cancel at the second kind: nothing spent, no turns added.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_effects.clear()
	b.spell_slots = {"1": 2}
	var order_before := _names(combat)
	await Batch047Controls.begin(h, combat, b, Batch061Checks.INSECTS)
	await Batch054Controls._pick(h, await Batch053Controls._popup(h, combat, "How many Spider"), "1")
	await Batch054Controls._pick(h, await Batch053Controls._popup(h, combat, "How many Wasp"), "Cancel")
	await Batch047Controls.settle(h, combat)
	h._assert(b.spell_slots.get("1", 0) == 2 and CreatedActorRules.actors(b).is_empty() and _names(combat) == order_before, "061 actual a cancelled mixed cast spends no slot and adds no turns (%s)" % str(_names(combat)))
	# One Spider and one Wasp: both join right after the owner, before anyone else.
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 2}
	await Batch047Controls.begin(h, combat, b, Batch061Checks.INSECTS)
	await Batch054Controls._pick(h, await Batch053Controls._popup(h, combat, "How many Spider"), "1")
	await Batch054Controls._pick(h, await Batch053Controls._popup(h, combat, "How many Wasp"), "1")
	await Batch047Controls.settle(h, combat)
	var live := CreatedActorRules.actors(b)
	var names: Array = live.map(func(x): return x.character_name)
	var order := _names(combat)
	var at := -1
	for i in combat.tracker.combatants.size():
		if combat.tracker.combatants[i].entity is Character and combat.tracker.combatants[i].entity == b: at = i
	h._assert(b.spell_slots.get("1", 0) == 1 and live.size() == 2 and at >= 0 and order.size() == order_before.size() + 2 and order.slice(at + 1, at + 3) == names, "061 actual the real cast pays one slot and both kinds take turns right after the owner (%s)" % str(order))
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_061_summon_timing"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "061 actual real save (block='%s')" % block)
	if saved:
		GameManager.test_mode = true # Keep the harness alive for the next encounter.
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var back: Array = [] if nb == null else CreatedActorRules.actors(nb)
		var after: Array = [] if nb == null else Batch056Checks.order(Batch056Checks.battle(nb, back))
		h._assert(loaded and back.size() == 2 and back.all(func(x): return CreatedCommandRules.initiative(nb, x) == "after_owner") and after == [nb.character_name] + names + ["Goblin"], "061 actual real load keeps both kinds' after_owner timing; the reloaded actors rejoin initiative right after the owner (%s)" % str(after))
		SaveManager.delete_save(slot)
		if loaded and nb != null:
			GameManager.test_mode = true
			GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
			GameManager.current_state = GameManager.GameState.COMBAT
			var resumed: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
			var arrivals: Array = resumed.player_entities.filter(func(e): return e.get("created_owner_id", "") == nb.character_id)
			var ids: Array = resumed.tracker.combatants.map(func(e): return str(e.id))
			var owner_entry: Array = resumed.tracker.combatants.filter(func(e): return is_same(e.get("entity"), nb))
			var owner_at := -1 if owner_entry.is_empty() else ids.find(str(owner_entry[0].id))
			var places: Array = resumed.player_entities.map(func(e): return e.hex_position)
			h._assert(arrivals.size() == 2 and owner_at >= 0 and ids.slice(owner_at + 1, owner_at + 3) == back.map(func(c): return c.character_id) and arrivals.all(func(e): return places.count(e.hex_position) == 1), "061 review saved summons enter the next real encounter in separate legal spaces and rejoin after their owner (owner=%s, arrivals=%s, order=%s, places=%s)" % [nb.character_id, str(arrivals.map(func(e): return e.combat_id)), str(ids), str(places)])
			h._teardown_scene(resumed)
	h._exit_test()
