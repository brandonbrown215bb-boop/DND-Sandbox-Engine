class_name Batch056Controls
extends RefCounted
## Batch 056 scenario: real combat turns for after_owner hounds, with a
## conscious, unconscious and dead owner, then concentration ending.

static func _names(combat: Node) -> Array:
	return combat.tracker.combatants.map(func(c): return str(c.name))

static func _is_hound(entity: Variant) -> bool:
	return entity is Character and str(entity.get_meta("created_spell_id", "")) == Batch056Checks.HOUNDS

## End the owner's real turn and let the real turn loop run until a turn that
## is neither the owner's nor a hound's begins (returns the hound turns seen).
static func _owner_round(h: Node, combat: Node, owner: Character) -> Array:
	for i in combat.tracker.combatants.size():
		if combat.tracker.combatants[i].entity is Character and combat.tracker.combatants[i].entity == owner: combat.tracker.active_index = i
	h._p_focus(combat, owner, false)
	combat.active_combatant = combat.tracker.get_active()
	combat.resolving_player_action = false
	var seen: Array = []
	combat._end_active_turn()
	for _t in 400:
		var e: Variant = combat.active_combatant.get("entity")
		if _is_hound(e) and not seen.has(e.character_name): seen.append(e.character_name)
		if not (e is Character and e == owner) and not _is_hound(e): break
		await h.get_tree().create_timer(0.02).timeout
	return seen

static func run(h: Node) -> void:
	h._enter_test("batch_056_created_initiative_flow")
	h._setup_world()
	Batch056Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true), "hp": b.current_hp}
	var spells: Array[String] = [Batch056Checks.HOUNDS, Batch056Checks.SPRITE]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b056_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
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
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(4, 4)
	enemy["current_hp"] = 200
	enemy["max_hp"] = 200
	enemy["armor_class"] = 1
	enemy["attacks"] = [] # keep the goblin's own turns from changing the owner's state
	combat._update_grid_entities()
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch056Checks.HOUNDS)
	await Batch047Controls.settle(h, combat)
	var hounds := CreatedActorRules.actors(b).filter(func(x): return _is_hound(x))
	var names := _names(combat)
	var at := -1
	for i in combat.tracker.combatants.size():
		if combat.tracker.combatants[i].entity is Character and combat.tracker.combatants[i].entity == b: at = i
	h._assert(hounds.size() == 2 and at >= 0 and at + 2 < names.size() and names[at + 1] == "Hound 1" and names[at + 2] == "Hound 2", "056 actual the cast puts Hound 1 and Hound 2 into initiative directly after their owner (%s)" % str(names))
	# Conscious owner: the HUD order is paid once now and carried out on the hound's own turn.
	Batch047Controls.fresh_turn(h, combat, b)
	combat.hud._on_feature_selected(Batch055Controls._index(combat, "Command Hound 2 [2]: Dodge"))
	for _f in 3: await h.get_tree().process_frame
	h._assert(not Batch055Controls._bonus(combat) and not hounds[1].has_condition("dodging"), "056 actual commanding Hound 2 charges the owner's Bonus Action once and waits for its turn")
	var seen := await _owner_round(h, combat, b)
	h._assert(seen == ["Hound 1", "Hound 2"] and hounds[1].has_condition("dodging") and hounds[0].has_condition("dodging"), "056 actual each hound takes its own turn after the owner: the order, then the declared default (%s)" % str(seen))
	# Unconscious owner: the hound takes its declared attack_nearest turn.
	hounds[0].remove_condition("dodging")
	hounds[1].remove_condition("dodging")
	var hound_hex: Vector2i = CreatedCommandRules._entity(combat, hounds[0].character_id).hex_position
	for n in HexUtils.get_neighbors(hound_hex):
		if not combat._is_occupied_hex(n):
			enemy["hex_position"] = n
			break
	combat._update_grid_entities()
	b.current_hp = 0
	b.is_alive = false
	var hp_before := int(enemy.current_hp)
	seen = await _owner_round(h, combat, b)
	h._assert(seen.has("Hound 1") and not hounds[0].has_condition("dodging") and int(enemy.current_hp) <= hp_before and CreatedCommandRules.behaviour(b, hounds[0]) == "attack_nearest", "056 actual unconscious owner: Hound 1 attacks the nearest enemy on its own turn (%s; hp %d->%d)" % [str(seen), hp_before, int(enemy.current_hp)])
	h._p_focus(combat, b)
	var forced_before: bool = combat._can_spend_action_cost("bonus_action")
	combat._on_hud_action("command_created_actor", {"actor_id": hounds[0].character_id, "order": "dodge"})
	for _f in 3: await h.get_tree().process_frame
	h._assert(forced_before and combat._can_spend_action_cost("bonus_action") and not hounds[0].has_condition("dodging"), "056 actual a command from the unconscious owner is refused and spends nothing")
	# Dead owner: declared 'none'; nothing happens and the hounds stay.
	b.death_save_failures = 3
	var hp_dead := int(enemy.current_hp)
	seen = await _owner_round(h, combat, b)
	h._assert(b.is_dead() and seen.size() == 2 and int(enemy.current_hp) == hp_dead and not hounds[0].has_condition("dodging") and CreatedActorRules.actors(b).size() == 2 and combat.player_entities.any(func(e): return e.character == hounds[0]), "056 actual dead owner: the hounds take their declared 'none' turns and are not deleted (%s)" % str(seen))
	# Concentration end while the sprite (own initiative) is mid-turn: it leaves; nobody replays or is skipped.
	b.death_save_failures = 0
	b.current_hp = prior.hp
	b.is_alive = true
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch056Checks.SPRITE)
	await Batch047Controls.settle(h, combat)
	var sprite: Character = null
	for x in CreatedActorRules.actors(b):
		if str(x.get_meta("created_spell_id", "")) == Batch056Checks.SPRITE: sprite = x
	var order_before := _names(combat)
	var next_name := ""
	for i in combat.tracker.combatants.size():
		if combat.tracker.combatants[i].entity is Character and combat.tracker.combatants[i].entity == sprite:
			combat.tracker.active_index = i
			next_name = str(combat.tracker.combatants[(i + 1) % combat.tracker.combatants.size()].name)
	h._assert(sprite != null and order_before.has("Sprite 1") and not next_name.is_empty(), "056 actual the 'own' sprite rolls into the real initiative order (%s)" % str(order_before))
	combat.active_combatant = combat.tracker.get_active()
	combat.active_character = sprite
	SpellEffects.end_concentration(b, [b])
	combat._end_active_turn()
	for _f in 10: await h.get_tree().process_frame
	h._assert(not CreatedActorRules.actors(b).has(sprite) and not _names(combat).has("Sprite 1") and not combat.player_entities.any(func(e): return e.character == sprite) and str(combat.tracker.get_active().name) == next_name and CreatedActorRules.actors(b).size() == 2, "056 actual concentration end removes the sprite mid-turn; the next turn is %s as planned and the hounds stay (%s)" % [next_name, str(_names(combat))])
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_056_initiative"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "056 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var back: Array = [] if nb == null else CreatedActorRules.actors(nb).map(func(x): return x.character_name)
		h._assert(loaded and back == ["Hound 1", "Hound 2"] and nb.spell_effects.values().all(func(r): return not JSON.stringify(r).contains("_orders")), "056 actual real load keeps both hounds; pending orders are not saved (%s)" % str(back))
		SaveManager.delete_save(slot)
	h._exit_test()
