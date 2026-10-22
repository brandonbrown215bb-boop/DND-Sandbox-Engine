class_name Batch055Controls
extends RefCounted
## Batch 055 scenario: the real HUD commands each exact owned wolf.

static func _index(combat: Node, prefix: String) -> int:
	combat.hud._show_feature_selection()
	for i in combat.hud.features_registered.size():
		if combat.hud.feature_list.get_item_text(i).begins_with(prefix): return i
	return -1

static func _bonus(combat: Node) -> bool:
	return combat._can_spend_action_cost("bonus_action")

static func run(h: Node) -> void:
	h._enter_test("batch_055_created_commands_flow")
	h._setup_world()
	Batch055Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior := {"known": b.known_spells.duplicate(), "book": b.wizard_spellbook.duplicate(), "choices": b.feature_choices.duplicate(true), "features": b.features.duplicate(true)}
	var spells: Array[String] = [Batch055Checks.PACK]
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b055_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
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
	enemy["hex_position"] = Vector2i(1, 1)
	enemy["current_hp"] = 200
	enemy["max_hp"] = 200
	combat._update_grid_entities()
	Batch047Controls.fresh_turn(h, combat, b)
	b.spell_slots = {"1": 4}
	await Batch047Controls.begin(h, combat, b, Batch055Checks.PACK)
	await Batch047Controls.settle(h, combat)
	var wolves := CreatedActorRules.actors(b)
	h._assert(wolves.size() == 2 and _index(combat, "Command Wolf 1 [1]: Dodge") >= 0 and _index(combat, "Command Wolf 2 [2]: Dodge") >= 0, "055 actual the HUD lists each same-named wolf separately")
	Batch047Controls.fresh_turn(h, combat, b)
	combat.hud._on_feature_selected(_index(combat, "Command Wolf 2 [2]: Dodge"))
	for _f in 3: await h.get_tree().process_frame
	h._assert(wolves[1].has_condition("dodging") and not wolves[0].has_condition("dodging") and not _bonus(combat), "055 actual commanding Wolf 2 affects only Wolf 2 and spends one Bonus Action")
	var blocked := _index(combat, "Command Wolf 1 [1]: Dodge")
	h._assert(blocked >= 0 and combat.hud.feature_list.is_item_disabled(blocked) and combat.hud.feature_list.get_item_text(blocked).contains("No bonus action"), "055 actual with no Bonus Action left the command is offered disabled")
	combat.hud._hide_feature_selection()
	combat._on_hud_action("command_created_actor", {"actor_id": wolves[0].character_id, "order": "dodge"})
	for _f in 3: await h.get_tree().process_frame
	h._assert(not wolves[0].has_condition("dodging"), "055 actual a forced command without budget is refused and changes nothing")
	var wolf_hex: Vector2i = CreatedCommandRules._entity(combat, wolves[0].character_id).hex_position
	for n in HexUtils.get_neighbors(wolf_hex):
		if not combat._is_occupied_hex(n):
			enemy["hex_position"] = n
			break
	Batch047Controls.fresh_turn(h, combat, b)
	combat.hud._on_feature_selected(_index(combat, "Command Wolf 1 [1]: Attack"))
	var menu := await Batch053Controls._popup(h, combat, "Command target")
	h._assert(menu != null and menu.get_item_text(0) == "Cancel", "055 actual an attack order asks for its target with Cancel")
	if menu != null:
		menu.id_pressed.emit(menu.get_item_id(0))
	for _f in 3: await h.get_tree().process_frame
	h._assert(_bonus(combat), "055 actual canceling the target spends nothing")
	combat.hud._on_feature_selected(_index(combat, "Command Wolf 1 [1]: Attack"))
	var old := await Batch053Controls._popup(h, combat, "Command target")
	combat.hud._on_feature_selected(_index(combat, "Command Wolf 1 [1]: Attack"))
	var newer := await Batch053Controls._popup(h, combat, "Command target", old)
	var both := old != null and newer != null
	var hp_before := int(enemy.current_hp)
	if old != null: old.id_pressed.emit(old.get_item_id(1))
	for _f in 3: await h.get_tree().process_frame
	h._assert(both and _bonus(combat) and int(enemy.current_hp) == hp_before, "055 actual answering a superseded target popup spends nothing")
	if newer != null: newer.id_pressed.emit(newer.get_item_id(1))
	for _f in 6: await h.get_tree().process_frame
	h._assert(not _bonus(combat) and CreatedCommandRules._commanded.get(wolves[0].character_id, -1) == CombatAction.active_turn_serial, "055 actual the current attack order charges the owner's Bonus Action once")
	h._teardown_scene(combat)
	b.known_spells.assign(prior.known)
	b.wizard_spellbook.assign(prior.book)
	b.feature_choices = prior.choices
	b.features = prior.features
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var slot := "batch_055_commands"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "055 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(slot)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var names: Array = [] if nb == null else CreatedActorRules.actors(nb).map(func(x): return x.character_name)
		h._assert(loaded and names == ["Wolf 1", "Wolf 2"] and nb.spell_effects.values().any(func(r): return r.get("created_actors", {}).has("control_until")), "055 actual real load keeps both wolves and their control deadline (%s)" % str(names))
		SaveManager.delete_save(slot)
	h._exit_test()

